# AreaChain 验证入口与边界

这是验收方法索引，不是另一份构建/签名规范。命令以 [scripts/build.sh](../../../../scripts/build.sh)、[README.md](../../../../README.md)、[架构文档](../../../../docs/architecture.md) 和 [签名文档](../../../../docs/signing.md) 的当前实现为准。所有命令从技能所属仓库根执行。

## 1. 预检

- 先确定本次文件差异和需要证明的行为；只读状态检查受环境限制时说明缺口，可使用已提供的可信差异，不为读取状态自动改变权限或工具链。
- Swift 构建需要项目 README 指定的 macOS/Xcode 环境；脚本检查需要已有 Python。发现缺失或不兼容时报告，不自动系统安装。
- 查看 `./scripts/build.sh help` 可核对当前参数；不要把其他版本的选项或技能目录当作工程参数。
- 构建/签名相关问题先读签名文档，必要时使用 `./scripts/build.sh check-signing` 只读检查。配置检查不能证明产物或真实系统认证可用。

## 2. 文档、规则与技能

- 运行 `python3 -B scripts/check_workflow.py` 检查本地内联引用/锚点、Domain 显式 UI 导入及项目技能 Git 边界。它只读取仓库文件并执行只读 Git 查询，不触碰个人签名、应用或真实数据；边界见 [工程手册](../../../../docs/engineering.md)。
- 检查差异、Markdown/元数据结构、相对引用和适用边界；仓库内使用 `git diff --check`。未跟踪文件还需单独检查，不能因 Git 未显示差异就略过。
- 本检查器改变时，先运行 `python3 -B -m unittest discover -s scripts/tests -p test_check_workflow.py -v`，再运行下文脚本回归。反例应证明坏引用、UI 导入和错误忽略规则能被拒绝，不能只测试当前仓库恰好通过。
- 个人规则也属于本次授权范围时，可显式传入 `--personal-root <实际个人规则目录>` 检查自有 AGENTS、路由及 `areasong-development` 的引用；默认不访问个人目录，不扫描其他技能/插件缓存。该选项不是 YAML 格式或冷启动发现测试。
- 创建/更新 Skill 时，按当前 `skill-creator` 的路径运行其校验器，不硬编码维护者主目录。工具不可用时说明已完成的静态检查和缺口，不以构建应用替代技能校验。
- 项目技能位于 `.agents/skills`，检查 Git 仅暴露预期技能文件，其他本地代理状态仍忽略。个人级技能不是本仓库内容，不复制同名技能来假定覆盖。
- 验证发现和作用域时使用受控的新会话；区分文件存在、清单可见、实际调用和真实任务通过。不仅凭当前上下文已经读过文件就认定冷启动加载成功。
- 只改这些文件不需要运行整套应用测试，也不需要安装或启动应用。

## 3. Swift 与领域/服务检查

先定位相关测试；以下名称只是当前候选，不代表固定必跑全集：

| 影响 | 候选测试或位置 |
|---|---|
| 分类、筛选、日期看板与搜索 | [Domain 测试](../../../../AreaChainTests/Domain) 中的 `ClassificationTests`、`DayBoardLogicTests`、`UnifiedSearchTests` |
| 输入语法及落盘 | `InputSyntaxInteractionTests`、`InputSyntaxPersistenceTests`，结合相关解析/标签测试 |
| 保存、失败与快照兼容 | [Services 测试](../../../../AreaChainTests/Services) 中的 `ModelChangesTests`、`SnapshotImporterTests`、`SnapshotImportValidationTests` |
| 系统日历协调逻辑 | `CalendarSyncEngineTests` 及隔离测试支持；不能由此推断真实日历写入已验收 |
| 字号、颜色与工作台外观 | [Theme 测试](../../../../AreaChainTests/Theme) 中的 `WorkspaceStyleTests`、`DaybookContrastTests` |
| 捕获、输入、窗口与渲染 | [Features 测试](../../../../AreaChainTests/Features) 中的 `CaptureOverlayLayoutTests`、`InputSyntaxInteractionTests`、`WorkspaceRenderingTests` 及相关窗口测试 |

定向测试示例，按实际目标替换或增加测试标识：

```bash
./scripts/build.sh test --only-testing AreaChainTests/DayBoardLogicTests
```

普通测试由脚本清除真实钥匙串授权并串行执行；不能为让默认跳过的系统钥匙串入口运行而恢复这些授权变量。需要全量回归时使用 `./scripts/build.sh test`，并说明扩大范围的依据。

需要编译验证时使用 `./scripts/build.sh`，它只构建并验签 Debug，不安装、不启动。构建成功不能替代测试、语言检查或实际界面操作。

## 4. 原生界面验证

- 先读架构文档的“隔离验收与真实启用门禁”及相关界面验收说明；采用独立 QA 应用标识、隔离构建目录与内存/临时数据，不使用日用应用作为测试宿主。
- 直接使用 `xcodebuild` 做隔离验收时，以该文档当前命令为基线，保留真实钥匙串授权变量清除、QA 标识、隔离签名参数与串行选项；按需要限制测试范围。不要把这些选项直接传给不支持它们的 `build.sh`。
- 这些命令行隔离参数不修改个人签名配置；签名或权限仍失败时先诊断，不自动申请 Apple 端资源或删改钥匙串授权来通过。
- 按本次宿主检查中英文、浅深色、正常/最小支持窗口和重要展开状态。不要仅凭现有测试类名推断覆盖，两种语言或某些状态可能需要补充夹具。
- 保存、取消、快捷键、焦点、输入法、撤销及未提交草稿按实际影响选择操作。UI 测试共享进程焦点，保持串行；截图查看和交互执行分开，不关闭用户其他窗口。
- 程序化控件动作、离屏绘制、几何断言和真实用户操作分别记录。检查器、系统材质或编辑器截图若只有占位内容，不算已看过实际界面。
- 测试环境可能绕过完成驻留或动画等待；这类证据不证明真实时序，需要时另做已授权的隔离运行验收。

## 5. 脚本检查

涉及构建、签名核验或应用管理脚本时，使用已有隔离测试：

```bash
python3 -B -m unittest discover -s scripts/tests -v
```

Shell 脚本另做语法检查，例如 `bash -n scripts/build.sh`；只检查实际修改或直接受影响的脚本。读取测试的隔离安排，不把路径名包含“test”当作没有真实副作用的证明。

这些测试使用模拟外部命令和隔离目录，不代替真实安装、权限、系统认证、续签或备份恢复验收。

## 6. 候选包与真实操作

- 只有任务需要候选包检查时才使用 `./scripts/build.sh release` 或 `./scripts/build.sh verify --configuration Release`；Release 不自动跑测试，也不是已公证发行包。
- 安装脚本可能重新构建并启动产物；`--dry-run` 只检查已有候选包，不代表实际安装/写权限验证。不要把安装、卸载或 `app.sh start` 当成常规验证收尾。
- `--allow-provisioning`、真实钥匙串验收、系统日历写入、真实数据转换及签名身份切换需独立确认。本技能不自动进入这些操作。
- 保留应用本体不等于完成数据备份，启动请求成功不等于运行验收；这些边界以签名文档为准。
