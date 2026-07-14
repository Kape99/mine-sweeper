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
  - [Cell & FSM](#cell--fsm)
  - [Global State](#global-state)
  - [Camera](#camera)
  - [UI](#ui)
- [Design Decisions](#design-decisions)

---

## Game Overview

Classic minesweeper rules on non-standard grids:

- **Square board** — 8 neighbors per cell (Chebyshev adjacency)
- **Triangle board** — 3 neighbors per cell (edge-sharing only)
- **Hexagonal board** — 6 neighbors per cell (offset coordinates)

Three difficulty levels (Easy, Medium, Hard) scale the grid size and mine count per board type. The game is designed for portrait-mode mobile with touch input, but also supports mouse and scroll wheel on desktop.

## How to Play

1. **Tap** a cell to reveal it
2. **Toggle the flag button**, then tap cells to flag/unflag suspected mines
3. Revealing a cell with **0 adjacent mines** triggers a flood-fill that auto-reveals all connected safe cells in a wave animation
4. Revealing a **mine** ends the game — all remaining mines are shown in a ripple from the explosion point
5. **Win** by revealing every non-mine cell

The first tap is always safe: mines are placed *after* the first click, excluding the tapped cell and its neighbors within distance 2.

---

## Setup Flow

```
┌─────────────┐
│  Main Menu  │
│             │
│  ◄ Medium ► │  ← difficulty selector (Easy / Medium / Hard)
│             │
│    ▲        │
│   [■]       │  ← board type selector (△ / □ / ⬡)
│    ▼        │
│             │
│   [Start]   │
└──────┬──────┘
       │ player taps Start
       ▼
┌─────────────┐
│ Board loads  │  board scene instantiated, cells created
│ Waiting for  │  no mines placed yet
│ first tap    │
└──────────────┘
```

1. **DifficultySelector** syncs `selected_difficulty` and `selected_board` to `GlobalState`
2. Player taps **Start** → `base.gd._load_game()` runs:
   - Looks up the board scene from a dictionary (`{0: triangle, 1: square, 2: hexagon}`)
   - Instantiates and adds to scene tree
   - Fetches `GameData` (cols, rows, mines) from `GlobalState` for the selected board + difficulty
   - Resets defuse mode and button state
   - Calls `board.start_game(cols, rows, mines)` → subclass `reset()` creates the cell grid
   - Sets camera bounds to the board rect
3. Board is visible but **no mines exist** — the grid is blank, waiting for the first tap

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
   │     FSM: Unknown ↔ Defused (toggle)
   │     Emits cell_defused → updates counter
   │
   └── [defuse mode OFF] → cell.explore()
         FSM: Unknown → Explored
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
│   ├── base.tscn                    Main scene (menu + GUI + camera)
│   ├── board_gui.tscn               In-game HUD (score, reset, defuse)
│   ├── Board/
│   │   ├── square_board.tscn
│   │   ├── triangle_board.tscn
│   │   └── hexagon_board.tscn
│   └── Cells/
│       ├── square_cell.tscn
│       ├── up_triangle_cell.tscn
│       ├── down_triangle_cell.tscn
│       ├── hexagonal_cell.tscn
│       └── hexagonal_cell_variant.tscn
├── Scripts/
│   ├── base.gd                      Main game controller
│   ├── global_state.gd              Autoload singleton (GlobalState)
│   ├── Board/
│   │   ├── base_board.gd            Abstract board (game logic)
│   │   ├── square_board.gd          Square grid + Chebyshev neighbors
│   │   ├── hexagon_board.gd         Hex grid + offset-coord neighbors
│   │   └── triangle_board.gd        Triangle grid + edge neighbors
│   ├── Gameplay/
│   │   └── cell.gd                  Cell base class (CellBase)
│   ├── FSM/
│   │   ├── state_machine.gd         Generic FSM
│   │   └── States/
│   │       ├── BaseState.gd         Abstract state
│   │       ├── UnknownState.gd      Default (unrevealed)
│   │       ├── DefuseState.gd       Flagged
│   │       └── ExploredState.gd     Revealed
│   └── GUI/
│       ├── board_gui.gd             Score tracker + reset
│       ├── camera_controller.gd     Pan/zoom with bounds clamping
│       └── difficulty_selector.gd   Menu selector with animations
└── Asset/
    ├── Icons/                        SVG icons (mine, flag, arrows, etc.)
    └── Font/                         Custom font (Anton)
```

### Scene Tree

The main scene (`base.tscn`) is always loaded:

```
Base (Node)                          ← base.gd — game controller
├── Camera (Camera2D)                ← camera_controller.gd
└── GUI (CanvasLayer)
    └── Screen (MarginContainer)     ← safe area margins
        ├── MainMenu                 ← visible at start
        │   └── DifficultySelector   ← difficulty_selector.gd
        ├── BoardGUI                 ← hidden until game starts
        │   ├── DefuseButton
        │   └── ScoreTracker
        └── FinalScreen              ← hidden until game ends
            └── BackToMenu
```

Board scenes are instantiated *dynamically* as children of Base when a game starts, and freed on reset.

### Board System

```
BaseBoard (abstract)
├── SquareBoard
├── HexagonBoard
└── TriangleBoard
```

**BaseBoard** (`base_board.gd`) owns all game logic:
- Mine placement via Fisher-Yates shuffle — O(n) guaranteed, no retry loops
- BFS flood fill for empty cell expansion — O(n) with visited set
- Tween-based wave animations (one active tween at a time, new kills old)
- Win/lose detection, signal emissions
- `_get_nearby_cells(cell, distance)` — abstract, returns `Dictionary` used as a Set

**Subclasses** only define:
- `reset()` — instantiate cells into the grid
- `_get_nearby_cells()` — topology-specific neighbor lookup

| Board | Neighbor strategy | Distance > 1 |
|-------|------------------|---------------|
| Square | Chebyshev box (direct iteration) | Expands box range |
| Hexagon | BFS ring expansion with offset-coord neighbor table | Iterative rings |
| Triangle | BFS ring expansion with edge-adjacency (3 neighbors) | Iterative rings |

### Cell & FSM

Each cell scene contains:
- `Area2D` with `Polygon2D` (shape), `Label` (number), `TextureRect` (icon)
- `StateMachine` node with 3 child states

```
CellBase
└── StateMachine
    ├── Unknown    ← initial state
    ├── Defused    ← flagged
    └── Explored   ← revealed
```

**State machine** is a generic FSM — states are scene tree nodes, transitions by name. Each state calls `owner.set_display()` to update visuals, keeping states **decoupled from the cell's internal node tree**.

Cell exposes explicit methods instead of magic setters:
- `mark_as_mine()` — permanently marks as mine
- `increment_nearby()` — adds 1 to neighbor count (no-op if mine)
- `is_mine()`, `is_explored()`, `is_defused()` — state queries
- `set_display(bg, content, icon, text)` — visual update API for states

### Global State

`GlobalState` autoload singleton holds:
- **Game config**: board type, difficulty, `board_configs` dictionary mapping to `GameData` (cols, rows, mines)
- **UI state**: `is_defusing` flag
- **Color schemes**: data-driven dictionary, active scheme selected by key, colors exposed via getter properties

### Camera

`CameraController` supports:
- **Single-finger pan** with offset clamping to board bounds
- **Two-finger pinch-zoom** with pivot-relative scaling
- **Mouse wheel zoom** for desktop
- **Bounds clamping**: after every input, offset is constrained to keep the board on-screen. Small boards are centered automatically.

### UI

- **DifficultySelector**: animated scrollers for difficulty and board type, with animation-locked input to prevent double-scroll
- **BoardGUI**: defuse counter (`flagged/total`), reset button
- **Screen.gd**: safe-area margin computation for notched devices, scales relative to 480×800 base resolution

---

## Design Decisions

### Why place mines after first click?
Guarantees the first tap is always safe and opens a playable area. The safe zone extends to distance 2 around the first click, giving a comfortable starting region.

### Why Fisher-Yates instead of random retry?
The original random-rejection loop degrades as the board fills — approaching O(∞) when mines nearly equal available cells. Shuffling valid indices and picking the first N is always O(n).

### Why BFS instead of recursive flood fill?
GDScript has a call stack limit. Deep recursion on large boards can overflow. Iterative BFS with an array-as-queue is stack-safe and equally efficient.

### Why a single Tween instead of per-cell Timers?
Flood fill and mine reveal can touch hundreds of cells. One Tween with sequential callbacks uses a single object. Per-cell Timers would create N concurrent timer nodes — wasteful and harder to cancel.

### Why Dictionary-as-Set for neighbors?
GDScript 4 has no native Set type. Dictionary with unused values is the standard workaround — O(1) lookup, O(1) insert, deduplication by key.

### Why decouple states from cell internals?
FSM states previously accessed `owner._cell_text`, `owner._cell_icon`, etc. This tightly couples state logic to the cell's node tree. Now states call `owner.set_display()` — if the cell's internal structure changes, only `CellBase` needs updating.

### Why explicit mark_as_mine() / increment_nearby()?
The original `nearby` setter silently accumulated on assignment (`cell.nearby = 1` actually did `nearby += 1`). Code reading `cell.nearby = -1` looked like it *set* the value. Explicit methods make intent unambiguous.
