# ChromaLoop — Remaining Work Handoff

**Purpose:** Give another coding AI enough context to finish ChromaLoop without repeating completed work or weakening locked requirements.

**Updated:** 2026-11-18  
**Project root:** `/Users/nugroho/Projects/ChromaLoop`  
**Engine:** Godot `4.7.2` at `/opt/homebrew/bin/godot`  
**Language:** GDScript 2.0  
**Git:** This folder is not a Git repository. Do not assume rollback or commit history exists.

## 0. Execution status (2026-11-17 pass)

### 0.0 Specification audit fixes (2026-11-18)

- ✅ Re-authored Levels 1–30 so every 9-marble tray contains one unique color and uses its matching shipped tray frame. Exact receiver supply/demand remains balanced.
- ✅ Level progression now measures valid release orders: easy stages allow at least 75%; hard stages allow at most 40%. Stored `solution_count` must match exhaustive prerequisite-aware validation.
- ✅ Levels 1–10 now stay within 2–4 colors. Levels 11–30 retain mystery, lock, crate and ice progression with branched prerequisites.
- ✅ `LevelValidator` now rejects mixed/duplicate-color trays, prerequisite cycles/unreachable trays, and solution-count drift.
- ✅ Gameplay capture fixes: compact tutorial info panel, shorter receiver labels, ring-based conveyor art, visibly moving belt marbles, and less-clipped booster controls.
- ⚠️ Mechanics still share prerequisite-unlock logic; mystery only adds hidden contents, while lock/crate/ice differ mainly by event/art/audio. Independent key, adjacency/break, and thaw rules remain P1 design work.
- ⚠️ Human difficulty/readability/fun approval and Android device QA remain mandatory. Exhaustive order counts prove solvability, not fun.

Completed in the latest pass, all covered by automated checks unless noted:

- ✅ Gameplay-rule audit fixed exact-full belt commits, future-action jam detection,
  immediate promoted-receiver cascades, partial receiver save/reorder state, Retry
  confirmation routing, failed-run restoration, stale marble cleanup, and ordered
  release/belt/receiver visual playback. Regression coverage: `tests/test_gameplay_rule_regressions.gd`.
- ✅ Full-belt lookahead now follows finite multi-tray progress sequences; mechanic
  unlock events run after release/cascades as required by §21.2.
- ✅ Levels 11–30 no longer force one linear tap chain. Spatial prerequisite branches
  preserve current expected traces while providing 3–15 validated winning orders.
- ✅ Failure/pause UX fixed: committed jam trays hide, Pause discloses `Restart −1`,
  zero-heart Retry remains blocked with live countdown until a heart regenerates.
- ✅ Mystery tray frames no longer leak hidden color; restored move HUD uses saved moves.
- ✅ Receiver queue previews and reduced-motion-safe conveyor flow cue added.
- ✅ Interface art pass: Changa One is global; Lobby uses full `button_play.png`,
  three connected `saga_path.png` map segments with Level 1 at bottom, profile-tap
  name/avatar editing, and asset-backed popup frames.
- ✅ Victory/popup frames use `panel_victory_large.png`; Retry/Restart use their
  baked-text button art. Gameplay release now drops marbles through shipped funnel,
  and moving belt markers show counter-clockwise travel without changing logical slots.
- ✅ §4.1 Receiver/tray/conveyor rendering, event playback, input locking.
  - Tray base, 9-marble grid, receiver column art, and the conveyor belt now render
	shipped art from `data/asset_manifest.json` (not default Godot controls or drawn lines).
- ✅ §4.2 Gameplay HUD, pause, restart/failure/zero-heart/victory flows and copy.
- ✅ §4.3 Monotonic operation ids, idempotent restart, safe regeneration, countdown.
- ✅ §4.4 `PuzzleSimulation.to_dict()/restore_from_dict()`, run persistence, safer backup.
- ✅ §4.5 Simulation-level Sweep/Picker/Reorder boosters and gameplay booster bar.
- ✅ §4.6 Distinct mechanic events, mystery non-leak, serialized mechanic state; unused `MechanicResolver.gd` removed.
- ✅ §4.7 Empty stubs filled (`set_receiver`, marble absorption, receiver promotion); audio mapping documented.
- ⚠️ §4.8 Accessibility foundation extended (a11y names/tooltips); real device layout QA still required.
- ⚠️ §4.9 Settings privacy/credits copy added; device persistence QA still required.
- ⚠️ §4.10 `assets/QA_ASSETS.md` created; owner license evidence still required (release blocker).
- ⚠️ §4.11 `export_presets.cfg` created; real APK/AAB build and device matrix still required (release blocker).

