-- BGKF: Battleground Kill Feed
-- Main addon file

-- Create main addon object
local BGKF = LibStub("AceAddon-3.0"):NewAddon("BGKF", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

-- Store modules for easy access
BGKF.modules = {}
BGKF.inTestMode = false

-- Defaults for saved variables
BGKF.defaults = {
  profile = {
    enabled = true,
    killFeed = {
      width = 300,
      height = 400,
      position = {
        point = "CENTER",
        relativePoint = "CENTER",
        xOffset = 0,
        yOffset = 0
      },
      entries = 30,
      fadeTime = 30,
      permanentKills = false,
      fontSize = 12,
      showIcons = true,
      showTimestamp = true,
      backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 },
      updateFrequency = 1.0
    },
    sounds = {
      enabled = true,
      volume = 0.5,
      killSound = "Kill",
      doubleKillSound = "DoubleKill",
      tripleKillSound = "TripleKill",
      ultraKillSound = "UltraKill",
      rampage = "Rampage"
    },
    ranks = {
      enabled = true,
      resetOnDeath = true,
      showOnNameplates = true,
      rankNames = {
        [1] = "Recruit",
        [2] = "Soldier",
        [3] = "Sergeant",
        [4] = "Lieutenant",
        [5] = "Captain",
        [6] = "Major",
        [7] = "Colonel",
        [8] = "General",
        [9] = "Warlord",
        [10] = "High Warlord"
      }
    }
  }
}



-- Addon initialization
function BGKF:OnInitialize()
  -- Set up database
  self.db = LibStub("AceDB-3.0"):New("BGKFDB", self.defaults)

  self.inTestMode = false

  -- Register chat commands
  self:RegisterChatCommand("bgkf", "ChatCommand")

  -- Print initialization message
  self:Print("Battleground Kill Feed loaded. Type /bgkf to access settings.")
end

-- Handle slash commands
function BGKF:ChatCommand(input)
  if input == "" then
    self.modules.Config:OpenConfig()
  elseif input == "test" then
    self:StartTestMode()
  else
    LibStub("AceConfigCmd-3.0"):HandleCommand("bgkf", "BGKF", input)
  end
end

-- Check if player is in a battleground
function BGKF:CheckBattleground()
  if self.inTestMode then
    return
  end
  -- Check if we're in a battleground
  local inInstance, instanceType = IsInInstance()
  local inBattleground = (instanceType == "pvp")

  -- Enable/disable modules based on battleground status
  if inBattleground then
    -- We're in a battleground, make sure all the modules are enabled
    if BGKF.db.profile.enabled then
      if BGKF.modules.KillFeed and not BGKF.modules.KillFeed:IsEnabled() then
        BGKF.modules.KillFeed:Enable()
      end

      if BGKF.modules.RankSystem and not BGKF.modules.RankSystem:IsEnabled() then
        BGKF.modules.RankSystem:Enable()
      end

      if BGKF.modules.SoundSystem and not BGKF.modules.SoundSystem:IsEnabled() then
        BGKF.modules.SoundSystem:Enable()
      end

      if BGKF.db.profile.ranks.showOnNameplates and BGKF.modules.Nameplates and not BGKF.modules.Nameplates:IsEnabled() then
        BGKF.modules.Nameplates:Enable()
      end
    end
  else
    -- We're not in a battleground, disable all modules
    if BGKF.modules.KillFeed and BGKF.modules.KillFeed:IsEnabled() then
      BGKF.modules.KillFeed:Disable()
    end

    if BGKF.modules.RankSystem and BGKF.modules.RankSystem:IsEnabled() then
      BGKF.modules.RankSystem:Disable()
    end

    if BGKF.modules.SoundSystem and BGKF.modules.SoundSystem:IsEnabled() then
      BGKF.modules.SoundSystem:Disable()
    end

    if BGKF.modules.Nameplates and BGKF.modules.Nameplates:IsEnabled() then
      BGKF.modules.Nameplates:Disable()
    end
  end
end

-- Refresh configuration
function BGKF:RefreshConfig()
  self:CheckBattleground()

  -- Update all modules
  for _, module in pairs(self.modules) do
    if module.UpdateConfig then
      module:UpdateConfig()
    end
  end
end

-- When addon is enabled
function BGKF:OnEnable()
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "CheckBattleground")
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "CheckBattleground")
  self:CheckBattleground()
  self:SchedulePeriodicCheck()
end

function BGKF:SchedulePeriodicCheck()
  -- Cancel any existing timer first
  if self.bgCheckTimer then
    self:CancelTimer(self.bgCheckTimer)
    self.bgCheckTimer = nil
  end

  -- Set up a new timer to check every 5 seconds
  self.bgCheckTimer = self:ScheduleRepeatingTimer("CheckBattleground", 100)
