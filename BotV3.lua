math.randomseed(os.time())

dofile("Token.lua") --Contains Token, ID of myself
local discordia = require('discordia')
client = discordia.Client()
discordia.extensions.string()
local fs = require("fs")
local Clock = discordia.Clock()
local timer = require('timer')
local sleep = timer.sleep
local json = require("json")
local slash = require("discordia-slash")
slash.constructor()
client:useSlashCommands()
local setInterval, clearInterval = timer.setInterval, timer.clearInterva

local LoadModule, UnloadModule, sendhelp
local Succ, Raw = pcall(json.decode, fs.readFileSync("./settings.json"))
local Settings =  Succ and Raw or {EnabledModules = {}}

local firstload = false
client:on('slashCommandsReady', function()
    if not firstload then
        LoadModule("Mootr","Mootr")
		LoadModule("Multi", "Multi")
        print('Logged in as '.. client.user.username)
        Clock:start()
        firstload = true
	end
	log = client:getChannel("506945145623805990")
end)

------------------------Utils
local function Save() --Save settings
    Settings.Time = os.time()
    fs.writeFileSync("./settings.json",json.encode(Settings, {indent = true}))
end

--[[local function Fullnametoid(guild,text)
	local user = guild.members:find(function(m) return m.tag == text end)
	if user then
		return user.id
	end
end]] --Something not currently used

local Comm, Perm, Mod = {}, {}, {}

local Modulepath={}
local Unloader = {}
local OnClock = {}

function UnloadModule(name)
	Comm[name] = nil
	Perm[name] = nil
	if Unloader[name] then
		for _,v in ipairs(Unloader[name]) do
			if type(v) == "function" then
				v()
			else
				clearInterval(v)
			end
		end
	end
	Unloader[name]=nil
	if OnClock[name] then
		OnClock[name]=nil
	end
	return true
end

local GuildSlashCommands = {}
local ModuleSlashCommands= {}

local function LoadSlashCommand(name)
	for _, cmd in ipairs(ModuleSlashCommands[name]) do
		for Id, _ in pairs(Settings.EnabledModules[name]) do
			GuildSlashCommands[name][Id] = GuildSlashCommands[name][Id] or {}
			local guild = client:getGuild(Id)
			local success, scom = pcall(guild.slashCommand, guild, cmd:finish())
			if success then
				table.insert(GuildSlashCommands[name][Id], scom)
			else
				print("Error loading slash command in module "..name.." raised error:\n"..scom)
			end
		end
	end
end

function LoadModule(name,path)
	local chunk, e = loadfile(path.."/"..name..".lua")
	local Commands, loop, Unloadfuncs
	if chunk then
		Settings.EnabledModules[name] = Settings.EnabledModules[name] or  {}
		setfenv(chunk,getfenv())
		Commands, loop, OnClock[name], Unloadfuncs, Perm[name] = chunk()
		Comm[name] = {}
		GuildSlashCommands[name] = {}
		ModuleSlashCommands[name] = {}
		for Command, CommData in pairs(Commands) do
			if CommData.slash then
				table.insert(ModuleSlashCommands[name], CommData.cmd)
				CommData.f = function(message)
					message:reply("Error.\nThis is a slash `/` command. Can't be called this way.")
				end
			end
			Comm[name][Command] = CommData
		end
		LoadSlashCommand(name)
		--Comm[name]
		Unloader[name]={}
		if loop then
			for _,v in ipairs(loop) do
				pcall(v.f)
				table.insert(Unloader[name],setInterval(v.tid,v.f))
			end
			--local e,err = pcall(loop)
			--if e==false then
				--p(e,err)
			--end
		end
		for _,v in pairs(Unloadfuncs) do
			table.insert(Unloader[name],v)
		end
		print("Module "..name.." sucessfully loaded")
		Modulepath[name] = path
		return true
	else
		print("Error loading module "..name.." raised error:\n"..e)
		return false, "Error loading module "..name.." raised error:\n"..e
	end
end
---------------Lua Eval

local function Reboot()
	client:stop()
	Clock:stop()
	for k,v in pairs(Unloader) do
		print(k,v)
	end
		os.execute("lxterminal -e bash -c \"luvit BotV3.lua;exec bash\"")
end

local sandbox = setmetatable({
	client = client,
	Comm = Comm,
	Load = LoadModule,
	Unload = UnloadModule,
	sleep = sleep,
	Reboot = Reboot,
	slash = slash
	},
	{ __index = _G }
)

local function code(str)
    return string.format('```\n%s```', str)
end

local pp = require('pretty-print')

local function prettyLine(...)
    local ret = {}
    for i = 1, select('#', ...) do
        local arg = pp.strip(pp.dump(select(i, ...)))
        table.insert(ret, arg)
    end
    return table.concat(ret, '\t')
end

local function printLine(...)
    local ret = {}
    for i = 1, select('#', ...) do
        local arg = tostring(select(i, ...))
        table.insert(ret, arg)
    end
    return table.concat(ret, '\t')
end

