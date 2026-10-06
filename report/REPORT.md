# Báo cáo Lab: Self evolving Agentic

## 1. Thông tin nhóm và cấu hình

| Họ tên | Mã sinh viên | Phần đóng góp |
|---|---|---|
| Lê Nguyễn Quốc Bảo | 2A202603011 | Toàn bộ |

- Mô hình: `LAB_MODEL=openai:gpt-4.1-mini`, `LAB_TEMPERATURE=0`, `recursion_limit=60` (mặc định của runner).
- Deep Agents 0.7.21; Windows 11 + Docker (`python:3.12-slim`, image `lab-deepagents` từ `Dockerfile`). Mọi lần chạy tác tử đi qua `run_isolated.ps1` (xem Phụ lục, mục "Sự cố và cách xử lý").
- Số lần chạy tác vụ đã dùng (chuỗi hợp lệ): 21 = 9 trước đóng băng (baseline 3, subagents 3, skills-auto-dev 3) + 12 sau đóng băng (baseline 3, subagents 3, skills-auto 6). Không lần chạy nào có `error` hay phải chạy lại. Các chuỗi chạy trước đó bị hủy vì lỗi môi trường, không dùng trong báo cáo (Phụ lục).
- Commit của tag `freeze`: `25695f7` (commit `hypotheses`: `b820f51`).

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

`report/table.md` (sinh bởi `python -m lab.compare`):

| Task | baseline | subagents | skills-auto |
|---|---|---|---|
| code-learn | 7/10 | 5/10 | 7/10 |
| data-learn | 5/8 | 5/8 | 5/8 |
| logs-learn | 1/9 | 2/9 | 1/9 |
| code-eval | 7/11 | 7/11 | 7/11 |
| data-eval | 5/9 | 1/9 | 0/9 |
| logs-eval | 1/10 | 0/10 | 1/10 |
| **Mean score - learning tasks** | 0.48 | 0.45 | 0.48 |
| **Mean score - evaluation tasks** | 0.43 | 0.25 | 0.25 |
| **Mean tokens per run** | 47,612 | 52,804 | 53,310 |
| **Runs that read a skill** | 0/6 | 0/6 | 0/6 |

`python scripts/check_breakdown.py`:

```text
condition     role    technical  house rules  mean tokens  read a skill
baseline      eval     13/18         0/12          34,136      0/3
baseline      learn    13/18         0/9           61,088      0/3
subagents     eval      8/18         0/12          30,140      0/3
subagents     learn    11/18         1/9           75,469      0/3
skills-auto   eval      8/18         0/12          39,346      0/3
skills-auto   learn    13/18         0/9           67,274      0/3
```

