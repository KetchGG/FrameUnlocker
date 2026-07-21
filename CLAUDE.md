# FrameUnlocker — Claude Context

## What this is
A World of Warcraft addon (Lua) that unlocks and repositions UI frames Blizzard normally locks. Written and maintained by Ketch (Andrew). Published on CurseForge.

**Current version:** 1.6.0  
**TOC interface versions:** Retail 120007, TBC Anniversary 20506, Classic Era 11509

## File map

| File | Role |
|------|------|
| `Config.lua` | Addon namespace setup, `FU.defaults`, `FU:InitDB()`, `FU:Get()`, `FU:Set()`, `FU:ResetToDefaults()` |
| `Chat.lua` | Chat frame unlock/lock — drag by tab, resize from corner (`FU:UnlockChatFrame` / `FU:LockChatFrame`) |
| `Frames.lua` | Scale-only features (no repositioning): raid and party frames (`FU:ApplyRaidFrameScale` / `ApplyPartyFrameScale`) |
| `Anchors.lua` | Repositionable features via draggable anchors: loot rolls, arena/flag carriers, quest tracker, raid warnings, below-minimap widgets (`UIWidgetBelowMinimapContainerFrame`). Shared `CreatePositionAnchor` factory + shared `HookFramePosition` + shared `ScaledOffset` (scale-corrects saved offsets); per-feature `Create/Show/Hide/Toggle*Anchor`, `Apply*Scale`/`Apply*Position`, `Reset*`, `Hook*Position`. **Note:** the top-center widget container (`UIWidgetTopCenterContainerFrame`) is deliberately NOT supported — its widgets anchor to `UIParent` (not the container), so moving the container repositions nothing; other addons cover that frame. |
| `Core.lua` | Shared utilities: `FU:Print()`, `FU:ApplyAllSettings()`, and **combat deferral** (`FU:InCombat`, `FU:DeferToCombatEnd(key, fn)`, `FU:FlushCombatDeferred()`) for secure/managed frames that can't be moved during combat |
| `Options.lua` | Blizzard settings panel UI (`FU:CreateOptionsPanel()`, `FU:OpenOptions()`, `FU:CloseOptions()`). Handles both modern `Settings` API and legacy `InterfaceOptions_AddCategory`. A `scaleControls` descriptor drives `panel.refresh`. Also `FU:SetupEditModeExtras()` — injects a compact control beneath the Edit Mode dialog: a scale slider for raid/party unit frames, an unlock checkbox for the chat frame (taint-safe: UIParent-parented, anchored to the dialog, post-hook only, non-protected actions only) |
| `Init.lua` | Event frame, `ADDON_LOADED` / `PLAYER_LOGIN` startup, throttled event handlers, `PLAYER_REGEN_ENABLED` (flushes combat-deferred work), slash commands |
| `FrameUnlocker.toc` | Retail (12.0.x) |
| `FrameUnlocker_TBC.toc` | TBC Anniversary (2.5.x) |
| `FrameUnlocker_Vanilla.toc` | Classic Era / HC / SoD (1.15.x) |

Load order: Config → Chat → Frames → Anchors → Core → Options → Init.

## Addon namespace
All files share `local addonName, FU = ...`. `FU` is the addon table. `_G.FrameUnlocker = FU` is set in Config.lua for external access.

## Settings system
- `FU.defaults` in Config.lua is the single source of truth for all setting keys and default values.
- `FU:InitDB()` merges defaults into `FrameUnlockerDB` (SavedVariables). Only missing keys are filled; existing values are preserved.
- `FU:Get(key)` / `FU:Set(key, value)` — `Set` only accepts keys present in `defaults` (guards against typos).
- Position coordinates are stored as `false` (not nil) to indicate "use default". Always check `x and x ~= false`.
- `MigrateDB(db)` in Config.lua runs one-time saved-variable migrations after the defaults merge. Its flags (e.g. `lootFrameYIsBottom`) live **outside** `FU.defaults` on purpose — a flag in `defaults` would be cleared by `ResetToDefaults` and the migration would re-run against already-migrated data.

