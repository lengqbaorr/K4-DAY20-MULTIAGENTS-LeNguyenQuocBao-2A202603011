# Báo cáo Lab: Self evolving Agentic

## 1. Thông tin nhóm và cấu hình

| Họ tên | Mã sinh viên | Phần đóng góp |
|---|---|---|
| Lê Nguyễn Quốc Bảo | 2A202603011 | Toàn bộ |

- Mô hình: `LAB_MODEL=openai:gpt-4o` (máy chủ trả về `gpt-4o-2024-08-06`), `LAB_TEMPERATURE=0`, `recursion_limit=60` (mặc định của runner).
- Deep Agents 0.7.21; Windows 11 + Docker (`python:3.12-slim`, image `lab-deepagents` từ `Dockerfile`). Mọi lần chạy tác tử đi qua `run_isolated.ps1` (Phụ lục).
- Số lần chạy tác vụ: 21 lần chạy được ghi trong `results/` = 9 trước đóng băng (baseline 3, subagents 3, skills-auto-dev 3) + 12 sau đóng băng (baseline 3, subagents 3, skills-auto 6), cộng các lần chạy lại do lỗi hạ tầng (mục 7, Phụ lục). Chi phí OpenAI của chuỗi này khoảng 2,6 USD (920.229 token vào, 28.892 token ra).
- Commit của tag `freeze`: `52b0302` (commit `hypotheses`: `817fed4`).

## 2. Giả thuyết (commit TRƯỚC tag `freeze`, Phần 4.0)

Căn cứ: mục 4 (lỗi chiếm đa số là bỏ qua quy ước đường dẫn rồi dừng, và quy ước `rule_`), mục 5, mục 6 (cả 3 skill chỉ phủ họ `code`; Phần 3.4 có 1/3 lần chạy đọc skill nhưng không làm theo); SkillsBench (skill do mô hình tự sinh trung bình không có lợi); SkillEvolBench (lợi ích trên tác vụ học thường không chuyển sang tác vụ mới); bài viết của Anthropic về hệ thống nghiên cứu đa tác tử (đa tác tử tốn nhiều token hơn đáng kể).

- H1 (subagents so với baseline): `subagents` **không** cao hơn `baseline` trên tác vụ đánh giá và tốn token nhiều hơn rõ rệt. Lý do: ở tác vụ học, hai điều kiện cùng đạt 7/18 check kỹ thuật và 0/9 check quy ước, trong khi token trung bình của `subagents` gấp 2,1 lần (37.950 so với 18.041); lời giao việc cho `implementer` không thể chứa quy ước `rule_` (đề không nêu) và tác tử chính không kiểm chứng báo cáo của subagent.
- H2 (skills-auto so với baseline): `skills-auto` có thể cao hơn `baseline` một chút trên tác vụ đánh giá, nhưng **không** nhờ nội dung skill: check quy ước vẫn 0, kể cả ở `code-eval` nơi skill mô tả đúng ba quy ước cũ. Lý do: ở Phần 3.4 `skills-auto-dev` đạt 10/18 check kỹ thuật so với 7/18 của `baseline` nhưng chênh lệch đến từ việc tác tử không mắc lỗi đường dẫn và có chạy code, còn skill duy nhất được đọc (`create-regression-tests`) không được làm theo; skill chỉ phủ họ `code`.
- H3 (tác vụ học so với tác vụ đánh giá): điểm tác vụ đánh giá của cả ba điều kiện **thấp hơn hoặc bằng** tác vụ học, vì mỗi tác vụ đánh giá thêm một quy ước mới mà không skill hay lời giao việc nào biết trước.

## 3. Làm quen Deep Agents (Phần 0.3)

1. Tác tử mặc định có 9 công cụ: công cụ tệp `ls`, `read_file`, `write_file`, `edit_file`, `delete`, `glob`, `grep`; shell `execute`; giao việc `task`. Công cụ chạy lệnh là `execute`.
2. Mô tả của `task` giới thiệu subagent `general-purpose` là tác tử đa năng "for researching complex questions, searching for files and content, and executing multi-step tasks", có cùng khả năng với tác tử chính. Subagent **không** thấy hội thoại của tác tử chính: "Each invocation is stateless by default: the agent sees only the prompt you give it and returns a single final report."
3. Câu từ `task`: "Put full detail in the prompt and state exactly what it should return". Câu từ `execute`: "You MUST avoid using search commands like find and grep. Instead use the grep, glob tools to search." Lưu ý: mô tả `execute` nói lệnh chạy "in an isolated sandbox", nhưng `LocalShellBackend` chạy lệnh thật trên hệ điều hành của runner (dẫn tới sự cố ở Phụ lục).

