# MPlusPanicMute

A World of Warcraft Retail addon. One button (or keybind) adds everyone else
in your 5-player party to the ignore list, and can undo it later.

Everything ships in `MPlusPanicMute.lua`; `MPlusPanicMute.toc` declares the
supported client builds and `Bindings.xml` declares the keybinds.

## Run the tests

**Always run the suite after changing `MPlusPanicMute.lua`.** It is fast
(~0.03s) and does not need the game client.

```bash
./run-tests.sh
```

Pass arguments through to busted to narrow a run:

```bash
./run-tests.sh spec/mute_group_spec.lua
```

If `busted` is missing, `run-tests.sh` prints the install commands. The
toolchain is LuaJIT (Lua 5.1, matching the game) plus busted in the user rock
tree at `~/.luarocks`.

## How the tests work

`spec/wow_stub.lua` implements just enough of the client API to load the addon
outside the game. Two behaviours are modelled on purpose, because the addon
has code that exists solely to cope with them:

- **`C_FriendList.AddIgnore` is asynchronous.** A name does not land on the
  ignore list when you call it; the server answers later and the client fires
  `FRIENDLIST_UPDATE`. Tests drive that with `env:resolveIgnores()`, which can
  confirm names one at a time (`{ only = { ... } }`) or skip the event
  (`{ silent = true }`) so a timer is the only thing that can report.
- **The ignore list drops the realm for same-realm players.** You ignore
  `Bob-Illidan` and the client hands back plain `Bob`. Every comparison in the
  addon therefore goes through `canonicalName`, which fills the player's own
  realm in for a bare name so both spellings reduce to one key. Compare names
  that way and never on the bare short name — two Bobs on different realms are
  two people, and treating them as one lets a party member escape the mute.

`spec/spec_helper.lua` re-executes the addon chunk for every test. The addon
keeps its state in file-locals (`db`, `pendingMute`, `muteButton`), so a fresh
load is the only reliable isolation. Every test therefore starts from a cold
login.

`helper.bootstrap{ group =, raid =, ignores =, db = }` returns
`env, addon, internals` — the stub handle, the addon table, and the
file-local name helpers exported through the private namespace at the bottom
of `MPlusPanicMute.lua`. Keep that export block in step with any helper you
add.

## What the tests cannot tell you

The stub is not the game. These still need a real client:

- Whether the frame actually draws, and whether templates such as
  `BasicFrameTemplateWithInset` still exist under the current build.
- Real server timing — the 1-second report timeout is a guess about latency.
- The true ignore cap (the addon assumes 50) and any server-side rejection.
- Anything gated by combat lockdown or protected functions.

So a green suite means the logic is intact, not that the addon loads in-game.
After a client patch, log in once and open `/mplusmute` to confirm.

## Client patch bumps

`## Interface` in the `.toc` lists every supported build. Add the new number
rather than replacing the list, and bump `## Version`. Current retail is
Midnight `120100` (patch 12.1). Check
<https://warcraft.wiki.gg/wiki/Patch_12.1.0/API_changes> for API removals
before assuming a bump is all that is needed.
