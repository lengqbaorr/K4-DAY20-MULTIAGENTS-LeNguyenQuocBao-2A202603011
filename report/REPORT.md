# Báo cáo Lab: Self evolving Agentic

## 1. Thông tin nhóm và cấu hình

| Họ tên | Mã sinh viên | Phần đóng góp |
|---|---|---|
| Lê Nguyễn Quốc Bảo | 2A202603011 | Toàn bộ |

- Mô hình: `LAB_MODEL=openai:gpt-4.1-mini`, `LAB_TEMPERATURE=0`, `recursion_limit=60` (mặc định của runner).
- Deep Agents 0.7.21; Windows 11 + Docker (`python:3.12-slim`, image `lab-deepagents` từ `Dockerfile`). Mọi lần chạy tác tử đi qua `run_isolated.ps1` (Phụ lục).
- Số lần chạy tác vụ: 21 = 9 trước đóng băng (baseline 3, subagents 3, skills-auto-dev 3) + 12 sau đóng băng (baseline 3, subagents 3, skills-auto 6). Không lần chạy nào có `error` hay phải chạy lại.
- Commit của tag `freeze`: `a5bcad6` (commit `hypotheses`: `aba53da`).

## 2. Giả thuyết (commit TRƯỚC tag `freeze`, Phần 4.0)

Căn cứ: mục 4 (9/14 check thất bại là quy ước `rule_` không có trong đề; lỗi kỹ thuật chỉ ở `logs-learn`), mục 5, mục 6 (cả 3 skill chỉ phủ họ `code`; `skills_read = 0` ở cả 3 lần chạy Phần 3.4); SkillsBench (skill do mô hình tự sinh trung bình không có lợi); SkillEvolBench (lợi ích trên tác vụ học thường không chuyển sang tác vụ mới); bài viết của Anthropic về hệ thống nghiên cứu đa tác tử (đa tác tử tốn nhiều token hơn đáng kể).

- H1 (subagents so với baseline): `subagents` **không** cao hơn `baseline` trên tác vụ đánh giá và tốn token nhiều hơn. Lý do: ở tác vụ học, `subagents` đạt 12/18 check kỹ thuật so với 13/18 của `baseline`, token trung bình +39% (61.677 so với 44.397); lời giao việc không thể chứa quy ước `rule_` (đề không nêu), nên subagent không xử lý được nhóm lỗi chiếm đa số (E); tác tử chính không kiểm chứng báo cáo của subagent.
- H2 (skills-auto so với baseline): `skills-auto` **không** cải thiện rõ rệt trên tác vụ đánh giá; nếu có thì chỉ ở `code-eval` và chỉ ở ba quy ước cũ mà skill mô tả, không ở quy ước mới của tác vụ đánh giá và không ở họ `data`, `logs`. Lý do: cả 3 skill chỉ rút ra từ `code-learn`; ở Phần 3.4 tác tử không đọc skill nào và điểm trùng `baseline` (7/10, 5/8, 1/9).
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
| data-learn | rule_money_in_cents | E | `RULE: money values in answer.json are integer cents (1606.67 USD is written 160667).` |
| data-learn | rule_meta_block | E | `RULE: answer.json has an object meta = {"source": <input file name>, "rows_in": ...` |
| data-learn | rule_clean_csv | E | `RULE: write workspace/clean.csv with the header order_id,timestamp_utc,region,amount_cents` |
| logs-learn | rule_service_names | E | `RULE: service names in the output are lower-case with '-' replaced by '_'` |
| logs-learn | rule_sorted_errors | E | `RULE: errors is sorted by service, then by timestamp_utc, ascending.` |
| logs-learn | rule_schema_header | E | `RULE: the top-level object has "schema_version": 2 and "generated_by": "log-triage".` |
| logs-learn | entry_count | B | `wrong number of entries (got 20)`. Vết: chỉ 3 tool call: hai lần `read_file` trên `app.log` rồi `write_file` thẳng `errors.json` gõ tay; không viết hay chạy script, không đối chiếu. |
| logs-learn | timestamps_utc | D | `8/25 timestamps match`: không chuẩn hóa múi giờ. |
| logs-learn | exception_fields | D | `17 wrong exception values`: bỏ sót stack trace nhiều dòng. |
| logs-learn | repeat_counts | D | `17 wrong repeat_count values`: bỏ sót dòng lặp. |
| logs-learn | counts_by_service | B | `counts_by_service: wrong values`: hệ quả của các lỗi trên, không kiểm tra lại. |

