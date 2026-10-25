# 机械制图学习 · Mechanical Drawing Learning

**中文** | [English](README.en.md)

用 **3D 模型、同步二维投影和可步进动画**，帮助学习者理解机械制图概念，并看懂作图过程中的每一个关键依据。

![平面各顶点向水平面投影的实际动画中间态](docs/screenshots/plane-projection.png)

## 能做什么

- **观察**：旋转空间模型，对照严格对应的二维投影。
- **讲解**：先说明对象、已知与目标，再用图旁短句和动画展示推导；熟悉的步骤连续演示。
- **题目**：按方法选择代表题，进入逐步作图讲解；不先朗读整题。
- **知识图谱**：按前置关系组织16章，便于在基础与后续方法之间切换。

当前包含 **16章、420个讲解小段、65个题目入口（61个去重任务）**。内容围绕现有43页、8套合订卷的69道大题及小问组织；同法题通过代表流程覆盖，不声称每道原题都有独立动画。程序界面和课程正文目前为中文。

## 程序截图

以下均为程序实际渲染截图，不是概念效果图。

### 知识图谱：从点、直线、平面衔接到形体与工程表达

![可缩放知识图谱的基础部分](docs/screenshots/knowledge-map.png)

图谱可缩放、拖动；截图展示其中一部分。

### 题目入口：按方法选择，不重复堆放同类题

![平面章节的八个题目任务及顶部导航](docs/screenshots/questions.png)

### 问题卡：先交代已知条件和目标，再进入作图

![平行四边形问题卡与已知图形](docs/screenshots/problem-card.png)

### 剖视：空间取材与工程图对应

![半剖讲解中的四分之一材料移去结果](docs/screenshots/half-section.png)

### 标准件：把公式、结构和规定画法对应起来

![圆柱齿轮分度圆的空间与二维对应](docs/screenshots/gear.png)

## 运行（Windows）

已验证环境：**Windows、Godot 4.7.2、OpenGL Compatibility**。最小窗口1060×720。仓库包含运行所需的课程数据、模型和图纸，不包含Godot可执行文件、系统字体、个人存档及导入缓存。

1. 克隆仓库，并从 [Godot官网](https://godotengine.org/download/windows/) 准备Godot 4.7.x标准版。
2. 在仓库根目录打开PowerShell，执行：

```powershell
git clone https://github.com/jiangshirong/mechanical-drawing-learning.git
cd mechanical-drawing-learning
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\prepare_windows.ps1 -GodotPath "C:\Tools\Godot\Godot.exe"
```

将示例引擎路径替换为实际位置。准备脚本只复制引擎和本机Windows的微软雅黑到本地、被Git忽略的目录，不下载软件或改动系统设置。

3. 双击 `机械制图学习/开始学习.cmd`；也可用Godot打开 `机械制图学习/project.godot`，首次等待资源导入后运行。

普通学习不需要Python、Blender、Figma、账号或AI/MCP服务。其他操作系统尚未做运行验收；不能直接使用上述Windows字体准备脚本。

## 操作

| 场景 | 操作 |
|---|---|
| 讲解 / 题目 | **A** 上一步，**D** 下一步；也可点击浅色按钮 |
| 正在输出文字 / 播放动画 | A或D先完成当前阶段，再次输入才换段 |
| 分节进度 | 点击节点回到该节开头；退出始终可用 |
| 讲解中的空间模型 | 鼠标左键拖动旋转；前后步进恢复讲解视角 |
| 讲解正文 | 原生拖选、复制 |
| 图谱及资料画布 | 滚轮缩放，左键拖动平移 |

练习入口目前隐藏，不包含评分、学习统计或在线服务。原题和参考依据属于开发资料：在知识图谱连续输入 `qwer` 可在本次运行中显示；学生正常查看题干使用“题”浮窗。

## 章节

| 基础与空间作图 | 形体与表达 | 零件、标注与读图 |
|---|---|---|
| 点的三面投影 | 截交线 | 螺纹及螺纹连接 |
| 直线的投影 | 相贯线 | 圆柱齿轮 |
| 平面的投影 | 组合体分析与补视图 | 滚动轴承 |
| 基本体的投影 | 剖视图 | 尺寸与几何公差 |
|  | 移出断面图 | 表面粗糙度 |
|  | 尺寸与基准 | 综合读零件图 |

## 制作与复用

```text
机械制图学习/        Godot应用、播放器、生成后的课程和几何资产
  模型/             点线面作者源、课程注册表与课程数据
  assets/           共用参数场景、GLB、工程图和来源图
work/               Python课程作者入口、领域几何与验证脚本
docs/               实际截图、验证摘要和第三方说明
学习资料/题集识别/   题目索引与归档来源
```

新章节复用讲解宿主、状态机和领域适配器；点、直线、平面保留各自成熟的控制器。空间几何、投影、辅助线和测量共享参数，工程规定画法单独生成。公开项目不启用本机AI编辑器集成，课程运行逻辑保持不变。

仅重新制作课程才需要Python依赖：

```powershell
python -m pip install -r requirements-authoring.txt
python work/build_exam_course.py --content-only
python work/check_exam_course.py
```

完整重建新章节几何使用 `python work/build_exam_course.py`；原始Blender模型重建另需Blender。直线、平面的作者入口分别为 `work/build_line_learning.py`、`work/build_line_practice.py`、`work/build_plane_lessons.py`。不要只修改生成JSON而遗漏作者源。

进一步阅读：[能力清单](机械制图学习/当前课程能力清单.md) · [知识覆盖表](机械制图学习/全卷知识覆盖表.md) · [方法前置与推导审查](机械制图学习/方法前置与推导审查.md) · [验证摘要](docs/verification.md)。历史审查文档中的本地QA图片、日志和个人环境记录不全部分发；可通过仓库中的脚本重新生成测试输出。

## 验证与边界

已进行正常/最小窗口渲染检查、自然动画中间态人工审查，以及内部按钮/A/D、回退、跳节、保存恢复、退出和几何约束核对。测试使用独立存档、离屏不抢焦点窗口，没有移动系统鼠标。

这不是加工级CAD，也不提供任意模型求交。未验证原生全屏显示、系统拖选手感或真实学习效果。教学尺度、原题事实和来源冲突分别记录。

## 资料与许可

原题、参考资料和第三方组件保留各自权利与出处；本项目尚未指定统一开源许可证。引擎和Windows系统字体不在仓库分发。见 [第三方说明](docs/THIRD_PARTY_NOTICES.md)。
