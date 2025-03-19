-- BGKF: Simplified Nameplate Integration Module

local BGKF = LibStub("AceAddon-3.0"):GetAddon("BGKF")
local Nameplates = BGKF:NewModule("Nameplates", "AceEvent-3.0")

-- Storage for nameplate frames and unit mappings
Nameplates.rankFrames = {}
Nameplates.unitMappings = {}
Nameplates.debugMode = false -- Set to false by default, will be updated from settings

-- Debug print function
function Nameplates:DebugPrint(...)
  if self.debugMode then
    BGKF:Print(...)
  end
end

-- Module initialization
function Nameplates:OnInitialize()
  -- Initialize debug mode from settings
  self.debugMode = BGKF.db.profile.debugMode

  -- Store in modules for easy access
  BGKF.modules.Nameplates = self
  self:DebugPrint("Nameplates module initialized")
end

-- Enable module
function Nameplates:OnEnable()
  -- Only set up hooks if enabled
  if BGKF.db.profile.ranks.showOnNameplates then
    self:SetupEvents()
    self:SetupPlayerFrameRank() -- Add this line
    self:DebugPrint("Nameplates hooks enabled")
  end
end

-- Disable module
function Nameplates:OnDisable()
  -- Unregister all events
  self:UnregisterAllEvents()

  -- Hide all rank frames
  for _, frame in pairs(self.rankFrames) do
    frame:Hide()
  end

  -- Hide player rank frame if it exists
  if self.playerRankFrame then
    self.playerRankFrame:Hide()
  end

  -- Clear mappings
  self.unitMappings = {}
  self:DebugPrint("Nameplates hooks disabled")
end

-- Set up nameplate events
function Nameplates:SetupEvents()
  -- Register nameplate events
  self:RegisterEvent("NAME_PLATE_UNIT_ADDED", "OnNamePlateAdded")
  self:RegisterEvent("NAME_PLATE_UNIT_REMOVED", "OnNamePlateRemoved")

  -- Also listen for rank changes to update icons
  self:RegisterMessage("BGKF_RANK_CHANGED", "OnRankChanged")

  -- Register for combat log to catch rank updates
  self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "ParseCombatLog")

  self:DebugPrint("Nameplate events registered")
end

-- Get PvP rank icon for nameplates
function Nameplates:GetRankIcon(playerName)
  local rankIndex = 1 -- Default to rank 1
  local normalizedName = BGKF:NormalizePlayerName(playerName)

  -- Get player's rank from RankSystem
  if BGKF.modules.RankSystem and normalizedName then
    rankIndex = BGKF.modules.RankSystem:GetPlayerRank(normalizedName)
    self:DebugPrint("Got rank for " .. normalizedName .. ": " .. rankIndex)
  elseif BGKF.modules.KillFeed and
      BGKF.modules.KillFeed.playerData and
      BGKF.modules.KillFeed.playerData[normalizedName] then
    -- Fallback to killingBlows from KillFeed
    rankIndex = math.min(math.floor(BGKF.modules.KillFeed.playerData[normalizedName].killingBlows or 0), 14)
    if rankIndex <= 0 then rankIndex = 1 end
    self:DebugPrint("Got fallback rank for " .. normalizedName .. ": " .. rankIndex)
  end

  -- Make sure icon number is valid (1-14)
  if rankIndex < 1 then rankIndex = 1 end
  if rankIndex > 14 then rankIndex = 14 end

  -- Return the icon path
  return string.format("Interface\\PvPRankBadges\\PvPRank%02d", rankIndex)
end