Nhận xét:
- Nhóm E chiếm đa số: 9/14 check thất bại; cả ba tác vụ đạt 0/9 check quy ước. Nguyên nhân chung: quy ước không có trong đề, tác tử chỉ biết được qua phản hồi. Skill có thể phòng ngừa nhóm này nếu rút ra đúng quy ước **và** được đọc.
- Bằng chứng phủ định cho A-D (`scripts/check_breakdown.py`): baseline đạt 13/18 check kỹ thuật trên tác vụ học; mọi check kỹ thuật của `code-learn` (7/7) và `data-learn` (5/5) đạt. Lỗi kỹ thuật chỉ ở `logs-learn` (1/6), nơi tác tử không dùng `execute` lần nào (0 lệnh) mà gõ tay kết quả (B, D); ở `code-learn` và `data-learn` tác tử có chạy lệnh (2 và 3 lệnh `execute`).
- Không có lỗi nhóm A, C, F ở baseline.

## 5. Điều kiện `subagents` (Phần 2.3)

- Subagent đã định nghĩa (`src/lab/subagents.py`): `explorer` (chỉ đọc; trích nguyên văn quy tắc, định dạng, docstring, liệt kê dữ liệu bẩn), `implementer` (chỉ sửa tệp được giao, chạy lại test, báo nguyên văn kết quả), `reviewer` (chỉ đọc; kiểm tra từng yêu cầu PASS/FAIL kèm bằng chứng). Lý do: tách đọc, làm và kiểm chứng để nhắm vào nhóm A, B, F.
- `subagent_calls`: `code-learn` 0, `data-learn` 1, `logs-learn` 1. Ở `code-learn` tác tử chính tự sửa và tự chạy test (2 lệnh `execute`), không giao việc dù `SUBAGENTS_NOTE` khuyến khích; nhiều khả năng vì tác vụ đủ nhỏ để tự làm trong vài bước. Ở hai tác vụ còn lại, tác tử chính giao **một** việc lớn (`"Analyze the sales data ..."`, `"Parse the log file ..."`) và không gọi `reviewer`. Cả 4 lần gọi `task` trong toàn thí nghiệm (2 ở tác vụ học, 2 ở tác vụ đánh giá) đều có `"subagent_type": "general-purpose"`, không lần nào chọn `explorer`, `implementer` hay `reviewer`. Đã kiểm chứng việc đăng ký bằng mô hình giả: mô tả công cụ `task` trong chế độ `subagents` liệt kê đủ `general-purpose`, `explorer`, `implementer`, `reviewer` kèm `description` của từng subagent; vậy việc không dùng subagent tự định nghĩa là lựa chọn của mô hình, không phải lỗi kết nối.
- Thông tin giao việc: lời giao việc chép yêu cầu của đề (đường dẫn, chỉ số cần tính, cấp log) nhưng không thể có quy ước `rule_`, nên subagent lặp lại đúng các lỗi E của baseline (0/9 check quy ước). Ở `logs-learn`, sau khi subagent trả về, tác tử chính lại tự `write_file` một `errors.json` gõ tay, chỉ có 11 bản ghi (`entry_count: got 11`, `3/25 timestamps match`); kết quả kém hơn baseline ở từng chỉ số. Ở `code-learn`, không có subagent nhưng trượt thêm `csv_quoting_follows_docstring` (`to_csv_row returned 'Desk, large "oak",10.00,2'`, nhóm A: bỏ qua docstring) so với baseline.
- Token và thời gian: token trung bình tác vụ học 61.677 (subagents) so với 44.397 (baseline), +39%; riêng `data-learn` 97.616 so với 59.042 (+65%) với cùng điểm 5/8. Check kỹ thuật 12/18 so với 13/18.

## 6. Self-evolving: skill do curator sinh (Phần 3)

- Số lần chạy curator: 1 (trên `results/baseline`, chỉ tác vụ học). Không xóa skill nào, không chạy lại: cả ba đúng với `detail` của bot đánh giá và vô hại; `skills_read = 0` không do `description` (xem dưới) nên chạy lại curator không có căn cứ.

