#!/usr/bin/env python3
"""
Generate 4x4 ASCII level candidates by enemy count and resource limits.

The generator reuses solve_ascii_level.py for the actual rule simulation, then
prints only boards that have at least one solution under the requested limits.

Examples:
  python tools/generate_ascii_levels.py --enemies 5 --max-moves 3 --max-attacks 3
  python tools/generate_ascii_levels.py --enemies 5 --moves 2 --attacks 3 --limit 50
  python tools/generate_ascii_levels.py --enemies 6 --allowed LAA,IMA,LMA --tsv tools/candidates.tsv
"""

from __future__ import annotations

import argparse
import importlib.util
import random
import sys
from itertools import combinations
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOLVER_PATH = Path(__file__).resolve().with_name("solve_ascii_level.py")


def load_solver():
    spec = importlib.util.spec_from_file_location("dir_level_solver", SOLVER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load solver from {SOLVER_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate solved 4x4 ASCII level candidates.")
    parser.add_argument("--enemies", type=int, required=True, help="Exact number of E cells")
    parser.add_argument("--width", type=int, default=4)
    parser.add_argument("--height", type=int, default=4)
    parser.add_argument("--moves", type=int, default=None, help="Exact move limit")
    parser.add_argument("--attacks", type=int, default=None, help="Exact attack limit")
    parser.add_argument("--max-moves", type=int, default=3)
    parser.add_argument("--max-attacks", type=int, default=3)
    parser.add_argument("--slots", type=int, default=2)
    parser.add_argument("--allowed", default="LAA,IMA,LMA", help="Comma-separated allowed skill names")
    parser.add_argument(
        "--require-skill-types",
        default="",
        help="Comma-separated skill names that must all appear in the same solution",
    )
    parser.add_argument("--limit", type=int, default=100, help="Maximum boards to output")
    parser.add_argument("--solutions", type=int, default=3, help="Solutions to keep per board")
    parser.add_argument("--max-steps", type=int, default=16)
    parser.add_argument("--player", default=None, help="Optional player position as x,y")
    parser.add_argument("--random-sample", action="store_true", help="Sample random boards instead of exhaustive order")
    parser.add_argument("--seed", type=int, default=0, help="Seed for --random-sample")
    parser.add_argument("--attempts", type=int, default=10000, help="Maximum random boards to test")
    parser.add_argument("--min-filled-rows", type=int, default=1, help="Minimum rows containing an enemy")
    parser.add_argument("--min-filled-cols", type=int, default=1, help="Minimum columns containing an enemy")
    parser.add_argument("--max-row-enemies", type=int, default=None, help="Maximum enemies allowed in any one row")
    parser.add_argument("--max-col-enemies", type=int, default=None, help="Maximum enemies allowed in any one column")
    parser.add_argument(
        "--max-player-adjacent-enemies",
        type=int,
        default=None,
        help="Maximum cardinal-adjacent enemies around the player",
    )
    parser.add_argument(
        "--tsv",
        type=Path,
        default=ROOT / "tools" / "generated_level_candidates.tsv",
        help="TSV output path",
    )
    parser.add_argument(
        "--txt",
        type=Path,
        default=ROOT / "tools" / "generated_level_candidates.txt",
        help="Human-readable output path",
    )
    return parser.parse_args()


def parse_allowed(text: str) -> frozenset[str]:
    names = [part.strip().upper() for part in text.split(",") if part.strip()]
    return frozenset(names)


def parse_player(text: str | None, width: int, height: int) -> tuple[int, int] | None:
    if text is None:
        return None
    raw = text.split(",")
    if len(raw) != 2:
        raise SystemExit("--player must be formatted as x,y")
    pos = (int(raw[0]), int(raw[1]))
    if not (0 <= pos[0] < width and 0 <= pos[1] < height):
        raise SystemExit("--player is outside the board")
    return pos


def resource_values(exact: int | None, max_value: int) -> range:
    if exact is not None:
        return range(exact, exact + 1)
    return range(0, max_value + 1)


def cardinal_neighbors(pos: tuple[int, int]) -> set[tuple[int, int]]:
    x, y = pos
    return {(x, y - 1), (x + 1, y), (x, y + 1), (x - 1, y)}


def board_passes_filters(
    width: int,
    height: int,
    player: tuple[int, int],
    enemies: frozenset[tuple[int, int]],
    args: argparse.Namespace,
) -> bool:
    enemy_rows = {y for _, y in enemies}
    enemy_cols = {x for x, _ in enemies}
    if len(enemy_rows) < args.min_filled_rows:
        return False
    if len(enemy_cols) < args.min_filled_cols:
        return False
    if args.max_row_enemies is not None:
        for y in range(height):
            if sum(1 for _, ey in enemies if ey == y) > args.max_row_enemies:
                return False
    if args.max_col_enemies is not None:
        for x in range(width):
            if sum(1 for ex, _ in enemies if ex == x) > args.max_col_enemies:
                return False
    if args.max_player_adjacent_enemies is not None:
        adjacent = cardinal_neighbors(player)
        if sum(1 for enemy in enemies if enemy in adjacent) > args.max_player_adjacent_enemies:
            return False
    return True


def board_text(width: int, height: int, player: tuple[int, int], enemies: set[tuple[int, int]]) -> str:
    lines: list[str] = []
    for y in range(height):
        chars: list[str] = []
        for x in range(width):
            pos = (x, y)
            if pos == player:
                chars.append("@")
            elif pos in enemies:
                chars.append("E")
            else:
                chars.append(".")
        lines.append("".join(chars))
    return "\n".join(lines)


def first_solution_text(solutions: list[list[str]]) -> str:
    if not solutions:
        return ""
    return " | ".join(solutions[0])


def solution_texts(solutions: list[list[str]]) -> str:
	return " || ".join(" | ".join(solution) for solution in solutions)


def solution_rows(solutions: list[list[str]]) -> list[str]:
	return [" | ".join(solution) for solution in solutions]


def solution_skill_types(solution: list[str]) -> frozenset[str]:
    result: set[str] = set()
    for action in solution:
        if "(" not in action or ")" not in action:
            continue
        payload = action.split("(", 1)[1].split(")", 1)[0]
        skill_type = payload.split("-", 1)[0].upper()
        result.add(skill_type)
    return frozenset(result)


def filter_required_solutions(solutions: list[list[str]], required: frozenset[str]) -> list[list[str]]:
    if not required:
        return solutions
    return [solution for solution in solutions if required.issubset(solution_skill_types(solution))]


def main() -> None:
    args = parse_args()
    solver = load_solver()
    allowed = parse_allowed(args.allowed)
    required = parse_allowed(args.require_skill_types)
    fixed_player = parse_player(args.player, args.width, args.height)
    cells = [(x, y) for y in range(args.height) for x in range(args.width)]

    rows: list[dict[str, object]] = []
    seen_boards: set[str] = set()
    if args.random_sample:
        rng = random.Random(args.seed)
        for _ in range(args.attempts):
            player = fixed_player if fixed_player is not None else rng.choice(cells)
            enemy_cells = [cell for cell in cells if cell != player]
            enemies = frozenset(rng.sample(enemy_cells, args.enemies))
            if not board_passes_filters(args.width, args.height, player, enemies, args):
                continue
            if try_add_candidate(args, solver, allowed, required, rows, seen_boards, player, enemies):
                if len(rows) >= args.limit:
                    break
        write_outputs(args.tsv, args.txt, rows)
        return

    for player in ([fixed_player] if fixed_player is not None else cells):
        if player is None:
            continue
        enemy_cells = [cell for cell in cells if cell != player]
        for enemies_tuple in combinations(enemy_cells, args.enemies):
            enemies = frozenset(enemies_tuple)
            if not board_passes_filters(args.width, args.height, player, enemies, args):
                continue
            if try_add_candidate(args, solver, allowed, required, rows, seen_boards, player, enemies):
                if len(rows) >= args.limit:
                    write_outputs(args.tsv, args.txt, rows)
                    return

    write_outputs(args.tsv, args.txt, rows)


def try_add_candidate(
    args: argparse.Namespace,
    solver,
    allowed: frozenset[str],
    required: frozenset[str],
    rows: list[dict[str, object]],
    seen_boards: set[str],
    player: tuple[int, int],
    enemies: frozenset[tuple[int, int]],
) -> bool:
    board = board_text(args.width, args.height, player, set(enemies))
    if board in seen_boards:
        return False
    for moves in resource_values(args.moves, args.max_moves):
        for attacks in resource_values(args.attacks, args.max_attacks):
            if moves == 0 and attacks == 0:
                continue
            level = solver.Level(
                code="generated",
                title="generated",
                zone=0,
                index=0,
                move_limit=moves,
                attack_limit=attacks,
                unlocked_slot_count=args.slots,
                allowed_skill_types=allowed,
                kill_recovery_enabled=False,
                width=args.width,
                height=args.height,
                player_start=player,
                enemies=enemies,
            )
            solutions = solver.solve_level(level, args.max_steps, args.solutions)
            solutions = filter_required_solutions(solutions, required)
            if not solutions:
                continue
            rows.append(
                {
                    "board": board,
                    "moves": moves,
                    "attacks": attacks,
                    "slots": args.slots,
                    "allowed": ",".join(sorted(allowed)),
                    "solution_count": len(solutions),
                    "first_solution": first_solution_text(solutions),
                    "solution_rows": solution_rows(solutions),
                    "solutions": solution_texts(solutions),
                }
            )
            seen_boards.add(board)
            return True
    return False


def write_outputs(tsv_path: Path, txt_path: Path, rows: list[dict[str, object]]) -> None:
    tsv_path.parent.mkdir(parents=True, exist_ok=True)
    txt_path.parent.mkdir(parents=True, exist_ok=True)

    headers = ["index", "solution_index", "moves", "attacks", "slots", "allowed", "solution_count", "board", "solution"]
    tsv_lines = ["\t".join(headers)]
    txt_lines = [f"generated candidates: {len(rows)}", ""]

    for index, row in enumerate(rows, start=1):
        for solution_index, solution in enumerate(row["solution_rows"], start=1):
            tsv_lines.append(
                "\t".join(
                    [
                        str(index),
                        str(solution_index),
                        str(row["moves"]),
                        str(row["attacks"]),
                        str(row["slots"]),
                        str(row["allowed"]),
                        str(row["solution_count"]),
                        str(row["board"]).replace("\n", "\\n"),
                        str(solution),
                    ]
                )
            )
        txt_lines.extend(
            [
                f"#{index} {row['moves']}M/{row['attacks']}A slots={row['slots']} allowed={row['allowed']}",
                str(row["board"]),
                f"first: {row['first_solution']}",
                f"solutions: {row['solutions']}",
                "",
            ]
        )

    tsv_path.write_text("\n".join(tsv_lines) + "\n", encoding="utf-8")
    txt_path.write_text("\n".join(txt_lines) + "\n", encoding="utf-8")
    print(f"candidates: {len(rows)}")
    print(f"tsv: {tsv_path}")
    print(f"txt: {txt_path}")


if __name__ == "__main__":
    main()
