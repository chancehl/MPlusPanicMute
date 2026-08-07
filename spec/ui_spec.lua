-- Frame, slash commands and keybinding wiring. These are shallow checks --
-- they confirm the addon registered what the player expects to find, not
-- that the client draws it correctly.

local helper = require("spec.spec_helper")

describe("addon load", function()
  it("builds the frame hidden", function()
    local env = helper.bootstrap()
    local ui = helper.ui(env)

    assert.is_table(ui.frame)
    assert.is_false(ui.frame:IsShown())
  end)

  it("builds the frame only once across repeated events", function()
    local env = helper.bootstrap()
    env:fireEvent("PLAYER_ENTERING_WORLD")
    env:fireEvent("GROUP_ROSTER_UPDATE")

    local named = 0
    for _, f in ipairs(env.frames) do
      if f.frameName == "MPlusPanicMuteFrame" then
        named = named + 1
      end
    end
    assert.equals(1, named)
  end)

  it("labels the keybinding header", function()
    helper.bootstrap()
    assert.equals("M+ Panic Mute", BINDING_HEADER_MPLUSPANICMUTE)
  end)

  it("exposes the keybinding globals declared in Bindings.xml", function()
    helper.bootstrap()
    assert.is_function(MPlusPanicMute_MuteGroup)
    assert.is_function(MPlusPanicMute_ClearPartyMutes)
  end)

  it("registers both slash commands", function()
    helper.bootstrap()
    assert.equals("/mplusmute", SLASH_MPLUSMUTE1)
    assert.equals("/mppm", SLASH_MPLUSMUTE2)
    assert.equals("/mplusclear", SLASH_MPLUSCLEARMUTE1)
    assert.is_function(SlashCmdList.MPLUSMUTE)
    assert.is_function(SlashCmdList.MPLUSCLEARMUTE)
  end)

  it("gives the three buttons their labels", function()
    local env = helper.bootstrap()
    local ui = helper.ui(env)

    assert.equals("Mute current group", ui.mute:GetText())
    assert.equals("Clear addon ignores", ui.clearTracked:GetText())
    assert.equals("Clear all ignores", ui.clearAll:GetText())
  end)
end)

describe("/mplusmute", function()
  it("toggles the frame", function()
    local env = helper.bootstrap()
    local frame = helper.ui(env).frame

    SlashCmdList.MPLUSMUTE()
    assert.is_true(frame:IsShown())

    SlashCmdList.MPLUSMUTE()
    assert.is_false(frame:IsShown())
  end)

  it("refreshes the mute button when opened", function()
    local env = helper.bootstrap()
    local ui = helper.ui(env)
    assert.is_false(ui.mute:IsEnabled())

    env:setGroup({ "Ann-" .. helper.PLAYER_REALM })
    SlashCmdList.MPLUSMUTE()

    assert.is_true(ui.mute:IsEnabled())
  end)
end)
