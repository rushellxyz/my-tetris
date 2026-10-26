# My Tetris

A Godot 4.6+ falling-block game for **Android phones in portrait orientation**, with simple square graphics, a 10 × 20 board, and gameplay based on NES Tetris. No external Godot plugins are required.

## Run

Import `project.godot` in Godot 4.6 or newer and press **F6** on `scenes/main.tscn`, or **F5** to run the project. From a terminal:

```sh
godot --path .
```

Choose a starting level from 0–19, then tap **PLAY**. Score, level, cleared lines, best score, and one next piece appear beside or above the board. Best score and sound preference are saved locally in `user://settings.cfg`.

## Controls

| Action | Phone | Keyboard |
| --- | --- | --- |
| Move | Hold `<` or `>` | Left / Right, A / D |
| Soft drop | Hold `v` | Down / S |
| Rotate counterclockwise | Tap left rotation button | Z |
| Rotate clockwise | Tap right rotation button | X / Up |
| Hard drop | Tap DROP | Space |
| Pause / resume | Tap II / RESUME; Android Back | P / Escape |
| Start / retry / resume | Tap main button | Enter |
| Toggle sound | Tap SFX | M |

Touch controls support multiple fingers, so movement and rotation can be combined. Switching apps or losing focus pauses the game and releases held controls. While paused, MAIN MENU ends the current run. Closing the app preserves the best score, not the unfinished board.

## Rules

- Seven tetrominoes; one next-piece preview; no hold, ghost, wall kicks, T-spin bonuses, combos, or seven-bag randomizer.
- Line-clear points: **40 / 100 / 300 / 1200 × (level + 1)** for one / two / three / four lines. The level before the clear determines the multiplier.
- The final continuous soft-drop run earns one point per cell when the piece locks. Hard drop is a phone convenience and earns no drop bonus.
- Starting at level 0, advance every 10 lines. Higher starting levels use the classic first-transition rule: `min((start + 1) × 10, max(100, start × 10 − 50))`, then every 10 lines. For example, starting at 18 reaches 19 at 130 lines.
- Gravity uses the NTSC frame table at 60 simulated frames/second: 48 frames/cell at level 0, 6 at level 9, 2 at level 19, and 1 at level 29+. A blocked downward step locks immediately.
- Horizontal movement repeats after 16 frames, then every 6 frames. Soft drop moves one cell on press, then repeats every 0.12 seconds while held, never slower than gravity. Pressing it starts a fresh timer, preventing accumulated gravity time from causing a sudden multi-row drop.
- Randomization rerolls once on an immediate repeat or dummy eighth value. Piece droughts are possible.
- Ten palettes cycle by level, recoloring both the stack and new pieces.
- A blocked spawn ends the run.

This is NES-inspired rather than a cycle-exact emulator: it adds touch controls and hard drop, uses fixed 0.18-second entry / 0.45-second line-clear delays, and omits original hardware timing quirks and score/level overflow bugs. Reference: [NES gameplay rules and gravity](https://tetris.wiki/Tetris_(NES,_Nintendo)).

## Android export

The included **Android** preset uses ARM64, the Compatibility renderer, immersive display, and a locked portrait orientation. The UI fits inside the phone's display safe area. It does not request internet or vibration permissions.

1. Install the Godot export templates matching your editor version.
2. Install a Java JDK and Android SDK and configure **Editor Settings → Export → Android → Java SDK Path / Android SDK Path**, following [Godot's Android export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html).
3. In **Project → Export → Android**, export a debug APK to `builds/my-tetris.apk`. Create the `builds` directory if needed. The current package ID is `com.example.mytetris`; change it before distributing your own app.

With those local SDK settings configured:

```sh
mkdir -p builds
godot --headless --path . --export-debug Android builds/my-tetris.apk
```

For a release, configure your own signing keystore in Godot. Keep signing keys outside version control. Google Play distribution requires an Android App Bundle and the corresponding Gradle export setup; the supplied preset targets sideloadable APKs.

Validation in this workspace: Godot 4.6.2 imported and ran the project; 2,092 rules checks and the touch UI checks passed, and desktop OpenGL rendering was inspected. A signed debug APK was successfully exported to `builds/my-tetris.apk` for ARM64 phones running Android 7.0 (API 24) or newer. APK signature, portrait orientation, packaged audio, and bundled attribution files were verified. ~~No physical-phone run has been performed.~~ Runs on my Redmi note 15, tho installing APK gets more painful every time i need

Local build tools: Java SDK `/usr/lib/jvm/java-21-openjdk`, Android SDK `/home/rushell/Android/Sdk`, Build Tools 35.0.1, Android platform 35. These paths are configured in Godot editor settings on this machine; other machines need their own SDK paths.

## Audio attribution and license

**Sci-Fi UI SFX** by **Paolo Migliorisi – Urizen Composer**.

**Original source (required credit): [https://opengameart.org/content/sci-fi-ui-sfx](https://opengameart.org/content/sci-fi-ui-sfx)**

Licensed under **[OpenGameArt Attribution 4.0 (OGA-BY 4.0)](https://opengameart.org/sites/default/files/archive/oga-by-40.txt)**. The project's audio folder contains supplied files from that pack, including files renamed to describe their gameplay events. This implementation uses those WAV files as supplied without additional audio processing. Preserve this attribution and source link when redistributing the audio or this game. The complete license is included in `licenses/OGA-BY-4.0.txt`. The title screen also displays the audio credit and source. See also `THIRD_PARTY_NOTICES.md`.

The named files are connected to hard drop, single/double/triple/Tetris line clears, game over, and a new high score. Unlabeled pack files are retained but are not assigned invented gameplay meanings.

## Verification and source layout

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/test_game.gd
godot --headless --path . --script tests/test_ui.gd
```

The rules test covers rotations, boundaries, pause, all four clear counts, scoring, level transitions, gravity, top-out, restart, and 2,000 simulated placements. UI checks cover starting-level selection, multitouch, input release, pause/resume, focus loss, and portrait sizes. Running the UI test with a graphical display also saves screenshots into `builds/` (create that directory first).

- `scripts/tetris_game.gd`: rules and board state, independent of rendering.
- `scripts/main.gd`: drawing, touch/keyboard input, audio, and local persistence.
- `scenes/main.tscn`: main scene.
- `export_presets.cfg`: Android APK preset.
