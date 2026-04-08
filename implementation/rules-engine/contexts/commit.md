Before committing:

1. Have you actually run the tests? The verification gate will block you if not, but ask yourself: did the tests exercise the code you changed, or did they just pass because they test something else?

2. Check git diff — are you committing only your changes? Are there files you didn't intend to modify? Secrets, env files, lock files?

3. Does the commit message describe WHY, not just WHAT? "Fix bug" is useless. "Fix race condition in session handoff that caused duplicate notifications" is useful.

4. Are you committing someone else's work? Check the worklog for other active sessions.
