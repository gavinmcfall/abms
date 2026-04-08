After running tests:

1. Tests passing does not mean the code is correct. It means the tests passed. Are the tests actually testing the requirement, or just that the code runs without crashing?

2. If tests fail, READ THE ERROR. Do not just retry. What assumption broke? What did the test expect vs what it got?

3. If you just made the tests pass, did you fix the code or fix the tests? Fixing the tests to match broken behavior is not a fix.