Verification commands now pass: compile (38 scripts, 0 broken), scene checker (0/0),
all 16 test scripts (exit 0, no errors), and main/lobby/gameplay smoke logs clean.
Headless passes do not prove on-device visuals or license clearance.

### 0.1 Asset integration pass (2026-11-17)

All 133 manifest entries exist on disk; **audio was already fully wired** and
**images are now fully wired**:

- New `UITheme` autoload builds a project-wide `Theme` from shipped panel art
  (`panel_pill`, `panel_dialog`, `panel_info`) so buttons, panels, text fields and
  labels are no longer default Godot controls.
- `AssetCatalog` gained section-aware lookups plus downscaled icon caching
  (`get_ui_icon`/`get_section_icon`), because `"red"` exists under both `marbles`
  and `receivers`, and shipped button art is very large.
- Gameplay: background, pause/restart icons, heart icon + counter, tray base art
  per colour, 9-marble grid, mechanic overlays, receiver column art with filled
  holes, conveyor belt tiled along the path, tutorial bubble, booster icons, and
  victory/game-over art with star row in the modal.
- Lobby: background, connected bottom-up saga path, avatar/name profile editor,
  heart/coin icons, full Play art, plus/store/settings icons, saga level-node icons,
  Changa One font, asset-framed popups, and shop booster icons.
- New `tests/test_asset_wiring.gd` locks this wiring (scenes must show real art,
  a tray tap must spawn a textured marble, lobby icons must exist).

Still owner/device work (unchanged release blockers): on-device visual QA,
Android APK/AAB build + device matrix, license/originality sign-off
(`assets/QA_ASSETS.md`), and human Level 1–30 playtest.

## 1. Source of truth

Read these before editing:

1. `CHROMALOOP_GODOT_GAME_SPECIFICATION_v1.2_DETAILED.md` — product rules and acceptance criteria.
2. This file — current implementation state and remaining tasks.
3. `data/asset_manifest.json` — logical asset IDs and real imported paths.
4. `AUDIO_MAPPING.md` — real audio event mapping.
5. Existing tests under `tests/` — regression floor, not proof game is finished.

When documents conflict, locked requirements in specification §18.1 win.

## 2. Locked requirements — never regress

- Product name: **ChromaLoop: Color Conveyor**.
- Portrait Android-first game, logical baseline `540×960`.
- Godot 4.x and GDScript only.
- Default board: 4 receiver lanes, 3 holes per receiver, 9 marbles per standard tray, 22 belt slots.
- Deterministic outcomes. Simulation logic must not depend on animation timing, frame rate, or physics.
- Restart and Retry cost **exactly 1 heart**, only after explicit confirmation.
- Pause, cancel, app backgrounding, save, and resume cost 0 hearts.
- Zero hearts blocks Restart/Retry. Hearts must never become negative.
- No Home, Lobby, Back-to-Lobby, Quit, or Exit-Level control during active gameplay, pause, or failure.
- Every shipped level must be solvable without boosters, ads, purchases, or networking.
- Save locally and atomically to `user://save_v1.json`.
- Existing art and audio take priority. Do not generate replacements or invent paths.
- Keep `PuzzleSimulation` independent of Node, Tween, audio, and scene code.
- View consumes ordered simulation events; view must not decide puzzle outcomes.

## 3. Work already present — preserve it

### Core and content

