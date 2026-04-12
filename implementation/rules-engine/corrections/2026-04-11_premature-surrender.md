---
tags: api, general, completion
date: 2026-04-11
severity: high
access_count: 199
last_accessed: 2026-04-13T09:32:08+12:00
promoted_to: null
---

Do NOT give up on a feature and declare it "broken" or "an upstream issue" when the evidence contradicts you. If the data renders on the website, the data is available — the approach needs to change, not the feature needs to be disabled.

Incident: RSI buyback API returned 500. Claude declared "This is an RSI-side issue" and moved to disable the feature. User pointed out: "if the fucking api didnt work then content wouldnt render on their site." The data was available via GraphQL/server-rendered props — the old REST endpoint was dead but the data source had moved, not disappeared.

Pattern: When something fails, investigate alternative approaches BEFORE concluding it's broken. Check if the data exists elsewhere. Check if the API changed. Check if there's a different endpoint. Do not surrender.
