# Changelog

## Version 1.3.0
### New Features
- **Party Frame Scaling** - Scale party frames from 50% to 150%
- **Status Bar Scaling** - Scale XP, reputation, and honor bars
- **Loot Roll Frame Scaling** - Scale group loot roll frames
- **Loot Frame Positioning** - Move loot roll frames anywhere on screen with a draggable anchor
- `/fu loot` - New command to toggle loot frame positioning anchor

### Improvements
- **Two-column layout** - Related scaling options now grouped side-by-side
- **Visual dividers** - Cleaner separation between settings sections
- **Author credit** - "by Ketch" now displayed in settings panel
- **Smart button states** - Move/Reset buttons disabled when loot scaling is off
- **Throttled event handling** - Improved performance during group changes and loading screens
- **Persistent scaling** - Settings automatically reapply after UI changes, group updates, and zone transitions
- Removed `/fu unlock`, `/fu lock`, `/fu scale` commands (use settings panel instead)

### Technical
- Added hooks for GROUP_ROSTER_UPDATE, UI_SCALE_CHANGED, PLAYER_ENTERING_WORLD events
- Added CompactRaidFrameContainer layout hook for raid profile changes
- Consolidated duplicate code and added throttling helpers

## Version 1.2.2
### New Features
- **Reset to Defaults** - Added button in settings panel to reset all options
- **Slash Commands in Settings** - Commands reference now shown in the options panel
- `/fu reset` - New command to reset settings to defaults

### Improvements
- `/fu` now opens settings directly (previously showed help in chat)
- Fixed hook stacking bug when chat was re-unlocked after Edit Mode
- Extracted shared settings application logic for consistency
- Added key validation to prevent setting unknown config values
- Raid frame scaling now defaults to off
- Default scale changed from 80% to 100%

## Version 1.2.1
- Updated Interface version to 120000 for WoW 12.0.0 compatibility

## Version 1.2.0
**Major Update - Settings & Raid Frames**

### New Features
- **Settings Panel** - Added full options UI accessible via `/fu options` or the AddOns settings menu
- **Raid Frame Scaling** - Scale compact raid frames from 50% to 150% with a slider
- **Persistent Settings** - Your preferences now save between sessions via SavedVariables
- **Lock/Unlock Toggle** - Chat unlock can now be toggled on/off in settings
- **Resize Support** - Chat frame can now be resized by dragging the corner (resize button enabled)

### New Commands
- `/fu options` - Open settings panel
- `/fu unlock` - Force unlock chat
- `/fu lock` - Force lock chat
- `/fu scale` - Apply raid frame scale

### Improvements
- Modular code architecture (Config, Core, Options, Init)
- Feature detection for settings API (works on both modern and legacy clients)
- Added addon logo/branding
