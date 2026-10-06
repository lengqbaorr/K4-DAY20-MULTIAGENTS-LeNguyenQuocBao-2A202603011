---
name: add-regression-tests-for-fixes
description: Use when fixing bugs to ensure each fix is covered by a dedicated regression test.
---
- For every bug fixed, write at least one test function that reproduces the bug scenario.
- Place all regression tests in a dedicated file named tests/test_regressions.py.
- Ensure each test function is clearly named to reflect the bug it covers.
- Run all tests to confirm the bug is fixed and no regressions occur.
- Confirm the regression test file passes without errors or failures.
- Add the regression test file to the test suite and CI pipeline.
- Maintain the regression tests as part of the codebase to prevent future regressions.
