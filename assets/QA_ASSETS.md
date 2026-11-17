# ChromaLoop — Asset QA & License Audit

Release blocker tracker for every shipped source group. Update the status column as
each row is verified by the owner before any store submission.

Legend: `pass` = verified, `pending` = needs owner evidence, `fix` = problem found.

## Source bundles

| Group | Files | Source / evidence | Intended use | Status |
|---|---|---|---|---|
| Gameplay PNGs | 84 | `mobile_game_assets.zip` | marbles, trays, receivers, conveyor, obstacles, UI icons | pending |
| UI / backgrounds / branding | 32 | `chromaloop_separated_assets.zip` | panels, buttons, saga map, results, brand | pending |
| Avatars (precise) | 12 | `chromaloop_avatars_precise.zip` | player avatar picker | pending |
| SFX | 17 | `assets/audio/sfx/*` (mapped in `AUDIO_MAPPING.md`) | gameplay/meta feedback | pending |
| Music | 2 | `assets/audio/music/*` (mapped in `AUDIO_MAPPING.md`) | lobby and gameplay loops | pending |

## Per-asset checks

Apply to every shipped source group. Record failures in the table above.

- [ ] Rights: owner or license evidence recorded for each source.
- [ ] Originality: no third-party marks, trademarks, or unlicensed look-alikes.
- [ ] Transparency: alpha edges are clean, no white/black fringes.
- [ ] Dark and blue background check: readable against both lobby and gameplay backgrounds.
- [ ] Avatar crop: face and border align in the circular header frame.
- [ ] Import filter: Android import uses appropriate mipmaps/filtering for scale.
- [ ] Unused duplicate/staging files excluded from export (do not delete sources without owner approval).

## Store identity

- [ ] Title `ChromaLoop: Color Conveyor` cleared for store use.
- [ ] Package/application ID chosen and unique.

Keep `mobile_game_assets/.gdignore` in place so the staging folder does not create
duplicate imported UIDs.
