Before claiming data work is complete, verify:

1. SELECT actual rows and READ the values. Row counts tell you nothing about correctness. Do the values make contextual sense?

2. Check foreign keys — are they resolving to real entities, or are they orphaned IDs pointing nowhere?

3. Check NULLs — which are intentional (optional fields) and which are missing data that should exist?

4. If this is a migration, what happens to existing data? Run it against a non-empty dataset, not just an empty schema.

5. Show sample output — actual values from actual rows, not just "migration ran successfully."
