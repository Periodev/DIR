# Zone 5 Blind-Test Notes

These notes capture the first blind-test pass over the generated Zone 5
candidate boards. They are design notes, not final level documentation.

## Current Test Batch

The active Zone 5 test batch in `scripts/LevelConstants_Zone5.gd` has been
reordered into a main-line draft. The first two boards are free-convergence
openers, and the first four boards are lower-pressure
`3M / 3A` candidates from the usable pool. The later boards switch back to
`2M / 3A` and ramp by difficulty. One `LAA / IMA`-only candidate was moved to
Zone 3 as `3-8`, but `Stair` remains here as a hinted opening
with more choice in the lower half. `5-9` adds a strong `Angle First` test. All nine
Zone 5 boards use 2 slots and
unlock `LAA`, `IMA`, and `LMA`.

```text
5-1 3M/3A
E...
..EE
E...
..@E

5-2 Topdown 3M/3A
E..@
.EE.
....
.EE.

5-3 Ring 3M/3A
.EE@
E...
E...
...E

5-4 Junction 2M/3A
@E.
.E.
..E
EE.

5-5 Stair 2M/3A
E.E.
.EE.
..E@

5-6 Line Up 2M/3A
E...
.E.E
@.E.
...E

5-7 Ridge 2M/3A
.EE
...
E.E
@.E

5-8 Bottom Up 2M/3A
.EE.
....
E...
.EE@

5-9 Loaded 2M/3A
..EE
.E.E
.@..
.EE.
```

## Current Solver Verification

- `5-1`: total solutions found `20+`.
- `5-2`: total solutions found `20+`.
- `5-3`: total solutions found `8`.
- `5-4`: total solutions found `19`.
- `5-5`: total solutions found `11`.
- `5-6`: total solutions found `1`.
- `5-7`: total solutions found `4`.
- `5-8`: total solutions found `1`.
- `5-9`: total solutions found `1`.

## Current Difficulty Order

- `5-1` and `5-2`: free-convergence openers; multiple routes can collapse into
  similar end-state structures.
- `5-3`: `Ring`; an orbit-style pursuit board where clockwise and
  counterclockwise routes can both work.
- `5-4`: `Junction`; highest-freedom `2M / 3A` bridge between the free opener
  set and the higher-pressure later puzzles.
- `5-5`: `Stair`; hinted opening followed by a stair-step climb from the
  lower-right toward the upper-left cluster.
- `5-6`: `Line Up`; place the player so `IMA-R` and `LMA-R/U` both line up
  with their targets.
- `5-7`: `Ridge`; an opening-branch mixed read along a diagonal ridge.
- `5-8`: `Bottom Up`; bottom-side counterpart to `Topdown`, compressed into a
  unique route.
- `5-9`: `Loaded`; build and hold material until the final paired release.

## 5-9 Loaded

Unique solution:

```text
AD | MR | AD | S1 | MU | AR | R2(LAA-U/L) | R1(LMA-U/R)
```

The difficulty comes from delayed release timing rather than detouring. The
first material is built early but cannot be released immediately. The next
material is collected after repositioning, and the final paired release clears
the board only after the path has been loaded correctly.

## Rejected 2M4A Batch

- Rejected reason: requiring one route to cast `LAA`, `IMA`, and `LMA` forces
  `2M / 4A`, which breaks the intended Zone 5 resource rhythm.
- Generated files are retained for reference:
  `tools/generated_z5_all_three_skills.txt` and
  `tools/generated_z5_all_three_skills.tsv`.

## 2M3A Blind Pass Notes

### 5-1 Blind 01

- Difficulty: mid-low.
- Has a misleading all-`IMA` read.
- Keep as an early ambiguity check rather than a hard puzzle.

### 5-2 Blind 02

- Difficulty: upper-middle.
- Requires routing around the board.
- Keep as a stronger mid-Zone 5 candidate.

### 5-3 Blind 03

- Difficulty: high.
- Strong misdirection.
- A wrong first step can still reach a late failing position, which makes the
  trap expensive.
- Keep only if Zone 5 needs a high-friction blind-test spike.

### 5-4 Blind 04

- Difficulty: mid-low.
- Useful as a lighter mixed-skill read.

