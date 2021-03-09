local fs = require("fs")
local json = require("json")
local Mootr = {help = "It's MOOTR ZOOTR"}
local timer = require('timer')
local Mootrsettings = json.decode(fs.readFileSync("./Mootr/settings.json")) or {}
local Seeds = json.decode(fs.readFileSync("./Mootr/seeds.json")) or {Seed = {}, Info = {}}
local uv = require("uv")
local WS = require("coro-websocket")
local Windows = package.config:sub(1,1)=="\\"
local discordia = require("discordia")

local CreatePlando, gd

local Weights, Constants = dofile("./Mootr/Weights.lua")
local Plandocwd, Patchcwd, RandoRando, Python, SeedFolder, Hashfile, Root, Icons

do --Set some paths
    if Windows then
        Root = "F:/Dropbox/Lua/Mootr/"
        Python = "python"
    else --Linux (Raspberry)
        gd = require("gd")
        Root = "/home/pi/Desktop/Mootr/"
        Python = "python3.6"
    end

    Plandocwd = Root.."Rando/OoT-Randomizer/plando-random-settings"
    Patchcwd = Root.."Rando/OoT-Randomizer"
    RandoRando = Root.."Rando/OoT-Randomizer/plando-random-settings/weights/MOoTR.json"
    SeedFolder = Root.."Rando/Seeds/"
    Hashfile = Root.."Rando/Hash.png"
    Icons = Root.."Mootr/Images/"
end

local function SettingsExists(message)
    if not Mootrsettings[message.guild.id] then
        Mootrsettings[message.guild.id] = { ignore = {} }
    end
    return Mootrsettings[message.guild.id]
end

local Deep = 0
local Tab = "\t" --debug function
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
    local Weight = {}
    local Name, Weighing
    print("CONVERT")
    for k,v in pairs(Votes) do
        --print(k)
        if Weights[k] then
            Name, Weighing = Weights[k]:f(v)
            if type(Name) == "string" then
                Weight[Name] = Weighing
            else
                for name,weighing in pairs(Name) do
                    Weight[name] = weighing
                end
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
                Message:clearReactions()
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
    end
}
Mootr.generate = {help = "Generates the MoOTR seed",
    f = function(message)
        local Info = Mootr.weight.f(message)
        message:reply("Weightsfile generated\nStarting settings file")
        CreatePlando(message, Info)
    end
}

Mootr.weight = {help = "Generates the weights file",
    f = function(message, SkipPost)
        local Settings = Mootrsettings[message.guild.id]
        if not(Settings) or (not(Settings) and not(Settings.channel)) then
            message:reply("You need to set the voting channel")
        end
        local Channel = client:getChannel(Settings.channel)
        local Messages = Channel:getMessages()
        local Votes = {}
        local Info = {Yes = 0, No = 0, Max = 0, Cat = ""}
        print("READ VOTES")
        for _, Message in pairs(Messages) do
            if not(Settings.ignore[Message.id]) and not(Message == message) then
                local SettingName = Message.content:match("__%*%*(.-)%*%*__") or Message.content:match("%*%*__(.-)__%*%*") or Message.content
                Votes[SettingName] = {Yes = 0, No = 0, Tot = 0}
                --print(SettingName)
                local Rule = Votes[SettingName]
                for _,v in pairs(Message.reactions) do
                    if v.emojiId == Settings.Yes or v.emojiName == Settings.Yes then
                        Info.Yes = Info.Yes + v.count - 1
                        Rule.Yes = Rule.Yes + v.count
                        Rule.Tot = Rule.Tot + v.count
                    elseif v.emojiId == Settings.No or v.emojiName == Settings.No then
                        Info.No = Info.No + v.count - 1
                        Rule.No = Rule.No + v.count
                        Rule.Tot = Rule.Tot + v.count
                    elseif (v.emojiId == Settings.FY or v.emojiName == Settings.FY) and not(Rule.ForceYes) then
                        Rule.ForceYes = true
                    elseif (v.emojiId == Settings.FN or v.emojiName == Settings.FN) and not(Rule.ForceNo) then
                        Rule.ForceNo = true
                    end
                end
                if Info.Max < Rule.Yes  + Rule.No - 2 then
                    Info.Max = Rule.Yes - 1 + Rule.No -1
                    Info.Cat = SettingName
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
        if not SkipPost then
            message:reply {
                file = {"weights.json",(json.encode(ConvertedWeights)) }
            }
        end
        fs.writeFileSync(RandoRando, json.encode(ConvertedWeights))
        return Info
   end
}


local function CreatePatch(message, Info)
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
                table.insert(Seeds.Seed,file)
                Info.Roller = message.member.name
                Seeds.Info[file] = Info
                SaveSeeds()
                local Filepath = SeedFolder..file..".zpf"
                --print(Filepath)
                message.member:send{
                    file = Filepath
                }
                message:reply("Seed generated and sent. You can also use ½publish to send it to the public channel.")
            end)()
        else
            coroutine.wrap(function()
                message.member:send("Gen FAILED tell Andols")
            end)()
            --if randolog:match(".*(junk).*") then
                --print("HEEEJ") --Add triforcehunt stuff here
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

