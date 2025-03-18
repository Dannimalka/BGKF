-- BGKF: Nameplate Integration Module

local BGKF = LibStub("AceAddon-3.0"):GetAddon("BGKF")
local Nameplates = BGKF:NewModule("Nameplates", "AceHook-3.0")

-- Module initialization
function Nameplates:OnInitialize()
  -- Store in modules for easy access
  BGKF.modules.Nameplates = self
end

-- Enable module
function Nameplates:OnEnable()
  -- Only set up hooks if enabled
  if BGKF.db.profile.ranks.showOnNameplates then
    self:SetupHooks()
  end
end

-- Disable module
function Nameplates:OnDisable()
  -- Remove hooks
  self:UnhookAll()
end

-- Set up nameplate hooks
function Nameplates:SetupHooks()
  -- Unhook first to prevent double-hooking
  self:UnhookAll()

  -- Hook into nameplate creation/update
  self:SecureHook("CompactUnitFrame_UpdateName", "UpdateNameplate")
end

-- Update a nameplate with rank information
function Nameplates:UpdateNameplate(frame)
  if not frame or not frame.unit or not UnitIsPlayer(frame.unit) then
    return
  end

  -- Make sure the rank system is enabled
  if not BGKF.db.profile.ranks.enabled or not BGKF.db.profile.ranks.showOnNameplates then
    return
  end

  local name = UnitName(frame.unit)

  -- Only modify enemy nameplates
  if name and UnitIsEnemy("player", frame.unit) and BGKF.modules.RankSystem then
    local rankName = BGKF.modules.RankSystem:GetPlayerRankName(name)

    -- Update nameplate with rank
    if frame.name and rankName then
      frame.name:SetText("[" .. rankName .. "] " .. name)
    end
  end
end

-- Update all nameplates
function Nameplates:UpdateAllNameplates()
  -- Skip if module is disabled or hooks aren't set up
  if not self:IsHooked("CompactUnitFrame_UpdateName") then
    return
  end

  -- Force update all visible nameplates
  for i = 1, 40 do
    local nameplate = C_NamePlate.GetNamePlateForUnit("nameplate" .. i)
    if nameplate and nameplate.UnitFrame and nameplate.UnitFrame:IsVisible() then
      self:UpdateNameplate(nameplate.UnitFrame)
    end
  end
end

-- Update nameplate hooks based on settings
function Nameplates:UpdateHooks(enabled)
  if enabled then
    self:SetupHooks()
  else
    self:UnhookAll()
  end

  -- Update all existing nameplates
  if enabled then
    self:UpdateAllNameplates()
  end
end

-- Update configuration (called when settings change)
function Nameplates:UpdateConfig()
  self:UpdateHooks(BGKF.db.profile.ranks.showOnNameplates)
end
