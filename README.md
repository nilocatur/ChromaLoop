# ChromaLoop: Color Conveyor

Godot 4.7 GDScript marble color-sorting puzzle. Built from `CHROMALOOP_GODOT_GAME_SPECIFICATION_v1.2_DETAILED.md`.
Portrait Android-first (logical baseline 540×960), deterministic outcomes, offline.

## Structure
- `data/asset_manifest.json` — logical ID → imported path map
- `data/game_balance.json` — economy / life tuning
- `data/levels/level_001.json` … `level_030.json` — level configs with expected traces
- `scripts/autoload/` — SceneRouter, PlayerProgress, AudioDirector, AssetCatalog, LevelRepository
- `scripts/core/` — deterministic `PuzzleSimulation`, belt/tray/receiver models, GameController
- `scripts/data/` — LevelRepository, LevelValidator
- `scripts/view/` — ConveyorView, ReceiverLaneView, TrayTile, Marble
- `scripts/boosters/` — booster effects live in `PuzzleSimulation` (`apply_booster`)
- `scenes/` — GameRoot, Lobby, Gameplay, ModalDialog
- `tests/` — GDScript unit tests (run headless)
- `AUDIO_MAPPING.md`, `assets/QA_ASSETS.md`, `HANDOFF_REMAINING_TASKS.md`

## Status
Levels 1–30 implemented and validator-checked. Gameplay renders trays, conveyor, and
receiver lanes from simulation events; pause/restart/failure/victory flows, zero-heart
countdown, atomic restart charging, authoritative run save/restore, boosters, and the
lobby/meta layer are in place. Android release packaging and on-device QA remain.

## Run
```bash
/opt/homebrew/bin/godot --path .            # main scene: res://scenes/app/GameRoot.tscn
```

## Test
```bash
/opt/homebrew/bin/godot --headless --path . --script res://tests/test_p0.gd   # example
```
Run every script in `tests/` headless; each asserts and exits non-zero on failure.
Smoke-test scenes and always inspect logs for `SCRIPT ERROR`.

## Audio
Audio events map in `scripts/autoload/AudioDirector.gd` and `AUDIO_MAPPING.md`;
files live under `res://assets/audio/`.
# chromaloop
# chromaloop
# ChromaLoop
# ChromaLoop
# ChromaLoop
# ChromaLoop
