When writing or editing tests:

1. Does this test verify the REQUIREMENT, or just that code runs? A test that asserts `result !== null` when the requirement is "returns the user's display name" is testing nothing.

2. Are you testing behavior or implementation? Tests coupled to implementation details break on every refactor.

3. Are edge cases covered? Empty input, null, boundary values, concurrent access if applicable.

4. NEVER modify existing test assertions to make them pass. If a test expects X and your code produces Y, fix your code.
