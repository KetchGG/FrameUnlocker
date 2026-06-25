# FrameUnlocker — Claude Context

## What this is
A World of Warcraft addon (Lua) that unlocks and repositions UI frames Blizzard normally locks. Written and maintained by Ketch (Andrew). Published on CurseForge.

**Current version:** 1.5.0  
**TOC interface versions:** Retail 120000, TBC Anniversary 20505, Classic Era 11504

## File map

| File | Role |
|------|------|
| `Config.lua` | Addon namespace setup, `FU.defaults`, `FU:InitDB()`, `FU:Get()`, `FU:Set()`, `FU:ResetToDefaults()` |
| `Core.lua` | All frame manipulation: chat unlock/lock, scaling, anchor creation, position hooks, `FU:Print()`, `FU:ApplyAllSettings()` |
| `Options.lua` | Blizzard settings panel UI (`FU:CreateOptionsPanel()`, `FU:OpenOptions()`). Handles both modern `Settings` API and legacy `InterfaceOptions_AddCategory`. |
| `Init.lua` | Event frame, `ADDON_LOADED` / `PLAYER_LOGIN` startup, throttled event handlers, slash commands |
| `FrameUnlocker.toc` | Retail (12.0.0+) |
| `FrameUnlocker_TBC.toc` | TBC Anniversary (2.5.5) |
| `FrameUnlocker_Vanilla.toc` | Classic Era / HC / SoD (1.15.x) |

Load order: Config → Core → Options → Init.

## Addon namespace
All files share `local addonName, FU = ...`. `FU` is the addon table. `_G.FrameUnlocker = FU` is set in Config.lua for external access.

## Settings system
- `FU.defaults` in Config.lua is the single source of truth for all setting keys and default values.
- `FU:InitDB()` merges defaults into `FrameUnlockerDB` (SavedVariables). Only missing keys are filled; existing values are preserved.
- `FU:Get(key)` / `FU:Set(key, value)` — `Set` only accepts keys present in `defaults` (guards against typos).
- Position coordinates are stored as `false` (not nil) to indicate "use default". Always check `x and x ~= false`.

## Supported WoW clients and compatibility rules
- **Retail** — full feature set. Uses `Settings` API, `EditModeManagerFrame`, `CompactRaidFrameContainer.ApplyToFrames`, `BackdropTemplateMixin`.
- **TBC Anniversary** — same Lua files, different TOC. Most features work.
- **Classic Era** — same Lua files. Missing: Edit Mode hook, `BackdropTemplateMixin` (use nil guard). `PartyMemberFrame1..4` instead of `PartyFrame`. No `EditModeManagerFrame`.

Compatibility approach: **feature detection, not version checks**. Check `if SomeFrame then` before using it. Never hardcode version numbers in Lua.

## Adding a new repositionable frame (the pattern)
Every repositionable feature follows this exact structure — use it as a template:

1. **Config.lua** — add `scaleXxx`, `xxxScale`, `xxxX`, `xxxY` to `FU.defaults` with appropriate defaults.
2. **Core.lua** — implement:
   - `FU:CreateXxxAnchor()` — draggable green/colored anchor frame, Scale button (opens options), Lock button.
   - `FU:ShowXxxAnchor()` / `FU:HideXxxAnchor()` / `FU:ToggleXxxAnchor()`
   - `FU:ApplyXxxScale(scale)` — calls `frame:SetScale(scale or FU:Get("xxxScale") or 1.0)`
   - `FU:ApplyXxxPosition()` — guards on `scaleXxx` enabled, then calls `frame:SetPoint(...)` with repositioning flag set.
   - `FU:HookXxxPosition()` — `hooksecurefunc(frame, "SetPoint", ...)` with throttled reapply using `C_Timer.After`.
   - `FU:ResetXxxToDefault()` — restores frame to Blizzard default (no saved coord changes).
   - `FU:ResetXxxPosition()` — clears saved coords, resets scale to 1.0, calls `ResetXxxToDefault`.
3. **Options.lua** — add `CreateScaleControl(...)` call, Move/Reset buttons, enable/disable helpers, wire `HookScript("OnClick")` on the checkbox, add to `panel.refresh`.
4. **Init.lua** — call `FU:HookXxxPosition()` in `PLAYER_LOGIN` and `FU:ApplyXxxPosition()` in `ReapplyScaling`.
5. **Config.lua** — add the new apply calls to `FU:ApplyAllSettings()` in Core.lua.
6. Slash command in Init.lua if needed.

## Repositioning guard pattern
To prevent `hooksecurefunc` SetPoint hooks from looping when we reposition a frame:

```lua
self.xxxRepositioning = true
frame:ClearAllPoints()
frame:SetPoint(...)
self.xxxRepositioning = false
```

In the hook: `if FU.xxxRepositioning then return end`

## Throttle helper (Init.lua)
```lua
ThrottledCall("key", delaySeconds, func)
```
Deduplicates rapid-fire events. Key is a string; if already pending, silently skips.

## Quest tracker special case
The quest tracker must be removed from Blizzard's managed frame system to prevent flickering:
```lua
tracker.isManagedFrame = false
tracker.isRightManagedFrame = false
tracker:SetParent(UIParent)
```
On reset, restore `isManagedFrame = true`, `isRightManagedFrame = true`, and reparent to `UIParentRightManagedFrameContainer`.

## Options panel layout
4-column fixed layout: COL1=16, COL2=155, COL3=294, COL4=433. `yOffset` tracks vertical position, starts at -80 and decrements. `CreateScaleControl()` returns `check, slider, sliderLabel`. `isRefreshing = true` during `panel.refresh()` to suppress slider `OnValueChanged` callbacks.

## No build system
No npm, no compilation, no test runner. Testing requires loading in WoW. When suggesting changes, remember there is no automated way to verify correctness — be precise and conservative.

## Versioning
- Version bumped in all three TOC files simultaneously (they must match).
- CHANGELOG.md is maintained manually per release.

## Slash commands
`/fu` and `/frameunlocker` both work. Subcommands: options/config/settings, loot, quest/tracker, arena, warn/warning, reset. Any unrecognized msg opens options.

## Print helper
`FU:Print(msg)` — prefixes `|cff2BB673[FU]|r ` (green) in DEFAULT_CHAT_FRAME.
