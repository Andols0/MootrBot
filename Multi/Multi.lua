local Multi = { help = "A tool for combining multiworld plando files."}
local fs = require("fs")
local json = require("json")
local Logs = json.decode(fs.readFileSync("./Multi/Logs.json")) or {}
local tinsert = table.insert
local http = require("coro-http")
math.randomseed(os.time())

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

local function Char()
    return string.char(math.random(48,122))
end

local function Save()
    fs.writeFileSync("./Multi/Logs.json", json.encode(Logs,{indent = true}))
end

local Ignored = {
    world_count = true,
    create_spoiler = true,
    triforce_hunt = true,
    all_reachable = true,
    triforce_goal_per_world = true,
    reachable_locations = true,
    misc_hints = true --Not used on the generator branch
}

local AllowedHintDists = {
    balanced = true,
    bingo = true,
    scrubs = true,
    strong = true,
    tournament = true,
    tournament_s3 = true,
    useless = true,
    very_strong = true
}

local NoRoman = [[
Non roman branch detected. Assuming following settings.
Mix entrance pools = off
Decouple Entrances = off
]]
local ToOld = [[
Error
Spoiler log needs to be generated with randomizer version 6 or later.
]]
local ToNew = [[
Warning
This log is generated with a newer version of the randomizer (this script was last updated for 6.2.1).
All settings might not be supported.
]]
local GBKCOMPAT = [[
Ganons bosskey will be on LACS with the specified amount of rewards needed.
]]
local CTMC = [[
Correct chest textures not added to this version of rando.
Changing to Correct chest SIZE instead.
]]
local Compats = [[
The individual branch is version 6.0.12
I have tried to find tricks/settings name changes and implemented those.
Not sure if i found them all.
]]
local BadHint = [[
ERROR
The specified hint distribution <%s> is not possible with this version of the randomizer.
Please use one of the below:
balanced
bingo
scrubs
strong
tournament   (Season 4)
tournament_s3
useless
very_strong
]]
local HintInfo = [[
---------------------------------------
FOR YOUR INFORMATION!!
You have specified season 5 hints but this version of the randomizer is to old for that.
Unless you manualy edit the final plando file to one of the supported dists below the hints will be Season 4.
Supported hints:
balanced
bingo
scrubs
strong
tournament   (Season 4)
tournament_s3
useless
very_strong
-----------------------------------
]]

local RenamedTricks = {
    ["Child Deadhand without Kokiri Sword"] = "Child Dead Hand without Kokiri Sword",
    ['Gerudo Fortress "Kitchen" with No Additional Items'] = 'Thieves\' Hideout "Kitchen" with No Additional Items',
    ["Gerudo Training Grounds MQ Left Side Silver Rupees with Hookshot"] = "Gerudo Training Ground MQ Left Side Silver Rupees with Hookshot",
    ["Gerudo Training Grounds Left Side Silver Rupees without Hookshot"] = "Gerudo Training Ground Left Side Silver Rupees without Hookshot",
    ["Gerudo Training Grounds MQ Left Side Silver Rupees without Hookshot"] = "Gerudo Training Ground MQ Left Side Silver Rupees without Hookshot",
    ["Reach Gerudo Training Grounds Fake Wall Ledge with Hover Boots"] = "Reach Gerudo Training Ground Fake Wall Ledge with Hover Boots",
    ["Gerudo Training Grounds MQ without Lens of Truth"] = "Gerudo Training Ground MQ without Lens of Truth",
    ["Gerudo Training Grounds without Lens of Truth"] = "Gerudo Training Ground without Lens of Truth",
}

local RenamedSettings = {  --Settings that are renamed without any functional change
    shuffle_fortresskeys = "shuffle_hideoutkeys",
}

