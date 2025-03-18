-- BGKF: Improved Rank System Module

local BGKF = LibStub("AceAddon-3.0"):GetAddon("BGKF")
local RankSystem = BGKF:NewModule("RankSystem", "AceEvent-3.0")

-- Module initialization
function RankSystem:OnInitialize()
  -- Create table to store player ranks
  self.playerRanks = {}

  -- Store in modules for easy access
  BGKF.modules.RankSystem = self

  -- Print debug message
  BGKF:Print("RankSystem module initialized")

  -- Define standard PvP ranks by faction
  self.factionRanks = {
    Alliance = {
      [1] = "Private",
      [2] = "Corporal",
      [3] = "Sergeant",
      [4] = "Master Sergeant",
      [5] = "Sergeant Major",
      [6] = "Knight",
      [7] = "Knight-Lieutenant",
      [8] = "Knight-Captain",
      [9] = "Knight-Champion",
      [10] = "Lieutenant Commander",
      [11] = "Commander",
      [12] = "Marshal",
      [13] = "Field Marshal",
      [14] = "Grand Marshal"
    },
    Horde = {
      [1] = "Scout",
      [2] = "Grunt",
      [3] = "Sergeant",
      [4] = "Senior Sergeant",
      [5] = "First Sergeant",
      [6] = "Stone Guard",
      [7] = "Blood Guard",
      [8] = "Legionnaire",
      [9] = "Centurion",
      [10] = "Champion",
      [11] = "Lieutenant General",
      [12] = "General",
      [13] = "Warlord",
      [14] = "High Warlord"
    }
  }
end

-- Enable module (when entering battleground)
function RankSystem:OnEnable()
  -- Reset all ranks
  self.playerRanks = {}
  BGKF:Print("RankSystem enabled - all ranks reset")

  -- Register player death event for rank resetting
  self:RegisterEvent("PLAYER_DEAD", "HandlePlayerDeath")

  -- Also register for COMBAT_LOG_EVENT_UNFILTERED to better track deaths
  self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "ParseCombatLog")
end

-- Disable module (when leaving battleground)
function RankSystem:OnDisable()
  -- Unregister events
  self:UnregisterAllEvents()

  -- Clear ranks
  self.playerRanks = {}
  BGKF:Print("RankSystem disabled - all ranks cleared")
end

-- Update a player's rank
function RankSystem:UpdateRank(playerName, change)
  if not playerName then
    BGKF:Print("UpdateRank called with nil playerName")
    return
  end

  -- Initialize if needed
  if not self.playerRanks[playerName] then
    self.playerRanks[playerName] = 1
    BGKF:Print("Initialized rank for " .. playerName .. " to 1")
  end

  local oldRank = self.playerRanks[playerName]

  if change > 0 then
    -- Increase rank (max 14)
    self.playerRanks[playerName] = math.min(14, self.playerRanks[playerName] + change)

    BGKF:Print(playerName .. " rank increased from " .. oldRank .. " to " .. self.playerRanks[playerName])

    -- Announce rank up for player
    if playerName == UnitName("player") and oldRank < self.playerRanks[playerName] then
      local rankName = self:GetPlayerRankName(playerName)
      BGKF:Print("You ranked up to: " .. rankName .. "!")

      if BGKF.modules.SoundSystem then
        BGKF.modules.SoundSystem:PlayRankUpSound()
      end
    end
  elseif change <= 0 then
    -- Reset rank to 1
    self.playerRanks[playerName] = 1

    BGKF:Print(playerName .. " rank reset to 1")

    -- Announce rank reset for player
    if playerName == UnitName("player") and BGKF.db.profile.ranks.resetOnDeath then
      BGKF:Print("Your rank was reset to: " .. self:GetPlayerRankName(playerName))
    end
  end

  -- Debug dump current ranks
  BGKF:Print("Current ranks:")
  for name, rank in pairs(self.playerRanks) do
    BGKF:Print("  " .. name .. ": " .. rank)
  end

  -- Notify other modules of the rank change
  BGKF:Print("Sending BGKF_RANK_CHANGED for " .. playerName)
  self:SendMessage("BGKF_RANK_CHANGED", playerName)
end

-- Get a player's rank
function RankSystem:GetPlayerRank(playerName)
  if not playerName or not self.playerRanks[playerName] then
    return 1 -- Default to rank 1
  end

  local rank = self.playerRanks[playerName]
  BGKF:Print("GetPlayerRank for " .. playerName .. " = " .. rank)
  return rank
end

-- Get a player's rank name
function RankSystem:GetPlayerRankName(playerName)
  local rankIndex = self:GetPlayerRank(playerName)

  -- Determine player's faction
  local faction = "Alliance" -- Default

  -- Try to get real faction if player exists
  if UnitExists(playerName) then
    faction = UnitFactionGroup(playerName)
  elseif playerName:find("Ally") then  -- For test mode
    faction = "Alliance"
  elseif playerName:find("Horde") then -- For test mode
    faction = "Horde"
  end

  -- Use appropriate rank name based on faction
  return self.factionRanks[faction][rankIndex] or self.factionRanks[faction][1]
end

-- Handle player death
function RankSystem:HandlePlayerDeath()
  if BGKF.db.profile.ranks.resetOnDeath then
    local playerName = UnitName("player")
    BGKF:Print("Player died: " .. playerName)
    self:UpdateRank(playerName, 0) -- Reset rank
  end
end

-- Parse combat log to find deaths
function RankSystem:ParseCombatLog()
  local timestamp, event, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags =
  CombatLogGetCurrentEventInfo()

  -- Check if this is a death event
  if event == "UNIT_DIED" then
    -- Check if the dead unit is a player
    if bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 then
      -- Reset rank if enabled
      if BGKF.db.profile.ranks.resetOnDeath then
        BGKF:Print("Combat log detected player death: " .. destName)
        self:UpdateRank(destName, 0)
      end
    end
  end
end

-- Update configuration (called when settings change)
function RankSystem:UpdateConfig()
  -- Nothing specific to update here
  -- Ranks are always pulled from the current configuration
end