local function exec(msg, arg)
    if not arg then return end
    arg = arg:gsub('```\n?', '') -- strip markdown codeblocks

    local lines = {}

	sandbox.message = msg
	sandbox.client = client

    sandbox.print = function(...)
        table.insert(lines, printLine(...))
    end

    sandbox.p = function(...)
        table.insert(lines, prettyLine(...))
    end

    local fn, syntaxError = load(arg, 'DiscordBot', 't', sandbox)
    if not fn then return msg:reply(code(syntaxError)) end

    local success, runtimeError = pcall(fn)
	if not success then return msg:reply(code(runtimeError)) end

    lines = table.concat(lines, '\n')

    if #lines > 1990 then -- truncate long messages
		for i = 1, #lines, 1990 do
			msg:reply(code(lines:sub(i, i + 1990)))
		end
		return
	else
		return msg:reply(code(lines))
	end
end
-----------------------------------

function ClearMessages(time, Command, Message)
	sleep(time)
	if Command.guild.me:hasPermission(Command.channel,0x00002000) then
		Command:delete()
		if Message then
			Message:delete()
		end
	end
end

local DefaultPrefix = "½"

local function PermissionCheck(message, module, cmd)
	if Perm[module] then
		local ok, err = Perm[module].Check(message,cmd)
		if not(ok) and err then
			return ok, message:reply(err)
		else
			return ok
		end
	else
		return true
	end
end

client:on('messageCreate', function(message)
    if message.author.bot then return end
    if message.author == client.user then return end
    if not(message.member) then return end --PM

	local Userid = message.author.id
	local IsGod = (Userid == AndolsId)
	local Owner = message.member == message.guild.owner
	--if not(IsGod) then return end    -----ONLY ME ATM
	local prefix = Settings.Prefix or DefaultPrefix
	local cmd, arg = message.content:match('^'..prefix..'(%S+)%s*(.*)')
	if arg == "" then arg = nil end
	local Name, Fullname = message.author.name, message.author.tag

    if cmd then
		cmd = cmd:lower()
		if cmd == "help" then
			return sendhelp(message, arg)
		--elseif cmd == "ping" then
			--return message:reply("Pong!")
		end
        for module, v in pairs(Comm) do
			if Settings.EnabledModules[module] and Settings.EnabledModules[module][message.guild.id] then
				if type(v)=="table" then
					if v[cmd] and v.help then
						if (IsGod or Owner) or PermissionCheck(message, cmd) then
							p(Fullname.." is running command", cmd.." with args", arg)
							local e, err = pcall(v[cmd].f, message, arg)
							if e == false then
								p(e,err)
							end
							return
						end
					end
				end
			end
        end
		if IsGod or Owner then
			if Mod[cmd] then
				return Mod[cmd](message,arg)
			end
		end
        if IsGod then -- My playground
			if Comm[cmd] then
				Comm[cmd](message,arg)
				return
			elseif cmd == "lua" then
				return exec(message,arg)
			end
		end
		message:reply("I'm sorry I cannot do that "..Name)
	end
end)

function Comm.reload(message,name)  --Module reload
	UnloadModule(name)
	if Modulepath[name] then
		local res, err = LoadModule(name,Modulepath[name])
		if res then
			message:reply("Sucessfull")
		else
			message:reply("Error on load```\n"..err.."```")
		end
	else
		message:reply("Invalid module name")
	end
end

function Mod.enablemodule(message, module)
	if Comm[module] then
		Settings.EnabledModules[module][message.guild.id] = true
		LoadSlashCommand(module)
		message:reply("Enabled module: "..module)
	end
	Save()
end

function Mod.disablemodule(message, module)
	local Id = message.guild.id
	if Comm[module] then
		Settings.EnabledModules[module][Id] = nil
		for _, scom in ipairs(GuildSlashCommands[module][Id]) do
			scom:delete()
		end
		GuildSlashCommands[module][Id] = nil
		message:reply("Disabled module: "..module)
	end
	Save()
end
-------------------------- Playground
function Comm.test(message, arg)
	print("Test", message, arg)
end


function sendhelp(message,arg)
    local Msg = ""
	if not arg then
		Msg = "Command categories:\n"
		for k,v in pairs(Comm) do
			if type(v) == "table" then
				if v.help then
					Msg = Msg.."\t"..k..":\t"..v.help.."\n"
				end
			end
		end
	elseif Comm[arg] then
		print("helparg "..arg)
		Msg = ""
		if Comm[arg].info then
			Msg = Msg.."General information for this module:\n\t"..Comm[arg].info.."\n"
		end
		Msg = Msg.."Commands:\n"

		for k,v in pairs(Comm[arg]) do
			if k ~= "help" and k ~= "info" then
				Msg = Msg.."\t**"..k.."**:\t"..v.help.."\n"
			end
		end
	end
	if Msg ~= "" then
		message.author:send(Msg)
	end
end

Clock:on('sec', function(tid)
	for _, v in pairs(OnClock) do
		pcall(v, tid, client, discordia)
	end
end)


client:run("Bot "..Token)

