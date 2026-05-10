# Zone 4 Template

Zone 4 starts after the Zone 3 two-slot peak.

Design role:
- Introduce a new focus ability and reduce local problem complexity.
- Keep the player carrying over slot literacy from Zone 3, but avoid making the first Zone 4 lessons feel like a third consecutive peak.

## New Focus Skill

- Skill family: `LMA`
- Current working name: `Sidestep Strike`

Comment:
- `Sidestep Strike` is readable and clear enough as a working name.
- It communicates `move first, then hit`.
- The main weakness is tone: `sidestep` sounds slightly defensive, while the actual skill is still an active reposition-attack.
- Keep it as a placeholder unless a stronger active name appears later.

## Zone 4 Rule Frame

Current baseline:
- Slots: start back at `2`
- 4-1 onward uses `LMA` only until the new geometry is stable.
- Kill recovery: `false`

Reason:
- Zone 4 should feel like a reset in local complexity, not `Zone 3 plus one more rule`.
- Keeping two slots preserves the Zone 3 slot literacy while reducing local pressure through simpler `LMA` boards.

## Curriculum Skeleton

## Basic LMA Patterns

These are the early Zone 4 building blocks before adding slot-order pressure.

### 4-1 Sidestep Strike

Define the basic Zone 4 pursuit frame: spend `M` first to enter the next local
center, then use `A` to lock the `LMA` attack side.

```text
E..
E..
.@.
```

Suggested solution:
- `M-up`
- `A-left`
- `S`
- `R-up`

### 4-2 Turn Pursuit

Force a left-hand `LMA`: `M-up` first enters the 9-grid center, `A-left` locks
the attack side, and releasing to the right pursues the upper-right target.

```text
..E
E..
.@.
```

Suggested solution:
- `M-up`
- `A-left`
- `S`
- `R-right`

### 4-3 Corner Pursuit

This flips the collection order: use the adjacent right target to collect
`A-right`, then `M-up` completes a diagonal pursuit toward the upper-left
corner.

```text
E..
...
.@E
```

Suggested solution:
- `A-right`
- `M-up`
- `S`
- `R-up`

### 4-4 Clear

Goal:
- Use the extra attack to clear local space before completing `LMA`.
- Keep the final target tied to the same 9-grid pursuit model.

```text
..E
.E.
E@.
```

Suggested solution:
- `A-left`
- `A-up`
- `M-up`
- `S`
- `R-right`

### 4-5 Return

Goal:
- Use the extra move as a return-to-center step.
- Teach that not every `M` is only LMA material; one move can reposition before release.

```text
..E
.@.
E..
```

Suggested solution:
- `M-up`
- `A-right`
- `M-down`
- `S`
- `R-down`

Note:
- This shape intentionally has multiple equivalent routes under `2M / 1A`.
- The lesson is not uniqueness; it is recognizing that the extra move can restore the release center.

### 4-6 Landing

Goal:
- Introduce LMA as movement utility.
- The LMA hit still matters, but the important lesson is the final standing position enabling a basic attack.

```text
.E.
...
E..
.@.
```

Suggested solution:
- `M-up`
- `A-left`
- `S`
- `R-up`
- `A-up`

### 4-7 Arc

Goal:
- Preview the first half of the later spiral pattern.
- Use one `LMA` arc to reposition, then spend the extra attack as a follow-up hit.

```text
.E.
..@
E..
.E.
```

Suggested solution:
- `M-left`
- `A-up`
- `S`
- `R-down`
- `A-down`

### 4-8 Spiral

Goal:
- Chain two `LMA` casts in sequence.
- This is still one-slot play: synthesize, release, then synthesize and release again.

```text
.E..
...E
E.@.
..E.
```

Suggested solution:
- `M-up`
- `A-right`
- `S`
- `M-left`
- `A-up`
- `R-down`
- `S`
- `R-right`

### 4-9 Zig

Goal:
- Introduce a compressed cross-start review with old skills available.
- The opening reads as alternating move/attack directions instead of same-axis material collection.

```text
EE.
EE.
..@
```

Suggested solution:
- `M-up`
- `A-left`
- `M-left`
- `A-up`
- `S`
- `R-right`
- `S`
- `R-down`

Note:
- With `LMA` only this is a double-LMA compression.
- With `LAA`, `IMA`, and `LMA` open, one solution naturally becomes `LMA` cut-in plus `IMA` line cleanup.

### 4-10 Miss

Goal:
- Teach that an `LMA` can intentionally miss while still preserving value through its movement.
- The top-right pair is an intentional decoy: the useful play is to avoid greedily taking the nearest visible target and instead preserve the next center and material for the second cast.

```text
..EE
....
E...
.@..
```

Suggested solution:
- `M-up`
- `A-left`
- `S`
- `R-right`
- `M-right`
- `A-up`
- `S`
- `R-right`

Later variants can use a fixed-handed `LMA` cycle to sweep diagonal corner
targets around a center point.

### Later: Comparison With IMA

Goal:
- Contrast `LMA` with `IMA`.
- One is linear entry; one is lateral entry.

Suggested frame:
- `allowed_skill_types`: `["LAA", "IMA", "LMA"]`
- Still prefer one-slot structure if possible.

### Later: First Mixed Application

Goal:
- Require the player to identify when `LMA` is the correct tool instead of `IMA`.
- This should be the first real Zone 4 exam-style application.

Suggested frame:
- More targets, but still avoid Zone 3-style slot complexity.

## Level Template

Use this dictionary shape when authoring concrete levels:

```gdscript
{
	"zone": 4,
	"index": 1,
	"code": "4-1",
	"title": "Sidestep Strike",
	"object_map": """
...
.@.
...
""",
	"direction_map": "",
	"move_limit": 1,
	"attack_limit": 1,
	"unlocked_slot_count": 2,
	"kill_recovery_enabled": false,
	"allowed_skill_types": ["LAA", "IMA", "LMA"],
}
```
