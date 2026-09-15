# How many draws until a winner, by player count

Not yet executed -- pure math/combinatorics, no code or live testing needed. Frank wants a table: for N players in {5, 10, 25, 50, 100}, how many cards typically need to be drawn before a win is possible.

## Model

- 54-card deck. A player's tabla is a uniformly random 16-card subset of it (the seeded shuffle-and-take-16 in `Tabla`). The draw order is an independent uniformly random permutation of the same 54 cards (`drawOrderFor`). Real Lotería behaves the same way, so treating these as independent is the right modeling assumption, not a simplification that changes the answer.
- After D draws, a specific 4-cell candidate shape on a tabla (one row, one column, one diagonal, the four corners, or one El Pozo 2x2 block) is "hit" iff all 4 of its cards are among the first D drawn. Because of the symmetry above, this probability doesn't depend on *which* 16 cards are on the tabla -- only on the deck size (54), the draw count (D), and how many candidate shapes the pattern has and whether they overlap:

  P(one specific 4-card shape is hit by draw D) = C(50, D-4) / C(54, D)

- A player *wins* the round's chosen pattern at draw D iff **any** of that pattern's candidate shapes is hit. Candidate counts per pattern (from `WinningPattern`):
  - Four in a row (horizontal/vertical): 4 disjoint candidates (the 4 rows, or the 4 columns)
  - Four in a row (diagonal): 2 disjoint candidates
  - Four corners: 1 candidate (no choice at all)
  - El Pozo: 9 candidates, **overlapping** (adjacent 2x2 blocks share cells) -- needs inclusion-exclusion, not a simple disjoint-union sum, to get exact.

## What to compute

1. For each of the 5 pattern types, exact P(a single random tabla has won) as a function of D (D = 4..54), via inclusion-exclusion over that pattern's candidate shapes. (Disjoint patterns collapse to a simple sum; El Pozo's overlapping blocks are the only one that actually needs the full inclusion-exclusion treatment.)
2. Combine across N *independent* players (independent tablas): P(at least one winner among N players by draw D) = 1 - (1 - p_D)^N, where p_D is the single-tabla probability from step 1.
3. For each N in {5, 10, 25, 50, 100} and each pattern type, find the **median** draw count (smallest D where that probability crosses 50%) -- and probably a P10/P90 spread too, since the tails matter for "how long could this realistically drag on."
4. Since the admin picks a pattern uniformly at random each round, also compute an **averaged-over-pattern** row per N, not just per-pattern numbers -- that's the one closest to "what should I actually expect at a real event."

## Output

A table: rows = player counts (5, 10, 25, 50, 100), columns = the 5 pattern types + one "random pattern" average column, cells = median draw count (plus maybe P10/P90 in parentheses).

## Implementation note

Pure combinatorics, no simulation needed -- exact via `math.comb`-style binomial coefficients (Python's arbitrary-precision integers are the easiest fit here, given C(54,27)-scale numbers; a short one-off script, not part of the app). El Pozo's inclusion-exclusion is the only fiddly part; everything else is a direct sum.

## Caveat to flag in the writeup

This computes the *theoretical earliest possible* win -- the draw count at which a valid claim first exists, not when a real player actually notices and taps ¡Lotería!. Real games will run a bit longer than these numbers due to human reaction time. Still the right thing to compute: it tells us the *shape* of the curve (how much N matters) and whether the 5s/draw default pace risks making small-N games dominated by reaction time rather than draw progress, or large-N games take a while regardless.

## Results (executed 2026-09-14)

Median draw count for the first valid win, with (P10-P90) spread in parens, computed exactly via the inclusion-exclusion approach above (54-card deck, out of a possible 54 draws):

| N players | horizontal | vertical | diagonal | four corners | el pozo | **random pattern (avg)** |
|---:|---:|---:|---:|---:|---:|---:|
| 5   | 24 (16-32) | 24 (16-32) | 29 (19-37) | 34 (22-43) | 21 (14-28) | **25 (16-33)** |
| 10  | 21 (14-27) | 21 (14-27) | 25 (16-32) | 29 (19-37) | 18 (12-24) | **21 (14-28)** |
| 25  | 17 (12-22) | 17 (12-22) | 20 (13-26) | 23 (15-31) | 15 (10-19) | **17 (12-23)** |
| 50  | 15 (10-19) | 15 (10-19) | 17 (12-22) | 20 (13-26) | 13 (9-16)  | **15 (10-19)** |
| 100 | 13 (9-16)  | 13 (9-16)  | 15 (10-19) | 17 (12-22) | 11 (8-14)  | **13 (9-17)** |

(Horizontal and vertical are identical, as expected -- both are 4 disjoint groups of 4, just a different grouping of the same 16 cells, so they have the same combinatorial structure.)

Takeaways:
- **Pattern difficulty spread is bigger than player-count effect at the extremes**: at N=5, the easiest pattern (El Pozo, 21 draws) and hardest (four corners, 34 draws) differ by more than the entire N=5-to-N=100 range for any single pattern. Which pattern gets picked matters more than how many people showed up.
- **Diminishing returns from more players**: going from 5 to 100 players only pulls the average-case median in from 25 to 13 draws -- roughly halves, not divides by 20, because winning is still gated by the shared draw order, not by player count directly (more tablas = more independent shots at the same shrinking pool of "already drawn" cards).
- **At the default 5s/draw pace**, a typical (random-pattern) round resolves in about 25 draws x 5s ≈ **2 minutes** at N=5, down to about 13 draws x 5s ≈ **1 minute** at N=100. Four Corners rounds specifically run about 30-45% longer than the average.

