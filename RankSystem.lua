-- BGKF: Improved Rank System Module

local BGKF = LibStub("AceAddon-3.0"):GetAddon("BGKF")
local RankSystem = BGKF:NewModule("RankSystem", "AceEvent-3.0")

-- Module initialization
function RankSystem:OnInitialize()
  -- Create table to store player ranks
  self.playerRanks = {}

  -- Add debug mode property
  self.debugMode = BGKF.db.profile.debugMode

  -- Store in modules for easy access
  BGKF.modules.RankSystem = self

  -- Print debug message
  self:DebugPrint("RankSystem module initialized")

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

-- Debug print function
function RankSystem:DebugPrint(...)
  if self.debugMode then
    BGKF:Print(...)
  end
end

-- Enable module (when entering battleground)
function RankSystem:OnEnable()
  -- Reset all ranks
  self.playerRanks = {}
  self:DebugPrint("RankSystem enabled - all ranks reset")

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
  self:DebugPrint("RankSystem disabled - all ranks cleared")
end

-- Update a player's rank
function RankSystem:UpdateRank(playerName, change)
  if not playerName then
    self:DebugPrint("UpdateRank called with nil playerName")
    return
  end

  local normalizedName = BGKF:NormalizePlayerName(playerName)
  self:DebugPrint("Updating rank for normalized name: " .. normalizedName)

  -- Initialize if needed
  if not self.playerRanks[normalizedName] then
    self.playerRanks[normalizedName] = 1
  end

  local oldRank = self.playerRanks[normalizedName]

  if change > 0 then
    -- Increase rank (max 14)
    self.playerRanks[normalizedName] = math.min(14, self.playerRanks[normalizedName] + change)

    -- Announce rank up for player
    local playerNormalizedName = BGKF:NormalizePlayerName(UnitName("player"))
    if normalizedName == playerNormalizedName then
      local rankName = self:GetPlayerRankName(normalizedName)
      self:DebugPrint("You ranked up to: " .. rankName .. "!")

      if BGKF.modules.SoundSystem then
        BGKF.modules.SoundSystem:PlayRankSound(normalizedName)
      end
    end

    self:DebugPrint(normalizedName .. " rank increased from " .. oldRank .. " to " .. self.playerRanks[normalizedName])
  elseif change <= 0 then
    -- Reset rank to 1
    self.playerRanks[normalizedName] = 1

    -- Announce rank reset for player
    local playerNormalizedName = BGKF:NormalizePlayerName(UnitName("player"))
    if normalizedName == playerNormalizedName and BGKF.db.profile.ranks.resetOnDeath then
      self:DebugPrint("Your rank was reset to: " .. self:GetPlayerRankName(normalizedName))
    end

    self:DebugPrint(normalizedName .. " rank reset to 1")
  end

  -- Always notify other modules of the rank change regardless of whether the rank actually changed
  self:SendMessage("BGKF_RANK_CHANGED", normalizedName)

  -- Debug output of all ranks after change
  if self.debugMode then
    self:DebugPrint("Current ranks:")
    for name, rank in pairs(self.playerRanks) do
      self:DebugPrint("  " .. name .. ": " .. rank)
    end
  end

  -- Make sure nameplates get updated
  if BGKF.modules.Nameplates then
    if BGKF.modules.Nameplates.UpdateNameplateForPlayer then
      BGKF.modules.Nameplates:UpdateNameplateForPlayer(normalizedName)
    else
      BGKF.modules.Nameplates:UpdateAllNameplates()
    end
  end
end

-- Get a player's rank
function RankSystem:GetPlayerRank(playerName)
  if not playerName then
    return 1   -- Default to rank 1
  end

  local normalizedName = BGKF:NormalizePlayerName(playerName)

  -- Try with the exact normalized name
  if self.playerRanks[normalizedName] then
    return self.playerRanks[normalizedName]
  end

  -- If we get here, we didn't find a rank
  return 1 -- Default to rank 1
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
    self:DebugPrint("Player died: " .. playerName)
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
        self:DebugPrint("Combat log detected player death: " .. destName)
        self:UpdateRank(destName, 0)
      end
    end
  end
end

-- Update configuration (called when settings change)
function RankSystem:UpdateConfig()
  -- Update debug mode
  self.debugMode = BGKF.db.profile.debugMode
end