end

-- When addon is disabled
function BGKF:OnDisable()
  self:UnregisterAllEvents()

  -- Disable all modules
  for name, module in pairs(self.modules) do
    if name ~= "Config" and module.Disable then
      module:Disable()
    end
  end
end

-- Test mode to simulate battleground events
-- Test mode to simulate battleground events
function BGKF:StartTestMode()
  -- Set test mode flag at the beginning
  self.inTestMode = true

  -- Unregister events that might trigger battleground checks
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  self:UnregisterEvent("ZONE_CHANGED_NEW_AREA")

  if not self.modules.KillFeed:IsEnabled() then
    self.modules.KillFeed:Enable() -- Enable module if disabled
  end

  -- Make sure all modules are enabled
  self:Print("Starting test mode...")

  -- Set up fake battlefield API
  self:SetupFakeBattlefieldAPI()

  -- Force-enable all modules
  for name, module in pairs(self.modules) do
    if module.Enable then
      module:Enable()

      -- Prevent modules from disabling themselves during test mode
      if module.CheckBattleground then
        module.originalCheckBattleground = module.CheckBattleground
        module.CheckBattleground = function() return true end
      end
    end
  end

  -- Disable the periodic check during test mode
  if self.bgCheckTimer then
    self:CancelTimer(self.bgCheckTimer)
    self.bgCheckTimer = nil
  end

  -- Disable timer that checks battlefield scores to prevent duplicate entries
  if self.modules.KillFeed and self.modules.KillFeed.scoreTimer then
    self.modules.KillFeed:CancelTimer(self.modules.KillFeed.scoreTimer)
    self.modules.KillFeed.scoreTimer = nil
  end

  -- Fake player data
  self.testData = {
    alliancePlayers = {
      { name = "AllyWarrior", class = "Warrior", faction = 1, race = "Human",    kills = 0, deaths = 0 },
      { name = "AllyPaladin", class = "Paladin", faction = 1, race = "Dwarf",    kills = 0, deaths = 0 },
      { name = "AllyHunter",  class = "Hunter",  faction = 1, race = "NightElf", kills = 0, deaths = 0 },
      { name = "AllyRogue",   class = "Rogue",   faction = 1, race = "Human",    kills = 0, deaths = 0 },
      { name = "AllyPriest",  class = "Priest",  faction = 1, race = "Human",    kills = 0, deaths = 0 }
    },
    hordePlayers = {
      { name = "HordeWarrior", class = "Warrior", faction = 0, race = "Orc",    kills = 0, deaths = 0 },
      { name = "HordeShaman",  class = "Shaman",  faction = 0, race = "Troll",  kills = 0, deaths = 0 },
      { name = "HordeHunter",  class = "Hunter",  faction = 0, race = "Orc",    kills = 0, deaths = 0 },
      { name = "HordeWarlock", class = "Warlock", faction = 0, race = "Undead", kills = 0, deaths = 0 },
      { name = "HordeDruid",   class = "Druid",   faction = 0, race = "Tauren", kills = 0, deaths = 0 }
    }
  }

  -- Initialize player data for all test players
  if self.modules.KillFeed then
    -- Initialize all test players in the KillFeed player data
    for _, faction in pairs({ "alliancePlayers", "hordePlayers" }) do
      for _, player in ipairs(self.testData[faction]) do
        self.modules.KillFeed.playerData[player.name] = {
          killingBlows = player.kills,
          honorableKills = 0,
          deaths = player.deaths,
          faction = player.faction,
          race = player.race,
          class = player.class,
          lastUpdated = GetTime()
        }
      end
    end
  end

  -- Simulate kills every few seconds
  local testTimer = self:ScheduleRepeatingTimer(function()
    -- Randomly select killer and victim
    local isAllianceKill = math.random(1, 2) == 1
    local killerList = isAllianceKill and self.testData.alliancePlayers or self.testData.hordePlayers
    local victimList = isAllianceKill and self.testData.hordePlayers or self.testData.alliancePlayers

    local killerIndex = math.random(1, #killerList)
    local victimIndex = math.random(1, #victimList)

    local killer = killerList[killerIndex]
    local victim = victimList[victimIndex]

    -- Update kill and death counts
    killer.kills = killer.kills + 1
    victim.deaths = victim.deaths + 1

    -- Update player data
    if self.modules.KillFeed then
      -- Update existing player data
      self.modules.KillFeed.playerData[killer.name].killingBlows = killer.kills
      self.modules.KillFeed.playerData[victim.name].deaths = victim.deaths

      -- Reset victim kills if resetOnDeath is enabled
      if self.db.profile.ranks.resetOnDeath then
        victim.kills = 0
        self.modules.KillFeed.playerData[victim.name].killingBlows = 0
      end
    end

    -- Update ranks first
    if self.modules.RankSystem then
      self.modules.RankSystem:UpdateRank(killer.name, 1)
      if self.db.profile.ranks.resetOnDeath then
        self.modules.RankSystem:UpdateRank(victim.name, 0)
      end
    end

    -- Add the kill to the feed
    if self.modules.KillFeed then
      self.modules.KillFeed:AddKill(killer.name, killer.class, victim.name, victim.class)
    end

    -- Play sound
    if self.modules.SoundSystem then
      self.modules.SoundSystem:PlayKillSound(killer.name)

      -- Reset the sound streak for victim if they died
      self.modules.SoundSystem:ResetKillStreak(victim.name)
    end

    -- Force update nameplates to show the new ranks
    if self.modules.Nameplates then
      self.modules.Nameplates:UpdateAllNameplates()
    end

    -- Print to chat for debugging
    self:Print(killer.name .. " [" .. killer.kills .. "] killed " .. victim.name .. " [" .. victim.kills .. "]")
  end, 3) -- Trigger every 3 seconds

  -- Stop test after 60 seconds
  self:ScheduleTimer(function()
    self:CancelTimer(testTimer)
    self:Print("Test mode finished.")

    -- Reset test mode flag
    self.inTestMode = false

    -- Restore original API
    GetNumBattlefieldScores = self.originalGetNumBattlefieldScores
    GetBattlefieldScore = self.originalGetBattlefieldScore

    -- Restore original module functions
    for name, module in pairs(self.modules) do
      if module.originalCheckBattleground then
        module.CheckBattleground = module.originalCheckBattleground
        module.originalCheckBattleground = nil
      end
    end

    -- Re-register battleground events
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "CheckBattleground")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "CheckBattleground")

    -- Re-enable the periodic check
    self:SchedulePeriodicCheck()

    -- Disable all modules except config
    for name, module in pairs(self.modules) do
      if name ~= "Config" and module.Disable then
        module:Disable()
      end
    end
  end, 60)
