-- BGKF: Kill Feed Module (Improved version)

local BGKF = LibStub("AceAddon-3.0"):GetAddon("BGKF")
local KillFeed = BGKF:NewModule("KillFeed", "AceEvent-3.0", "AceTimer-3.0")

-- Module initialization
function KillFeed:OnInitialize()
  -- Create main frame for kill feed
  self:CreateFrame()

  -- Storage for player data
  self.playerData = {}
  self.lastScoreCheck = {}

  -- New tracking for improved detection
  self.recentDeaths = {}   -- Recent player deaths with timestamps
  self.recentKills = {}    -- Recent player kills with timestamps
  self.processedKills = {} -- Already processed kill IDs
  self:RegisterMessage("BGKF_RANK_CHANGED", "OnRankChanged")

  -- debug mode
  self.debugMode = BGKF.db.profile.debugMode

  -- Store in modules for easy access
  BGKF.modules.KillFeed = self
end

-- Create main frame
function KillFeed:CreateFrame()
  -- Create main frame for kill feed
  self.frame = CreateFrame("Frame", "BGKFKillFeedFrame", UIParent)
  local frame = self.frame

  -- Make frame more visible
  frame:SetFrameStrata("HIGH")

  -- Set initial position and dimensions
  frame:SetWidth(BGKF.db.profile.killFeed.width)
  frame:SetHeight(BGKF.db.profile.killFeed.height)
  frame:SetPoint(
    BGKF.db.profile.killFeed.position.point,
    UIParent,
    BGKF.db.profile.killFeed.position.relativePoint,
    BGKF.db.profile.killFeed.position.xOffset,
    BGKF.db.profile.killFeed.position.yOffset
  )

  -- Make frame movable
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    -- Save position
    local point, _, relativePoint, xOffset, yOffset = frame:GetPoint()
    BGKF.db.profile.killFeed.position.point = point
    BGKF.db.profile.killFeed.position.relativePoint = relativePoint
    BGKF.db.profile.killFeed.position.xOffset = xOffset
    BGKF.db.profile.killFeed.position.yOffset = yOffset
  end)

  -- Create background
  frame.bg = frame:CreateTexture(nil, "BACKGROUND")
  frame.bg:SetAllPoints(frame)
  local bg = BGKF.db.profile.killFeed.backgroundColor
  frame.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)

  -- Create entries table to store kill feed entries
  frame.entries = {}

  -- Create a title bar for moving
  frame.titleBar = CreateFrame("Frame", nil, frame)
  frame.titleBar:SetHeight(20)
  frame.titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  frame.titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)

  -- Add title text
  frame.titleText = frame.titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.titleText:SetPoint("CENTER", frame.titleBar, "CENTER", 0, 0)
  frame.titleText:SetText("BG Kill Feed")

  -- Make title background to make it more visible for dragging
  frame.titleBg = frame.titleBar:CreateTexture(nil, "BACKGROUND")
  frame.titleBg:SetAllPoints(frame.titleBar)
  frame.titleBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

  -- Only show in battlegrounds initially
  frame:Hide()
end

-- Enable module (when entering battleground)
function KillFeed:OnEnable()
  -- Clear kill feed
  self:ClearEntries()

  -- Show frame
  self.frame:Show()

  -- Reset player data
  self.playerData = {}
  self.lastScoreCheck = {}
  self.recentDeaths = {}
  self.recentKills = {}
  self.processedKills = {}

  -- Initial score check - now with forced data request
  self:RequestScoreData()

  -- Set up timer to check scores regularly
  self.scoreTimer = self:ScheduleRepeatingTimer("RequestScoreData", BGKF.db.profile.killFeed.updateFrequency)

  -- Register for battleground events
  self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE", "ProcessScoreUpdate")
end

-- Disable module (when leaving battleground)
function KillFeed:OnDisable()
  -- Cancel timer
  if self.scoreTimer then
    self:CancelTimer(self.scoreTimer)
    self.scoreTimer = nil
  end

  -- Unregister all events
  self:UnregisterAllEvents()

  -- Hide frame
  self.frame:Hide()
