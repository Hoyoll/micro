local micro = import("micro")
local shell = import("micro/shell")
local config = import("micro/config")
local buffer = import("micro/buffer")
local util = import("micro/util")
local deferred = nil

function fzf(bp)
	local output, err = shell.RunInteractiveShell("fzf --preview 'bat --color=always --style=numbers --line-range=:50 {}'", false, true)
	if output ~= "" then
	    fzf_output(output, bp)
	end	
end

function fzf_output(output, bp)
    local strings = import("strings")
    output = strings.TrimSpace(output)
	if output ~= "" then		 
		bp:HandleCommand("st '" .. output .. "'") 
	end
end

function rg(bp, args)
	if args and #args >= 1 then
	    local query = args[1]
	    local cmd = [[cmd /C rg --json --follow . .link "]] .. query ..[[" | jq -r 'select(.type=="match") | "\(.data.path.text)::\(.data.line_number)::\(.data.submatches[0].start + 1)::\(.data.line_number - 1)::\(.data.line_number + 50)"' | fzf --delimiter :: --preview 'bat --style=numbers --color=always {1} --highlight-line {2} --line-range {4}:{5}']]
		local output, err = shell.RunInteractiveShell(cmd, false, true)
		if output ~= "" then
			local strings = import("strings")
			output = strings.TrimSpace(output)
			local parsed = split(output, "::")
			table.remove(parsed)
			table.remove(parsed)
			local column = table.remove(parsed)
			local go_to = ""
			go_to = table.remove(parsed) .. ":" .. column
			local file = table.concat(parsed, ":")
			bp:HandleCommand("st "..file)		
			deferred = "goto " .. go_to
		end	
	end
end
-- it's meant to deal with file path with rg format
-- like this: plug\fzf\main.lua:88:23
function gt(bp, args)
	if args and #args >= 1 then
		local argv = split(args[1], ":")
		local go_to = ""
		local column = table.remove(argv)
		go_to = table.remove(argv) .. ":" .. column
		local file = table.concat(argv, ":")
		bp:HandleCommand("st "..file)		
		deferred = "goto " .. go_to
	end
end

function onAnyEvent()
	if deferred ~= nil then
		micro.CurPane():HandleCommand(deferred)
		deferred = nil
	end
end

function split(str, sep)
    local result = {}
    local pattern = "([^" .. sep .. "]+)"

    for match in string.gmatch(str, pattern) do
        table.insert(result, match)
    end

    return result
end

function show_text_in_pane(text, bp, query)
    local buf = buffer.NewBuffer("", "rg-buffer")
    buf:Insert(buffer.Loc(0, 0), text)
	buf.Settings["filetype"] = "md"
    bp:HSplitIndex(buf, true)
end

function get_goto(bp)
	local cursor = bp.Cursor
	local line = util.String(bp.Buf:Line(cursor.Loc.Y))
	local splitted = split(line, "@")
	if splitted ~= nil then
		bp:HandleCommand("gt " .. splitted[1])
		micro.InfoBar():Message("Now in: "..splitted[1])
	end
end

function dig(bp)
	local cursor = bp.Cursor
	if cursor:HasSelection() then
		local selected = util.String(cursor:GetSelection())
		bp:HandleCommand("rg '"..selected .."'")
	end
end

function lf(bp)
	local output, err = shell.RunInteractiveShell("lf -print-selection", false, true)
	if output ~= "" then
		local strings = import("strings")
		output = strings.TrimSpace(output)
		bp:HandleCommand("st '".. output .."'")
	end	
end

function tab_exist(tab_name)
	for i = 1, #micro.Tabs().List do
        for j = 1, #micro.Tabs().List[i].Panes do
            local current_pane = micro.Tabs().List[i].Panes[j]
            local current_buf = current_pane.Buf
            if current_buf.Path == tab_name then
            	return true
            elseif current_buf.AbsPath == tab_name then
            	return true
            end
        end
    end
    return false
end

function smart_tab(bp, args)
	if args and #args >= 1 then
		local tab = args[1]
		if tab_exist(tab) then
			bp:HandleCommand("tabswitch '"..tab.."'")
		else
			bp:HandleCommand("tab '"..tab.."'")
		end
	end	
end

function list_tab(bp)
	local buffer_names = ""
    for i = 1, #micro.Tabs().List do
        for j = 1, #micro.Tabs().List[i].Panes do
            local current_pane = micro.Tabs().List[i].Panes[j]
            local current_buf = current_pane.Buf
            
            if current_buf ~= nil then
                local current_text = ""
                if current_buf.Path ~= nil and current_buf.Path ~= "" then
                    current_text = current_buf.Path
                elseif current_buf.AbsPath ~= nil and current_buf.AbsPath ~= "" then
                    current_text = current_buf.AbsPath
                end
                buffer_names = buffer_names..current_text.."\n"
            end
        end
    end
	local cmd = [[nu -c "echo ']] .. buffer_names .. [[' | fzf --preview 'bat --color=always --style=numbers --line-range=:50 {}'"]]
	local output, err = shell.RunInteractiveShell(cmd, false, true)
	if output ~= "" then
		local strings = import("strings")
		output = strings.TrimSpace(output)
		bp:HandleCommand("st '"..output.."'")
	end
end

function init()
	-- idempoten tab mechanism
	config.MakeCommand("st", smart_tab, config.NoComplete)
	-- listing active buffers
	config.MakeCommand("lt", list_tab, config.NoComplete)
	-- run fzf
    config.MakeCommand("fzf", fzf, config.NoComplete)
	-- run rg
	config.MakeCommand("rg", rg, config.NoComplete)
	-- run lf
	config.MakeCommand("lf", lf, config.NoComplete)
	-- run rg but from selected line
	config.MakeCommand("dig", dig, config.NoComplete)
	-- run gt
	-- it's meant to deal with file path with rg format
	-- like this: plug\fzf\main.lua:88:23
	config.MakeCommand("gt", gt, config.NoComplete)
	-- run gt but from selected line
	config.MakeCommand("get-gt", get_goto, config.NoComplete)
	-- run rg TO-DO
end
