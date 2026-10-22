# Per-monitor scale — front-page spec (Display+ / `gdeyoung.hyprmoncfg`)

Replaces `UniversalScaleControl.qml` (155 lines) with `PerMonitorScaleControl.qml`.
Only other code touch: the instantiation block in `Panel.qml` ~2180–2192 (type swap +
one new binding). `applyUniversalScale()` / `drainUniversalScaleQueue()` (Panel.qml
~646–672) are reused unchanged — `fieldsByKey` already serializes multi-output edits.

## 0. Decisions at a glance

- One slider row per display. Header renames `UNIVERSAL SCALE` → `SCALE`.
- Control = `PanelSlider` indexing that display's clean-divisor stops — the same
  grammar as the TEXT SIZE row directly above. Pills cannot return: 9–11 post-filter
  stops don't fit ~380px (Hick's Law — unpickable choice density).
- Options: `Model.scaleOptions(editorDisplays, key, output.scale)`, then drop stops
  > 2.5 (owner ruling), but always keep the output's current value even if > 2.5.
- Readout rounding: 2 decimals, trailing zeros trimmed — `1x`, `1.2x`, `1.33x`
  (same rounding as `Model.displayDetailLabel`). Applies send the exact stop string.
- "Set all displays" is SHRUNK to: right-click any row's slider = apply that row's
  scale to every enabled display, taught by the caption line. No preset pill row.
- Apply fires on slider RELEASE only (never per stop crossed); keyboard steps
  debounce 600 ms. Every apply rides the existing edit_profile → confirm-revert path.

## 1. ASCII layout (popup ~420px, content ~380px; two-display owner scenario)

```
┌────────────────────────────────────────────────────────────────┐
│ SCALE · 2 DISPLAYS                                   Mixed      │  header line
│ Per display · right-click a slider to set every display        │  caption (dim)
│                                                                │
│ ╭────────────────────────────────────────────────────────────╮ │  row 1 surface
│ │ ① eDP-1   ●━━━━━━━━━━━━━━━━┼━━━━━━━━━━━━━━━━━━━━━━   2x   │ │  (outline)
│ ╰────────────────────────────────────────────────────────────╯ │
│ ╭────────────────────────────────────────────────────────────╮ │  row 2 surface
│ │ ② DP-1    ●━┼──┼──┼──┼──┼──┼──┼──┼──┼──┼─────────────  1.2x │ │  ticks = stops
│ ╰────────────────────────────────────────────────────────────╯ │
└────────────────────────────────────────────────────────────────┘
  ①② = rank badges (Model.displayColor) · names fixed-width · values right-aligned
```

Row anatomy, left→right: badge (18px) · connector name (fixed width, elides) ·
slider (fills remaining ~230px, notches mark every stop) · value (fixed, right).

## 2. Element tree (QML terms)

```
PerMonitorScaleControl.qml — Column { id: root; spacing: Style.space(5)
  props: bar, profile, editorDisplays ([]), foreground, dim (= Qt.darker(foreground,1.5)),
         accent, fontFamily, editPending, previewBusy
  signal: requested(var fieldsByKey)            // CONTRACT UNCHANGED from today

  ├─ Item (header line, height: max(title, value))
  │   ├─ PanelSectionHeader { id: scaleTitle; anchors.left…right: scaleValue.left
  │   │     text: "SCALE · " + n + (n === 1 ? " DISPLAY" : " DISPLAYS") }
  │   └─ Text { id: scaleValue; anchors.right; font.caption, bold, color: dim
  │         text: busy ? "…" : (uniform ? fmt(shared) : "Mixed") }
  ├─ Text { id: scaleHint; caption, dim; elide; // strings in §4/§5; urgent in state 8 }
  └─ Column { spacing: Style.space(3)
      └─ Repeater { model: root.rows()          // outputs, enabled-first, then off
          └─ CursorSurface { id: rowSurface; width: parent.width; outline: true
              height: Math.max(rowSlider.implicitHeight + Style.spacing.controlGap,
                               Style.space(36))
              opacity: modelData.off ? 0.45 : (busy ? 0.5 : 1.0)
              enabled: !modelData.off && !busy
              Row { spacing: Style.space(4); anchors.verticalCenter: parent
                ├─ Rectangle (badge) 18×18, radius: Math.min(Style.cornerRadius, 9)
                │   color: Model.displayColor(display)
                │   └─ Text { number; color: Color.background; font.caption, bold }
                ├─ Text (rowName) width: Style.space(11); caption; elide middle
                │   text: connector + (off ? " · off" : "")
                ├─ PanelSlider { id: rowSlider; width: parent.width − badgeW − nameW
                │     − valueW − 3×Style.space(4); bar: root.bar
                │     minimum: 0; maximum: stops.length − 1; step: 1; integer: true
                │     value: stopIndex(current); tickCount: stops.length
                │     onMoved: showPending(fmt(stops[round(v)]))   // readout only
                │     onReleased: root.requested({ key: {scale: parseFloat(stop)} })
                │     onRightClicked: root.requested(allFieldsAtScale(stop)) }
                └─ Text (rowValue) width: Style.space(7); caption, bold; right-aligned
                    color: pending !== "" ? root.accent : root.dim } } }
      // Fallback row (state 5b): same CursorSurface, slider replaced by
      // Text { "No clean scale steps for this mode"; caption; dim } + rowValue }
```

