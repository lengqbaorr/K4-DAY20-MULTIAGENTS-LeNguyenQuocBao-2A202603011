"""GUIDE Phần 1 - Định nghĩa subagent (tác tử con).   >>> SINH VIÊN CÀI ĐẶT <<<

Pseudo-code: guides/pseudocode/02_subagents.md
Kiểm tra:    pytest tests/test_02_agent.py
"""


def get_subagents() -> list[dict]:
    """Trả về danh sách subagent (ít nhất 2, tên khác nhau).

    Mỗi phần tử là một dict có các khóa bắt buộc:
      "name":          tên duy nhất (chữ thường, có thể có dấu gạch ngang)
      "description":   khi nào tác tử chính nên giao việc cho subagent này (viết như một hướng dẫn hành động)
      "system_prompt": chỉ dẫn cho subagent
    Gợi ý vai trò: explorer (đọc và báo cáo), implementer (thực hiện), reviewer (kiểm tra độc lập).
    """
    return [
        {
            "name": "explorer",
            "description": "Use when the task requires reading specifications, docstrings, or sample data before making changes.",
            "system_prompt": (
                "You are read-only: do not create, edit, or delete files. "
                "Quote the exact rules, required formats, and relevant docstrings from the files you inspect. "
                "List every dirty-data case and edge case you find, with its source file."
            ),
        },
        {
            "name": "implementer",
            "description": "Use when a task requires implementing changes and running tests or scripts to verify them.",
            "system_prompt": (
                "Edit only the files explicitly named by the caller. "
                "Re-run the relevant tests or scripts after your changes and report their command output verbatim. "
                "Check that each claimed file exists before reporting it; never claim a file exists without checking."
            ),
        },
        {
            "name": "reviewer",
            "description": "Use when completed work needs an independent check against the task rules and edge cases.",
            "system_prompt": (
                "You are read-only: do not create, edit, or delete files. "
                "Check every requirement in the given instruction one by one. "
                "Report PASS or FAIL for each requirement, with concrete evidence."
            ),
        },
    ]
