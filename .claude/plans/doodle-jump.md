# Plan: Doodle Jump HTML game

## Goal
A self-contained, dependency-free Doodle Jump clone in a single `octo-test/doodle-jump.html`
file (HTML + Canvas + vanilla JS). Opens directly in a browser, no build step.

## Mechanics
- Canvas ~400x600. Player auto-bounces on platforms; gravity pulls down.
- Left/right arrows (and A/D) move horizontally with screen wraparound.
- Camera scrolls up as the player climbs; score = max height climbed.
- Platforms generated procedurally above the viewport; old ones culled below.
- Platform types: normal (static), moving (horizontal), breakable (one-time, disappears).
- Game over when player falls below the bottom of the viewport. Restart on key/click.
- High score persisted in localStorage.

## Tasks
1. HTML scaffold + canvas + styling + score/game-over overlay (task-1, file: doodle-jump.html).
2. Core game loop: gravity, player bounce physics, input handling (task-2, file: doodle-jump.html).
3. Platform generation/culling + platform types + camera scroll + scoring (task-3, file: doodle-jump.html).
4. Game states (start/playing/over), restart, localStorage high score (task-4, file: doodle-jump.html).

All tasks touch the single file → executed sequentially in one implementer pass (no parallel lanes apply).

## Verification
- Static: HTML parses, no JS syntax errors (node --check on extracted script).
- Manual/headless: game initializes, requestAnimationFrame loop runs, no console errors.

## Assumptions
- [SAFE] Single-file vanilla JS, no external libs/CDN — most reversible, zero deps.
- [SAFE] Target = octo-test/ (repo's existing scratch dir) since no host CLAUDE.md and this is a demo artifact.
- [SAFE] Simple colored-rectangle sprites (no image assets) — reversible, keeps it single-file.

## Open Questions
None blocking. Gate clears unattended.
