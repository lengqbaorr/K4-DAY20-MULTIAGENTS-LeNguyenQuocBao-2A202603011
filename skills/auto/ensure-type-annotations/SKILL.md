---
name: ensure-type-annotations
description: Use when writing or modifying public functions to ensure all parameters and return values have type annotations.
---
- Identify all public functions (those not starting with an underscore) in your code.
- For each function, add type annotations for all parameters.
- Add a type annotation for the return value of each function.
- Review the function signatures to ensure all annotations are correct and complete.
- Run a static type checker (e.g., mypy) to verify that type annotations are correctly applied.
