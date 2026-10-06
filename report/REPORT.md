# Báo cáo Lab: Self evolving Agentic

## 1. Thông tin nhóm và cấu hình

| Họ tên | Mã sinh viên | Phần đóng góp |
|---|---|---|
| Lê Nguyễn Quốc Bảo | 2A202603011 | Toàn bộ |

- Mô hình: `LAB_MODEL=openai:gpt-4.1-mini`, `LAB_TEMPERATURE=0`, `recursion_limit=60` (mặc định của runner).
- Deep Agents 0.7.21; Windows 11 + Docker (`python:3.12-slim`, image `lab-deepagents` từ `Dockerfile`). Mọi lần chạy tác tử đi qua `run_isolated.ps1` (Phụ lục).
- Số lần chạy tác vụ: 9 trước đóng băng (baseline 3, subagents 3, skills-auto-dev 3); xem mục 7 cho các lần chạy sau đóng băng.
- Commit của tag `freeze`: xem mục 7.

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
- `subagent_calls`: `code-learn` 0, `data-learn` 1, `logs-learn` 1. Ở `code-learn` tác tử chính tự sửa và tự chạy test (2 lệnh `execute`), không giao việc dù `SUBAGENTS_NOTE` khuyến khích; nhiều khả năng vì tác vụ đủ nhỏ để tự làm trong vài bước. Ở hai tác vụ còn lại, tác tử chính giao **một** việc lớn (`"Analyze the sales data ..."`, `"Parse the log file ..."`) và không gọi `reviewer`.
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

(điền sau Phần 4)

## 8. Phân tích

(điền sau Phần 4)

## 9. Hạn chế và tính hợp lệ

(điền sau Phần 4)

## 10. Kết luận

(điền sau Phần 4)

## Phụ lục

- Lệnh đã chạy (theo thứ tự):
  1. `pwsh ./run_isolated.ps1 -Condition baseline -Tasks learn`
  2. `pwsh ./run_isolated.ps1 -Condition subagents -Tasks learn`
  3. `docker run --rm --env-file .env -v "${PWD}:/lab" lab-deepagents python -B -m lab.curator`
  4. `pwsh ./run_isolated.ps1 -Condition skills-auto -Tasks learn`, rồi đổi tên `results/skills-auto` thành `results/skills-auto-dev`
- Sự cố và cách xử lý (các chuỗi chạy trước bị hủy, không dùng số liệu):
  1. **Rò rỉ khỏi sandbox.** Container mount cả kho vào `/lab`; shell `execute` (`LocalShellBackend`) chạy lệnh thật nên trong chuỗi chạy đầu tiên tác tử đã `cd /lab` và đọc `GUIDE.md`, `RUBRIC.md`, `tasks/*/check.py`, kể cả `tasks/data-eval/check.py`. Toàn bộ kết quả và skill của chuỗi đó bị xóa. Khắc phục: `run_isolated.ps1` chạy mỗi tác vụ trong một container riêng và che (bằng volume rỗng) mọi tác vụ khác, tài liệu `.md`, `.env`, `.git`, `report/`, `results/` của điều kiện khác và `skills/` (trừ `skills-auto`). Đã kiểm chứng: không vết nào của chuỗi hợp lệ chứa `check.py` hay `-eval`.
  2. **Xuống dòng CRLF.** `git core.autocrlf=true` trên Windows đổi 33 tệp trong `tasks/` sang CRLF, làm check `tests_not_modified` (so sha256 với bản LF) luôn thất bại và thay đổi dữ liệu `app.log`, `orders.json`. Khắc phục: `git config --local core.autocrlf false` và khôi phục tệp về LF (`sales.csv` vốn CRLF trong kho, giữ nguyên). Đã kiểm chứng: `check.py` trên workspace chưa sửa đạt `tests_not_modified`.
  3. **Đổi mô hình.** DeepSeek hết số dư (HTTP 402) giữa chừng; toàn bộ chạy lại từ đầu bằng `gpt-4.1-mini`.
  4. **Chạy lại toàn bộ.** Sau khi rà lại mã, toàn bộ quy trình (Phần 1 đến 4) được chạy lại từ đầu với bộ kết quả, skill và tag `freeze` mới; bộ trước bị xóa.
  5. **Mở rộng runner.** `run_task` dùng `agent.stream(..., stream_mode="values")` (mở rộng tùy chọn trong `03_runner.md`, ghi chú 8) để vẫn có vết khi gặp lỗi như `GraphRecursionError`.
- Thử thách mở rộng: không thực hiện.