| Skill | Tổng quát hay riêng cho tác vụ học? | Đúng hay sai (nêu chỗ sai nếu có) | Độ dài, `description` và `skills_read` ở Phần 3.4 |
|---|---|---|---|
| add-regression-tests-for-fixes | Tổng quát cho mọi tác vụ sửa lỗi; `tests/test_regressions.py` là quy ước được phép. Chỉ phủ họ `code`. | Đúng với `rule_regression_tests`. Không có chỉ dẫn sai; "Update the regression test file incrementally" hơi thừa. | 8 dòng; "Use when fixing bugs ..." nêu đúng tình huống; `skills_read` = 0 ở cả 3 tác vụ. |
| enforce-complete-type-annotations | Tổng quát. Chỉ phủ họ `code`. | Đúng với `rule_type_hints`. "Run a static type checker (e.g., mypy)" có thể không làm được (mypy không cài sẵn trong sandbox). | 7 dòng; `description` rõ; `skills_read` = 0. |
| update-changelog-for-fixes | Tổng quát; định dạng `- fix(<function name>):` và `## Unreleased` là quy ước được phép. Chỉ phủ họ `code`. | Đúng với `rule_changelog`. "Save and commit" thừa (tác vụ không dùng git). Không nhắc tối thiểu 3 bullet. | 7 dòng; `description` rõ; `skills_read` = 0. |

- Không skill nào phủ quy ước của `data` (tiền tính bằng cent, khối `meta`, `clean.csv`) hay `logs` (tên dịch vụ, sắp xếp, `schema_version`) dù prompt curator có đủ `detail` của cả ba tác vụ.
- Phần 3.4 (`results/skills-auto-dev`): 7/10, 5/8, 1/9, trùng điểm baseline; `skills_read = 0`, `skills_modified = false` ở cả ba. Kiểm chứng harness bằng mô hình giả (`ScriptedChatModel`) với `build_agent(..., use_skills=True)`: system prompt có `SKILLS_NOTE` ("As your FIRST action, read the SKILL.md of every skill whose description could apply") và danh sách 3 skill kèm đường dẫn `/skills/<name>/SKILL.md`. Vậy `skills_read = 0` là do `gpt-4.1-mini` không làm theo chỉ dẫn, không phải do skill không được nạp hay `description` quá hẹp.

## 7. Kết quả so sánh (Phần 4.3, 4.4)

`report/table.md` (sinh bởi `python -m lab.compare`):

| Task | baseline | subagents | skills-auto |
|---|---|---|---|
| code-learn | 7/10 | 6/10 | 7/10 |
| data-learn | 5/8 | 5/8 | 5/8 |
| logs-learn | 1/9 | 1/9 | 1/9 |
| code-eval | 7/11 | 7/11 | 7/11 |
| data-eval | 3/9 | 1/9 | 5/9 |
| logs-eval | 1/10 | 0/10 | 6/10 |
| **Mean score - learning tasks** | 0.48 | 0.45 | 0.48 |
| **Mean score - evaluation tasks** | 0.36 | 0.25 | 0.60 |
| **Mean tokens per run** | 40,484 | 44,243 | 60,264 |
| **Runs that read a skill** | 0/6 | 0/6 | 0/6 |

`python scripts/check_breakdown.py`:

```text
condition     role    technical  house rules  mean tokens  read a skill
baseline      eval     11/18         0/12          36,570      0/3
baseline      learn    13/18         0/9           44,397      0/3
subagents     eval      8/18         0/12          26,810      0/3
subagents     learn    12/18         0/9           61,677      0/3
skills-auto   eval     18/18         0/12          85,988      0/3
skills-auto   learn    13/18         0/9           34,540      0/3
```

