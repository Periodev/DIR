# Zone 5 Usable Candidate Pool

This file records the filtered usable candidates after correcting the `LMA`
solver model to preserve LEFT_MA / RIGHT_MA handedness.

## Summary

- Strict usable pool: 16 boards.
- Stronger main-line pool: about 10-12 boards after excluding filler and low
  Zone 5 value.
- Invalid: current `5-5`.
- Redesign suggested: current `5-6`, because it is solvable and valid but too
  close to a Zone 3 structure.

## Previous Batch Usable

### P1

- Resource: `3M / 3A`
- Status: usable.

```text
.EE@
E...
E...
...E
```

### P2

- Resource: `2M / 3A`
- Status: usable.

```text
E...
@E..
.E..
.E.E
```

### P5

- Resource: `2M / 3A`
- Status: usable backup.

```text
...E
..E.
@E.E
...E
```

### P6

- Resource: `3M / 3A`
- Status: usable.

```text
E..@
.EE.
....
.EE.
```

### P7

- Resource: `3M / 3A`
- Status: usable.

```text
.@EE
..E.
.E..
E...
```

### P8

- Resource: `2M / 3A`
- Status: usable backup.

```text
..EE
..E.
.E.E
...@
```

### P9

- Resource: `2M / 3A`
- Status: usable.

```text
E.E.
.@E.
...E
..E.
```

### P10

- Resource: `3M / 3A`
- Status: usable backup / early-mid.

```text
E...
..EE
E...
..@E
```

## Current 2M3A Batch Usable

### 5-1

- Resource: `2M / 3A`
- Status: usable early / mid-low.
- Note: misleading all-`IMA` read.

```text
EE..
.E..
E..E
.@..
```

### 5-2

- Resource: `2M / 3A`
- Status: usable upper-middle.
- Note: requires routing around the board.

```text
..EE
....
.E.E
.@.E
```

### 5-3

- Resource: `2M / 3A`
- Status: usable high / late spike.
- Note: strong misdirection; wrong first step can still reach a failing
  endgame.

```text
.EE.
....
E...
.EE@
```

### 5-4

- Resource: `2M / 3A`
- Status: usable early / mid-low.

```text
@E..
....
.EE.
.E.E
```

### 5-7

- Resource: `2M / 3A`
- Status: usable medium.
- Note: misleading all-`IMA` read.

```text
E...
E...
...E
EE.@
```

### 5-8

- Resource: `2M / 3A`
- Status: usable backup / filler.

```text
...E
..E.
E..E
@.E.
```

### 5-9

- Resource: `2M / 3A`
- Status: usable backup / filler.
- Note: isomorphic role with `5-10`, but less friendly.

```text
...E
EE..
@E.E
....
```

### 5-10

- Resource: `2M / 3A`
- Status: usable early / mid-low.
- Note: isomorphic to `5-9`, but flow is more predictable and player-friendly.

```text
E...
.E.E
@.E.
...E
```

## Excluded From Usable Pool

### Current 5-5

- Resource: `2M / 3A`
- Status: invalid after corrected solver.

```text
E..E
...@
.E.E
.E..
```

### Current 5-6

- Resource: `2M / 3A`
- Status: valid but redesign suggested.
- Reason: `1M / 3A` solvable and structurally close to a Zone 3 pattern.

```text
E...
@.E.
..EE
E...
```

## Lower Priority Previous Batch

These are valid after the corrected solver, but not currently prioritized for
the Zone 5 main line.

### P3

- Resource: `2M / 3A`
- Status: valid, lower priority.

```text
E.E@
E.E.
....
E...
```

### P4

- Resource: `3M / 3A`
- Status: valid, lower priority.

```text
.E@.
....
..EE
E.E.
```
