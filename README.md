# AreaChain

AreaChain 是菜单栏上的 **今天待办本**：打开看还要做什么、已经勾完什么。任务只有一种，分常驻和临时；两边都可以到点通知。日记是一句话旁路。没有 Dock 图标，数据只存在这台电脑。

## 现在能做什么

- 顶栏点 **书本 +「今」** 打开浮层；未完成数跟在旁边
- **回车** 加今天的临时任务，**⌘回车** 写一句日记（不跳页）
- 常驻按你勾的星期再出现，混在今天的清单里，用重复符号标出；在设置里配星期、时刻、项目/标签和四象限
- 今天勾完的默认可看见；昨天没做完的有才出现「昨天 N」
- 改到未来的待办有才出现「即将 N」；不进今天角标
- 底栏 **日历窗** 用月网格看同一批任务，临时可拖到另一天；浮层仍是今天
- 底栏 **更多** 打开搜索、附件浏览、四象限窗、当月安排（轻量甘特）
- 删除会先确认，进回收站；底栏打开后可恢复或彻底删掉
- 默认 **⌘⇧A** 打开同一块浮层；**⌘⇧V** 把剪贴板加成今天一条。设置里可改热键、项目/标签（可嵌套），以及默认关的 App 戳和系统日历同步
- 可登录自启、预览后导入 JSON。iCloud 开关目前只是说明，不会真同步

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

不做成跟前台 App 走的工作台，不常驻录屏（行上可截当前屏一张），不监听剪贴板（热键只读一次），当前签名下不上真 iCloud 双机同步，不把别人的会议收成任务。