-- Handle nameplate added event
function Nameplates:OnNamePlateAdded(event, unitToken)
  if not BGKF.db.profile.ranks.showOnNameplates then return end

  -- Get the player name
  local name = UnitName(unitToken)
  if not name or not UnitIsPlayer(unitToken) then
    return
  end

  -- Normalize the name
  local normalizedName = BGKF:NormalizePlayerName(name)
  self:DebugPrint("Nameplate added for: " .. name .. " (Normalized: " .. normalizedName .. ")")

  -- Get the nameplate frame
  local nameplate = C_NamePlate.GetNamePlateForUnit(unitToken)
  if not nameplate then return end

  -- Store the unit token for this player for later updates
  self.unitMappings[normalizedName] = unitToken

  -- Create or get the rank frame for this player
  local rankFrame = self:GetRankFrame(normalizedName)

  -- Attach to nameplate
  rankFrame:SetParent(nameplate)
  rankFrame:ClearAllPoints()

  -- Position the icon on the right side of the nameplate
  rankFrame:SetPoint("RIGHT", nameplate, "RIGHT", 5, 0)
  self:DebugPrint("Positioned rank frame for " .. normalizedName .. " on right side of nameplate")

  -- Update icon texture
  local iconPath = self:GetRankIcon(normalizedName)
  rankFrame.icon:SetTexture(iconPath)

  -- Ensure the frame is visible
  rankFrame:Show()

  self:DebugPrint("Nameplate added for " .. normalizedName .. " with rank icon")
end

-- Handle nameplate removed event
function Nameplates:OnNamePlateRemoved(event, unitToken)
  local name = UnitName(unitToken)
  if not name then return end

  local normalizedName = BGKF:NormalizePlayerName(name)

  if self.rankFrames[normalizedName] then
    self.rankFrames[normalizedName]:Hide()
    self:DebugPrint("Nameplate removed for " .. normalizedName)
  end

  -- Clean up unit mapping
  self.unitMappings[normalizedName] = nil
end

-- Add this function to your Nameplates.lua file
function Nameplates:SetupPlayerFrameRank()
  -- Create a frame for the player's own rank
  if not self.playerRankFrame then
    local frame = CreateFrame("Frame", "BGKFPlayerRankFrame", PlayerFrame)

    -- Get the current player frame scale to determine appropriate size
    local parentScale = PlayerFrame:GetScale()
    local baseSize = 16     -- Base size for the icon
    local scaledSize = baseSize * parentScale

    frame:SetSize(scaledSize, scaledSize)

    -- Create icon texture
    frame.icon = frame:CreateTexture(nil, "OVERLAY")
    frame.icon:SetAllPoints()

    -- Position it to the LEFT of the player's level
    frame:ClearAllPoints()
    frame:SetPoint("RIGHT", PlayerLevelText, "LEFT", -5, 0)     -- Position left of level text

    -- Create a scale update function
    frame.UpdateScale = function()
      local newParentScale = PlayerFrame:GetScale()
      local newSize = baseSize * newParentScale
      frame:SetSize(newSize, newSize)
    end

    -- Register for player frame scale changes
    PlayerFrame:HookScript("OnSizeChanged", function()
      if frame.UpdateScale then
        frame.UpdateScale()
      end
    end)

    self.playerRankFrame = frame
    self:DebugPrint("Created player rank frame")
  end

  -- Update the player's rank icon
  local playerName = UnitName("player")
  local normalizedName = BGKF:NormalizePlayerName(playerName)
  local iconPath = self:GetRankIcon(normalizedName)
  self.playerRankFrame.icon:SetTexture(iconPath)
  self.playerRankFrame:Show()

  self:DebugPrint("Updated player rank frame: " .. playerName)
end

-- Create or get a rank frame for a player
function Nameplates:GetRankFrame(playerName)
  if not self.rankFrames[playerName] then
    -- Create new frame
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(16, 16)

    -- Create icon texture
    frame.icon = frame:CreateTexture(nil, "OVERLAY")
    frame.icon:SetAllPoints()

    -- Store in table
    self.rankFrames[playerName] = frame

    self:DebugPrint("Created new rank frame for " .. playerName)
  end

  return self.rankFrames[playerName]
end

