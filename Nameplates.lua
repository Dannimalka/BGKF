-- BGKF: Improved Nameplate Integration Module

local BGKF = LibStub("AceAddon-3.0"):GetAddon("BGKF")
local Nameplates = BGKF:NewModule("Nameplates", "AceEvent-3.0")

-- Storage for nameplate frames
Nameplates.rankFrames = {}

-- Module initialization
function Nameplates:OnInitialize()
  -- Store in modules for easy access
  BGKF.modules.Nameplates = self
end

-- Enable module
function Nameplates:OnEnable()
  -- Only set up hooks if enabled
  if BGKF.db.profile.ranks.showOnNameplates then
    self:SetupEvents()
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
end

-- Set up nameplate events
function Nameplates:SetupEvents()
  -- Register nameplate events
  self:RegisterEvent("NAME_PLATE_UNIT_ADDED", "OnNamePlateAdded")
  self:RegisterEvent("NAME_PLATE_UNIT_REMOVED", "OnNamePlateRemoved")

  -- Also listen for rank changes to update icons
  self:RegisterMessage("BGKF_RANK_CHANGED", "OnRankChanged")
end

-- Get PvP rank icon for nameplates
function Nameplates:GetRankIcon(playerName)
  local rankIndex = 1 -- Default to rank 1

  -- Get player's rank from RankSystem
  if BGKF.modules.RankSystem and playerName then
    rankIndex = BGKF.modules.RankSystem:GetPlayerRank(playerName)
    -- Debug print for rank checking
    --BGKF:Print("GetRankIcon for " .. playerName .. " = rank " .. rankIndex)
  elseif BGKF.modules.KillFeed and
      BGKF.modules.KillFeed.playerData and
      BGKF.modules.KillFeed.playerData[playerName] then
    -- Fallback to killingBlows from KillFeed
    rankIndex = math.min(math.floor(BGKF.modules.KillFeed.playerData[playerName].killingBlows or 0), 14)
    if rankIndex <= 0 then rankIndex = 1 end
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

  -- Get the nameplate frame
  local nameplate = C_NamePlate.GetNamePlateForUnit(unitToken)
  if not nameplate then return end

  -- Create or get the rank frame for this player
  local rankFrame = self:GetRankFrame(name)

  -- Attach to nameplate
  rankFrame:SetParent(nameplate)
  rankFrame:ClearAllPoints()

  -- Change this line to position the rank on the side of the nameplate
  rankFrame:SetPoint("LEFT", nameplate.UnitFrame.name, "RIGHT", 2, 0)

  -- Update icon texture
  local iconPath = self:GetRankIcon(name)
  rankFrame.icon:SetTexture(iconPath)

  -- Show the frame
  rankFrame:Show()
end

-- Handle nameplate removed event
function Nameplates:OnNamePlateRemoved(event, unitToken)
  local name = UnitName(unitToken)
  if name and self.rankFrames[name] then
    self.rankFrames[name]:Hide()
  end
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
  end

  return self.rankFrames[playerName]
end

-- Handle rank changed event
function Nameplates:OnRankChanged(event, playerName)
  -- Update the player's rank frame if it exists
  if self.rankFrames[playerName] and self.rankFrames[playerName]:IsShown() then
    local iconPath = self:GetRankIcon(playerName)
    self.rankFrames[playerName].icon:SetTexture(iconPath)
    --BGKF:Print("Updated nameplate rank icon for " .. playerName)
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
end

-- Update nameplate hooks based on settings
function Nameplates:UpdateHooks(enabled)
  if enabled then
    self:SetupEvents()
    self:UpdateAllNameplates()
  else
    self:UnregisterAllEvents()

    -- Hide all rank frames
    for _, frame in pairs(self.rankFrames) do
      frame:Hide()
    end
  end
end

-- Update configuration (called when settings change)
function Nameplates:UpdateConfig()
  self:UpdateHooks(BGKF.db.profile.ranks.showOnNameplates)
end