function CreatePlando(message, Info)
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
            CreatePatch(message, Info)
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

local Publishtemplate = {
        title = "Todays patch file!",
        description = "Have fun and MoOTR safely?",
        color = 9637520,
        timestamp = "2021-01-07T10:03:14.328Z",
        footer = {
            icon_url = "https://static-cdn.jtvnw.net/jtv_user_pictures/ca0e1fe6-0a2d-4a53-a118-bae6505bb3d4-profile_image-70x70.png",
            text = "Mootr On"
        },
        fields = {
            {
                name = "Rolled by:",
                value = "Testrunner",
            },
            {
                name = "Number of votes",
                value = 5,
                inline = true
            },
            {
                name = "Yes",
                value = "6",
                inline = true
            },
            {
                name = "No",
                value = 5,
                inline = true
            },
            {
                name = "Most voted category",
                value = "Keysanity"
            }
        },
        image = { url = "attachment://Hash.png"},
    }


Mootr.test = {help = "asd",
    f = function()
    end
}


Mootr.setpublic = {help = "Sets the channel for public messages",
    f = function(message, arg)
        local Settings = SettingsExists(message)
        Settings.public = message.mentionedChannels.first.id or arg
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
        --print("Start publish")
        local Settings = SettingsExists(message)
        if not(Settings) or (Settings and not(Settings.public)) then
            return message:reply("You need to set a public channel")
        end
        local Seed = Seeds.Seed[#Seeds.Seed]
        local Hash = json.decode(fs.readFileSync(SeedFolder..Seed.."_Spoiler.json")).file_hash
        --p("Hash", Hash)
        local Info = Seeds.Info[Seed]
        if Windows then --The graphic library can't load into this enviroment on windows so do this in a separate file.
            local command = 'F:\\Dropbox\\Lua\\Mootr\\Mootr\\Image.lua "%s" "%s" "%s" "%s" "%s"'
            os.execute(command:format(Hash[1], Hash[2], Hash[3], Hash[4], Hash[5]))
        else
            local image = gd.createFromPng(Icons.."Background.png")
            local Hash1 = gd.createFromPng(Icons..Hash[1]..".png")
            local Hash2 = gd.createFromPng(Icons..Hash[2]..".png")
            local Hash3 = gd.createFromPng(Icons..Hash[3]..".png")
            local Hash4 = gd.createFromPng(Icons..Hash[4]..".png")
            local Hash5 = gd.createFromPng(Icons..Hash[5]..".png")
            image:copy(Hash1,8, 3, 0, 0, 64, 64)
            image:copy(Hash2, 88, 3, 0, 0, 64, 64)
            image:copy(Hash3, 168, 3, 0, 0, 64, 64)
            image:copy(Hash4, 248, 3, 0, 0, 64, 64)
            image:copy(Hash5, 322, 3, 0, 0, 64, 64)
            image:png(Hashfile,100)
        end
        --print("Created image")
        Publishtemplate.timestamp = discordia.Date():toISO('T', 'Z')
        Publishtemplate.fields[1].value = Info.Roller
        Publishtemplate.fields[2].value = Info.Yes + Info.No
        Publishtemplate.fields[3].value = Info.Yes
        Publishtemplate.fields[4].value = Info.No
        Publishtemplate.fields[5].value = Info.Cat
        --print("Filled template")
        message.guild:getChannel(Settings.public):send {
            embed = Publishtemplate,
            files = {
                SeedFolder..Seed..".zpf",
                Hashfile
            }
        }
        --print("Message sent")
    end
}

Mootr.sneaky = {help = "Sends a PM with the latest generated seed",
    f = function(message)
        message.member:send {
            file = SeedFolder..Seeds.Seed[#Seeds.Seed]..".zpf"
        }
    end
}

local function RacetimeSocket(message,options, Seed, Settings)
    print("Connecting to WS")
    local _, read, write = WS.connect(options)
    local Done = false
    for Data in read do
        if Data.opcode == 1 then
            local data = json.decode(Data.payload)
            if data.type == "race.data" then
                if data.race.status.value == "finished" then
                    Done = true
                    print("Race finished, posting seed")
                    local file = SeedFolder..Seed.."_Spoiler.json"
                    message.guild:getChannel(Settings.public):send {
                        content = "Race is now finished.\nHere is the spoiler log:",
                        file = file
                    }
                    write()
                end
            end
        end
    end
    if not Done then
        print("Reconnecting WS")
        return RacetimeSocket(message,options, Seed) --DC (i hope) reconnect.
    end

end

Mootr.raceroom = {help = "Set the raceroom for automatic spoiler log posting",
    f = function(message, arg)
        local Settings = SettingsExists(message)
        if not(Settings) or (not(Settings) and not(Settings.public)) then
            return message:reply("You need to set a public channel")
        end
        message:addReaction("👀")
        local options = WS.parseUrl("wss://racetime.gg/ws/race/"..arg)
        coroutine.wrap(RacetimeSocket)(message, options, Seeds.Seed[#Seeds.Seed], Settings)
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

local Reactionfunction4 = client:on("reactionRemoveUncached", function(channel, messageId, hash)
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

function Perm.Check(message, cmd)
    print("Checkperm")
    if cmd == "ping" then
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