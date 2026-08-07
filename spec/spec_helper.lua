-- Loads a pristine copy of the addon against a freshly stubbed client API.
--
-- MPlusPanicMute.lua keeps its state in file-locals (db, pendingMute,
-- muteButton, ...), so the only reliable way to isolate tests is to execute
-- the chunk again for each one. Every test therefore starts from a cold
-- login: no saved variables, no frames, an empty ignore list.

local stub = require("spec.wow_stub")

local M = {}

M.PLAYER = stub.PLAYER_NAME .. "-" .. stub.PLAYER_REALM
M.PLAYER_NAME = stub.PLAYER_NAME
M.PLAYER_REALM = stub.PLAYER_REALM

local ADDON_FILE = "MPlusPanicMute.lua"

-- Build a fresh world. Returns:
--   env      the stub handle (group, ignores, timers, chat)
--   addon    the addon table, for calling methods directly
--   internal the file-local helpers (formatName, normalize, shortName)
--
-- opts.group   party members to start in, as "Name-Realm"
-- opts.raid    treat the group as a raid
-- opts.ignores names already on the ignore list
-- opts.db      pre-existing MPlusPanicMuteDB, to simulate a /reload
-- opts.login   fire PLAYER_LOGIN after loading (default true)
function M.bootstrap(opts)
  opts = opts or {}

  local env = stub.install(opts)

  if opts.group then
    env:setGroup(opts.group, { raid = opts.raid })
  end

  if opts.ignores then
    env:seedIgnores(opts.ignores)
  end

  if opts.db then
    _G.MPlusPanicMuteDB = opts.db
  end

  local chunk = assert(loadfile(ADDON_FILE))
  local ns = {}
  chunk("MPlusPanicMute", ns)

  assert(ns.addon, "addon did not expose ns.addon -- did the export block change?")

  if opts.login ~= false then
    env:fireEvent("PLAYER_LOGIN")
    env:clearChat()
  end

  return env, ns.addon, ns.internals
end

-- The frame the addon builds for /mplusmute, plus its buttons in layout order.
function M.ui(env)
  local frame
  for _, f in ipairs(env.frames) do
    if f.frameName == "MPlusPanicMuteFrame" then
      frame = f
      break
    end
  end

  local buttons = {}
  for _, f in ipairs(env.frames) do
    if f.frameType == "Button" then
      table.insert(buttons, f)
    end
  end

  return {
    frame = frame,
    mute = buttons[1],
    clearTracked = buttons[2],
    clearAll = buttons[3],
  }
end

-- Sorted, lowercased ignore list, so assertions do not depend on insertion order.
function M.sortedIgnores(env)
  local names = {}
  for i, name in ipairs(env:ignoreList()) do
    names[i] = name:lower()
  end
  table.sort(names)
  return names
end

return M
