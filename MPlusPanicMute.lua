local addonName = ...
local addon = {}

-- Binding labels (shown in the in-game keybinds menu).
BINDING_HEADER_MPLUSPANICMUTE = "M+ Panic Mute"

local playerFullName
local db
local muteButton
local pendingMute
local pendingMuteId = 0

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

local function shortName(fullName)
  return fullName and fullName:match("^[^-]+") or nil
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

  local short = normalize(shortName(fullName))
  if short and short ~= key then
    db.trackedIgnores[short] = { name = fullName, addedAt = time() }
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

  local short = normalize(shortName(fullName))
  if short then
    db.trackedIgnores[short] = nil
  end
end

function addon:GetTrackedNamesSet()
  local set = {}

  if not db or not db.trackedIgnores then
    return set
  end

  for _, info in pairs(db.trackedIgnores) do
    local norm = normalize(info.name)
    if norm then
      set[norm] = info.name
    end

    local short = normalize(shortName(info.name))
    if short then
      set[short] = info.name
    end
  end

  return set
end

function addon:BuildIgnoreSet()
  local set = {}
  for _, name in ipairs(self:GetIgnoreList()) do
    local norm = normalize(name)
    if norm then
      set[norm] = name
    end

    local short = normalize(shortName(name))
    if short then
      set[short] = name
    end
  end

  return set
end

function addon:IsIgnoredName(fullName, ignoreSet)
  if not fullName then
    return false
  end

  local norm = normalize(fullName)
  local short = normalize(shortName(fullName))
  ignoreSet = ignoreSet or self:BuildIgnoreSet()

  return (norm and ignoreSet[norm]) or (short and ignoreSet[short]) or false
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

function addon:ClearPartyIgnores()
  if not IsInGroup() or IsInRaid() then
    self:Print("You are not in a party. Nothing to clear.")
    return
  end

  local units = self:CollectGroupUnits()
  if #units == 0 then
    self:Print("No party members found to clear.")
    return
  end

  local partySet = {}
  for _, unit in ipairs(units) do
    local fullName = self:GetFullUnitName(unit)
    if fullName then
      local norm = normalize(fullName)
      if norm then
        partySet[norm] = true
      end

      local short = normalize(shortName(fullName))
      if short then
        partySet[short] = true
      end
    end
  end

  local tracked = self:GetTrackedNamesSet()
  local removed = {}

  for _, name in ipairs(self:GetIgnoreList()) do
    local norm = normalize(name)
    if partySet[norm] and tracked[norm] then
      C_FriendList.DelIgnore(name)
      self:ForgetTracked(name)
      table.insert(removed, name)
    end
  end

  if #removed == 0 then
    self:Print("No tracked party ignores to clear.")
    return
  end

  self:Print(string.format("Cleared %d party ignore(s).", #removed))
end

function addon:IsEligibleMythicParty()
  if not IsInGroup() or IsInRaid() then
    return false
  end

  local num = GetNumGroupMembers() or 0
  return num > 1 and num <= 5
end

function addon:UpdateMuteButtonState()
  if not muteButton then
    return
  end

  local enabled = self:IsEligibleMythicParty()
  muteButton:SetEnabled(enabled)

  if enabled then
    muteButton:EnableMouse(true)
    muteButton:SetAlpha(1)
  else
    muteButton:EnableMouse(false)
    muteButton:SetAlpha(0.5)
  end
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

function addon:ReportMuteResults(requested, already)
  local ignoreSet = self:BuildIgnoreSet()
  local added, failed = {}, {}

  for _, fullName in ipairs(requested) do
    if self:IsIgnoredName(fullName, ignoreSet) then
      table.insert(added, fullName)
      self:TrackIgnored(fullName)
    else
      table.insert(failed, fullName)
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

function addon:FlushMuteReport()
  if not pendingMute then
    return
  end

  local requested = pendingMute.requested or {}
  local already = pendingMute.already or {}
  pendingMute = nil

  self:ReportMuteResults(requested, already)
end

function addon:MuteGroup()
  if not IsInGroup() then
    self:Print("You are not in a party. Nothing to mute.")
    return
  end

  if not self:IsEligibleMythicParty() then
    self:Print("Mute is limited to 5-player (Mythic+) parties.")
    return
  end

  local units = self:CollectGroupUnits()
  if #units == 0 then
    self:Print("No party members found to mute.")
    return
  end

  local already, requested = {}, {}
  local ignoreSet = self:BuildIgnoreSet()

  for _, unit in ipairs(units) do
    local fullName = self:GetFullUnitName(unit)

    if fullName and fullName ~= playerFullName then
      if self:IsIgnoredName(fullName, ignoreSet) then
        table.insert(already, fullName)
      else
        C_FriendList.AddIgnore(fullName)
        table.insert(requested, fullName)
      end
    end
  end

  if #requested > 0 then
    pendingMuteId = pendingMuteId + 1
    local currentId = pendingMuteId
    pendingMute = { id = currentId, requested = requested, already = already }
    C_Timer.After(1.0, function()
      if pendingMute and pendingMute.id == currentId then
        addon:FlushMuteReport()
      end
    end)
  else
    self:ReportMuteResults(requested, already)
  end
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
  muteButton = button

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
  label:SetText("Keybind: AddOns → MPlusPanicMute\nSlash: /mplusmute | Clear tracked: /mplusclear")

  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)

  self.frame = f
  self:UpdateMuteButtonState()
end

function addon:ToggleFrame()
  if not self.frame then
    self:BuildFrame()
  end

  if self.frame:IsShown() then
    self.frame:Hide()
  else
    self.frame:Show()
    self:UpdateMuteButtonState()
  end
end

-- Global function used by the keybinding.
function MPlusPanicMute_MuteGroup()
  addon:MuteGroup()
end

-- Global function used by the keybinding.
function MPlusPanicMute_ClearPartyMutes()
  addon:ClearPartyIgnores()
end

-- Initialize player name on login to avoid nils before the player is fully loaded.
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
loginFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loginFrame:RegisterEvent("FRIENDLIST_UPDATE")
loginFrame:SetScript("OnEvent", function(_, event)
  if event == "FRIENDLIST_UPDATE" then
    if pendingMute then
      addon:FlushMuteReport()
    end
    return
  end

  addon:EnsureDB()
  playerFullName = addon:GetFullUnitName("player")
  addon:BuildFrame()
  addon:UpdateMuteButtonState()
end)

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
