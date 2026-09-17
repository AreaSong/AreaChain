# 本机构建与系统解锁签名

## 两种开发模式

| 模式 | 默认身份 | 系统解锁 | 用途 |
|---|---|---|---|
| `local` | ad-hoc 临时签名，不绑定账号 | 不具备受保护钥匙串授权 | 无开发账号的源码构建、普通功能和独立主密码路径 |
| `development` | 自己的 Apple Development 证书与开发描述文件 | 须通过签名及真机验收 | 本机开发、个人使用和隔离 QA |

`Release` 是优化后的编译配置，不代表已经使用 Developer ID 签名或完成公证。本流程生成的开发签名 Release 包仍是开发产物，不能当作供任意 Mac 下载即用的正式发行包。

Xcode 可能为 ad-hoc 构建关闭 Hardened Runtime。本机模式会如实报告 `hardenedRuntime`，不将其视为系统解锁或发行验收；开发签名模式则必须具备 Hardened Runtime。

## 个人配置

工程的 Debug、Release 配置共用 `Config/Signing.xcconfig`。仓库默认是 `local`，不包含任何个人 Team ID。

需要指纹／系统密码解锁时：

1. 在 Xcode 的 Apple Accounts 中登录自己的账号，准备有效的 Apple Development 签名身份。
2. 将 `Config/Signing.local.xcconfig.example` 复制为同目录的 `Signing.local.xcconfig`，不要覆盖已有个人配置。
3. 填写自己的 `AREACHAIN_DEVELOPMENT_TEAM` 和稳定的 `AREACHAIN_BUNDLE_IDENTIFIER`，保留 `AREACHAIN_SIGNING_MODE = development`。
4. 运行 `./scripts/build.sh check-signing`，核对实际生效的模式、团队和应用标识。

个人配置被 Git 忽略。它只存构建参数，不存 Apple 账号密码、签名私钥、`.p12` 或公证凭据。源码共享者使用自己的账号，不复制维护者的个人开发描述文件。

已有私密数据后，不应随意更换开发团队、应用标识或钥匙串访问组。切换前必须验证独立加密备份与恢复，不能假定新签名身份可以读取旧钥匙串条目。

## 构建与检查

脚本需要 Python 3.9+，仅使用标准库；另外需要已配置的 Xcode 命令行工具。

```bash
# 默认只构建 Debug，不安装、不启动
./scripts/build.sh

# 只读核对 Release 配置
./scripts/build.sh check-signing --configuration Release

# 构建 Release 并自动验签；默认不允许 Xcode 写入开发者账号资源
./scripts/build.sh release

# 再次核对已有 Release 产物
./scripts/build.sh verify --configuration Release

# 普通单测；不会继承真实钥匙串验收授权
./scripts/build.sh test
./scripts/build.sh test --only-testing AreaChainTests/PrivacyVaultTests

# 只测构建／签名／应用管理工具；应用管理使用临时目录与模拟外部命令
python3 -B -m unittest discover -s scripts/tests -v
```

产物按模式隔离在 `build/local-DerivedData/Build/Products/` 或 `build/development-DerivedData/Build/Products/` 下。切换配置后须重新构建，不能拿另一模式的旧产物冒充当前结果。

首次申请或更新描述文件时，只有在明确同意 Apple 端资源写入后，才使用：

```bash
./scripts/build.sh release --allow-provisioning
```

这个选项允许 Xcode 创建／更新应用标识、描述文件和证书，并在必要时登记本机设备标识。普通构建和单测不会自动加上该选项；脚本不会接收或保存 Apple 密码，也不会购买会员。

免费 Personal Team 的开发描述文件通常只有 7 天有效期。核验输出会报告当前文件的到期时间，过期则失败。证书有效、编译成功、代码签名完整，不等于实际到期／续签恢复已通过验收。

## 验签门禁

`scripts/signing.py` 只读核对：

- 实际应用标识、签名团队和沙盒／Hardened Runtime。
- 开发签名的 Apple 证书链锚点与团队，以及描述文件有效期、授权应用标识、签名证书与钥匙串访问组。
- 钥匙串访问组仅限当前应用；不会为通过检查而扩大权限。
- Release 不含调试权限、临时测试权限、XCTest 或测试插件。

检查会临时提取签名中的公有证书做指纹匹配，不读取或导出私钥，不修改系统信任。输出中的 `distributionReady` 始终为 `false`：这里没有实现 Developer ID 公证发行。

静态核验不能代替真机验证。系统解锁仍需在独立 QA 标识和随机条目下验证认证、用户取消、重新构建后读取和清理；不得在真实数据上试验。普通 `test` 命令会清除真实钥匙串授权变量，包括 `TEST_RUNNER_` 形式。

## 安装与回退门禁

构建工具不再关闭应用、覆盖 `/Applications/AreaChain.app` 或自动启动产物。`./scripts/build.sh` 无参数仍只构建 Debug；原 `build.sh install` 会提示使用独立的安装入口。

### 常用命令

