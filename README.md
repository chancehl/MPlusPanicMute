# M+ Panic Mute

Press a single button or keybind to ignore everyone else in your current Mythic+ group. Useful for tanks who want to focus on the run instead of arguments.

## Install
- Copy the `MPlusPanicMute` folder into `_retail_/Interface/AddOns/`.
- Make sure `## Interface` in `MPlusPanicMute.toc` includes your client build. Current Retail Midnight is `120100` (patch 12.1); this addon also keeps older Retail interface values for compatibility.

## Use
- In-game, bind a key: `Esc` → `Key Bindings` → `AddOns` → `M+ Panic Mute` → set `Mute current party`.
- Slash command `/mplusmute` (or `/mppm`) toggles a small frame with buttons to mute your group and clear ignores.
- Press the keybind or the frame button to add every current party member to your ignore list (skips you, reports already-ignored or failed names in chat). The addon remembers who it muted.
- Slash `/mplusclear` or click “Clear addon ignores” to remove only the names the addon added. “Clear all ignores” wipes the entire ignore list.

## Notes
- Mute button is enabled only for 5-player parties (Mythic+); raids and solo won’t activate it.
- Requires being in a group; otherwise it just prints a notice.

## Development

### Running the tests

The addon's logic is covered by a test suite that runs outside the game — no client, no party required.

```bash
./run-tests.sh
```

To run a single file:

```bash
./run-tests.sh spec/mute_group_spec.lua
```

### First-time setup

The suite runs on LuaJIT (Lua 5.1, the same version the game uses) with [busted](https://olivinelabs.com/busted/):

```bash
brew install luajit luarocks
```

```bash
luarocks --lua-version=5.1 --lua-dir=$(brew --prefix luajit) --local install busted
```

### How it works

`spec/wow_stub.lua` fakes the slice of the WoW API the addon touches, including two behaviours that shape most of the addon's code: `C_FriendList.AddIgnore` is asynchronous (names appear only after the server answers and `FRIENDLIST_UPDATE` fires), and the ignore list stores same-realm players without a realm suffix, so `Bob-Illidan` comes back as `Bob`.

Tests cover name matching, the 50-entry ignore cap, tracked-vs-manual ignore clearing, the async report flush, and the button/slash/keybind wiring.

### What still needs a real client

A green suite means the logic is intact, not that the addon loads. Frame templates, real server latency, the true ignore cap, and combat lockdown all need an in-game check — log in once after a patch and open `/mplusmute`.