## 4. Đường cơ sở và phân loại lỗi (Phần 2.2)

Nguồn: `results/baseline/*-learn/run.json` và `trace.md`.

| Tác vụ | Check thất bại | Nhóm lỗi (A-G) | Bằng chứng (trích ngắn từ `detail` hoặc vết) |
|---|---|---|---|
| code-learn | rule_type_hints | E | `RULE: every public function (name not starting with '_') in the package has type annotations ...` |
| code-learn | rule_regression_tests | E | `RULE: add tests/test_regressions.py with one test function per bug you fixed (at least 3)` |
| code-learn | rule_changelog | E | `RULE: record each fix in CHANGELOG.md under the heading '## Unreleased' ...` |
| data-learn | north_q1_revenue, north_q1_orders, top_region, missing_amount_orders, duplicate_rows_removed, rule_money_in_cents, rule_meta_block (7 check) | A | `FileNotFoundError: ... workspace/answer.json`. Vết (2 tool call): `read_file {"file_path": "/sandbox/workspace/README.md"}` và `/sandbox/workspace/sales.csv` → `Error: File '/sandbox/workspace/README.md' not found`; tác tử tự đặt tiền tố `/sandbox/`, trái với `PATHS_NOTE` ("every path is relative ... never starts with '/'"). |
| data-learn | rule_clean_csv | A | `RULE: write workspace/clean.csv ...`: không tệp nào được ghi, cùng nguyên nhân. |
| logs-learn | 9/9 check (valid_structure ... rule_schema_header) | A + B | `FileNotFoundError: ... workspace/errors.json`. Vết: cùng lỗi `/sandbox/workspace/...`; câu trả lời cuối: "It seems that both the workspace/README.md and workspace/app.log files are missing ... Please ensure these files are available" (dừng sau một lần lỗi, không thử `ls` hay đường dẫn tương đối, nhóm B). |

Nhận xét:
- Nhóm A chiếm đa số: 17/20 check thất bại (toàn bộ `data-learn` và `logs-learn`) đến từ **một** lỗi bỏ qua đặc tả đường dẫn rồi bỏ cuộc sau 2 tool call (khoảng 5.400 token mỗi lần chạy). 3/20 còn lại là nhóm E (quy ước `rule_` không có trong đề). Một skill có thể phòng ngừa nhóm A ("dùng đường dẫn tương đối; khi không thấy tệp, chạy `ls` trước khi kết luận"), nhưng curator không rút ra skill như vậy (mục 6) vì `detail` của bot chỉ nói `FileNotFoundError` về tệp đầu ra.
- Bằng chứng phủ định cho C, D, F (`scripts/check_breakdown.py`): baseline đạt 7/18 check kỹ thuật, trong đó `code-learn` đạt 7/7 (sửa đúng nguyên nhân gốc ở hàm dùng chung, không vá triệu chứng); ở `data-learn` và `logs-learn` không có dữ liệu được xử lý nên không thể quan sát nhóm D. Câu trả lời cuối của hai lần chạy thất bại nói đúng sự thật (không tạo tệp), nên không có nhóm F.

## 5. Điều kiện `subagents` (Phần 2.3)

