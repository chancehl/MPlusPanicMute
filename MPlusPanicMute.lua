local addonName = ...
local addon = {}

-- Binding labels (shown in the in-game keybinds menu).
BINDING_HEADER_MPLUSPANICMUTE = "M+ Panic Mute"
BINDING_NAME_MPLUSPANICMUTE_BINDING_MUTE = "Mute current party"

local playerFullName
local db

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

local function normalize(name)
  return name and string.lower(name) or nil
end

function addon:EnsureDB()
  if not MPlusPanicMuteDB then
    MPlusPanicMuteDB = {}
  end

  if not MPlusPanicMuteDB.trackedIgnores then
    MPlusPanicMuteDB.trackedIgnores = {}
  end

  db = MPlusPanicMuteDB
end

function addon:TrackIgnored(fullName)
  if not db then
    return
  end

  local key = normalize(fullName)
  if key then
    db.trackedIgnores[key] = { name = fullName, addedAt = time() }
  end
end

function addon:ForgetTracked(fullName)
  if not db then
    return
  end

  local key = normalize(fullName)
  if key then
    db.trackedIgnores[key] = nil
  end
end

function addon:GetTrackedNamesSet()
  local set = {}

  if not db or not db.trackedIgnores then
    return set
  end

  for _, info in pairs(db.trackedIgnores) do
    set[normalize(info.name)] = info.name
  end

  return set
end

function addon:GetIgnoreList()
  local ignores = {}
  local num = C_FriendList.GetNumIgnores() or 0
  local getIgnoreName = C_FriendList.GetIgnoreName or GetIgnoreName

  for i = 1, num do
    local name = getIgnoreName(i)
    if name then
      table.insert(ignores, name)
    end
  end

  return ignores
end

function addon:ClearIgnores(opts)
  local onlyTracked = opts and opts.onlyTracked
  local names = self:GetIgnoreList()

  if #names == 0 then
    self:Print("Ignore list is already empty.")
    return
  end

  local tracked = self:GetTrackedNamesSet()
  local removed, skipped = {}, {}

  for _, name in ipairs(names) do
    local norm = normalize(name)
    if not onlyTracked or tracked[norm] then
      C_FriendList.DelIgnore(name)
      self:ForgetTracked(name)
      table.insert(removed, name)
    else
      table.insert(skipped, name)
    end
  end

  if #removed == 0 then
    self:Print(onlyTracked and "No tracked ignores to clear." or "Unable to clear ignores.")
    return
  end

  local parts = { string.format("Cleared %d ignore(s).", #removed) }
  if onlyTracked and #skipped > 0 then
    table.insert(parts, string.format("Skipped %d untracked.", #skipped))
  end

  self:Print(table.concat(parts, " "))
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
          self:TrackIgnored(fullName)
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
  f:SetSize(260, 180)
  f:SetPoint("CENTER")
  f:Hide()

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.title:SetPoint("LEFT", f.TitleBg, "LEFT", 5, 0)
  f.title:SetText("M+ Panic Mute")

  local button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  button:SetSize(190, 26)
  button:SetPoint("TOP", f, "TOP", 0, -36)
  button:SetText("Mute current group")
  button:SetScript("OnClick", function()
    addon:MuteGroup()
  end)

  local clearTrackedBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  clearTrackedBtn:SetSize(190, 22)
  clearTrackedBtn:SetPoint("TOP", button, "BOTTOM", 0, -10)
  clearTrackedBtn:SetText("Clear addon ignores")
  clearTrackedBtn:SetScript("OnClick", function()
    addon:ClearIgnores({ onlyTracked = true })
  end)

  local clearAllBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  clearAllBtn:SetSize(190, 22)
  clearAllBtn:SetPoint("TOP", clearTrackedBtn, "BOTTOM", 0, -6)
  clearAllBtn:SetText("Clear all ignores")
  clearAllBtn:SetScript("OnClick", function()
    addon:ClearIgnores({ onlyTracked = false })
  end)

  local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("TOP", clearAllBtn, "BOTTOM", 0, -10)
  label:SetText("Keybind: AddOns → M+ Panic Mute\nSlash: /mplusmute | Clear tracked: /mplusclear")

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

-- Slash command to clear only tracked ignores.
SLASH_MPLUSCLEARMUTE1 = "/mplusclear"
SlashCmdList.MPLUSCLEARMUTE = function()
  addon:ClearIgnores({ onlyTracked = true })
end

-- Global function used by the keybinding.
function MPlusPanicMute_MuteGroup()
  addon:MuteGroup()
end

-- Initialize player name on login to avoid nils before the player is fully loaded.
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function()
  addon:EnsureDB()
  playerFullName = addon:GetFullUnitName("player")
  addon:BuildFrame()
end)