- Autoloads configured: `SceneRouter`, `PlayerProgress`, `AudioDirector`, `AssetCatalog`, `LevelRepository`.
- Pure simulation supports tray release, belt placement, receiver matching, cascades, win/fail, and atomic jam rollback.
- Level files `data/levels/level_001.json` through `level_030.json` exist.
- Levels include deterministic expected traces.
- Mystery, locked, crate, and ice trays use deterministic branched `unlock_after` prerequisites.
- `LevelValidator` checks core schema, supply/demand, tray types, prerequisites, and opening actions.
- `tools/validate_levels.gd` provides basic editor-side validation.

### Meta and persistence

- Save schema 3 with migration.
- Name and 12-avatar selection persist.
- Coins, stars, completion, unlocks, booster inventory, settings, and streak fields persist.
- Lobby has 30 saga nodes, header, avatar picker, Shop, Settings, streak, and footer tabs.
- Music/SFX settings use `Music` and `SFX` buses.
- Existing Shop prices:
  - Sweep: 60 coins
  - Picker: 80 coins
  - Reorder: 70 coins

### Layout/accessibility foundation

- `canvas_items` stretch with `expand` aspect.
- Portrait orientation configured.
- Dynamic safe-area margin script exists at `scripts/ui/SafeAreaMargin.gd`.
- Lobby popups and gameplay top/bottom HUD use anchored Controls.
- Main controls target at least 48 logical pixels.
- Lobby/modal focus setup and focus restoration exist.
- Reduced-motion setting skips belt movement tween.
- Tray color letters and mechanic text markers supplement color.

### Existing checks

- `tests/test_p0.gd`
- `tests/test_levels_1_10.gd`
- `tests/test_levels_1_30.gd`
- `tests/test_milestone_c.gd`
- `tests/test_meta.gd`
- `tests/test_accessibility_layout.gd`

These checks currently pass. They cover narrow assertions and do **not** prove polished or fully playable presentation.

## 4. Critical remaining work

Complete tasks in order. Do not start release packaging before sections 4.1–4.7 pass.

### 4.1 Gameplay visual integration — completed; device QA remains

Gameplay model/view integration is complete in headless checks. Human device review remains.

#### Receiver lanes

`scripts/view/ReceiverLaneView.gd` renders active receiver, exact fill, identity text,
and two stable queued previews.

Implement:

- Render active receiver art by color.
- Show 3 holes and exact filled count.
- Show queued receivers beneath/behind active receiver in stable order.
- Promote next receiver visually when current completes.
- Add text/shape marker so receiver identity is not color-only.
- Keep four lanes readable at 540 logical pixels wide.
- Update views from simulation events/state; never duplicate receiver logic in view.

Acceptance:

- Releasing a matching marble visibly fills one hole.
- Completing 3/3 visibly removes active receiver and promotes next.
- Visual queue always matches `ReceiverLaneModel.queue`.
- No overlap at 9:16, 9:19.5, or 9:20.

#### Tray rendering

`TrayTile` renders tray base plus all nine marbles, hides mystery contents/frame color,
and follows simulation accessibility.

Implement:

- Render tray base plus all 9 marble contents in deterministic order.
- Remove/hide tray after committed release.
- Keep blocked trays visibly blocked and untappable.
- Mystery must not leak hidden color before reveal.
- Locked/crate/ice overlays must clear only after simulation event.
- Legal trays need non-color-only highlight or label.

Acceptance:

- Every tray displays exactly 9 marbles before release.
- Blocked tray cannot emit `tray_tapped`.
- Jam rollback leaves tray and all 9 marbles visually unchanged.

#### Conveyor

`ConveyorView` tiles the shipped `conveyor/straight` art along the `Path2D` and
draws warning/slot markers; `belt_capacity` follows the level.

Implement:

- Render supplied conveyor/funnel assets or one scalable path-based track.
- Use level `belt_capacity`; remove hardcoded `22` from `ConveyorView.belt_capacity()` where levels override capacity.
- Show occupied logical slots accurately.
- Animate movement without changing logical slot state.
- Add near-full warning readable without sound or color alone.
- Stop or simplify continuous effects when reduced motion is enabled.

Acceptance:

- Visual slot count equals simulation capacity.
- Every `marble_to_belt` event ends at correct slot.
- Cascade absorption removes correct belt marble.
- No token remains visible after logical absorption.

