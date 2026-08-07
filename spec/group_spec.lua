-- Which groups the addon is willing to act on, and how it enumerates them.

local helper = require("spec.spec_helper")

local function party(n)
  local members = {}
  for i = 1, n do
    members[i] = "Member" .. i .. "-" .. helper.PLAYER_REALM
  end
  return members
end

describe("IsEligibleMythicParty", function()
  it("is false when solo", function()
    local _, addon = helper.bootstrap()
    assert.is_false(addon:IsEligibleMythicParty())
  end)

  it("is true for a full 5-player party", function()
    local _, addon = helper.bootstrap({ group = party(4) })
    assert.is_true(addon:IsEligibleMythicParty())
  end)

  it("is true for a partial party", function()
    local _, addon = helper.bootstrap({ group = party(1) })
    assert.is_true(addon:IsEligibleMythicParty())
  end)

  -- Five players can convert their party to a raid, which still reports five
  -- members. The addon should stay out of it.
  it("is false for a 5-player raid", function()
    local _, addon = helper.bootstrap({ group = party(4), raid = true })
    assert.is_false(addon:IsEligibleMythicParty())
  end)

  it("is false for a large raid", function()
    local _, addon = helper.bootstrap({ group = party(19), raid = true })
    assert.is_false(addon:IsEligibleMythicParty())
  end)
end)

describe("CollectGroupUnits", function()
  it("returns nothing when solo", function()
    local _, addon = helper.bootstrap()
    assert.same({}, addon:CollectGroupUnits())
  end)

  it("returns only the party units that exist", function()
    local _, addon = helper.bootstrap({ group = party(3) })
    assert.same({ "party1", "party2", "party3" }, addon:CollectGroupUnits())
  end)

  it("returns raid units, which include the player", function()
    local _, addon = helper.bootstrap({ group = party(4), raid = true })
    assert.same({ "raid1", "raid2", "raid3", "raid4", "raid5" }, addon:CollectGroupUnits())
  end)
end)

describe("mute button state", function()
  it("is enabled in an eligible party", function()
    local env, addon = helper.bootstrap({ group = party(4) })
    addon:UpdateMuteButtonState()

    local ui = helper.ui(env)
    assert.is_true(ui.mute:IsEnabled())
    assert.equals(1, ui.mute:GetAlpha())
  end)

  it("is dimmed and unclickable when solo", function()
    local env, addon = helper.bootstrap()
    addon:UpdateMuteButtonState()

    local ui = helper.ui(env)
    assert.is_false(ui.mute:IsEnabled())
    assert.equals(0.5, ui.mute:GetAlpha())
    assert.is_false(ui.mute.mouseEnabled)
  end)

  it("updates when the roster changes", function()
    local env = helper.bootstrap()
    local ui = helper.ui(env)
    assert.is_false(ui.mute:IsEnabled())

    env:setGroup(party(4))
    env:fireEvent("GROUP_ROSTER_UPDATE")

    assert.is_true(ui.mute:IsEnabled())
  end)
end)
