# AreaChain

菜单栏上的每日任务本：今天的例行项、突然想到的待办，以及一句日记。没有 Dock 图标，数据只存在这台电脑。

## 现在能做什么

- 顶栏点 **书本 +「今」** 打开浮层；未完成数跟在旁边
- **回车** 加今天的待办，**⌘回车** 写今天的日记
- 例行项每天重新出现；可勾完、今天跳过、在设置里排序
- 昨天没做完的不混进今天，点「昨天 N」展开；待办可放到今天
- 勾完的收进「已完成」，点开一条就能改字
- **⌘⇧A** 打开今日窗口；设置里可登录自启、导出 / 导入 JSON

完整清单见 [docs/features.md](docs/features.md)。怎么用见 [docs/usage.md](docs/usage.md)。

## 运行

需要 macOS 14+、Xcode 16+。

```bash
open AreaChain.xcodeproj
```

或：

```bash
xcodebuild -project AreaChain.xcodeproj -scheme AreaChain -destination 'platform=macOS' test
open build/DerivedData/Build/Products/Debug/AreaChain.app
```

顶栏找不到图标时，点菜单栏左边的 `«`。

## 目录

```
AreaChain/          应用源码（按层分目录，见 docs/architecture.md）
AreaChainTests/     单测，镜像 Domain / Services
docs/               产品、功能、架构、用法
AreaChain.xcodeproj
```

## 明确不做

不跟前台 App 绑定，不截屏，不听剪贴板，不上云、不设账号。
