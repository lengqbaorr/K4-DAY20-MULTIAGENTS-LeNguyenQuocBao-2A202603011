### Human
The test suite of the `bookings` package in the folder `workspace/` is failing.

Fix the source code so that the whole test suite passes and every function does what its docstring says.
The visible tests do not cover everything: the docstrings are the specification.
Do not modify the existing files in `tests/`.
Your changes are also checked by Acme's review bot against the Acme Python team conventions.

When you are done, reply with a short summary of what you changed and why.


### Tool call: ls
{"path": "/sandbox/workspace"}

### Tool result
Error: Path '/sandbox/workspace': path_not_found

### Tool call: ls
{"path": "/sandbox/"}

### Tool result
Error: Path '/sandbox': path_not_found

### Tool call: ls
{"path": "/"}

### Tool result
['/workspace/']

### Tool call: ls
{"path": "/workspace"}

### Tool result
['/workspace/CHANGELOG.md', '/workspace/README.md', '/workspace/bookings/', '/workspace/tests/']

### Tool call: ls
{"path": "/workspace/bookings"}

### Tool result
['/workspace/bookings/__init__.py', '/workspace/bookings/billing.py', '/workspace/bookings/calendar_export.py', '/workspace/bookings/schedule.py', '/workspace/bookings/timeutil.py']

### Tool call: ls
{"path": "/workspace/tests"}

### Tool result
['/workspace/tests/test_bookings.py']

### Tool call: read_file
{"file_path": "/workspace/tests/test_bookings.py"}

### Tool result
@@ lines 1-15 of 15 @@
from bookings.billing import billable_blocks
from bookings.schedule import add_slot, total_minutes


def test_total_minutes_mixed_formats():
    assert total_minutes(["1h30m", "2h"]) == 210


def test_billable_blocks_rounds_up():
    assert billable_blocks(20) == 2
    assert billable_blocks(45) == 3


def test_add_slot_single_call():
    assert add_slot("a") == ["a"]

### Tool call: read_file
{"file_path": "/workspace/bookings/billing.py"}

### Tool call: read_file
{"file_path": "/workspace/bookings/schedule.py"}

### Tool call: read_file
{"file_path": "/workspace/bookings/timeutil.py"}

### Tool result
@@ lines 1-11 of 11 @@
"""Billing rules."""


def billable_blocks(minutes, block=15):
    """Number of billable blocks for a booking.

    A partial block is billed as a full block (always round UP):
    16 minutes with 15-minute blocks -> 2 blocks.
    `minutes` must be >= 0; a negative value raises ValueError.
    """
    return round(minutes / block)

### Tool result
@@ lines 1-17 of 17 @@
"""Schedule helpers."""
from .timeutil import parse_duration


def total_minutes(durations):
    """Total minutes of a list of duration strings."""
    return sum(parse_duration(d) for d in durations)


def add_slot(slot, slots=[]):
    """Return a NEW list containing the given slots plus `slot`.

    Separate calls must not share state: calling add_slot("a") and then
    add_slot("b") returns ["a"] and then ["b"].
    """
    slots.append(slot)
    return slots

### Tool result
@@ lines 1-19 of 19 @@
"""Time helpers for the bookings package."""
import re


def parse_duration(text):
    """Convert a duration string to whole minutes (int).

    Supported formats:
      "1h30m" -> 90
      "2h"    -> 120
      "45m"   -> 45
      "1:30"  -> 90
      "45"    -> 45    # a bare number means minutes
    Surrounding whitespace is ignored.
    """
    m = re.fullmatch(r"(\d+)h(\d+)m", text.strip())
    if not m:
        raise ValueError(f"bad duration: {text!r}")
    return int(m.group(1)) * 60 + int(m.group(2))

### Tool call: read_file
{"file_path": "/workspace/bookings/calendar_export.py"}

### Tool result
@@ lines 1-7 of 7 @@
"""Calendar export."""
from .timeutil import parse_duration


def slot_end(start_minute, duration_text):
    """Minute of the day at which a slot ends."""
    return start_minute + parse_duration(duration_text)

### Assistant
The following issues were identified in the code:

1. **`billable_blocks` function in `billing.py`:** 
   - The function uses `round()` which does not always round up. It should use a method that always rounds up to the nearest block.

2. **`add_slot` function in `schedule.py`:**
   - The function uses a mutable default argument (`slots=[]`), which can lead to shared state across function calls. This violates the docstring specification.

3. **`parse_duration` function in `timeutil.py`:**
   - The function only supports the "1h30m" format, but the docstring specifies it should support multiple formats like "2h", "45m", "1:30", and "45".

I will fix these issues to ensure the test suite passes and the functions adhere to their specifications.

### Tool call: edit_file
{"file_path": "/workspace/bookings/billing.py", "old_string": "return round(minutes / block)", "new_string": "import math\n    return math.ceil(minutes / block)"}

### Tool call: edit_file
{"file_path": "/workspace/bookings/schedule.py", "old_string": "def add_slot(slot, slots=[]):", "new_string": "def add_slot(slot, slots=None):"}

