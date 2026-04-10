---
tags: ui, api, general, completion
date: 2026-04-11
severity: high
access_count: 6
last_accessed: 2026-04-11T07:21:14+12:00
promoted_to: null
---

After applying a fix, verify it ACTUALLY worked. Do not claim success based on "the code looks right" — check the actual output.

Incident: Claude applied a material fix in Blender (setting alpha mid-level control on a shader). Claimed it was fixed. User checked and reported: "wear is still there and you didnt correctly set the alpha mid-level control on orig_100i_exterior_mtl_internal_pom." The fix was applied to the wrong parameter or not applied at all.

Pattern: After making a change, verify the result matches the intended outcome. Read back the actual state. If you changed a value, confirm the value is now what you set it to. If you fixed a visual issue, look at the visual output. "I made the change" is not verification. "I made the change and confirmed the output now shows X" is verification.