## Supported WoW clients and compatibility rules
All clients share the same Lua files; only the TOC differs. Never branch on the client — use feature detection. Compatibility facts below are **not authoritative to branch on**; they only explain what tends to differ so you know what to feature-detect.
- **Retail** (12.0.x) — full feature set. Uses `Settings` API, `EditModeManagerFrame`, `CompactRaidFrameContainer.ApplyToFrames` (mixin method), `BackdropTemplateMixin`, `PartyFrame`.
- **TBC Anniversary** (2.5.x) — same Lua files. Most features work.
- **Classic Era** (1.15.x) — same Lua files. As of **1.15.9** Era gained `EditModeManagerFrame` and the `Settings` API, so the Edit Mode hook and modern options panel now run here too (previously dormant). Still no `PartyFrame` (`PartyMemberFrame1..4` instead). `CompactRaidFrameContainer` has **no mixin** — its methods are globals (`CompactRaidFrameContainer_ApplyToFrames(self, ...)`), so `CompactRaidFrameContainer.ApplyToFrames` is nil there; `Init.lua` hooks the global by name in that case.

Compatibility approach: **feature detection, not version checks**. Check `if SomeFrame then` before using it. Never hardcode version numbers in Lua. Because everything is feature-detected, don't delete a compatibility fallback just because the current clients no longer need it — it costs nothing and guards other/older clients (SoD, HC, unpatched).

### Party vs raid frames (Classic Era gotcha)
Era has no `PartyFrame`, and `CompactPartyFrame` is reparented onto `CompactRaidFrameContainer` (unconditional `SetParent` in Blizzard's `AddGroup`), so scaling both would compound — frame scale is inherited multiplicatively. Era never displays party and raid frames simultaneously, though, so `Frames.lua` resolves ownership of the container by context via `PartyUsesRaidContainer()` (`GetDisplayedAllyFrames()` + `IsInRaid()`), and `NormalizeRaidContainer()` re-asserts the winning scale so a group-type change can't leave a stale one. Note `CompactPartyFrame` is generated lazily and never torn down, so `if CompactPartyFrame then` is **not** a valid test for which frames are on screen.

## Adding a new repositionable frame (the pattern)
Every repositionable feature follows this exact structure — use it as a template:

1. **Config.lua** — add `scaleXxx`, `xxxScale`, `xxxX`, `xxxY` to `FU.defaults` with appropriate defaults.
2. **Anchors.lua** (repositionable frames; scale-only frames go in **Frames.lua** instead) — implement:
   - `FU:CreateXxxAnchor()` — built via the shared `CreatePositionAnchor` factory. Pass `scaleKey` + `applyScale` (the `Apply*Scale` FU method) so the anchor's built-in scale slider works. The anchor has a scale slider and a Lock button; Lock runs `onLock` then reopens the panel. Opening an anchor from the panel's Move button closes the panel (`FU:CloseOptions()`); locking reopens it (`FU:OpenOptions()`).
   - `FU:ShowXxxAnchor()` / `FU:HideXxxAnchor()` / `FU:ToggleXxxAnchor()`
   - `FU:ApplyXxxScale(scale)` — calls `frame:SetScale(scale or FU:Get("xxxScale") or 1.0)`
   - `FU:ApplyXxxPosition()` — guards on `scaleXxx` enabled, then calls `frame:SetPoint(...)` with repositioning flag set.
   - `FU:HookXxxPosition()` — a thin wrapper over the shared `HookFramePosition(spec)` (debounced `hooksecurefunc(frame, "SetPoint", ...)` reapply; `spec.delay` per feature).
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

## Combat safety
Secure/managed Blizzard frames (e.g. `ArenaEnemyFrames`, the objective tracker)
**can't be moved or reparented during combat** — doing so is blocked and taints the
addon. Any `Apply*Position` that does `SetPoint`/`SetParent`/reparent on such a frame
must defer when in combat:

```lua
if not Frame then return end
if self:InCombat() then
    self:DeferToCombatEnd("xxxPosition", function() self:ApplyXxxPosition() end)
    return
end
```

`Core.lua` owns the queue; `Init.lua` flushes it on `PLAYER_REGEN_ENABLED`. Note
`SetScale` is **not** combat-restricted, so scale-only appliers don't need this.

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
- Version bumped in all three TOC files simultaneously (they must match): `.toc`, `_TBC`, `_Vanilla`.
- CHANGELOG.md is maintained manually per release.

## Slash commands
`/fu` and `/frameunlocker` both work. Only two behaviors: `reset` resets all settings to defaults; anything else (including no argument) opens the options panel. Per-feature moving is done via the Move buttons in the panel, not slash commands.

## Print helper
`FU:Print(msg)` — prefixes `|cff2BB673[FU]|r ` (green) in DEFAULT_CHAT_FRAME.