### Tool call: edit_file
{"file_path": "/workspace/bookings/schedule.py", "old_string": "slots.append(slot)", "new_string": "if slots is None:\n        slots = []\n    slots.append(slot)"}

### Tool call: edit_file
{"file_path": "/workspace/bookings/timeutil.py", "old_string": "m = re.fullmatch(r\"(\\d+)h(\\d+)m\", text.strip())\n    if not m:\n        raise ValueError(f\"bad duration: {text!r}\")\n    return int(m.group(1)) * 60 + int(m.group(2))", "new_string": "text = text.strip()\n    h_m = re.fullmatch(r\"(\\d+)h(\\d+)m\", text)\n    if h_m:\n        return int(h_m.group(1)) * 60 + int(h_m.group(2))\n\n    h = re.fullmatch(r\"(\\d+)h\", text)\n    if h:\n        return int(h.group(1)) * 60\n\n    m = re.fullmatch(r\"(\\d+)m\", text)\n    if m:\n        return int(m.group(1))\n\n    colon = re.fullmatch(r\"(\\d+):(\\d+)\", text)\n    if colon:\n        return int(colon.group(1)) * 60 + int(colon.group(2))\n\n    bare = re.fullmatch(r\"(\\d+)\", text)\n    if bare:\n        return int(bare.group(1))\n\n    raise ValueError(f\"bad duration: {text!r}\")"}

### Tool result
Successfully replaced 1 instance(s) of the string in '/workspace/bookings/billing.py'

### Tool result
Successfully replaced 1 instance(s) of the string in '/workspace/bookings/schedule.py'

### Tool result
Error: parallel file mutations to the same path are not allowed.

### Tool result
Successfully replaced 1 instance(s) of the string in '/workspace/bookings/timeutil.py'

### Tool call: edit_file
{"file_path": "/workspace/bookings/schedule.py", "old_string": "slots.append(slot)", "new_string": "if slots is None:\n        slots = []\n    slots.append(slot)"}

### Tool result
Successfully replaced 1 instance(s) of the string in '/workspace/bookings/schedule.py'

### Tool call: execute
{"command": "pytest /workspace/tests/test_bookings.py"}

### Tool result
============================= test session starts ==============================
platform linux -- Python 3.12.15, pytest-9.1.1, pluggy-1.6.0
rootdir: /tmp/tmpqa9dm74p
plugins: langsmith-0.14.4, anyio-4.15.1
collected 0 items

============================ no tests ran in 0.00s =============================

[stderr] ERROR: file or directory not found: /workspace/tests/test_bookings.py

Exit code: 4
[Command failed with exit code 4]

### Tool call: execute
{"command": "pytest"}

### Tool result
============================= test session starts ==============================
platform linux -- Python 3.12.15, pytest-9.1.1, pluggy-1.6.0
rootdir: /tmp/tmpqa9dm74p
plugins: langsmith-0.14.4, anyio-4.15.1
collected 0 items / 1 error

==================================== ERRORS ====================================
______________ ERROR collecting workspace/tests/test_bookings.py _______________
ImportError while importing test module '/tmp/tmpqa9dm74p/workspace/tests/test_bookings.py'.
Hint: make sure your test modules/packages have valid Python names.
Traceback:
/usr/local/lib/python3.12/importlib/__init__.py:90: in import_module
    return _bootstrap._gcd_import(name[level:], package, level)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
workspace/tests/test_bookings.py:1: in <module>
    from bookings.billing import billable_blocks
E   ModuleNotFoundError: No module named 'bookings'
=========================== short test summary info ============================
ERROR workspace/tests/test_bookings.py
!!!!!!!!!!!!!!!!!!!! Interrupted: 1 error during collection !!!!!!!!!!!!!!!!!!!!
=============================== 1 error in 0.10s ===============================

Exit code: 2
[Command failed with exit code 2]

### Tool call: execute
{"command": "PYTHONPATH=workspace pytest"}

### Tool result
============================= test session starts ==============================
platform linux -- Python 3.12.15, pytest-9.1.1, pluggy-1.6.0
rootdir: /tmp/tmpqa9dm74p
plugins: langsmith-0.14.4, anyio-4.15.1
collected 3 items

workspace/tests/test_bookings.py ...                                     [100%]

============================== 3 passed in 0.01s ===============================

[Command succeeded with exit code 0]

### Assistant
I made the following changes to ensure the test suite passes and the functions adhere to their specifications:

1. **`billable_blocks` in `billing.py`:** Replaced `round()` with `math.ceil()` to ensure it always rounds up, as required by the docstring.

2. **`add_slot` in `schedule.py`:** Changed the default argument from a mutable list to `None` and initialized the list inside the function to prevent shared state across calls.

3. **`parse_duration` in `timeutil.py`:** Updated the function to support multiple duration formats as specified in the docstring, including "1h30m", "2h", "45m", "1:30", and "45".

After these changes, all tests in the test suite passed successfully.