end

-- Request up-to-date score data
function KillFeed:RequestScoreData()
  -- Request fresh data from the server
  RequestBattlefieldScoreData()

  -- Set a small delay to wait for data to be available
  C_Timer.After(0.5, function()
    self:CheckBattlefieldScores()
  end)
end

-- Process scoreboard update event
function KillFeed:ProcessScoreUpdate()
  self:CheckBattlefieldScores()
end

function KillFeed:RemoveServerName(name)
  if not name then return "" end

  -- Remove server name (everything after the first hyphen)
  local baseName = name:match("^([^-]+)")
  return baseName or name
end

-- Check battlefield scores for new kills (improved version)
function KillFeed:CheckBattlefieldScores()
  local numScores = GetNumBattlefieldScores()

  -- If no scores are available, return
  if numScores == 0 then
    return
  end

  -- First pass: track all score changes
  local newKillers = {}
  local newVictims = {}

  for i = 1, numScores do
    -- GetBattlefieldScore returns more data than we used before
    local name, killingBlows, honorableKills, deaths, honorGained, faction, race, class = GetBattlefieldScore(i)

    -- Skip if no name
    if not name or name == "" then
      return
    end

    -- Initialize player if needed
    if not self.playerData[name] then
      self.playerData[name] = {
        killingBlows = killingBlows,
        honorableKills = honorableKills,
        deaths = deaths,
        faction = faction,
        race = race,
        class = class, -- Store the class name ("Monk", "Warrior", etc.)
        lastUpdated = GetTime()
      }
      self.lastScoreCheck[name] = {
        killingBlows = killingBlows,
        honorableKills = honorableKills,
        deaths = deaths
      }
    else
      -- Check for new kills
      local newKillingBlows = killingBlows - (self.lastScoreCheck[name] and self.lastScoreCheck[name].killingBlows or 0)

      -- Check for new deaths
      local newDeaths = deaths - (self.lastScoreCheck[name] and self.lastScoreCheck[name].deaths or 0)

      -- Record timestamp for new killers
      if newKillingBlows > 0 then
        newKillers[name] = GetTime()
      end

      -- Record timestamp for new victims
      if newDeaths > 0 then
        newVictims[name] = GetTime()

        -- Also handle rank reset on death if enabled
        if BGKF.db.profile.ranks.resetOnDeath and name == UnitName("player") and BGKF.modules.RankSystem then
          BGKF.modules.RankSystem:UpdateRank(name, 0) -- Reset rank
        end
      end

      -- Update player data
      self.playerData[name].killingBlows = killingBlows
      self.playerData[name].honorableKills = honorableKills
      self.playerData[name].deaths = deaths
      self.playerData[name].lastUpdated = GetTime()

      -- Update last score check
      self.lastScoreCheck[name].killingBlows = killingBlows
      self.lastScoreCheck[name].honorableKills = honorableKills
      self.lastScoreCheck[name].deaths = deaths
    end
  end

  -- Match killers with victims based on timing
  self:MatchKillersAndVictims(newKillers, newVictims)

  -- Clean up old tracking data (older than 60 seconds)
  self:CleanupTrackingData()
end