| 命令 | 行为 |
|---|---|
| `./scripts/app.sh status` | 只读查看 `/Applications/AreaChain.app` 是否存在、进程与签名状态、开发描述文件有效期 |
| `./scripts/install.sh --dry-run` | 检查已有 Release 候选包与现用应用身份，不构建、复制、安装或启动 |
| `./scripts/install.sh` | 构建 Release、验签、请求确认，保留旧包后安装并请求启动 |
| `./scripts/install.sh --no-build --no-open` | 复用已有 Release，确认安装但不启动 |
| `./scripts/app.sh start` | 验签后请求启动已安装应用，不构建、不安装 |
| `./scripts/uninstall.sh --dry-run` | 预览卸载目标，不移动文件 |
| `./scripts/uninstall.sh` | 确认后将应用移入可恢复目录，保留数据和钥匙串 |
| `./scripts/app.sh delete` | `uninstall` 的同义命令，不表示清空数据 |

`./scripts/app.sh install`、`./scripts/app.sh uninstall` 分别等价于两个独立脚本。各入口支持 `--help`；从其他目录调用时，使用脚本的实际路径，无需先切回仓库。

`--dry-run` 只检查已有产物；如果没有候选包，应先执行 `./scripts/build.sh release`。它不是实际写入权限、安装成功或运行验收的保证。应用正在运行时，预览仍可报告 `running: true`，真正安装／卸载前必须正常退出。

### 确认与签名边界

安装或替换前应单独确认：

1. 候选包确实是预期的 Release 产物，应用标识与签名身份已经核对；QA 标识的包不能覆盖日用应用。
2. 保存并退出当前应用，验证完整数据备份及恢复；安装脚本仅保留原应用本体，不创建用户数据备份。
3. 明确签名身份变化的影响，确认后再安装，并验证冷启动、系统解锁、附件和数据兼容。

安装和卸载默认要求在终端输入 `INSTALL` 或 `UNINSTALL`；非交互环境没有明确确认时拒绝执行。`--yes` 表示使用者已确认本次范围，安装时也确认已完成必要的数据备份与恢复验证；它不会绕过验签、签名身份、进程、路径、权限或并发检查，不能与 `--dry-run` 同用。

管理脚本只处理本机临时签名与 Apple Development 产物，不自动提权或使用 `sudo`，不强制关闭应用。安装会拒绝切换签名模式、团队、应用标识或钥匙串访问组，不会自动续签，也不接受 `--allow-provisioning`；确需更新 Apple 端资源时，应另行确认并使用前述构建命令。

已安装应用的描述文件过期时，仍可核对其代码完整性和原签名身份，使用同一身份且描述文件有效的新包更新；不能据此认为真实到期／续签恢复已通过验收。候选包自身过期或验签不通过则停止安装。

### 应用回退与卸载保留

原应用保留在当前用户目录下的 `Library/Application Support/AreaChain-InstallBackups/install-<UTC 时间>-<随机后缀>/AreaChain.app`；卸载使用同级 `uninstall-.../AreaChain.app`。这些目录仅当前用户可访问，输出会给出实际路径。它们是应用本体的回退材料，不是数据备份或加密备份。

替换前会暂存并重新验签，核对确认时的候选包和现用应用是否变化；安装后验签失败时尝试恢复原应用。自动回退失败会报错并保留原包位置，不应在排查前清理回退目录。启动请求失败不会自动降级，因为新应用可能已经开始运行。

同一用户的安装与卸载使用文件锁互斥执行；另一个管理操作进行中时直接报错，不排队等待。回退根目录中会保留空的 `.app-manager.lock`，进程退出即释放锁，不要删除锁文件来绕过并发检查。回退目录与应用目录不在同一文件系统，或现有目录权限不符合要求时停止，不自动更改权限。

卸载只移动应用本体，不删除容器、数据库、附件、私密锁、钥匙串、证书或已有回退材料。卸载后如果仍有私密锁配置，且无法找到现用应用核对原签名身份，重新安装会停止；应先核对并恢复原应用或另行完成恢复验证，不能靠删除私密配置来绕过检查。本工具不提供自动恢复旧包或清空数据命令。

只有回退应用本体，不能撤销数据库或加密格式变更。真实数据转换需另行确认，不能靠删除配置、清空钥匙串或安装不兼容旧版本来回退。

### 输出与验证范围

`status` 正常输出一个 JSON 对象；已安装包验签失败时保留安装状态与 `verificationError`，退出码为 `1`。操作成功或查询成功（包括尚未安装）返回 `0`，参数用法错误返回 `2`，其他未完成操作返回 `1`。安装／卸载会分阶段输出 JSON，并可能混有构建日志和交互提示，不是单个 JSON 文档。

`launchRequested: true` 只表示系统接受了启动请求，`runtimeVerified` 仍为 `false`。工具测试覆盖隔离目录中的安装、卸载、数据保留、异常回退、并发和参数转发；不调用真实钥匙串、不替换日用应用，不代替真机安装、系统认证或恢复验收。

GitHub／DMG 的正式发行仍需单独落实许可证、发布身份、Developer ID 签名、公证和发布验收；本流程不会上传、推送或创建 Release。

正式发行所需的输入、候选物追溯、渠道决策、分阶段验收及当前缺口见 [工程手册的发行准备](engineering.md#发行准备与回退)。那里定义的是准备门禁，不表示已有 Developer ID、公证、上传或发布自动化；本页继续作为本机构建、签名与安装操作的权威来源。

参考：[Apple 个人开发账号限制](https://developer.apple.com/help/account/basics/about-your-developer-account)、[macOS 描述文件与权限](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles)。