#### Event playback and input locking

Current controller applies events immediately and starts tweens without an action queue.

Implement:

- Replay events sequentially in emitted order.
- Lock tray input during critical event playback, or queue at most one tap as specification allows.
- Never call simulation twice from double-tap.
- Reduced motion should shorten/skip nonessential animation while preserving event order.
- Play `marble_release`, `receiver_fill`, and rolling audio at correct events.

Acceptance:

- Rapid tapping cannot spend two moves or release same tray twice.
- Normal and reduced-motion modes produce same checksum/result.
- Visual playback can be skipped in tests without changing simulation.

### 4.2 Finish gameplay HUD, overlays, and result flow — P0

Current modal is generic; required copy/state is incomplete.

Implement exact flows:

#### Pause

- Actually pause gameplay input/event playback.
- Buttons: `Resume`, optional sound controls, `Restart −1`.
- Never show Home/Exit/Lobby.
- Android Back opens pause; Back while pause is open resumes or leaves pause open consistently.
- Opening/resuming pause costs 0 hearts.

#### Restart confirmation

- Title: `Restart Level?`
- Message: `Restarting costs 1 heart. Your current attempt will reset.`
- Live balance text: `Hearts: N → N-1`.
- Buttons: `Cancel`, `Restart −1`.
- Revalidate heart count on confirm.
- Disable repeat confirmation while wallet transaction runs.

#### Failure/Retry

- Title: `Game Over`.
- Show reason: conveyor blocked or out of moves.
- Retry must be labeled `Retry −1`, not generic Restart.
- Explicit Retry confirmation costs exactly 1 heart.
- No automatic heart charge on failure.
- Never show Home/Exit/Lobby.

#### Zero hearts

Current `show_zero_heart()` only displays `Out of Hearts` and `OK`.

Implement:

- Disable Restart/Retry.
- Display `Next heart in MM:SS` using persisted UTC regeneration data.
- Refresh countdown without writing save every frame.
- Re-enable Retry when one heart regenerates.
- Handle wall-clock rollback without granting negative or duplicate regeneration.

#### Victory

- Show stars, earned coins, and `Next Level`.
- Save reward/progress before transition.
- Level 30 should show all-levels-complete behavior without recursive modal handler mistakes.
- Starting next level costs no heart.

#### HUD

- Keep Pause, level number, optional moves, and Restart visible in safe area.
- Update moves after every committed action.
- Add actual booster controls and counts only after section 4.5 is implemented.
- No dead or decorative controls that look interactive.

### 4.3 Repair and prove heart transactions/regeneration — P0

`PlayerProgress.try_spend_life_for_restart()` needs stronger crash/idempotency tests. Current operation duplicate handling checks only `pending_restart_operation`, while operation IDs restart from 1 per new `GameController` instance.

Fix design:

- Use operation IDs that cannot collide after scene reload/app restart. Persist monotonic ID or use persisted unique string IDs.
- Repeating same operation after save/reload must never charge twice.
- Interrupted transaction must resolve to either one committed charge or no charge, never ambiguous double charge.
- Restart and Retry use same atomic transaction API.
- Cancel never creates pending transaction.
- Save failure restores in-memory balance and emits corrected wallet state.

Fix regeneration:

- Read `max_hearts` and interval from `data/game_balance.json` or one authoritative constant source.
- When hearts are full, do not leave stale `next_regen_utc` that grants an immediate replacement after spending.
- Spending from full hearts must start correct next-heart timer.
- Regeneration should catch up offline only to max hearts.
- Handle clock rollback safely.
- Emit/save when regenerated balance changes.

Add `tests/test_lives_transactions.gd` covering specification `LIVES-01` through `LIVES-09`, especially:

- Confirm once: 5 to 4.
- Confirm callback twice: still 4.
- Same operation after simulated reload: still 4.
- One heart to zero.
- Zero-heart retry blocked.
- Cancel/pause/background preserve hearts.
- Full-heart stale timer cannot cancel a restart cost.
- Save interruption resolves safely.

### 4.4 Complete authoritative run save/restore — P0

