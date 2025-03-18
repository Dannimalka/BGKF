-- BGKF: Sound System Module

local BGKF = LibStub("AceAddon-3.0"):GetAddon("BGKF")
local SoundSystem = BGKF:NewModule("SoundSystem")

-- Module initialization
function SoundSystem:OnInitialize()
  -- Register available sounds
  self.sounds = {
    Kill = "Interface\\AddOns\\BGKF\\Sounds\\kill.ogg",
    DoubleKill = "Interface\\AddOns\\BGKF\\Sounds\\doublekill.ogg",
    TripleKill = "Interface\\AddOns\\BGKF\\Sounds\\triplekill.ogg",
    UltraKill = "Interface\\AddOns\\BGKF\\Sounds\\ultrakill.ogg",
    Rampage = "Interface\\AddOns\\BGKF\\Sounds\\rampage.ogg",
    RankUp = "Interface\\AddOns\\BGKF\\Sounds\\rankup.ogg"
  }

  -- Initialize kill streak tracking
  self.killStreaks = {}

  -- Store in modules for easy access
  BGKF.modules.SoundSystem = self
end

-- Enable module
function SoundSystem:OnEnable()
  -- Reset kill streaks
  self.killStreaks = {}
end

-- Disable module
function SoundSystem:OnDisable()
  -- Nothing specific to do
end

-- Get a list of available sounds
function SoundSystem:GetSoundList()
  local list = {}

  for name, _ in pairs(self.sounds) do
    list[name] = name
  end

  return list
end

-- Play a specific sound
function SoundSystem:PlaySound(soundName)
  if not BGKF.db.profile.sounds.enabled then
    return
  end

  local soundFile = self.sounds[soundName]

  if soundFile then
    PlaySoundFile(soundFile, "Master", BGKF.db.profile.sounds.volume)
  end
end

-- Play rank up sound
function SoundSystem:PlayRankUpSound()
  self:PlaySound("RankUp")
end

-- Play sound for kill streak
function SoundSystem:PlayKillSound(playerName)
  if not BGKF.db.profile.sounds.enabled then
    return
  end

  -- Initialize if needed
  if not self.killStreaks[playerName] then
    self.killStreaks[playerName] = {
      count = 0,
      lastKill = 0
    }
  end

  local streak = self.killStreaks[playerName]
  local currentTime = GetTime()

  -- Reset streak if too much time passed (10 seconds)
  if currentTime - streak.lastKill > 10 and streak.count > 0 then
    streak.count = 0
  end

  -- Increment streak
  streak.count = streak.count + 1
  streak.lastKill = currentTime

  -- Determine which sound to play
  local soundFile
  if streak.count == 1 then
    soundFile = "Kill"
  elseif streak.count == 2 then
    soundFile = "DoubleKill"
  elseif streak.count == 3 then
    soundFile = "TripleKill"
  elseif streak.count == 4 then
    soundFile = "UltraKill"
  elseif streak.count >= 5 then
    soundFile = "Rampage"
  end

  -- Play the sound
  if soundFile then
    self:PlaySound(soundFile)
  end

  -- Announce for player's own streaks
  if playerName == UnitName("player") and streak.count > 1 then
    local streakText = ""
    if streak.count == 2 then
      streakText = "Double Kill!"
    elseif streak.count == 3 then
      streakText = "Triple Kill!"
    elseif streak.count == 4 then
      streakText = "Ultra Kill!"
    elseif streak.count >= 5 then
      streakText = "RAMPAGE!"
    end

    if streakText ~= "" then
      BGKF:Print(streakText)
    end
  end
end

-- Reset kill streak for a player
function SoundSystem:ResetKillStreak(playerName)
  if self.killStreaks[playerName] then
    self.killStreaks[playerName].count = 0
    BGKF:Print("Reset kill streak for " .. playerName)
  end
end

-- Update configuration (called when settings change)
function SoundSystem:UpdateConfig()
  -- Nothing specific to update here
  -- Sound settings are checked when playing sounds
end