-- Match killers with victims based on timing
function KillFeed:MatchKillersAndVictims(newKillers, newVictims)
  -- If no new data, nothing to do
  if not next(newKillers) or not next(newVictims) then return end

  -- The match window (how close in time kill and death need to be)
  local matchWindow = 1.2 -- seconds

  -- Keep track of which killers were matched to prevent duplicates
  local matchedKillers = {}

  -- Check each new killer
  for killer, killerTime in pairs(newKillers) do
    local matchedVictim = nil
    local bestTimeDiff = matchWindow + 1 -- Start outside our window

    -- Try to find the best victim match
    for victim, victimTime in pairs(newVictims) do
      -- Don't match someone to themselves
      if killer ~= victim then
        local timeDiff = math.abs(killerTime - victimTime)

        -- If this is a better match (closer in time)
        if timeDiff < bestTimeDiff and timeDiff <= matchWindow then
          bestTimeDiff = timeDiff
          matchedVictim = victim
        end
      end
    end

    -- If we found a good match
    if matchedVictim then
      -- Create a unique ID to prevent duplicates
      local killID = killer .. matchedVictim .. tostring(math.floor(killerTime))

      -- Only add if we haven't processed this kill before
      if not self.processedKills[killID] then
        -- Clean names for consistency
        local cleanKillerName = self:RemoveServerName(killer)
        local cleanVictimName = self:RemoveServerName(matchedVictim)

        -- Update killer's rank first
        if BGKF.db.profile.ranks.enabled and BGKF.modules.RankSystem then
          -- Only update once with the normalized name
          cleanKillerName = self:RemoveServerName(killer)
          BGKF.modules.RankSystem:UpdateRank(cleanKillerName, 1)
        end

        -- Create the kill feed entry - it will use the updated rank
        self:AddKill(killer, self.playerData[killer].class, matchedVictim, self.playerData[matchedVictim].class)

        -- Reset victim's rank
        if BGKF.db.profile.ranks.enabled and BGKF.db.profile.ranks.resetOnDeath and BGKF.modules.RankSystem then
          -- Update with both full and short names for compatibility
          BGKF.modules.RankSystem:UpdateRank(matchedVictim, 0)
          if cleanVictimName ~= matchedVictim then
            BGKF.modules.RankSystem:UpdateRank(cleanVictimName, 0)
          end
        end

        -- Play sound if enabled
        if BGKF.db.profile.sounds.enabled and BGKF.modules.SoundSystem then
          -- Check which method exists and use it
          if BGKF.modules.SoundSystem.PlayRankSound then
            BGKF.modules.SoundSystem:PlayRankSound(killer)
          elseif BGKF.modules.SoundSystem.PlayKillSound then
            BGKF.modules.SoundSystem:PlayKillSound(killer)
          elseif BGKF.modules.SoundSystem.PlaySound then
            BGKF.modules.SoundSystem:PlaySound("Rank1") -- Fallback to basic sound
          end
        end

        -- Mark as processed
        self.processedKills[killID] = GetTime()

        -- Record that this killer was matched to prevent generic entry
        matchedKillers[killer] = true

        -- Remove the matched victim so they don't get matched again
        newVictims[matchedVictim] = nil
      end
    end
  end

  -- For remaining unmatched killers, create generic entries
  for killer, killerTime in pairs(newKillers) do
    -- Only create generic entries for killers that didn't get matched to a specific victim
    if not matchedKillers[killer] then
      local killerFaction = self.playerData[killer].faction == 0 and "Horde" or "Alliance"
      local enemyFaction = killerFaction == "Horde" and "Alliance" or "Horde"

      -- Create a unique ID for this kill
      local killID = killer .. "generic" .. tostring(math.floor(killerTime))

      -- Only add if we haven't processed this kill before
      if not self.processedKills[killID] then
        -- Clean name for consistency
        local cleanKillerName = self:RemoveServerName(killer)

        -- Update killer's rank first
        if BGKF.db.profile.ranks.enabled and BGKF.modules.RankSystem then
          -- Only update once with the normalized name
          cleanKillerName = self:RemoveServerName(killer)
          BGKF.modules.RankSystem:UpdateRank(cleanKillerName, 1)
        end

        -- Create the generic kill feed entry
        self:AddGenericKill(killer, self.playerData[killer].class, enemyFaction)

        -- Play sound if enabled
        if BGKF.db.profile.sounds.enabled and BGKF.modules.SoundSystem then
          -- Check which method exists and use it
          if BGKF.modules.SoundSystem.PlayRankSound then
            BGKF.modules.SoundSystem:PlayRankSound(killer)
          elseif BGKF.modules.SoundSystem.PlayKillSound then
            BGKF.modules.SoundSystem:PlayKillSound(killer)
          elseif BGKF.modules.SoundSystem.PlaySound then
            BGKF.modules.SoundSystem:PlaySound("Rank1") -- Fallback to basic sound
          end
        end

        -- Mark as processed
        self.processedKills[killID] = GetTime()
      end
    end
  end

  -- Clean up old tracking data (older than 60 seconds)
  self:CleanupTrackingData()
