# SuperNovaUI

SuperNovaUI is a modular World of Warcraft Retail UI suite.

The project focuses on practical interface improvements organized into clear feature modules. Each module is designed to be small, predictable, and easy to configure as the suite grows.

## Features

### Compatibility

Restores Blizzard globals that were removed while installed addons still call them. The fixes live in the companion addon `!SuperNovaUI_Compat`: the leading `!` makes the game load it before every other addon, which matters for addons that call the removed functions while they are loading. A shim only activates when the global is missing, so it never overrides Blizzard or another addon (it coexists with FixRematch / `!RematchCompat`).

- `MouseIsOver` (removed in patch 12.1): fixes the blank Rematch 5.3.1 window, its menus, drag and drop, queue and notes card.
- `LE_BATTLE_PET_WEATHER`, `LE_BATTLE_PET_ALLY`, `LE_BATTLE_PET_ENEMY` (replaced by `Enum.BattlePetOwner`): fixes the original tdBattlePetScript.
- Item globals that moved to `C_Item` (`GetItemInfo`, `GetItemInfoInstant`, `GetItemCount`, `GetDetailedItemLevelInfo`, `GetItemSpell`, `IsUsableItem`, ...): fixes addons that still call the old names, such as ClassCodex and CraftInfoAnywhere. Each one is restored only when missing.

The compatibility menu (`/snui compat`) lists which known incompatible addons you have installed (tdBattlePetScript, its Rematch plugin, Rematch ElvUI Skin, RematchCelestialTournament, RematchNextTarget, Rematch) and whether each one is already fixed. A "Tweaks" section shows the state of the Premade Groups Filter tweak (active, disabled, not hooked or not installed). An addon counts as fixed when its `.toc` has the `X-SuperNovaUI-Patch` field (the Rematch fix is checked at runtime instead). Game addons cannot write to other addons' files and SuperNovaUI never edits them; the "How to fix" button only explains what to do (look for an updated version or ask the author).

Note: patch 12.1 "secret value" restrictions can still make Rematch show "Unknown (npc ID ...)" for some targets. That is a separate issue the shim cannot fix.

### Premade Groups Filter

With Premade Groups Filter installed, **Party Fit** also hides groups that already have a member with your character's class and specialization (it used to check only free tank/healer/damage slots). It works while the game runs, by wrapping two PGF functions, so PGF's own files stay untouched and updating PGF does not undo it.

### Rematch

Rematch 5.3.1 reads NPC names from a tooltip, and patch 12.1 made that text a "secret value", which raised an error and broke opening the pet journal. SuperNovaUI wraps `Rematch.targetInfo:GetNpcName` while the game runs: when the original fails, the NPC shows as `Unknown (npc id N)`, the label Rematch already uses for names it cannot find. Rematch's own files stay untouched. The real names return when Rematch ships its own fix.

## Commands

- `/snui` or `/supernova` - show help.
- `/snui status` - show global SuperNovaUI status.
- `/snui compat` - open the compatibility menu.
- `/snui compat status` - print the compatibility state in the chat.
- `/snui pgf` - show the Premade Groups Filter tweak state.
- `/snui rematch` - show the Rematch fix state.
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
