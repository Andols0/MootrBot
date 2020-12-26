local fs = require("fs")
local json = require("json")
local Mootr = {help = "It's MOOTR ZOOTR"}
local timer = require('timer')
local SettingsString = fs.readFileSync("./Mootr/settings.json")
local Mootrsettings = json.decode(SettingsString) or {}
local SeedsString = fs.readFileSync("./Mootr/seeds.json")
local Seeds = json.decode(SeedsString) or {}
local uv = require("uv")
local WS = require("coro-websocket")

local CreatePlando

local Weights, Constants = dofile("./Mootr/Weights.lua")

local function SettingsExists(message)
    if not Mootrsettings[message.guild.id] then
        Mootrsettings[message.guild.id] = { ignore = {} }
    end
    return Mootrsettings[message.guild.id]
end

local Deep = 0
local Tab = "\t"
local function Printtable(table)
    for k,v in pairs(table) do
        print(Tab:rep(Deep)..k,v)
		if type(v) == "table" then
			Deep = Deep + 1
            print("-------------->")
            Printtable(v)
        end
	end
	Deep = Deep - 1
    print("<------------")
end

local function Save()
    Mootrsettings.Time = os.time()
    fs.writeFileSync("./Mootr/settings.json", json.encode(Mootrsettings))
end

local function SaveSeeds()
    fs.writeFileSync("./Mootr/seeds.json", json.encode(Seeds))
end

local function ResolveEmoji(message, Emoji)
    if Emoji:match("^%d+") then
        return message.guild.emojis:get(Emoji)
    else
        return Emoji
    end
end


local function VotesToWheight(Votes)
    local Weight, Above = {}, {}
    local Name, Weighing, Over
    print("CONVERT")
    for k,v in pairs(Votes) do
        --print(k)
        if Weights[k] then
            Name, Weighing, Over = Weights[k]:f(v)
            if type(Name) == "string" then
                Weight[Name] = Weighing
            else
                for name,weighing in pairs(Name) do
                    Weight[name] = weighing
                end
            end
            if Over then
                Above[k] = true
            end
        else
            print("CAN'T FIND",k)
        end
    end
    return Weight
end


Mootr.resetvotes = {help = "Resets the votes",
    f = function(message)
        local Settings = Mootrsettings[message.guild.id]
        if not(Settings) or (not(Settings) and not(Settings.channel)) then
            message:reply("You need to set the voting channel")
        end
        local Channel = message.guild:getChannel(Settings.channel)
        local Messages = Channel:getMessages()
        message:addReaction("👍")
        for _, Message in pairs(Messages) do
            if not(Settings.ignore[Message.id] or Message == message) then
                Message:clearReactions()  --Version 1
                --[[for _,Reaction in pairs(Message.reactions) do --Version 2
                    if reaction ~= Reaction then
                        for _,member in pairs(Reaction:getUsers()) do
                            if member.id ~= "770332007871283223" then
                                Reaction:delete(member.id)
                            end
                        end
                    end
                end]]
            end
        end
        local Yes = ResolveEmoji(message, Settings.Yes)
        local No = ResolveEmoji(message, Settings.No)
        for _, Message in pairs(Messages) do
            if not(Settings.ignore[Message.id] or Message == message) then
                Message:addReaction(Yes)
                Message:addReaction(No)
            end
        end
        ClearMessages(5000,message)
    end
}

local Plandocwd, Patchcwd, RandoRando, Python, SeedFolder

if package.config:sub(1,1)=="\\" then --Windows
    Plandocwd = "F:/Dropbox/Lua/Mootr/Rando/OoT-Randomizer/plando-random-settings"
    Patchcwd = "F:/Dropbox/Lua/Mootr/Rando/OoT-Randomizer"
    RandoRando = "F:/Dropbox/Lua/Mootr/Rando/OoT-Randomizer/plando-random-settings/weights/MOoTR.json"
    Python = "python"
    SeedFolder = "F:/Dropbox/Lua/Mootr/Rando/Seeds"

else
    Plandocwd = "/home/pi/Desktop/Mootr/Rando/OoT-Randomizer//plando-random-settings/"
    Patchcwd = "/home/pi/Desktop/Mootr/Rando/OoT-Randomizer/"
    RandoRando = "/home/pi/Desktop/Mootr/Rando/OoT-Randomizer/plando-random-settings/weights/rando_rando_league_s2.json"
    Python = "python3.6"
    SeedFolder = "/home/pi/Desktop/Mootr/Rando/Seeds/"
end

