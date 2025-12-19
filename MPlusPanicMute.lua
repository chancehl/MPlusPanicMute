local addonName = ...
local addon = {}

-- Binding labels (shown in the in-game keybinds menu).
BINDING_HEADER_MPLUSPANICMUTE = "M+ Panic Mute"
BINDING_NAME_MPLUSPANICMUTE_BINDING_MUTE = "Mute current party"

local playerFullName

local function formatName(name, realm)
  if not name then
    return nil
  end

  if not realm or realm == "" then
    realm = GetNormalizedRealmName() or ""
  end

  if realm ~= "" then
    return string.format("%s-%s", name, realm)
  end

  return name
end

function addon:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00d8ffM+ Mute:|r %s", msg))
end

function addon:GetFullUnitName(unit)
  local name, realm = UnitFullName(unit)
  return formatName(name, realm)
end

function addon:CollectGroupUnits()
  local units = {}

  if IsInRaid() then
    for i = 1, 40 do
      local unit = string.format("raid%d", i)
      if UnitExists(unit) then
        table.insert(units, unit)
      end
    end
  elseif IsInGroup() then
    for i = 1, 4 do
      local unit = string.format("party%d", i)
      if UnitExists(unit) then
        table.insert(units, unit)
      end
    end
  end

  return units
end

function addon:MuteGroup()
  if not IsInGroup() then
    self:Print("You are not in a party. Nothing to mute.")
    return
  end

  local units = self:CollectGroupUnits()
  if #units == 0 then
    self:Print("No party members found to mute.")
    return
  end

  local added, already, failed = {}, {}, {}

  for _, unit in ipairs(units) do
    local fullName = self:GetFullUnitName(unit)

    if fullName and fullName ~= playerFullName then
      if C_FriendList.IsIgnored(fullName) then
        table.insert(already, fullName)
      else
        C_FriendList.AddIgnore(fullName)
        if C_FriendList.IsIgnored(fullName) then
          table.insert(added, fullName)
        else
          table.insert(failed, fullName)
        end
      end
    end
  end

  if #added == 0 and #already == 0 and #failed == 0 then
    self:Print("No one else is in your party to mute.")
    return
  end

  local parts = {}
  if #added > 0 then
    table.insert(parts, string.format("Muted: %s", table.concat(added, ", ")))
  end
  if #already > 0 then
    table.insert(parts, string.format("Already ignored: %s", table.concat(already, ", ")))
  end
  if #failed > 0 then
    table.insert(parts, string.format("Failed: %s", table.concat(failed, ", ")))
  end

  self:Print(table.concat(parts, " | "))
end

function addon:BuildFrame()
  if self.frame then
    return
  end

  local f = CreateFrame("Frame", "MPlusPanicMuteFrame", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(240, 110)
  f:SetPoint("CENTER")
  f:Hide()

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.title:SetPoint("LEFT", f.TitleBg, "LEFT", 5, 0)
  f.title:SetText("M+ Panic Mute")

  local button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  button:SetSize(170, 26)
  button:SetPoint("TOP", f, "TOP", 0, -36)
  button:SetText("Mute current group")
  button:SetScript("OnClick", function()
    addon:MuteGroup()
  end)

  local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("TOP", button, "BOTTOM", 0, -8)
  label:SetText("Click or bind a key to ignore your party.\nSlash: /mplusmute")

  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)

  self.frame = f
end

function addon:ToggleFrame()
  if not self.frame then
    self:BuildFrame()
  end

  if self.frame:IsShown() then
    self.frame:Hide()
  else
    self.frame:Show()
  end
end

-- Slash commands to show the panic button frame.
SLASH_MPLUSMUTE1 = "/mplusmute"
SLASH_MPLUSMUTE2 = "/mppm"
SlashCmdList.MPLUSMUTE = function()
  addon:ToggleFrame()
end

-- Global function used by the keybinding.
function MPlusPanicMute_MuteGroup()
  addon:MuteGroup()
end

-- Initialize player name on login to avoid nils before the player is fully loaded.
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function()
  playerFullName = addon:GetFullUnitName("player")
  addon:BuildFrame()
end)
