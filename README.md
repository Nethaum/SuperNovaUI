# SuperNovaUI

SuperNovaUI is a modular World of Warcraft Retail UI suite.

The project focuses on practical interface improvements organized into clear feature modules. Each module is designed to be small, predictable, and easy to configure as the suite grows.

## Features

### Window Mover

Move and scale selected Blizzard UI windows with guarded interactions.

- Hold `Shift` and drag a registered window to move it.
- Hold `Ctrl` and use the mouse wheel over a registered window to scale it.
- Saved positions and scale values are stored in `SuperNovaUIDB`.
- Window movement is disabled during combat lockdown.

### Chat History

Use regular arrow-key history navigation in the chat input box.

- Press `Enter` to open chat.
- Press `Up` and `Down` to cycle through recently typed chat text and slash commands.
- Chat edit boxes are configured with history lines and direct arrow navigation.

## Commands

- `/snui` or `/supernova` - show help.
- `/snui status` - show global SuperNovaUI status.
- `/snui windows status` - show Window Mover status.
- `/snui windows lock` - lock window movement and scaling.
- `/snui windows unlock` - unlock window movement and scaling.
- `/snui windows reset` - close windows and reset saved window positions and scales.
- `/snui chat status` - show Chat History status.
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