- Subagent đã định nghĩa (`src/lab/subagents.py`): `explorer` (chỉ đọc; trích nguyên văn quy tắc, định dạng, docstring, liệt kê dữ liệu bẩn), `implementer` (chỉ sửa tệp được giao, chạy lại test, báo nguyên văn kết quả), `reviewer` (chỉ đọc; kiểm tra từng yêu cầu PASS/FAIL kèm bằng chứng). Lý do: tách đọc, làm và kiểm chứng để nhắm vào nhóm A, B, F.
- `subagent_calls`: `code-learn` 1, `data-learn` 0, `logs-learn` 1; cả hai lần đều có `"subagent_type": "implementer"` (subagent tự định nghĩa). `explorer` và `reviewer` không được gọi. Ở `data-learn`, tác tử chính mắc đúng lỗi đường dẫn `/sandbox/workspace/...` như baseline và dừng trước khi kịp giao việc.
- Thông tin giao việc: lời giao việc đủ chi tiết về đề (`code-learn`: "The test suite for the inventory package is failing. The package consists of ... export.py, pricing.py, and report.py ..."; `logs-learn`: "Parse the log file workspace/app.log according to the format specified in workspace/README.md ... adhering to Acme's log-triage conventions") nhưng không thể có nội dung quy ước `rule_`, nên `implementer` lặp lại các lỗi E (0/9 check quy ước). Ở `logs-learn`, `errors.json` do subagent viết có cấu trúc sai (`valid_structure: structure: missing keys or wrong types`; các check khác `TypeError: list indices must be integers or slices, not str`), vậy mà tác tử chính vẫn báo "The results were written ... adhering to Acme's log-triage conventions" mà không mở tệp kiểm tra (nhóm B/F).
- Token và thời gian: token trung bình tác vụ học 37.950 (subagents) so với 18.041 (baseline), gấp 2,1 lần; riêng `code-learn` 81.055 so với 43.155 với cùng điểm 7/10. Check kỹ thuật bằng nhau (7/18).

## 6. Self-evolving: skill do curator sinh (Phần 3)

- Số lần chạy curator: 1 (trên `results/baseline`, chỉ tác vụ học). Không xóa skill nào, không chạy lại: cả ba đúng với `detail` của bot và vô hại.

| Skill | Tổng quát hay riêng cho tác vụ học? | Đúng hay sai (nêu chỗ sai nếu có) | Độ dài, `description` và `skills_read` ở Phần 3.4 |
|---|---|---|---|
| create-regression-tests | Tổng quát cho mọi tác vụ sửa lỗi; `tests/test_regressions.py` là quy ước được phép. Chỉ phủ họ `code`. | Đúng với `rule_regression_tests`, nhưng thiếu "ít nhất 3 test". Dòng "Document the tests ... with comments" thừa. | 6 dòng; "Use when fixing bugs ..." nêu đúng tình huống; được đọc ở `code-learn` (1 lần) nhưng không được làm theo. |
| ensure-type-annotations | Tổng quát. Chỉ phủ họ `code`. | Đúng với `rule_type_hints`. "Run a static type checker (e.g., mypy)" có thể không làm được (mypy không cài sẵn). | 5 dòng; `description` rõ; không được đọc. |
| update-changelog | Tổng quát; định dạng `- fix(<function name>):` dưới `## Unreleased` là quy ước được phép. Chỉ phủ họ `code`. | Đúng với `rule_changelog`. "commit it along with your code changes" thừa (tác vụ không dùng git). `description` "Use when making changes to the codebase" hơi rộng. | 6 dòng; không được đọc. |

- Không skill nào phủ nhóm lỗi chiếm đa số (A: đường dẫn) hay quy ước của `data`, `logs`: phản hồi duy nhất curator thấy ở hai tác vụ này là `FileNotFoundError` về tệp đầu ra (và `detail` của `rule_clean_csv`), không đủ để suy ra quy ước.
- Phần 3.4 (`results/skills-auto-dev`): `code-learn` 6/10, `data-learn` 3/8, `logs-learn` 1/9; `skills_read` = 1, 0, 0; `skills_modified = false` ở cả ba. Ở `code-learn`, tác tử gọi `read_file {"file_path": "/skills/create-regression-tests/SKILL.md"}` ngay đầu, đọc được dòng "create a test function in a file named tests/test_regressions.py", nhưng sau đó không tạo tệp này (`rule_regression_tests` vẫn trượt): skill được đọc nhưng không được làm theo. Ở `data-learn` và `logs-learn`, tác tử dùng đúng đường dẫn tương đối (không có `/sandbox/`) nên có dữ liệu để xử lý (`data-learn` 3 lệnh `execute`, 3/8), nhưng đây không phải tác dụng của skill (không skill nào được đọc).
- Ghi chú so sánh mô hình: với `gpt-4.1-mini` (chuỗi chạy trước, đã hủy) không skill nào được đọc ở 9 lần chạy và mọi lần giao việc đều chọn `general-purpose`; với `gpt-4o`, skill được đọc và subagent tự định nghĩa (`implementer`) được chọn. Cách nạp skill và đăng ký subagent đã được kiểm chứng độc lập bằng mô hình giả (`ScriptedChatModel`): system prompt có `SKILLS_NOTE` và danh sách skill; mô tả công cụ `task` liệt kê `general-purpose`, `explorer`, `implementer`, `reviewer`.

