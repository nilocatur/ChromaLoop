# ChromaLoop — Audio Mapping (§7.2 / §19.4)

Event keys used by `AudioDirector` (`res://scripts/autoload/AudioDirector.gd`)
map to imported audio under `res://assets/audio/`. Logical keys are referenced
from code; filenames are never assembled from user input.

## SFX — `res://assets/audio/sfx/`

| event key | file | usage |
|---|---|---|
| `ui_tap` | `button_tap.wav` | generic button tap |
| `tray_select` | `tile_tap.wav` | tray tap / select |
| `marble_release` | `marble_drop.wav` | marble released from tray |
| `marble_roll` | `belt_hum_loop.wav` | belt rolling loop |
| `receiver_fill` | `slot_fill_1.wav` | receiver slot filled |
| `receiver_complete` | `stars_appear.wav` | receiver completed |
| `belt_warning` | `belt_jam.wav` | belt near-full / jam warning |
| `booster_use` | `cannon.wav` | booster activated |
| `victory` | `level_complete.wav` | level won |
| `failure` | `fail.wav` | level failed |
| `ice_break` | `ice_break.wav` | ice obstacle cleared |
| `mystery_reveal` | `mystery_reveal.wav` | mystery box revealed |
| `magnet` | `magnet.wav` | magnet booster |
| `shuffle` | `shuffle.wav` | shuffle booster |
| `booster_locked` | `booster_locked.wav` | booster unavailable |
| `slot_fill_2` | `slot_fill_2.wav` | alternate receiver fill |

## Music — `res://assets/audio/music/`

| event key | file | usage |
|---|---|---|
| `lobby_music` | `bgm_lobby.wav` | lobby background music (loop) |
| `gameplay_music` | `bgm_game.wav` | gameplay background music (loop) |

## Import state

All `.wav` sources were moved from the project root to `assets/audio/sfx|music/`
together with their `.wav.import` (and `.wav.meta` where present) so Godot's
import settings are preserved. No reimport is required.

## Notes

- `AudioDirector._asset_path()` returns `""` for unknown keys; `play_sfx` /
  `play_music` silently no-op when the path or stream fails to load — missing
  audio never breaks gameplay (REQ-08: levels solvable without audio).
- `slot_fill_2.wav` is present on disk but not bound to an event key; reserved.
