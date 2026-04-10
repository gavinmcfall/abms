#!/usr/bin/env python3
"""
score_results.py — Thin wrapper that calls mempalace search and scores results
with FadeMem importance scoring before outputting.

Called by inject.sh to replace raw `mempalace search` output with
importance-ranked results.

Usage:
    echo "query terms" | python3 score_results.py [--results N] [--wing WING]

Reads query from stdin, outputs scored results to stdout.
Falls back to raw search if scoring fails.
"""

import sys
import subprocess
import json
import re
from pathlib import Path

# Import the scorer
sys.path.insert(0, str(Path(__file__).parent))
from fademem_scorer import importance, classify


def parse_mempalace_output(raw: str) -> list[dict]:
    """Parse mempalace search CLI output into structured results."""
    results = []
    current = {}

    for line in raw.split('\n'):
        # Match result header: [N] wing / room
        header = re.match(r'\s*\[(\d+)\]\s+(\S+)\s*/\s*(\S+)', line)
        if header:
            if current:
                results.append(current)
            current = {
                'rank': int(header.group(1)),
                'wing': header.group(2),
                'room': header.group(3),
                'source': '',
                'similarity': 0.0,
                'content': '',
                'access_count': 0,
                'last_accessed': None,
            }
            continue

        # Match source line
        source = re.match(r'\s*Source:\s+(.+)', line)
        if source and current:
            current['source'] = source.group(1).strip()
            continue

        # Match similarity score
        match_score = re.match(r'\s*Match:\s+([-\d.]+)', line)
        if match_score and current:
            # Convert distance to similarity (mempalace uses cosine distance)
            dist = float(match_score.group(1))
            current['similarity'] = max(0, 1 - abs(dist))
            continue

        # Content lines
        if current and line.strip() and not line.startswith('──') and not line.startswith('==='):
            current['content'] += line.strip() + ' '

    if current:
        results.append(current)

    return results


def format_scored_results(results: list[dict], budget: int = 3) -> str:
    """Format scored results for injection into context."""
    if not results:
        return ""

    # Score each result
    for r in results:
        r['importance_score'] = importance(r)
        r['importance_level'] = classify(r['importance_score'])

    # Sort by importance (descending)
    results.sort(key=lambda r: r['importance_score'], reverse=True)

    # Take top N
    results = results[:budget]

    lines = []
    for i, r in enumerate(results, 1):
        level = r['importance_level'].upper()
        score = r['importance_score']
        wing = r.get('wing', '?')
        room = r.get('room', '?')
        source = r.get('source', '?')
        content = r.get('content', '').strip()[:200]

        lines.append(f"[{i}] [{level} {score:.2f}] {wing}/{room}")
        lines.append(f"    Source: {source}")
        if content:
            lines.append(f"    {content}")
        lines.append("")

    return '\n'.join(lines)


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--results', type=int, default=5)
    parser.add_argument('--wing', type=str, default=None)
    args = parser.parse_args()

    # Read query from stdin
    query = sys.stdin.read().strip()
    if not query:
        sys.exit(0)

    # Build mempalace search command
    cmd = ['mempalace', 'search', query, '--results', str(args.results)]
    if args.wing:
        cmd.extend(['--wing', args.wing])

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        raw_output = result.stdout
    except (subprocess.TimeoutExpired, FileNotFoundError):
        sys.exit(0)

    if not raw_output.strip():
        sys.exit(0)

    # Parse and score
    try:
        results = parse_mempalace_output(raw_output)
        scored = format_scored_results(results, budget=3)
        if scored:
            print(scored)
    except Exception:
        # Fall back to raw output on any scoring failure
        print(raw_output[:500])


if __name__ == '__main__':
    main()
