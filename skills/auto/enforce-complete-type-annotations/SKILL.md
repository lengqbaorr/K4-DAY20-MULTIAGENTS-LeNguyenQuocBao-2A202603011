---
name: enforce-complete-type-annotations
description: Use when writing or reviewing code to ensure all public functions have full type annotations on parameters and return values.
---
- Identify all public functions in the code (names not starting with '_').
- For each public function, verify that every parameter has a type annotation.
- Verify that the function has a return type annotation.
- If any annotation is missing, add it before finalizing the code.
- Use consistent and clear type hints (e.g., built-in types, typing module).
- Run a static type checker (e.g., mypy) to confirm no missing or incorrect annotations.
- Do not submit or finalize code until all public functions are fully annotated.
