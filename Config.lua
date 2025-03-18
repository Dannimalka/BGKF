-- BGKF: Configuration Module

local BGKF = LibStub("AceAddon-3.0"):GetAddon("BGKF")
local Config = BGKF:NewModule("Config")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Setup config options
function Config:OnInitialize()
  -- Create options table
  local options = {
    name = "BGKF - Battleground Kill Feed",
    handler = BGKF,
    type = "group",
    args = {
      general = {
        name = "General Settings",
        type = "group",
        order = 1,
        args = {
          enabled = {
            name = "Enable Addon",
            desc = "Enable or disable the addon functionality",
            type = "toggle",
            width = "full",
            order = 1,
            get = function() return BGKF.db.profile.enabled end,
            set = function(_, value)
              BGKF.db.profile.enabled = value
              BGKF:RefreshConfig()
            end
          },
          desc = {
            name = "BGKF shows kill feeds in battlegrounds similar to CS:GO",
            type = "description",
            order = 2,
          },
          testMode = {
            name = "Test Mode",
            desc = "Start test mode to see how the addon works without being in a battleground",
            type = "execute",
            order = 3,
            func = function()
              -- Make sure we call the function on the KillFeed module, not on BGKF directly
              if BGKF.modules.KillFeed and BGKF.modules.KillFeed.StartTestMode then
                BGKF.modules.KillFeed:StartTestMode()
              else
                BGKF:Print("Error: KillFeed module not found or StartTestMode function not available")
              end
            end
          }
        }
      },
      killFeed = {
        name = "Kill Feed Display",
        type = "group",
        order = 2,
        args = {
          feedHeader = {
            name = "Kill Feed Display Settings",
            type = "header",
            order = 1
          },
          width = {
            name = "Width",
            desc = "Width of the kill feed frame",
            type = "range",
            min = 100,
            max = 600,
            step = 10,
            order = 2,
            get = function() return BGKF.db.profile.killFeed.width end,
            set = function(_, value)
              BGKF.db.profile.killFeed.width = value
              if BGKF.modules.KillFeed and BGKF.modules.KillFeed.UpdateLayout then
                BGKF.modules.KillFeed:UpdateLayout()
              end
            end
          },
          height = {
            name = "Height",
            desc = "Height of the kill feed frame",
            type = "range",
            min = 100,
            max = 800,
            step = 10,
            order = 3,
            get = function() return BGKF.db.profile.killFeed.height end,
            set = function(_, value)
              BGKF.db.profile.killFeed.height = value
              if BGKF.modules.KillFeed and BGKF.modules.KillFeed.UpdateLayout then
                BGKF.modules.KillFeed:UpdateLayout()
              end
            end
          },
          entries = {
            name = "Max Entries",
            desc = "Maximum number of entries to show in the kill feed",
            type = "range",
            min = 1,
            max = 100,
            step = 1,
            order = 4,
            get = function() return BGKF.db.profile.killFeed.entries end,
            set = function(_, value)
              BGKF.db.profile.killFeed.entries = value
              if BGKF.modules.KillFeed and BGKF.modules.KillFeed.UpdateLayout then
                BGKF.modules.KillFeed:UpdateLayout()
              end
            end
          },
          fadeTime = {
            name = "Fade Time",
            desc = "Time in seconds before kill feed entries fade away (0 = never fade)",
            type = "range",
            min = 0,
            max = 300,
            step = 5,
            order = 5,
            get = function() return BGKF.db.profile.killFeed.fadeTime end,
            set = function(_, value)
              BGKF.db.profile.killFeed.fadeTime = value
            end
          },
          permanentKills = {
            name = "Permanent Kill Feed",
            desc = "Keep all kills in the feed for the entire battleground (overrides fade time)",
            type = "toggle",
            width = "full",
            order = 6,
            get = function() return BGKF.db.profile.killFeed.permanentKills end,
            set = function(_, value)
              BGKF.db.profile.killFeed.permanentKills = value
            end
          },
          fontSize = {
            name = "Font Size",
            desc = "Size of the text in the kill feed",
            type = "range",
            min = 8,
            max = 24,
            step = 1,
            order = 7,
            get = function() return BGKF.db.profile.killFeed.fontSize end,
            set = function(_, value)
              BGKF.db.profile.killFeed.fontSize = value
              if BGKF.modules.KillFeed and BGKF.modules.KillFeed.UpdateLayout then
                BGKF.modules.KillFeed:UpdateLayout()
              end
            end
          },
          showIcons = {
            name = "Show Faction Icons",
            desc = "Show faction icons next to player names",
            type = "toggle",
            order = 8,
            get = function() return BGKF.db.profile.killFeed.showIcons end,
            set = function(_, value)
              BGKF.db.profile.killFeed.showIcons = value
              if BGKF.modules.KillFeed and BGKF.modules.KillFeed.UpdateLayout then
                BGKF.modules.KillFeed:UpdateLayout()
              end
            end
          },
          showTimestamp = {
            name = "Show Timestamps",
            desc = "Show timestamps for each kill",
            type = "toggle",
            order = 9,
            get = function() return BGKF.db.profile.killFeed.showTimestamp end,
            set = function(_, value)
              BGKF.db.profile.killFeed.showTimestamp = value
              if BGKF.modules.KillFeed and BGKF.modules.KillFeed.UpdateLayout then
                BGKF.modules.KillFeed:UpdateLayout()
              end
            end
          },
          backgroundColor = {
            name = "Background Color",
            desc = "Color and transparency of the kill feed background",
            type = "color",
            hasAlpha = true,
            order = 10,
            get = function()
              local bg = BGKF.db.profile.killFeed.backgroundColor
              return bg.r, bg.g, bg.b, bg.a
            end,
            set = function(_, r, g, b, a)
              local bg = BGKF.db.profile.killFeed.backgroundColor
              bg.r, bg.g, bg.b, bg.a = r, g, b, a
              if BGKF.modules.KillFeed and BGKF.modules.KillFeed.UpdateLayout then
                BGKF.modules.KillFeed:UpdateLayout()
              end
            end
          },
          advancedHeader = {
            name = "Advanced Settings",
            type = "header",
            order = 11
          },
          updateFrequency = {
            name = "Update Frequency",
            desc = "How often to check for new kills (in seconds)",
            type = "range",
            min = 0.1,
            max = 5.0,
            step = 0.1,
            order = 12,
            get = function() return BGKF.db.profile.killFeed.updateFrequency end,
            set = function(_, value)
              BGKF.db.profile.killFeed.updateFrequency = value
              -- Update timer if KillFeed module is active
              if BGKF.modules.KillFeed and BGKF.modules.KillFeed.UpdateScoreTimer then
                BGKF.modules.KillFeed:UpdateScoreTimer()
              end
            end
          }
        }
      },
      ranks = {
        name = "PvP Ranks",
        type = "group",
        order = 3,
        args = {
          ranksHeader = {
            name = "Kill Streak Rank Settings",
            type = "header",
            order = 1
          },
          enabled = {
            name = "Enable Ranks",
            desc = "Enable or disable the rank system",
            type = "toggle",
            order = 2,
            get = function() return BGKF.db.profile.ranks.enabled end,
            set = function(_, value)
              BGKF.db.profile.ranks.enabled = value
              if BGKF.modules.RankSystem then
                BGKF.modules.RankSystem:UpdateConfig()
              end
            end
          },
          resetOnDeath = {
            name = "Reset on Death",
            desc = "Reset rank to 1 when player dies",
            type = "toggle",
            order = 3,
            get = function() return BGKF.db.profile.ranks.resetOnDeath end,
            set = function(_, value)
              BGKF.db.profile.ranks.resetOnDeath = value
            end
          },
          showOnNameplates = {
            name = "Show on Nameplates",
            desc = "Show player ranks on nameplates",
            type = "toggle",
            order = 4,
            get = function() return BGKF.db.profile.ranks.showOnNameplates end,
            set = function(_, value)
              BGKF.db.profile.ranks.showOnNameplates = value
              if BGKF.modules.Nameplates then
                BGKF.modules.Nameplates:UpdateHooks(value)
              end
            end
          },
          rankInfo = {
            name = "Rank System Info",
            desc = "The addon uses standard WoW PvP ranks based on faction (Alliance vs Horde)",
            type = "description",
            order = 5,
            fontSize = "medium"
          }
        }
      },
      sounds = {
        name = "Sound Settings",
        type = "group",
        order = 4,
        args = {
          soundHeader = {
            name = "Kill Sound Settings",
            type = "header",
            order = 1
          },
          enabled = {
            name = "Enable Sounds",
            desc = "Enable or disable kill sounds",
            type = "toggle",
            order = 2,
            get = function() return BGKF.db.profile.sounds.enabled end,
            set = function(_, value)
              BGKF.db.profile.sounds.enabled = value
            end
          },
          volume = {
            name = "Sound Volume",
            desc = "Volume of kill sounds",
            type = "range",
            min = 0,
            max = 1,
            step = 0.05,
            order = 3,
            get = function() return BGKF.db.profile.sounds.volume end,
            set = function(_, value)
              BGKF.db.profile.sounds.volume = value
            end
          },
          firstBloodSound = {
            name = "First Kill Sound",
            desc = "Sound to play on a single kill",
            type = "select",
            values = function()
              if BGKF.modules.SoundSystem then
                return BGKF.modules.SoundSystem:GetSoundList()
              else
                return { FirstBlood = "FirstBlood" }
              end
            end,
            order = 4,
            get = function() return BGKF.db.profile.sounds.killSound end,
            set = function(_, value)
              BGKF.db.profile.sounds.killSound = value
              if BGKF.modules.SoundSystem and BGKF.modules.SoundSystem.PlaySound then
                BGKF.modules.SoundSystem:PlaySound(value)
              end
            end
          },
          soundDesc = {
            name =
            "Sounds will play automatically based on your kill count and kill streaks:\n• Single Kill: FirstBlood or random Headshot\n• 2 Kills in a row: DoubleKill\n• 3 Kills in a row: TripleKill\n• 4 Kills in a row: MultiKill\n• 5 Kills in a row: MegaKill\n• 6 Kills in a row: UltraKill\n• 7+ Kills in a row: MonsterKill\n\nTotal score milestones:\n• 5 Total Kills: KillingSpree\n• 8 Total Kills: Rampage\n• 10 Total Kills: Dominating\n• 12 Total Kills: Unstoppable\n• 15+ Total Kills: Godlike",
            type = "description",
            order = 5,
            fontSize = "medium"
          }
        }
      }
    }
  }

  -- Add alliance rank display
  options.args.ranks.args.allianceRanksHeader = {
    name = "Alliance Ranks",
    type = "header",
    order = 10
  }

  for i = 1, 10 do
    options.args.ranks.args["allianceRank" .. i] = {
      name = "Rank " .. i,
      desc = "Alliance rank " .. i,
      type = "description",
      order = 10 + i,
      width = "full",
      fontSize = "medium"
    }
  end

  -- Add horde rank display
  options.args.ranks.args.hordeRanksHeader = {
    name = "Horde Ranks",
    type = "header",
    order = 30
  }

  for i = 1, 10 do
    options.args.ranks.args["hordeRank" .. i] = {
      name = "Rank " .. i,
      desc = "Horde rank " .. i,
      type = "description",
      order = 30 + i,
      width = "full",
      fontSize = "medium"
    }
  end

  -- Register options table
  AceConfig:RegisterOptionsTable("BGKF", options)
  self.optionsFrame = AceConfigDialog:AddToBlizOptions("BGKF", "BGKF")

  -- Store in modules for easy access
  BGKF.modules.Config = self
end

-- Open config panel
function Config:OpenConfig()
  AceConfigDialog:Open("BGKF")
end

-- Update config (called when settings change)
function Config:UpdateConfig()
  -- Update rank display info
  if BGKF.modules.RankSystem then
    local options = AceConfig:GetOptionsTable("BGKF")

    -- Update Alliance ranks
    for i = 1, 10 do
      options.args.ranks.args["allianceRank" .. i].name = i .. ". " .. BGKF.modules.RankSystem.factionRanks.Alliance[i]
    end

    -- Update Horde ranks
    for i = 1, 10 do
      options.args.ranks.args["hordeRank" .. i].name = i .. ". " .. BGKF.modules.RankSystem.factionRanks.Horde[i]
    end

    -- Refresh config
    AceConfig:NotifyChange("BGKF")
  end
end

function Config:OnEnable()
  -- Update rank display info
  self:UpdateConfig()
end
