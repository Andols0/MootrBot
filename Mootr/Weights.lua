local Bridgeweights = {
    Num = 0
}
local function Bridge(self, votes)
    local type = self.type
    if Bridgeweights.Num == 5 or Bridgeweights.Num == 0 then
        Bridgeweights.votes = {
            open = 0.5,
            vanilla = 0.5,
            stones = 0.5,
            medallions = 0.5,
            dungeons = 0.5
        }
        Bridgeweights.Num = 0
        Bridgeweights.Force = false
    end
    Bridgeweights.votes = Bridgeweights.votes or { open = 0.5, vanilla = 0.5, stones = 0.5, medallions = 0.5, dungeons = 0.5}
    local Vote = Bridgeweights.votes
    if votes.ForceYes or (votes.Yes - votes.No >= 5) then
        for k,_ in pairs(Vote) do
            if k ~= type then
                Vote[k] = 0
            end
        end
        Bridgeweights.Force = true
    elseif votes.ForceNo or (votes.No - votes.Yes >= 5) then
        Vote[type] = 0
    elseif not(Bridgeweights.Force) then
        local Score = votes.Yes - votes.No
        if Score > 0 then
            Vote[type] = Score
        end
    end

    local Tot = 0
    for _,v in pairs(Vote) do
        Tot = Tot + v
    end
    local Bridges = {
        open = Vote.open/Tot*100,
        vanilla = Vote.vanilla/Tot*100,
        stones = Vote.stones/Tot*100,
        medallions = Vote.medallions/Tot*100,
        dungeons = Vote.dungeons/Tot*100,
        tokens = 0
    }
    Bridgeweights.Num = Bridgeweights.Num + 1
    return "bridge", Bridges
end

local Keyweights = {
    Num = 0,
}

local function Keys(self, votes)
    local type = self.type
    local Keyes
    if Keyweights.Num == 2 or Keyweights.Num == 0 then
        Keyweights.votes =  {
            SyYes = 0,
            SyNo = 0,
            SanYes = 0,
            SanNo = 0
        }
        Keyweights.Num = 0
    end
    local Vot = Keyweights.votes
    if type == "Sanity" then
        Vot.SanYes = votes.Yes
        Vot.SanNo = votes.No
        if votes.ForceYes then
            Vot.SanY = true
        elseif votes.ForceNo then
            Vot.SanN = true
        end
    elseif type == "Keysy" then
        Vot.SyYes = votes.Yes
        Vot.SyNo = votes.No
        if votes.ForceYes then
            Vot.SyY = true
        elseif votes.ForceNo then
            Vot.SyN = true
        end
    end

    if Keyweights.Num == 1 then
        if Vot.SyYes - Vot.SyNo >= 5 or Vot.SyY then
            Keyes = {
                vanilla = 0,
                keysanity = 0,
                dungeon = 0,
                remove = 100
            }
        elseif Vot.SanYes - Vot.SanNo >= 5 or Vot.SanY then
            Keyes = {
                vanilla = 0,
                keysanity = 100,
                dungeon = 0,
                remove = 0
            }
        else
            local Mix = Vot.SanNo + Vot.SyNo
            local SanYes = Vot.SyNo + Vot.SanYes
            local SyYes = Vot.SanNo + Vot.SyYes
            local Tot = (Mix + SanYes + SyYes)
            if Vot.SanN then
                Tot = Tot - Vot.SyNo
                SanYes = 0
            end
            if Vot.SyN then
                Tot = Tot - Vot.SanNo
                SyYes = 0
            end
            Keyes = {
                vanilla = Mix/Tot*100/2,
                keysanity = SanYes/Tot*100,
                dungeon = Mix/Tot*100/2,
                remove = SyYes/Tot*100,
                overworld = 0, --What to do?
                any_dungeon = 0 --What to do?
            }
        end
    end
    Keyweights.Num = Keyweights.Num + 1

    return "shuffle_smallkeys" , Keyes
end

local Ganonweights = {
    Num = 0,
}

