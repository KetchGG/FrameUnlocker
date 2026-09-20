# FrameUnlocker

Unlock and customize your UI frames. Drag chat by its tab, resize it from the corner, and scale or reposition frames Blizzard normally locks down.

## Features

### Chat Frames
- Unlock chat to drag by tab and resize from the corner
- Stays clamped to screen so it can't be lost off-edge
- Automatically re-unlocks after exiting Edit Mode
- Toggle on/off in settings, or straight from the Edit Mode chat dialog

### Frame Scaling & Positioning
Each of these can be scaled from 50% to 150%; the repositionable ones also get a draggable on-screen anchor with its own scale slider, plus Move and Reset buttons in settings.

| Frame | Scale | Reposition |
|-------|:-----:|:----------:|
| Raid Frames | ✔ | — |
| Party Frames | ✔ | — |
| Arena / Flag Carriers | ✔ | ✔ |
| Loot Roll Frames | ✔ | ✔ |
| Quest Tracker | ✔ | ✔ |
| Raid Warnings / Hardcore death alerts | ✔ | ✔ |
| Below-Minimap Widgets | ✔ | ✔ |

- **Arena / Flag Carriers** also covers WSG/BG flag carrier frames.
- **Quest Tracker** and **Below-Minimap Widgets** are removed from Blizzard's managed layout while repositioned to prevent flickering.
- Repositioning stays aligned to your anchor at any scale, and adjusting the scale keeps the frame put.

### Combined Bag Frame (Retail)
- Unlock the combined bags to drag them anywhere, the same way as the chat frame
- Position is remembered between sessions
- Retail only — other clients use individual bag frames

### Edit Mode Integration
When you select a frame in Blizzard's Edit Mode, a matching FrameUnlocker control appears beneath its dialog:
- **Raid Frames / Party Frames** → a scale slider
- **Chat Frame** → an unlock checkbox

So our settings sit right alongside Edit Mode's own, no need to leave Edit Mode.

### Move Anchors
- Clicking **Move** closes the settings panel so the on-screen anchor is unobstructed
- Each anchor carries its own scale slider — position and scale together
- Clicking **Lock** saves the position and reopens settings

### Settings Panel
- Full options UI integrated into the AddOns menu, on a single page
- All preferences persist between sessions
- Reset buttons restore both position and scale

## Commands

| Command | Description |
|---------|-------------|
| `/fu` | Open the settings panel |
| `/fu reset` | Reset all settings to defaults |

Per-frame moving is done from the Move buttons in the settings panel.

## Supported Versions

- Retail (Midnight)
- TBC Anniversary
- Classic Era (Hardcore / Season of Discovery)
- WoW Forever

## WoW Forever beta note

The Forever beta client (1.60.x) has a bug where it doesn't read addon settings
files back when it starts, so **settings reset every time you fully close the
game**. FrameUnlocker works around as much of this as an addon can: your
settings are also saved per character and restored automatically, so they survive
`/reload` and logging out to character select. Restoring after a full client exit
isn't something an addon can fix — Blizzard has said they'll fix the underlying
bug. Other clients are unaffected.