- Không lần chạy nào có `error`; `skills_modified = false` ở mọi lần chạy.
- `python scripts/verify_freeze.py` (chạy trên Linux/WSL): `checked 6 runs of skill conditions: OK`. Trên Windows script báo nhầm "skills differ from the frozen skills" vì `hash_skills` băm cả đường dẫn tương đối (`\` trên Windows, `/` trong container Linux nơi các lần chạy diễn ra); nội dung skill không đổi. Cần chạy script trên Linux/macOS như README yêu cầu.
- Vết `code-eval` của cả ba điều kiện có dòng `/lab/tasks/code-eval/workspace/tests/test_bookings.py` trong traceback của pytest. Đây không phải rò rỉ: tệp test được nạp từ sandbox (`/tmp/.../workspace/tests/test_bookings.py`), còn đường dẫn `/lab/...` là tên tệp nằm sẵn trong `__pycache__` mà `prepare_sandbox` sao chép cùng workspace (sinh ra khi chạy pytest của lab trên kho). Các `__pycache__` này đã được xóa sau đó.

## 8. Phân tích

1. **Học và đánh giá.** Tác vụ học: không điều kiện nào hơn `baseline` (0,48; `subagents` 0,45; `skills-auto` 0,48 với điểm từng tác vụ trùng `baseline`). Tác vụ đánh giá: `subagents` kém hơn (0,25 so với 0,36), `skills-auto` cao hơn (0,60). `skills-auto` là trường hợp ngược với quá khớp: không cải thiện tác vụ học nhưng cải thiện tác vụ đánh giá. Vì `skills_read = 0` ở mọi lần chạy, sự cải thiện này **không** đến từ nội dung skill (xem câu 3), nên không phải bằng chứng của học chuyển giao. Đối chiếu giả thuyết: H1 đúng (`subagents` không hơn, thấp hơn 0,11 trên tác vụ đánh giá). H2 sai về điểm số (`skills-auto` cao hơn 0,24) nhưng đúng về cơ chế dự đoán: skill không được đọc và không giúp check quy ước nào. H3 đúng với `baseline` (0,36 ≤ 0,48) và `subagents` (0,25 ≤ 0,45), sai với `skills-auto` (0,60 > 0,48).
2. **Kỹ thuật và quy ước.** Check quy ước: 0/9 (học) và 0/12 (đánh giá) ở cả ba điều kiện. Skill không giúp nhóm check nào: ở `code-eval`, `skills-auto` vẫn trượt đúng ba quy ước cũ mà skill mô tả (`rule_type_hints`, `rule_regression_tests`, `rule_changelog`) và quy ước mới `rule_version_bump`. Quy ước mới của tác vụ đánh giá (`rule_version_bump`, `rule_sorted_keys_format`, `rule_source_line`) không thể được skill giúp vì không xuất hiện trong phản hồi nào của tác vụ học; quy ước cũ cũng không được giúp vì skill không được đọc. Toàn bộ chênh lệch giữa các điều kiện nằm ở check **kỹ thuật** (đánh giá: 11/18, 8/18, 18/18).
3. **Cơ chế qua vết.** `skills_read = 0` ở cả 9 lần chạy có skill (3 lần `skills-auto-dev` và 6 lần `skills-auto`). Kiểm chứng bằng mô hình giả: system prompt có danh sách 3 skill và `SKILLS_NOTE`; vậy `gpt-4.1-mini` không làm theo chỉ dẫn đọc skill. Check skill lẽ ra giúp nhưng không giúp: `rule_changelog` ở `skills-auto/code-eval`; skill `update-changelog-for-fixes` mô tả đúng định dạng `- fix(<function name>):` dưới `## Unreleased`, nhưng vết không có `read_file` nào vào `/skills/` và `CHANGELOG.md` không được sửa. Không có check nào mà **nội dung** skill giúp đạt. Biến số thật sự quyết định điểm kỹ thuật là **tác tử có viết và chạy code hay không**: `skills-auto/data-eval` (5 lệnh `execute`) đạt 5/5 check kỹ thuật, `baseline/data-eval` (1 lệnh) đạt 3/5, `subagents/data-eval` (0 lệnh) đạt 1/5; `skills-auto/logs-eval` (1 lệnh) đạt 6/6 check kỹ thuật, còn `baseline/logs-eval` và `subagents/logs-eval` (0 lệnh, `write_file` gõ tay) đạt 1/6 và 0/6. Điều kiện `skills-auto` khác `baseline` ở system prompt (thêm `SKILLS_NOTE` và danh sách skill); với một lần chạy mỗi cấu hình, không tách được hiệu ứng của phần prompt này khỏi nhiễu (câu 6).
4. **Chi phí.** Token trung bình mỗi lần chạy: `baseline` 40.484, `subagents` 44.243 (+9%), `skills-auto` 60.264 (+49%). Điểm trung bình 6 tác vụ: 0,418; 0,347; 0,538, tức 1,03; 0,78; 0,89 điểm trên 100 nghìn token. `baseline` hiệu quả nhất theo điểm trên token; `skills-auto` đạt điểm cao nhất nhưng tốn nhiều token nhất (85.988 token mỗi lần chạy trên tác vụ đánh giá, chủ yếu do viết và chạy code: `data-eval` 122.956 token). Đa tác tử không đáng chi phí: tốn thêm token mà điểm thấp nhất. Cơ chế (vết): ở `subagents/logs-eval`, subagent để lại `errors.json` rỗng và tác tử chính kết thúc mà không sửa (0/10, kể cả `valid_structure`); ở `subagents/data-eval`, tác tử chính chép số liệu của subagent vào `answer.json` mà không kiểm chứng (1/9). Subagent `reviewer` không được gọi lần nào.
5. **Rò rỉ và quá khớp.** Ba skill không chứa định danh hay số liệu của tác vụ đánh giá (`validate_skill` đạt; `tests/test_regressions.py`, `CHANGELOG.md`, `## Unreleased` là quy ước được phép). Chúng chỉ khớp với họ `code` nhưng không gây hại đo được. Phòng tránh: curator chỉ đọc `role == "learn"`; viết giả thuyết và đóng băng trước khi chạy tác vụ đánh giá; `run_isolated.ps1` che mọi tác vụ khác, tài liệu và `.env` khỏi shell của tác tử. Đã kiểm tra: không vết nào chứa `check.py`; dòng `-eval` duy nhất là đường dẫn trong `__pycache__` của chính tác vụ đang chạy (mục 7). Chuỗi chạy đầu tiên, trước khi có biện pháp cách ly, đã bị hủy vì tác tử đọc được `tasks/data-eval/check.py` (Phụ lục).
6. **Nhiễu.** Cùng bộ skill trên tác vụ học: Phần 3.4 (`skills-auto-dev`) 7/10, 5/8, 1/9 và sau đóng băng 7/10, 5/8, 1/9: chênh lệch điểm 0; token trung bình 45.580 so với 34.540 (-24%). Nhiễu điểm trên tác vụ học thấp vì kết quả bị chi phối bởi lỗi có tính hệ thống (quy ước; không chạy code ở `logs`). Trên tác vụ đánh giá, cùng một tác vụ dao động lớn giữa các điều kiện mà không điều kiện nào đọc skill: `data-eval` 3/9, 1/9, 5/9; `logs-eval` 1/10, 0/10, 6/10, tương ứng với việc tác tử có chọn chạy code hay không. Do đó chênh lệch +0,24 của `skills-auto` và -0,11 của `subagents` so với `baseline` trên tác vụ đánh giá đều nằm trong phạm vi một quyết định chiến lược (chạy code hay gõ tay) của một lần chạy, và không đủ tin cậy để quy cho skill hay cho đa tác tử.

## 9. Hạn chế và tính hợp lệ

1. **Mỗi cấu hình chạy một lần, chỉ 3 tác vụ mỗi vai trò.** Hai tác vụ (`data-eval`, `logs-eval`) quyết định gần như toàn bộ chênh lệch điểm đánh giá; với n = 1 không có khoảng tin cậy, nên kết luận chỉ là định tính.
2. **Một mô hình duy nhất (`gpt-4.1-mini`).** Mô hình bỏ qua chỉ dẫn đọc skill và thường không chạy code ở họ `logs`. Kết luận "nội dung skill không có tác dụng" có thể chỉ đúng với mô hình kém tuân thủ chỉ dẫn.
3. **Nhiễu lẫn với khác biệt prompt.** `skills-auto` khác `baseline` ở system prompt; không tách được hiệu ứng của `SKILLS_NOTE` (khuyến khích cẩn thận hơn) khỏi nhiễu ngẫu nhiên khi chỉ có một lần chạy.
4. **Cách ly không hoàn toàn.** `LocalShellBackend` chạy lệnh thật với cùng quyền của bộ chấm; `run_isolated.ps1` che các tác vụ khác, tài liệu và `.env`, nhưng tác tử vẫn có thể đọc `check.py` của chính tác vụ đang làm (không xảy ra trong chuỗi hợp lệ, đã `grep`).
5. **Giả thuyết không hoàn toàn "mù".** Toàn bộ quy trình được chạy lại lần hai (Phụ lục); giả thuyết của lần chạy này được viết sau khi đã thấy điểm tác vụ đánh giá của lần chạy trước (cùng mô hình, cùng mã). Giả thuyết được viết từ số liệu tác vụ học của lần chạy hiện tại và giữ dự đoán của lần trước, nhưng không thể loại trừ hoàn toàn ảnh hưởng.
6. **Tác vụ có quy ước ẩn do giảng viên thiết kế; curator chạy một lần.** 9/14 check thất bại ở baseline là quy ước không có trong đề; mỗi tác vụ đánh giá thêm một quy ước mới mà không phương pháp nào biết trước. Bộ skill là một mẫu của curator, chỉ phủ họ `code`.

## 10. Kết luận

Với `gpt-4.1-mini`, đa tác tử không cải thiện điểm so với tác tử mặc định (tác vụ đánh giá 0,25 so với 0,36) và tốn thêm token, vì tác tử chính tin báo cáo của subagent mà không kiểm chứng. `skills-auto` đạt điểm đánh giá cao nhất (0,60) nhưng tác tử không đọc skill nào (`skills_read = 0`) và không đạt check quy ước nào, nên cải thiện này đến từ việc tác tử chọn viết và chạy code ở `data-eval` và `logs-eval`, không phải từ tri thức trong skill. Với một lần chạy mỗi cấu hình, chênh lệch này chưa đủ tin cậy để quy cho điều kiện thí nghiệm. Biến số quyết định điểm kỹ thuật trong mọi điều kiện là tác tử có chạy code để kiểm chứng hay không. Đề xuất tiếp theo: buộc kiểm chứng ở tầng harness (bắt buộc chạy script hoặc gọi `reviewer` trước khi kết thúc) và lặp mỗi cấu hình ít nhất 3 lần để đo nhiễu.

## Phụ lục

- Lệnh đã chạy (theo thứ tự):
  1. `pwsh ./run_isolated.ps1 -Condition baseline -Tasks learn`
  2. `pwsh ./run_isolated.ps1 -Condition subagents -Tasks learn`
  3. `docker run --rm --env-file .env -v "${PWD}:/lab" lab-deepagents python -B -m lab.curator`
  4. `pwsh ./run_isolated.ps1 -Condition skills-auto -Tasks learn`, rồi đổi tên `results/skills-auto` thành `results/skills-auto-dev`
  5. `git commit -m "hypotheses"`; `git commit --allow-empty -m "freeze skills"`; `git tag freeze`
  6. `pwsh ./run_isolated.ps1 -Condition baseline -Tasks eval`
  7. `pwsh ./run_isolated.ps1 -Condition subagents -Tasks eval`
  8. `pwsh ./run_isolated.ps1 -Condition skills-auto -Tasks all`
  9. `python scripts/verify_freeze.py` (trên WSL), `python -m lab.compare > report/table.md`, `python scripts/check_breakdown.py`
- Sự cố và cách xử lý (các chuỗi chạy trước bị hủy, không dùng số liệu):
  1. **Rò rỉ khỏi sandbox.** Container mount cả kho vào `/lab`; shell `execute` (`LocalShellBackend`) chạy lệnh thật nên trong chuỗi chạy đầu tiên tác tử đã `cd /lab` và đọc `GUIDE.md`, `RUBRIC.md`, `tasks/*/check.py`, kể cả `tasks/data-eval/check.py`. Toàn bộ kết quả và skill của chuỗi đó bị xóa. Khắc phục: `run_isolated.ps1` chạy mỗi tác vụ trong một container riêng và che (bằng volume rỗng) mọi tác vụ khác, tài liệu `.md`, `.env`, `.git`, `report/`, `results/` của điều kiện khác và `skills/` (trừ `skills-auto`). Đã kiểm chứng: không vết nào của chuỗi hợp lệ chứa `check.py` hay `-eval`.
  2. **Xuống dòng CRLF.** `git core.autocrlf=true` trên Windows đổi 33 tệp trong `tasks/` sang CRLF, làm check `tests_not_modified` (so sha256 với bản LF) luôn thất bại và thay đổi dữ liệu `app.log`, `orders.json`. Khắc phục: `git config --local core.autocrlf false` và khôi phục tệp về LF (`sales.csv` vốn CRLF trong kho, giữ nguyên). Đã kiểm chứng: `check.py` trên workspace chưa sửa đạt `tests_not_modified`.
  3. **Đổi mô hình.** DeepSeek hết số dư (HTTP 402) giữa chừng; toàn bộ chạy lại từ đầu bằng `gpt-4.1-mini`.
  4. **Chạy lại toàn bộ.** Sau khi rà lại mã, toàn bộ quy trình (Phần 1 đến 4) được chạy lại từ đầu với bộ kết quả, skill và tag `freeze` mới; bộ trước bị xóa.
  5. **Mở rộng runner.** `run_task` dùng `agent.stream(..., stream_mode="values")` (mở rộng tùy chọn trong `03_runner.md`, ghi chú 8) để vẫn có vết khi gặp lỗi như `GraphRecursionError`.
- Thử thách mở rộng: không thực hiện.
