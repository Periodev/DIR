#!/usr/bin/env python3
"""
State-space solver for the current EXE ASCII tutorial levels.

Scope:
- Loads levels from scripts/LevelConstants_Zone*.gd by level code, e.g. 3-6.
- Simulates the current A/M/S/R slot rules used by the authored tutorial levels.
- Supports basic move, basic attack, manual synthesis, and skill release.
- Prints a small batch of valid solution sequences.

This is intentionally scoped to the current authored tutorial content:
- no end-turn action
- no pollution spread / spawn simulation
- no shield handling

Usage:
  python tools/solve_ascii_level.py 3-6
  python tools/solve_ascii_level.py 3-6 --limit 10 --max-steps 14
  python tools/solve_ascii_level.py 3-6 --output D:\\DIR_02\\godot_project\\tools\\my_3-6.txt
"""

from __future__ import annotations

import argparse
import re
from collections import deque
from dataclasses import dataclass
from pathlib import Path


UP = "U"
RIGHT = "R"
DOWN = "D"
LEFT = "L"
DIRS = (UP, RIGHT, DOWN, LEFT)
DIR_VECTOR = {
    UP: (0, -1),
    RIGHT: (1, 0),
    DOWN: (0, 1),
    LEFT: (-1, 0),
}
OPPOSITE = {
    UP: DOWN,
    RIGHT: LEFT,
    DOWN: UP,
    LEFT: RIGHT,
}

MOVE = "M"
ATTACK = "A"


@dataclass(frozen=True)
class Level:
    code: str
    title: str
    zone: int
    index: int
    move_limit: int
    attack_limit: int
    unlocked_slot_count: int
    allowed_skill_types: frozenset[str]
    kill_recovery_enabled: bool
    width: int
    height: int
    player_start: tuple[int, int]
    enemies: frozenset[tuple[int, int]]


@dataclass(frozen=True)
class State:
    pos: tuple[int, int]
    enemies: frozenset[tuple[int, int]]
    moves_used: int
    attacks_used: int
    slots: tuple[tuple[tuple[str, str], ...], ...]
    pending_tokens: tuple[tuple[str, str], ...]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Solve current EXE ASCII tutorial levels.")
    parser.add_argument("level_code", nargs="?", help="Level code like 1-9 or 3-6")
    parser.add_argument("--limit", type=int, default=10, help="Maximum number of solutions to print")
    parser.add_argument("--max-steps", type=int, default=14, help="Maximum action count to search")
    parser.add_argument("--all", action="store_true", help="Solve all authored ASCII tutorial levels")
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Path to godot_project root",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Optional explicit output txt path. Default writes to tools/solver_outputs/solve_<level>.txt",
    )
    return parser.parse_args()


def load_level(root: Path, level_code: str) -> Level:
    for level in load_all_levels(root):
        if level.code == level_code:
            return level
    scripts_dir = root / "scripts"
    raise SystemExit(f"Level code {level_code!r} not found under {scripts_dir}")


def load_all_levels(root: Path) -> list[Level]:
    levels: list[Level] = []
    scripts_dir = root / "scripts"
    for path in sorted(scripts_dir.glob("LevelConstants_Zone*.gd")):
        text = path.read_text(encoding="utf-8")
        for block in iter_level_blocks(text):
            levels.append(build_level(parse_level_block(block)))
    return sorted(levels, key=lambda level: (level.zone, level.index))


def iter_level_blocks(text: str) -> list[str]:
    blocks: list[str] = []
    depth = 0
    start = -1
    for index, char in enumerate(text):
        if char == "{":
            if depth == 0:
                start = index
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0 and start >= 0:
                blocks.append(text[start : index + 1])
                start = -1
    return blocks


