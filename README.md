# Display+ for Omarchy

![Display+ — one panel for every display setting](preview.png)

One panel for every display setting. Brightness, text size, and universal
scale sit on the front page — one click from the bar — with hyprmoncfg's full
multi-monitor layout editor underneath.

![Display+ front page](docs/panel-front.png)

Synthetic mockups — no real hardware identifiers. The expanded layout editor and confirm-revert guard:

![Expanded layout editor](docs/panel-editor.png)
![Universal scale, guarded](docs/panel-guard.png)

## The problem

Omarchy ends up with two display panels that overlap. The stock panel gives you
brightness, text size, and scale for the focused display; hyprmoncfg gives you
auto-switching monitor layouts, profiles, and per-display brightness — but its
scale control lives a level or two deep in the layout editor, and it has no
text-size control at all. So both icons sit on the bar, and changing how big
things look means remembering which panel has which knob.

Display+ collapses the two into one pane:

- **Brightness** — per-display, right on the front page (from hyprmoncfg)
- **Text size** — a slider with the stock panel's curated stops (9–20px),
  applied across shell, apps, and terminals together (from the stock panel)
- **Universal scale** — one click sets the same scale on every connected
  display, then rides hyprmoncfg's confirm-revert dialog so a bad choice
  undoes itself in 10 seconds
- **Identify** — every monitor card carries a numbered, color-coded badge
  (leftmost display = 1, matching Windows); the **Identify** button flashes a
  big numbered overlay on each physical screen so you can see which is which.
  Also bindable: `qs -p /usr/share/omarchy/shell ipc call hyprmoncfg identify`
- **Per-monitor scale** stays in the expanded layout editor, where it belongs
- Everything else hyprmoncfg does — auto profiles on hotplug/lid/resume,
  mirroring, rotation, colour management, workspace planning — unchanged

<details>
<summary>See the expanded editor</summary>

![Expanded monitor layout editor](docs/panel-editor.png)

</details>

## Install

**Prerequisite — install the backend first.** Display+ is a front end: the
[hyprmoncfg](https://github.com/crmne/hyprmoncfg) daemon stays the backend and
keeps doing the profile switching. Install it yourself (minimum **1.18.3**),
reviewing what it installs — Display+ never installs or upgrades packages for
you:

```sh
# upstream instructions: https://github.com/crmne/hyprmoncfg#install
omarchy pkg aur add hyprmoncfg-bin
```

Then add the widget:

```sh
omarchy plugin add https://github.com/gdeyoung/omarchy-displayplus.git --enable
```

If you had the stock display panel or upstream hyprmoncfg on your bar, disable
them — Display+ replaces both:

```sh
omarchy plugin disable omarchy.monitor
omarchy plugin disable crmne.hyprmoncfg   # if installed
```

## Remove

```sh
omarchy plugin remove gdeyoung.hyprmoncfg
```

The hyprmoncfg daemon and your saved profiles are untouched; reinstall the
upstream panel (`omarchy plugin add https://github.com/crmne/omarchy-hyprmoncfg.git --enable`)
or re-enable `omarchy.monitor` to get a bar panel back.

## Credits

Fork of [hyprmoncfg for Omarchy](https://github.com/crmne/omarchy-hyprmoncfg)
by Carmine Paolino (MIT), which does all the hard work — Display+ only
reorganizes the front page. Text size uses Omarchy's own
`omarchy-display-text-size` CLI, so it stays consistent with the stock panel.

## Development

```sh
node --test tests/
omarchy plugin validate .
```

Fork additions live in `TextSizeControl.qml` and `UniversalScaleControl.qml`;
everything else is upstream code, so diff against
[crmne/omarchy-hyprmoncfg](https://github.com/crmne/omarchy-hyprmoncfg) to see
exactly what changed.
