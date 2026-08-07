-- Stand-ins for the World of Warcraft client API, enough to load and drive
-- MPlusPanicMute.lua outside the game.
--
-- Two client behaviours are modelled deliberately, because the addon has code
-- that exists purely to work around them:
--
--   * C_FriendList.AddIgnore is asynchronous. A name does not appear on the
--     ignore list when you call it; the server answers later and the client
--     fires FRIENDLIST_UPDATE. Tests drive that with env:resolveIgnores().
--   * The ignore list stores same-realm players WITHOUT a realm suffix, so
--     "Bob-Illidan" comes back as plain "Bob" for a character on Illidan.
--
-- UnitFullName is likewise modelled to return a nil realm for same-realm
-- units, which is what the live client does.

local M = {}

M.PLAYER_REALM = "Illidan"
M.PLAYER_NAME = "Chance"

local function shortOf(name)
  return name and name:match("^[^-]+") or nil
end

local function realmOf(name)
  return name and name:match("%-(.+)$") or nil
end

local function lower(s)
  return s and s:lower() or nil
end

-- How the client's ignore list would store a name: bare for same-realm.
local function storedForm(name)
  local realm = realmOf(name)
  if not realm or realm == M.PLAYER_REALM then
    return shortOf(name)
  end
  return name
end

-- Which player a name refers to. The server resolves a name to a character,
-- so a bare name means "on my realm" and two Bobs on different realms are
-- two different people.
local function identity(name)
  if not name then
    return nil
  end
  return lower(shortOf(name)) .. "-" .. lower(realmOf(name) or M.PLAYER_REALM)
end

--------------------------------------------------------------------------
-- Frame stubs
--------------------------------------------------------------------------

local function newFontString()
  local fs = { text = nil }
  function fs:SetPoint() end
  function fs:SetText(t) self.text = t end
  function fs:GetText() return self.text end
  return fs
end

local function newFrame(env, frameType, name, parent, template)
  local frame = {
    frameType = frameType,
    frameName = name,
    parent = parent,
    template = template,
    shown = false,
    alpha = 1,
    enabled = true,
    mouseEnabled = false,
    text = nil,
    scripts = {},
    events = {},
    -- Provided by BasicFrameTemplateWithInset in the real client.
    TitleBg = {},
  }

  function frame:SetSize() end
  function frame:SetPoint() end
  function frame:SetMovable() end
  function frame:RegisterForDrag() end
  function frame:StartMoving() end
  function frame:StopMovingOrSizing() end
  function frame:SetText(t) self.text = t end
  function frame:GetText() return self.text end
  function frame:SetAlpha(a) self.alpha = a end
  function frame:GetAlpha() return self.alpha end
  function frame:SetEnabled(v) self.enabled = v and true or false end
  function frame:IsEnabled() return self.enabled end
  function frame:EnableMouse(v) self.mouseEnabled = v and true or false end
  function frame:Show() self.shown = true end
  function frame:Hide() self.shown = false end
  function frame:IsShown() return self.shown end
  function frame:CreateFontString() return newFontString() end
  function frame:SetScript(kind, fn) self.scripts[kind] = fn end
  function frame:GetScript(kind) return self.scripts[kind] end
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:UnregisterEvent(event) self.events[event] = nil end

  table.insert(env.frames, frame)
  return frame
end

--------------------------------------------------------------------------
-- Environment
--------------------------------------------------------------------------

local Env = {}
Env.__index = Env

-- Set the current group. `members` are the OTHER players, as "Name-Realm".
-- In a raid the player occupies raid1, matching the live client; party units
-- never include the player.
function Env:setGroup(members, opts)
  opts = opts or {}
  self.groupMembers = members or {}
  self.inRaid = opts.raid and true or false
end

function Env:setSolo()
  self:setGroup({})
end

-- Resolve the unit token to an entry, or nil if the unit does not exist.
function Env:unitInfo(unit)
  if unit == "player" then
    return { id = "player", name = M.PLAYER_NAME, realm = M.PLAYER_REALM }
  end

  local count = #self.groupMembers
  if count == 0 then
    return nil
  end

  if self.inRaid then
    local index = tonumber(unit:match("^raid(%d+)$"))
    if not index then
      return nil
    end
    -- raid1 is the player; raid2..N are the other members.
    if index == 1 then
      return { id = "player", name = M.PLAYER_NAME, realm = M.PLAYER_REALM }
    end
    local member = self.groupMembers[index - 1]
    if not member then
      return nil
    end
    return { id = "raid" .. index, name = shortOf(member), realm = realmOf(member) or M.PLAYER_REALM }
  end

  local index = tonumber(unit:match("^party(%d+)$"))
  if not index then
    return nil
  end
  local member = self.groupMembers[index]
  if not member then
    return nil
  end
  return { id = "party" .. index, name = shortOf(member), realm = realmOf(member) or M.PLAYER_REALM }
end

--------------------------------------------------------------------------
-- Ignore list control
--------------------------------------------------------------------------

-- Names the client has confirmed, in stored form.
function Env:ignoreList()
  local copy = {}
  for i, name in ipairs(self.ignores) do
    copy[i] = name
  end
  return copy
end

-- Seed the ignore list directly, bypassing the async round-trip.
function Env:seedIgnores(names)
  for _, name in ipairs(names) do
    table.insert(self.ignores, storedForm(name))
  end
end