local function GanonKey(self, votes)
    local type = self.type
    if Ganonweights.Num == 8 or Ganonweights.Num == 0  then
        Ganonweights.votes = {
            remove = 0.5,
            vanilla = 0.5,
            any_dungeon = 0.5,
            keysanity = 0.5,
            lacs_vanilla = 0.5,
            lacs_stones = 0.5,
            lacs_medallions = 0.5,
            lacs_dungeons = 0.5,
        }
        Ganonweights.Force = false
        Ganonweights.Num = 0
    end
    local Vote = Ganonweights.votes
    if votes.ForceYes or (votes.Yes - votes.No >= 5) then
        for k,_ in pairs(Vote) do
            if k ~= type then
                Vote[k] = 0
            end
        end
        Ganonweights.Force = true
    elseif votes.ForceNo or (votes.No - votes.Yes >= 5) then
        Vote[type] = 0
    elseif not(Ganonweights.Force) then
        local Score = votes.Yes - votes.No
        if Score > 0 then
            Vote[type] = Score
        end
    end

    local Tot = 0
    for _,v in pairs(Vote) do
        Tot = Tot + v
    end
    local GKey = {
        remove = Vote.remove/Tot*100,
        vanilla = Vote.vanilla/Tot*100,
        any_dungeon = Vote.any_dungeon/Tot*100,
        keysanity = Vote.keysanity/Tot*100,
        lacs_vanilla = Vote.lacs_vanilla/Tot*100,
        lacs_stones = Vote.lacs_stones/Tot*100,
        lacs_medallions = Vote.lacs_medallions/Tot*100,
        lacs_dungeons = Vote.lacs_dungeons/Tot*100,
        dungeon = 0,
        overworld = 0,
        lacs_tokens = 0,
    }

    Ganonweights.Num = Ganonweights.Num + 1
    if Ganonweights.Num == 8 then
        p(GKey)
    end
    return "shuffle_ganon_bosskey", GKey
end

local function VotesToWheight(votes)
    -- The return is Yes, No
    if votes.ForceYes then
        return 100, 0
    elseif votes.ForceNo then
        return 0, 100
    else
        if votes.Tot == 2 then
            return 50, 50
        else
            if votes.Yes - votes.No >= 5 then
                return 100, 0
            elseif votes.No - votes.Yes >= 5 then
                return 0, 100
            else
                local Yes = votes.Yes  / votes.Tot * 100
                local No = votes.No   / votes.Tot  * 100
                return Yes, No
            end
        end
    end
end

