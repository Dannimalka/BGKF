-- BGKF: Kill Feed Module

local BGKF = LibStub("AceAddon-3.0"):GetAddon("BGKF")
local KillFeed = BGKF:NewModule("KillFeed", "AceEvent-3.0", "AceTimer-3.0")

-- Module initialization
function KillFeed:OnInitialize()
  -- Create main frame for kill feed
  self:CreateFrame()

  -- Storage for player data
  self.playerData = {}
  self.lastScoreCheck = {}

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
  frame.titleText:SetText("BGKF Kill Feed")

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

  -- Initial score check
  self:CheckBattlefieldScores()

  -- Set up timer to check scores regularly
  self.scoreTimer = self:ScheduleRepeatingTimer("CheckBattlefieldScores", 1)

  -- Register for battleground events
  self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE", "CheckBattlefieldScores")
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

-- Check battlefield scores for new kills
function KillFeed:CheckBattlefieldScores()
  local numScores = GetNumBattlefieldScores()

  -- If no scores are available, return
  if numScores == 0 then
    return
  end

  for i = 1, numScores do
    local name, killingBlows, honorableKills, deaths, honorGained, faction, race, class = GetBattlefieldScore(i)

    -- Skip if no name
    if not name then
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
        class = class,
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
      local newHonorableKills = honorableKills -
      (self.lastScoreCheck[name] and self.lastScoreCheck[name].honorableKills or 0)

      -- If player got new kills, try to find victims
      if newKillingBlows > 0 or newHonorableKills > 0 then
        self:ProcessNewKills(name, class, newKillingBlows, newHonorableKills)
      end

      -- Check for new deaths (reset kill streak if died)
      local newDeaths = deaths - (self.lastScoreCheck[name] and self.lastScoreCheck[name].deaths or 0)
      if newDeaths > 0 and BGKF.modules.SoundSystem then
        BGKF.modules.SoundSystem:ResetKillStreak(name)
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
end

