# AreaChain

AreaChain 是菜单栏上的 **今天待办本**：打开看还要做什么、已经勾完什么。例行只是明天还会出现的待办。日记是一句话旁路。没有 Dock 图标，数据只存在这台电脑。

## 现在能做什么

- 顶栏点 **书本 +「今」** 打开浮层；未完成数跟在旁边
- **回车** 加今天的待办，**⌘回车** 写一句日记（不跳页）
- 例行项每天重新出现；没有例行时任务页不占那一段
- 今天勾完的默认可看见；昨天没做完的有才出现「昨天 N」
- 改到未来的待办有才出现「即将 N」；不进今天角标
- 默认 **⌘⇧A** 打开同一块浮层，设置里可改热键；可登录自启、预览后导入 JSON

完整清单见 [docs/features.md](docs/features.md)。怎么用见 [docs/usage.md](docs/usage.md)。

## 运行

需要 macOS 14+、Xcode 16+。编 Debug、装到「应用程序」并打开：

```bash
./scripts/build.sh
```

只编译 / 只安装 / 跑测试：

```bash
./scripts/build.sh build
./scripts/build.sh install
./scripts/build.sh test
```

也可以 `open AreaChain.xcodeproj` 用 Xcode。顶栏找不到图标时，点菜单栏左边的 `«`。

## 目录

```
AreaChain/          应用源码（按层分目录，见 docs/architecture.md）
AreaChainTests/     单测，镜像 Domain / Services
scripts/            Debug 编译、安装
docs/               产品、功能、架构、用法
AreaChain.xcodeproj
```

## 明确不做

不跟前台 App 绑定，不截屏，不听剪贴板，不上云、不设账号。
