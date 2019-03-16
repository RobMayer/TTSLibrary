config = {
    PROMPT = "!tower", --edit this to determine what you want your command line trigger to be. Recommend starting with an exclaimation point
    TERMINAL = "[ff8000]TOWER>[-] ", --printed before each line in most cases
}

--add your commands here
commands = {
	["echo"] = { --name of the command
		desc = "This is a sample command - it will echo back what you send it ...", -- description of the command
		arguments = { -- list of arguments
			{"[requiredArgument]", "Some required Argument", true}, -- {syntax, description, requiredFlag (optional, defaults to false)}
			{"[optionalRequirement]", "some optional argument"},
			{"on|off", "Literally either \"on\" or \"off\""},
		},
		requiredArgs = 1, --optional but recommended. number of required arguments. If this is not set, then it will go through the arguments list to find how many required flags are true, stopping at the first non-required one.
		adminOnly = false, --optional, defaults to false. If the player calling the command is not promoted or host and this is true, it will error before the function is called
		hostOnly = false, --optional, defaults to false. If the player calling the command is not host and this is true, it will error before the function is called
		private = false, --optional, defaults to false. If this is true, this command will not show up in the help list, but can still be looked up with the specific help command
		call = function(player, ...) --the function that actually gets run when the thing is called
			printToColor(config.TERMINAL..table.concat({...}, " "), player.color, const.COLOR_WHITE[1])
		end
	},
}

--Don't forget to remove this onload function

function onLoad()
    print((config.TERMINAL).."type \""..(config.PROMPT).." help\" into game chat to get started. Open my script to edit me. Don't forget to remove my onLoad function when you're done or this message will get really annoying.")
end

--DO NOT EDIT BELOW THIS LINE

const = {
    COLOR_YELLOW = {{1.0,0.9,0.5}, "[ffe680]"},
    COLOR_RED = {{1.0,0.4,0.4}, "[ff6666]"},
    COLOR_GREEN = {{0.5,0.9,0.5}, "[80e680]"},
    COLOR_BLUE = {{0.6,0.8,1.0}, "[99ccff]"},
    COLOR_PURPLE = {{0.8,0.6,1.0}, "[cc99ff]"},
    COLOR_WHITE = {{1.0,1.0,1.0}, "[ffffff]"},
    OK = 0,
    STATUS_ERROR = 1,
    STATUS_BADARGS = 2,
    STATUS_ADMINONLY = 3,
    STATUS_HOSTONLY = 4,
}

commands = commands or {}