- Không lần chạy nào có `error`; `skills_modified = false` ở mọi lần chạy.
- `python scripts/verify_freeze.py` (chạy trên Linux/WSL): `checked 6 runs of skill conditions: OK`. Chạy trên Windows, script báo "skills differ from the frozen skills" vì `hash_skills` băm cả đường dẫn tương đối, mà Windows dùng `\` còn các lần chạy (trong container Linux) dùng `/`; nội dung skill không đổi. Cần chạy script trên Linux/macOS như README yêu cầu.

## 8. Phân tích

1. **Học và đánh giá.** Tác vụ học: không điều kiện nào hơn `baseline` (0,48; `subagents` 0,45; `skills-auto` 0,48 với điểm từng tác vụ trùng hệt `baseline`). Tác vụ đánh giá: cả hai điều kiện đều **kém** `baseline` (0,25 và 0,25 so với 0,43). Không có trường hợp "cải thiện học nhưng không cải thiện đánh giá" vì không có cải thiện nào ở tác vụ học; vì vậy thí nghiệm không cho thấy quá khớp mà cho thấy skill **không có tác dụng** (H2 đúng). H1 đúng một phần: `subagents` không hơn `baseline`, nhưng kém hơn dự đoán ±0,1 (-0,18 trên tác vụ đánh giá). H3 đúng: cả ba điều kiện có điểm đánh giá ≤ điểm học.
2. **Kỹ thuật và quy ước.** Check quy ước: 0/9 (học) và 0/12 (đánh giá) ở cả ba điều kiện, trừ 1/9 của `subagents` trên tác vụ học. Skill do curator sinh không giúp check nào: ở `code-eval`, `skills-auto` vẫn trượt đúng ba quy ước cũ mà skill mô tả (`rule_type_hints`, `rule_regression_tests`, `rule_changelog`) và quy ước mới `rule_version_bump`. Quy ước mới của tác vụ đánh giá (`rule_version_bump`, `rule_sorted_keys_format`, `rule_source_line`) không thể được skill giúp vì không xuất hiện trong phản hồi nào của tác vụ học; quy ước cũ cũng không được giúp vì skill không được đọc. Toàn bộ chênh lệch điểm giữa các điều kiện nằm ở check **kỹ thuật** (13/18, 8/18, 8/18 trên tác vụ đánh giá).
3. **Cơ chế qua vết.** `skills_read = 0` ở cả 9 lần chạy có skill (kể cả `skills-auto-dev`). Kiểm chứng bằng mô hình giả (`ScriptedChatModel`): system prompt có danh sách 3 skill và `SKILLS_NOTE` yêu cầu đọc skill "as your FIRST action", nên nguyên nhân là `gpt-4.1-mini` không làm theo chỉ dẫn, không phải skill thiếu hay `description` sai. Check skill lẽ ra giúp nhưng không giúp: `rule_changelog` ở `skills-auto/code-learn` và `skills-auto/code-eval`; skill `update-changelog-for-fixes` mô tả đúng định dạng `- fix(<function name>):` nhưng vết không có `read_file` nào vào `/skills/`. Không có check nào mà skill giúp đạt. Biến số thật sự quyết định điểm kỹ thuật là **tác tử có viết và chạy code hay không**: ở họ `data`, các lần chạy có `execute` (`baseline/data-eval` 2 lệnh, `skills-auto/data-learn` 6 lệnh) đạt mọi check kỹ thuật, còn lần không có `execute` mà `write_file` thẳng `answer.json` thì sai số liệu (`skills-auto/data-eval` 0/9: tự nhẩm `march_revenue_utc` rồi khẳng định "2 duplicates removed"; nhóm B/F). Ở họ `logs`, **không** lần chạy nào dùng `execute` (0 lệnh ở cả 7 lần chạy họ `logs`) và mọi lần đều trượt gần hết check kỹ thuật.
4. **Chi phí.** Token trung bình mỗi lần chạy: `baseline` 47.612, `subagents` 52.804 (+11%), `skills-auto` 53.310 (+12%). Điểm trung bình 6 tác vụ: 0,455; 0,349; 0,362, tức 0,96; 0,66; 0,68 điểm trên 100 nghìn token. `baseline` hiệu quả nhất. Đa tác tử không đáng chi phí trong thí nghiệm này: tốn thêm token (riêng `code-learn` gấp 2,1 lần) mà điểm thấp hơn. Cơ chế (vết): tác tử chính giao một việc lớn rồi tin báo cáo của subagent mà không kiểm chứng. Ở `subagents/logs-eval`, subagent để lại `errors.json` rỗng (`{"entries":[],"counts_by_service":{}}`); tác tử chính đọc thấy rỗng nhưng vẫn kết thúc (0/10, kể cả `valid_structure`). Ở `subagents/data-eval`, tác tử chính chép nguyên số liệu sai của subagent vào `answer.json` (1/9). Subagent `reviewer` không được gọi lần nào.
5. **Rò rỉ và quá khớp.** Ba skill không chứa định danh hay số liệu của tác vụ đánh giá (`validate_skill` đạt; `tests/test_regressions.py`, `CHANGELOG.md`, `## Unreleased` là quy ước được phép). Chúng chỉ khớp với họ `code` (không phủ `data`, `logs`) nhưng không gây hại đo được. Phòng tránh: curator chỉ đọc `role == "learn"`; viết giả thuyết và đóng băng trước khi chạy tác vụ đánh giá; `run_isolated.ps1` che mọi tác vụ khác, tài liệu và `.env` khỏi shell của tác tử. Chuỗi chạy đầu tiên, trước khi có biện pháp này, đã bị hủy vì tác tử đọc được `tasks/data-eval/check.py` (Phụ lục). Đã kiểm tra: không vết nào của chuỗi hợp lệ chứa `check.py` hay `-eval`.
6. **Nhiễu.** Cùng bộ skill trên tác vụ học: Phần 3.4 (`skills-auto-dev`) 7/10, 5/8, 1/9 và sau đóng băng 7/10, 5/8, 1/9, chênh lệch điểm 0; nhưng token trung bình 44.704 so với 67.275 (+50%; `data-learn` 36.106 so với 95.843). Nhiễu điểm trên tác vụ học thấp vì kết quả bị chi phối bởi lỗi có tính hệ thống (quy ước; không chạy code ở `logs`). Tuy nhiên `data-eval` dao động 5/9, 1/9, 0/9 giữa ba điều kiện mà không điều kiện nào thực sự dùng skill; khác biệt đến từ việc tác tử có chọn chạy code hay không. Vì vậy chênh lệch 0,18 giữa `baseline` và hai điều kiện còn lại trên tác vụ đánh giá chủ yếu do **một** tác vụ và không đủ tin cậy để kết luận chúng tệ hơn; chỉ kết luận chắc chắn được rằng chúng **không tốt hơn**.