`PlayerProgress.run` exists, but gameplay does not persist or restore complete simulation state.

Implement:

- Add explicit `PuzzleSimulation.to_dict()` and `restore_from_dict()` public APIs.
- Include trays, token states, lane queues/counts, belt slots, status, moves, action count, seed, rules version, and checksum.
- Save after every committed action and terminal result.
- Save only committed logical state, never half-played visual animation.
- Save on app suspension/background notification.
- On launch, restore safe active/failure checkpoint where required.
- Verify level/rules version before restore; reject incompatible state safely.
- Preserve backup semantics. Backup should retain last known valid save, not merely mirror possibly bad new JSON.
- Validate parsed types before casting malformed JSON.
- Report low-storage/write/rename failure without losing current valid save.

Add `tests/test_save_restore.gd`:

- Round-trip every simulation field.
- Same restored actions produce same checksum.
- Corrupt primary recovers backup.
- Corrupt primary and backup produce safe defaults.
- Old schema migration preserves progress/settings.
- In-flight visual interruption restores last committed action only.
- Save write failure does not deduct heart or destroy old save.

### 4.5 Implement real boosters — P1

Shop inventory exists, but gameplay boosters do not. `scripts/boosters/` mentioned in old README does not exist.

Implement all three in simulation-level deterministic APIs:

- **Sweep:** clear belt into explicit rescued sink; update objectives correctly.
- **Picker:** choose one otherwise inaccessible valid tray/source target with preview and validation.
- **Reorder:** deterministically reorder eligible queued receivers while preserving color totals and solvability guardrails.

Rules:

- Never consume inventory if activation cannot complete.
- Confirm activation when stock is low.
- Disable at zero inventory or when no legal target exists.
- Booster use must produce ordered events and update checksum.
- No level solution may require a booster.
- Add controls to gameplay booster bar with icon, name, count, disabled state, focus, and 48px target.

Add `tests/test_boosters.gd` for success, invalid target, zero inventory, no negative inventory, determinism, and objective correctness.

### 4.6 Strengthen Level 11–30 mechanics and content quality — P1

Current Mystery/Lock/Crate/Ice implementation is one generic `unlock_after` prerequisite mechanism. `scripts/core/MechanicResolver.gd` remains unused/stubbed.

Choose one clean approach:

- Delete unused `MechanicResolver.gd` and keep mechanic resolution in `PuzzleSimulation`, or
- Move mechanic rules into resolver contract and use it from simulation.

Do not leave two competing systems.

Implement distinct tested behavior from specification:

- Mystery reveals after declared neighboring/prerequisite tray clears without leaking hidden content.
- Lock opens from declared key/prerequisite; all references resolve.
- Crate breaks from declared adjacency/tagged clear rule.
- Ice thaws from declared adjacent/matching clear rule.
- Serialize every mechanic state.
- Emit unique visual/audio event per mechanic (`mystery_reveal`, `ice_break`, etc.).
- Validator detects missing references, self-reference, cycles with no opening, unsupported tags, and unresolved obstacle records.

Content pass:

- Human-playtest Levels 1–30.
- Replace repetitive or trivial layouts.
- Difficulty labels must reflect measured play, not level number alone.
- Keep at most two new mechanics mixed until taught.
- Ensure tutorial prompts explain each mechanic once and do not cover tappable content.
- Preserve deterministic validation metadata (`validated_at`, rules version, checksum).

### 4.7 Receiver/gameplay view integration — completed; audio device polish remains

Ordered event playback owns marble absorption and receiver promotion. Obsolete empty
callbacks are absent; `SceneRouter.change_to_paused()` intentionally preserves gameplay.

Audio:

- Use `AssetCatalog` or one audio catalog instead of duplicated hardcoded maps where practical.
- Limit concurrent rolling sounds to 2.
- Stop old music cleanly when switching Lobby/gameplay.
- Test mute at zero, app background/foreground, phone interruption, and repeated scene changes.
- Use correct SFX for mystery, ice, fill, completion, win, and failure.
- Haptics must respect saved toggle and unsupported platforms.

### 4.8 Finish accessibility and responsive layout — P1