No Layouts, no Canvas, no images — Rectangle/Text/Row/Column/Repeater only.
`stops = Model.scaleOptions(editorDisplays, key, output.scale)` filtered `≤ 2.5`,
then current value re-appended if missing (order: merge → filter → re-append current).

## 3. Typography, spacing, radii

- Header: `PanelSectionHeader` (its own caption-size, letter-spaced role).
- Caption, row name, badge, value: `Style.font.caption`; value + badge bold.
- Root spacing `Style.space(5)` (identical to BRIGHTNESS/TEXT SIZE); rows
  `Style.space(3)`; intra-row gaps `Style.space(4)`; slider track inset none extra.
- Surfaces: `CursorSurface` outline (radius from Style.cornerRadius); badge radius
  `Math.min(Style.cornerRadius, 9)`; slider track/knob radii owned by PanelSlider.
- Heights: row surface `max(slider.implicitHeight + controlGap, space(36))` — the
  exact formula TEXT SIZE uses. Section height ≈ 84px (1 display), 124px (2), 164px
  (3), +40px per extra row; uncapped beyond 5 rows (panel is fitted-height).

## 4. Color system (zero new hex literals)

- All chrome via existing token paths: `CursorSurface(outline)` and `PanelSlider`
  already resolve `Style.normalBorderFor/hoverFillFor/selectedFillFor` and
  `bar.foreground`; header via `PanelSectionHeader(foreground)`.
- Dim text (`scaleHint`, names, values): `Qt.darker(foreground, 1.5)` — the exact
  convention of the three neighboring controls; on the default theme that is
  ≈8:1 against `Color.background` (WCAG 1.4.3 AA passes with margin).
- `Color.accent`: pending readout while dragging/stepping only (transient state).
- `Color.urgent`: the reconnect hint (state 8) — error semantics only.
- Badges: `Model.displayColor(display)` + number in `Color.background` — the same
  color that flashes on the physical screen from Identify (reuse, don't reinvent).
- Busy/off dimming via `opacity` on token-colored content, never grey hex.

## 5. States (every one, with exact strings / colors / enabled)

1. **Single display.** Header `SCALE · 1 DISPLAY`; right value `2x`; caption
   `Clean scale steps for this display's current mode`; one row `① eDP-1 … 2x`,
   enabled. Compact: header + caption + one 36px surface ≈ today's height.
2. **Two displays, same scale (2x + 2x).** Header `SCALE · 2 DISPLAYS`; right value
   `2x` (uniform); caption `Per display · right-click a slider to set every
   display`; rows `① eDP-1 … 2x`, `② DP-1 … 2x`; both knobs identical position.
3. **Two displays, different (2x + 1.2x — owner's glasses case).** Right value
   `Mixed` (dim, bold); rows read `2x` / `1.2x`; knobs at different stops; all
   enabled. This is the state the redesign exists for.
4. **Three+ displays (laptop + G9 + glasses).** Header `SCALE · 3 DISPLAYS`, value
   `Mixed`; rows stack, fixed 380px width, +40px each; sliders shrink never (name
   and value columns are fixed; only the track absorbs width). Worst realistic
   height ~204px section; panel grows (fitted height) beyond that.
5. **Current scale not in the daemon list (set from CLI, e.g. 1.4).** `scaleOptions`
   already merges `current` (Model.js ~548), so the row shows `1.4x` with the knob
   parked on the merged stop — never blank. If the daemon later normalizes it
   (1.4 → 1.33), the readout follows the round-tripped value on next editor_state.
   5b. **No mode metadata at all** (empty `scale_options`): slider replaced by dim
   `No clean scale steps for this mode`; value readout still shows current scale.
6. **Draft/preview in flight** (`editPending` or `previewBusy`). ALL rows disabled
   (`enabled: false`), section `opacity: 0.5`; knobs freeze at committed values;
   header value `…`; dragging is refused. Rationale: edits serialize through one
   edit_profile queue — per-row enabling would invite dropped edits (NN/g error
   prevention). The daemon's 10s confirm-revert overlay is the outer guard.
7. **Disabled output present in layout.** Shown, not hidden: row at `opacity: 0.45`,
   name suffixed `HDMI-A-1 · off`, slider `enabled: false`, value still displayed.
   Keeps the persisted scale visible for when it's re-enabled (NN/g visibility of
   system status). Reordering: enabled rows first, off rows last.
8. **Daemon reconnecting (`editPending` error).** Caption line swaps to
   `hyprmoncfg is reconnecting. Try again in a moment.` in `Color.urgent`; all rows
   disabled at full opacity (values stay readable); recovers on next editor_state.

## 6. Interaction & apply semantics

- Mouse: press/drag scrubs the readout live (pending value in `Color.accent`);
  release commits — ONE `requested({ key: { scale } })` per gesture. Live per-stop
  applying (TEXT SIZE style) is deliberately rejected: each scale apply is a draft
  pipeline round-trip + confirm overlay (NN/g error prevention; spam guard).
- Right-click anywhere on a row's slider: `requested` with every enabled output
  key set to that row's scale → existing queue drains → ONE `applyDraft()` → ONE
  confirm-revert overlay. Caption teaches it (NN/g recognition over recall).
- Wheel on slider: steps one stop, debounced like keyboard.
- Keyboard: rows join the panel cursor chain exactly as the BRIGHTNESS / TEXT SIZE
  surfaces do (CursorSurface + hasCursor; no Qt activeFocus — nothing traps focus).
  Cursor on a row: `h`/`l` step ±1 stop (readout updates instantly), apply after a
  600ms `Timer` debounce; moving the cursor off the row flushes immediately.
  `j`/`k` always leave the row. Rationale: instant applies per keypress would be
  dropped by the `editPending` guard in `applyUniversalScale`.
- Uniform header value recomputes from `profile.outputs` only (source of truth);
  `Mixed` when enabled outputs' scales differ at all.

## 7. Motion (QML Behavior/PropertyAnimation only)

- Reuse PanelSlider built-ins: fill/knob 140ms `OutCubic`, knob hover scale 110ms
  (both auto-disabled while dragging). No new slider animation.
- One addition: `Behavior on opacity { NumberAnimation { duration: 150;
  easing.type: Easing.OutCubic } }` on each row surface for busy/off transitions.
- Pending-value color swap is instant (state feedback should be immediate).

## 8. Panel.qml integration (the only other edit)

```
PerMonitorScaleControl {            // was UniversalScaleControl
  visible: root.compactTab === "display"
  width: parent.width; bar: root.bar
  profile: root.draftProfile
  editorDisplays: root.editorDocument.displays || []   // NEW binding
  foreground/dim/accent/fontFamily/editPending/previewBusy: as today
  onRequested: function(fieldsByKey) { root.applyUniversalScale(fieldsByKey) }  // unchanged
}
```
`draftProfile` and `editorDocument.displays` arrive in the same `editor_state`
message (Panel.qml ~582 `updateEditor`), so the section is never half-fed; before
`editorReady`, render header + dim `…` skeleton. Delete `UniversalScaleControl.qml`.
No Model.js changes needed; the ≤2.5 filter lives in the new control (plain V4 JS:
no arrow functions, no computed keys, no ES modules).

## 9. Rationale index (major decision → principle)

- Per-row stop-indexed sliders over pills: Hick's Law (9–11 choices can't be
  parallel buttons in 380px) + Fitts's Law (whole track is the target) + NN/g
  consistency (third analog slider under BRIGHTNESS/TEXT SIZE — one grammar).
