# M+ Panic Mute

Press a single button or keybind to ignore everyone else in your current Mythic+ group. Useful for tanks who want to focus on the run instead of arguments.

## Install
- Copy the `MPlusPanicMute` folder into `_retail_/Interface/AddOns/`.
- Make sure `## Interface` in `MPlusPanicMute.toc` matches your client build (currently `100207`).

## Use
- In-game, bind a key: `Esc` → `Key Bindings` → `AddOns` → `M+ Panic Mute` → set `Mute current party`.
- Slash command `/mplusmute` (or `/mppm`) toggles a small frame with buttons to mute your group and clear ignores.
- Press the keybind or the frame button to add every current party member to your ignore list (skips you, reports already-ignored or failed names in chat). The addon remembers who it muted.
- Slash `/mplusclear` or click “Clear addon ignores” to remove only the names the addon added. “Clear all ignores” wipes the entire ignore list.

## Notes
- Works in 5-player groups; it will iterate raid units too, but it’s intended for Mythic+ parties.
- Requires being in a group; otherwise it just prints a notice.
