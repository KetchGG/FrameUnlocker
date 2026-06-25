# FrameUnlocker — Pre-Release Testing Checklist

**Version:** 1.5.0  
**Clients:** Retail · TBC Anniversary · Classic Era

Work through each section top to bottom. Items marked **[Retail]**, **[TBC]**, or **[Classic]** only apply to that client. Items marked **[Group]**, **[Arena]**, **[Loot]** require a specific in-game condition — batch those together to save time.

---

## 1. Pre-Flight

- [ ] Load game — no Lua error (red text in chat)
- [ ] `[FU] Initialized. Type /fu for options.` appears in chat on login
- [ ] `/reload` — no Lua error, initialized message appears again

---

## 2. Settings Panel

- [ ] `/fu` opens the settings panel
- [ ] `/fu options`, `/fu config`, `/fu settings` each open the panel
- [ ] `/frameunlocker` opens the panel
- [ ] `/fu anythingunrecognized` opens the panel (fallback behavior)
- [ ] Logo, version number, subtitle (`Unlock and customize UI frames`), and `by Ketch` credit are all visible
- [ ] `* Not available in Classic Era` note visible in top right
- [ ] Four sections present: **Chat Frames**, **Group & PvP Frames**, **Misc Frames**, **Slash Commands**
- [ ] **Reset to Defaults** button present in the bottom right

---

## 3. Chat Frames

- [ ] **Unlock chat frame** checkbox is checked by default on a fresh install
- [ ] Drag chat by its tab — frame moves correctly
- [ ] Resize chat from the corner resize button — frame resizes correctly
- [ ] Drag chat near the screen edge — stays clamped, does not go off-screen
- [ ] Uncheck **Unlock chat frame** — tab no longer draggable, resize button hidden
- [ ] Re-check — dragging and resizing work again
- [ ] `/reload` — chat still draggable, position from before reload is preserved

### Edit Mode re-unlock **[Retail]**

- [ ] Open Edit Mode
- [ ] Exit Edit Mode
- [ ] `[FU] Chat re-unlocked after Edit Mode.` appears in chat
- [ ] Chat tab is draggable immediately after

---

## 4. Raid Frames **[Group]**

- [ ] Enable **Raid frames** checkbox — slider becomes active, shows `Scale: 100%`
- [ ] Move slider to 150% — compact raid frames visibly enlarge
- [ ] Move slider to 50% — compact raid frames visibly shrink
- [ ] Disable checkbox — raid frames return to default (100%) scale
- [ ] `/reload` with checkbox enabled — scale value persists

---

## 5. Party Frames **[Group — party, not full raid]**

- [ ] Enable **Party frames** checkbox
- [ ] Slider correctly scales party frames up and down
- [ ] Disable — party frames return to default scale
- [ ] `/reload` — scale persists

---

## 6. Status Bars **[Retail / TBC]**

- [ ] Enable **Status bars** checkbox (asterisked — skip on Classic Era)
- [ ] XP bar, reputation bar, or honor bar visibly scales
- [ ] Slider adjusts scale correctly
- [ ] Disable — bars return to default size
- [ ] `/reload` — scale persists

---

## 7. Loot Roll Frames **[Group Loot]**

- [ ] Enable **Loot rolls** checkbox — **Move** and **Reset** buttons become active
- [ ] Disable checkbox — Move and Reset buttons grey out and are unclickable
- [ ] Re-enable
- [ ] Click **Move** — loot anchor appears
  - [ ] Anchor color is green (brand color, not old colors)
  - [ ] Anchor is approximately the size of one loot roll item
  - [ ] **Scale** and **Lock** buttons present inside anchor
  - [ ] Options panel **Move** button text changed to **Lock**
- [ ] Drag anchor to a new position
- [ ] Click **Lock** inside anchor — anchor hides, `[FU] Loot roll frame position saved.` in chat, options button reverts to **Move**
- [ ] Trigger a group loot roll **[Loot]** — roll frames appear at the new position
- [ ] `/reload` — loot frames still appear at custom position
- [ ] `/fu loot` — toggles anchor (enables Loot rolls if off, shows anchor)
- [ ] Click **Reset** in options — loot frames return to default position, slider resets to 100%, `[FU] Loot frame reset to default.` in chat

---

## 8. Arena / Flag Carrier Frames **[Retail / TBC · Arena or BG with flags]**

- [ ] Enable **Arena / Flags** checkbox (asterisked — skip on Classic Era)
- [ ] **Move** and **Reset** buttons become active
- [ ] Click **Move** — arena anchor appears
  - [ ] Anchor color is green (brand color)
  - [ ] Anchor height approximates 3 stacked enemy frames
  - [ ] **Scale** and **Lock** buttons present
- [ ] Drag anchor to a new position and click **Lock** — position saved
- [ ] Enter an arena or BG with flag carriers — enemy/carrier frames appear at anchor position
- [ ] Scale slider — enemy frames scale visibly
- [ ] `/reload` — position and scale persist
- [ ] `/fu arena` — toggles anchor
- [ ] Click **Reset** — frames return to default TOPRIGHT position, scale resets to 100%

---

## 9. Quest Tracker

