# Báo cáo Lab: Self evolving Agentic

## 1. Thông tin nhóm và cấu hình

| Họ tên | Mã sinh viên | Phần đóng góp |
|---|---|---|
| Lê Nguyễn Quốc Bảo | 2A202603011 | Toàn bộ |

- Mô hình: `LAB_MODEL=openai:gpt-4.1-mini`, `LAB_TEMPERATURE=0`, `recursion_limit=60` (mặc định của runner).
- Deep Agents 0.7.21; Windows 11 + Docker (`python:3.12-slim`, image `lab-deepagents` từ `Dockerfile`). Mọi lần chạy tác tử đi qua `run_isolated.ps1` (xem Phụ lục, mục "Sự cố và cách xử lý").
- Số lần chạy tác vụ đã dùng (chuỗi hợp lệ cuối cùng, trước đóng băng): 9 (baseline 3, subagents 3, skills-auto-dev 3). Các chuỗi chạy trước đó bị hủy vì lỗi môi trường, không dùng trong báo cáo (Phụ lục).
- Commit của tag `freeze`: (điền sau Phần 4.1)

## 2. Giả thuyết (commit TRƯỚC tag `freeze`, Phần 4.0)

Căn cứ: mục 4 (đa số lỗi là quy ước `rule_` không có trong đề, cộng lỗi kỹ thuật của họ `logs`), mục 5, mục 6 (skill chỉ phủ họ `code` và `skills_read = 0` ở cả 3 lần chạy Phần 3.4), SkillsBench (skill do mô hình tự sinh trung bình không có lợi), SkillEvolBench (lợi ích trên tác vụ học thường không chuyển sang tác vụ mới), bài viết của Anthropic về hệ thống nghiên cứu đa tác tử (tốn ~15 lần token).

- H1 (subagents so với baseline): `subagents` **không** cao hơn `baseline` trên tác vụ đánh giá (chênh lệch điểm trung bình trong khoảng ±0,1) nhưng tốn token nhiều hơn. Lý do: ở tác vụ học, `subagents` đạt 11/18 check kỹ thuật so với 13/18 của `baseline` với token trung bình cao hơn ~24% (75.469 so với 61.088); lời giao việc cho subagent không chứa quy ước `rule_` (vì đề không nêu), nên subagent không thể làm tốt hơn tác tử chính ở nhóm lỗi chiếm đa số (E).
- H2 (skills-auto so với baseline): `skills-auto` **không** cải thiện rõ rệt trên tác vụ đánh giá; nếu có cải thiện thì chỉ ở `code-eval` và chỉ ở các check quy ước cũ (type hints, test hồi quy, CHANGELOG), không ở quy ước mới của tác vụ đánh giá và không ở họ `data`, `logs`. Lý do: cả 3 skill chỉ rút ra từ `code-learn`; ở Phần 3.4 tác tử không đọc skill nào (`skills_read = 0` cả 3 tác vụ) dù danh sách skill có trong system prompt, và điểm bằng đúng `baseline` (7/10, 5/8, 1/9). Phù hợp với SkillsBench.
- H3 (tác vụ học so với tác vụ đánh giá): điểm trên tác vụ đánh giá của cả ba điều kiện **thấp hơn hoặc bằng** tác vụ học, vì tác vụ đánh giá thêm một quy ước mới mà không skill nào và không lời giao việc nào biết trước; bất kỳ lợi thế nào của `skills-auto` trên tác vụ học sẽ không chuyển trọn sang tác vụ đánh giá (SkillEvolBench).

## 3. Làm quen Deep Agents (Phần 0.3)

1. Tác tử mặc định có 9 công cụ: công cụ tệp `ls`, `read_file`, `write_file`, `edit_file`, `delete`, `glob`, `grep`; shell `execute`; giao việc `task`. Công cụ chạy lệnh là `execute`.
2. Mô tả của `task` giới thiệu subagent `general-purpose` là tác tử đa năng "for researching complex questions, searching for files and content, and executing multi-step tasks", có cùng khả năng với tác tử chính. Subagent **không** thấy hội thoại của tác tử chính: "Each invocation is stateless by default: the agent sees only the prompt you give it and returns a single final report."
3. Câu từ `task`: "Put full detail in the prompt and state exactly what it should return". Câu từ `execute`: "You MUST avoid using search commands like find and grep. Instead use the grep, glob tools to search." Lưu ý: mô tả `execute` nói lệnh chạy "in an isolated sandbox", nhưng `LocalShellBackend` chạy lệnh thật trên hệ điều hành của runner; điều này dẫn tới sự cố rò rỉ ở Phụ lục.

## 4. Đường cơ sở và phân loại lỗi (Phần 2.2)

Nguồn: `results/baseline/*-learn/run.json` và `trace.md`.

