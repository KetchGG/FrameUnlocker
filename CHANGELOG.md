# Changelog

## Version 1.7.1
### Bug Fixes
- **Settings not saving on WoW Forever** - The WoW Forever beta client doesn't read addon settings files back, so every setting reset on `/reload` or relog. Settings are now also saved per character and restored automatically when the account-wide settings come back empty. **Scope:** this covers `/reload` and logging out to character select; a full client exit still starts from defaults, which is a client bug Blizzard has said it will fix and no addon can work around. Other clients are unaffected — their settings always take precedence.
- **Addon flagged out of date on WoW Forever** - That client ignores the `_Forever` TOC suffix and loads `FrameUnlocker.toc`, so it saw the Retail interface version and marked the addon out of date. The Retail TOC now declares `## Interface: 16001, 120100`, covering both.

## Version 1.7.0
### New Features
- **WoW Forever support** - Added `FrameUnlocker_Forever.toc` (interface 16001) for Blizzard's new WoW Forever client, which entered beta 2026-09-17. Same Lua files as the other clients; no code changes were needed since compatibility is handled entirely by feature detection.
- **Combined bag frame unlock** - The combined bag frame can now be unlocked and dragged freely at any time, same as the chat frame, with its position remembered across sessions. Retail-only, since Classic Era/TBC/Forever use individual bag frames instead of the combined view.

### Bug Fixes
- **Stale Retail interface version** - `FrameUnlocker.toc` still declared interface 120007 (12.0.7) after Retail patched to 12.1.0; bumped to 120100 so the addon isn't flagged out of date.

## Version 1.6.1
### Bug Fixes
- **Loot roll position stutter** - Repositioned loot roll frames no longer snap back to the default spot when a roll appears. The loot container is one of Blizzard's managed frames, which re-anchored it to default on every update; it's now detached from that managed layout while repositioned (and handed back on reset), the same way the quest tracker is.

## Version 1.6.0
### Bug Fixes
- **Combat-safe frame repositioning** - Arena/flag-carrier frames and the objective tracker are secure/managed and can't be moved during combat (doing so was blocked and tainted the addon). Both repositioning *and* resetting these frames is now queued during combat and applied automatically when combat ends.

- **Loot roll flickering** - Repositioned loot rolls no longer flash at Blizzard's default spot before snapping into place; the correction now happens on the next frame rather than 100ms later.
- **Loot roll stacking** - The roll stack is now anchored by its bottom edge, so multiple simultaneous rolls pile upward like Blizzard intends instead of the whole stack shifting every time a roll appears or expires. Existing saved positions are migrated automatically.
- **Loot roll reset** - Resetting loot roll position now re-anchors the container explicitly instead of leaving it briefly unanchored.
- **Party frame scaling in Classic Era** - Party scaling had no effect once the compact party frame had been created, because it took priority over the legacy `PartyMemberFrame`s that were actually on screen. Party and raid scaling also compounded when raid-style party frames were enabled, since Era nests the compact party frame inside the raid container. Scaling now follows whichever frames are actually displayed.
- **Raid scale reapply in Classic Era** - The hook that reapplies raid scale after Blizzard rebuilds the frames only installed on Retail/TBC. Era exposes the same routine as a global function rather than a container method, so raid scale could briefly revert to default on some layout rebuilds; it's now hooked on Era too.

- **Scaled frames landing off-position** - Repositioned frames (arena/flag carriers, quest tracker, loot rolls, raid warnings) drifted away from where the anchor was placed the further their scale was from 100%, because position offsets weren't corrected for the frame's scale. Frames now land where you drop the anchor at any scale, and adjusting the scale slider keeps them put.

### New Features
- **Below-minimap widgets** - New repositionable/scalable control for the below-minimap objective widget container.
- **Edit Mode integration** - Selecting a frame in Blizzard's Edit Mode now shows a matching FrameUnlocker control beneath its dialog: a scale slider for Raid/Party Frames, and an unlock checkbox for the Chat Frame - so our settings sit right alongside Edit Mode's own.

### Removed
- **Status bar scaling** - Removed the status bar (XP/reputation) scaling option. Blizzard's Edit Mode now scales these bars natively, so the feature is redundant.

### Improvements
- **Move/Lock flow** - Clicking Move now closes the settings panel so the on-screen anchor is unobstructed, and clicking Lock on the anchor reopens settings automatically.
- **Scale slider on anchors** - Each move anchor now has its own scale slider, so you can position and scale a frame together without going back to the settings panel.
- **Simplified slash commands** - `/fu` now just opens settings and `/fu reset` restores defaults. The per-feature move commands (loot/arena/quest/warn/etc.) were removed; use the Move buttons in the settings panel instead.
- **Settings panel** - Reorganized into two four-column sections ("Group and Gameplay Frames", "PvP and Misc") so everything fits on a single page without scrolling, even with the new PvP controls.
- **Move anchors** - Enlarged the draggable position anchors and made their labels wrap, so the Scale/Lock buttons and titles no longer crowd or overflow.
- **Client compatibility** - Updated interface versions for Retail 12.0.7, TBC Anniversary 2.5.6, and Classic Era 1.15.9.
- **Addon list icon** - Added an `IconTexture` so FrameUnlocker shows its logo in the in-game AddOns list.

### Technical
- Internal combat-deferral queue in `Core.lua` (`InCombat`/`DeferToCombatEnd`/`FlushCombatDeferred`), flushed on `PLAYER_REGEN_ENABLED`.
- Refactored the options panel's per-feature anchor/reset controls into a shared `CreatePositionControls` helper.

## Version 1.5.0
### New Features
- **Classic Era Support** - Added `FrameUnlocker_Vanilla.toc` for WoW Classic Era (including Hardcore/Season of Discovery)
- **Raid Warning Positioning** - Scale and reposition raid warnings and Hardcore death alerts
  - Draggable anchor for custom positioning
  - Scale slider from 50% to 150%
  - Move and Reset buttons in settings
- `/fu warn` - Toggle raid warning positioning anchor

### Improvements
- **Four-column layout** - Settings panel expanded to fit all options without scrolling
- **Classic Era compatibility note** - Asterisk marks features not available in Classic Era
- Defensive checks for Edit Mode hooks on clients that don't support it

### Technical
- Conditional `BackdropTemplate` usage for Classic Era anchor compatibility
- Added `HookScript` existence check for `EditModeManagerFrame` on non-retail clients
- Raid warning position hook with throttled reapply to prevent Blizzard resets

## Version 1.4.0
### New Features
- **Quest Tracker** - Scale and reposition the quest/objective tracker
  - Draggable anchor for custom positioning
  - Removed from Blizzard's managed frame system to prevent flickering
  - Position and scale persist across sessions
- **Arena / Flag Carrier Frames** - Scale and reposition arena enemy frames (also used for WSG/BG flag carriers)
  - Draggable anchor for custom positioning
  - Move and Reset buttons in settings
- `/fu quest` - Toggle quest tracker positioning anchor
- `/fu arena` - Toggle arena frames positioning anchor

### Improvements
- **Three-column layout** - More compact settings panel with better organization
- **Reorganized sections** - Chat Frames, Group & PvP Frames, Misc Frames
- **Reset buttons now reset scale** - Reset buttons restore both position and scale to defaults
- Improved hook system with repositioning guards to prevent frame flickering
- Cleaner divider styling in options panel

### Technical
- Added hooks for ARENA_PREP_OPPONENT_SPECIALIZATIONS and ARENA_OPPONENT_UPDATE events
- Quest tracker removed from UIParentRightManagedFrameContainer when repositioned
- Fixed naming collision in internal reset functions

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
