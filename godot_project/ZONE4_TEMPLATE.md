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
- Slots: start back at `1`
- 4-1 onward uses `LMA` only until the new geometry is stable.
- Kill recovery: `false`

Reason:
- Zone 4 should feel like a reset in local complexity, not `Zone 3 plus one more rule`.
- Reintroducing one-slot structure lets the new skill be understood for its own shape before being recombined with two-slot timing problems again.

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

### 4-4 Exam

Goal:
- Mix same-direction pursuit, left-hand `LMA`, and right-hand `LMA`.
- Keep `1M / 1A` unless the exam needs an extra target to prevent a shortcut.
- Avoid targets that can be solved by a straight `IMA` line unless the contrast is intentional.

Status:
- Map not fixed yet.

Later variants can use a fixed-handed `LMA` cycle to sweep diagonal corner
targets around a center point.

### 4-5 Comparison With IMA

Goal:
- Contrast `LMA` with `IMA`.
- One is linear entry; one is lateral entry.

Suggested frame:
- `allowed_skill_types`: `["LAA", "IMA", "LMA"]`
- Still prefer one-slot structure if possible.

### 4-6 First Mixed Application

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
	"unlocked_slot_count": 1,
	"kill_recovery_enabled": false,
	"allowed_skill_types": ["LAA", "IMA", "LMA"],
}
```
