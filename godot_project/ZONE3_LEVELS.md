# Zone 3 Levels

Zone 3 is the `LAA + IMA` two-slot peak before Zone 4 resets local complexity with a new ability.

Shared rule frame:
- Slots: `2`
- Allowed skill types: `LAA`, `IMA`
- Kill recovery: `false`

## 3-1 Jump

Goal:
- Introduce two-slot half-start play.
- Start both slots with their first half, then complete and release them one by one.

Resources:
- `2M / 2A`

Map:
```text
...E
....
E...
@E..
```

Target pattern:
- Dual half-start, then complete each slot and cast immediately.

## 3-2 Hop

Goal:
- Harder `Jump`.
- Keep the same dual half-start pattern, but add one extra target so the two follow-up routes are no longer symmetric.
- Force earlier commitment without changing the underlying slot grammar.

Resources:
- `2M / 2A`

Map:
```text
...E
.E..
E...
@E..
```

Target pattern:
- Dual half-start, then complete each slot and cast immediately.

## 3-3 Cut in

Goal:
- First clean two-slot release-order lesson.
- Teach the canonical `S1 -> S2 -> R1 -> R2` pattern.

Resources:
- `1M / 3A`

Map:
```text
@EE
.E.
EE.
.E.
```

Target pattern:
- Standard `S1 S2 R1 R2`.

## 3-4 Crowded

Goal:
- First reverse-release lesson on a dense board.
- Teach `S1 -> S2 -> R2 -> R1` under tighter target spacing.

Resources:
- `1M / 3A`

Map:
```text
EE.
EEE
@E.
```

Target pattern:
- Reverse release: `S1 S2 R2 R1`.

## 3-5 Hold

Goal:
- Reinforce `S1 -> S2 -> R2 -> R1`.
- Add opening misdirection so the player must recognize the reverse-release structure rather than follow the most obvious first action.

Resources:
- `1M / 3A`

Map:
```text
E.E
EE@
..E
```

Target pattern:
- Reverse release with misdirection.

## 3-6 Reserve

Goal:
- Introduce reserve-half-slot play.
- Finish one skill, bank the front half of the next skill, then complete it after releasing the first one.

Resources:
- `1M / 3A`

Map:
```text
.E.
@E.
.EE
.E.
```

Target pattern:
- `S1`, then build a half-slot, `R1`, then complete `S2`.

## 3-7 Weave

Goal:
- Mix the earlier two-slot grammars together.
- Combine half-slot management, completion order, and release order into a higher-freedom end-of-zone problem.

Resources:
- `2M / 3A`

Map:
```text
.E.E
...E
E.@E
```

Target pattern:
- Mixed two-slot sequencing.
