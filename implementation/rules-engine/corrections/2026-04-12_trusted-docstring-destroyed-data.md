---
tags: api, data, commit, general, infra, test-run, test-write
date: 2026-04-12
severity: critical
access_count: 59
last_accessed: 2026-04-13T09:32:08+12:00
promoted_to: null
---

NEVER trust a docstring or comment about what a destructive operation does. READ THE IMPLEMENTATION. Especially before running anything with `--wipe`, `--clear`, `--reset`, `DROP`, `TRUNCATE`, `DELETE FROM`, `rm -rf`, or any script whose name contains those words.

Incident (2026-04-12): Claude ran `load_staging.py --full-wipe` against staging with live user data. The docstring for `generate_clear_sql` said "User/BA data is preserved." Claude trusted that and did not read the function. The function actually deleted: user_change_history, user_hangar_syncs, user_llm_configs, user_localization_configs, user_buyback_pledges. Hours of user data destroyed. Recovery required restoring from a pre-wipe SQL dump.

The session had already filed two corrections that morning about this exact pattern (feedback_preserved_tables_broken_fks.md, feedback_verify_output_not_input.md) and ran the destructive op anyway — trusting documentation instead of the code.

Pattern:
1. Before running ANY destructive operation, read the actual code that performs the destruction. Not the docstring. Not the CHANGELOG. The code.
2. When documentation says "X is preserved" for a destructive operation, prove it by reading the SQL/code that specifies which tables are dropped or which rows are deleted.
3. When interpretation is ambiguous ("wipe push the data" could mean --pipeline-only UPSERT or --full-wipe), CHOOSE the least destructive interpretation and ask the user to confirm before running the destructive one.
4. For shared environments (staging, production, shared clusters), ALWAYS take a verified backup before destructive operations. Take the backup OF THE ACTUAL DATA YOU COULD DESTROY, not just the tables you predicted might be affected.
5. Destructive operations against shared environments should be blocked by hook. If this correction ever fires without the block, escalate immediately.
