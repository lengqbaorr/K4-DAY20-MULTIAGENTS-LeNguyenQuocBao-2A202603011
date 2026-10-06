---
name: add-regression-tests-for-fixes
description: Use when fixing bugs to ensure each fix is covered by a dedicated regression test in a centralized test file.
---
- For every bug fix made, write a new test function that reproduces the bug scenario and verifies the fix.
- Place all regression tests in a single file named tests/test_regressions.py.
- Name each test function clearly to indicate the bug it covers.
- Ensure the regression test file imports necessary modules and runs without errors.
- Run the full test suite to confirm all tests, including regressions, pass.
- Maintain at least one regression test per bug fixed.
- Update the regression test file incrementally with each new bug fix.
- Do not finalize code without adding these regression tests.