- Header summary `2x` / `Mixed`: NN/g visibility of system status at a glance.
- Right-click-to-unify instead of a preset row: Hick's Law (one secondary gesture
  vs six always-present pills) + NN/g recognition over recall (caption teaches it).
- Release-only applies + debounce: NN/g error prevention (draft pipeline cost,
  serialized edits) + visibility of system status (accent pending readout).
- Off rows dimmed, not hidden: NN/g visibility of system status.
- Fixed name/value columns and shared row edges: Gestalt common region + alignment
  (rows read as one family; sliders optically share a range).
- Badge reuse from DisplayCanvas/Identify: Gestalt figure-ground consistency — the
  number on screen IS the number in the row.
- 2.5 ceiling: owner ruling; also Hick (fewer no-op stops).

## 10. Invariants kept (checklist for the implementer)

- BRIGHTNESS and TEXT SIZE sections untouched; tabs Display/Layout/Windows; ~380px
  width; fitted height. Per-monitor scale stays in the Layout inspector untouched.
- Every apply → `edit_profile` → daemon confirm-revert; no hyprctl from the front
  page; no new persistence or panel settings.
- Keyboard nav reaches every row, never traps focus; renders in any dark theme and
  survives accent changes (no accent hex anywhere).

## 11. Implementation risks

- Stop density: 11 stops over ~230px track ≈ 21px/stop; integer snapping + notches
  mitigate, but a 2.5-capped glasses list (few stops) vs laptop list differ in tick
  spacing — test knob alignment visually on both.
- `editorDisplays` plumbing: front page previously consumed `profile` only; if
  `editorDocument` is ever stale vs `draftProfile`, rows show stale options (both
  update in one message today — keep it that way).
- Rebuild churn: `Repeater model` re-evaluates on every `editor_state`; keep
  `rows()` cheap and value-driven (string keys) to avoid knob flicker.
- Daemon normalization vs displayed value (state 5): after a CLI-set 1.4 is edited,
  the readout will jump to the snapped value — expected, but note in release notes.
- `PanelSlider.rightClicked` is currently consumed by convention for "secondary
  action"; confirm no panel-level right-click handler swallows it first.