- [ ] Enable **Quest tracker** checkbox (have at least one tracked quest active)
- [ ] **Move** and **Reset** buttons become active
- [ ] Click **Move** — quest tracker anchor appears
  - [ ] Anchor color is green (brand color)
  - [ ] Anchor height closely matches the current objective tracker height
  - [ ] Tracker visually overlaps or aligns with the anchor
- [ ] Drag anchor — quest tracker moves in real-time (or within one frame)
- [ ] Click **Lock** — position saved, anchor hides
- [ ] Scale slider — tracker scales correctly
- [ ] Zone change — tracker stays at custom position, no flicker
- [ ] Go through a loading screen — tracker returns to custom position after load
- [ ] `/reload` — position and scale persist, no flicker on login
- [ ] `/fu quest` and `/fu tracker` — both toggle the anchor
- [ ] Disable checkbox — tracker snaps back to Blizzard's managed position (right side)
- [ ] Click **Reset** — tracker returns to default position, scale resets, `[FU] Quest tracker reset to default.` in chat
- [ ] After reset, tracker no longer flickers when entering new zones

---

## 10. Raid Warnings

- [ ] Enable **Raid warnings** checkbox
- [ ] **Move** and **Reset** buttons become active
- [ ] Click **Move** — raid warning anchor appears
  - [ ] Anchor color is green (brand color)
  - [ ] Anchor width matches the RaidWarningFrame container width
- [ ] Drag anchor to a new position and click **Lock**
- [ ] Trigger a raid warning (boss emote, `/script RaidNotice_AddMessage(RaidWarningFrame, "Test warning", 1, 1, 1)`, or real encounter) — warning appears at anchor position
- [ ] `/reload` — position persists
- [ ] `/fu warn` and `/fu warning` — both toggle the anchor
- [ ] Click **Reset** — warnings return to default top-center position, scale resets

---

## 11. Anchor Appearance (all anchors)

Run through each anchor's Move flow and verify:

- [ ] Loot anchor — green background, bright green border
- [ ] Arena anchor — green background, bright green border (was purple/red)
- [ ] Quest tracker anchor — green background, bright green border (was blue/gold)
- [ ] Raid warning anchor — green background, bright green border (was red/orange)
- [ ] All four anchors match each other in color
- [ ] All four anchors: label text readable, Scale and Lock buttons functional

---

## 12. Settings Persistence

Configure a non-default value for every feature, then `/reload`:

- [ ] Chat unlock state matches pre-reload
- [ ] All scale sliders show the same percentage as before reload
- [ ] All custom anchor positions (loot, arena, quest, warnings) are maintained
- [ ] Options panel opens with all checkboxes and sliders correctly reflecting saved values

---

## 13. Reset to Defaults

- [ ] Configure multiple settings (custom scales, positions, toggle off chat unlock)
- [ ] Click **Reset to Defaults** in options panel
  - [ ] Chat unlock checkbox returns to **checked** (default)
  - [ ] All other feature checkboxes return to **unchecked**
  - [ ] All sliders return to 100%
  - [ ] All position resets apply (loot/arena/quest/warnings return to default)
  - [ ] `[FU] Settings reset to defaults.` in chat
- [ ] `/fu reset` slash command — same result
- [ ] `/reload` — default state persists

---

## 14. Slash Command Coverage

- [ ] `/fu` — opens settings
- [ ] `/fu options` — opens settings
- [ ] `/fu config` — opens settings
- [ ] `/fu settings` — opens settings
- [ ] `/frameunlocker` — opens settings
- [ ] `/fu loot` — enables Loot rolls if off, toggles anchor
- [ ] `/fu quest` — enables Quest tracker if off, toggles anchor
- [ ] `/fu tracker` — same as `/fu quest`
- [ ] `/fu arena` — enables Arena if off, toggles anchor
- [ ] `/fu warn` — enables Raid warnings if off, toggles anchor
- [ ] `/fu warning` — same as `/fu warn`
- [ ] `/fu reset` — resets all settings to defaults

---

## 15. Classic Era **[Classic Era client only]**

These verify the bug fixed in the last update (anchors previously errored on Classic Era).

- [ ] Addon loads without errors
- [ ] `[FU] Initialized.` appears in chat
- [ ] Enable **Loot rolls**, click **Move** — loot anchor appears without Lua error
- [ ] Enable **Quest tracker**, click **Move** — quest tracker anchor appears without Lua error
- [ ] Enable **Raid warnings**, click **Move** — raid warning anchor appears without Lua error
- [ ] No `BackdropTemplate` error in any anchor
- [ ] Edit Mode hook does not error (no `EditModeManagerFrame` on Classic)
- [ ] **Arena / Flags** and **Status bars** do nothing visually (frames don't exist) — no errors
- [ ] Party frames scale via legacy `PartyMemberFrame1`–`4` **[Group]**
- [ ] Raid frame scaling works **[Group]**
- [ ] Raid warnings appear at custom position if configured

---

## 16. TBC Anniversary **[TBC client only]**

- [ ] Addon loads without errors
- [ ] All features available (same scope as Retail except Edit Mode)
- [ ] Arena frames scale and reposition in arena **[Arena]**
- [ ] Party frames scale correctly (CompactPartyFrame or legacy)
- [ ] Loot anchor, quest anchor, raid warning anchor all appear without errors
