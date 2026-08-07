-- The addon remembers who it muted so "Clear addon ignores" can leave
-- long-standing manual ignores alone. That bookkeeping lives in
-- MPlusPanicMuteDB and has to survive a /reload.

local helper = require("spec.spec_helper")

describe("saved variables", function()
  it("creates the database on login", function()
    helper.bootstrap()
    assert.is_table(MPlusPanicMuteDB)
    assert.is_table(MPlusPanicMuteDB.trackedIgnores)
  end)

  it("keeps entries from a previous session", function()
    local existing = {
      trackedIgnores = {
        ["bob-area52"] = { name = "Bob-Area52", addedAt = 1 },
      },
    }
    local _, addon = helper.bootstrap({ db = existing })

    local tracked = addon:GetTrackedNamesSet()
    assert.equals("Bob-Area52", tracked["bob-area52"])
  end)

  it("repairs a database missing its trackedIgnores table", function()
    local _, addon = helper.bootstrap({ db = {} })
    assert.is_table(MPlusPanicMuteDB.trackedIgnores)
    assert.same({}, addon:GetTrackedNamesSet())
  end)
end)

describe("TrackIgnored", function()
  it("stores the name under a normalized key with a timestamp", function()
    local _, addon = helper.bootstrap()
    addon:TrackIgnored("Bob-Area52")

    local entry = MPlusPanicMuteDB.trackedIgnores["bob-area52"]
    assert.is_table(entry)
    assert.equals("Bob-Area52", entry.name)
    assert.is_number(entry.addedAt)
  end)

  it("does not create duplicate keys for the same player", function()
    local _, addon = helper.bootstrap()
    addon:TrackIgnored("Bob-Area52")
    addon:TrackIgnored("bob-area52")

    local count = 0
    for _ in pairs(MPlusPanicMuteDB.trackedIgnores) do
      count = count + 1
    end
    assert.equals(1, count)
  end)
end)

describe("ForgetTracked", function()
  it("removes an entry by its full name", function()
    local _, addon = helper.bootstrap()
    addon:TrackIgnored("Bob-Area52")
    addon:ForgetTracked("Bob-Area52")

    assert.same({}, addon:GetTrackedNamesSet())
  end)

  -- The client hands back "Bob" for a same-realm player, but the addon
  -- tracked "Bob-Illidan" when it muted them.
  it("removes an entry when the client reports a bare name", function()
    local _, addon = helper.bootstrap()
    addon:TrackIgnored("Bob-" .. helper.PLAYER_REALM)
    addon:ForgetTracked("Bob")

    assert.same({}, addon:GetTrackedNamesSet())
  end)

  it("leaves other entries alone", function()
    local _, addon = helper.bootstrap()
    addon:TrackIgnored("Bob-Area52")
    addon:TrackIgnored("Carol-Area52")
    addon:ForgetTracked("Bob-Area52")

    local tracked = addon:GetTrackedNamesSet()
    assert.is_nil(tracked["bob-area52"])
    assert.equals("Carol-Area52", tracked["carol-area52"])
  end)
end)

describe("GetTrackedNamesSet", function()
  it("keys entries by realm-qualified name only", function()
    local _, addon = helper.bootstrap()
    addon:TrackIgnored("Bob-Area52")

    local tracked = addon:GetTrackedNamesSet()
    assert.equals("Bob-Area52", tracked["bob-area52"])
    assert.is_nil(tracked["bob"])
  end)

  it("does not conflate same-named players on different realms", function()
    local _, addon = helper.bootstrap()
    addon:TrackIgnored("Bob-Area52")
    addon:TrackIgnored("Bob-Stormrage")

    local tracked = addon:GetTrackedNamesSet()
    assert.equals("Bob-Area52", tracked["bob-area52"])
    assert.equals("Bob-Stormrage", tracked["bob-stormrage"])
  end)

  it("leaves a different realm's namesake tracked when one is forgotten", function()
    local _, addon = helper.bootstrap()
    addon:TrackIgnored("Bob-Area52")
    addon:TrackIgnored("Bob-Stormrage")

    addon:ForgetTracked("Bob-Area52")

    local tracked = addon:GetTrackedNamesSet()
    assert.is_nil(tracked["bob-area52"])
    assert.equals("Bob-Stormrage", tracked["bob-stormrage"])
  end)
end)