| Tác vụ | Check thất bại | Nhóm lỗi (A-G) | Bằng chứng (trích ngắn từ `detail` hoặc vết) |
|---|---|---|---|
| code-learn | rule_type_hints | E | `RULE: every public function ... has type annotations on all parameters and on the return value.` |
| code-learn | rule_regression_tests | E | `RULE: add tests/test_regressions.py with one test function per bug you fixed (at least 3)` |
| code-learn | rule_changelog | E | `RULE: record each fix in CHANGELOG.md under the heading '## Unreleased' ...` |
| data-learn | rule_money_in_cents | E | `RULE: money values in answer.json are integer cents (1606.67 USD is written 1606...` |
| data-learn | rule_meta_block | E | `RULE: answer.json has an object meta = {"source": <input file name>, "rows_in" ...` |
| data-learn | rule_clean_csv | E | `RULE: write workspace/clean.csv with the header order_id,timestamp_utc,region,amount_cents` |
| logs-learn | rule_service_names, rule_sorted_errors, rule_schema_header | E | `RULE: service names ... lower-case with '-' replaced by '_'`; `errors is sorted by service, then by timestamp_utc`; `"schema_version": 2` |
| logs-learn | entry_count | B + D | `wrong number of entries (got 21)`. Vết: tác tử chỉ `read_file` hai lần trên `app.log` rồi `write_file` thẳng `errors.json` gõ tay, không viết hay chạy script phân tích (3 tool call). |
| logs-learn | timestamps_utc | D | `8/25 timestamps match`: không chuẩn hóa múi giờ của các dòng log. |
| logs-learn | exception_fields, repeat_counts | D | `17 wrong exception values`, `17 wrong repeat_count values`: bỏ sót stack trace nhiều dòng và dòng lặp. |
| logs-learn | counts_by_service | B | `counts_by_service: wrong values`: hệ quả của các lỗi trên, không có bước đối chiếu. |

Nhận xét:
- Nhóm E chiếm đa số: 9/14 check thất bại, và cả ba tác vụ đều đạt 0/9 check quy ước. Nguyên nhân chung: quy ước `rule_` không có trong đề, tác tử chỉ có thể biết qua phản hồi. Skill có thể phòng ngừa nhóm này **nếu** được rút ra đúng quy ước và **được đọc**.
- Bằng chứng phủ định cho A-D (`scripts/check_breakdown.py`): baseline đạt 13/18 check kỹ thuật trên tác vụ học; toàn bộ check kỹ thuật của `code-learn` (7/7) và `data-learn` (5/5) đạt. Lỗi kỹ thuật chỉ tập trung ở `logs-learn` (1/6), nơi tác tử không viết code mà gõ tay kết quả (B, D).
- Không có lỗi nhóm A, C, F ở baseline.

## 5. Điều kiện `subagents` (Phần 2.3)

- Subagent đã định nghĩa (`src/lab/subagents.py`): `explorer` (chỉ đọc; trích nguyên văn quy tắc, định dạng, docstring, liệt kê dữ liệu bẩn), `implementer` (chỉ sửa tệp được giao, chạy lại test, báo nguyên văn kết quả), `reviewer` (chỉ đọc; kiểm tra từng yêu cầu PASS/FAIL kèm bằng chứng). Lý do: tách đọc, làm và kiểm chứng để nhắm vào nhóm A, B, F.
- `subagent_calls`: 1 ở cả ba tác vụ (code-learn, data-learn, logs-learn). Tác tử chính luôn giao **một** việc lớn ("Fix the source code ...", "Parse the log file ...") rồi tự hoàn tất, không gọi `reviewer`.
- Thông tin giao việc: lời giao việc chép lại yêu cầu của đề (đường dẫn, định dạng) nhưng không thể có quy ước `rule_` (đề không nêu), nên subagent lặp lại đúng các lỗi E của baseline (1/9 check quy ước). Ở `logs-learn`, sau khi subagent trả về, tác tử chính tự `write_file` một `errors.json` chỉ có 1 bản ghi (`entry_count: got 1`) mà không đối chiếu báo cáo của subagent. Ở `code-learn`, check `tests_not_modified` thất bại dù luồng chính chỉ **đọc** `tests/test_report.py`; việc sửa tệp test vì vậy xảy ra bên trong subagent (không hiện trong `trace.md`), một dạng lỗi C/F khó quan sát của đa tác tử.
- Token và thời gian: token trung bình tác vụ học 75.469 (subagents) so với 61.088 (baseline), +24%; riêng `code-learn` 135.619 so với 63.971 (gấp 2,1 lần). Điểm kỹ thuật thấp hơn (11/18 so với 13/18).

## 6. Self-evolving: skill do curator sinh (Phần 3)

- Số lần chạy curator: 1 (trên `results/baseline`, chỉ tác vụ học). Không xóa skill nào, không chạy lại. Lý do giữ: cả ba đúng với `detail` của bot đánh giá và vô hại; chạy lại sẽ thay toàn bộ bộ skill mà không có căn cứ rằng `description` là nguyên nhân của `skills_read = 0` (xem dưới).