def parse_level_block(block: str) -> dict[str, object]:
    result: dict[str, object] = {}
    string_fields = ("code", "title", "object_map", "direction_map")
    int_fields = ("zone", "index", "move_limit", "attack_limit", "unlocked_slot_count")
    bool_fields = ("kill_recovery_enabled",)

    for field in string_fields:
        triple_pattern = rf'"{field}"\s*:\s*"""(.*?)"""'
        single_pattern = rf'"{field}"\s*:\s*"([^"]*)"'
        match = re.search(triple_pattern, block, re.S)
        if match:
            result[field] = match.group(1)
            continue
        match = re.search(single_pattern, block)
        if match:
            result[field] = match.group(1)

    for field in int_fields:
        match = re.search(rf'"{field}"\s*:\s*(-?\d+)', block)
        if match:
            result[field] = int(match.group(1))

    for field in bool_fields:
        match = re.search(rf'"{field}"\s*:\s*(true|false)', block)
        if match:
            result[field] = match.group(1) == "true"

    allowed_match = re.search(r'"allowed_skill_types"\s*:\s*\[(.*?)\]', block, re.S)
    if allowed_match:
        result["allowed_skill_types"] = re.findall(r'"([^"]+)"', allowed_match.group(1))

    return result


def build_level(raw: dict[str, object]) -> Level:
    object_map = normalize_lines(str(raw["object_map"]))
    if not object_map:
        raise SystemExit(f"Level {raw['code']} has empty object_map")

    width = len(object_map[0])
    for row in object_map:
        if len(row) != width:
            raise SystemExit(f"Level {raw['code']} has non-rectangular object_map")

    player_start: tuple[int, int] | None = None
    enemies: set[tuple[int, int]] = set()
    for y, row in enumerate(object_map):
        for x, cell in enumerate(row):
            if cell == "@":
                if player_start is not None:
                    raise SystemExit(f"Level {raw['code']} has multiple player starts")
                player_start = (x, y)
            elif cell == "E":
                enemies.add((x, y))
            elif cell not in (".", " "):
                raise SystemExit(f"Unsupported cell {cell!r} in level {raw['code']}")

    if player_start is None:
        raise SystemExit(f"Level {raw['code']} does not contain @")

    return Level(
        code=str(raw["code"]),
        title=str(raw.get("title", "")),
        zone=int(raw.get("zone", 1)),
        index=int(raw.get("index", 1)),
        move_limit=int(raw.get("move_limit", 0)),
        attack_limit=int(raw.get("attack_limit", 0)),
        unlocked_slot_count=int(raw.get("unlocked_slot_count", 1)),
        allowed_skill_types=frozenset(str(name).upper() for name in raw.get("allowed_skill_types", [])),
        kill_recovery_enabled=bool(raw.get("kill_recovery_enabled", False)),
        width=width,
        height=len(object_map),
        player_start=player_start,
        enemies=frozenset(enemies),
    )


def normalize_lines(text: str) -> list[str]:
    stripped = text.strip()
    if not stripped:
        return []
    return [line.strip() for line in stripped.splitlines()]


def auto_store_pending(level: Level, state: State) -> State:
    if not state.pending_tokens:
        return state

    slots = [list(slot) for slot in state.slots]
    tokens = list(state.pending_tokens)
    consumed = try_store_token_order(level, slots, tokens)
    if not consumed and len(tokens) == 2:
        alt_slots = [list(slot) for slot in state.slots]
        alt_tokens = [tokens[1], tokens[0]]
        consumed = try_store_token_order(level, alt_slots, alt_tokens)
        if consumed:
            slots = alt_slots

    if not consumed:
        return state

    remaining = list(state.pending_tokens)
    for token in consumed:
        remaining.remove(token)

    return State(
        pos=state.pos,
        enemies=state.enemies,
        moves_used=state.moves_used,
        attacks_used=state.attacks_used,
        slots=tuple(tuple(slot) for slot in slots),
        pending_tokens=tuple(remaining),
    )


def try_store_token_order(
    level: Level,
    slots: list[list[tuple[str, str]]],
    tokens: list[tuple[str, str]],
) -> list[tuple[str, str]]:
    consumed: list[tuple[str, str]] = []
    for token in tokens:
        if store_token_default(level, slots, token):
            consumed.append(token)
    return consumed


def store_token_default(
    level: Level,
    slots: list[list[tuple[str, str]]],
    token: tuple[str, str],
) -> bool:
    if token[0] != ATTACK:
        return False

    for slot in slots:
        if not slot:
            slot.append(token)
            return True

    for slot in reversed(slots):
        if len(slot) == 1 and can_compose(slot[0], token):
            if not skill_type_allowed(level, classify_slot((slot[0], token))):
                continue
            slot.append(token)
            return True

    return False