### 5-5 Blind 05

- Invalid in the corrected solver.
- The earlier solver allowed `LMA` to rotate across LEFT_MA / RIGHT_MA
  handedness, which produced an impossible route.
- Remove or replace this board before using the batch as authored content.

### 5-6 Blind 06

- Can be solved with `1M / 3A`.
- Structure is close to an existing Zone 3 pattern.
- Reject or redesign for Zone 5 unless the map is changed to force a clearer
  three-skill mixed read.

### 5-7 Blind 07

- Difficulty: medium.
- Has a misleading all-`IMA` read.
- Keep as a better version of 5-1's ambiguity, likely after the easier reads.

### 5-8 Blind 08

- Difficulty: mid-low.
- Backup or filler; not currently a strong Zone 5 teaching point.

### 5-9 Blind 09

- Difficulty: mid-low.
- Similar role to 5-10 but less friendly.

### 5-10 Blind 10

- Difficulty: mid-low.
- Isomorphic to 5-9, but the flow is more predictable and player-friendly.
- Prefer over 5-9 if only one of the two remains.

## Previous Test Batch

The notes below are from the previous generated batch. They are kept as
calibration history and no longer match the active Zone 5 level file.

## Candidate Notes

### 5-1 Blind 01

```text
.EE@
E...
E...
...E
```

- Keep.
- Main read: preserve two `LMA` casts to chase the lower-right target.
- Good Zone 5 opening candidate because full skill access still leaves `LMA`
  with clear value.

### 5-2 Blind 02

```text
E...
@E..
.E..
.E.E
```

- High difficulty.
- Requires precise `IMA` usage.
- Better as a later Zone 5 candidate, not an opener.

### 5-3 Blind 03

```text
E.E@
E.E.
....
E...
```

- Reject or move out of the Zone 5 main line.
- Feels too close to Zone 3 behavior rather than a Zone 5 mixed-skill lesson.

### 5-4 Blind 04

```text
.E@.
....
..EE
E.E.
```

- Too open at `3M / 3A`.
- Solvable through `LMA + IMA`, `LAA + IMA`, or `LAA + LMA`.
- Possible cause: too many moves.
- Needs resource reduction or map adjustment if kept as a teaching puzzle.

### 5-5 Blind 05

```text
...E
..E.
@E.E
...E
```

- Backup candidate.
- First move is obvious.
- Later play converges toward `LAA`.

### 5-6 Blind 06

```text
E..@
.EE.
....
.EE.
```

- Keep candidate.
- Can be solved entirely with `LMA`.
- Also has a non-obvious `LMA + IMA` route.
- Good fit for the idea that full unlocks can increase ambiguity.

### 5-7 Blind 07

```text
.@EE
..E.
.E..
E...
```

- Keep.
- `IMA + LAA` structure, but requires interleaving `M`.
- Difficulty: upper-middle.

### 5-8 Blind 08

```text
..EE
..E.
.E.E
...@
```

- Lower priority.
- Mostly `IMA` or `IMA + LAA`.
- Feels ordinary compared with stronger candidates.

### 5-9 Blind 09

```text
E.E.
.@E.
...E
..E.
```

- Add candidate.
- Found two routes, both tricky.
- Good mid-late Zone 5 puzzle.

### 5-10 Blind 10

```text
E...
..EE
E...
..@E
```

- Backup / early-mid candidate.
- `LMA only` can solve with `2M / 3A`.
- Full access allows `IMA` only or `LMA + LAA`.
- Difficulty: mid-low.

## Difficulty Calibration

- If the designer sees the main line within 30 seconds, players may still find
  it medium difficulty.
- If the designer needs to try a few branches, treat it as high difficulty for
  normal players.
- If the designer cannot find the main line without backtracking, it is likely
  late-game or optional unless the solution is especially elegant.
- If the solution feels arbitrary after solving, it should not be in the main
  line.

## Current Triage

- Early / mid-low: `5-1`, `5-4`, `5-10`
- Mid: `5-7`
- Upper-middle: `5-2`
- High / late spike: `5-3`
- Backup / filler: `5-8`, `5-9`
- Reject or redesign: `5-5`, `5-6`
