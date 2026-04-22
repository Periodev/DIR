# Combat Rules

## Core Loop
- The board is `5x5`; the player starts in the center.
- Direction input attempts a basic attack first. If no adjacent enemy is hit, the same input falls back to a basic move.
- `Enter` ends the turn, stores attack vectors into skill storage, advances the turn, and spawns new enemies.
- `Space` combines a stored vector into a full skill or uses the selected complete skill.

## Characters
- `EXE`: 5 sequence slots, 3 moves, 2 attacks, 4 unified skill slots.
- `RDR`: 9 sequence slots, 2 moves, 1 attack, 3 unified skill slots, teleport-on-kill behavior. MM and MA/AM skills that land grant one free adjacent follow-up attack instead of `+1` attack; MA/AM also grants `+1` move when the landing hit kills.

## Pollution
- Pollution is a persistent terrain layer. It is separate from enemy occupancy and can coexist with enemies.
- Each spawned enemy records its spawn turn.
- If an enemy is still alive after two full end-turn checks, its current tile becomes polluted.
- Pollution is permanent for the rest of the run. Killing the enemy does not clear the tile.
- If a live enemy is pushed to a new tile, its pollution timer moves with it.

## Player Interaction With Pollution
- The player may move onto or remain on polluted tiles.
- Standing on a polluted tile disables basic attacks.
- Standing on a polluted tile also disables skill combination.
- Complete skills may still be used while standing on pollution.

## Extended Loss Condition
- Loss is checked only after `End Turn`.
- The player loses if all three are true:
  1. The player is standing on a polluted tile.
  2. The player has no legal basic move.
  3. Every complete skill is ineffective.

## Legal Move And Effective Skill
- A legal basic move is any orthogonal move whose destination is within bounds and currently empty.
- Only complete skills are considered for the loss check.
- A skill is treated as effective if, after simulating it, at least one of the following is true:
  - the player leaves the polluted tile,
  - the player gains a legal basic move,
  - the skill changes player position,
  - the skill causes a kill.

## Threat Score
- The board computes a heuristic threat score from `0-100`.
- Major contributors:
  - player standing on pollution,
  - player standing on pollution while combine materials are stranded,
  - low number of legal basic moves,
  - no effective complete skills,
  - pollution concentrated in the central `3x3`,
  - large connected pollution chains,
  - polluted chokepoints or pocket structures.
- The most dangerous layouts are central pockets, single-tile throats into polluted zones, cross-lock centers, and long connected pollution lanes.
