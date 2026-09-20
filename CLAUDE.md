# FrameUnlocker — Claude Context

## What this is
A World of Warcraft addon (Lua) that unlocks and repositions UI frames Blizzard normally locks. Written and maintained by Ketch (Andrew). Published on CurseForge.

**Current version:** 1.6.1  
**TOC interface versions:** Retail 120100, TBC Anniversary 20506, Classic Era 11509, WoW Forever 16001

## File map

| File | Role |
|------|------|
| `Config.lua` | Addon namespace setup, `FU.defaults`, `FU:InitDB()`, `FU:Get()`, `FU:Set()`, `FU:ResetToDefaults()` |
| `Chat.lua` | Chat frame unlock/lock — drag by tab, resize from corner (`FU:UnlockChatFrame` / `FU:LockChatFrame`) |
| `Frames.lua` | Scale-only features (no repositioning): raid and party frames (`FU:ApplyRaidFrameScale` / `ApplyPartyFrameScale`) |
| `Anchors.lua` | Repositionable features via draggable anchors: loot rolls, arena/flag carriers, quest tracker, raid warnings, below-minimap widgets (`UIWidgetBelowMinimapContainerFrame`). Shared `CreatePositionAnchor` factory + shared `HookFramePosition` + shared `ScaledOffset` (scale-corrects saved offsets); per-feature `Create/Show/Hide/Toggle*Anchor`, `Apply*Scale`/`Apply*Position`, `Reset*`, `Hook*Position`. Also the combined bag frame (`ContainerFrameCombinedBags`, Retail-only): unlike the anchor-based features, it's dragged directly and continuously while unlocked (`FU:UnlockBagFrame`/`LockBagFrame`, same model as `Chat.lua`) rather than via a proxy anchor — position is saved on drag-stop and restored via `FU:ApplyBagFramePosition` + `HookBagFramePosition` (shares the `HookFramePosition` helper). Not a managed/secure frame, so no combat deferral needed. **Note:** the top-center widget container (`UIWidgetTopCenterContainerFrame`) is deliberately NOT supported — its widgets anchor to `UIParent` (not the container), so moving the container repositions nothing; other addons cover that frame. |
| `Core.lua` | Shared utilities: `FU:Print()`, `FU:ApplyAllSettings()`, and **combat deferral** (`FU:InCombat`, `FU:DeferToCombatEnd(key, fn)`, `FU:FlushCombatDeferred()`) for secure/managed frames that can't be moved during combat |
| `Options.lua` | Blizzard settings panel UI (`FU:CreateOptionsPanel()`, `FU:OpenOptions()`, `FU:CloseOptions()`). Handles both modern `Settings` API and legacy `InterfaceOptions_AddCategory`. A `scaleControls` descriptor drives `panel.refresh`. Also `FU:SetupEditModeExtras()` — injects a compact control beneath the Edit Mode dialog: a scale slider for raid/party unit frames, an unlock checkbox for the chat frame (taint-safe: UIParent-parented, anchored to the dialog, post-hook only, non-protected actions only) |
| `Init.lua` | Event frame, `ADDON_LOADED` / `PLAYER_LOGIN` startup, throttled event handlers, `PLAYER_REGEN_ENABLED` (flushes combat-deferred work), slash commands |
| `FrameUnlocker.toc` | Retail (12.1.x) |
| `FrameUnlocker_TBC.toc` | TBC Anniversary (2.5.x) |
| `FrameUnlocker_Vanilla.toc` | Classic Era / HC / SoD (1.15.x) |
| `FrameUnlocker_Forever.toc` | WoW Forever (1.60.x) |

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
- **Retail** (12.1.x) — full feature set. Uses `Settings` API, `EditModeManagerFrame`, `CompactRaidFrameContainer.ApplyToFrames` (mixin method), `BackdropTemplateMixin`, `PartyFrame`.
- **TBC Anniversary** (2.5.x) — same Lua files. Most features work.
- **Classic Era** (1.15.x) — same Lua files. As of **1.15.9** Era gained `EditModeManagerFrame` and the `Settings` API, so the Edit Mode hook and modern options panel now run here too (previously dormant). Still no `PartyFrame` (`PartyMemberFrame1..4` instead). `CompactRaidFrameContainer` has **no mixin** — its methods are globals (`CompactRaidFrameContainer_ApplyToFrames(self, ...)`), so `CompactRaidFrameContainer.ApplyToFrames` is nil there; `Init.lua` hooks the global by name in that case.
- **WoW Forever** (1.60.x, interface 16001) — new client line, launched beta 2026-09-17. Early community findings (forever-addon-kit) say it runs on the **Retail 12.x engine** (`WOW_PROJECT_ID == WOW_PROJECT_MAINLINE`, full `C_*` namespaces, old Classic globals like `GetSpellInfo` absent) with Classic-era content — not the Era codebase as first reported. **Unverified by us in-game** — don't assume parity with either Era or Retail; check `if SomeFrame then` as always and update this note once tested.
  - **SavedVariables bug (beta build 1.60.1), verified in-game 2026-09-19:** the
    client writes SavedVariables but never reads back the **account-wide** table,
    so `FrameUnlockerDB` arrives nil every session (a hand-seeded account file
    stayed nil through main chunk/`ADDON_LOADED`/`PLAYER_LOGIN`).
    **`SavedVariablesPerCharacter` does load** -- but only within a running client:
    a per-character table came back carrying the previous logout's value after a
    logout->login, and came back empty after a client restart. So `Config.lua`
    keeps a copy of the DB in `FrameUnlockerCharDB` and restores from it when the
    account table is empty (`FU.restoredFromMirror`); a loaded account DB always
    wins, so this is inert on every other client. **Verified scope:** the backup
    persists across `/reload` and logging out to character select, but **not** a full
    client exit -- on a cold start every addon comes up on defaults, because the
    client only reads SavedVariables files at launch and that path is broken for both
    account-wide and per-character tables. No addon-side fix exists for that case
    (Leatrix Plus, 1.60.03, ships a manual file-deletion workaround with the same
    ceiling and notes Blizzard will fix the bug).
    Consequence on the buggy client: settings are per character, and a cold start
    still starts from defaults.
  - **Dead ends, don't retry:** addon-registered **CVars are never written to disk**
    on that build (`config-cache.wtf` untouched after sessions that set them), so a
    CVar mirror only survives `/reload`. And **the client ignores the `_Forever`
    TOC suffix** — it loads the base `FrameUnlocker.toc`, confirmed with an
    `X-TocFlavor` metadata probe, which is why that TOC now leads with
    `## Interface: 16001, 120100`. `## LoadSavedVariablesFirst: 1` changed nothing.

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
- Version bumped in all four TOC files simultaneously (they must match): `.toc`, `_TBC`, `_Vanilla`, `_Forever`.
- CHANGELOG.md is maintained manually per release.

## Slash commands
`/fu` and `/frameunlocker` both work. Only two behaviors: `reset` resets all settings to defaults; anything else (including no argument) opens the options panel. Per-feature moving is done via the Move buttons in the panel, not slash commands.

## Print helper
`FU:Print(msg)` — prefixes `|cff2BB673[FU]|r ` (green) in DEFAULT_CHAT_FRAME.