## 7. Kết quả so sánh (Phần 4.3, 4.4)

`report/table.md` (sinh bởi `python -m lab.compare`):

| Task | baseline | subagents | skills-auto |
|---|---|---|---|
| code-learn | 7/10 | 7/10 | 6/10 |
| data-learn | 0/8 | 0/8 | 3/8 |
| logs-learn | 0/9 | 0/9 | 1/9 |
| code-eval | 6/11 | 6/11 | 6/11 |
| data-eval | 0/9 | 3/9 | 3/9 |
| logs-eval | 0/10 | 0/10 | 1/10 |
| **Mean score - learning tasks** | 0.23 | 0.23 | 0.36 |
| **Mean score - evaluation tasks** | 0.18 | 0.29 | 0.33 |
| **Mean tokens per run** | 27,663 | 38,984 | 71,503 |
| **Runs that read a skill** | 0/6 | 0/6 | 3/6 |

`python scripts/check_breakdown.py`:

```text
condition     role    technical  house rules  mean tokens  read a skill
baseline      eval      6/18         0/12          37,285      0/3
baseline      learn     7/18         0/9           18,040      0/3
subagents     eval      9/18         0/12          40,017      0/3
subagents     learn     7/18         0/9           37,950      0/3
skills-auto   eval     10/18         0/12          64,674      1/3
skills-auto   learn    10/18         0/9           78,332      2/3
```

