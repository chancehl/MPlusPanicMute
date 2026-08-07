-- The main action: ignore everyone else in the party.
--
-- AddIgnore is asynchronous in the live client, so these tests call
-- env:resolveIgnores() to stand in for the server answering.

local helper = require("spec.spec_helper")

local REALM = helper.PLAYER_REALM

local function party(names)
  local members = {}
  for i, name in ipairs(names) do
    members[i] = name .. "-" .. REALM
  end
  return members
end

describe("MuteGroup", function()
  it("refuses when solo", function()
    local env, addon = helper.bootstrap()
    addon:MuteGroup()

    assert.is_true(env:chatMatches("not in a party"))
    assert.same({}, env:ignoreList())
  end)

  it("refuses in a raid", function()
    local env, addon = helper.bootstrap({ group = party({ "Ann", "Ben", "Cid", "Dot" }), raid = true })
    addon:MuteGroup()

    assert.is_true(env:chatMatches("limited to 5%-player"))
    assert.same({}, env:ignoreList())
  end)

  it("ignores every other party member", function()
    local env, addon = helper.bootstrap({ group = party({ "Ann", "Ben", "Cid", "Dot" }) })
    addon:MuteGroup()
    env:resolveIgnores()

    assert.same({ "ann", "ben", "cid", "dot" }, helper.sortedIgnores(env))
  end)

  it("never ignores the player", function()
    local env, addon = helper.bootstrap({ group = party({ "Ann", "Ben" }) })
    addon:MuteGroup()
    env:resolveIgnores()

    for _, name in ipairs(helper.sortedIgnores(env)) do
      assert.not_equals(helper.PLAYER_NAME:lower(), name)
    end
  end)

  it("records who it muted", function()
    local env, addon = helper.bootstrap({ group = party({ "Ann", "Ben" }) })
    addon:MuteGroup()
    env:resolveIgnores()

    local tracked = addon:GetTrackedNamesSet()
    assert.is_truthy(tracked["ann-" .. REALM:lower()])
    assert.is_truthy(tracked["ben-" .. REALM:lower()])
  end)

  it("reports the muted names", function()
    local env, addon = helper.bootstrap({ group = party({ "Ann", "Ben" }) })
    addon:MuteGroup()
    env:resolveIgnores()

    assert.is_true(env:chatMatches("Muted:"))
    assert.is_true(env:chatMatches("Ann%-" .. REALM))
  end)

  it("separates players who were already ignored", function()
    local env, addon = helper.bootstrap({
      group = party({ "Ann", "Ben" }),
      ignores = { "Ann-" .. REALM },
    })
    addon:MuteGroup()
    env:resolveIgnores()

    assert.is_true(env:chatMatches("Already ignored: Ann%-" .. REALM))
    assert.is_true(env:chatMatches("Muted: Ben%-" .. REALM))
  end)

  it("reports immediately when everyone is already ignored", function()
    local env, addon = helper.bootstrap({
      group = party({ "Ann", "Ben" }),
      ignores = { "Ann-" .. REALM, "Ben-" .. REALM },
    })
    addon:MuteGroup()

    -- No round-trip needed: nothing was requested.
    assert.is_true(env:chatMatches("Already ignored:"))
    assert.is_false(env:chatMatches("Muted:"))
  end)

  it("mutes cross-realm players under their full name", function()
    local env, addon = helper.bootstrap({ group = { "Ann-Area52" } })
    addon:MuteGroup()
    env:resolveIgnores()

    assert.same({ "ann-area52" }, helper.sortedIgnores(env))
  end)

  -- The bug this guards: a bare-name match treated Bob-Stormrage as already
  -- ignored because an unrelated Bob-Area52 was on the list, so the party
  -- member was never muted and nothing said so.
  it("mutes a party member whose first name collides with an existing ignore", function()
    local env, addon = helper.bootstrap({
      group = { "Bob-Stormrage" },
      ignores = { "Bob-Area52" },
    })
    addon:MuteGroup()
    env:resolveIgnores()

    assert.same({ "bob-area52", "bob-stormrage" }, helper.sortedIgnores(env))
    assert.is_true(env:chatMatches("Muted: Bob%-Stormrage"))
    assert.is_false(env:chatMatches("Already ignored"))
  end)

  it("mutes a cross-realm namesake of a bare same-realm ignore", function()
    local env, addon = helper.bootstrap({
      group = { "Bob-Area52" },
      ignores = { "Bob-" .. REALM },
    })
    -- The existing entry is stored bare, as the client does for same-realm.
    assert.same({ "Bob" }, addon:GetIgnoreList())

    addon:MuteGroup()
    env:resolveIgnores()

    assert.same({ "bob", "bob-area52" }, helper.sortedIgnores(env))
    assert.is_true(env:chatMatches("Muted: Bob%-Area52"))
  end)

  it("still skips a same-realm member who is genuinely ignored", function()
    local env, addon = helper.bootstrap({
      group = party({ "Bob" }),
      ignores = { "Bob-" .. REALM },
    })
    addon:MuteGroup()

    assert.is_true(env:chatMatches("Already ignored: Bob%-" .. REALM))
    assert.is_false(env:chatMatches("Muted:"))
    assert.equals(1, #env:ignoreList())
  end)

  it("fires from the frame button", function()
    local env = helper.bootstrap({ group = party({ "Ann" }) })
    local ui = helper.ui(env)
    env:click(ui.mute)
    env:resolveIgnores()

    assert.same({ "ann" }, helper.sortedIgnores(env))
  end)

  it("fires from the keybinding global", function()
    local env = helper.bootstrap({ group = party({ "Ann" }) })
    MPlusPanicMute_MuteGroup()
    env:resolveIgnores()

    assert.same({ "ann" }, helper.sortedIgnores(env))
  end)
end)

describe("MuteGroup and the 50-entry ignore cap", function()
  local function filler(n)
    local names = {}
    for i = 1, n do
      names[i] = "Filler" .. i .. "-" .. REALM
    end
    return names
  end

  it("refuses outright when the list is full", function()
    local env, addon = helper.bootstrap({
      group = party({ "Ann", "Ben" }),
      ignores = filler(50),
    })
    addon:MuteGroup()

    assert.is_true(env:chatMatches("Ignore list is full %(50/50%)"))
    assert.equals(50, #env:ignoreList())
  end)

  it("mutes as many as will fit and says how many it dropped", function()
    local env, addon = helper.bootstrap({
      group = party({ "Ann", "Ben", "Cid", "Dot" }),
      ignores = filler(48),
    })
    addon:MuteGroup()

    assert.is_true(env:chatMatches("Only 2 of 4 can be muted"))

    env:resolveIgnores()
    assert.equals(50, #env:ignoreList())
  end)

  it("does not count already-ignored party members against the free slots", function()
    local env, addon = helper.bootstrap({
      group = party({ "Ann", "Ben" }),
      ignores = filler(48),
    })
    -- 48 fillers plus Ann is 49 entries, so only Ben needs a slot and there
    -- is exactly one left. Ann must not be double-counted into the total.
    env:seedIgnores({ "Ann-" .. REALM })
    assert.equals(49, #env:ignoreList())

    addon:MuteGroup()
    env:resolveIgnores()

    assert.is_true(env:chatMatches("Muted: Ben%-" .. REALM))
    assert.is_false(env:chatMatches("Ignore list is full"))
  end)
end)

describe("mute reporting", function()
  it("waits for every requested ignore before reporting", function()
    local env, addon = helper.bootstrap({ group = party({ "Ann", "Ben", "Cid" }) })
    addon:MuteGroup()

    -- The client confirms one name at a time; reporting after the first
    -- FRIENDLIST_UPDATE would call the other two failures.
    env:resolveIgnores({ only = { "Ann-" .. REALM } })
    assert.is_false(env:chatMatches("Muted:"))

    env:resolveIgnores({ only = { "Ben-" .. REALM } })
    assert.is_false(env:chatMatches("Muted:"))

    env:resolveIgnores()
    assert.is_true(env:chatMatches("Muted:"))
    assert.is_false(env:chatMatches("Failed:"))
  end)

  it("reports stragglers as failed once the timeout elapses", function()
    local env, addon = helper.bootstrap({ group = party({ "Ann", "Ben", "Cid" }) })
    addon:MuteGroup()

    env:resolveIgnores({ only = { "Ann-" .. REALM, "Ben-" .. REALM } })
    assert.is_false(env:chatMatches("Muted:"))

    env:advanceTime(1.0)
    assert.is_true(env:chatMatches("Muted: "))
    assert.is_true(env:chatMatches("Failed: Cid%-" .. REALM))
  end)

  it("reports once, not twice, when the timeout follows a successful flush", function()
    local env, addon = helper.bootstrap({ group = party({ "Ann" }) })
    addon:MuteGroup()

    env:resolveIgnores()
    env:advanceTime(5.0)

    local reports = 0
    for _, line in ipairs(env:chatLines()) do
      if line:find("Muted:") then
        reports = reports + 1
      end
    end
    assert.equals(1, reports)
  end)

  -- A stale timer from an earlier press must not report on behalf of a later
  -- one; that is what the pendingMuteId generation counter guards.
  it("lets a second mute supersede the first press's timer", function()
    local env, addon = helper.bootstrap({ group = party({ "Ann", "Ben" }) })

    addon:MuteGroup()
    env:advanceTime(0.5)
    addon:MuteGroup()

    -- Confirm the ignores without firing FRIENDLIST_UPDATE, so that a timer
    -- is the only thing that can produce the report.
    env:resolveIgnores({ silent = true })

    -- The first press's timer comes due here and must stay quiet, because
    -- the second press bumped the generation counter.
    env:advanceTime(0.5)
    assert.is_false(env:chatMatches("Muted:"))

    -- The second press's timer is what reports, exactly once.
    env:advanceTime(0.5)
    assert.is_true(env:chatMatches("Muted:"))

    local reports = 0
    for _, line in ipairs(env:chatLines()) do
      if line:find("Muted:") then
        reports = reports + 1
      end
    end
    assert.equals(1, reports)
  end)

  it("reports failures when the client rejects the request outright", function()
    local env, addon = helper.bootstrap({ group = party({ "Ann" }) })
    env.addIgnoreFails = true

    addon:MuteGroup()
    env:advanceTime(1.0)

    assert.is_true(env:chatMatches("Failed: Ann%-" .. REALM))
    assert.same({}, env:ignoreList())
  end)
end)