end

-- Set up fake battlefield API for testing
function BGKF:SetupFakeBattlefieldAPI()
  -- Save original functions
  self.originalGetNumBattlefieldScores = GetNumBattlefieldScores
  self.originalGetBattlefieldScore = GetBattlefieldScore

  -- Override with our test versions
  GetNumBattlefieldScores = function()
    return #self.testData.alliancePlayers + #self.testData.hordePlayers
  end

  GetBattlefieldScore = function(index)
    local allPlayers = {}

    -- Combine alliance and horde players
    for _, player in ipairs(self.testData.alliancePlayers) do
      table.insert(allPlayers, player)
    end

    for _, player in ipairs(self.testData.hordePlayers) do
      table.insert(allPlayers, player)
    end

    if index > #allPlayers then
      return nil
    end

    local player = allPlayers[index]

    -- Return values in the same order as the API
    return player.name, -- name
        player.kills,   -- killingBlows
        0,              -- honorableKills
        player.deaths,  -- deaths
        0,              -- honorGained
        player.faction, -- faction
        player.race,    -- race
        player.class,   -- class (lowercase class name like 'warrior')
        0,              -- damageDone
        0,              -- healingDone
        0,              -- bgRating
        0,              -- ratingChange
        0,              -- preMatchMMR
        0,              -- mmrChange
        player.class    -- talentSpec
  end
end

-- Utility function: Get class coordinates for icons
function BGKF:GetClassCoords(class)
  local coords = {
    ["WARRIOR"] = "0:32:0:32",
    ["MAGE"] = "32:64:0:32",
    ["ROGUE"] = "64:96:0:32",
    ["DRUID"] = "96:128:0:32",
    ["HUNTER"] = "0:32:32:64",
    ["SHAMAN"] = "32:64:32:64",
    ["PRIEST"] = "64:96:32:64",
    ["WARLOCK"] = "96:128:32:64",
    ["PALADIN"] = "0:32:64:96",
    ["DEATHKNIGHT"] = "32:64:64:96",
    ["MONK"] = "64:96:64:96",
    ["DEMONHUNTER"] = "96:128:64:96"
  }

  return coords[class] or "0:0:0:0"
end

-- Utility function: Get class from GUID
function BGKF:GetClassFromGUID(guid)
  local _, class = GetPlayerInfoByGUID(guid)
  return class
end

-- Make addon global
_G.BGKF = BGKF
