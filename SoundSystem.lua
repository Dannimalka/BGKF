-- BGKF: Improved Sound System Module with Rank Progression

local BGKF = LibStub("AceAddon-3.0"):GetAddon("BGKF")
local SoundSystem = BGKF:NewModule("SoundSystem", "AceEvent-3.0")

-- Module initialization
function SoundSystem:OnInitialize()
  -- Store player's previous rank for comparison
  self.previousRank = 1

  -- Debug mode
  self.debugMode = BGKF.db.profile.debugMode

  -- List of available kill sounds - just the essential 14 rank sounds
  self.soundFiles = {
    -- Rank 1 starts with a placeholder (never actually played because you start at rank 1)
    ["Rank1"] = "Sounds\\headshot.ogg", -- This is just a placeholder, rarely played

    -- Rank 2-4 (Basic sounds)
    ["Rank2"] = "Sounds\\firstblood.ogg",
    ["Rank3"] = "Sounds\\doublekill.ogg",
    ["Rank4"] = "Sounds\\triplekill.ogg",

    -- Rank 5-8 (Mid-tier sounds)
    ["Rank5"] = "Sounds\\multikill.ogg",
    ["Rank6"] = "Sounds\\killingspree.ogg",
    ["Rank7"] = "Sounds\\megakill.ogg",
    ["Rank8"] = "Sounds\\rampage.ogg",

    -- Rank 9-12 (High-tier sounds)
    ["Rank9"] = "Sounds\\ultrakill.ogg",
    ["Rank10"] = "Sounds\\dominating.ogg",
    ["Rank11"] = "Sounds\\monsterkill.ogg",
    ["Rank12"] = "Sounds\\unstoppable.ogg",

    -- Rank 13-14 (Elite sounds)
    ["Rank13"] = "Sounds\\godlike.ogg",
    ["Rank14"] = "Sounds\\winner.ogg",

    -- Special sounds
    ["Death"] = "Sounds\\failed.ogg",
    ["Headshot"] = "Sounds\\headshot.ogg"
  }
  -- Register with BGKF modules
  BGKF.modules.SoundSystem = self

  -- Print initialization message
  self:DebugPrint("SoundSystem module initialized with " .. self:GetSoundCount() .. " rank sounds")
end

-- Debug print function
function SoundSystem:DebugPrint(...)
  if self.debugMode then
    BGKF:Print(...)
  end
end

-- Get count of available sounds
function SoundSystem:GetSoundCount()
  local count = 0
  for _ in pairs(self.soundFiles) do
    count = count + 1
  end
  return count
end

-- Get list of available sounds for config
function SoundSystem:GetSoundList()
  local list = {}
  for name, _ in pairs(self.soundFiles) do
    list[name] = name
  end
  return list
end

-- Play a specific sound
function SoundSystem:PlaySound(soundName)
  -- Get the sound file path
  local soundFile = self.soundFiles[soundName]
  if not soundFile then
    self:DebugPrint("Sound not found: " .. (soundName or "nil"))
    return
  end

  -- Build the full path including the addon folder
  local fullPath = "Interface\\AddOns\\BGKF\\" .. soundFile

  -- Print debug message
  self:DebugPrint("Playing sound: " .. soundName .. " (" .. fullPath .. ")")

  -- Play the sound
  PlaySoundFile(fullPath, "Master", BGKF.db.profile.sounds.volume or 1.0)
end

-- Play a rank sound based on player rank
-- This is the key function that now plays the correct rank sound
function SoundSystem:PlayRankSound(playerName)
  if not BGKF.db.profile.sounds.enabled then
    return
  end

  -- Only play sounds for the player using the addon
  if playerName ~= UnitName("player") then
    return
  end

  -- Check if ranks are disabled
  if not BGKF.db.profile.ranks.enabled then
    -- Play only headshot sound when ranks are disabled
    self:PlaySound("Headshot")
    self:DebugPrint("Ranks disabled - Playing headshot sound")
    return
  end

  -- Get player's rank from RankSystem
  local rank = 1
  if BGKF.modules.RankSystem then
    rank = BGKF.modules.RankSystem:GetPlayerRank(playerName)
  end

  -- Clamp rank to 1-14 range
  rank = math.max(1, math.min(14, rank))

  self:DebugPrint("Current rank: " .. rank .. ", Previous rank: " .. self.previousRank)

  -- If rank increased, play the sound for the new rank
  if rank > self.previousRank then
    local soundName = "Rank" .. rank
    self:PlaySound(soundName)
    self:DebugPrint("Rank increased! Playing " .. soundName)

    -- Get player's faction
    local faction = UnitFactionGroup("player")

    -- Get the rank name appropriate for the player's faction
    local rankName = "Unknown"
    if BGKF.modules.RankSystem and BGKF.modules.RankSystem.factionRanks and
        BGKF.modules.RankSystem.factionRanks[faction] and
        BGKF.modules.RankSystem.factionRanks[faction][rank] then
      rankName = BGKF.modules.RankSystem.factionRanks[faction][rank]
    end

    -- Print rank message for the player with the proper rank name
    BGKF:Print("New rank achieved: " .. rankName .. "!")
  else
    -- If rank didn't increase but we killed someone, play the current rank sound
    local soundName = "Rank" .. rank
    self:PlaySound(soundName)
    self:DebugPrint("Kill with current rank. Playing " .. soundName)
  end

  -- Store current rank for next comparison
  self.previousRank = rank
end

-- Play death sound when player dies
function SoundSystem:PlayDeathSound()
  if BGKF.db.profile.sounds.enabled then
    self:PlaySound("Death")
    self:DebugPrint("Player died! Playing death sound")

    -- Reset previous rank when we die
    self.previousRank = 1
  end
end

-- Handle player death
function SoundSystem:OnPlayerDeath()
  self:PlayDeathSound()
  self:DebugPrint("OnPlayerDeath triggered")
end

-- Compatibility function for older code
function SoundSystem:PlayKillSound(playerName)
  self:PlayRankSound(playerName)
end

-- Compatibility function for older code
function SoundSystem:ResetKillStreak(playerName)
  if playerName == UnitName("player") then
    -- Store previous rank for messaging
    local oldRank = self.previousRank

    -- Reset the rank
    self.previousRank = 1

    -- Get player's faction
    local faction = UnitFactionGroup("player")

    -- Get the rank name appropriate for the player's faction
    local rankName = "Private/Scout"
    if oldRank > 1 and BGKF.modules.RankSystem and BGKF.modules.RankSystem.factionRanks and
        BGKF.modules.RankSystem.factionRanks[faction] and
        BGKF.modules.RankSystem.factionRanks[faction][1] then
      rankName = BGKF.modules.RankSystem.factionRanks[faction][1]
    end

    -- Only display the message if we actually lost rank
    if oldRank > 1 then
      BGKF:Print("Rank reset to " .. rankName .. "!")
    end

    self:DebugPrint("Kill streak reset for " .. playerName)
  end
end

-- Enable module
function SoundSystem:OnEnable()
  -- Register for events
  self:RegisterEvent("PLAYER_DEAD", "OnPlayerDeath")

  -- Reset previous rank
  self.previousRank = 1

  self:DebugPrint("SoundSystem enabled")
end

-- Disable module
function SoundSystem:OnDisable()
  -- Unregister all events
  self:UnregisterAllEvents()

  self:DebugPrint("SoundSystem disabled")
end

-- Update configuration (called when settings change)
function SoundSystem:UpdateConfig()
  -- Nothing specific to update here
  -- Sound settings are checked each time a sound is played
end
