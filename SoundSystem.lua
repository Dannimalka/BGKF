-- Update for SoundSystem.lua
-- This function needs to be updated to work with the new KillFeed system

-- Modify the PlayKillSound function to work with the improved kill detection
function SoundSystem:PlayKillSound(playerName)
  if not BGKF.db.profile.sounds.enabled then
    return
  end

  -- Only play sounds for the player using the addon
  if playerName ~= UnitName("player") then
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

  -- Get player's total kill count from the kill feed data
  local killCount = 1
  if BGKF.modules.KillFeed and
      BGKF.modules.KillFeed.playerData and
      BGKF.modules.KillFeed.playerData[playerName] then
    killCount = BGKF.modules.KillFeed.playerData[playerName].killingBlows
  end

  -- Determine which sound to play based on kill count
  local soundName = nil

  -- First check if there's a special sound for this exact kill count
  if self.killScoreSounds[killCount] then
    soundName = self.killScoreSounds[killCount]
  else
    -- Otherwise use a sound based on streak
    if streak.count == 1 then
      -- For first kill in a streak, determine by kill count
      if killCount >= 15 then
        soundName = "Godlike"
      elseif killCount >= 12 then
        soundName = "Unstoppable"
      elseif killCount >= 10 then
        soundName = "Dominating"
      elseif killCount >= 8 then
        soundName = "Rampage"
      elseif killCount >= 5 then
        soundName = "KillingSpree"
      elseif math.random(1, 10) == 1 then   -- 10% chance of headshot sound
        soundName = "Headshot"
      else
        soundName = "FirstBlood"   -- Default to FirstBlood for single kills
      end
    elseif streak.count == 2 then
      soundName = "DoubleKill"
    elseif streak.count == 3 then
      soundName = "TripleKill"
    elseif streak.count == 4 then
      soundName = "MultiKill"
    elseif streak.count == 5 then
      soundName = "MegaKill"
    elseif streak.count == 6 then
      soundName = "UltraKill"
    elseif streak.count >= 7 then
      soundName = "MonsterKill"
    end
  end

  -- Play the sound
  if soundName then
    self:PlaySound(soundName)
  end

  -- Announce for player's own streaks
  if streak.count > 1 then
    local streakText = ""
    if streak.count == 2 then
      streakText = "Double Kill!"
    elseif streak.count == 3 then
      streakText = "Triple Kill!"
    elseif streak.count == 4 then
      streakText = "Multi Kill!"
    elseif streak.count == 5 then
      streakText = "Mega Kill!"
    elseif streak.count == 6 then
      streakText = "ULTRA KILL!"
    elseif streak.count >= 7 then
      streakText = "MONSTER KILL!!"
    end

    if streakText ~= "" then
      BGKF:Print(streakText)
    end
  end

  -- Also print kill count milestone announcements
  if killCount == 5 then
    BGKF:Print("Killing Spree!")
  elseif killCount == 10 then
    BGKF:Print("DOMINATING!")
  elseif killCount == 15 then
    BGKF:Print("GODLIKE!!")
  end
end
