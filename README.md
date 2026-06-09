# SuperNovaUI

A modular World of Warcraft Retail UI suite.

SuperNovaUI is being built as a clean, modular AddOn suite for Retail. The long-term goal is to consolidate common UI, utility, collection, map, group, and quality-of-life features into one coherent project with clear modules and one configuration surface.

## Current Module

### FrameMover

Makes selected Blizzard UI windows movable with a guarded drag interaction.

- Hold `Shift` and drag a registered frame to move it.
- Hold `Ctrl` and use the mouse wheel over a registered frame to scale it.
- Positions and scale are stored in `SuperNovaUIDB`.
- The module avoids moving frames while in combat lockdown.

This module is implemented from scratch for SuperNovaUI.

## Commands

- `/snui` or `/supernova` - show help.
- `/snui status` - show enabled modules and FrameMover status.
- `/snui lock` - lock FrameMover.
- `/snui unlock` - unlock FrameMover.
- `/snui resetframes` - clear saved frame positions and scales.
- `/snui reload` - reload the UI.

## Source Policy

We use official Blizzard sources first. Community docs are fallback references for AddOn UI APIs when official coverage is missing or incomplete. Third-party repositories are examples only and are not copied.

See `docs/SOURCES.md` for the current source notes.