-- Process new kills
function KillFeed:ProcessNewKills(killerName, killerClass, newKillingBlows, newHonorableKills)
  -- Look for recently deceased players
  local potentialVictims = {}
  local killerFaction = self.playerData[killerName].faction

  for playerName, data in pairs(self.playerData) do
    -- Only consider players of the opposite faction who died recently
    if playerName ~= killerName and
        data.faction ~= killerFaction and
        data.deaths > (self.lastScoreCheck[playerName] and self.lastScoreCheck[playerName].deaths or 0) then
      -- Calculate time since death
      local timeSinceDeath = GetTime() - data.lastUpdated

      -- Only consider recent deaths (within last 10 seconds)
      if timeSinceDeath < 10 then
        table.insert(potentialVictims, {
          name = playerName,
          class = data.class,
          timeSinceDeath = timeSinceDeath
        })
      end
    end
  end

  -- Sort victims by time (most recent first)
  table.sort(potentialVictims, function(a, b)
    return a.timeSinceDeath < b.timeSinceDeath
  end)

  -- Process kills
  local totalNewKills = newKillingBlows + newHonorableKills
  for i = 1, math.min(totalNewKills, #potentialVictims) do
    local victim = potentialVictims[i]

    -- Add to kill feed
    self:AddKill(killerName, killerClass, victim.name, victim.class)

    -- Update ranks if enabled
    if BGKF.db.profile.ranks.enabled and BGKF.modules.RankSystem then
      BGKF.modules.RankSystem:UpdateRank(killerName, 1)       -- Increase rank
    end

    -- Play sound if enabled
    if BGKF.db.profile.sounds.enabled and BGKF.modules.SoundSystem then
      BGKF.modules.SoundSystem:PlayKillSound(killerName)
    end
  end

  -- If we couldn't find enough victims, create generic entries
  for i = #potentialVictims + 1, totalNewKills do
    -- Create a generic kill message with unknown victim
    self:AddGenericKill(killerName, killerClass, (killerFaction == 0) and "Alliance" or "Horde")

    -- Update ranks if enabled
    if BGKF.db.profile.ranks.enabled and BGKF.modules.RankSystem then
      BGKF.modules.RankSystem:UpdateRank(killerName, 1)       -- Increase rank
    end

    -- Play sound if enabled
    if BGKF.db.profile.sounds.enabled and BGKF.modules.SoundSystem then
      BGKF.modules.SoundSystem:PlayKillSound(killerName)
    end
  end
end

-- Add a kill to the feed
function KillFeed:AddKill(killerName, killerClass, victimName, victimClass)
  local frame = self.frame
  local config = BGKF.db.profile.killFeed

  -- Create new entry frame
  local entry = CreateFrame("Frame", nil, frame)
  entry:SetHeight(config.fontSize + 4)
  entry:SetWidth(config.width)

  -- Create text
  entry.text = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  entry.text:SetFont("Fonts\\FRIZQT__.TTF", config.fontSize, "OUTLINE")

  -- Get class colors for names
  -- Convert class to uppercase for RAID_CLASS_COLORS lookup
  local killerClassToken = string.upper(killerClass)
  local victimClassToken = string.upper(victimClass)

  local killerClassColor = RAID_CLASS_COLORS[killerClassToken] or RAID_CLASS_COLORS["WARRIOR"]
  local victimClassColor = RAID_CLASS_COLORS[victimClassToken] or RAID_CLASS_COLORS["WARRIOR"]

  -- Get killer's score if available
  local killerScore = ""
  if self.playerData[killerName] and self.playerData[killerName].killingBlows > 0 then
    killerScore = " |cFFFFFF00[" .. self.playerData[killerName].killingBlows .. "]|r"
  end

  -- Get victim's score if available
  local victimScore = ""
  if self.playerData[victimName] and self.playerData[victimName].killingBlows > 0 then
    victimScore = " |cFFFFFF00[" .. self.playerData[victimName].killingBlows .. "]|r"
  end

  -- Format class colored names
  local killerColoredName = string.format("|cFF%02x%02x%02x%s|r",
    killerClassColor.r * 255,
    killerClassColor.g * 255,
    killerClassColor.b * 255,
    killerName)

  local victimColoredName = string.format("|cFF%02x%02x%02x%s|r",
    victimClassColor.r * 255,
    victimClassColor.g * 255,
    victimClassColor.b * 255,
    victimName)

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

  local killerIcon = killerFaction == "Horde"
      and "|TInterface\\TargetingFrame\\UI-PVP-Horde:14:14:0:0:64:64:0:40:0:40|t "
      or "|TInterface\\TargetingFrame\\UI-PVP-Alliance:14:14:0:0:64:64:0:40:0:40|t "

  local victimIcon = victimFaction == "Horde"
      and " |TInterface\\TargetingFrame\\UI-PVP-Horde:14:14:0:0:64:64:0:40:0:40|t"
      or " |TInterface\\TargetingFrame\\UI-PVP-Alliance:14:14:0:0:64:64:0:40:0:40|t"

  -- Format text
  local timeText = config.showTimestamp and "[" .. date("%H:%M:%S", time()) .. "] " or ""

  entry.text:SetText(timeText ..
  killerIcon .. killerColoredName .. killerScore .. " killed " .. victimColoredName .. victimScore .. victimIcon)
  entry.text:SetPoint("LEFT", entry, "LEFT", 5, 0)

  -- Add to entries table and position it
  table.insert(frame.entries, entry)   -- Add to end of list (oldest at top, newest at bottom)
  self:RepositionEntries()

  -- Schedule fade out (if not permanent)
  if not config.permanentKills and config.fadeTime > 0 then
    self:ScheduleTimer("FadeOutEntry", config.fadeTime, entry)
  end

  -- Remove excess entries
  if #frame.entries > config.entries then
    local oldEntry = table.remove(frame.entries, 1)     -- Remove oldest (top) entry
    oldEntry:Hide()
    oldEntry:SetParent(nil)
  end
end

-- Add a generic kill to the feed (when victim is unknown)
function KillFeed:AddGenericKill(killerName, killerClass, enemyFaction)
  local frame = self.frame
  local config = BGKF.db.profile.killFeed

  -- Create new entry frame
  local entry = CreateFrame("Frame", nil, frame)
  entry:SetHeight(config.fontSize + 4)
  entry:SetWidth(config.width)

  -- Create text
  entry.text = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  entry.text:SetFont("Fonts\\FRIZQT__.TTF", config.fontSize, "OUTLINE")

  -- Get class color for killer
  -- Convert class to uppercase for RAID_CLASS_COLORS lookup
  local killerClassToken = string.upper(killerClass)
  local killerClassColor = RAID_CLASS_COLORS[killerClassToken] or RAID_CLASS_COLORS["WARRIOR"]

  -- Get killer's score if available
  local killerScore = ""
  if self.playerData[killerName] and self.playerData[killerName].killingBlows > 0 then
    killerScore = " |cFFFFFF00[" .. self.playerData[killerName].killingBlows .. "]|r"
  end

  -- Format class colored name
  local killerColoredName = string.format("|cFF%02x%02x%02x%s|r",
    killerClassColor.r * 255,
    killerClassColor.g * 255,
    killerClassColor.b * 255,
    killerName)

  -- Get faction for killer
  local killerFaction = "Alliance"
  if self.playerData[killerName] and self.playerData[killerName].faction == 0 then
    killerFaction = "Horde"
  elseif killerName:find("Horde") then
    killerFaction = "Horde"
  end

  -- Get faction icons
  local killerIcon = killerFaction == "Horde"
      and "|TInterface\\TargetingFrame\\UI-PVP-Horde:14:14:0:0:64:64:0:40:0:40|t "
      or "|TInterface\\TargetingFrame\\UI-PVP-Alliance:14:14:0:0:64:64:0:40:0:40|t "

  -- Format text
  local timeText = config.showTimestamp and "[" .. date("%H:%M:%S", time()) .. "] " or ""

  entry.text:SetText(timeText .. killerIcon .. killerColoredName .. killerScore .. " killed an enemy " .. enemyFaction)
  entry.text:SetPoint("LEFT", entry, "LEFT", 5, 0)

  -- Add to entries table and position it
  table.insert(frame.entries, entry)   -- Add to end of list (oldest at top, newest at bottom)
  self:RepositionEntries()

  -- Schedule fade out (if not permanent)
  if not config.permanentKills and config.fadeTime > 0 then
    self:ScheduleTimer("FadeOutEntry", config.fadeTime, entry)
  end

  -- Remove excess entries
  if #frame.entries > config.entries then
    local oldEntry = table.remove(frame.entries, 1)     -- Remove oldest (top) entry
    oldEntry:Hide()
    oldEntry:SetParent(nil)
  end
end

-- Position all entries in the kill feed
function KillFeed:RepositionEntries()
  local frame = self.frame
  local yOffset = 20   -- Start below the title bar

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

-- Update configuration (called when settings change)
function KillFeed:UpdateConfig()
  -- Update frame layout
  self:UpdateLayout()
end
