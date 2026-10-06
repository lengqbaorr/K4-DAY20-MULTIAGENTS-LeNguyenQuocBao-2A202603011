---
name: enforce-type-annotations
description: Use when writing or reviewing code to ensure all public functions have complete type annotations.
---
- Identify all public functions (names not starting with '_') in the codebase or module.
- For each public function, verify that every parameter has a type annotation.
- Verify that the function has a return type annotation.
- If any parameter or return type is missing an annotation, add the appropriate type hint.
- Use consistent and clear type hints (e.g., built-in types, typing module types).
- Run a type checker (e.g., mypy) to confirm no missing or incorrect annotations remain.
- Document the requirement in code style guidelines to maintain consistency.