end

-- Clean up old tracking data
function KillFeed:CleanupTrackingData()
  local now = GetTime()
  local cutoffTime = now - 60 -- 1 minute cutoff

  -- Clean up old entries
  for killID, timestamp in pairs(self.processedKills) do
    if timestamp < cutoffTime then
      self.processedKills[killID] = nil
    end
  end
end

-- Updated function to get PvP rank icons based on kill count and faction
function KillFeed:GetPvPRankIcon(playerName)
  -- If ranks are disabled, return empty string (no icon)
  if not BGKF.db.profile.ranks.enabled then
    return ""
  end

  local rankIndex = 1 -- Default to rank 1

  -- Try to get player's rank from RankSystem
  if BGKF.modules.RankSystem and playerName then
    rankIndex = BGKF.modules.RankSystem:GetPlayerRank(playerName)
  elseif self.playerData[playerName] then
    -- Fallback to killingBlows if RankSystem isn't available
    rankIndex = math.min(math.floor(self.playerData[playerName].killingBlows or 0), 14)
    if rankIndex <= 0 then rankIndex = 1 end
  end

  -- Make sure icon number is valid (1-14)
  if rankIndex < 1 then rankIndex = 1 end
  if rankIndex > 14 then rankIndex = 14 end

  -- PvP rank icons are stored in Interface\\PvPRankBadges\\
  local iconPath = "Interface\\PvPRankBadges\\PvPRank"

  -- Format the icon string
  local icon = string.format("|T%s%02d:16:16:0:0:16:16:0:16:0:16|t", iconPath, rankIndex)

  return icon
end

function KillFeed:OnRankChanged(event, playerName)
  -- Force a redraw of all kill feed entries
  self:UpdateLayout()
end

