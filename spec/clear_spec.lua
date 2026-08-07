-- Undoing mutes. The distinction that matters is tracked (added by this
-- addon) versus untracked (ignores the player added themselves and would be
-- annoyed to lose).

local helper = require("spec.spec_helper")

local REALM = helper.PLAYER_REALM

local function party(names)
  local members = {}
  for i, name in ipairs(names) do
    members[i] = name .. "-" .. REALM
  end
  return members
end

-- Mute the given party and let the client confirm, so the addon has tracked
-- entries to work with.
local function muteParty(env, addon)
  addon:MuteGroup()
  env:resolveIgnores()
  env:clearChat()
end

describe("ClearIgnores with onlyTracked", function()
  it("says so when the list is empty", function()
    local env, addon = helper.bootstrap()
    addon:ClearIgnores({ onlyTracked = true })

    assert.is_true(env:chatMatches("already empty"))
  end)

  it("removes what the addon muted", function()
    local env, addon = helper.bootstrap({ group = party({ "Ann", "Ben" }) })
    muteParty(env, addon)

    addon:ClearIgnores({ onlyTracked = true })

    assert.same({}, env:ignoreList())
    assert.is_true(env:chatMatches("Cleared 2 ignore"))
  end)

  it("leaves manually added ignores alone", function()
    local env, addon = helper.bootstrap({ group = party({ "Ann" }) })
    muteParty(env, addon)
    env:seedIgnores({ "Spammer-Area52" })

    addon:ClearIgnores({ onlyTracked = true })

    assert.same({ "spammer-area52" }, helper.sortedIgnores(env))
    assert.is_true(env:chatMatches("Skipped 1 untracked"))
  end)

  it("refuses to touch anything when nothing is tracked", function()
    local env, addon = helper.bootstrap({ ignores = { "Spammer-Area52" } })
    addon:ClearIgnores({ onlyTracked = true })

    assert.same({ "spammer-area52" }, helper.sortedIgnores(env))
    assert.is_true(env:chatMatches("No tracked ignores to clear"))
  end)

  it("forgets the tracking entries it cleared", function()
    local env, addon = helper.bootstrap({ group = party({ "Ann" }) })
    muteParty(env, addon)

    addon:ClearIgnores({ onlyTracked = true })

    assert.same({}, addon:GetTrackedNamesSet())
  end)

  it("runs from the slash command", function()
    local env, addon = helper.bootstrap({ group = party({ "Ann" }) })
    muteParty(env, addon)

    SlashCmdList.MPLUSCLEARMUTE()

    assert.same({}, env:ignoreList())
  end)
end)

describe("ClearIgnores without onlyTracked", function()
  it("wipes the whole list, tracked or not", function()
    local env, addon = helper.bootstrap({ group = party({ "Ann" }) })
    muteParty(env, addon)
    env:seedIgnores({ "Spammer-Area52" })

    addon:ClearIgnores({ onlyTracked = false })

    assert.same({}, env:ignoreList())
    assert.is_true(env:chatMatches("Cleared 2 ignore"))
  end)

  it("runs from the frame button", function()
    local env, addon = helper.bootstrap({ group = party({ "Ann" }) })
    muteParty(env, addon)
    env:seedIgnores({ "Spammer-Area52" })

    env:click(helper.ui(env).clearAll)

    assert.same({}, env:ignoreList())
  end)
end)

describe("ClearPartyIgnores", function()
  it("refuses when solo", function()
    local env, addon = helper.bootstrap()
    addon:ClearPartyIgnores()

    assert.is_true(env:chatMatches("not in a party"))
  end)

  it("refuses in a raid", function()
    local env, addon = helper.bootstrap({ group = party({ "Ann", "Ben" }), raid = true })
    addon:ClearPartyIgnores()

    assert.is_true(env:chatMatches("not in a party"))
  end)

  it("clears only the current party", function()
    -- Mute one group, then move to another with a different roster.
    local env, addon = helper.bootstrap({ group = party({ "Ann", "Ben" }) })
    muteParty(env, addon)

    env:setGroup(party({ "Cid", "Dot" }))
    env:fireEvent("GROUP_ROSTER_UPDATE")
    muteParty(env, addon)

    addon:ClearPartyIgnores()

    -- The first group's mutes survive; the current group's are gone.
    assert.same({ "ann", "ben" }, helper.sortedIgnores(env))
    assert.is_true(env:chatMatches("Cleared 2 party ignore"))
  end)

  it("leaves untracked party members ignored", function()
    local env, addon = helper.bootstrap({
      group = party({ "Ann", "Ben" }),
      ignores = { "Ben-" .. REALM },
    })
    -- Ben was ignored by hand before the run, so he is not the addon's to undo.
    muteParty(env, addon)

    addon:ClearPartyIgnores()

    assert.same({ "ben" }, helper.sortedIgnores(env))
  end)

  -- DelIgnore takes a name, so a bare-name match could unignore the wrong
  -- Bob entirely -- one who was never in this party.
  it("does not unignore a namesake from another realm", function()
    local env, addon = helper.bootstrap({ group = { "Bob-Area52" } })
    muteParty(env, addon)

    -- A different Bob, muted in an earlier run and not in the current party.
    env:setGroup({ "Bob-Stormrage" })
    env:fireEvent("GROUP_ROSTER_UPDATE")
    muteParty(env, addon)

    addon:ClearPartyIgnores()

    assert.same({ "bob-area52" }, helper.sortedIgnores(env))
    assert.is_true(env:chatMatches("Cleared 1 party ignore"))
  end)

  it("says so when there is nothing of its own to clear", function()
    local env, addon = helper.bootstrap({ group = party({ "Ann" }) })
    addon:ClearPartyIgnores()

    assert.is_true(env:chatMatches("No tracked party ignores"))
  end)

  it("runs from the keybinding global", function()
    local env, addon = helper.bootstrap({ group = party({ "Ann" }) })
    muteParty(env, addon)

    MPlusPanicMute_ClearPartyMutes()

    assert.same({}, env:ignoreList())
  end)
end)