def can_compose(first_token: tuple[str, str], second_token: tuple[str, str]) -> bool:
    if first_token[0] != ATTACK:
        return False
    if OPPOSITE[first_token[1]] == second_token[1]:
        return False
    return second_token[0] in (MOVE, ATTACK)


def classify_slot(slot: tuple[tuple[str, str], ...]) -> str:
    first, second = slot
    if second[0] == MOVE:
        return "IMA" if first[1] == second[1] else "LMA"
    return "IAA" if first[1] == second[1] else "LAA"


def skill_type_allowed(level: Level, skill_type: str) -> bool:
    if not level.allowed_skill_types:
        return True
    return skill_type in level.allowed_skill_types


def release_variants(skill_type: str, slot: tuple[tuple[str, str], ...]) -> list[tuple[str, ...]]:
    if skill_type in ("IMA", "IAA"):
        return [(direction,) for direction in DIRS]
    if skill_type == "LAA":
        return [
            (first, second)
            for first in DIRS
            for second in DIRS
            if first != second and is_orthogonal(first, second)
        ]
    if skill_type == "LMA":
        return lma_release_variants(slot)
    return []


def is_orthogonal(first: str, second: str) -> bool:
    dx0, dy0 = DIR_VECTOR[first]
    dx1, dy1 = DIR_VECTOR[second]
    return dx0 * dx1 + dy0 * dy1 == 0


def lma_release_variants(slot: tuple[tuple[str, str], ...]) -> list[tuple[str, str]]:
    attack_token, move_token = slot
    original_attack = attack_token[1]
    original_move = move_token[1]
    move_dx, move_dy = DIR_VECTOR[original_move]
    attack_dx, attack_dy = DIR_VECTOR[original_attack]
    is_left_ma = (attack_dx, attack_dy) == (move_dy, -move_dx)

    variants: list[tuple[str, str]] = []
    for move_dir in DIRS:
        dx, dy = DIR_VECTOR[move_dir]
        attack_vector = (dy, -dx) if is_left_ma else (-dy, dx)
        for attack_dir, vector in DIR_VECTOR.items():
            if vector == attack_vector:
                variants.append((move_dir, attack_dir))
                break
    return variants


def solve_level(level: Level, max_steps: int, solution_limit: int) -> list[list[str]]:
    start = State(
        pos=level.player_start,
        enemies=level.enemies,
        moves_used=0,
        attacks_used=0,
        slots=tuple(() for _ in range(level.unlocked_slot_count)),
        pending_tokens=(),
    )
    queue: deque[tuple[State, list[str]]] = deque([(start, [])])
    seen: set[State] = {start}
    solutions: list[list[str]] = []

    while queue and len(solutions) < solution_limit:
        state, path = queue.popleft()
        if not state.enemies:
            solutions.append(path)
            continue
        if len(path) >= max_steps:
            continue

        for next_state, action in successors(level, state):
            if next_state in seen:
                continue
            seen.add(next_state)
            queue.append((next_state, path + [action]))

    return solutions


def successors(level: Level, state: State) -> list[tuple[State, str]]:
    result: list[tuple[State, str]] = []
    action_base = auto_store_pending(level, state)

    for direction in DIRS:
        move_state = try_basic_move(level, action_base, direction)
        if move_state is not None:
            result.append((move_state, f"M{direction}"))

    for direction in DIRS:
        attack_state = try_basic_attack(level, action_base, direction)
        if attack_state is not None:
            result.append((attack_state, f"A{direction}"))

    for slot_index in range(level.unlocked_slot_count):
        stored = try_manual_store(level, state, slot_index)
        if stored is not None:
            result.append((stored, f"S{slot_index + 1}"))

    # Runtime rotation auto-stores pending EXE vectors before release. Model
    # releases from action_base so pending attacks can be committed before a
    # cast. Pending moves still require an explicit store into a partial slot.
    for slot_index, slot in enumerate(action_base.slots):
        if len(slot) != 2:
            continue
        skill_type = classify_slot(slot)
        if not skill_type_allowed(level, skill_type):
            continue
        for orientation in release_variants(skill_type, slot):
            released = try_release(level, action_base, slot_index, skill_type, orientation)
            if released is not None:
                action = format_release(slot_index, skill_type, orientation)
                result.append((released, action))

    return result