- `python scripts/verify_freeze.py` (chạy trên Linux/WSL): `checked 6 runs of skill conditions: OK`; `skills_modified = false` ở mọi lần chạy. Trên Windows script báo nhầm "skills differ from the frozen skills" vì `hash_skills` băm cả đường dẫn tương đối (`\` trên Windows, `/` trong container Linux nơi các lần chạy diễn ra); nội dung skill không đổi.
- Lần chạy có `error` và cách xử lý (GUIDE 4.2: chạy lại lần lỗi và ghi chú):
  - `baseline/code-eval`: lần đầu `GraphRecursionError` (60 bước, 175.936 token, 3/11); chạy lại gặp 429, chạy lại lần nữa thành công (6/11, không lỗi). Bảng dùng lần thành công.
  - `skills-auto/code-eval`: lần đầu `GraphRecursionError` (171.804 token, 7/11); chạy lại gặp `OpenAIConnectionError` (3/11); chạy lại lần nữa thành công (6/11, không lỗi). Bảng dùng lần thành công.
  - `subagents/data-eval`: **vẫn còn lỗi** `OpenAIRateLimitError` (429) sau 9 lần thử (4 lần trong lượt chính, 5 lần khi chạy lại). Một lần chạy này tự nó dùng 39.000-71.000 token trong 20-90 giây, vượt giới hạn 30.000 token/phút của tài khoản nên không thể hoàn tất bằng cách chờ. Bảng dùng lần cuối (3/9, có `error`). Đây là lỗi hạ tầng; điểm 3/9 là chặn dưới của điều kiện này trên `data-eval`.

## 8. Phân tích

1. **Học và đánh giá.** Tác vụ học: `skills-auto` 0,36 so với 0,23 của `baseline` và `subagents`. Tác vụ đánh giá: `skills-auto` 0,33, `subagents` 0,29, `baseline` 0,18. Không có điều kiện nào cải thiện tác vụ học mà không cải thiện tác vụ đánh giá, nên không thấy dấu hiệu quá khớp. Tuy nhiên chênh lệch không đến từ tri thức trong skill (câu 2, 3). Đối chiếu giả thuyết: H1 sai về điểm số (`subagents` cao hơn `baseline` 0,11 trên tác vụ đánh giá, toàn bộ ở `data-eval`: 3/9 so với 0/9) nhưng đúng về chi phí; H2 đúng (cao hơn một chút, check quy ước vẫn 0); H3 đúng với `baseline` (0,18 ≤ 0,23) và `skills-auto` (0,33 ≤ 0,36), sai với `subagents` (0,29 > 0,23).
2. **Kỹ thuật và quy ước.** Check quy ước: 0/9 (học) và 0/12 (đánh giá) ở **cả ba** điều kiện. Skill do curator sinh không giúp check quy ước nào, kể cả ba quy ước cũ mà skill mô tả đúng (`rule_type_hints`, `rule_regression_tests`, `rule_changelog`) ở `code-learn` và `code-eval`. Quy ước mới của tác vụ đánh giá (`rule_version_bump`, `rule_sorted_keys_format`, `rule_source_line`) không thể được skill giúp vì không có trong phản hồi nào của tác vụ học. Toàn bộ chênh lệch giữa các điều kiện nằm ở check **kỹ thuật**: học 7/18, 7/18, 10/18; đánh giá 6/18, 9/18, 10/18.
3. **Cơ chế qua vết.** Skill được đọc ở 3/6 lần chạy `skills-auto` (`code-learn`: `create-regression-tests`; `logs-learn`: cả 3 skill; `code-eval`: `create-regression-tests`), khác với `gpt-4.1-mini` (0 lần, Phụ lục). Nhưng skill **được đọc mà không được làm theo**: ở `skills-auto/code-learn` và `skills-auto/code-eval`, tác tử đọc dòng "create a test function in a file named `tests/test_regressions.py`" ngay đầu, rồi không bao giờ tạo tệp này (chuỗi `test_regressions` chỉ xuất hiện trong nội dung skill được đọc), nên `rule_regression_tests` vẫn trượt. Ở `logs-learn`, tác tử đọc cả 3 skill nhưng chúng chỉ nói về sửa lỗi code, không áp dụng được cho log (1/9). Không có check nào mà nội dung skill giúp đạt. Cơ chế thật sự tạo khác biệt kỹ thuật là **lỗi đường dẫn**: tác tử tự thêm tiền tố `/sandbox/workspace/...` (trái `PATHS_NOTE`), gặp "not found" rồi dừng. Lỗi này gây thất bại toàn bộ ở `baseline/data-learn`, `baseline/logs-learn`, `baseline/logs-eval` và `subagents/data-learn`, nhưng xuất hiện **0 lần** trong 9 lần chạy `skills-auto` (kể cả `skills-auto-dev`). Giải thích hợp lý nhất: `SKILLS_NOTE` thêm một câu với đường dẫn tương đối ("Skills are in the folder skills/") vào system prompt, củng cố quy ước đường dẫn, tức là một hiệu ứng của **prompt**, không phải của nội dung skill. Khi không mắc lỗi đường dẫn, tác tử có dữ liệu để xử lý và chạy code (`skills-auto/data-learn` 8 lệnh `execute`, `data-eval` 5 lệnh), từ đó đạt thêm check kỹ thuật.
4. **Chi phí.** Token trung bình mỗi lần chạy: `baseline` 27.663, `subagents` 38.984 (+41%), `skills-auto` 71.503 (gấp 2,6 lần). Điểm trung bình 6 tác vụ: 0,208; 0,263; 0,344, tức 0,75; 0,67; 0,48 điểm trên 100 nghìn token. `baseline` hiệu quả nhất theo điểm trên token (một phần vì các lần chạy thất bại sớm rất rẻ, khoảng 5.400 token); `skills-auto` đạt điểm cao nhất nhưng đắt nhất. Đa tác tử: mọi lần giao việc trong `subagents` đều chọn `implementer` (5 lần, khác với `gpt-4.1-mini` luôn chọn `general-purpose`), nhưng tác tử chính không kiểm chứng kết quả: ở `subagents/logs-learn`, `errors.json` do subagent viết sai cấu trúc (`valid_structure: structure: missing keys or wrong types`) mà tác tử chính vẫn báo đã làm "adhering to Acme's log-triage conventions". `explorer` và `reviewer` không được gọi lần nào. Đa tác tử tốn token đến mức vượt giới hạn tốc độ của tài khoản (`subagents/data-eval`, mục 7), một chi phí vận hành thực tế. Trong thí nghiệm này đa tác tử không đáng chi phí: chênh lệch +0,11 trên tác vụ đánh giá đến từ một tác vụ, trong khi `baseline/data-eval` thất bại vì tác tử chính giao cho `general-purpose` rồi chấp nhận một `answer.json` mà chính nó mô tả là "contains placeholders".
5. **Rò rỉ và quá khớp.** Ba skill không chứa định danh hay số liệu của tác vụ đánh giá (`validate_skill` đạt; `tests/test_regressions.py`, `CHANGELOG.md`, `## Unreleased` là quy ước được phép). Skill chỉ khớp với họ `code`. Phòng tránh: curator chỉ đọc `role == "learn"`; giả thuyết và đóng băng trước khi chạy tác vụ đánh giá; `run_isolated.ps1` che mọi tác vụ khác, tài liệu và `.env` khỏi shell của tác tử. Đã kiểm tra: không vết nào chứa `check.py` hay đọc tác vụ khác.
6. **Nhiễu.** Cùng bộ skill trên tác vụ học: Phần 3.4 (`skills-auto-dev`) 6/10, 3/8, 1/9 và sau đóng băng 6/10, 3/8, 1/9, chênh lệch điểm 0; token trung bình 40.073 so với 78.332 (gần gấp đôi). Nhiễu điểm trên tác vụ học thấp, nhưng nhiễu hành vi lớn: `code-eval` của cùng điều kiện dao động 3/11 đến 7/11 qua các lần chạy lại (do lỗi đệ quy và lỗi kết nối), và việc mắc hay không mắc lỗi đường dẫn quyết định cả một tác vụ (0 điểm hoặc vài check). Vì vậy các chênh lệch 0,04-0,15 giữa các điều kiện trên tác vụ đánh giá chỉ tương đương 1-3 check của một tác vụ và không đủ tin cậy để xếp hạng; điều chắc chắn là không điều kiện nào đạt check quy ước nào.

## 9. Hạn chế và tính hợp lệ

1. **Mỗi cấu hình chạy một lần, chỉ 3 tác vụ mỗi vai trò.** Chênh lệch giữa điều kiện chỉ 1-3 check; với n = 1 không có khoảng tin cậy và thứ hạng có thể đảo khi chạy lại (mục 8.6).
2. **Giới hạn tốc độ và lỗi hạ tầng.** Tài khoản bị giới hạn 30.000 token/phút; `subagents/data-eval` không hoàn tất được (điểm là chặn dưới) và nhiều lần chạy phải chạy lại. Điều kiện tốn token nhiều (đa tác tử) bị ảnh hưởng nhiều nhất, nên so sánh có thể thiên lệch bất lợi cho `subagents`.
3. **Một mô hình duy nhất (`gpt-4o`).** Kết quả nhạy với mô hình: với `gpt-4.1-mini` (chuỗi trước, đã hủy) không skill nào được đọc và subagent tự định nghĩa không được chọn. Lỗi đường dẫn `/sandbox/` là đặc thù của `gpt-4o` và chi phối kết quả.
4. **Nhiễu lẫn với khác biệt prompt.** `skills-auto` khác `baseline` ở system prompt (`SKILLS_NOTE`); hiệu ứng tránh lỗi đường dẫn có thể đến từ câu này chứ không phải từ skill, và không tách được với một lần chạy.
5. **Cách ly không hoàn toàn.** `LocalShellBackend` chạy lệnh thật với cùng quyền của bộ chấm; `run_isolated.ps1` che các tác vụ khác, tài liệu và `.env`, nhưng tác tử vẫn có thể đọc `check.py` của chính tác vụ đang làm (không xảy ra, đã `grep`).
6. **Giả thuyết không hoàn toàn "mù".** Quy trình được chạy lại nhiều lần (Phụ lục); giả thuyết của chuỗi này được viết sau khi đã thấy điểm tác vụ đánh giá của các chuỗi trước (mô hình khác), dù được suy ra từ số liệu tác vụ học của chuỗi hiện tại.
7. **Tác vụ có quy ước ẩn; curator chạy một lần.** Mỗi tác vụ đánh giá thêm một quy ước mới mà không phương pháp nào biết trước; bộ skill là một mẫu của curator, chỉ phủ họ `code` và không phủ nhóm lỗi chiếm đa số (đường dẫn).

## 10. Kết luận

Với `gpt-4o`, không điều kiện nào đạt được check quy ước nào (0/21 ở cả ba điều kiện), nên skill tự sinh không truyền được tri thức quy ước dù tác tử có đọc skill ở 3/6 lần chạy: skill được đọc nhưng không được làm theo. `skills-auto` có điểm cao nhất (đánh giá 0,33 so với 0,18 của `baseline`) nhờ thêm check kỹ thuật, và vết cho thấy nguyên nhân hợp lý nhất là `SKILLS_NOTE` giúp tác tử tránh lỗi đường dẫn `/sandbox/`, không phải nội dung skill; chi phí của nó gấp 2,6 lần `baseline`. Đa tác tử dùng đúng subagent `implementer` nhưng tác tử chính không kiểm chứng báo cáo, tốn thêm 41% token và chạm giới hạn tốc độ. Với một lần chạy mỗi cấu hình, các chênh lệch điểm chỉ là 1-3 check và chưa đủ tin cậy để xếp hạng. Đề xuất: đưa quy ước đường dẫn và bước kiểm chứng bắt buộc (gọi `reviewer` hoặc đọc lại tệp đầu ra) vào harness, và lặp mỗi cấu hình ít nhất 3 lần.

## Phụ lục

- Lệnh đã chạy (theo thứ tự; mỗi lệnh `run_isolated.ps1` chạy từng tác vụ qua một vòng lặp nghỉ 60 giây trước mỗi lần chạy và chạy lại tác vụ khi `run.json` ghi lỗi 429, vì tài khoản OpenAI bị giới hạn 30.000 token/phút cho `gpt-4o`):
  1. `pwsh ./run_isolated.ps1 -Condition baseline -Tasks learn`
  2. `pwsh ./run_isolated.ps1 -Condition subagents -Tasks learn`
  3. `docker run --rm --env-file .env -v "${PWD}:/lab" lab-deepagents python -B -m lab.curator`
  4. `pwsh ./run_isolated.ps1 -Condition skills-auto -Tasks learn`, rồi đổi tên `results/skills-auto` thành `results/skills-auto-dev`
  5. `git commit -m "hypotheses"`; `git commit --allow-empty -m "freeze skills"`; `git tag freeze`
  6. `pwsh ./run_isolated.ps1 -Condition baseline -Tasks eval`
  7. `pwsh ./run_isolated.ps1 -Condition subagents -Tasks eval`
  8. `pwsh ./run_isolated.ps1 -Condition skills-auto -Tasks all`
  9. Chạy lại các lần có `error`: `subagents/data-eval`, `baseline/code-eval`, `skills-auto/code-eval` (mục 7)
  10. `python scripts/verify_freeze.py` (trên WSL), `python -m lab.compare > report/table.md`, `python scripts/check_breakdown.py`
- Chạy lại do giới hạn tốc độ (429) trước đóng băng: `baseline/code-learn` bị 429 ba lần, kết quả trong báo cáo là lần thứ tư (không lỗi). Sau đóng băng: xem mục 7.
- Sự cố và cách xử lý (các chuỗi chạy trước bị hủy, không dùng số liệu):
  1. **Rò rỉ khỏi sandbox.** Container mount cả kho vào `/lab`; shell `execute` (`LocalShellBackend`) chạy lệnh thật nên trong chuỗi chạy đầu tiên tác tử đã `cd /lab` và đọc `GUIDE.md`, `RUBRIC.md`, `tasks/*/check.py`, kể cả `tasks/data-eval/check.py`. Kết quả và skill của chuỗi đó bị xóa. Khắc phục: `run_isolated.ps1` chạy mỗi tác vụ trong một container riêng và che (bằng volume rỗng) mọi tác vụ khác, tài liệu `.md`, `.env`, `.git`, `report/`, `results/` của điều kiện khác và `skills/` (trừ `skills-auto`). Đã kiểm chứng: không vết nào của chuỗi hợp lệ chứa `check.py` hay tác vụ khác.
  2. **Xuống dòng CRLF.** `git core.autocrlf=true` trên Windows đổi 33 tệp trong `tasks/` sang CRLF, làm check `tests_not_modified` (so sha256 với bản LF) luôn thất bại và thay đổi dữ liệu `app.log`, `orders.json`. Khắc phục: `git config --local core.autocrlf false` và khôi phục tệp về LF (`sales.csv` vốn CRLF trong kho, giữ nguyên).
  3. **Đổi mô hình.** DeepSeek hết số dư (HTTP 402); chuỗi chạy bằng `gpt-4.1-mini` cho thấy mô hình không đọc skill và không chọn subagent tự định nghĩa; toàn bộ quy trình được chạy lại từ đầu bằng `gpt-4o` (bộ kết quả, skill và tag `freeze` trước bị xóa).
  4. **Mở rộng runner.** `run_task` dùng `agent.stream(..., stream_mode="values")` (mở rộng tùy chọn trong `03_runner.md`, ghi chú 8) để vẫn có vết khi gặp lỗi.
- Thử thách mở rộng: không thực hiện.
