# Contributing

SuperNovaUI is built around small, focused modules and predictable behavior.

## Source Rules

- Use official Blizzard documentation, local client metadata, or Blizzard-published policy first.
- Use community documentation only when official sources do not cover the needed UI API detail.
- Treat third-party AddOn repositories as product and architecture references only.
- Do not copy code, strings, assets, distinctive structure, or implementation details from other AddOns.

## Code Style

- Lua files use `local addonName, SN = ...` and attach shared project API to `SN`.
- Modules register with `SN:RegisterModule("moduleName", moduleTable)`.
- Keep functions small, named after their intent, and scoped to one responsibility.
- Prefer clear guards over clever control flow.
- If a frame or API is missing, skip cleanly.
- Do not modify protected frames during combat lockdown.
- Comments should explain intent, constraints, or risk.

## Verification

- Validate Lua syntax when possible before packaging.
- Check the `.toc` interface against the local Retail client build before releases.
- Final compatibility testing must happen inside World of Warcraft Retail.
