"""
FadeMem-inspired importance scorer for ABMS Phase 3.

Scores memory results and corrections by importance, combining:
  - Semantic relevance to the current action
  - Access frequency (saturating — high access doesn't dominate)
  - Recency (exponential decay, half-life ~14 days)

Corrections receive a 1.5x salience boost over general memories.

Based on: "FadeMem: Biologically-Inspired Forgetting for Efficient Agent Memory"
(arxiv 2601.18642, January 2026)

Usage:
    from fademem_scorer import score_and_rank

    results = mempalace_search(query)
    ranked = score_and_rank(results, budget=5)
"""

import math
from datetime import datetime, timezone
from typing import Any


# Tunable weights — these determine the balance between
# relevance, frequency, and recency in the importance score
ALPHA = 0.5   # semantic relevance weight
BETA = 0.3    # access frequency weight
GAMMA = 0.2   # recency weight

# Decay constant for recency (0.05 ≈ 14-day half-life)
DECAY_RATE = 0.05

# Corrections get a salience boost
CORRECTION_BOOST = 1.5

# Importance thresholds (from FadeMem paper)
THRESHOLD_HIGH = 0.7    # always surface
THRESHOLD_LOW = 0.3     # only via semantic search


def importance(memory: dict, now: datetime = None) -> float:
    """
    Calculate FadeMem importance score for a memory result.

    Args:
        memory: dict with keys:
            - similarity (float, 0-1): cosine similarity from search
            - access_count (int): times this memory was accessed
            - last_accessed (str, ISO format): when last accessed
            - hall (str, optional): memory type (hall_advice = correction)
            - tags (str, optional): comma-separated tags
        now: current time (defaults to now)

    Returns:
        float importance score (0-1, clamped)
    """
    now = now or datetime.now(timezone.utc)

    # Semantic relevance (0-1, from search distance)
    relevance = memory.get("similarity", 0.5)

    # Access frequency (saturating function prevents overweighting)
    access_count = memory.get("access_count", 0)
    frequency = access_count / (1 + access_count)

    # Recency (exponential decay)
    last_accessed = memory.get("last_accessed")
    if last_accessed:
        try:
            last_dt = datetime.fromisoformat(last_accessed)
            if last_dt.tzinfo is None:
                last_dt = last_dt.replace(tzinfo=timezone.utc)
            days_since = max(0, (now - last_dt).total_seconds() / 86400)
            recency = math.exp(-DECAY_RATE * days_since)
        except (ValueError, TypeError):
            recency = 0.1
    else:
        recency = 0.1  # never accessed

    # Weighted combination
    score = ALPHA * relevance + BETA * frequency + GAMMA * recency

    # Correction boost — learning from mistakes is higher-value
    is_correction = (
        memory.get("hall") == "hall_advice"
        or "correction" in memory.get("tags", "")
        or memory.get("type") == "correction"
    )
    if is_correction:
        score *= CORRECTION_BOOST

    return min(score, 1.0)


def score_and_rank(
    memories: list[dict],
    budget: int = 5,
    min_importance: float = 0.0,
    now: datetime = None,
) -> list[dict]:
    """
    Score a list of memory results and return the top N by importance.

    Args:
        memories: list of memory dicts (from MemPalace search)
        budget: max results to return
        min_importance: minimum score to include
        now: current time

    Returns:
        list of memory dicts, sorted by importance (descending),
        with 'importance_score' added to each
    """
    now = now or datetime.now(timezone.utc)

    scored = []
    for mem in memories:
        score = importance(mem, now=now)
        if score >= min_importance:
            mem["importance_score"] = round(score, 3)
            scored.append(mem)

    scored.sort(key=lambda m: m["importance_score"], reverse=True)
    return scored[:budget]


def classify(score: float) -> str:
    """Classify importance level for display."""
    if score >= THRESHOLD_HIGH:
        return "high"
    elif score >= THRESHOLD_LOW:
        return "medium"
    else:
        return "low"