local function LoadSpoiler(Data, ID, message)
    local Log = Logs[ID]
    local settings = {}
    local tricks = {}
    local disabled = {}
    local items = {}
    local songs = {}
    local equipment = {}
    local Major, Minor, Build, Name = Data[":version"]:match("(%d*)%.(%d*)%.(%d*)%s(.*)")
    Major, Minor, Build = tonumber(Major), tonumber(Minor), tonumber(Build)
    if Major < 6 then
        return false, message:reply(ToOld)
    elseif Major == 6 and Minor > 2 or (Minor == 2 and Build > 1) then
        message:reply(ToNew)
    elseif Major == 6 and Minor > 0 or Build > 90 then
        message:reply(Compats)
    end
    if not Name:find("R%-") then
        message:reply(NoRoman)
        Data.settings.mix_entrance_pools = "off"
        Data.settings.decouple_entrances = false
    end
    if not(AllowedHintDists[Data.settings.hint_dist]) then
        return false, message:reply(BadHint:format(Data.settings.hint_dist))
    end
    if Major == 6 and Minor >=1 and Data.settings.hint_dist == "tournament" then
        message:reply(HintInfo)
    end

    --Simple renamings
    --Tricks
    for i, trick in ipairs(Data.settings.allowed_tricks) do
        if RenamedTricks[trick] then
            Data.settings.allowed_tricks[i] = RenamedTricks[trick]
        end
    end
    --Settings
    for i, trick in ipairs(Data.settings) do
        if RenamedSettings[trick] then
            Data.settings[i] = RenamedSettings[trick]
        end
    end

    --Ganons Boss key stuff
    if Data.settings.shuffle_ganon_bosskey == "on_lacs" then --Compat in a settings name change.
        local lacs_condition = Data.settings.lacs_condition
        if lacs_condition == "vanilla" then
            Data.settings.shuffle_ganon_bosskey = "lacs_vanilla"
        elseif lacs_condition == "stones" then
            Data.settings.shuffle_ganon_bosskey = "lacs_stones"
        elseif lacs_condition == "medallions" then
            Data.settings.shuffle_ganon_bosskey = "lacs_medallions"
        elseif lacs_condition == "dungeons" then
            Data.settings.shuffle_ganon_bosskey = "lacs_dungeons"
        elseif lacs_condition == "tokens" then
            Data.settings.shuffle_ganon_bosskey = "lacs_tokens"
        end
    end
    Data.settings.lacs_condition = nil

    if Data.settings.shuffle_ganon_bosskey == "stones" then
        Data.settings.shuffle_ganon_bosskey = "lacs_stones"
        Data.settings.lacs_stones = Data.settings.ganon_bosskey_stones
        Data.settings.ganon_bosskey_stones = nil
        message:reply(GBKCOMPAT)
    elseif Data.settings.shuffle_ganon_bosskey == "medallions" then
        Data.settings.shuffle_ganon_bosskey = "lacs_medallions"
        Data.settings.lacs_medallions = Data.settings.ganon_bosskey_medallions
        Data.settings.ganon_bosskey_medallions = nil
        message:reply(GBKCOMPAT)
    elseif Data.settings.shuffle_ganon_bosskey "dungeons" then
        Data.settings.shuffle_ganon_bosskey = "lacs_dungeons"
        Data.settings.lacs_dungeons = Data.settings.ganon_bosskey_rewards
        Data.settings.ganon_bosskey_rewards = nil
        message:reply(GBKCOMPAT)
    elseif Data.settings.shuffle_ganon_bosskey "tokens" then
        Data.settings.shuffle_ganon_bosskey = "lacs_tokens"
        Data.settings.lacs_tokens = Data.settings.ganon_bosskey_tokens
        Data.settings.ganon_bosskey_tokens = nil
        message:reply(GBKCOMPAT)
    end

    --CTMC does not work.
    if Data.settings.correct_chest_appearances then
        if Data.settings.correct_chest_appearances ~= "off" then
            Data.settings.correct_chest_sizes = true
            message:reply(CTMC)
        else
            Data.settings.correct_chest_sizes = false
        end
        Data.settings.correct_chest_appearances = nil
    end

    for k,v in pairs(Data.settings) do
        if k == "disabled_locations" then
            for _, location in ipairs(v) do
                disabled[location] = true
            end
        elseif k == "allowed_tricks" then
            for _, trick in ipairs(v) do
                tricks[trick] = true
            end
        elseif k == "starting_equipment" then
            for _, item in ipairs(v) do
                equipment[item] = true
            end
        elseif k == "starting_items" then
            for _, item in ipairs(v) do
                items[item] = true
            end
        elseif k == "starting_songs" then
            for _, song in ipairs(v) do
                songs[song] = true
            end
        elseif not Ignored[k] then
            settings[k] = v
        end
    end
    tinsert(Log.Settings,settings)
    tinsert(Log.Tricks,tricks)
    tinsert(Log.Disabled,disabled)
    tinsert(Log.Items,items)
    tinsert(Log.Songs,songs)
    tinsert(Log.Equipment,equipment)
    return true, #Log.Settings
end