-- Apply queued AddIgnore calls and fire FRIENDLIST_UPDATE, mimicking the
-- server answering. `opts.only` resolves just those names (as passed to
-- AddIgnore), leaving the rest outstanding; `opts.silent` skips the event.
function Env:resolveIgnores(opts)
  opts = opts or {}

  local onlySet
  if opts.only then
    onlySet = {}
    for _, name in ipairs(opts.only) do
      onlySet[lower(name)] = true
    end
  end

  local remaining = {}
  for _, name in ipairs(self.pendingAdds) do
    if onlySet and not onlySet[lower(name)] then
      table.insert(remaining, name)
    else
      local stored = storedForm(name)
      local exists = false
      for _, have in ipairs(self.ignores) do
        if identity(have) == identity(stored) then
          exists = true
          break
        end
      end
      if not exists and #self.ignores < self.maxIgnores then
        table.insert(self.ignores, stored)
      end
    end
  end
  self.pendingAdds = remaining

  if not opts.silent then
    self:fireEvent("FRIENDLIST_UPDATE")
  end
end

--------------------------------------------------------------------------
-- Events, timers, chat
--------------------------------------------------------------------------

function Env:fireEvent(event, ...)
  for _, frame in ipairs(self.frames) do
    if frame.events[event] and frame.scripts.OnEvent then
      frame.scripts.OnEvent(frame, event, ...)
    end
  end
end

function Env:click(button)
  assert(button and button.scripts.OnClick, "button has no OnClick handler")
  button.scripts.OnClick(button)
end

-- Run every timer callback whose delay has elapsed.
function Env:advanceTime(seconds)
  self.now = self.now + seconds

  local due, pending = {}, {}
  for _, timer in ipairs(self.timers) do
    if timer.at <= self.now then
      table.insert(due, timer)
    else
      table.insert(pending, timer)
    end
  end
  self.timers = pending

  table.sort(due, function(a, b) return a.at < b.at end)
  for _, timer in ipairs(due) do
    timer.fn()
  end
end

-- Chat output with the addon's colour escape stripped.
function Env:chatLines()
  local lines = {}
  for i, msg in ipairs(self.chat) do
    lines[i] = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  end
  return lines
end

function Env:lastChat()
  local lines = self:chatLines()
  return lines[#lines]
end

function Env:chatMatches(pattern)
  for _, line in ipairs(self:chatLines()) do
    if line:find(pattern) then
      return true
    end
  end
  return false
end

function Env:clearChat()
  self.chat = {}
end

--------------------------------------------------------------------------
-- Installation
--------------------------------------------------------------------------

local GLOBALS = {
  "C_FriendList", "C_Timer", "CreateFrame", "DEFAULT_CHAT_FRAME", "GetIgnoreName",
  "GetNormalizedRealmName", "GetNumGroupMembers", "IsInGroup", "IsInRaid",
  "MPlusPanicMuteDB", "MPlusPanicMute_ClearPartyMutes", "MPlusPanicMute_MuteGroup",
  "SLASH_MPLUSCLEARMUTE1", "SLASH_MPLUSMUTE1", "SLASH_MPLUSMUTE2", "SlashCmdList",
  "UIParent", "UnitExists", "UnitFullName", "UnitIsUnit", "time",
  "BINDING_HEADER_MPLUSPANICMUTE", "MPlusPanicMuteFrame",
}

-- Install the stubbed client API into _G. Returns the environment handle.
function M.install(opts)
  opts = opts or {}

  local env = setmetatable({
    frames = {},
    timers = {},
    chat = {},
    ignores = {},
    pendingAdds = {},
    groupMembers = {},
    inRaid = false,
    now = 0,
    maxIgnores = opts.maxIgnores or 50,
    -- Set true to make AddIgnore a no-op, simulating a rejected request.
    addIgnoreFails = false,
  }, Env)

  for _, key in ipairs(GLOBALS) do
    _G[key] = nil
  end

  _G.UIParent = {}
  _G.SlashCmdList = {}

  _G.time = function()
    return 1700000000 + env.now
  end

  _G.DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, msg)
      table.insert(env.chat, msg)
    end,
  }

  _G.CreateFrame = function(frameType, name, parent, template)
    return newFrame(env, frameType, name, parent, template)
  end

  _G.C_Timer = {
    After = function(delay, fn)
      table.insert(env.timers, { at = env.now + delay, fn = fn })
    end,
  }

  _G.GetNormalizedRealmName = function()
    return M.PLAYER_REALM
  end

  -- The live client returns a nil realm for same-realm units.
  _G.UnitFullName = function(unit)
    local info = env:unitInfo(unit)
    if not info then
      return nil
    end
    if info.realm == M.PLAYER_REALM then
      return info.name, nil
    end
    return info.name, info.realm
  end

  _G.UnitExists = function(unit)
    return env:unitInfo(unit) ~= nil
  end

  _G.UnitIsUnit = function(a, b)
    local ia, ib = env:unitInfo(a), env:unitInfo(b)
    return (ia and ib and ia.id == ib.id) or false
  end

  _G.IsInGroup = function()
    return #env.groupMembers > 0
  end

  _G.IsInRaid = function()
    return env.inRaid and #env.groupMembers > 0
  end

  _G.GetNumGroupMembers = function()
    if #env.groupMembers == 0 then
      return 0
    end
    return #env.groupMembers + 1
  end

  _G.GetIgnoreName = function(index)
    return env.ignores[index]
  end

  _G.C_FriendList = {
    GetNumIgnores = function()
      return #env.ignores
    end,

    AddIgnore = function(name)
      if env.addIgnoreFails then
        return false
      end
      table.insert(env.pendingAdds, name)
      return true
    end,

    DelIgnore = function(name)
      local target = identity(name)
      for i, have in ipairs(env.ignores) do
        if identity(have) == target then
          table.remove(env.ignores, i)
          return true
        end
      end
      return false
    end,

    -- Tests exercising the pre-C_FriendList fallback path clear this field.
    GetIgnoreName = function(index)
      return env.ignores[index]
    end,
  }

  return env
end

return M