Foundation exists, but current automated check only tests one logical viewport headlessly.

Complete:

- Test actual rendered layouts at 9:16, 9:19.5, and 9:20.
- Test notched Android safe areas and bottom gesture inset.
- Ensure world gameplay content also reflows/centers on tall displays; current Node2D positions remain mostly fixed.
- Keep CTA/footer/booster bar visible without clipping.
- Add accessibility names/descriptions to icon-only controls where Godot platform support permits.
- Verify keyboard/gamepad traversal for Lobby, avatar picker, Shop, Settings, pause, confirmations, failure, and victory.
- Trap modal focus and restore previous focus on close.
- Test text at larger OS/font scale if supported.
- Ensure gameplay identity is not communicated by color alone for trays, receivers, belt warnings, and locked state.
- Reduced motion must cover all nonessential tweens/effects, not only belt movement.
- Add language selector only when localization is implemented; otherwise do not show dead selector.

Add screenshot/manual QA records for each target aspect ratio. Headless bounds checks alone are insufficient.

### 4.9 Complete Settings, privacy, and credits — P2

Current Settings has music, SFX, haptics, reduced motion, reset, and brief credits.

Finish specification-required items:

- Add language only with real translations; otherwise document English-only release scope.
- Add readable credits for owned/licensed asset/audio sources.
- Add privacy link/document appropriate for offline game.
- Ensure Reset confirmation clearly states all erased data.
- Reset must remove active run, transactions, progress, inventory, settings, and regenerate a valid default save.
- Settings changes survive process restart.

### 4.10 Asset, originality, and license audit — release blocker

Create/update `assets/QA_ASSETS.md` with one row per shipped source group or asset:

- Filename/logical ID.
- Source/owner/license evidence.
- Intended use.
- Transparency and edge quality.
- Dark/blue background check.
- Avatar border/crop check.
- Pass/needs-fix status.

Also:

- Confirm ChromaLoop title/store-name availability.
- Confirm all 84 gameplay PNGs, 20 UI files, 12 precise avatars, and audio are owned/licensed for release.
- Remove unused duplicate/staging assets from exports, but do not delete source files without owner approval.
- Keep `mobile_game_assets/.gdignore` to avoid duplicate imported UIDs.
- Audit texture import filtering/compression for Android.

### 4.11 Android build and device QA — release blocker

No `export_presets.cfg` currently exists.

Implement:

- Android export preset for Godot 4.7.2.
- Correct package/application ID, versioning, portrait orientation, icons, and required SDK/template settings.
- Debug APK build first; release AAB/signing only with owner-provided secure credentials.
- Never commit signing secrets or passwords.

Device matrix:

- At least one low-range and one mid-range Android device.
- 9:16, 9:19.5, and 9:20/notched display.
- Touch input, rapid taps, system Back, app background/resume, phone audio interruption.
- Cold launch, corrupted save recovery, low storage, muted audio, haptics off, reduced motion.
- Stable target 60 fps; no obvious battery-heavy polling or unbounded audio players.
- Full Level 1 and representative Levels 11/15/19/23/27/30 playthrough.

Do not claim release-ready from headless desktop tests alone.

## 5. Known technical risks

1. **Receiver view is empty.** Tests can pass while gameplay receivers are invisible.
2. **Tray view is not 3×3.** It currently represents tray by one color texture.
3. **Event playback is immediate.** Conflicting taps are not robustly locked during animation.
4. **Run restore is incomplete.** Save fields exist but authoritative simulation resume does not.
5. **Wallet idempotency needs crash/reload proof.** Current tests do not cover full transaction matrix.
6. **Heart regeneration may use stale timestamps.** Test spending after long time at full hearts.
7. **Boosters are inventory/shop only.** No gameplay effects exist.
8. **Mechanics are generic prerequisites.** Distinct crate/ice/key behavior needs implementation or explicit scope approval.
9. **Stars are always awarded as 3.** Define and test star calculation from declared level rules/moves.
10. **30-level solver check is narrow.** It validates a trace/permutation model, not fun, readability, or every mechanic branch.
11. **UI visual QA is missing.** Headless tests cannot prove no clipping, poor contrast, or bad safe areas.
12. **README is stale.** It says Milestone A/B and references folders that do not exist.

