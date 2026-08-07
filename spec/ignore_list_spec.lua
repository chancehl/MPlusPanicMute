-- Reading the client's ignore list and deciding whether a given player is
-- already on it. The awkward part is that the client stores same-realm
-- players without a realm suffix, so "Bob-Illidan" comes back as "Bob".

local helper = require("spec.spec_helper")

describe("GetIgnoreList", function()
  it("returns an empty table when nothing is ignored", function()
    local _, addon = helper.bootstrap()
    assert.same({}, addon:GetIgnoreList())
  end)

  it("reads every entry the client reports", function()
    local _, addon = helper.bootstrap({ ignores = { "Bob-Area52", "Carol-" .. helper.PLAYER_REALM } })
    -- Carol is same-realm, so the client stores her bare.
    assert.same({ "Bob-Area52", "Carol" }, addon:GetIgnoreList())
  end)

  it("falls back to the legacy global when C_FriendList.GetIgnoreName is absent", function()
    local _, addon = helper.bootstrap({ ignores = { "Bob-Area52" } })
    C_FriendList.GetIgnoreName = nil
    assert.same({ "Bob-Area52" }, addon:GetIgnoreList())
  end)
end)

describe("IsIgnoredName", function()
  it("matches a same-realm player stored without a realm", function()
    local _, addon = helper.bootstrap({ ignores = { "Bob-" .. helper.PLAYER_REALM } })
    assert.is_truthy(addon:IsIgnoredName("Bob-" .. helper.PLAYER_REALM))
  end)

  it("matches a cross-realm player stored with a realm", function()
    local _, addon = helper.bootstrap({ ignores = { "Bob-Area52" } })
    assert.is_truthy(addon:IsIgnoredName("Bob-Area52"))
  end)

  it("ignores case differences", function()
    local _, addon = helper.bootstrap({ ignores = { "Bob-Area52" } })
    assert.is_truthy(addon:IsIgnoredName("bob-area52"))
    assert.is_truthy(addon:IsIgnoredName("BOB-AREA52"))
  end)

  it("does not match an unrelated player", function()
    local _, addon = helper.bootstrap({ ignores = { "Bob-Area52" } })
    assert.is_falsy(addon:IsIgnoredName("Carol-Area52"))
  end)

  it("returns false for nil", function()
    local _, addon = helper.bootstrap({ ignores = { "Bob-Area52" } })
    assert.is_falsy(addon:IsIgnoredName(nil))
  end)

  -- Same first name, different realms: two different people. Treating them
  -- as one made a party member silently escape being muted.
  it("keeps same-named players on different realms apart", function()
    local _, addon = helper.bootstrap({ ignores = { "Bob-Area52" } })
    assert.is_falsy(addon:IsIgnoredName("Bob-Stormrage"))
  end)

  -- The same distinction has to hold when the stored entry is the bare
  -- same-realm form, which is the case that motivated short-name matching
  -- in the first place.
  it("does not let a bare same-realm entry match another realm's player", function()
    local _, addon = helper.bootstrap({ ignores = { "Bob-" .. helper.PLAYER_REALM } })
    -- The client stores this one as plain "Bob".
    assert.same({ "Bob" }, addon:GetIgnoreList())

    assert.is_truthy(addon:IsIgnoredName("Bob-" .. helper.PLAYER_REALM))
    assert.is_falsy(addon:IsIgnoredName("Bob-Area52"))
  end)
end)

describe("BuildIgnoreSet", function()
  it("keys a cross-realm entry by its full name only", function()
    local _, addon = helper.bootstrap({ ignores = { "Bob-Area52" } })
    local set = addon:BuildIgnoreSet()

    assert.equals("Bob-Area52", set["bob-area52"])
    assert.is_nil(set["bob"])
  end)

  it("keys a bare same-realm entry under the player's realm", function()
    local _, addon = helper.bootstrap({ ignores = { "Bob-" .. helper.PLAYER_REALM } })
    local set = addon:BuildIgnoreSet()

    assert.equals("Bob", set["bob-" .. helper.PLAYER_REALM:lower()])
    assert.is_nil(set["bob"])
  end)
end)

describe("canonicalName", function()
  local internal

  before_each(function()
    local _, _, internals = helper.bootstrap()
    internal = internals
  end)

  it("fills in the player's realm for a bare name", function()
    assert.equals("bob-" .. helper.PLAYER_REALM:lower(), internal.canonicalName("Bob"))
  end)

  it("preserves an explicit realm", function()
    assert.equals("bob-area52", internal.canonicalName("Bob-Area52"))
  end)

  it("gives the two spellings of a same-realm player one form", function()
    assert.equals(
      internal.canonicalName("Bob"),
      internal.canonicalName("Bob-" .. helper.PLAYER_REALM)
    )
  end)

  it("gives players on different realms different forms", function()
    assert.not_equals(
      internal.canonicalName("Bob-Area52"),
      internal.canonicalName("Bob-Stormrage")
    )
  end)

  it("returns nil for nil", function()
    assert.is_nil(internal.canonicalName(nil))
  end)
end)