def try_basic_move(level: Level, state: State, direction: str) -> State | None:
    if state.moves_used >= level.move_limit:
        return None
    target = step(state.pos, direction)
    if not in_bounds(level, target) or target in state.enemies:
        return None

    pending = [token for token in state.pending_tokens if token[0] != MOVE]
    pending.append((MOVE, direction))
    return State(
        pos=target,
        enemies=state.enemies,
        moves_used=state.moves_used + 1,
        attacks_used=state.attacks_used,
        slots=state.slots,
        pending_tokens=tuple(pending),
    )


def try_basic_attack(level: Level, state: State, direction: str) -> State | None:
    if state.attacks_used >= level.attack_limit:
        return None
    target = step(state.pos, direction)
    if target not in state.enemies:
        return None

    enemies = set(state.enemies)
    enemies.remove(target)
    pending = list(state.pending_tokens)
    pending.append((ATTACK, direction))
    return State(
        pos=state.pos,
        enemies=frozenset(enemies),
        moves_used=state.moves_used,
        attacks_used=state.attacks_used + 1,
        slots=state.slots,
        pending_tokens=tuple(pending),
    )


def try_manual_store(level: Level, state: State, slot_index: int) -> State | None:
    token = get_pending_token_for_slot(level, state, slot_index)
    if token is None:
        return None

    slots = [list(slot) for slot in state.slots]
    slots[slot_index].append(token)
    pending = list(state.pending_tokens)
    pending.remove(token)
    return State(
        pos=state.pos,
        enemies=state.enemies,
        moves_used=state.moves_used,
        attacks_used=state.attacks_used,
        slots=tuple(tuple(slot) for slot in slots),
        pending_tokens=tuple(pending),
    )


def get_pending_token_for_slot(level: Level, state: State, slot_index: int) -> tuple[str, str] | None:
    slot = state.slots[slot_index]
    pending_attack = latest_pending_token(state.pending_tokens, ATTACK)
    pending_move = latest_pending_token(state.pending_tokens, MOVE)

    if len(slot) == 1:
        if pending_attack is not None and can_compose(slot[0], pending_attack):
            if skill_type_allowed(level, classify_slot((slot[0], pending_attack))):
                return pending_attack
        if pending_move is not None and can_compose(slot[0], pending_move):
            if skill_type_allowed(level, classify_slot((slot[0], pending_move))):
                return pending_move
        return None

    if len(slot) == 0:
        return pending_attack

    return None


def latest_pending_token(
    pending_tokens: tuple[tuple[str, str], ...],
    kind: str,
) -> tuple[str, str] | None:
    for token in reversed(pending_tokens):
        if token[0] == kind:
            return token
    return None


def try_release(
    level: Level,
    state: State,
    slot_index: int,
    skill_type: str,
    orientation: tuple[str, ...],
) -> State | None:
    pos = state.pos
    enemies = set(state.enemies)
    recovered_dirs: list[str] = []

    def kill_enemy(target: tuple[int, int], attack_dir: str) -> bool:
        if target not in enemies:
            return False
        enemies.remove(target)
        if attack_dir not in recovered_dirs and len(recovered_dirs) < 2:
            recovered_dirs.append(attack_dir)
        return True

    if skill_type == "IMA":
        dash = pos
        direction = orientation[0]
        for _ in range(2):
            next_pos = step(dash, direction)
            if not in_bounds(level, next_pos):
                break
            if kill_enemy(next_pos, direction):
                dash = next_pos
                break
            dash = next_pos
        pos = dash
    elif skill_type == "LMA":
        move_dir, attack_dir = orientation
        move_target = step(pos, move_dir)
        if in_bounds(level, move_target) and move_target not in enemies:
            pos = move_target
            kill_enemy(step(pos, attack_dir), attack_dir)
    elif skill_type == "IAA":
        direction = orientation[0]
        front = step(pos, direction)
        if front not in enemies:
            return None
        kill_enemy(front, direction)
        kill_enemy(step(front, direction), direction)
    elif skill_type == "LAA":
        first_dir, second_dir = orientation
        kill_enemy(step(pos, first_dir), first_dir)
        kill_enemy(step(pos, second_dir), second_dir)
    else:
        return None

    if pos == state.pos and enemies == set(state.enemies):
        return None

    slots = [list(slot) for slot in state.slots]
    slots[slot_index] = []
    pending = list(state.pending_tokens)
    if level.kill_recovery_enabled and recovered_dirs:
        pending.append((ATTACK, recovered_dirs[0]))

    return State(
        pos=pos,
        enemies=frozenset(enemies),
        moves_used=state.moves_used,
        attacks_used=state.attacks_used,
        slots=tuple(tuple(slot) for slot in slots),
        pending_tokens=tuple(pending),
    )


