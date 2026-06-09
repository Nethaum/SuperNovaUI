# SuperNovaUI Agent Guide

## Principles

- Use official Blizzard documentation, local Blizzard client metadata, or Blizzard-published policy first.
- Use community documentation only when official sources do not cover the needed UI API detail.
- Treat third-party AddOn repositories as inspiration only. Do not copy code, structure verbatim, strings, assets, or distinctive implementation details.
- Keep code guided by Clean Code: small functions, clear names, explicit responsibilities, and minimal global state.
- Avoid hidden behavior, obfuscation, in-game ads, donation prompts, or paid features.

## Coding Style

- Lua files use `local addonName, SN = ...` and attach public project API to `SN`.
- Modules register with `SN:RegisterModule("moduleName", moduleTable)`.
- Prefer guards over cleverness. If a frame or API is missing, skip cleanly.
- Do not modify protected frames during combat lockdown.
- Comments should explain intent or risk, not repeat the line of code.

## Verification

- Validate Lua syntax when possible with `luaparse` or a Lua parser.
- The final compatibility test must happen inside World of Warcraft Retail.
- Check `.toc` interface against the local client build before releases.