-- Add a kill to the feed
-- Add a kill to the feed
function KillFeed:AddKill(killerName, killerClass, victimName, victimClass)
  local frame = self.frame
  local config = BGKF.db.profile.killFeed

  -- Clean up player names by removing server names
  local cleanKillerName = self:RemoveServerName(killerName)
  local cleanVictimName = self:RemoveServerName(victimName)

  -- Create new entry frame
  local entry = CreateFrame("Frame", nil, frame)
  entry:SetHeight(config.fontSize + 4)
  entry:SetWidth(config.width)

  -- Create text
  entry.text = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  entry.text:SetFont("Fonts\\FRIZQT__.TTF", config.fontSize, "OUTLINE")

  -- Get class colors for names
  -- Convert class to uppercase for RAID_CLASS_COLORS lookup
  local killerClassToken = string.upper(killerClass or "WARRIOR")
  local victimClassToken = string.upper(victimClass or "WARRIOR")

  local killerClassColor = RAID_CLASS_COLORS[killerClassToken] or RAID_CLASS_COLORS["WARRIOR"]
  local victimClassColor = RAID_CLASS_COLORS[victimClassToken] or RAID_CLASS_COLORS["WARRIOR"]

  -- Get killer and victim kill counts
  local killerKills = 0
  local victimKills = 0

  if self.playerData[killerName] then
    killerKills = self.playerData[killerName].killingBlows or 0
  end

  if self.playerData[victimName] then
    victimKills = self.playerData[victimName].killingBlows or 0
  end

  -- Get PvP rank icons
  local killerRankIcon = self:GetPvPRankIcon(killerName)
  local victimRankIcon = self:GetPvPRankIcon(victimName)

  -- Format class colored names
  local killerColoredName = string.format("|cFF%02x%02x%02x%s|r",
    killerClassColor.r * 255,
    killerClassColor.g * 255,
    killerClassColor.b * 255,
    cleanKillerName) -- Use clean name without server

  local victimColoredName = string.format("|cFF%02x%02x%02x%s|r",
    victimClassColor.r * 255,
    victimClassColor.g * 255,
    victimClassColor.b * 255,
    cleanVictimName) -- Use clean name without server

  -- Get faction icons
  local killerFaction = "Alliance"
  local victimFaction = "Alliance"

  if self.playerData[killerName] then
    killerFaction = self.playerData[killerName].faction == 0 and "Horde" or "Alliance"
  elseif killerName:find("Horde") then
    killerFaction = "Horde"
  end

  if self.playerData[victimName] then
    victimFaction = self.playerData[victimName].faction == 0 and "Horde" or "Alliance"
  elseif victimName:find("Horde") then
    victimFaction = "Horde"
  end

  -- And replace with (for example, 20x20 icons):
  local killerIcon = killerFaction == "Horde"
      and "|TInterface\\TargetingFrame\\UI-PVP-Horde:20:20:0:0:64:64:0:40:0:40|t "
      or "|TInterface\\TargetingFrame\\UI-PVP-Alliance:20:20:0:0:64:64:0:40:0:40|t "

  local victimIcon = victimFaction == "Horde"
      and " |TInterface\\TargetingFrame\\UI-PVP-Horde:20:20:0:0:64:64:0:40:0:40|t"
      or " |TInterface\\TargetingFrame\\UI-PVP-Alliance:20:20:0:0:64:64:0:40:0:40|t"

  -- Format text with more spacing and rank icons after names
  local timeText = config.showTimestamp and "[" .. date("%H:%M:%S", time()) .. "] " or ""

  entry.text:SetText(timeText ..
    (config.showIcons and killerIcon or "") .. killerColoredName .. " " .. killerRankIcon .. "   killed   " ..
    victimColoredName .. (config.showIcons and victimIcon or ""))
  entry.text:SetPoint("LEFT", entry, "LEFT", 5, 0)

  -- Trigger a sound event if the killer or victim is the local player
  local playerName = UnitName("player")
  if (killerName == playerName or cleanKillerName == playerName) and BGKF.modules.SoundSystem then
    -- Play the rank-based sound
    BGKF.modules.SoundSystem:PlayRankSound(playerName)
  end

  -- If the player was killed, play death sound
  if (victimName == playerName or cleanVictimName == playerName) and BGKF.modules.SoundSystem then
    BGKF.modules.SoundSystem:PlayDeathSound()
  end

  -- Add to entries table and position it
  table.insert(frame.entries, entry) -- Add to end of list (oldest at top, newest at bottom)
  self:RepositionEntries()

  -- Schedule fade out (if not permanent)
  if not config.permanentKills and config.fadeTime > 0 then
    self:ScheduleTimer("FadeOutEntry", config.fadeTime, entry)
  end

  -- Remove excess entries
  if #frame.entries > config.entries then
    local oldEntry = table.remove(frame.entries, 1) -- Remove oldest (top) entry
    oldEntry:Hide()
    oldEntry:SetParent(nil)
  end
end

