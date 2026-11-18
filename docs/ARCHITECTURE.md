# Architecture

SuperNovaUI is intentionally split into a small core and feature modules.

## AddOn Layout

- `SuperNovaUI/SuperNovaUI.toc` loads the AddOn in a predictable order.
- `SuperNovaUI/Core/` owns bootstrap, database, module registry, profiles, console output, and slash commands.
- `SuperNovaUI/Panel/` owns the options window.
- `SuperNovaUI/Modules/` owns the user-facing modules, one file each; add each file to the `.toc`.

## Options Panel

`/snui` opens a window that works like a file explorer: modules grouped by category on the left, the selected module's page
on the right. A module describes itself with `module.info` (category, kind, name, description, the addon it needs, options),
and the panel, the on/off switch, the status dot and the profile export all come from that description.

- Kinds: `fix` (repairs another addon), `compat` (restores something the game removed), `feature`, and `core` (a page that
  has no switch: General, Profile, Debug).
- A module is on by default and only starts when the addon it needs is installed. The first time the addon loads it asks
  whether to load all compatible modules; the General page can enable or disable all of them at any time.
- A module that cannot start or stop on the fly (no `module:SetEnabled`) asks for a reload; the window shows a banner. PGF and Rematch can: their wrappers stay installed and only change behaviour while the module is on. The shims cannot (they are defined while the game loads), so their switch is saved in `SuperNovaUICompatDB`, which the companion addon reads at load.
- Profiles are text (`SNUI1:<checksum>:<base64>`) read by our own parser: nothing is run, and only known modules and valid
  option values are kept.
- The window saves its position in `db.ui.position`; the module rows and toggles with a description show tooltips (a widget with a `.tooltip` function); Up/Down/Ctrl+F are handled by the panel's `OnKeyDown`, which stops propagating only for keys it used and never touches the protected propagation flag in combat.
- Look: the palette is `W.colors` (deep indigo background, dusk-violet borders, the brand cyan as accent); `W.fonts` are the window's own font objects (`CreateFont`) pointing at `Fonts\FRIZQT__.TTF` for Latin-alphabet clients and at the client's `STANDARD_TEXT_FONT` for the others, and `W.Text` maps each `GameFont*` template to one of them, so a font addon that replaces the game's font objects does not change the window. Friz Quadrata is wide, so a `W.Button` grows to its text and `flow:Buttons` advances by each button's real width. `W.Stars` draws a seeded, dim, tiny star field (the same sky every time) and leaves out a region so nothing sits behind text: the whole page on the right in the window, the middle of the welcome window.
- `Core/` and `Panel/` are shared with the WoW Forever addon: edit them here and run `python tools/sync-shared.py`
  (`--check` to compare). Only `Core/Config.lua` differs.
- `Modules/CooldownMacro.lua` (module `macro`, no required addon) is also shared with Forever. It reads one spell's cooldown (`C_Spell.GetSpellCooldown` or `GetSpellCooldown`; anything of 1.5 s or less is the global cooldown; a hidden value in Retail 12 raises on comparison and counts as unknown) and, on `SPELL_UPDATE_COOLDOWN`, `PLAYER_REGEN_ENABLED`, `PLAYER_ENTERING_WORLD` and `SPELLS_CHANGED`, writes the "ready" or "cooldown" text into one character macro (`EditMacro`, or `CreateMacro` when it does not exist). `EditMacro` and `CreateMacro` are blocked in combat, so a change is remembered (`blocked`) and applied when the fight ends. The game reports when a cooldown starts or changes but not when it ends, so the end it reported (start + duration, which already include talents and anything Blizzard changes; no duration is written in the addon) is remembered in `watching` and one `C_Timer.After` look is scheduled for that moment (`WatchEnd`). If the cooldown moves, the game reports it, the end changes and the look is rescheduled (a token drops the old one); nothing runs on every frame or on a fixed interval, and a ready spell schedules nothing. It does not touch macros before `PLAYER_ENTERING_WORLD` (before that the macro list is empty and it would create a duplicate). Its settings (spell, macro name, two texts) are saved in the module's account settings by its own page and are not part of a profile export.
- `python tests/run_tests.py [addon folder]` runs the Lua outside the game with a stand-in for the WoW API (needs
  `pip install lupa`).

## Runtime Shape

The WoW AddOn namespace table is the public project table:

```lua
local addonName, SN = ...
```

Core code adds shared helpers to `SN`. Modules register with:

```lua
SN:RegisterModule("myModule", MyModule)
SN:RegisterModuleDefaults("myModule", { enabled = true })
```

The bootstrap initializes the database, registers slash commands, then initializes modules in registration order.

Account-wide module options live in `SuperNovaUIDB`. Character-specific runtime choices live in `SuperNovaUICharDB`.

## Clean Code Rules

- One module owns one feature.
- A function should do one thing and be named after that thing.
- Configuration lives in the database defaults, not scattered through feature logic.
- Frame and API access is guarded because Blizzard UI names can change between builds.
- Community examples can influence product thinking, but implementation must remain original.
