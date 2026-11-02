# Mine Sweeper

A minimal, touch-friendly minesweeper game built with **Godot 4.7** for mobile devices. Features three distinct board geometries — **square**, **triangular**, and **hexagonal** — each with its own neighbor topology and visual style.

## Table of Contents

- [Game Overview](#game-overview)
- [How to Play](#how-to-play)
- [Setup Flow](#setup-flow)
- [Gameplay Flow](#gameplay-flow)
- [Architecture](#architecture)
  - [Project Structure](#project-structure)
  - [Scene Tree](#scene-tree)
  - [Board System](#board-system)
  - [Board Topology: Wrap vs. Classic](#board-topology-wrap-vs-classic)
  - [Cell State](#cell-state)
  - [Global State](#global-state)
  - [Settings & Persistence](#settings--persistence)
  - [Camera](#camera)
  - [UI](#ui)
- [Design Decisions](#design-decisions)
- [Testing](#testing)

---

## Game Overview

Classic minesweeper rules on non-standard grids:

- **Square board** — 8 neighbors per cell (Chebyshev adjacency)
- **Triangle board** — 12 neighbors per cell (edge + vertex sharing)
- **Hexagonal board** — 6 neighbors per cell (offset coordinates)

Board dimensions and mine density are configurable from the main menu (rows, columns, bomb percentage), so any geometry can be tuned from tiny to large. The game is designed for portrait-mode mobile with touch input, but also supports mouse and scroll wheel on desktop.

## How to Play

1. **Tap** a cell to reveal it
2. **Toggle the flag button**, then tap cells to flag/unflag suspected mines
3. Revealing a cell with **0 adjacent mines** triggers a flood-fill that auto-reveals all connected safe cells in a wave animation
4. Revealing a **mine** ends the game — all remaining mines are shown in a ripple from the explosion point
5. **Win** by revealing every non-mine cell

The first tap is always safe: mines are placed *after* the first click, excluding the tapped cell and its neighbors within distance 2. On boards too small or dense for that, the safe zone shrinks (distance 1, then just the tapped cell) so every requested mine still fits — the mine counter and win condition always reflect the mines actually placed.

The **seed** (0 = random) only seeds the mine-placement RNG: the same seed, board type, size, mine count and first tap give the same layout.

---

## Setup Flow

```
┌────────────────────────────────────┐
│     MainMenu (standalone scene)    │
│                                    │
│  ◄ Square ►   (board type)         │
│  Rows: 18    Cols: 18              │
│  Bomb %: 15    Seed: 0              │
│  ◄ Wrap   ►   (topology mode)      │
│  [ ] No Border                     │
│                                    │
│          [ PLAY ]                  │
│          [ SETTINGS ]  ───┐        │
│          [ QUIT ]         │        │
└────────────────────────────────────┘
       │ Play                │ Settings
       ▼                     ▼
┌───────────────────────┐  ┌────────────────────┐
│ Board loads            │  │ SettingsMenu        │
│ board scene            │  │ (pushed over        │
│ instantiated, cells    │  │  MainMenu, which    │
│ created, no mines      │  │  is hidden — not    │
│ placed yet             │  │  destroyed)         │
└───────────────────────┘  └────────────────────┘
```

1. **MainMenu** (`Scenes/Menu/MainMenu.tscn`, `main_menu.gd`) is a standalone scene shown through `ScreenManager`, not embedded in `base.tscn`. It owns board type, rows/columns, bomb percentage, seed, wrap/classic, and no-border selection, writing directly to `GlobalState` as the player changes options.
2. Player taps **Play** → `main_menu.gd` emits `start_requested` → `base.gd._load_game()` runs:
   - Looks up the board scene from a dictionary (`{0: triangle, 1: square, 2: hexagon}`)
   - Instantiates and adds to scene tree
   - Reads `board_rows`, `board_cols`, and `get_mine_count()` from `GlobalState`
   - Resets defuse mode and button state
   - Calls `board.start_game(cols, rows, mines, GlobalState.board_wrap)` → builds the tile block (see [Board Topology](#board-topology-wrap-vs-classic))
   - Configures the camera: unconstrained + centered in wrap mode, bounds-clamped in classic mode
3. Board is visible but **no mines exist** — the grid is blank, waiting for the first tap
4. Player taps **Settings** (from MainMenu or the in-game Pause overlay) → `ScreenManager.push()` shows `SettingsMenu` on top; the screen underneath is hidden (not freed) and restored on back — see [UI](#ui)


---

## Gameplay Flow

```
First tap
   │
   ▼
_first_move(cell)
   ├── _place_mines(cell)     Fisher-Yates shuffle, O(n)
   │     └── mark_as_mine() / increment_nearby() on affected cells
   └── on_game_started.emit() → UI shows mine counter
   │
   ▼
_on_cell_pressed(cell, nearby)
   │
   ├── [defuse mode ON] → cell.defuse()
   │     State: Unknown ↔ Defused (toggle)
   │     Emits cell_defused → updates counter
   │
   └── [defuse mode OFF] → cell.explore()
         State: Unknown → Explored
         │
         ├── [nearby == -1] → MINE
         │     Emits cell_exploded
         │     → _handle_explosion()
         │       ├─ _is_game_over = true
         │       ├─ on_game_finished(false)
         │       ├─ _reveal_mines_from(cell)  ← tween wave animation
         │       └─ haptic feedback
         │
         ├── [nearby == 0] → EMPTY
         │     Emits cell_explored (+1 explored count)
         │     → _explore_nearby(cell)
         │       BFS flood fill, sorted by distance
         │       Single tween reveals all in wave
         │
         └── [nearby > 0] → NUMBER
               Emits cell_explored (+1 explored count)
               Shows digit on cell
               │
               ▼
         if _explored == _to_be_explored → WIN
               on_game_finished(true)

Game end → Final screen ("Good job!" / "Oh no!")
        → "Back to Menu" frees the board, returns to main menu
```

---

## Architecture

### Project Structure

```
mine-sweeper/
├── Scenes/
│   ├── base.tscn                    Gameplay root scene (camera + GUI + ScreenManager)
│   ├── board_gui.tscn               In-game HUD (score, reset, defuse, pause)
│   ├── Board/
│   │   ├── square_board.tscn
│   │   ├── triangle_board.tscn
│   │   └── hexagon_board.tscn
│   ├── Cells/
│   │   ├── square_cell.tscn
│   │   ├── up_triangle_cell.tscn
│   │   ├── down_triangle_cell.tscn
│   │   ├── hexagonal_cell.tscn
│   │   └── hexagonal_cell_variant.tscn
│   ├── Menu/
│   │   ├── MainMenu.tscn             Standalone main menu
│   │   ├── SettingsMenu.tscn         Standalone settings screen
│   │   └── PauseOverlay.tscn         In-game pause overlay
│   └── Tests/
│       └── test_*.tscn              One scene per test suite
├── Scripts/
│   ├── base.gd                      Main game controller
│   ├── global_state.gd              Autoload singleton (GlobalState) — game config
│   ├── Settings.gd                  Autoload singleton (Settings) — persisted user prefs
│   ├── Board/
│   │   ├── base_board.gd            Abstract board (game logic + tile block)
│   │   ├── board_copy_renderer.gd   Draws the wrap-mode copies (no node per copied cell)
│   │   ├── square_board.gd          Square grid + Chebyshev neighbors
│   │   ├── hexagon_board.gd         Hex grid + offset-coord neighbors
│   │   └── triangle_board.gd        Triangle grid + edge neighbors
│   ├── Gameplay/
│   │   └── cell.gd                  Cell base class (CellBase)
│   ├── GUI/
│   │   ├── board_gui.gd             Score tracker + reset + pause button
│   │   ├── camera_controller.gd     Pan/zoom, optional bounds clamping
│   │   ├── screen_manager.gd        Screen push/pop stack with transitions
│   │   ├── main_menu.gd             MainMenu logic (selection state + signals)
│   │   ├── settings_menu.gd         SettingsMenu logic (bound to Settings)
│   │   └── pause_overlay.gd         Pause overlay logic
│   └── Tests/
│       ├── test_case.gd             Minimal test-case base class
│       ├── test_*.gd                One file per suite (see Testing)
│       └── run_tests.sh             Aggregate test runner (shell script)
└── Asset/
    ├── Icons/                        SVG icons (mine, flag, arrows, etc.)
    └── Font/                         Custom font (Anton)
```

### Scene Tree

The main gameplay scene (`base.tscn`) is always loaded:

```
Base (Node)                          ← base.gd — game controller
├── Camera (Camera2D)                ← camera_controller.gd
├── ScreenManager (Control)          ← screen_manager.gd — screen stack logic
└── GUI (CanvasLayer)                ← screen space, unaffected by the camera
    ├── Screen (MarginContainer)     ← safe area margins
    │   ├── MainMenu                  ← instance of Scenes/Menu/MainMenu.tscn
    │   ├── BoardGUI                  ← hidden until game starts
    │   │   ├── DefuseButton
    │   │   ├── PauseButton
    │   │   └── ScoreTracker
    │   └── FinalScreen               ← hidden until game ends
    │       └── BackToMenu
    └── ScreensContainer (Control)    ← %ScreensContainer: MainMenu, Settings and
                                         Pause are shown here, on top of the HUD.
                                         mouse_filter = IGNORE; each screen blocks
                                         input with its own background.
```

Board scenes are instantiated *dynamically* as children of Base when a game starts, and freed on reset. `MainMenu` participates in the `ScreenManager` stack (see [UI](#ui)) even though it lives inline in `base.tscn` — `ScreenManager.show_main_menu()` treats it as the base of the navigation stack.

### Board System

```
BaseBoard (abstract)
├── SquareBoard
├── HexagonBoard
└── TriangleBoard
```

**BaseBoard** (`base_board.gd`) owns all game logic and the tile block (see [Board Topology](#board-topology-wrap-vs-classic) for wrap/classic details):
- Mine placement via Fisher-Yates shuffle — O(n) guaranteed, no retry loops
- BFS flood fill for empty cell expansion — O(n) with visited set
- Tween-based wave animations (overlapping waves allowed; all are stopped on game over / clear)
- Win/lose detection, signal emissions
- `_get_nearby_cells(cell, distance)` — abstract, returns `Dictionary` used as a Set
- `_build_tiles()` — builds the interactive tile, plus (wrap mode only) a `BoardCopyRenderer` that draws the 8 surrounding copies
- `recenter_if_needed(camera_offset)` — called every frame in wrap mode only

**Subclasses** only define:
- `_get_cell_type_idx(col, row)` — which cell scene variant to use at a global coordinate (hex/triangle alternate patterns)
- `_get_nearby_cells()` — topology-specific neighbor lookup, wrap-aware via `_wrap_mode`

| Board | Neighbor strategy | Distance > 1 |
|-------|------------------|---------------|
| Square | Chebyshev box (direct iteration) | Expands box range |
| Hexagon | BFS ring expansion with offset-coord neighbor table | Iterative rings |
| Triangle | BFS ring expansion with edge-adjacency (12 total with vertex-sharing) | Iterative rings |

### Board Topology: Wrap vs. Classic

The board supports two topology modes, selectable from the MainMenu or Settings and stored in `GlobalState.board_wrap` / `Settings.board_wrap`:

| | **Wrap** (default) | **Classic** |
|---|---|---|
| Tile block | 3×3 block — 1 interactive center tile + 8 drawn copies | Single tile, no copies |
| Scrolling | Infinite — camera recenters by exactly one board size when it drifts past 50% of a board dimension from center | Bounded — camera clamped to the board's rect via `CameraController.set_board_bounds()` |
| Neighbor lookup | Toroidal — coordinates wrap with `posmod()` | Hard edges — out-of-bounds neighbors are skipped |
| Board size | Rounded up to a valid wrap size (see below) | As chosen |
| Feel | Left edge connects to right edge, top to bottom (like Pac-Man) | Traditional bounded Minesweeper board |

**Why wrap mode needs even dimensions on hex/triangle boards:** hexagon neighbor offsets depend on row parity, and triangle orientation (up/down) on `(col + row)` parity. If the seam joins two rows/columns of the same parity, the neighbor relation becomes asymmetric there (a mine counts toward a cell that doesn't consider the mine its neighbor). `BaseBoard.start_game()` therefore rounds the size up via `_get_wrap_dimension_multiple()` — hexagon: even rows; triangle: even rows and columns — scaling the mine count to keep the requested density.

**How the copies are drawn:** only the center tile has real cell nodes. The 8 copies are drawn by `BoardCopyRenderer` (`Scripts/Board/board_copy_renderer.gd`): each copy is split into 8×8-cell chunks, and each chunk is a single `Node2D` whose `_draw()` paints its cells straight from the logical cells' current fill color, text and icon. A cell change (`_sync_display_to_copies()` on explore/defuse/highlight) only queues a redraw of that cell's chunk in each copy. Taps on copies are mapped back to logical cells mathematically (`_find_display_logical_cell()`), so the copies need no nodes for input either.

**Why snapping by exactly one board size is invisible:** the copies are pixel-identical to the center tile — including Control pixel snapping of the cells' labels and icons, which the renderer replicates (`_snap()`). Shifting the tile block by a full board dimension lands the camera on an identical-looking tile, so the recenter jump is imperceptible. (Checked by screenshotting a windowed run and diffing the center tile against a copy: 0 differing pixels for all three shapes. The old node-based copies drew numbers top-left instead of centered, differing on ~7.5% of pixels.)

### Cell State

Each cell scene contains:
- `Area2D` with `Polygon2D` (shape), `Label` (number), `TextureRect` (icon)
- A `CellState` enum tracking `UNKNOWN`, `DEFUSED`, or `EXPLORED`

```
CellBase
└── visual nodes (Area2D / Polygon2D / Label / TextureRect)
└── CellState enum
```

State transitions are handled directly by `CellBase.defuse()` and `CellBase.explore()`. Both methods update the enum and call `set_display()` to refresh visuals, keeping visual state in one place.

Cell exposes explicit methods instead of magic setters:
- `mark_as_mine()` — permanently marks as mine
- `increment_nearby()` — adds 1 to neighbor count (no-op if mine)
- `is_mine()`, `is_explored()`, `is_defused()` — state queries
- `set_display(bg, content, icon, text)` — visual update API for states

### Global State

`GlobalState` autoload singleton holds:
- **Game config**: board type, rows, columns, bomb percentage, and seed
- **Topology**: `board_wrap` — mirrors `Settings.board_wrap`, read by `base.gd` when starting a game
- **UI state**: `is_defusing` flag, `no_border` flag
- **Color schemes**: data-driven dictionary, active scheme selected by key, colors exposed via getter properties

`GlobalState` holds *transient/session* game config; `Settings` (below) holds *persisted* user preferences. `board_wrap` and `no_border` currently exist as plain fields on `GlobalState` for quick access during a session — `Settings.board_wrap` is the durable copy read back on next launch.

### Settings & Persistence

`Settings` autoload singleton (`Scripts/Settings.gd`) is a `ConfigFile`-backed store for user preferences, saved to `user://settings.cfg`:

| Property | Type | Notes |
|---|---|---|
| `master_volume`, `music_volume`, `sfx_volume` | `float` (0.0–1.0) | Clamped in the setter; `master_volume` applies live to the `AudioServer` "Master" bus |
| `vibration_enabled` | `bool` | Gates haptic feedback on cell taps and explosions |
| `graphics_quality` | `String` | `"low"` / `"medium"` / `"high"` — sets the root viewport's 2D MSAA (off / 2× / 4×) and vertex pixel snapping |
| `fullscreen` | `bool` | Applies immediately via `DisplayServer.window_set_mode()` |
| `board_wrap` | `bool` | Wrap vs. classic board topology, default `true` |
| `nickname`, `language` | `String` | Reserved for future use |

Every property is a Godot property with a custom `set()` that calls `_persist(key, value)`, which writes to the `ConfigFile`, saves to disk, and emits `setting_changed(key, value)`. `SettingsMenu` reads/writes these properties directly — there is no separate view-model layer.

**Naming note:** the internal persistence helpers are named `get_setting()` and `_persist()` rather than `get()` / `_set()` — using the latter names collides with `Object`'s built-in virtual `get(StringName)` / `_set(StringName, Variant)` methods and silently breaks script compilation (this was caught by the test suite; see [Testing](#testing)).

### Camera

`CameraController` supports:
- **Single-finger pan**, always active
- **Two-finger pinch-zoom** with pivot-relative scaling
- **Mouse wheel zoom** for desktop
- **Bounds clamping** — *conditional*: in wrap mode there are no bounds (the board recenters instead, see [Board Topology](#board-topology-wrap-vs-classic)); in classic mode, `set_board_bounds()` clamps offset to the board's rect (with a margin), and small boards are centered automatically.

### UI

- **MainMenu** (`main_menu.gd`): owns board type / rows / cols / bomb percentage / seed / wrap-mode / no-border selection; emits `start_requested`, `settings_requested`, `quit_requested`, `no_border_toggled`, `wrap_mode_changed` rather than calling into `base.gd` directly
- **ScreenManager** (`screen_manager.gd`): push/pop screen stack with fade transitions.
  - `push(screen, animated, dismiss_current)` — `dismiss_current=false` hides the current screen in place (modulate → 0, processing disabled) instead of freeing it, so it can be restored by the next `pop()`. Used when Settings is opened from either MainMenu or PauseOverlay, so either one reappears correctly on back.
  - `show_main_menu(main_menu)` — treats the always-present inline MainMenu node as the base of the navigation stack
  - `show_pause(gameplay_root)` / `hide_pause(gameplay_root)` — dims gameplay behind the PauseOverlay rather than swapping screens
- **PauseOverlay** (`pause_overlay.gd`): Resume / Restart / Settings / Quit to Menu, shown via `ScreenManager.show_pause()`; also triggered by the Android back button / <kbd>Esc</kbd> during gameplay (`base.gd._unhandled_input`)
- **SettingsMenu** (`settings_menu.gd`): sliders/checkboxes bound directly to `Settings` properties, built programmatically (no hand-authored control tree)
- **BoardGUI**: defuse counter (`flagged/total`), reset button, pause button
- **Screen.gd**: safe-area margin computation for notched devices, scales relative to 480×800 base resolution

## Design Decisions

### Why place mines after first click?
Guarantees the first tap is always safe and opens a playable area. The safe zone extends to distance 2 around the first click, giving a comfortable starting region.

### Why Fisher-Yates instead of random retry?
The original random-rejection loop degrades as the board fills — approaching O(∞) when mines nearly equal available cells. Shuffling valid indices and picking the first N is always O(n).

### Why BFS instead of recursive flood fill?
GDScript has a call stack limit. Deep recursion on large boards can overflow. Iterative BFS with an array-as-queue is stack-safe and equally efficient.

### Why one Tween per wave instead of per-cell Timers?
Flood fill and mine reveal can touch hundreds of cells. One Tween with sequential callbacks per wave uses a single object. Per-cell Timers would create N concurrent timer nodes — wasteful and harder to cancel. Waves are tracked in `_active_tweens` and may overlap (tapping again mid-wave must not cancel the earlier wave); `explore()` is a no-op on already-revealed or flagged cells, so overlapping waves are safe.

### Why Dictionary-as-Set for neighbors?
GDScript 4 has no native Set type. Dictionary with unused values is the standard workaround — O(1) lookup, O(1) insert, deduplication by key.

### Why explicit mark_as_mine() / increment_nearby()?
The original `nearby` setter silently accumulated on assignment (`cell.nearby = 1` actually did `nearby += 1`). Code reading `cell.nearby = -1` looked like it *set* the value. Explicit methods make intent unambiguous.

### Why draw the wrap-mode copies instead of instancing them?
The copies used to be 8 full tiles of display-only Control nodes — 4 nodes per cell, ~100k nodes on a 50×50 board — and they dominated build, first-frame and teardown time. Drawing them from a few hundred chunk nodes keeps the 3×3 block (so recentering stays a simple one-board shift) at a fraction of the cost. Measured on a 50×50 wrap board (headless, desktop CPU):

| | Node copies | Drawn copies |
|---|---|---|
| `start_game()` | 1,100–1,400 ms | ~150 ms |
| First frame | ~500 ms | ~135 ms |
| `clear()` | ~640 ms | ~120 ms |
| Nodes | ~100k | ~20k |
| Frame after one cell change | — | ~2 ms (one 8×8 chunk redrawn in each copy) |

Chunking (rather than one node drawing everything) keeps a cell change cheap and lets the renderer cull off-screen chunks. Dynamically spawning/freeing tiles as the camera moves was rejected earlier for the same reason it's still unnecessary: the block is built once per game, never per frame.

### Why recenter the board instead of the camera?
Early attempts moved the `Camera2D.offset` directly from inside `BaseBoard.recenter_if_needed()`. This put two different systems (the generic, reusable `CameraController` and the board's own wrap logic) writing to the same property from different call sites (input events vs. `_process`), risking order-dependent bugs — e.g. a pinch-zoom recalculating `offset` in the same frame a recenter snapped it. Moving `_board_node.position` instead keeps a strict single-writer rule: `CameraController` owns `offset` (pan/zoom/touch), `BaseBoard` owns its own transform. The visual result is identical either way since the copies are pixel-identical to the center tile.

### Why is a single tile's collision polygon derived from its fill polygon at runtime?
Each cell scene originally hand-authored two separate hardcoded vertex arrays — one for the visible `Polygon2D` fill, one for the `CollisionPolygon2D` hit area — that had to be kept in sync manually. `CellBase._bind_collision_shape()` now computes the collision polygon by scaling the fill polygon outward from its centroid (`COLLISION_SCALE = 1.1`) at `_ready()`, so there's one source of truth per cell shape and no risk of the two drifting apart when a shape is tweaked.

---

## Testing

The project has no editor dependency (no GUT or other addon) — tests are plain Godot scenes with a ~50-line custom harness (`Scripts/Tests/test_case.gd`), runnable headlessly.

### Running tests

```bash
./Scripts/Tests/run_tests.sh
```

Runs `godot --headless --import` first (a stale `.godot/` class cache makes every `class_name` type unresolvable, so scenes fail to load and hang), then every `Scenes/Tests/test_*.tscn` as its own `godot --headless` process with a per-suite timeout (`SUITE_TIMEOUT`, default 60 s). Prints per-assertion `PASS`/`FAIL` lines and exits non-zero if any suite failed or timed out. Individual suites can also be run directly:

```bash
godot --headless --path . Scenes/Tests/test_board_wrapping.tscn
```

### Suites

| File | Assertions | Covers |
|---|---|---|
| `test_board_wrapping.gd` | 14 | Wrap mode builds a 9-tile block with toroidal neighbor wrap; classic mode builds 1 tile with edge-clipped neighbors; odd hex/triangle sizes are rounded up in wrap mode and the neighbor relation stays symmetric — checked for square, hex, and triangle boards |
| `test_cell_binding.gd` | 15 | Collision polygon is non-empty, has the same vertex count, and has strictly larger area than the fill polygon — checked for all 5 cell scenes |
| `test_chord_reveal.gd` | 9 | Correctly flagged neighbors match the cell number and all remaining hidden neighbors are revealed |
| `test_long_press_defuse.gd` | 4 | Long-press toggles the flag on a hidden cell |
| `test_mine_color_sync.gd` | 8 | A mined cell explosion shows red background + white mine icon on the logical cell, the wrap-mode copies draw the same, and their chunks are redrawn on the next frame |
| `test_mine_placement.gd` | 10 | Distance-2 safe zone around the first tap; on a 5×5 board with 16 mines every mine is still placed and the mine count / win target match; overlapping reveal waves don't cancel each other |
| `test_neighbor_highlight.gd` | 11 | Holding a revealed number highlights its hidden neighbors, and releasing clears it |
| `test_pause_overlay.gd` | 12 | Drives `base.tscn`: Resume un-dims the board, the overlay is in screen space, Esc backs out of Settings to the same overlay, Restart builds a new board, Quit returns to the menu |
| `test_settings_persistence.gd` | 7 | Value clamping, `setting_changed` signal payload, and a real round-trip through `user://settings.cfg` via a fresh `ConfigFile` read |

### Writing a new test

1. Create `Scripts/Tests/test_my_thing.gd` extending `TestCase`, override `run()`, and call `assert_true` / `assert_eq` / `assert_gt` / `assert_false`
2. Create a matching `Scenes/Tests/test_my_thing.tscn` with a `Node` root and that script attached
3. Add the scene path to `TEST_SCENES` — actually, `run_tests.sh` globs `Scenes/Tests/test_*.tscn` automatically, so no registration step is needed

`TestCase._report()` calls `get_tree().quit()` after printing results, so each test scene is a self-contained, standalone-runnable process — this is why the runner shells out per-scene rather than looping in-process (see the comment in `run_tests.sh`).

### Gotchas this caught (worth knowing before writing more tests)

- **GDScript lambdas capture value-type locals by snapshot, not by reference.** A lambda that reassigns an outer `var received_key: String` won't be visible to the caller. Use a mutable container (`Array`, `Dictionary`) instead — see `test_settings_persistence.gd`'s `_test_signal_emission()`.
- **Use `wait_wall_ms()` for anything timed with `Time.get_ticks_msec()`** (e.g. long-press). `SceneTreeTimer` counts game time, and the large first-frame delta at startup can make a 0.5 s timer fire after ~360 ms of real time.
- **`Object.get()` / `Object._set()` are reserved virtual method names.** Defining a method literally named `get` or `_set` on any `Node`/`Object` subclass with an incompatible signature breaks compilation silently in the editor and only surfaces when the script is actually loaded (e.g. as an autoload at game start).
