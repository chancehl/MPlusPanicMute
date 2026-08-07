-- Name plumbing: the addon has to reconcile three spellings of the same
-- player -- "Bob-Illidan" from unit APIs, "Bob" from the ignore list, and
-- whatever case the client hands back.

local helper = require("spec.spec_helper")

describe("name helpers", function()
  local internal

  before_each(function()
    local _, _, internals = helper.bootstrap()
    internal = internals
  end)

  describe("formatName", function()
    it("joins name and realm", function()
      assert.equals("Bob-Area52", internal.formatName("Bob", "Area52"))
    end)

    it("falls back to the player's realm when the realm is missing", function()
      -- UnitFullName returns a nil realm for same-realm units.
      assert.equals("Bob-" .. helper.PLAYER_REALM, internal.formatName("Bob", nil))
      assert.equals("Bob-" .. helper.PLAYER_REALM, internal.formatName("Bob", ""))
    end)

    it("returns nil for a nil name", function()
      assert.is_nil(internal.formatName(nil, "Area52"))
    end)
  end)

  describe("shortName", function()
    it("strips the realm suffix", function()
      assert.equals("Bob", internal.shortName("Bob-Area52"))
    end)

    it("passes through a bare name", function()
      assert.equals("Bob", internal.shortName("Bob"))
    end)

    it("keeps only the first segment of a multi-word realm", function()
      -- Realms such as "Aerie Peak" normalize to "AeriePeak", so a hyphen
      -- always separates name from realm.
      assert.equals("Bob", internal.shortName("Bob-AeriePeak"))
    end)

    it("returns nil for nil", function()
      assert.is_nil(internal.shortName(nil))
    end)
  end)

  describe("normalize", function()
    it("lowercases", function()
      assert.equals("bob-area52", internal.normalize("Bob-Area52"))
    end)

    it("returns nil for nil", function()
      assert.is_nil(internal.normalize(nil))
    end)
  end)
end)

describe("GetFullUnitName", function()
  it("appends the player's realm for a same-realm party member", function()
    local _, addon = helper.bootstrap({ group = { "Healer-" .. helper.PLAYER_REALM } })
    assert.equals("Healer-" .. helper.PLAYER_REALM, addon:GetFullUnitName("party1"))
  end)

  it("keeps the foreign realm for a cross-realm party member", function()
    local _, addon = helper.bootstrap({ group = { "Healer-Area52" } })
    assert.equals("Healer-Area52", addon:GetFullUnitName("party1"))
  end)

  it("returns nil for a unit that does not exist", function()
    local _, addon = helper.bootstrap({ group = { "Healer-Area52" } })
    assert.is_nil(addon:GetFullUnitName("party4"))
  end)
end)
