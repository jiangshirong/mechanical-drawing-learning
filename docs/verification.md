# 验证摘要 / Verification summary

原始工作构建已完成16章内容审查、几何与表达核对、正常/1060×720窗口内部操作、自然动画中间态人工查看、恢复/取消/退出及作者源可复现性检查。当前420个讲解小段，65个题目入口、61个去重任务。

The working build was checked for lesson content, geometry and drawing conventions, normal/minimum-window behavior, natural animation intermediate states, restoration/cancellation, and deterministic authoring. It contains 420 explanation beats and 65 entries for 61 distinct tasks.

- 正式存档未改、原始7例GLB/data未改；测试进程正常退出。
- Formal saves and original model assets were unchanged; owned test processes exited normally.
- 公开版只关闭本机AI编辑器集成；课程与几何资产沿用已核验构建。
- The public snapshot disables only the local AI editor integration and retains verified lesson and geometry data.
- 不宣称原生全屏、系统鼠标拖选手感、加工级CAD精度或真实学习效果通过。
- Native fullscreen, system text-selection feel, manufacturing CAD precision and learner outcomes are not claimed as verified.

See `verification.json` for public-snapshot smoke tests. Historical local QA artifacts are not all distributed. Generate new outputs with isolated saves:

```powershell
python work/check_exam_course.py
python work/check_method_derivations.py
python work/run_method_review_qa.py
python work/run_method_review_qa.py --minimum
python work/run_course_final_qa.py
```

Tests use offscreen windows and internal Godot input. Do not move the system mouse or reuse student save files.