## 9. Hạn chế và tính hợp lệ

1. **Mỗi cấu hình chạy một lần, chỉ 3 tác vụ mỗi vai trò.** Một tác vụ (`data-eval`) quyết định gần như toàn bộ chênh lệch điểm đánh giá; với n = 1 không có khoảng tin cậy. Kết luận "kém hơn" có thể chỉ là nhiễu (mục 8.6); kết luận "không tốt hơn" vững hơn.
2. **Một mô hình duy nhất, mô hình nhỏ (`gpt-4.1-mini`).** Mô hình bỏ qua chỉ dẫn đọc skill và không chạy code ở họ `logs`. Kết luận "skill không có tác dụng" có thể chỉ đúng với mô hình kém tuân thủ chỉ dẫn; mô hình mạnh hơn có thể đọc skill và đạt các quy ước cũ.
3. **Cách ly không hoàn toàn.** `LocalShellBackend` chạy lệnh thật với cùng quyền của bộ chấm; `run_isolated.ps1` che các tác vụ khác, tài liệu và `.env`, nhưng tác tử vẫn có thể đọc `check.py` của chính tác vụ đang làm. Trong chuỗi hợp lệ không lần chạy nào làm vậy (đã `grep`), nhưng đây là hạn chế của harness, không phải đảm bảo.
4. **Tác vụ có quy ước ẩn do giảng viên thiết kế.** 9/14 check thất bại ở baseline là quy ước không có trong đề; điểm vì thế đo khả năng học từ phản hồi nhiều hơn năng lực kỹ thuật. Mỗi tác vụ đánh giá thêm một quy ước mới mà không phương pháp nào trong lab biết trước, nên trần điểm của `skills-auto` trên tác vụ đánh giá thấp hơn 1,0 theo thiết kế.
5. **Curator chạy một lần.** Bộ skill là một mẫu ngẫu nhiên của curator và chỉ phủ họ `code`; một lần chạy khác có thể phủ `data`, `logs`.
6. **Môi trường Windows.** Lab yêu cầu macOS/Linux; trên Windows phải xử lý CRLF (`core.autocrlf`) và chạy `verify_freeze.py` trên Linux. Các sự cố đã được khắc phục trước chuỗi hợp lệ nhưng là rủi ro khi tái lập.

## 10. Kết luận