commands['help'] = {
    desc = "lists out what commands are available, or describes a specific command",
    arguments = {
        {"[command]", "Specific command to gather more information on"},
    },
    call = function(player, command)
        if (command ~= nil) then
            printToAll("\n================\nHelp: "..command.."\n================\n", const.COLOR_YELLOW[1]);
            if (commands[command] ~= nil) then
                local params = ""
                local paramDesc = {}
                for i,arg in ipairs(commands[command].arguments or {}) do
                     params = params .. " " .. ((arg[3] or false) and "[b]"..(arg[1]).."[/b] " or "[i]"..(arg[1]).."[/i]")
                     paramDesc[i] = "> "..const.COLOR_BLUE[2]..arg[1].."[-] "..((arg[3] or false) and "(required)" or "(optional)").." - "..arg[2]
                end
                printToColor((commands[command].desc or "No information found"), player.color, const.COLOR_WHITE[1])
                printToColor("", player.color, const.COLOR_WHITE[1])
                printToColor("Syntax", player.color, const.COLOR_WHITE[1])
                printToColor(const.COLOR_YELLOW[2]..config.PROMPT.." "..command.."[-]"..const.COLOR_BLUE[2]..params.."[-]", player.color, const.COLOR_WHITE[1])
                printToColor("", player.color, const.COLOR_WHITE[1])
                if (#paramDesc > 0) then
                    printToColor("Arguments", player.color, const.COLOR_WHITE[1])
                end
                for _,v in ipairs(paramDesc) do
                    printToColor(v, player.color, const.COLOR_WHITE[1])
                end
            else
                printToColor("Help doesn't know anything about '"..command.."'", player.color, const.COLOR_RED[1])
            end
        else
            printToAll("\n================\nHelp\n================\n", const.COLOR_YELLOW[1]);
            for k,v in pairs(commands) do
                if (not (v.private or false)) then
                    local params = ""
                    for i,arg in ipairs(v.arguments or {}) do
                         params = params .. " " .. ((arg[3] or false) and "[b]"..(arg[1]).."[/b] " or "[i]"..(arg[1]).."[/i]")
                    end
                    printToColor(const.COLOR_YELLOW[2]..config.PROMPT.." "..k.."[-]"..const.COLOR_BLUE[2]..params.."[-] - "..(v.desc), player.color, const.COLOR_WHITE[1])
                end
            end
        end
    end,
}

-- Command Line handler
function onChat(message, player)
    if (string.lower(string.sub(message, 1, string.len(config.PROMPT) + 1)) == string.lower(config.PROMPT).." ") then
        local args = {};
        local pass = string.sub(message, string.len(config.PROMPT) + 2)
        local e = 0
        while true do
            local b = e+1
            b = pass:find("%S",b)
            if b==nil then break end
            if pass:sub(b,b)=="'" then
                e = pass:find("'",b+1)
                b = b+1
            elseif pass:sub(b,b)=='"' then
                e = pass:find('"',b+1)
                b = b+1
            else
                e = pass:find("%s",b+1)
            end
            if e==nil then e=#pass+1 end
            args[#args + 1] = pass:sub(b,e-1)
        end
        if (#args < 1) then
			printToColor(config.TERMINAL.."Command Expected", player.color, const.COLOR_RED[1])
            if (commands.help ~= nil) then
				printToColor("Use '"..config.PROMPT.." help' for a list of valid commands", player.color, const.COLOR_RED[1])
			else
				printToColor(config.TERMINAL.." Help command not found!", player.color, const.COLOR_RED[1])
			end
            return false
        end
        local command = string.lower(table.remove(args, 1))
        if (commands[command] ~= nil) then
            if ((commands[command].adminOnly or false) and player.admin) then
                printToColor(config.TERMINAL.." Insufficient Priviliges - You must be promoted", player.color, const.COLOR_RED[1])
                return false
            elseif ((commands[command].hostOnly or false) and player.host) then
                printToColor(config.TERMINAL.." Insufficient Priviliges - You must be the host", player.color, const.COLOR_RED[1])
                return false
            else
				local req = commands[command].requiredArgs
				if (req == nil) then
					req = 0
					for _,v in pairs(commands[command].arguments or {}) do
						if (v[3]) then
							req = req + 1
						else
							break
						end
					end
				end
				if (#args < req) then
					printToColor(config.TERMINAL.." Bad Arguments", player.color, const.COLOR_RED[1])
					if (commands.help == nil) then
						printToColor("WARNING: Help command not found!", player.color, const.COLOR_RED[1])
					else
						commands.help.call(player, command)
					end
					return false
				end
                local status = commands[command].call(player, table.unpack(args))
                if (status ~= nil) then
                    if (status == const.STATUS_ERROR) then printToColor(config.TERMINAL.." General Error", player.color, const.COLOR_RED[1]) end
                    if (status == const.STATUS_BADARGS) then
						printToColor(config.TERMINAL.." Bad Arguments", player.color, const.COLOR_RED[1])
						if (commands.help ~= nil) then
							printToColor("Use '"..config.PROMPT.." help "..command.."' for a list of valid commands", player.color, const.COLOR_RED[1])
						else
							printToColor(config.TERMINAL.." Help command not found!", player.color, const.COLOR_RED[1])
						end
					end
                    if (status == const.STATUS_ADMINONLY) then printToColor(config.TERMINAL.." Insufficient Priviliges - You must be promoted", player.color, const.COLOR_RED[1]) end
                    if (status == const.STATUS_HOSTONLY) then printToColor(config.TERMINAL.." Insufficient Priviliges - You must be the host", player.color, const.COLOR_RED[1]) end
                end
            end
        else
            printToColor(config.TERMINAL.."Unknown Command '"..command.."'", player.color, const.COLOR_RED[1])
			if (commands.help ~= nil) then
				printToColor("Use '"..config.PROMPT.." help' for a list of valid commands", player.color, const.COLOR_RED[1])
			else
				printToColor("WARNING: Help command not found!", player.color, const.COLOR_RED[1])
			end
        end
        return false
    end
end