# Changelog

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