local function BuildCommon(NameOfStuff)
    local Common = {}
    for _ ,v in pairs(NameOfStuff) do
        for setting, data in pairs(v) do
            if not(Common[setting]) then
                Common[setting] = {}
                Common[setting][data] = 0
            elseif not Common[setting][data] then
                Common[setting][data] = 0
            end
            Common[setting][data] = Common[setting][data] + 1
        end
    end
    local CommonSettings = {}
    for setting, v in pairs(Common) do
        for value, num in pairs(v) do
            if num == #NameOfStuff then
                CommonSettings[setting] = value
            end
        end
    end
    return CommonSettings
end

local function BuildCategory(Settings, Tolist)
    local Common = BuildCommon(Settings)
    local Output = {}

    for WorldNum = 1, #Settings do
        Output["World "..WorldNum] = {}
        local World = Output["World "..WorldNum]
        for Setting, value in pairs(Settings[WorldNum]) do
            if Common[Setting] == nil then
                if Tolist then
                    tinsert(World, Setting)
                else
                    World[Setting] = value
                end
            end
        end
    end
    if Tolist then
        local Temp = {}
        for k, _ in pairs(Common) do
            tinsert(Temp, k)
        end
        Common = Temp
    end
    return Output, Common
end



Multi.finishmulti = { help = "Finalizes the plandofile",
    f = function (message, arg)
        local Plandofile = {}
        local Log = Logs[arg]
        if not Log then
            return message:reply("Error could not find ID")
        end
        --Settings
        local world_settings, settings = BuildCategory(Log.Settings)
        Plandofile.world_settings = world_settings
        Plandofile.settings = settings
        --Tricks
        local world_tricks, common_tricks = BuildCategory(Log.Tricks, true)
        for i = 1, #Log.Settings do
            print("World".. i, "Tricks", #world_tricks["World "..i])
            if #world_tricks["World "..i] > 0 then
                Plandofile.world_settings["World "..i].allowed_tricks = world_tricks["World "..i]
            end
        end
        Plandofile.settings.allowed_tricks = common_tricks
        --Disabled locations
        local world_disabled, common_disabled = BuildCategory(Log.Disabled, true)
        for i = 1, #Log.Settings do
            print("World".. i, "world_disabled", #world_disabled["World "..i])
            if #world_disabled["World "..i] > 0 then
                Plandofile.world_settings["World "..i].disabled_locations = world_disabled["World "..i]
            end
        end
        Plandofile.settings.disabled_locations = common_disabled
        --Items

        local world_items, common_items = BuildCategory(Log.Items, true)
        for _, v in pairs(common_items) do
            world_items[v] = true
        end
        Plandofile.settings.starting_items = world_items

        local world_songs, common_songs = BuildCategory(Log.Songs, true)
        for _, v in pairs(common_songs) do
            world_songs[v] = true
        end
        Plandofile.settings.starting_songs = world_songs

        local world_equipment, common_equipment = BuildCategory(Log.Equipment, true)
        for _, v in pairs(common_equipment) do
            world_equipment[v] = true
        end
        Plandofile.settings.starting_equipment = world_equipment

        message:reply {
            content = "Here is your plandofile enjoy",
            file = {"plandofile.json", json.encode(Plandofile,{indent = true})}
        }
    end
}

local Startmessage = [[Multiworld initiated.
To load a spoiler log send it in a ~~DM or~~ textchannel with the message
½loadspoiler %s
Use ½finishmulti %s to finalize]]
Multi.startmulti = { help = "Initiate a multiworld",
    f = function(message)
        local string
        while not(Logs[string]) do
            string = Char()..Char()..Char()..Char()..Char()..Char()..Char()
            if not(Logs[string]) then
                Logs[string] = {
                    Settings = {},
                    Tricks = {},
                    Disabled = {},
                    Items = {},
                    Songs = {},
                    Equipment = {}
                }
            end
        end
        if message then
            message:reply(Startmessage:format(string, string))
        else
            print(Startmessage:format(string))
        end
        Save()
    end
}

Multi.loadspoiler = { help = "Load in a spoiler.",
    f = function(message, arg)
        if not message.attachment then
            return message:reply("Error no spoiler log found")
        elseif not Logs[arg] then
            return message:reply("Error, ID not found")
        end
        local _, body = http.request("GET",message.attachment.url)
        local Data = json.decode(body)
        Data.settings.USER = message.author.name
        local success, worldnum = LoadSpoiler(Data, arg, message)
        if success then
            message:reply("Spoiler log loaded for world "..worldnum)
            Save()
        end
    end
}





local Unloader = { function()
    return true
end
}
local Perm = {}

function Perm.Check()
    return true
end

return Multi, nil, nil, Unloader, Perm