Resolved in the latest pass: 1–9 and 12. Still open: 10 (30-level solver remains narrow),
11 (no on-device visual/accessibility QA yet).

## 6. Required automated tests before declaring finished

Keep existing tests and add these:

- `tests/test_lives_transactions.gd` ✅ added
- `tests/test_save_restore.gd` ✅ added
- `tests/test_boosters.gd` ✅ added
- `tests/test_deterministic_replay.gd` ✅ added
- `tests/test_input_locking.gd` ✅ added
- `tests/test_mechanics_all.gd` ✅ added
- `tests/test_navigation_rules.gd` ✅ added
- `tests/test_audio_settings.gd` ✅ added

Minimum assertions:

- Same seed + actions gives same checksum twice and after restore.
- Jam rollback restores every token/tray/lane/belt field and emits no aborted mutation visuals.
- No token ID is lost or duplicated.
- Restart/Retry costs exactly one heart under rapid/double callbacks and reload.
- Pause/cancel/background costs zero hearts.
- Zero hearts blocks paid actions.
- No Home/Lobby/Exit control exists in gameplay, pause, or failure trees.
- Every visible Lobby control acts or is intentionally disabled/hidden.
- Shop coin/inventory transaction reconciles after save/reload.
- Invalid booster use consumes nothing.
- Levels 1–30 validate and replay without boosters.
- Music/SFX zero volume mutes correct bus.
- Reduced motion preserves simulation checksum.

## 7. Verification commands

Run from `/Users/nugroho/Projects/ChromaLoop`.

### Compile all GDScript

```bash
/opt/homebrew/bin/godot --headless --path . --script /Users/nugroho/.agents/skills/godot-gdscript/assets/check_scripts_compile.gd
```

Expected: `broken: 0`.

### Check scenes/resources

```bash
python3 /Users/nugroho/.agents/skills/godot-nodes-scenes/scripts/check_godot_project.py . --json
```

Expected: `error_count: 0`, `warning_count: 0`.

### Existing tests

```bash
for test in \
  test_p0.gd \
  test_levels_1_10.gd \
  test_levels_1_30.gd \
  test_milestone_c.gd \
  test_meta.gd \
  test_accessibility_layout.gd; do
  /opt/homebrew/bin/godot --headless --path . --script "res://tests/$test" || exit 1
done
```

### Main scene smoke test

Godot can return success despite script/runtime errors. Always inspect logs.

```bash
timeout 10 /opt/homebrew/bin/godot --headless --path . > /tmp/chromaloop-main.log 2>&1
grep -nE "SCRIPT ERROR|^ERROR:|^WARNING:" /tmp/chromaloop-main.log
```

No matches expected. `timeout` exit is normal for a running game.

### Gameplay scene smoke test

```bash
timeout 10 /opt/homebrew/bin/godot --headless --path . --scene res://scenes/gameplay/Gameplay.tscn > /tmp/chromaloop-gameplay.log 2>&1
grep -nE "SCRIPT ERROR|^ERROR:|^WARNING:" /tmp/chromaloop-gameplay.log
```

No matches expected.

## 8. Manual acceptance checklist

Do not mark project finished until all items pass on Android hardware.

### Gameplay

- [ ] Level shows real 3×3 trays, visible conveyor, and four visible receiver lanes.
- [ ] Every tap releases correct 9 marbles exactly once.
- [ ] Receiver holes, queue promotion, and belt slots match simulation.
- [ ] Mystery/lock/crate/ice are visually and logically distinct.
- [ ] Rapid tapping cannot double-release or double-charge.
- [ ] Win/fail reasons and rewards are readable.
- [ ] Levels 1–30 complete without boosters.

### Lives/navigation/save

- [ ] Confirmed Restart costs exactly 1 heart.
- [ ] Confirmed Retry costs exactly 1 heart.
- [ ] Pause/cancel/background costs 0 hearts.
- [ ] Zero hearts shows countdown and blocks paid action.
- [ ] No Home/Lobby/Exit control appears during gameplay/pause/failure.
- [ ] Relaunch restores safe committed state.
- [ ] Corrupt primary save recovers backup/default safely.

