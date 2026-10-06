---
name: create-regression-tests
description: Use when fixing bugs to ensure that regression tests are created and pass successfully.
---
- Identify each bug you have fixed in the code.
- For each bug, create a test function in a file named `tests/test_regressions.py`.
- Ensure each test function is named descriptively and tests the specific bug fix.
- Run the test suite to ensure all regression tests pass.
- If any test fails, review and correct the test or the code as necessary.
- Document the tests in the test file with comments explaining the purpose of each test.