-- Add this function to Nameplates module
function Nameplates:UpdateNameplateForPlayer(playerName)
  if not playerName then return end

  local normalizedTarget = BGKF:NormalizePlayerName(playerName)
  self:DebugPrint("Looking to update nameplates for player: " .. normalizedTarget)

  -- Find matching nameplates and update them
  for unitName, unitToken in pairs(self.unitMappings) do
    local normalizedUnit = BGKF:NormalizePlayerName(unitName)

    if normalizedUnit == normalizedTarget then
      self:DebugPrint("Found matching nameplate for: " .. normalizedTarget)
      if UnitExists(unitToken) then
        self:ForceUpdateNameplate(unitToken, unitName)
        self:DebugPrint("Forced update for nameplate: " .. unitName)
      end
    end
  end
end

-- Handle rank changed event
function Nameplates:OnRankChanged(event, playerName)
  self:DebugPrint("Rank changed event for " .. playerName)

  -- Check if it's the player's own rank that changed
  local playerNormalizedName = BGKF:NormalizePlayerName(UnitName("player"))
  local changedNormalizedName = BGKF:NormalizePlayerName(playerName)

  if playerNormalizedName == changedNormalizedName then
    self:SetupPlayerFrameRank() -- Update player's own rank display
  end

  -- Check all nameplates to see if any need updating based on this rank change
  self:UpdateAllNameplates()

  -- Also specifically update any nameplates for this player name
  for unitName, unitToken in pairs(self.unitMappings) do
    -- Check if the normalized names match
    local unitNormalizedName = BGKF:NormalizePlayerName(unitName)
    if unitNormalizedName == changedNormalizedName then
      if UnitExists(unitToken) then
        self:ForceUpdateNameplate(unitToken, unitName)
        self:DebugPrint("Updated nameplate for " .. unitName .. " due to rank change")
      end
    end
  end
end

-- Force update a specific nameplate
function Nameplates:ForceUpdateNameplate(unitToken, playerName)
  local nameplate = C_NamePlate.GetNamePlateForUnit(unitToken)
  if not nameplate then return end

  -- Use existing frame or create a new one
  local rankFrame = self.rankFrames[playerName]
  if not rankFrame then
    rankFrame = self:GetRankFrame(playerName)
  end

  -- Update icon texture
  local iconPath = self:GetRankIcon(playerName)
  rankFrame.icon:SetTexture(iconPath)

  -- Ensure correct position - Position on right side of nameplate
  rankFrame:ClearAllPoints()
  rankFrame:SetPoint("RIGHT", nameplate, "RIGHT", 5, 0)

  -- Ensure proper parent
  rankFrame:SetParent(nameplate)

  -- Show the frame
  rankFrame:Show()

  self:DebugPrint("Force updated nameplate for " .. playerName)
end

-- Parse combat log to catch player kills for rank updates
function Nameplates:ParseCombatLog()
  local timestamp, event, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags =
      CombatLogGetCurrentEventInfo()

  -- Check if this is a player kill event
  if event == "UNIT_DIED" and destName then
    -- Force update all nameplates to catch any rank changes
    self:UpdateAllNameplates()
  end
end

-- Update all visible nameplates
function Nameplates:UpdateAllNameplates()
  for i = 1, 40 do
    local unitToken = "nameplate" .. i
    if UnitExists(unitToken) then
      self:OnNamePlateAdded("NAME_PLATE_UNIT_ADDED", unitToken)
    end
  end
  self:DebugPrint("Updated all nameplates")
end

-- Update nameplate hooks based on settings
function Nameplates:UpdateHooks(enabled)
  if enabled then
    self:SetupEvents()
    self:UpdateAllNameplates()
    self:DebugPrint("Nameplate hooks updated - enabled")
  else
    self:UnregisterAllEvents()

    -- Hide all rank frames
    for _, frame in pairs(self.rankFrames) do
      frame:Hide()
    end

    -- Clear mappings
    self.unitMappings = {}
    self:DebugPrint("Nameplate hooks updated - disabled")
  end
end

-- Update configuration (called when settings change)
function Nameplates:UpdateConfig()
  -- Update debug mode
  self.debugMode = BGKF.db.profile.debugMode

  -- Update hooks
  self:UpdateHooks(BGKF.db.profile.ranks.showOnNameplates)
end