local function Multichoice(self, votes)
    local fixed = self.fixed or {}
    local options = self.options
    local default = self.def
    local Weights = {}
    local Yes, No = VotesToWheight(votes)
    Weights[default] = No
    local Splityes = Yes / (#options - 1)
    for i = 1, #options do
        local opt = options[i]
        if default ~= opt then
            Weights[opt] = Splityes
        end
    end
    for k,v in pairs(fixed) do
        Weights[k] = v
    end
    local Over = Yes > 70

   -- Weights.Yes = votes.Yes
   -- Weights.No = votes.No
    return self.name, Weights, Over
end

local function Multicat(self, votes)
    local Weights = {}
    local Yes, No = VotesToWheight(votes)
    for Name, data in pairs(self.categories) do  --Make the thing loop through Multichoice?
        Weights[Name] = {}
        local Cat = Weights[Name]
        local options = data.options
        local default = data.def
        local fixed = data.fixed or {}
        Cat[default] = No
        local Splityes = Yes / (#options - 1)
        for i = 1, #options do
            local opt = options[i]
            if default ~= opt then
                Cat[opt] = Splityes
            end
        end
        for k,v in pairs(fixed) do
            Cat[k] = v
        end
        --Cat.Yes = votes.Yes
        --Cat.No = votes.No

    end
    return Weights
end

local Weights = {
    ["Zora’s Fountain Open"] = {
        name = "zora_fountain",
        def = "closed",
        options = {
            "closed",
            "adult",
            "open",
        },
        f = Multichoice
    },
    ["Gerudo Fortress Open or 4 carpenters"] = {
        name = "gerudo_fortress",
        options = {
            "normal",
            "fast",
            "open",
        },
        def = "fast",
        f = Multichoice
    },
    ["Closed Forest/Deku"] = {
        name = "open_forest",
        options = {
            "open",
            "closed_deku",
            "closed"
        },
        def = "open",
        f = Multichoice
    },
    ["Closed Door Of Time"] = {
        name = "open_door_of_time",
        options = {
            "true",
            "false",
        },
        def = "true",
        f = Multichoice
    },
    ["Ganon’s Trial #"] = {
        name = "trials",
        options = {
            0,
            1,
            2,
            3,
            4,
            5,
            6,
        },
        def = 0,
        f = Multichoice
    },
    ["Starting Age"] = {
        name = "starting_age",
        options = {
            "child",
            "random",
        },
        fixed = {
            adult = 0
        },
        def = "child",
        f = Multichoice
    },
    ["Dungeon Entrance Shuffle"] = {
        name = "shuffle_dungeon_entrances",
        options = {
            "true",
            "false",
        },
        def = "false",
        f = Multichoice
    },
    ["Triforce Hunt"] = {
        name = "triforce_hunt",
        options = {
            "true",
            "false"
        },
        def = "false",
        f = Multichoice
    },
    ["Shopsanity"] = {
        name = "shopsanity",
        options = {
            "off",
            0,
            1,
            2,
            3,
            4,
            "random",
        },
        def = "off",
        f = Multichoice
    },
    ["Tokensanity"] = {
        name = "tokensanity",
        options = {
            "off",
            "dungeons",
            "overworld",
            "all",
        },
        def = "off",
        f = Multichoice
    },
    ["Scrubsanity"] = {
        name = "shuffle_scrubs",
        options = {
            "off",
            "low",
        },
        def = "off",
        "regular",
        "random",
        f = Multichoice
    },
    ["Cowsanity"] = {
        name = "shuffle_cows",
        options = {
            "true",
            "false"
        },
        def = "false",
        f = Multichoice
    },
    ["Songsanity"] = {
        name = "shuffle_song_items",
        options = {
            "song",
            "any"
        },
        fixed = {
            dungeon = 0
        },
        def = "song",
        f = Multichoice
    },
    ["Static Items Shuffle (Ocarina, egg)"] = {
        categories = {
            shuffle_ocarinas =  {
                options = {
                    "true",
                    "false"
                },
                def = "false",

            },
            shuffle_weird_egg = {
                options = {
                    "true",
                    "false"
                },
                def = "false"
            },
            shuffle_kokiri_sword = {
                options = {
                    "true",
                    "false"
                },
                def = "true"
            },
            shuffle_gerudo_card = {
                options = {
                    "true",
                    "false"
                },
                def = "false"
            },
            shuffle_beans = {
                options = {
                    "true",
                    "false"
                },
                def = "false"
            },
        },
        f = Multicat
    },
    ["Maps & Compasses Could Be Added/Give Info"] = {
        categories = {
            enhance_map_compass = {
                options = {
                    "true",
                    "false"
                },
                def = "false"
            },
            shuffle_mapcompass = {
                options = {
                    "startwith",
                    "vanilla",
                    "dungeon",
                    "keysanity"
                },
                fixed = {
                    remove = 0,
                    overworld = 0, --What to do?
                    any_dungeon = 0, --What to do?
                },
                def = "startwith"
            },
        },
        f = Multicat
    },
    ["Small Key Sanity"] = {
        type = "Sanity",
        f = Keys
    },
    ["Small Keysy"] = {
        type = "Keysy",
        f = Keys
    },
    ["Add In Some/All/Few Cutscenes"] = {
        categories = {
            no_escape_sequence = {
                options = {
                    "true",
                    "false"
                },
                def = "true"
            },
            no_guard_stealth = {
                options = {
                    "true",
                    "false"
                },
                def = "true"
            },
            no_epona_race = {
                options = {
                    "true",
                    "false"
                },
                def = "true"
            },
            useful_cutscenes = {
                options = {
                    "true",
                    "false"
                },
                def = "false"
            },
        },
        f = Multicat
    },
    ["Starting With Extra Items"] = {
        categories = {
            start_with_consumables = {
                options = {
                    "true",
                    "false"
                },
                def = "false"
            },
            start_with_rupees = {
                options = {
                    "true",
                    "false"
                },
                def = "false"
            },
        },
        f = Multicat
    },
    ["Bombchus In Logic"] = {
        name = "bombchus_in_logic",
        options = {
            "true",
            "false"
        },
        def = "false",
        f = Multichoice
    },
    ["Different Hint Distributions (but limit to Tournament, Strong and Balanced)"] = {
        name = "hint_dist",
        options = {
            "strong",
            "very_strong",
            "scrubs",
            "tournament_s3"
        },
        fixed = {
            useless = 0,
            balanced = 0,
            bingo = 0,
            tournament = 0,
        },
        def = "scrubs",
        f = Multichoice
    },
    ["Chest Size Match Contents"] = {
        name = "correct_chest_sizes",
        options = {
            "true",
            "false"
        },
        def = "false",
        f = Multichoice
    },
    ["Damage Multiplier (limit to 0.5x, normal and 2x)"] = {
        name = "damage_multiplier",
        options = {
            "half",
            "normal",
            "double"
        },
        fixed = {
            quadruple = 0,
            ohko = 0
        },
        def = "normal",
        f = Multichoice
    },
    ["Random Warp Songs Locations"] = {
        name = "warp_songs",
        options = {
            "true",
            "false",
        },
        def = "false",
        f = Multichoice
    },
    ["Random Spawn"] = {
        name = "spawn_positions",
        options = {
            "true",
            "false"
        },
        def = "false",
        f = Multichoice
    },

    ["Rainbow Bridge Req : All Medallions"] = {
        type = "medallions",
        f =  Bridge
    },
    ["Rainbow Bridge Req : All Dungeons"] = {
        type = "dungeons",
        f = Bridge
    },
    ["Rainbow Bridge Req : All Stones"] = {
        type = "stones",
        f = Bridge
    },
    ["Rainbow Bridge Req : Open"] = {
        type = "open",
        f = Bridge
    },
    ["Rainbow Bridge Req : Vanilla"] = {
        type = "vanilla",
        f = Bridge
    },
    ["Medigoron/Carpet Salesmen Shuffled"] = {
        name = "shuffle_medigoron_carpet_salesman",
        options = {
            "true",
            "false",
        },
        def = "false",
        f = Multichoice
    },
    ["Boss Key Sanity"] = {
        name = "shuffle_bosskeys",
        options = {
            "dungeon",
            "keysanity"
        },
        fixed = {
            remove = 0,
            vanilla = 0, --What to do?
            overworld = 0, --What to do?
            any_dungeon = 0 --what to do?
        },
        def = "dungeon",
        f = Multichoice
    },
    ["Ganon Boss Key Removed (Open Door)"] = {
        type = "remove",
        f =  GanonKey
    },
    ["Ganon Boss Key In Vanilla location"] = {
        type = "vanilla",
        f = GanonKey
    },
    ["Ganon Boss Key In Keysanity (Dungeon)"] = {
        type = "any_dungeon",
        f = GanonKey
    },
    ["Ganon Boss Key In Keysanity (Everywhere)"] = {
        type = "keysanity",
        f = GanonKey
    },
    ["Ganon Boss Key On LACS: Vanilla"] = {
        type = "lacs_vanilla",
        f = GanonKey
    },
    ["Ganon Boss Key On LACS: Stones"] = {
        type = "lacs_stones",
        f =  GanonKey
    },
    ["Ganon Boss Key On LACS: Medallions"] = {
        type = "lacs_medallions",
        f = GanonKey
    },
    ["Ganon Boss Key On LACS: All Dungeons"] = {
        type = "lacs_dungeons",
        f = GanonKey
    },
}


local Static = {
    open_kakariko = {
        open = 50, --What to do?
        zelda = 0,
        closed = 50
    },
    bridge_medallions = {
        0, -- 1
        0, -- 2
        0, -- 3
        0, -- 4
        0, -- 5
        ["6"] = 100
    },
    bridge_stones = {
        0, -- 1
        0, -- 2
        ["3"] = 100
    },
    bridge_rewards = {
        0, -- 1
        0, -- 2
        0, -- 3
        0, -- 4
        0, -- 5
        0, -- 6
        0, -- 7
        0, -- 8
        ["9"] = 100
    },
    one_item_per_dungeon  = {
        ["true"] = 0,
        ["false"] = 100
    },
    shuffle_fortresskeys = { --What to do?
        vanilla = 100,
        overworld = 0,
        any_dungeon = 0,
        keysanity = 0
    },
    trials_random  = {
        ["true"] = 0,
        ["false"] = 100
    },
    shuffle_interior_entrances  = {
        off  = 100,
        simple  = 0,
        all  = 0
    },
    shuffle_grotto_entrances  = {
        ["true"] = 0,
        ["false"] = 100
    },
    shuffle_overworld_entrances  = {
        ["true"] = 0,
        ["false"] = 100
    },
    mix_entrance_pools  = {
        ["all"] = 0,
        ["indoor"] = 0,
        ["off"] = 100
    },
    decouple_entrances  = {
        ["true"] = 0,
        ["false"] = 100
    },
    owl_drops  = {
        ["true"] = 0,
        ["false"] = 100.0
    },
    mq_dungeons_random  = {
        ["true"] = 0.0,
        ["false"] = 100
    },
    mq_dungeons  = {
        ["0"]  = 100.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0
    },
    lacs_medallions = { --What to do?
        0, --1
        0, --2
        0, --3
        0, --4
        0, --5
        ["6"] = 100 --6
    },
    lacs_stones = { --What to do?
        0,
        0, --2
        ["3"] = 100 --3
    },
    lacs_rewards = { --What to do?
        0, --1
        0, --2
        0, --3
        0, --4
        0, --5
        0, --6
        0, --7
        0, --8
        ["9"] = 100
    },
     all_reachable  = {
        ["true"] = 100.0,
        ["false"] = 0
    },
    skip_child_zelda = { --What to do?
        ["true"] = 0,
        ["false"] = 100
    },
    complete_mask_quest = { --What to do?
        ["true"] = 50.0,
        ["false"] = 50.0
    },
    fast_bunny_hood = { --What to do?
        ["true"] = 100,
        ["false"] = 0
    },
    logic_no_night_tokens_without_suns_song  = {
        ["true"] = 50.0,
        ["false"] = 50.0--100?
    },
    no_collectible_hearts = {
        ["false"] = 100,
        ["true"] = 0
    },
    skip_some_minigame_phases  = {
        ["true"] = 100.0,
        ["false"] = 0
    },
    fast_chests  = {
        ["true"] = 100,
        ["false"] = 0
    },
    free_scarecrow  = {
        ["true"] = 50.0,
        ["false"] = 50.0
    },
    chicken_count_random  = {
        ["true"] = 100,
        ["false"] = 0
    },
    chicken_count  = {
        ["0"]  = 12.5,
        12.5, --1
        12.5, --2
        12.5, --3
        12.5, --4
        12.5, --5
        12.5, --6
        12.5 --7
    },
    big_poe_count_random  = {
        ["true"] = 0,
        ["false"] = 100
    },
    big_poe_count  = {
        100,  --1
        0,    --2
        0,    --3
        0,    --4
        0,    --5
        0,    --6
        0,    --7
        0,    --8
        0,    --9
        ["10"] = 0    --10
    },
    ocarina_songs  = {
        ["true"] = 0,
        ["false"] = 100
    },
    clearer_hints  = {
        ["true"] = 100,
        ["false"] = 0
    },
    hints  = {
        none  = 0,
        mask  = 0,
        agony  = 0,
        always  = 100
    },
    text_shuffle  = {
        none  = 100,
        except_hints  = 0,
        complete  = 0
    },
    starting_tod  = {
        default  = 0,
        random  = 0,
        sunrise  = 0,
        morning  = 0,
        noon  = 100,
        afternoon  = 0,
        sunset  = 0,
        evening  = 0,
        midnight  = 0,
        ["witching-hour"]  = 0
    },
    item_pool_value  = {
        plentiful  = 0,
        balanced  = 100,
        scarce  = 0,
        minimal  = 0
    },
    junk_ice_traps  = {
        off  = 50,
        normal  = 50,
        on  = 0,
        mayhem  = 0,
        onslaught  = 0
    },
    ice_trap_appearance  = {
        major_only  = 33.333333333333336,
        junk_only  = 33.333333333333336,
        anything  = 33.333333333333336
    },
    logic_rules  = {
        glitchless  = 100,
        glitched  = 0,
        none  = 0
    },
    logic_earliest_adult_trade  = {
        pocket_egg  = 0,
        pocket_cucco  = 0,
        cojiro  = 0,
        odd_mushroom  = 0,
        poachers_saw  = 0,
        broken_sword  = 0,
        prescription  = 0,
        eyeball_frog  = 0,
        eyedrops  = 0,
        claim_check  = 100
    },
    logic_latest_adult_trade  = {
        pocket_egg  = 0,
        pocket_cucco  = 0,
        cojiro  = 0,
        odd_mushroom  = 0,
        poachers_saw  = 0,
        broken_sword  = 0,
        prescription  = 0,
        eyeball_frog  = 0,
        eyedrops  = 0,
        claim_check  = 100
    },
    starting_hearts  = {
        ["3"]  = 50.0,
        ["4"]  = 25.0,
        ["5"]  = 12.5,
        ["6"]  = 6.25,
        ["7"]  = 3.125,
        ["8"]  = 1.5625,
        ["9"]  = 0.78125,
        ["10"]  = 0.390625,
        ["11"]  = 0.1953125,
        ["12"]  = 0.09765625,
        ["13"]  = 0.048828125,
        ["14"]  = 0.0244140625,
        ["15"]  = 0.01220703125,
        ["16"]  = 0.006103515625,
        ["17"]  = 0.0030517578125,
        ["18"]  = 0.00152587890625,
        ["19"]  = 0.000762939453125,
        ["20"]  = 0.0003814697265625
    }
}

return Weights, Static