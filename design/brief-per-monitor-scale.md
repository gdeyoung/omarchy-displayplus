# Design brief — per-monitor scale on the front page (Display+)

You are the designer agent for **Display+** (`gdeyoung.hyprmoncfg`), an Omarchy
desktop bar plugin (Arch/Hyprland, Quickshell QML). The owner rejected the
current **front-page UNIVERSAL SCALE section**:

> "I plugged in my X-Real Ultra glasses and they came up as a second monitor…
> I couldn't set the Display scale differently for the glasses and if I did it
> changed the laptop. I wanted the laptop to stay on 2 and I wanted to run the
> glasses on like 1.2 or 1.4… our display scale is universal — that needs to be
> fixed."

Follow-up rulings from the owner (same session, verbatim):

> "I'd love more scaling options or steps between that 1.0 and 2.0."
> "Because anything above 2.0 is worthless. 3 and 4 will never be used."
> "Really anything above 2.5 will never be used."

Deliver a concrete, implementable redesign spec for **the front-page scale
section: per-monitor scale controls with fine steps** plus **an optional
"set all displays" secondary affordance** (keep, shrink, or kill it — decide
with rationale).

## The job

Replace the current UNIVERSAL SCALE row (one set of 6 preset pills applied to
EVERY display at once) with per-monitor scale controls: each enabled display
gets its own scale value, settable independently, on the front page ("Display"
tab). Real case: laptop panel 2880x1800 stays at 2x; XREAL glasses 1920x1200
run at 1.2x–1.5x. Per-monitor scale already exists buried in the Layout tab's
inspector — the front page must surface it because mixed-DPI is now an
everyday state for this owner (laptop + glasses, laptop + docked G9).

## Deliverable

Write `~/work/omarchy-display-plus/design/per-monitor-scale-spec.md` (create
`design/`). Spec contents: (1) ASCII layout sketch at ~420px popup width;
(2) element tree in QML terms (Row/Column/Rectangle/Text structure);
(3) EVERY state spelled out — see state list below — each with exact visible
text strings, color roles, and which controls are enabled; (4) typography
scale (which Style.font.* role per element), spacing rhythm in Style.space()
units, corner radii; (5) color decisions: prefer theme tokens
(Commons.Color.accent / .urgent, Style.normalBorderFor / hoverFillFor /
selectedFillFor helpers) — any literal hex must be justified and
theme-degradable; (6) motion notes (QML Behavior/PropertyAnimation only);
(7) a short rationale per major decision citing a named UX principle
(NN/g, Fitts, Gestalt, Hick, WCAG). Max 250 lines. Do NOT edit any other
file in the repo.

## Inputs to study first

- Screenshots (look before writing):
  - `/tmp/panel-tight.png` — the live front page TODAY with two displays
    connected (laptop + headless test output). Note the UNIVERSAL SCALE · 2
    DISPLAYS section and its 6 pills; also note BRIGHTNESS already has a
    per-display picker ("Selected display · Samsung Display Corp. 0x4188") —
    an in-panel precedent for per-display targeting.
  - `~/work/omarchy-display-plus/docs/panel-editor.png` — the Layout tab's
    expanded editor (synthetic mockup, public-safe) where per-monitor scale
    lives today.
- Current code (source repo `~/work/omarchy-display-plus/`, identical to the
  installed clone):
  - `UniversalScaleControl.qml` — the whole file (155 lines): the control
    being replaced. Note `requested(fieldsByKey)` signal contract and the
    6-preset `scalePresets` list.
  - `Panel.qml` lines 2170–2195 — instantiation + `applyUniversalScale`
    handler at ~line 620 (draft pipeline: edit_profile → daemon → 10s
    confirm-revert overlay).
  - `TextSizeControl.qml` — reference pattern for a labeled slider row
    (front-page neighbor).
  - `Model.js` — `formatScale()`, `scaleOptions()` (line ~540) which already
    merges daemon `metadata.scale_options` with the current value.
- Theme system: `/usr/share/omarchy/shell/Commons/Style.qml` and `Color.qml`
  (the ONLY sanctioned design tokens).

## Data contract (verified live against the daemon this session)

- The hyprmoncfg daemon publishes per-output `metadata.scale_options` —
  clean Hyprland scale divisors for that output's CURRENT mode, live. Real
  examples:
  - 2880x1800 (laptop): 1, 1.125, 1.2, 1.25, 1.33333, 1.5, 1.6, 1.66667,
    1.8, 1.875, 2, 2.25, 2.4, 2.5, …
  - 1920x1080 (test output): 1, 1.2, 1.25, 1.33333, 1.5, 1.6, 1.66667,
    1.875, 2, …
  - Owner's glasses are 1920x1200 — its own list arrives live; 1.2 and 1.5
    are exact there; a requested "1.4" snaps to the nearest clean value
    (1.33333 or 1.5) by pixel math. The UI shows clean values only.
- **Filter: options above 2.5 are dropped** (owner ruling). Between 1.0 and
  2.0 that leaves ~9–11 stops per display — too many for today's 6-pill row;
  pick a control that handles 9+ stops in ~380px without a scrollbar
  (slider + readout, stepper, segmented scroll, …your call, justify it).
- Label formatting: `Model.formatScale` yields e.g. "1.33333" — decide the
  display rounding (suggest 2 decimals: "1.33x") and state it in the spec.
- Applying a scale rides the daemon's draft pipeline: 10-second
  confirm-revert overlay guards every apply. The section should surface
  "pending/busy" states (existing `editPending` / `previewBusy` props).

## States to spell out (all of them)

1. Single display connected (the common case — must stay compact, ≈ today).
2. Two displays, same scale (2x + 2x).
3. Two displays, different scales (2x + 1.2x — the owner's exact scenario).
4. Three+ displays (owner docks a G9 too — worst-case width/height).
5. A display whose current scale is NOT in the daemon's option list
   (e.g. set from CLI): the current value must still display, not blank.
6. Draft/preview in flight (a scale change applied, confirm-revert timer
   running) — controls disabled? which rows?
7. A disabled output present in the layout (show it? dimmed? hide?).
8. Daemon reconnecting (`editPending` error state — existing pattern: hint
   text "hyprmoncfg is reconnecting. Try again in a moment.").

## Hard engine constraints (Quickshell 0.3.2, Qt6 Quick, V4 JS)

No ES6 computed object keys, no ES modules in .js, no single-file QML
imports, no Canvas, no external images/icons — glyphs/unicode only; plain
Rectangle/Text/Row/Column/Flow/Behavior. Everything must render correctly
in a dark theme and survive an accent-color theme change (tokens, not
hardcoded accent).

## Known good invariants (must survive)

- BRIGHTNESS (per-display) and TEXT SIZE sections unchanged.
- Tabs Display / Layout / Windows; panel width ~380 logical, fitted height.
- Keyboard navigation works today (j/k/h/l + PanelKeyCatcher patterns);
  new controls must be reachable and must not trap focus.
- Every scale apply goes through the draft pipeline (edit_profile → daemon
  confirm-revert). No direct hyprctl writes from the front page.
- Per-monitor scale remains in the Layout inspector (do not redesign it;
  just stop pretending the front page must defer to it).
- Numbered display badges + Identify overlay exist for display identity —
  reuse, don't reinvent.
- No config/persistence added to the popup: scale values persist via the
  daemon's layout, not via panel settings.

Write the spec file, then reply with a compact summary: the 5 biggest
changes, your color story, and implementation risks.
