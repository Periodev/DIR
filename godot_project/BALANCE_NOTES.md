# Balance Notes

## EXE Skill Loop Test Matrix

Use this table to record manual test runs. The goal is to see whether the four EXE skill shapes are complementary, or whether one loop becomes dominant.

| Skill | Pattern | Synthesis Difficulty | Synthesis Ratio | Avg Kills | Avg Recovery | Recovery Ratio | Common Opener | Common Finisher | Chains Into Next Skill |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 貫穿 | Same AA |  |  |  |  |  |  |  |  |
| 衝撞 | Same MA |  |  |  |  |  |  |  |  |
| 旋擊 | Orthogonal MA |  |  |  |  |  |  |  |  |
| 雙擊 | Orthogonal AA |  |  |  |  |  |  |  |  |

### Field Guide

| Field | What To Track |
| --- | --- |
| Synthesis Difficulty | How hard it is to assemble the required vectors under pressure. |
| Synthesis Ratio | How often this skill is synthesized among all completed EXE skills. |
| Avg Kills | Average enemies killed by one cast. |
| Avg Recovery | Average vectors recovered by one cast. |
| Recovery Ratio | Recovered vectors divided by vectors spent on this skill. Since each cast spends 2 vectors, use `Avg Recovery / 2`. |
| Common Opener | Whether the skill is often used to start a turn or break into a cluster. |
| Common Finisher | Whether the skill is often used after movement/setup to close a turn. |
| Chains Into Next Skill | Whether the recovery and final position commonly enable another skill immediately or next turn. |

### Notes

- Track normal 4-slot mode first. Use 8-slot debug only to inspect ceiling behavior.
- If one skill has high kills, high recovery, and frequent chaining, it may be forming a dominant loop.
- If one skill has low kills but high opener or positioning value, it may still be healthy as a utility skill.
- 旋擊 does not separate left/right in this table; combine both orthogonal MA directions into one row.
