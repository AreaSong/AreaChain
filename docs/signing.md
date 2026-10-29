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

# 开发调试与性能基线用的普通单测；不会继承真实钥匙串验收授权。仅此次 xcodebuild 使用
# AreaChainTesting.entitlements（测试宿主关闭沙盒以便写 derivedData/phase1-logs），不改日用应用签名。
# 它与日用应用同一标识，不作为原生测试的验收结果；验收走 quality_gate.py（隔离 QA）。
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

完整非钥匙串 QA 使用 `./scripts/build.sh qa-compile --qa-batch cm2` 或定向 `qa --qa-batch cm2 --only-testing AreaChainTests/AppStartupTests`。批次参数只允许1～40位小写字母、数字及连字符，生成独立目录和精确QA标识；缺省保留原PrivacyQA。它显式使用 `Config/QA.xcconfig`，不读取个人配置来决定QA签名身份。编译、`qa_identity.py --expected-identifier` 和测试在同一原锁内依次执行；验签复用本文件的local沙盒／无受限钥匙串权限策略，并额外交叉核对编译符号与签名plist。QA仍无系统解锁或发行资格，源码全集／有界进程观察须由调用方补齐。边界和模板见[隔离验收](architecture.md#隔离验收与真实启用门禁)。

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
| `./scripts/install.sh --dry-run` | 检查已有 Debug 产物与现用应用身份，不构建、复制、安装或启动 |
| `./scripts/install.sh` | 增量构建当前 Debug、验签、请求确认，默认安装为独立共存的 `AreaChain (Debug).app` |
| `./scripts/install.sh --yes` | 同上，并跳过终端确认。开发中用它装上最新测试代码，与正式版完美共存 |
| `./scripts/install.sh --release` | 改为整包优化的 Release 构建后安装为正式版 `/Applications/AreaChain.app` |
| `./scripts/install.sh --single` | 单包模式：强制将 Debug 覆盖安装到正式版目标 `/Applications/AreaChain.app` |
| `./scripts/install.sh --no-build --no-open` | 复用已有产物，确认安装但不启动 |
| `./scripts/install.sh --previous-app /绝对路径/AreaChain.app --dry-run` | 已安装应用缺失时，用显式指定的原应用备份核对身份，不安装或启动 |
| `./scripts/app.sh start` | 验签后请求启动已安装应用，不构建、不安装；支持 `--debug` 启动测试版 |
| `./scripts/uninstall.sh --dry-run` | 预览卸载目标，不移动文件 |
| `./scripts/uninstall.sh` | 确认后将应用移入可恢复目录，保留数据和钥匙串 |
| `./scripts/app.sh delete` | `uninstall` 的同义命令，不表示清空数据 |

`./scripts/app.sh install`、`./scripts/app.sh uninstall` 分别等价于两个独立脚本。各入口支持 `--help`；从其他目录调用时，使用脚本的实际路径，无需先切回仓库。

`--dry-run` 只检查已有产物；如果没有对应配置的包，应先执行 `./scripts/build.sh`，Release 则先执行 `./scripts/build.sh release`。它不是实际写入权限、安装成功或运行验收的保证。应用正在运行时，预览仍可报告 `running: true`；安装会自动请求正在运行的应用优雅退出并完成替换重启，卸载前则仍须正常退出。开发阶段的日常安装使用 Debug：只重编有改动的文件。`--release` 才做整包优化，耗时会明显变长。同一签名身份下，可以用 Debug 替换已经装上的 Release。

### 确认与签名边界

安装或替换前应单独确认：

1. 候选包确实是这次选择的 Debug 或 Release 产物，应用标识与签名身份已经核对；QA 标识的包不能覆盖日用应用。
2. 保存当前工作并确认已完成必要的数据备份；安装脚本仅保留原应用本体，不创建用户数据备份。
3. 明确签名身份变化的影响，确认后再安装，并验证冷启动、系统解锁、附件和数据兼容。

安装和卸载默认要求在终端输入 `INSTALL` 或 `UNINSTALL`；非交互环境没有明确确认时拒绝执行。`--yes` 表示使用者已确认本次范围，安装时也确认已完成必要的数据备份与恢复验证；它不会绕过验签、签名身份、进程、路径、权限或并发检查，不能与 `--dry-run` 同用。

管理脚本只处理本机临时签名与 Apple Development 产物，不自动提权或使用 `sudo`；安装会在替换前请求运行中的应用优雅退出，卸载时拒绝在运行中执行。安装会拒绝切换签名模式、团队、应用标识或钥匙串访问组，不会自动续签，也不接受 `--allow-provisioning`；确需更新 Apple 端资源时，应另行确认并使用前述构建命令。

已安装应用的描述文件过期时，仍可核对其代码完整性和原签名身份，使用同一身份且描述文件有效的新包更新；不能据此认为真实到期／续签恢复已通过验收。候选包自身过期或验签不通过则停止安装。

### 应用回退与卸载保留

原应用保留在当前用户目录下的 `Library/Application Support/AreaChain-InstallBackups/install-<UTC 时间>-<随机后缀>/AreaChain.app`；卸载使用同级 `uninstall-.../AreaChain.app`。这些目录仅当前用户可访问，输出会给出实际路径。它们是应用本体的回退材料，不是数据备份或加密备份。

替换前会暂存并重新验签，核对确认时的候选包和现用应用是否变化；安装后验签失败时尝试恢复原应用。自动回退失败会报错并保留原包位置，不应在排查前清理回退目录。启动请求失败不会自动降级，因为新应用可能已经开始运行。

同一用户的安装与卸载使用文件锁互斥执行；另一个管理操作进行中时直接报错，不排队等待。回退根目录中会保留空的 `.app-manager.lock`，进程退出即释放锁，不要删除锁文件来绕过并发检查。回退目录与应用目录不在同一文件系统，或现有目录权限不符合要求时停止，不自动更改权限。

卸载只移动应用本体，不删除容器、数据库、附件、私密锁、钥匙串、证书或已有回退材料。卸载后如果仍有私密锁配置，且无法找到现用应用核对原签名身份，默认重新安装会停止。可以显式指定可信原应用备份来核对身份；无可信原包时仍需另行完成恢复验证，不能靠删除私密配置来绕过检查。本工具不提供清空数据命令。

### 原应用缺失时重装

先在上述回退目录确认原应用，再传入其完整绝对路径：

```bash
# PATH 替换为本用户回退目录中原 AreaChain.app 的绝对路径，含空格时保留引号
./scripts/install.sh --previous-app "PATH" --dry-run
# 预检通过后，复用已有候选包安装；不启动旧包或新版
./scripts/install.sh --previous-app "PATH" --no-build --no-open
```

`--previous-app` 仅在 `/Applications/AreaChain.app` 缺失时接受，来源限定为本用户 `AreaChain-InstallBackups` 下由脚本命名的 `install-...`／`uninstall-...` 目录，目录须为当前用户独占且不能包含符号链接。指定这个参数表示使用者确认它是用于本次恢复的原应用；脚本不根据文件名、时间或新包身份自动挑选历史包，也不能仅靠签名证明备份与当前私密数据的历史归属。

脚本验证原包完整性，并按既有规则比较模式、团队、应用标识、application identifier 和钥匙串访问组；原包描述文件过期不阻止只读身份核对，候选包仍必须通过有效期及完整验签。Debug／Release 和代码哈希允许不同。暂存后、替换前重新核验原包的签名及文件身份，缺失、损坏、替换或现用应用重新出现均停止。普通覆盖安装始终以现用应用为准，不能用该参数绕过它。

预检输出的 `identitySource` 指明本次核对的原包；安装直接放入新包，不恢复或启动旧版本，不消耗原备份，不读取私密正文或修改数据、锁配置与钥匙串。失败沿原安装回退恢复到“安装目录无应用”的状态。`--yes` 仍只确认本次范围，不能跳过这些检查。该流程不是数据恢复、系统解锁或跨签名迁移验收。

只有回退应用本体，不能撤销数据库或加密格式变更。真实数据转换需另行确认，不能靠删除配置、清空钥匙串或安装不兼容旧版本来回退。

- 隔离回归覆盖显式同身份重装、各身份字段不一致、无参数仍阻止遗留锁重装、损坏或非受管原包、路径／权限／符号链接、备份改变／替换／消失、现用应用重新出现、取消、安装锁、失败恢复缺失状态及含空格的参数透传。外部命令均模拟，应用和用户资料使用临时合成目录。

### 输出与验证范围

`status` 正常输出一个 JSON 对象；已安装包验签失败时保留安装状态与 `verificationError`，退出码为 `1`。操作成功或查询成功（包括尚未安装）返回 `0`，参数用法错误返回 `2`，其他未完成操作返回 `1`。安装／卸载会分阶段输出 JSON，并可能混有构建日志和交互提示，不是单个 JSON 文档。

`launchRequested: true` 只表示系统接受了启动请求，`runtimeVerified` 仍为 `false`。工具测试覆盖隔离目录中的安装、卸载、数据保留、异常回退、并发和参数转发；不调用真实钥匙串、不替换日用应用，不代替真机安装、系统认证或恢复验收。

GitHub／DMG 的正式发行仍需单独落实许可证、发布身份、Developer ID 签名、公证和发布验收；本流程不会上传、推送或创建 Release。

## 发行准备

这里补的是准备方法，不实现或执行正式发行。当前 [signing.py](../scripts/signing.py) 仅支持 local/development，`distributionReady` 固定为 false；[app_manager.py](../scripts/app_manager.py) 的运行请求也不等于验收。

| 阶段 | 输入与执行方法 | 输出/通过证据 | 失败/授权边界 |
|---|---|---|---|
| 范围与渠道 | 版本保持 `1.0.0` / build `1`，直到打发行标签。许可证见仓库根 `LICENSE`（Apache-2.0）。支持下限仍是文档中的 macOS 14+，本机 macOS 26 的测试不是 14 的认证 | 渠道定为「可公证的本机分发」，但公证本身未执行 | Developer ID、公证上传和商店路线仍须另授权；`distributionReady` 保持 false |
| 候选物追溯 | 记录 revision、脏差异指纹、工具链/SDK、配置/权限、依赖及构建命令，生成候选物摘要 | 测试/验签记录能关联到确切包，而非仅关联 HEAD | 脏工作区可开发验证，不自动成为可发行版本；重建/签名后重核摘要及证据 |
| 本地候选验证 | 已有构建、Release 静态验签、适用测试及隔离 QA | 编译、测试、静态签名、运行场景分别给结果 | 此门禁通过仍不是 Developer ID、公证、正式安装或升级验收 |
| 渠道准备/执行 | 渠道确定后再落实对应身份、打包、公证/信任核对、变更说明与分发方法 | 渠道要求的实际返回结果、包摘要与版本记录 | 身份/权限改变、Apple 端资源、公证上传、发布均须另获明确授权；当前未实现 |
| 安装升级/发布后 | 在已授权的隔离目标核对首次安装、升级、冷启动、关键操作、系统解锁与数据/附件 | 实际运行和兼容证据；记录失败阶段与恢复路径 | 不拿日用应用试验，不因启动请求成功宣称已验收 |
| 回退 | 先判断旧程序是否可读当前数据，区分程序、数据、配置和凭据 | 原包可核验；数据恢复另有演练，含可能丢失的新数据及耗时 | 不兼容则停止降级；真实恢复/身份切换/回撤发布仍需确认 |

当前安装脚本保留的只是应用本体；它不创建完整数据备份。自动回退失败应保留原包位置并停止；新程序可能已写入数据时不能盲目再次启动旧版。具体参数和现有脚本行为以上文“安装与回退门禁”为准，不另写第二套安装指令。

参考：[Apple 个人开发账号限制](https://developer.apple.com/help/account/basics/about-your-developer-account)、[macOS 描述文件与权限](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles)。
