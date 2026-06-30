# Architecture

SuperNovaUI is intentionally split into a small core and feature modules.

## AddOn Layout

- `SuperNovaUI/SuperNovaUI.toc` loads the AddOn in a predictable order.
- `SuperNovaUI/Core/` owns bootstrap, database, console output, and slash commands.
- `SuperNovaUI/Modules/` owns user-facing feature modules.

## Runtime Shape

The WoW AddOn namespace table is the public project table:

```lua
local addonName, SN = ...
```

Core code adds shared helpers to `SN`. Modules register with:

```lua
SN:RegisterModule("frameMover", FrameMover)
```

The bootstrap initializes the database, registers slash commands, then initializes modules in registration order.

## Clean Code Rules

- One module owns one feature.
- A function should do one thing and be named after that thing.
- Configuration lives in the database defaults, not scattered through feature logic.
- Frame and API access is guarded because Blizzard UI names can change between builds.
- Community examples can influence product thinking, but implementation must remain original.
