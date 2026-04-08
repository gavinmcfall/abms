Before claiming API work is complete, verify:

1. READ THE RESPONSE BODY. A 200 status code is not verification. What are the actual values? Are there UUIDs where human-readable names should be? Are lists populated or empty? Are enum values localized or raw internal strings?

2. Check at least one edge case: empty collection, missing optional fields, malformed input. What does the error response look like? Is it structured and useful, or a raw stack trace?

3. If the endpoint returns localized content, check at least one non-default locale.

4. If the endpoint requires auth, confirm that missing/invalid auth returns a proper 401/403 — not a 500 or a redirect.

5. Show the actual response body in your evidence. Not "it works" — the literal JSON/data you received.
