# SuperNovaUI

SuperNovaUI is a modular World of Warcraft Retail UI suite.

The project focuses on practical interface improvements organized into clear feature modules. Each module is designed to be small, predictable, and easy to configure as the suite grows.

## Features

### Options panel

`/snui` opens a window with the modules grouped by category on the left (General, Compatibility, Groups and dungeons, Battle pets, ...) and the selected module's page on the right. Every fix is a module you can turn on or off. A module starts on, except when it would be useless for you (the addon it fixes is missing, or it has nothing to do yet) or would duplicate an addon you already run: then it starts off, and once you switch it yourself your choice is kept. The first time the addon loads it asks whether to load the recommended modules, and the General page can enable or disable them all at any time. The Profile page exports your settings as text and imports them on another character or computer (or in the WoW Forever addon, see below). The window has a dark "deep space" look (a few dim stars along the edges, none behind the text), draws its text with the font file Blizzard ships (Friz Quadrata) whatever a font addon did to the game's fonts, is available in English and Portuguese (Brazil), remembers where you put it (the General page can reset it), shows a tooltip for each module, and can be driven from the keyboard: Up and Down move through the modules, Ctrl+F jumps to the search, Esc closes it.

### Compatibility

Restores Blizzard globals that were removed while installed addons still call them. The fixes live in the companion addon `!SuperNovaUI_Compat`: the leading `!` makes the game load it before every other addon, which matters for addons that call the removed functions while they are loading. A shim only activates when the global is missing, so it never overrides Blizzard or another addon (it coexists with FixRematch / `!RematchCompat`).

- `MouseIsOver` (removed in patch 12.1): fixes the blank Rematch 5.3.1 window, its menus, drag and drop, queue and notes card.
- `LE_BATTLE_PET_WEATHER`, `LE_BATTLE_PET_ALLY`, `LE_BATTLE_PET_ENEMY` (replaced by `Enum.BattlePetOwner`): fixes the original tdBattlePetScript.
- Item globals that moved to `C_Item` (`GetItemInfo`, `GetItemInfoInstant`, `GetItemCount`, `GetDetailedItemLevelInfo`, `GetItemSpell`, `IsUsableItem`, ...): fixes addons that still call the old names, such as ClassCodex and CraftInfoAnywhere. Each one is restored only when missing.

The Compatibility > Fix status page (`/snui compat`) lists which known incompatible addons you have installed (tdBattlePetScript, its Rematch plugin, Rematch ElvUI Skin, RematchCelestialTournament, RematchNextTarget, Rematch) and whether each one is already fixed, and which fixes are built in. An addon counts as fixed when its `.toc` has the `X-SuperNovaUI-Patch` field (the Rematch fix is checked at runtime instead). Game addons cannot write to other addons' files and SuperNovaUI never edits them; the page only explains what to do (look for an updated version or ask the author). The shims have their own switch (Compatibility > Game functions); a change there applies after a reload.

Note: patch 12.1 "secret value" restrictions can still make Rematch show "Unknown (npc ID ...)" for some targets. That is a separate issue the shim cannot fix.

### Premade Groups Filter

With Premade Groups Filter installed, **Party Fit** also hides groups that already have a member with your character's class and specialization (it used to check only free tank/healer/damage slots). It works while the game runs, by wrapping two PGF functions, so PGF's own files stay untouched and updating PGF does not undo it.

### Rematch

Rematch 5.3.1 reads NPC names from a tooltip, and patch 12.1 made that text a "secret value", which raised an error and broke opening the pet journal. SuperNovaUI wraps `Rematch.targetInfo:GetNpcName` while the game runs: when the original fails, the NPC shows as `Unknown (npc id N)`, the label Rematch already uses for names it cannot find. Rematch's own files stay untouched. The real names return when Rematch ships its own fix.

### Exploration markers

Marks the regions of the current zone you have not discovered yet, on the world map and on the minimap, with a small ring that disappears when you discover the region. The regions come from the game's own tables (`python tools/gen-exploration.py` rebuilds `Data/Exploration.lua` after a patch); it does nothing next to Leatrix Maps unless you turn it on.

### Macro by cooldown

A macro cannot ask whether a spell is on cooldown; this module can. It watches one spell and keeps one macro in step with it: one text while the spell is ready, another while it recharges, and it switches back by itself when the spell is ready again. You keep a single button on the bar. Set it up in Tools > Macro by cooldown: the spell (name or id), the macro name (created for the character if it does not exist; an existing macro with that name has its text replaced) and the two texts. The page has a **Fill with the druid example** button for WoW Forever: the racial "Sky Vision" while it is ready; on cooldown, shift into Cat Form and use Dash.

A macro can only be changed outside combat, so a cooldown that starts or ends during a fight is applied when the fight ends (until then the button keeps the text it had). The global cooldown (1.5 s or less) is ignored. In Retail 12 the cooldown values can be hidden from addons in combat; the macro is then left as it is. The module does nothing until a spell and both texts are set.

If you use the spell in combat, use two fixed macros instead, one button each (their text never changes, so combat does not matter). Example for the druid: button 1 is `#showtooltip` and `/cast Sky Vision`; button 2 is `#showtooltip`, `/cast [form:3] Dash` and `/cast [noform:3] Cat Form`. The module's page shows this example in the player's language.

## Commands

- `/snui` or `/supernova` - open the options panel.
- `/snui help` - list the commands.
- `/snui status` - show global SuperNovaUI status.
- `/snui compat` - open the Fix status page.
- `/snui compat status` - print the compatibility state in the chat.
- `/snui pgf` - show the Premade Groups Filter tweak state.
- `/snui rematch` - show the Rematch fix state.
- `/snui macro` - show the state of the macro by cooldown.
- `/snui explore` - list the regions of the current zone that are still undiscovered.
- `/snui reload` - reload the UI.

## Installation

Copy both AddOn folders into:

```text
World of Warcraft/_retail_/Interface/AddOns/
```

- `SuperNovaUI` (the addon, with `SuperNovaUI.toc` directly inside it)
- `!SuperNovaUI_Compat` (loads first and provides the compatibility fixes; without it the fixes are inactive)

## Releasing

`python build/package.py` builds `dist/SuperNovaUI-<version>.zip` (both addon folders plus the license). The project description for CurseForge is in `docs/CURSEFORGE.md` (English and Brazilian Portuguese).

## License

MIT, see `LICENSE`.

## Development Notes

- Official Blizzard sources are preferred first.
- Community API references are used only when official client UI API coverage is incomplete.
- Third-party AddOn repositories are treated as references only and are not copied.
- Code should favor clear responsibilities, guarded API access, and small modules.
