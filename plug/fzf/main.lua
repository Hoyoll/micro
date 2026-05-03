local micro = import("micro")
local shell = import("micro/shell")
local config = import("micro/config")
local buffer = import("micro/buffer")
local util = import("micro/util")
local deferred = nil
function fzf(bp)
	local output, err = shell.RunInteractiveShell("fzf --preview 'bat --color=always --style=numbers --line-range=:50 {}'", false, true)
	if err ~= nil then
	    micro.InfoBar():Error(err)
	else
	    fzf_output(output, bp)
	end	
end

function fzf_output(output, bp)
    local strings = import("strings")
    output = strings.TrimSpace(output)
	if output ~= "" then 
		bp:HandleCommand("tab '" .. output .. "'") 
	end
end

function fzf_d(bp)
	local output, err = shell.RunInteractiveShell("fzf --preview 'bat --color=always --style=numbers --line-range=:50 {}'", false, true)
    if err ~= nil then
        micro.InfoBar():Error(err)
    else
       local strings = import("strings")
       output = strings.TrimSpace(output)
       if output ~= "" then
       	   os.remove(output)
       	   micro.InfoBar():Message("Deleted: " .. output)
       end
    end
end

function rg(bp, args)
	if args and #args >= 1 then
	    local query = args[1]
    	local rg = "rg --line-number --column --no-heading " .. query
    	local out = shell.RunCommand(rg)
    	show_text_in_pane(out, bp, query)
    	micro.InfoBar():Message("Results for: "..query)
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
		-- if tab_exist(file) then
		bp:HandleCommand("tabswitch "..file)		
		-- else
		-- bp:HandleCommand("tab "..file)		
		-- end
		deferred = "goto " .. go_to
	end
end

-- function tab_exist(name)
-- 	local tabs = micro.Tabs()
-- 	for i = 1, #tabs.List do
-- 	    local tab = tabs[i]
-- 	    local buf = tabCurPane()
--             if buf and buf.Name() == name then
--                 return true
--             end
-- 	end
--     -- for _, tab in ipairs() do
--     --     
--     -- end
--     return false
-- end

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

function to_do(bp)
	bp:HandleCommand("rg TO-DO")
end

function get_goto(bp)
	local cursor = bp.Cursor
	if cursor:HasSelection() then
		local selected = util.String(cursor:GetSelection())
		bp:HandleCommand("gt "..selected)
		micro.InfoBar():Message("Now in: "..selected)
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
		bp:HandleCommand("tab '".. output .."'")
	end	
end

function init()
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
	config.MakeCommand("todo!", to_do, config.NoComplete)
end
