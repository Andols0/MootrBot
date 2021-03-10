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
local setInterval, clearInterval = timer.setInterval, timer.clearInterva

local LoadModule, UnloadModule, sendhelp

local Settings = {}

local firstload = false
client:on('ready', function()
    if not firstload then
        LoadModule("Mootr","Mootr")
        print('Logged in as '.. client.user.username)
        Clock:start()
        firstload = true
	end
	log = client:getGuild("331016187443937290"):getChannel("506945145623805990")
end)

------------------------Utils
local function Save() --Save settings
    Settings.Time = os.time()
    fs.writeFileSync("./Settings.json",json.encode(Settings))
end

local function Fullnametoid(guild,text)
	local user = guild.members:find(function(m) return m.tag == text end)
	if user then
		return user.id
	end
end

local Comm, Perm = {}, {}

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

function LoadModule(name,path)
	local chunk,e = loadfile(path.."/"..name..".lua")
	local loop, Unloadfuncs
	if chunk then
		setfenv(chunk,getfenv())
		Comm[name], loop, OnClock[name], Unloadfuncs, Perm[name] = chunk()
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
		return false
	end
end
---------------Lua Eval

local function Reboot(message)
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
	Reboot = Reboot
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
            if type(v)=="table" then
				if v[cmd] and v.help then
					local ok = (IsGod or Owner) or not(Perm[module]) or Perm[module].Check(message,cmd)
					if ok == true then
                        p(Fullname.." is running command", cmd.." with args", arg)
                        local e, err = pcall(v[cmd].f, message, arg)
                        if e == false then
                            p(e,err)
                        end
                        return
					else
						print("NOPE")
						if type(ok) == "string" then
							return message:reply(ok)
						end
					end
                end
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
		if LoadModule(name,Modulepath[name]) then
			message:reply("Sucessfull")
		else
			message:reply("Error on load")
		end
	else
		message:reply("Invalid module name")
	end
end

-------------------------- Playground
function Comm.test(message, arg)
	print("Test", message, arg)
end





function sendhelp(message,arg)
    local Msg = ""
    print("helparg"..arg)
	if arg == "" then
		Msg = "Command categories:\n"
		for k,v in pairs(Comm) do
			if type(v) == "table" then
				if v.help then
					Msg = Msg.."\t"..k..":\t"..v.help.."\n"
				end
			end
		end
	elseif Comm[arg] then
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

