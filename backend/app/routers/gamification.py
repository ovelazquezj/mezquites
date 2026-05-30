"""Rankings (Q4 E3/C2) — por periodo, individual + por institución, filtrable por estado (Q8).

Gate #3: ningún ranking gatea funcionalidad; es puramente informativo.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import CurrentUser, get_current_user
from ..gamification import rankings as compute_rankings
from ..schemas import RankingsResponse

router = APIRouter(prefix="/gamification", tags=["gamification"])


@router.get("/rankings", response_model=RankingsResponse)
def get_rankings(
    period: str = Query("all", pattern="^(all|month|quarter|year)$"),
    estado: str | None = Query(None),
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> RankingsResponse:
    data = compute_rankings(db, period=period, estado=estado)
    return RankingsResponse(**data)