-- Update the AddGenericKill function to use PvP rank icons
function KillFeed:AddGenericKill(killerName, killerClass, enemyFaction)
  local frame = self.frame
  local config = BGKF.db.profile.killFeed

  -- Clean up player name by removing server names
  local cleanKillerName = self:RemoveServerName(killerName)

  -- Create new entry frame
  local entry = CreateFrame("Frame", nil, frame)
  entry:SetHeight(config.fontSize + 4)
  entry:SetWidth(config.width)

  -- Create text
  entry.text = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  entry.text:SetFont("Fonts\\FRIZQT__.TTF", config.fontSize, "OUTLINE")

  -- Get class color for killer
  -- Convert class to uppercase for RAID_CLASS_COLORS lookup
  local killerClassToken = string.upper(killerClass or "WARRIOR")
  local killerClassColor = RAID_CLASS_COLORS[killerClassToken] or RAID_CLASS_COLORS["WARRIOR"]

  -- Get killer kill count
  local killerKills = 0

  if self.playerData[killerName] then
    killerKills = self.playerData[killerName].killingBlows or 0
  end

  -- Get PvP rank icon
  local killerRankIcon = self:GetPvPRankIcon(killerName)

  -- Format class colored name
  local killerColoredName = string.format("|cFF%02x%02x%02x%s|r",
    killerClassColor.r * 255,
    killerClassColor.g * 255,
    killerClassColor.b * 255,
    cleanKillerName) -- Use clean name without server

  -- Get faction icon
  local killerFaction = "Alliance"

  if self.playerData[killerName] then
    killerFaction = self.playerData[killerName].faction == 0 and "Horde" or "Alliance"
  elseif killerName:find("Horde") then
    killerFaction = "Horde"
  end

  local killerIcon = killerFaction == "Horde"
      and "|TInterface\\TargetingFrame\\UI-PVP-Horde:20:20:0:0:64:64:0:40:0:40|t "
      or "|TInterface\\TargetingFrame\\UI-PVP-Alliance:20:20:0:0:64:64:0:40:0:40|t "

  -- Format text with adjusted spacing and rank icon after name
  local timeText = config.showTimestamp and "[" .. date("%H:%M:%S", time()) .. "] " or ""

  entry.text:SetText(timeText ..
    (config.showIcons and killerIcon or "") ..
    killerColoredName .. " " .. killerRankIcon .. "   killed an enemy " .. enemyFaction)
  entry.text:SetPoint("LEFT", entry, "LEFT", 5, 0)

  -- Trigger a sound event if the killer is the local player
  local playerName = UnitName("player")
  if (killerName == playerName or cleanKillerName == playerName) and BGKF.modules.SoundSystem then
    -- Play the rank-based sound
    BGKF.modules.SoundSystem:PlayRankSound(playerName)
  end

  -- Add to entries table and position it
  table.insert(frame.entries, entry) -- Add to end of list (oldest at top, newest at bottom)
  self:RepositionEntries()

  -- Schedule fade out (if not permanent)
  if not config.permanentKills and config.fadeTime > 0 then
    self:ScheduleTimer("FadeOutEntry", config.fadeTime, entry)
  end

  -- Remove excess entries
  if #frame.entries > config.entries then
    local oldEntry = table.remove(frame.entries, 1) -- Remove oldest (top) entry
    oldEntry:Hide()
    oldEntry:SetParent(nil)
  end
end

-- Position all entries in the kill feed
function KillFeed:RepositionEntries()
  local frame = self.frame
  local yOffset = 20 -- Start below the title bar

  for i, entry in ipairs(frame.entries) do
    entry:ClearAllPoints()
    entry:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -yOffset)
    entry:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -yOffset)
    yOffset = yOffset + entry:GetHeight()
  end
end

-- Fade out and remove an entry
function KillFeed:FadeOutEntry(entry)
  -- Create animation
  if not entry.fadeAnim then
    entry.fadeAnim = entry:CreateAnimationGroup()
    local fade = entry.fadeAnim:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(1)

    entry.fadeAnim:SetScript("OnFinished", function()
      -- Remove from entries table
      for i, e in ipairs(self.frame.entries) do
        if e == entry then
          table.remove(self.frame.entries, i)
          break
        end
      end

      -- Reposition remaining entries
      self:RepositionEntries()

      -- Clean up
      entry:Hide()
      entry:SetParent(nil)
    end)
  end

  -- Start fade animation
  entry.fadeAnim:Play()
end

-- Clear all entries
function KillFeed:ClearEntries()
  for _, entry in ipairs(self.frame.entries) do
    entry:Hide()
    entry:SetParent(nil)
  end

  self.frame.entries = {}
end

-- Update layout when settings change
function KillFeed:UpdateLayout()
  local frame = self.frame
  local config = BGKF.db.profile.killFeed

  -- Update dimensions
  frame:SetWidth(config.width)
  frame:SetHeight(config.height)

  -- Update background
  local bg = config.backgroundColor
  frame.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)

  -- Update existing entries
  for _, entry in ipairs(frame.entries) do
    entry:SetWidth(config.width)
    entry:SetHeight(config.fontSize + 4)
    entry.text:SetFont("Fonts\\FRIZQT__.TTF", config.fontSize, "OUTLINE")
  end

  -- Reposition entries
  self:RepositionEntries()
