# SuperNovaUI

SuperNovaUI is a modular World of Warcraft Retail UI suite.

The project focuses on practical interface improvements organized into clear feature modules. Each module is designed to be small, predictable, and easy to configure as the suite grows.

## Features

### Compatibility

Restores Blizzard globals that were removed while installed addons still call them. A shim only activates when the global is missing, so it never overrides Blizzard or another addon (it coexists with FixRematch / `!RematchCompat`).

- `MouseIsOver` (removed in patch 12.1): fixes the blank Rematch 5.3.1 window, its menus, drag and drop, queue and notes card.
- `LE_BATTLE_PET_WEATHER`, `LE_BATTLE_PET_ALLY`, `LE_BATTLE_PET_ENEMY` (replaced by `Enum.BattlePetOwner`): fixes the original tdBattlePetScript.

Note: patch 12.1 "secret value" restrictions can still make Rematch show "Unknown (npc ID ...)" for some targets. That is a separate issue the shim cannot fix.

## Commands

- `/snui` or `/supernova` - show help.
- `/snui status` - show global SuperNovaUI status.
- `/snui compat` - show which compatibility shims are active.
- `/snui reload` - reload the UI.

## Installation

Copy the `SuperNovaUI` AddOn folder into:

```text
World of Warcraft/_retail_/Interface/AddOns/
```

The installed folder should contain `SuperNovaUI.toc` directly inside it:

```text
Interface/AddOns/SuperNovaUI/SuperNovaUI.toc
```

## Development Notes

- Official Blizzard sources are preferred first.
- Community API references are used only when official client UI API coverage is incomplete.
- Third-party AddOn repositories are treated as references only and are not copied.
- Code should favor clear responsibilities, guarded API access, and small modules.
