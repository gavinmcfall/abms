---
description: MemPalace setup and integration guide for ABMS Phase 2
tags: [setup, mempalace, memory, chromadb, phase-2]
audience: { human: 80, agent: 20 }
purpose: { low-agency-process: 70, reference: 30 }
---

# Phase 2: MemPalace Integration

Phase 2 adds verbatim memory storage with semantic search and a temporal knowledge graph. This gives the rules engine the ability to ask "what have I forgotten?" before every action.

## Prerequisites

- Phase 1 installed and working
- Python 3.9+
- pip

## Step 1: Install MemPalace

```bash
pip install mempalace
```

## Step 2: Initialize your palace

```bash
mempalace init ~/projects/your-main-project
```

This runs guided onboarding — it asks about your projects, people, and preferences, then generates wing configuration.

## Step 3: Mine existing conversations

If you have Claude Code conversation exports or chat history:

```bash
# Mine conversation exports
mempalace mine ~/chats/ --mode convos

# Mine project files (code, docs, notes)
mempalace mine ~/projects/your-project/
```

## Step 4: Add MCP server

```bash
claude mcp add mempalace -- python -m mempalace.mcp_server
```

This gives Claude Code 19 memory tools:

| Category | Tools |
|----------|-------|
| Palace (read) | `mempalace_status`, `mempalace_search`, `mempalace_list_wings`, `mempalace_list_rooms`, `mempalace_get_taxonomy`, `mempalace_check_duplicate`, `mempalace_get_aaak_spec` |
| Palace (write) | `mempalace_add_drawer`, `mempalace_delete_drawer` |
| Knowledge Graph | `mempalace_kg_query`, `mempalace_kg_add`, `mempalace_kg_invalidate`, `mempalace_kg_timeline`, `mempalace_kg_stats` |
| Navigation | `mempalace_traverse`, `mempalace_find_tunnels`, `mempalace_graph_stats` |
| Agent Diary | `mempalace_diary_write`, `mempalace_diary_read` |

## Step 5: Add auto-save hooks

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "python -m mempalace.hooks.mempal_save_hook",
        "timeout": 30
      }]
    }],
    "PreCompact": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "python -m mempalace.hooks.mempal_precompact_hook",
        "timeout": 30
      }]
    }]
  }
}
```

The save hook fires every 15 human messages and forces a structured memory save. The precompact hook fires before compaction and forces a comprehensive save.

## Step 6: Update inject.sh for memory queries

Replace the Phase 1 inject.sh with the Phase 2 version in this directory (`inject-phase2.sh`). The Phase 2 version adds Layer 5: memory queries after static rules and corrections.

```bash
cp implementation/phase-2-memory/inject-phase2.sh ~/.claude/rules-engine/inject.sh
chmod +x ~/.claude/rules-engine/inject.sh
```

## Step 7: Verify

```bash
# Check palace status
mempalace status

# Search for something
mempalace search "auth decisions"

# Check knowledge graph
mempalace kg-stats
```

## Storage Locations

| Component | Location |
|-----------|----------|
| ChromaDB (vector store) | `~/.mempalace/palace/` |
| Knowledge graph (SQLite) | `~/.mempalace/knowledge_graph.sqlite3` |
| Wing configuration | `~/.mempalace/wing_config.json` |
| Global config | `~/.mempalace/config.json` |
| Identity (L0) | `~/.mempalace/identity.txt` |
| Hook state | `~/.mempalace/hook_state/` |

## How It Connects to ABMS

MemPalace becomes the memory backend for Layer 5 of the injection pipeline. Before every action, inject.sh queries MemPalace for:

1. **Relevant corrections** from past sessions (semantic search on `hall_advice`)
2. **Relevant decisions** from the knowledge graph (what was decided about this topic)
3. **Failure patterns** (`claude → failed_at → {pattern}` triples)

Results are scored by FadeMem importance (Phase 3) and injected alongside static rules.