Với `gpt-4.1-mini`, cả đa tác tử lẫn skill do curator tự sinh đều không cải thiện điểm so với tác tử Deep Agents mặc định trên tác vụ học hay tác vụ đánh giá, trong khi tốn thêm khoảng 11-12% token. Skill không có tác dụng vì không được đọc lần nào (`skills_read = 0`), và kể cả nếu được đọc cũng chỉ phủ quy ước của họ `code`, không phủ quy ước mới của tác vụ đánh giá. Biến số quyết định điểm kỹ thuật là tác tử có viết và chạy code để kiểm chứng hay không; đa tác tử làm xấu đi vì tác tử chính tin báo cáo của subagent mà không kiểm tra. Do mỗi cấu hình chỉ chạy một lần, kết quả chỉ khẳng định được các điều kiện "không tốt hơn" baseline. Đề xuất tiếp theo: buộc kiểm chứng ở tầng harness (bắt buộc gọi `reviewer` hoặc chạy script trước khi kết thúc) và lặp mỗi cấu hình ít nhất 3 lần để đo nhiễu.

## Phụ lục

- Lệnh đã chạy (theo thứ tự, chuỗi hợp lệ):
  1. `pwsh ./run_isolated.ps1 -Condition baseline -Tasks learn`
  2. `pwsh ./run_isolated.ps1 -Condition subagents -Tasks learn`
  3. `docker run --rm --env-file .env -v "${PWD}:/lab" lab-deepagents python -B -m lab.curator`
  4. `pwsh ./run_isolated.ps1 -Condition skills-auto -Tasks learn`, rồi đổi tên `results/skills-auto` thành `results/skills-auto-dev`
  5. `git commit -m "hypotheses"`; `git commit --allow-empty -m "freeze skills"`; `git tag freeze`
  6. `pwsh ./run_isolated.ps1 -Condition baseline -Tasks eval`
  7. `pwsh ./run_isolated.ps1 -Condition subagents -Tasks eval`
  8. `pwsh ./run_isolated.ps1 -Condition skills-auto -Tasks all`
  9. `python scripts/verify_freeze.py` (trên WSL), `python -m lab.compare > report/table.md`, `python scripts/check_breakdown.py`
- Sự cố và cách xử lý (các chuỗi chạy bị hủy, không dùng số liệu):
  1. **Rò rỉ khỏi sandbox.** Container mount cả kho vào `/lab`; shell `execute` của tác tử (`LocalShellBackend`) chạy lệnh thật nên tác tử đã `cd /lab` và đọc `GUIDE.md`, `RUBRIC.md`, `tasks/*/check.py` kể cả `tasks/data-eval/check.py`. Toàn bộ kết quả và skill của chuỗi đó bị xóa. Khắc phục: `run_isolated.ps1` chạy mỗi tác vụ trong một container riêng và che (bằng volume rỗng) mọi tác vụ khác, tài liệu `.md`, `.env`, `.git`, `report/`, `results/` của điều kiện khác và `skills/` (trừ `skills-auto`). Đã kiểm chứng: không vết nào của chuỗi hợp lệ chứa `check.py` hay `-eval`.
  2. **Xuống dòng CRLF.** `git core.autocrlf=true` trên Windows đổi 33 tệp trong `tasks/` sang CRLF, khiến check `tests_not_modified` (so sha256 với bản LF) luôn thất bại và làm thay đổi dữ liệu `app.log`, `orders.json`. Khắc phục: `git config --local core.autocrlf false` và khôi phục tệp về LF (`sales.csv` vốn CRLF trong kho, giữ nguyên). Đã kiểm chứng: `check.py` trên workspace chưa sửa đạt `tests_not_modified`.
  3. **Đổi mô hình.** DeepSeek hết số dư (HTTP 402) giữa chừng; toàn bộ chạy lại bằng `gpt-4.1-mini` để mọi số liệu cùng một mô hình.
  4. **Mở rộng runner.** `run_task` dùng `agent.stream(..., stream_mode="values")` (mở rộng tùy chọn trong `03_runner.md`, ghi chú 8) để vẫn có vết khi gặp `GraphRecursionError`.
- Thử thách mở rộng: không thực hiện.