| Skill | Tổng quát hay riêng cho tác vụ học? | Đúng hay sai (nêu chỗ sai nếu có) | Độ dài, `description` và `skills_read` ở Phần 3.4 |
|---|---|---|---|
| add-regression-tests-for-fixes | Tổng quát cho mọi tác vụ sửa lỗi; tên `tests/test_regressions.py` là quy ước được phép. Chỉ phủ họ `code`. | Đúng với `rule_regression_tests`. Dòng "Add ... to the CI pipeline" và "Maintain ..." không thực hiện được trong sandbox, thừa. | 7 dòng; `description` "Use when fixing bugs ..." nêu đúng tình huống; `skills_read` = 0 ở cả 3 tác vụ. |
| enforce-type-annotations | Tổng quát. Chỉ phủ họ `code`. | Đúng với `rule_type_hints`. "Run a type checker (e.g., mypy)" có thể không làm được (mypy không cài sẵn). | 7 dòng; `description` rõ ràng; `skills_read` = 0. |
| update-changelog-for-fixes | Tổng quát; định dạng `- fix(<function name>):` là quy ước được phép. Chỉ phủ họ `code`. | Đúng với `rule_changelog`. "Save and commit" thừa (tác vụ không dùng git). | 7 dòng; `description` rõ ràng; `skills_read` = 0. |

- Không skill nào phủ quy ước của `data` (tiền tính bằng cent, khối `meta`, `clean.csv`) hay `logs` (tên dịch vụ, sắp xếp, `schema_version`), dù prompt curator có đủ `detail` của cả ba tác vụ.
- Phần 3.4 (`results/skills-auto-dev`): 7/10, 5/8, 1/9; trùng điểm baseline; `skills_read = 0`, `skills_modified = false` ở cả ba. Đã kiểm chứng harness: chạy `build_agent(..., use_skills=True)` với mô hình giả cho thấy system prompt có `SKILLS_NOTE` ("As your FIRST action, read the SKILL.md of every skill whose description could apply") và danh sách 3 skill với đường dẫn `/skills/<name>/SKILL.md`. Vậy `skills_read = 0` là do `gpt-4.1-mini` không làm theo chỉ dẫn, không phải do skill không được nạp.

## 7. Kết quả so sánh (Phần 4.3, 4.4)

(điền sau Phần 4)

## 8. Phân tích

(điền sau Phần 4)

## 9. Hạn chế và tính hợp lệ

(điền sau Phần 4)

## 10. Kết luận

(điền sau Phần 4)

## Phụ lục

- Lệnh đã chạy (theo thứ tự, chuỗi hợp lệ):
  1. `pwsh ./run_isolated.ps1 -Condition baseline -Tasks learn`
  2. `pwsh ./run_isolated.ps1 -Condition subagents -Tasks learn`
  3. `docker run --rm --env-file .env -v "${PWD}:/lab" lab-deepagents python -B -m lab.curator`
  4. `pwsh ./run_isolated.ps1 -Condition skills-auto -Tasks learn`, rồi đổi tên `results/skills-auto` thành `results/skills-auto-dev`
- Sự cố và cách xử lý (các chuỗi chạy bị hủy, không dùng số liệu):
  1. **Rò rỉ khỏi sandbox.** Container mount cả kho vào `/lab`; shell `execute` của tác tử (`LocalShellBackend`) chạy lệnh thật nên tác tử đã `cd /lab` và đọc `GUIDE.md`, `RUBRIC.md`, `tasks/*/check.py` kể cả `tasks/data-eval/check.py`. Toàn bộ kết quả và skill của chuỗi đó bị xóa. Khắc phục: `run_isolated.ps1` chạy mỗi tác vụ trong một container riêng và che (bằng volume rỗng) mọi tác vụ khác, tài liệu `.md`, `.env`, `.git`, `report/`, `results/` của điều kiện khác và `skills/` (trừ `skills-auto`). Đã kiểm chứng: không vết nào của chuỗi hợp lệ chứa `check.py` hay `-eval`.
  2. **Xuống dòng CRLF.** `git core.autocrlf=true` trên Windows đổi 33 tệp trong `tasks/` sang CRLF, khiến check `tests_not_modified` (so sha256 với bản LF) luôn thất bại và làm thay đổi dữ liệu `app.log`, `orders.json`. Khắc phục: `git config --local core.autocrlf false` và khôi phục tệp về LF (`sales.csv` vốn CRLF trong kho, giữ nguyên). Đã kiểm chứng: `check.py` trên workspace chưa sửa đạt `tests_not_modified`.
  3. **Đổi mô hình.** DeepSeek hết số dư (HTTP 402) giữa chừng; toàn bộ chạy lại bằng `gpt-4.1-mini` để mọi số liệu cùng một mô hình.
  4. **Mở rộng runner.** `run_task` dùng `agent.stream(..., stream_mode="values")` (mở rộng tùy chọn trong `03_runner.md`, ghi chú 8) để vẫn có vết khi gặp `GraphRecursionError`.
- Thử thách mở rộng: không thực hiện.