end

-- Update score timer when frequency changes
function KillFeed:UpdateScoreTimer()
  -- Cancel existing timer
  if self.scoreTimer then
    self:CancelTimer(self.scoreTimer)
  end

  -- Create new timer with updated frequency
  self.scoreTimer = self:ScheduleRepeatingTimer("RequestScoreData", BGKF.db.profile.killFeed.updateFrequency)
end

-- Update configuration (called when settings change)
function KillFeed:UpdateConfig()
  -- Update frame layout
  self:UpdateLayout()
end

function KillFeed:OnRankChanged(event, playerName)
  -- Force a redraw of all kill feed entries
  self:UpdateLayout()
end

-- Test mode function - simulates some kills
function KillFeed:StartTestMode()
  if not self:IsEnabled() then
    self:Enable() -- Enable module if disabled
  end

  -- Create some test player data with existing factions and classes
  local testData = {
    ["AllyWarrior"] = { faction = 1, class = "Warrior" },
    ["AllyPaladin"] = { faction = 1, class = "Paladin" },
    ["AllyHunter"] = { faction = 1, class = "Hunter" },
    ["AllyRogue"] = { faction = 1, class = "Rogue" },
    ["AllyPriest"] = { faction = 1, class = "Priest" },
    ["HordeWarrior"] = { faction = 0, class = "Warrior" },
    ["HordePaladin"] = { faction = 0, class = "Paladin" },
    ["HordeHunter"] = { faction = 0, class = "Hunter" },
    ["HordeRogue"] = { faction = 0, class = "Rogue" },
    ["HordeShaman"] = { faction = 0, class = "Shaman" },
  }

  -- Add test data to player data
  for name, data in pairs(testData) do
    self.playerData[name] = {
      killingBlows = math.random(0, 10),
      honorableKills = math.random(10, 30),
      deaths = math.random(0, 8),
      faction = data.faction,
      class = data.class,
      lastUpdated = GetTime()
    }
  end

  -- Schedule some test kills
  local playerFaction = select(1, UnitFactionGroup("player")) == "Horde" and 0 or 1
  local delay = 1

  -- Loop through and create some kills between opposing factions
  for name, data in pairs(testData) do
    C_Timer.After(delay, function()
      if data.faction == playerFaction then
        -- Same faction as player, make them kill an enemy
        local enemies = {}
        for enemyName, enemyData in pairs(testData) do
          if enemyData.faction ~= playerFaction then
            table.insert(enemies, enemyName)
          end
        end

        if #enemies > 0 then
          local victim = enemies[math.random(1, #enemies)]
          self:AddKill(name, data.class, victim, self.playerData[victim].class)
        else
          self:AddGenericKill(name, data.class, playerFaction == 0 and "Alliance" or "Horde")
        end
      else
        -- Enemy faction, make them kill an ally
        local allies = {}
        for allyName, allyData in pairs(testData) do
          if allyData.faction == playerFaction then
            table.insert(allies, allyName)
          end
        end

        if #allies > 0 then
          local victim = allies[math.random(1, #allies)]
          self:AddKill(name, data.class, victim, self.playerData[victim].class)
        else
          self:AddGenericKill(name, data.class, playerFaction == 1 and "Alliance" or "Horde")
        end
      end
    end)

    delay = delay + 2 -- Add 2 seconds between kills
  end

  -- Add the player if they make a killing blow
  C_Timer.After(delay, function()
    local playerName = UnitName("player")
    local _, playerClass = UnitClass("player")

    for name, data in pairs(testData) do
      if data.faction ~= playerFaction then
        self:AddKill(playerName, playerClass, name, data.class)
        break
      end
    end
  end)

  BGKF:Print("Test mode started. Showing simulated kills...")
end