def format_release(slot_index: int, skill_type: str, orientation: tuple[str, ...]) -> str:
    if len(orientation) == 1:
        return f"R{slot_index + 1}({skill_type}-{orientation[0]})"
    return f"R{slot_index + 1}({skill_type}-{orientation[0]}/{orientation[1]})"


def step(pos: tuple[int, int], direction: str) -> tuple[int, int]:
    dx, dy = DIR_VECTOR[direction]
    return (pos[0] + dx, pos[1] + dy)


def in_bounds(level: Level, pos: tuple[int, int]) -> bool:
    x, y = pos
    return 0 <= x < level.width and 0 <= y < level.height


def main() -> None:
    args = parse_args()
    if args.all:
        run_all_levels(args)
        return

    if not args.level_code:
        raise SystemExit("Provide a level code like 3-6, or use --all.")

    level = load_level(args.root, args.level_code)
    output_path, lines = solve_one_level(args.root, level, args.max_steps, args.limit, args.output)

    for line in lines:
        print(line)
    print(f"output file: {output_path}")


def solve_one_level(
    root: Path,
    level: Level,
    max_steps: int,
    solution_limit: int,
    explicit_output: Path | None,
) -> tuple[Path, list[str]]:
    solutions = solve_level(level, max_steps, solution_limit)
    lines = level_report_lines(level, max_steps, solution_limit, solutions)
    output_path = resolve_output_path(root, level.code, explicit_output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return output_path, lines


def level_report_lines(
    level: Level,
    max_steps: int,
    solution_limit: int,
    solutions: list[list[str]],
) -> list[str]:
    lines = [
        f"{level.code} {level.title}",
        (
            f"resources: {level.move_limit}M / {level.attack_limit}A, "
            f"slots: {level.unlocked_slot_count}, recovery: {level.kill_recovery_enabled}"
        ),
        f"search: max_steps={max_steps}, solution_limit={solution_limit}",
    ]

    if not solutions:
        lines.append("No solutions found in current search window.")
    else:
        lines.append(f"solutions found: {len(solutions)}")
        for index, solution in enumerate(solutions, start=1):
            lines.append(f"{index}. {' | '.join(solution)}")
    return lines


def run_all_levels(args: argparse.Namespace) -> None:
    levels = load_all_levels(args.root)
    output_dir = args.root / "tools" / "solver_outputs"
    output_dir.mkdir(parents=True, exist_ok=True)

    level_rows: list[dict[str, object]] = []
    summary_lines = [
        "All ASCII tutorial levels",
        f"search: max_steps={args.max_steps}, solution_limit={args.limit}",
        f"levels: {len(levels)}",
        "",
    ]

    for level in levels:
        output_path, lines = solve_one_level(args.root, level, args.max_steps, args.limit, None)
        solutions_found = extract_solution_count(lines)
        status = "ok" if solutions_found > 0 else "none"
        summary_lines.append(
            f"{level.code} {level.title} | {level.move_limit}M/{level.attack_limit}A | "
            f"slots={level.unlocked_slot_count} | solutions={solutions_found} | {status}"
        )
        representative = first_solution_line(lines)
        level_rows.append(
            {
                "code": level.code,
                "title": level.title,
                "zone": level.zone,
                "resources": f"{level.move_limit}M/{level.attack_limit}A",
                "slots": level.unlocked_slot_count,
                "allowed": ",".join(sorted(level.allowed_skill_types)),
                "solution_count": solutions_found,
                "status": status,
                "representative": representative.removeprefix("1. ").strip() if representative else "",
                "solutions": all_solution_lines(lines),
                "detail_file": str(output_path),
            }
        )
        if representative:
            summary_lines.append(f"  {representative}")
        summary_lines.append(f"  file: {output_path}")

    summary_path = output_dir / "solve_all_levels.txt"
    summary_path.write_text("\n".join(summary_lines) + "\n", encoding="utf-8")
    tsv_path = output_dir / "solve_all_levels.tsv"
    tsv_path.write_text(build_tsv_summary(level_rows) + "\n", encoding="utf-8")
    md_path = output_dir / "solve_all_levels.md"
    md_path.write_text(build_markdown_summary(args.max_steps, args.limit, level_rows) + "\n", encoding="utf-8")

    for line in summary_lines:
        print(line)
    print(f"output file: {summary_path}")
    print(f"output file: {tsv_path}")
    print(f"output file: {md_path}")


def extract_solution_count(lines: list[str]) -> int:
    for line in lines:
        if line.startswith("solutions found: "):
            return int(line.split(": ", 1)[1])
    return 0


def first_solution_line(lines: list[str]) -> str:
    for line in lines:
        if re.match(r"^\d+\.\s", line):
            return line
    return ""


def all_solution_lines(lines: list[str]) -> list[str]:
    result: list[str] = []
    for line in lines:
        if re.match(r"^\d+\.\s", line):
            result.append(re.sub(r"^\d+\.\s*", "", line))
    return result


def build_tsv_summary(level_rows: list[dict[str, object]]) -> str:
    headers = [
        "code",
        "title",
        "zone",
        "resources",
        "slots",
        "allowed",
        "solution_count",
        "status",
        "solution_index",
        "solution",
        "detail_file",
    ]
    lines = ["\t".join(headers)]
    for row in level_rows:
        solutions = row.get("solutions", [])
        if not solutions:
            expanded_row = {
                "code": row.get("code", ""),
                "title": row.get("title", ""),
                "zone": row.get("zone", ""),
                "resources": row.get("resources", ""),
                "slots": row.get("slots", ""),
                "allowed": row.get("allowed", ""),
                "solution_count": row.get("solution_count", 0),
                "status": row.get("status", ""),
                "solution_index": "",
                "solution": "",
                "detail_file": row.get("detail_file", ""),
            }
            values = [sanitize_tsv(expanded_row.get(header, "")) for header in headers]
            lines.append("\t".join(values))
            continue
        for index, solution in enumerate(solutions, start=1):
            expanded_row = {
                "code": row.get("code", ""),
                "title": row.get("title", ""),
                "zone": row.get("zone", ""),
                "resources": row.get("resources", ""),
                "slots": row.get("slots", ""),
                "allowed": row.get("allowed", ""),
                "solution_count": row.get("solution_count", 0),
                "status": row.get("status", ""),
                "solution_index": index,
                "solution": solution,
                "detail_file": row.get("detail_file", ""),
            }
            values = [sanitize_tsv(expanded_row.get(header, "")) for header in headers]
            lines.append("\t".join(values))
    return "\n".join(lines)


def sanitize_tsv(value: object) -> str:
    return str(value).replace("\t", " ").replace("\r", " ").replace("\n", " ")


def build_markdown_summary(max_steps: int, solution_limit: int, level_rows: list[dict[str, object]]) -> str:
    lines = [
        "# All ASCII Tutorial Levels",
        "",
        f"- search: `max_steps={max_steps}`, `solution_limit={solution_limit}`",
        f"- levels: `{len(level_rows)}`",
        "",
        "| Code | Title | Zone | Resources | Slots | Allowed | Solutions | Status | Representative |",
        "| --- | --- | ---: | --- | ---: | --- | ---: | --- | --- |",
    ]
    for row in level_rows:
        lines.append(
            "| {code} | {title} | {zone} | {resources} | {slots} | {allowed} | {solution_count} | {status} | {representative} |".format(
                code=escape_markdown_cell(row["code"]),
                title=escape_markdown_cell(row["title"]),
                zone=row["zone"],
                resources=escape_markdown_cell(row["resources"]),
                slots=row["slots"],
                allowed=escape_markdown_cell(row["allowed"]),
                solution_count=row["solution_count"],
                status=escape_markdown_cell(row["status"]),
                representative=escape_markdown_cell(row["representative"]),
            )
        )
    return "\n".join(lines)


def escape_markdown_cell(value: object) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ").replace("\r", " ")


def resolve_output_path(root: Path, level_code: str, explicit_output: Path | None) -> Path:
    if explicit_output is not None:
        return explicit_output
    safe_code = level_code.replace("/", "-").replace("\\", "-")
    return root / "tools" / "solver_outputs" / f"solve_{safe_code}.txt"


if __name__ == "__main__":
    main()
