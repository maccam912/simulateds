# Accessibility and comfort review — November 4, 2026

Disposition of [QA batch 12](https://github.com/maccam912/simulateds/issues/12).
Base: `dab7cbd`, native development checkout, Godot 4.7.2
`ed1daf0bf`, OpenGL Compatibility, Apple M5 Pro, macOS 26.6.2 (25G83).
This is a bounded settings/presentation review, not accessibility certification.

| Finding | Disposition |
| --- | --- |
| ACCESS-01 | Confirmed unnamed settings controls and keyboard entry/scroll issues fixed. Native AX review completed for settings; actual VoiceOver output, full gameplay reading order and announcements remain unverified. Keep the batch open for that audit. |
| ACCESS-02 | Independent larger text/reflow explicitly deferred. Retain the existing 90–125% whole-interface choices; do not describe those as independent text scaling. |
| ACCESS-03 | Implemented: Reduced motion label, visible description, and preserved static dancing pose. Simulation remains authoritative. |
| ACCESS-04 | Split adopted and implemented with migration and independent persisted controls. Native audio-output measurements pass; an actual listening/mix review remains outstanding. |

## Native accessibility exposure

The engine's default Auto accessibility mode can omit controls when an assistive
app is not active. Its [ProjectSettings documentation](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-accessibility-general-accessibility-support)
distinguishes screen readers from accessibility inspectors. Launching this build
with `--accessibility always` exposes the main menu and settings in macOS AX.
The earlier app/window-only automation observation therefore cannot establish
that VoiceOver is unsupported. Keep the production default Auto behavior.

Before this change, volume sliders exposed numeric values without channel names,
and keyboard entry into Audio started at Preview sound, after all sliders.
Settings now starts at its tab bar. Tab enters the first control, arrows adjust
sliders or tabs, and focus scrolls long pages. Back and Restore defaults remain
outside the scrolling content. Sliders expose their channel and percent guidance;
display pickers expose their purpose; rebinding buttons expose action names and
current keys, updating after a successful rebind.

The final native AX inspection observed:

| Surface | Exposed role/name/state |
| --- | --- |
| Main menu | Named buttons including Continue, Settings, Guide & controls and Quit |
| Settings tabs | Tab group with Audio/Display/Comfort/Controls and selected on/off state |
| Audio | Five named sliders; Master changed from 80 to 81 with Right; percent/mute help present |
| Display | Fullscreen and Vertical sync switches; Frame limit: 60 FPS, Scenery detail: High, Interface scale: 100% pickers |
| Comfort | Reduced motion switch changed to on with Tab/Space; adjacent description exposed as text |
| Controls | Action and key together, e.g. Rotate furnishing: R, with Current key help |

This establishes native exposure, not spoken reading order. Keyboard tests cover
tab-bar → first field → subsequent fields and scroll-to-focus; disabled-state
announcements and dynamic notice delivery remain part of the pending audit.

VoiceOver was launched, its Use VoiceOver prompt accepted, and its enabled state
confirmed in System Settings. The automation could not reliably observe its
spoken/caption output or establish that VO-navigation commands moved its reading
cursor. VoiceOver was switched off afterward, restoring the pre-review state.
This attempt is **not a completed VoiceOver audit or a VoiceOver failure**.

Pending real screen-reader checks:

- With VoiceOver already running, launch in default Auto mode. Traverse main,
  pause, settings, the household editor, live HUD, context actions and catalog.
- Record announced names, roles, selected/disabled/checked states and values.
  Verify tabs, popup choices, rebinding conflicts and their recovery messages.
- Verify focus after tray/panel changes, Escape/F1 recovery, and dynamic notices
  without repeated announcements or loss of the currently read item.
- Assess world inspection and complete activities without sight or pointer input.
  A named icon alone does not make the 3D world accessible.
- Repeat on supported exports with their platform assistive technology. Windows,
  Linux and Android accessibility were not tested here.

## Text enlargement decision

Independent larger text is desirable, but is deferred until the catalog/HUD can
reflow. The current compact catalog reserves fixed areas for selected-item
details, edit controls and household feedback; many labels also override theme
font sizes. Raising a global font size would neither enlarge all text nor keep
those controls reachable. Adding 150–200% whole-UI choices would not solve that.

A future implementation should use shared text-size tokens and adapt the catalog
to a single scrolling column with reachable selection details and editing actions.
Validate 1280×720, long resident/item names, keyboard focus reveal and physical
touch before adding the preference. This change improves settings scrolling but
does not claim catalog reflow, low-vision coverage or larger-text support.

## Reduced motion contract

- Menu/tray/console fades are bypassed; camera Find/Center is immediate.
- Accepted resident positions and facing update without movement/turn smoothing.
- Decorative world gestures/strides/dancing, floating cue motion and dressing-room
  idle animation stop. A dancer keeps raised arms instead of becoming an idle pose.
- Activity labels, static poses, selection, routes and progress remain available.
  Needs, commands, reservations, pathfinding, saves and simulation timing do not
  depend on this preference.
- Manual camera pan/zoom/rotation and preview turning remain directly controlled.
  Day/night still follows world time. Audio remains enabled at the chosen volume;
  context crossfades shorten from 1.1 seconds to 0.15 seconds.

## Independent music controls

Background music uses `music_volume`: menu/live/build score routes through the
ducking Score bus to Music and then Master. Household stereos uses `stereo_volume`:
the positional stereo routes through Stereos directly to Master. Effects and
Ambience retain their existing buses. Master zero silences all channels; each
individual zero mutes only its channel. An audible stereo still lowers the score;
muting the stereo releases that ducking. Score mute never cancels the stereo.

An old settings file without `stereo_volume` initializes it from the validated
old combined `music_volume`, including zero. The next ordinary settings save
persists both. Reset restores both to 35%. World saves and dancing orders do not
change. Menus, paused solo time, offscreen speakers and construction retain the
existing rules for stopping household audio.

## Reproducible checks and evidence

All review runs use disposable paths under ignored `build/accessibility-review/`.
Never test replacement or faults against a normal player profile/save.

```sh
python3 tools/check.py
python3 tools/godot.py --script res://tests/accessibility_settings.gd -- \
  --profile-path=build/accessibility-review/settings-profile.json \
  --save-path=build/accessibility-review/settings-world.json
python3 tools/godot.py --script res://tests/dancing_ui.gd -- --compact \
  --profile-path=build/accessibility-review/dance-profile.json \
  --save-path=build/accessibility-review/dance-world.json
python3 tools/godot.py --accessibility always -- --skip-splash \
  --profile-path=build/accessibility-review/ax-profile.json \
  --save-path=build/accessibility-review/ax-world.json
```

`tests/preferences.gd` covers independent levels, legacy mute/level migration and
settings reload. `tests/accessibility_settings.gd` covers focus order, keyboard
volume adjustment, names, binding updates, scrolling and unchanged world state
when toggling motion. It captures settings at 1440×900 and 1280×720 with the UI
preference at 125%, in daylight and night. `tests/dancing_ui.gd` checks the static
pose against unchanged accepted state and records native Master output with
score-only, stereo-only, both-muted and master-muted levels. It also covers
pause/menu/offscreen/construction transitions and repeated snapshots.

Native captures are `build/accessibility-*.png` and
`build/dancing-reduced-motion*.png`; recordings are `build/dancing-*.wav`.
These are reproducible ignored local artifacts, not files present in a fresh clone.
Energy/silence and non-clipping assertions are output measurements, **not an
actual listening test**. A listener still needs to assess balance, transitions,
repetition, voices and positional quality with different channel settings.

Exports, physical Android/touch, other operating systems and human playtest feel
were not tested in this local review. Hosted CI is reported separately in the PR.

Final local aggregate result: `python3 tools/check.py` exited 0 with 122
gameplay/UI suites, two-process save continuity, eight Iroh scenarios and dedicated
server smoke. Native settings and normal/compact dancing checks passed separately.
Staged asset-storage and diff checks passed. The first aggregate attempt hit a
stale commission test save whose local view selected the second resident; that
test passed with a fresh profile, and the complete fresh run passed. Prior test
artifacts were preserved rather than discarded. Logs are under
`build/accessibility-review/`, including `check-fresh.log`.
