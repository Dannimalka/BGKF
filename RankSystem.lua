-- BGKF: Rank System Module

local BGKF = LibStub("AceAddon-3.0"):GetAddon("BGKF")
local RankSystem = BGKF:NewModule("RankSystem", "AceEvent-3.0")

-- Module initialization
function RankSystem:OnInitialize()
  -- Create table to store player ranks
  self.playerRanks = {}

  -- Store in modules for easy access
  BGKF.modules.RankSystem = self

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
      [10] = "Lieutenant Commander"
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
      [10] = "Champion"
    }
  }
end

-- Enable module (when entering battleground)
function RankSystem:OnEnable()
  -- Reset all ranks
  self.playerRanks = {}

  -- Register player death event for rank resetting
  self:RegisterEvent("PLAYER_DEAD", "HandlePlayerDeath")
end

-- Disable module (when leaving battleground)
function RankSystem:OnDisable()
  -- Unregister events
  self:UnregisterAllEvents()
end

-- Update a player's rank
function RankSystem:UpdateRank(playerName, change)
  if not playerName then return end

  if not self.playerRanks[playerName] then
    self.playerRanks[playerName] = 1     -- Start at rank 1
  end

  if change > 0 then
    -- Increase rank (max 10)
    local oldRank = self.playerRanks[playerName]
    self.playerRanks[playerName] = math.min(10, self.playerRanks[playerName] + change)

    -- Announce rank up for player
    if playerName == UnitName("player") and oldRank < self.playerRanks[playerName] then
      local rankName = BGKF.db.profile.ranks.rankNames[self.playerRanks[playerName]]
      BGKF:Print("You ranked up to: " .. rankName .. "!")

      if BGKF.modules.SoundSystem then
        BGKF.modules.SoundSystem:PlayRankUpSound()
      end
    end
  elseif change == 0 then
    -- Reset rank
    self.playerRanks[playerName] = 1

    -- Announce rank reset for player
    if playerName == UnitName("player") and BGKF.db.profile.ranks.resetOnDeath then
      BGKF:Print("Your rank was reset to: " .. BGKF.db.profile.ranks.rankNames[1])
    end
  end

  -- Update nameplates if needed
  if BGKF.db.profile.ranks.showOnNameplates and BGKF.modules.Nameplates then
    BGKF.modules.Nameplates:UpdateAllNameplates()
  end
end

-- Get a player's rank
function RankSystem:GetPlayerRank(playerName)
  if not playerName or not self.playerRanks[playerName] then
    return 1     -- Default to rank 1
  end

  return self.playerRanks[playerName]
end

-- Get a player's rank name
function RankSystem:GetPlayerRankName(playerName)
  local rankIndex = self:GetPlayerRank(playerName)

  -- Determine player's faction
  local faction = "Alliance"   -- Default

  -- Try to get real faction if player exists
  if UnitExists(playerName) then
    faction = UnitFactionGroup(playerName)
  elseif playerName:find("Ally") then    -- For test mode
    faction = "Alliance"
  elseif playerName:find("Horde") then   -- For test mode
    faction = "Horde"
  end

  -- Use appropriate rank name based on faction
  return self.factionRanks[faction][rankIndex] or self.factionRanks[faction][1]
end

-- Handle player death
function RankSystem:HandlePlayerDeath()
  if BGKF.db.profile.ranks.resetOnDeath then
    local playerName = UnitName("player")
    self:UpdateRank(playerName, 0)     -- Reset rank
  end
end

-- Update configuration (called when settings change)
function RankSystem:UpdateConfig()
  -- Nothing specific to update here
  -- Ranks are always pulled from the current configuration
end