Mootr.generate = {help = "Generates the MoOTR seed",
    f = function(message)
        Mootr.weight.f(message, true)
        message:reply("Weightsfile generated\nStarting settings file")
        CreatePlando(message)
    end
}

Mootr.weight = {help = "Generates the wheights file",
    f = function(message)
        local Settings = Mootrsettings["389836194516566018"]--[message.guild.id]
        if not(Settings) or (not(Settings) and not(Settings.channel)) then
            message:reply("You need to set the voting channel")
        end
        local Channel = client:getGuild("389836194516566018"):getChannel(Settings.channel)--message.guild:getChannel(Settings.channel)
        local Messages = Channel:getMessages()
        local Votes = {}
        local tot = 0
        print("READ VOTES")
        for _, Message in pairs(Messages) do
            if not(Settings.ignore[Message.id]) and not(Message == message) then
                local SettingName = Message.content:match("__%*%*(.-)%*%*__") or Message.content:match("%*%*__(.-)__%*%*") or Message.content
                Votes[SettingName] = {Yes = 0, No = 0, Tot = 0}
                --print(SettingName)
                tot = tot + 1
                --print(tot)
                local Rule = Votes[SettingName]
                for _,v in pairs(Message.reactions) do
                    if v.emojiId == Settings.Yes or v.emojiName == Settings.Yes then
                        Rule.Yes = Rule.Yes + v.count
                        Rule.Tot = Rule.Tot + v.count
                    elseif v.emojiId == Settings.No or v.emojiName == Settings.No then
                        Rule.No = Rule.No + v.count
                        Rule.Tot = Rule.Tot + v.count
                    elseif (v.emojiId == Settings.FY or v.emojiName == Settings.FY) and not(Rule.ForceYes) then
                        Rule.ForceYes = true
                    elseif (v.emojiId == Settings.FN or v.emojiName == Settings.FN) and not(Rule.ForceNo) then
                        Rule.ForceNo = true
                    end
                end
            end
        end
        local ConvertedWeights = VotesToWheight(Votes)
        for k,v in pairs(Constants) do
            ConvertedWeights[k] = {}
            for q,w in pairs(v) do
                ConvertedWeights[k][q] = w
            end
        end
        --message:reply("```json\n"..json.encode(VotesToWheight(Votes)).."```")
        --message:delete()
        --Printtable(ConvertedWeights)
        --message.member:send {
        message:reply {
            file = {"weights.json",(json.encode(ConvertedWeights)) }
        }
        fs.writeFileSync(RandoRando, json.encode(ConvertedWeights))
   end
}


local function CreatePatch(message)
    local Patchstderr = uv.new_pipe(false)
    local randolog = ""
    local time = os.time()
    uv.spawn(Python,{
        stdio = {0, 1, Patchstderr},
        cwd = Patchcwd,
        args = {"OoTRandomizer.py"},
    },
    function(code) -- on exit
        print("PATCH EXIT", message)
        if code == 0 then
            coroutine.wrap(function()
                fs.writeFileSync(Patchcwd.."/Roms/Log.txt", randolog)
                local file = randolog:match("Created patchfile at: .+[/\\](.-)%.zpf")
                p(file)
                table.insert(Seeds,file)
                SaveSeeds()
                --local Filepath = SeedFolder..file..".zpf"
                --print(Filepath)
                --message.member:send{
                    --file = Filepath
                --}
                message:send("Seed generated")
            end)()
        else
            coroutine.wrap(function()
                message.member:send("Gen FAILED tell Andols")
            end)()
            --if randolog:match(".*(junk).*") then
                --print("HEEEJ")
            --end
        end
        coroutine.wrap(function()
            message.member:send("Time taken: "..os.time()-time)
        end)()
        print("exit code", code)
    end)
    uv.read_start(Patchstderr, function(err, data)
        assert(not err, err)
        if data then
            randolog = randolog..data
          print("stderr chunk", data)
          print("chunk end")
        else
          print("stderr end")
        end
      end)
end

function CreatePlando(message)
    local plandostderr = uv.new_pipe(false)
    uv.spawn(Python, {
        stdio = {0, 1, plandostderr},
        cwd = Plandocwd,
        args = {"PlandoRandomSettings.py"},
    }, function(code) -- exit function
        if code == 0 then
            coroutine.wrap(function()
                message:reply("Settings file generated\nStarting randomizer")
            end)()
            CreatePatch(message)
        end
    end)

    uv.read_start(plandostderr, function(err, data)
        assert(not err, err)
        if data then
          print("stderr chunk", data)
          print("chunk end")
        else
          print("stderr end")
        end
      end)
end


Mootr.test = {help = "asd",
    f = function(message)
        Mootr.generate.f(message, true)
        message:reply("Weightsfile generated\nStarting settings file")
        CreatePlando(message)
        --CreatePatch(message)
    end
}


Mootr.setpublic = {help = "Sets the channel for public messages",
    f = function(message, arg)
        local Settings = SettingsExists(message)
        Settings.public = arg
        message:addReaction("👍")
        Save()
    end
}

Mootr.includemessage = {help = "Include an ignored message.",
    f = function(message, arg)
        local Settings = SettingsExists(message)
        Settings.ignore = Settings.ignore or {}
        Settings.ignore[arg] = nil
        message:addReaction("👍")
        ClearMessages(10000,message)
        Save()
    end
}

Mootr.ignoremessage = {help = "Ignores votes on the entered message id's. Example instructions",
    f = function(message, arg)

        local Settings = SettingsExists(message)
        Settings.ignore = Settings.ignore or {}
        Settings.ignore[arg] = true
        message:addReaction("👍")
        ClearMessages(10000,message)
        Save()
    end
}

Mootr.setvotechannel = {help = "Sets the current channel as voting channel",
    f = function(message, arg)
        local Settings = SettingsExists(message)
        Settings.channel = arg or message.channel.id
        message:addReaction("👍")
        ClearMessages(10000,message)
        Save()
    end
}


local function AwaitReaction(reply)
    local _,reaction = client:waitFor("reactionAdd",nil,function(reaction)
        if reaction.message == reply then
            return true
        end
    end)
    return reaction.emojiId or reaction.emojiName, reaction.emojiName
end

Mootr.ping = {help = "pong",
    f = function(message)
    message:reply("pong!")
    end
}

Mootr.publish = {help = "Publish the seed to the public channel",
    f = function(message)
        local Settings = SettingsExists(message)
        if not(Settings) or (Settings and not(Settings.public)) then
            return message:reply("You need to set a public channel")
        end
        message.guild:getChannel(Settings.public):send {
            file = SeedFolder..Seeds[#Seeds]..".zpf"
        }
    end
}

Mootr.sneaky = {help = "Sends a PM with the latest generated seed",
    f = function(message)
        message.member:send {
            file = SeedFolder..Seeds[#Seeds]..".zpf"
        }
    end
}

Mootr.raceroom = {help = "Set the raceroom for automatic spoiler log posting",
    f = function(message, arg)
        local Settings = SettingsExists(message)
        if not(Settings) or (not(Settings) and not(Settings.public)) then
            return message:reply("You need to set a public channel")
        end
        message:addReaction("👀")
        print(arg)
        local options = WS.parseUrl("wss://racetime.gg/ws/race/"..arg)
        p(options)
        coroutine.wrap(function()
            local res, read, write = WS.connect(options)
            for Data in read do
                if Data.opcode == 9 then
                    print(os.date(), "ping")
                else
                    local data = json.decode(Data.payload)
                    if data.type == "race.data" then
                        print(os.date(), "data")
                        if data.race.status.value == "finished" then
                            print("KLAR!!!")
                            local file = SeedFolder..Seeds[#Seeds].."_Spoiler.json"
                            message.guild:getChannel(Settings.public):send {
                                content = "Race is now finished.\nHere is the spoiler log:",
                                file = file
                            }
                            write()
                        end
                    end
                end
            end
            print("Race ENDED")
        end)()
    end
}

Mootr.setemotes = {help = "Set the emotes used for voting.",
    f = function(message)

        local Settings = SettingsExists(message)
        local intro = message:reply(
        [[Hi!
        React to the following messages to set the emojis to vote with
        Note the bot needs to have acess to the emojis]])
        local reply1 = message:reply("Yes.")
        Settings.Yes, Settings.YesName = AwaitReaction(reply1)
        local reply2 = message:reply("No")
        Settings.No, Settings.NoName = AwaitReaction(reply2)
        local reply3 = message:reply("Force Yes")
        Settings.FY, Settings.FYName = AwaitReaction(reply3)
        local reply4 = message:reply("Force No")
        Settings.FN, Settings.FNName = AwaitReaction(reply4)
       --[[ local sneaky = message:reply("sneaky yes emoji")
        Settings.SY = AwaitReaction(sneaky)
        sneaky:delete()
        sneaky = message:reply("sneaky no emoji")
        Settings.SN = AwaitReaction(sneaky)
        sneaky:delete()]]
        Save()
        timer.sleep(10000)
        message.channel:bulkDelete({message.id, intro.id, reply1.id, reply2.id, reply3.id, reply4.id})
    end
}

Mootr.getemotes = {help = "Show what emotes are used",
    f = function(message)
        local Settings = SettingsExists(message)
        local Msg = "Yes: %s, No: %s, Force Yes: %s, Force No: %s"
        message.member:send(Msg:format(Settings.YesName, Settings.NoName, Settings.FYName, Settings.FNName))
        message:delete()
    end
}

local Banned = [[Hi!
The allmighty Mimms has banned ``%s`` this week.
Your vote has been removed to show this.
Feel free to vote on another setting.
And remember to stay cute!
]]

local function ClearReactions(Reaction, Setting)
    for _,member in pairs(Reaction:getUsers()) do
        Reaction:delete(member.id)
        print("Remove")
        if not(member.bot) then
            print("Message")
            member:send(Banned:format(Setting))
        end
    end
end

local Reactionfunction = client:on("reactionAdd", function(reaction)
    local Settings = SettingsExists(reaction.message.channel)
    if reaction.emojiId == Settings.FN or reaction.emojiName == Settings.FN or reaction.emojiId == Settings.FY or reaction.emojiName == Settings.FY then
        local message = reaction.message
        if Settings.channel == message.channel.id then
            for _,Reaction in pairs(reaction.message.reactions) do
                if reaction ~= Reaction then
                    ClearReactions(Reaction, message.content)
                end
            end
        end
    end
end)

local Reactionfunction2 = client:on("reactionAddUncached", function(channel, messageId, hash)
    local Settings = SettingsExists(channel)
        if Settings.channel == channel.id then
            if hash == Settings.FN or hash == Settings.FY then
                local message = channel:getMessage(messageId)
                for _,Reaction in pairs(message.reactions) do
                    if hash ~= Reaction.emojiId and hash ~= Reaction.emojiName then
                        ClearReactions(Reaction, message.content)
                    end
                end
            end
        end
end)

local Reactionfunction3 = client:on("reactionRemove", function(reaction,_)
    local Settings = SettingsExists(reaction.message.channel)
    if reaction.emojiId == Settings.FN or reaction.emojiName == Settings.FN or reaction.emojiId == Settings.FY or reaction.emojiName == Settings.FY then
        local Message = reaction.message
        if not(Settings.ignore[Message.id]) then
            Message:addReaction(ResolveEmoji(Message, Settings.Yes))
            Message:addReaction(ResolveEmoji(Message, Settings.No))
        end
    end
end)

local Reactionfunction4 = client:on("reactionRemoveUncached", function(channel, messageId, hash, userid)
    local Settings = SettingsExists(channel)
    if Settings.channel == channel.id then
        if hash == Settings.FN or hash == Settings.FY then
            local message = channel:getMessage(messageId)
            message:addReaction(ResolveEmoji(message, Settings.Yes))
            message:addReaction(ResolveEmoji(message, Settings.No))
        end
    end
end)

local StreamStatus = {}

local precencefunc = client:on("presenceUpdate", function(member)
	--print("-------------")
	--print(member.name, member.tag)
    --print(member.status)
    if true then return end
    local act = member.activity
    if act then
		--print(member.activity.type)
        if act.type == 1 then
            if not(StreamStatus[member.tag]) then
                log:send(member.name.." is streaming")
               --print(act.url)
               --print(act.details)
                --print(act.name)
                StreamStatus[member.tag] = true
            end
        else
            if StreamStatus[member.tag] then
               StreamStatus[member.tag] = nil
               log:send(member.name.." is NOT streaming")
            end
        end
    else
        if StreamStatus[member.tag] then
            StreamStatus[member.tag] = nil
            log:send(member.name.." is NOT streaming")
         end
	end
end)


local Unloader = { function()
        client:removeListener("reactionAdd",Reactionfunction)
        client:removeListener("reactionAddUncached",Reactionfunction2)
        client:removeListener("reactionRemove",Reactionfunction3)
        client:removeListener("reactionRemoveUncached",Reactionfunction4)
        client:removeListener("presenceUpdate",precencefunc)
    end
}

local Whitelist = {
    "390913554657837066", --Admin
    "433347376468590592", --Twitch Mod
    "697070228529479711"  --Discord Mod
}

local  Perm = {}

function Perm.Check(message)
    print("Checkperm")
    if message.member.id == "279970636284035073" then --Nagi
        return true
    end
    for _,v in pairs(Whitelist) do
        if message.member:hasRole(v) then
            return true
        end
    end
    return "You don't have permission to do this command"
end



return Mootr, nil, nil, Unloader, Perm