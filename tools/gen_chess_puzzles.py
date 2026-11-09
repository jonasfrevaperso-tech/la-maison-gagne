"""Génère les positions des Échecs éclair (mat en un coup, trait aux Blancs) dans
data/throw/throw_trials.json (entrée « chess », champ « puzzles »).

Critères : position légale, Noirs pas en échec, un seul coup qui mate, ce coup n'est ni une
promotion ni un roque, aucun droit de roque ni prise en passant (le moteur du jeu les ignore).
Trois paliers selon le nombre de pièces et de coups légaux (plus de leurres = plus dur).
Graine fixe : le fichier produit est reproductible.

    uv run --with chess tools/gen_chess_puzzles.py
"""
import json
import random
from pathlib import Path

import chess

ROOT = Path(__file__).resolve().parent.parent
TRIALS = ROOT / "data" / "throw" / "throw_trials.json"
PER_TIER = 14
# (pièces blanches hors roi, pièces noires hors roi, coups légaux minimum)
TIERS = [((2, 2), (0, 1), 8), ((2, 3), (1, 3), 18), ((3, 4), (3, 5), 26)]
WHITE_POOL = "QRRBBNNPPP"
BLACK_POOL = "qrbnpppp"


def _place(board: chess.Board, rng: random.Random, piece: chess.Piece, squares: list) -> bool:
    for _ in range(40):
        sq = rng.choice(squares)
        rank = chess.square_rank(sq)
        if board.piece_at(sq) is not None:
            continue
        if piece.piece_type == chess.PAWN and rank in (0, 7):
            continue
        if piece.piece_type == chess.PAWN and piece.color == chess.WHITE and rank == 6:
            continue  # pas de promotion possible au coup gagnant
        board.set_piece_at(sq, piece)
        return True
    return False


def candidate(rng: random.Random, tier: tuple) -> chess.Board | None:
    (w_min, w_max), (b_min, b_max), _ = tier
    board = chess.Board(None)
    edge = [s for s in chess.SQUARES if chess.square_rank(s) in (6, 7) or chess.square_file(s) in (0, 7)]
    bk = rng.choice([s for s in edge if chess.square_rank(s) >= 5])
    board.set_piece_at(bk, chess.Piece(chess.KING, chess.BLACK))
    wk_squares = [s for s in chess.SQUARES if chess.square_distance(s, bk) >= 2]
    board.set_piece_at(rng.choice(wk_squares), chess.Piece(chess.KING, chess.WHITE))
    near = [s for s in chess.SQUARES if chess.square_distance(s, bk) <= 4]
    for sym in rng.sample(WHITE_POOL, rng.randint(w_min, w_max)):
        _place(board, rng, chess.Piece.from_symbol(sym), list(chess.SQUARES))
    for sym in rng.sample(BLACK_POOL, rng.randint(b_min, b_max)):
        _place(board, rng, chess.Piece.from_symbol(sym), near)
    board.turn = chess.WHITE
    board.castling_rights = chess.BB_EMPTY
    board.ep_square = None
    if not board.is_valid():
        return None
    board.turn = chess.BLACK
    if board.is_check():
        return None
    board.turn = chess.WHITE
    return board


def mates(board: chess.Board) -> list:
    out = []
    for mv in board.legal_moves:
        board.push(mv)
        if board.is_checkmate():
            out.append(mv)
        board.pop()
    return out


def main() -> None:
    rng = random.Random(20251109)
    puzzles = []
    seen = set()
    for t, tier in enumerate(TIERS):
        found = 0
        while found < PER_TIER:
            b = candidate(rng, tier)
            if b is None or b.is_checkmate() or b.is_stalemate():
                continue
            if b.legal_moves.count() < tier[2]:
                continue
            m = mates(b)
            if len(m) != 1 or m[0].promotion is not None or b.is_castling(m[0]):
                continue
            fen = b.board_fen()
            if fen in seen:
                continue
            seen.add(fen)
            puzzles.append({"fen": fen, "tier": t, "solution": m[0].uci()})
            found += 1
    raw = TRIALS.read_text()
    data = json.loads(raw)
    for e in data:
        if e["id"] == "chess":
            e["puzzles"] = puzzles
    indent = 2 if raw.startswith("[\n  {") else 1
    TRIALS.write_text(json.dumps(data, ensure_ascii=False, indent=indent) + "\n")
    print(f"{len(puzzles)} positions écrites")


if __name__ == "__main__":
    main()