### Meta/UI/accessibility

- [ ] Lobby opens at current level and locked levels cannot launch.
- [ ] Avatar, name, coins, hearts, stars, streak, inventory, settings persist.
- [ ] Shop reconciles coins and booster stock after restart.
- [ ] All visible controls work with touch and gamepad/keyboard.
- [ ] No clipping at 9:16, 9:19.5, 9:20, or notch/gesture insets.
- [ ] Color information has text/shape backup.
- [ ] Reduced motion and audio/haptics toggles work after relaunch.

### Release

- [ ] Asset/audio rights and originality audit complete.
- [ ] Android debug APK installs and runs.
- [ ] Android release AAB builds with owner-controlled signing.
- [ ] Low/mid-range device smoke tests pass.
- [ ] README matches actual project structure/status.

## 9. Files most likely to change

| File | Why |
|---|---|
| `scripts/core/PuzzleSimulation.gd` | Serialization, boosters, mechanic rules, deterministic actions |
| `scripts/core/GameController.gd` | Input lock, event playback, HUD, pause/win/fail/retry flow |
| `scripts/core/TrayModel.gd` | Mechanic state and serialization |
| `scripts/core/MechanicResolver.gd` | Deleted; mechanic rules live in `PuzzleSimulation` |
| `scripts/autoload/PlayerProgress.gd` | Atomic wallet, regeneration, run persistence, recovery |
| `scripts/autoload/AudioDirector.gd` | Concurrency, scene transitions, interruption handling |
| `scripts/view/TrayTile.gd` | Real 3×3 tray and blocked overlays |
| `scripts/view/ReceiverLaneView.gd` | Active/queued receiver rendering |
| `scripts/view/ConveyorView.gd` | Capacity-driven track and belt visuals |
| `scenes/gameplay/Gameplay.tscn` | Finished HUD/playfield/booster layout |
| `scenes/ui/ModalDialog.tscn` | Correct copy, timer, focus, disabled transaction state |
| `scripts/app/Lobby.gd` | Final settings/privacy/credits and responsive polish |
| `data/levels/*.json` | Human content/difficulty polish only; preserve IDs |
| `tests/*.gd` | New correctness and regression coverage |
| `export_presets.cfg` | Android export configuration |
| `README.md` | Final accurate status and commands |

## 10. Implementation rules for next AI

- Make smallest safe changes; do not rewrite working simulation without evidence.
- Read surrounding code before replacing files.
- Do not delete unfamiliar assets or user files.
- Do not add dependencies; Godot/native APIs are enough.
- Keep trust-boundary validation for JSON, save data, IDs, prices, and settings.
- Never expose private methods from `PlayerProgress` as UI transaction shortcuts.
- Add one runnable test for every nontrivial rule fix.
- Run compile, scene, all tests, and smoke logs after each task group.
- Report exact files changed and exact checks run.
- Do not claim visual/device acceptance from headless tests.
- Do not add ads, IAP, analytics, or networking unless owner explicitly requests them.
- Do not alter locked life/navigation rules for convenience.

## 11. Definition of finished

Project is finished for current offline Android scope only when:

1. Levels 1–30 are visually playable and human-playtested.
2. Gameplay has complete tray, belt, receiver, HUD, modal, audio, haptic, and booster presentation.
3. All deterministic, save, transaction, mechanic, navigation, and accessibility tests pass.
4. Restart/Retry and zero-heart behavior pass device tests exactly.
5. Save recovery survives corrupted/interrupted cases.
6. No Home/Lobby/Exit route exists during active gameplay, pause, or failure.
7. Android debug APK and release AAB build successfully.
8. Required aspect ratios and low/mid Android hardware pass manual QA.
9. Asset/audio licenses, privacy, credits, and store identity are approved by owner.
10. README and this handoff no longer contain unresolved release blockers.

Ads, IAP, analytics, iOS shipping, and expansion mechanics are outside current finish scope unless owner explicitly adds them.
