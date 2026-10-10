# neo_top_bar

一个可自定义的 Denial 顶栏插件。整条栏由**模块**组成，每个模块可以在配置里开关，
并选择停在左 / 中 / 右三段中的哪一段。

## 默认布局

默认状态按下面这版排布（左 → 右）：

```
┌──────────────┬────────────────┬──────────────────────────────────────────────┐
│ 工作区       │      Arch      │ 托盘  通知  电池                 时钟与日期   │
└──────────────┴────────────────┴──────────────────────────────────────────────┘
```

| 模块 | id | 区 | 默认 | 说明 |
|---|---|---|---|---|
| 工作区胶囊 | `workspaces` | 左 | 开 | 每个工作区一个圆点，当前工作区高亮，占用状态变实心；点击切换；**可选**（默认关）在每个工作区里显示它自己的窗口图标，最多 3 个 + `+N` |
| 应用启动器 | `launcher` | 中 | 开 | Arch Linux 图标 + **当前工作区每个窗口的图标**，点击图标聚焦该窗口、点击其余部分调 `services.toggleLauncher()`；胶囊宽度随窗口数动态伸缩，超过 10 个折叠成 `+N`；图标顺序按窗口**首次出现**固定，点谁都不会重排 |
| 系统托盘 | `tray` | 右 | 开 | StatusNotifier 图标；托盘隐藏或为空时整块自动消失（**不会留下空位**）；空间不够时只留前 3 个，其余收进一个向下箭头（**裸字形、没有底色**，因为宿主把托盘图标画成裸的 22px 方块；点它展开，锚在胶囊正下方，弹出的是**被折叠的那几个图标**（栏上已经有的不再重复一遍——那只会让人找不到自己要找的那个）：宽高都贴着 4 列网格算，没有标题也没有关闭按钮，点外面 / Esc 关） |
| 通知 | `notifications` | 右 | 开 | 未读徽章 + 历史面板（逐条忽略 / 全部清除 / 免打扰） |
| 媒体播放 | `media` | 右 | **关** | 曲目 + 上一首 / 播放暂停 / 下一首；无播放时自动消失（不留空位、不留间隙） |
| 电池与电源 | `battery` | 右 | 开 | 电量与充电状态，点击打开电源设置；无电池的机器自动消失 |
| 控制中心 | `control_center` | 右 | 开（**自带选项**：胶囊显示哪几个图标、电源行放哪几个按钮） | 胶囊上实时显示音量 / 网络（有线会用专用图标）/ 蓝牙 / 电量；**每个图标右键即快捷操作**（音量=静音、网络=开关无线、蓝牙=开关）；点击在下方弹出面板：音量与亮度滑条（点图标展开输出设备 / 各应用音量 / 各显示器亮度）、Wi-Fi 与蓝牙设备列表、免打扰、深浅模式、电源行（自定义 / 锁屏 / 注销 / 重启 / 关机） |
| CPU 负载 | `cpu` | 右 | **关** | 折线 + 百分比 + 温度 |
| GPU 负载 | `gpu` | 右 | **关** | 每块显卡一条，含温度 |
| 时钟与日期 | `clock` | 右 | 开 | 点击打开日历面板（上/下月、回到今天） |

可选模块默认关闭，所以第一眼接近系统原来的样子。想开就在下面说的设置面板里打开。

## 交互

- **左键**：模块各自的行为（切工作区、开启动器、开电源页、开日历、开通知面板、开控制中心、媒体控制）。
- **右键控制中心的单个图标**：音量静音、无线开关、蓝牙开关（电量无动作）。
- **长按胶囊拖动**：直接在顶栏上拖拽排序。
  - 跟着指针走的是**胶囊本体**，不是替代图标
  - 它原本的位置留一个同尺寸的**虚影**（强调色描边的圆角矩形），标出它会落在哪
  - **其余胶囊会平滑移开让位**，虚影滑到目标空档，松手即写入配置
  - **拖到别的区就会改区**——落点所在的区决定它归哪一段
  长按（不是立即拖动）是为了不抢走每个胶囊原本的点击行为。
- **右键某个胶囊**：在鼠标旁边直接弹出**这个胶囊自己的设置**（标题就是组件名，下面是它全部的选项，
  底部一条「全部组件设置」通到看板）。它按的是**实例**：同一个组件加了两份，右键哪一份就改哪一份。
- **右键胶囊内部的图标仍然优先**：托盘的图标由宿主渲染，右键是它们的上下文菜单；
  控制中心的状态图标右键是静音 / 无线 / 蓝牙开关。这两种情况下胶囊自己的设置卡**不会**跟着弹出来。
  靠的是**手势竞技场**而不是命中测试：胶囊包一层手势识别器，托盘图标和控制中心图标在更里层，
  最里层赢——细节见下面「右键为什么不会一次弹两个」。
- **右键顶栏的空白处**：在鼠标旁边弹出**右键菜单**。目前里面只有一项，
  就是最下面的**「顶栏组件设置」**（以后往菜单里加别的项时，设置永远排在最后一行）。
  点它打开**组件设置面板**。它是一块**看板**：左 / 中 / 右三个区各列出自己那一段的**组件实例**，
  **卡片可以直接拖动**调整区内顺序（拖动手柄即时拖，按住卡片任意位置也会「拎起来」）；
  每个区底部有**添加组件**，可以把**任何组件加进任何一段，想加几个就加几个**；
  卡片右侧的 **✕** 把它从栏上移除，箭头展开**这个实例自己的选项**。顶部还有整条栏的间距。
  改动立即生效并写入配置。
- **快捷键**：插件额外提供一个动作 `neo_top_bar.openSettings`（顶栏组件设置）。
  在 **设置 → 快捷键 → Denial 动作** 里绑一个键（比如 `Super+Shift+T`），
  这是打开设置面板最可靠的方式——不用去找空白处，也不会碰到托盘。

  这个面板是**屏幕正中偏大的居中卡片**（820×760），不是贴着鼠标的小菜单：它是配置界面，
  行数多、需要横向空间放说明文字，居中才有地方铺开。胶囊的设置卡、菜单、日历、通知才是贴着鼠标/图标弹的。

### 右键为什么不会一次弹两个

三种右键目标套在一起（空白栏面 ⊃ 胶囊 ⊃ 托盘图标 / 状态图标），如果每层都用
`Listener(onPointerDown:)`，一次点击会**三层全中**——这就是「右键一下，两个东西弹出来」的来源。
改成手势识别器就能让竞技场决定归属，但还有一个坑：

- **里层用 `onSecondaryTapDown`，外层必须用 `onSecondaryTapUp`。**
  `TapGestureRecognizer.didExceedDeadline` 到 100ms 会**无条件**调 `_checkDown()`，
  它不会先赢下竞技场；所以两个嵌套的 down 回调在「按住右键超过 100ms」时会**双双触发**。
  而 `_checkUp()` 有 `_wonArenaForPrimaryPointer` 守卫，松手时只有赢家（最里层）会跑。
- 外层用 up 的代价是：按住不放时动作在松手那一刻发生，而不是按下去就发生。对右键菜单来说这没问题。
- 只挂 `onSecondaryTap*` 的 `GestureDetector` 对**左键**直接 `isPointerAllowed == false`，
  根本不进竞技场，所以点击、长按拖动、按下反馈一点都不受影响。

## 配置文件

`~/.config/denial/plugins/neo_top_bar.json`（遵循 `XDG_CONFIG_HOME`）。

它是一个**稀疏覆盖层**，只记录你改过的东西；没写的部分用内置默认值。所以以后新增模块
会按它自己的默认状态出现，不会被你的旧文件影响。

```json
{
  "schema": 1,
  "density": "compact",
  "modules": {
    "media": { "enabled": true },
    "cpu": { "enabled": false, "zone": "start" }
  },
  "order": {
    "end": ["tray", "notifications", "battery", "clock"]
  }
}
```

| 字段 | 含义 |
|---|---|
| `schema` | 必须是 `1`。缺省或更高版本会被当成"没有可用配置"，回落到默认值（不会瞎猜） |
| `density` | `compact` / `regular` / `comfortable`；等于 `regular` 时不写入 |
| `modules.<id>.enabled` | 覆盖该模块的默认开关 |
| `modules.<id>.zone` | `start` / `center` / `end`；等于模块自带区时不写入 |
| `order.<zone>` | 该区内的先后顺序；没列到的模块按自带优先级排在后面 |

**区（zone）顺序**：`start` → `center` → `end`，沿顶栏主轴排列。

**精度与安全性**：写入是原子的（临时文件 + rename），并且会**保留本插件不认识的其他键**。
如果文件损坏无法解析，插件不会静默覆盖它，而是先备份成 `neo_top_bar.json.broken`，
再写入新的配置。解析失败时顶栏用默认值继续渲染，面板里会显示原因。

## 安装与启用

⚠️ **必须先关掉内置 Top Bar**。两者都通过 `ShellWorkArea` 独占预留原生工作区，
同时启用会在预检阶段直接失败：

```
denial-plugins: Native work area is provided by Top Bar and Neo Top Bar.
Reference Desktop accepts only one. Disable one of these plugins before applying.
```

本地开发安装：

```sh
denial-plugins --local add ~/Projects/Denial-plugins/plugins/neo_top_bar
denial-plugins remove denial_top_bar
denial-plugins plan
denial-plugins build CANDIDATE_ID
denial-plugins activate CANDIDATE_ID
```

或者全程在 GUI 里做：Plugins → Add plugin → 展开 *Local development* → 勾选
*Use a local development checkout* → 填目录 → Find plugins → Add plugin →
**先把 Top Bar 关掉** → Apply。

**边缘、厚度、显示器全部照读 Denial 自己的设置**，也就是
**系统设置 → 桌面系统栏** 里那三项：

| Settings 里的项 | 对应字段 | 效果 |
|---|---|---|
| 边缘（顶部 / 底部 / 左侧 / 右侧） | `systemBarSide` | 栏贴哪条边；选「隐藏」则整栏不出现 |
| 显示器（可多选） | `systemBarOutputNames` | **每个选中的显示器各有一条自己的栏**，没选的屏不显示 |
| 系统栏厚度（像素） | `systemBarThickness` | 栏的高度，同时也是**原生工作区预留**的厚度 |

厚度这一项特别重要：它同时决定「画多高」和「预留多少原生空间」。两者必须用同一个值，
否则要么窗口压到栏上，要么栏下留一条缝。本插件把这两个计算收敛到同一个函数
（`neoTopBarStripThickness`），`place()` 和 `reserve()` 都调它，所以无法漂移。
如果这一项被设成 0 或负数（`edgeBounds` 和 `ShellWorkAreaReservation` 都会抛异常），
回落到 `neoTopBarFallbackThickness`（33）。

卡片会**填满栏的厚度**（和 Denial 自己的栏一致），所以把厚度调大时药丸会一起变高，
而不是留一堆空白。觉得太占地方就把厚度调小，或者用组件设置面板里的「紧凑」间距。

## 开发

先从 Denial 准备好的构建套件里取出工具链路径，**不要写死**（每台机器、
每次 Denial 升级后路径都不同）：

```sh
DENIAL_PLUGIN_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/denial/plugins"
DENIAL_PLUGIN_FLUTTER="$(jq -er '.flutter' "$DENIAL_PLUGIN_STATE/configuration.json")"
DENIAL_PLUGIN_RUNTIME="$(jq -er '.runtime' "$DENIAL_PLUGIN_STATE/configuration.json")"
DENIAL_PLUGIN_DART="$(command -v dart)"
```

然后：

```sh
"$DENIAL_PLUGIN_FLUTTER" pub get
"$DENIAL_PLUGIN_DART" format --output=none --set-exit-if-changed lib test
"$DENIAL_PLUGIN_DART" analyze --fatal-infos lib test
```

`pubspec_overrides.yaml` 里要把两个 SDK 指向
`$DENIAL_PLUGIN_RUNTIME/packages/{denial_sdk,denial_flutter_sdk}`
（**绝对路径**，YAML 不展开 `$VAR`）。它和 `pubspec.lock` 都已在 `.gitignore` 里：
本机 SDK 路径一旦被 pub 写进 lock 就带上机器信息了，所以两个都不提交——
上游的 `denialwm/denial-plugins` 同样不提交 lock。SDK 版本约束写在 `pubspec.yaml` 里。

纯逻辑测试**不要**用 `dart test`（本包依赖 Flutter SDK，`dart test` 会在解析阶段失败）。
直接指定已解析好的 package config 跑：

```sh
"$DENIAL_PLUGIN_DART" --packages=.dart_tool/package_config.json test/config_test.dart
"$DENIAL_PLUGIN_DART" --packages=.dart_tool/package_config.json test/bar_budget_test.dart
"$DENIAL_PLUGIN_DART" --packages=.dart_tool/package_config.json test/popup_geometry_test.dart
"$DENIAL_PLUGIN_DART" --packages=.dart_tool/package_config.json test/preferences_test.dart
"$DENIAL_PLUGIN_DART" --packages=.dart_tool/package_config.json test/window_order_test.dart
"$DENIAL_PLUGIN_DART" --packages=.dart_tool/package_config.json test/control_center_model_test.dart
```

### Denial 是源码构建的时候，apply 要用哪一份工具

这台机器上现在同时存在两套 Denial：系统包 `denial 0.5.0-1`（`/usr/bin/deniald`，登录器里的
`Denial`）和本地源码构建（`~/.cache/denial/pc-build/rust/release/deniald`，登录器里的
`Denial (development)`）。**插件构建套件是按「已安装构建」的身份选的**，所以用错工具就会出现：

```
plugin bundle source does not match installed Denial; prepare the matching build tools and rebuild
```

（bundle 构建成功、但 shell 拒绝启用，composition 停在旧候选上。更麻烦的是：系统那份
manager 会把它认的 kit 写进共享状态，并**顺手删掉 dev 那份 kit**。）

在 dev 会话里改插件时，用**本地构建自带的那份 manager**：

```sh
DENIAL_SRC="$HOME/Projects/Denial/denial"
"$DENIAL_SRC/tools/denial-plugins" bootstrap          # 按运行中的构建重新准备 kit（自带正确身份）
"$DENIAL_SRC/tools/denial-plugins" --brief status     # 确认 configuration.build-kit 变了
PUB_HOSTED_URL=https://pub.flutter-io.cn "$DENIAL_SRC/tools/denial-plugins" submit apply
```

判断标准：`status` 里的 `configuration.build-kit` 指向的 kit，其 `kit.json` 的
`identity.source_revision` 要等于**正在运行的那个 deniald** 的源码修订（dev 构建就是
`~/Projects/Denial/denial` 的 `git rev-parse HEAD`）。kit 哈希是按输入算的，所以同一个构建
每次算出来都一样（这台机器上 dev 构建 = `b48ea491…`，0.5.0 包 = `8b3b2d88…`）。

顺带一个反直觉但正常的现象：**dev 会话和系统会话共用** `~/.local/state/denial/plugins`，
所以两边切换登录时 shell 会各自重建一次插件候选（切换期间黑几秒），属预期行为。

## 代码结构

```
lib/
  neo_top_bar.dart          @Plugin() 入口：ShellSurface + ShellWorkArea + ShellAction
  neo_top_bar_logic.dart    纯 Dart 导出，供测试使用（不引 Flutter widget）
  src/core/
    module_descriptor.dart  模块身份类型（id / 标签 / 区 / 优先级 / 默认开关）
    module_defaults.dart    ★ 默认布局的唯一来源：id 字符串 + 10 个描述符常量
    module.dart             模块契约 + NeoModuleContext
    module_registry.dart    注册表：描述符 id → 实现，`all` 由默认常量派生
    config.dart             配置模型、JSON 解析、区/排序解析（NeoDensity）
    config_state.dart       运行时配置状态（内存生效 + 后台持久化）
    preferences.dart        配置文件读写（原子写、保留未知键、写合并）
    drop_target.dart        落点解析（先判区，再判区内间隙）
    bar_drag_layout.dart    三个区的几何：显式坐标 / 拖动预览共用
    bar_budget.dart         空间预算：什么时候让步、记忆怎么防抖（不引 dart:ui，可单测）
    popup_geometry.dart     面板锚定几何（不引 dart:ui，可单测）
    window_order.dart       启动器窗口图标的稳定顺序（不引 dart:ui，可单测）
    control_center_model.dart 控制中心的纯逻辑（列表排序、主题切换、有线判定、确认规则、选项解析）
    calendar_data.dart      日历的纯日期逻辑
  src/modules/              每个模块一个文件
  src/widgets/
    neo_bar.dart            三个区的布局、拖动、右键菜单接线
    neo_card.dart           药丸卡片外观（玻璃 / 渐变 / hover / 聚焦）
    neo_setting_controls.dart 设置行 / 开关：面板与模块设置共用
    neo_popup_surface.dart  弹出面板外观
    module_settings_panel.dart  组件设置面板
```

### 默认布局只有一个来源

`module_defaults.dart` 是 id、区、优先级的**唯一**书写处：10 个模块实现、
注册表和测试都读它。注册表的 `_factories` 只把描述符 id 映射到实现，
`NeoTopBarModules.all` 再按这份常量列表生成——所以：

- 描述符加了但没写实现 → **第一次使用直接抛错**，不会悄悄少一个胶囊；
- 改了某个模块的区/优先级 → 测试里那条"默认布局"断言立刻失败。

这一层是补上的：早先测试里手抄了一份描述符清单，抄的是"我想要的"布局，
而注册表里托盘其实还在左区，测试却是绿的。现在两者不可能再分叉。

### 区的判定：先判区，再判位置

拖放的落点解析是**两步**，顺序不能反（`drop_target.dart` 的 `neoDropZoneAt`）：

1. **指针落在哪个区的范围内**——每个区把所有可见胶囊沿主轴并成一段区间。
   区间之间的空白按**中点**归属，所以栏中间的空白不会突然跳到另一侧。
2. **再在该区内部算插入位置**，只和这个区自己的胶囊比较。

反过来的写法（"插到第一个中点在指针右侧的胶囊之前"，按那个胶囊的区决定归属）
会有个致命毛病：**指针只要越过某区最后一个胶囊的中线，归属就会翻到下一个区**。
这个 bug 真发生过——把系统托盘拖到工作区胶囊上、松手却落到了中间的应用启动器旁边，
因为落点在工作区胶囊的右半边，规则判定"插到工作区之后"，而它后面正好是中间区的启动器。

被拖动的胶囊**仍然计入**它所在区间的范围：它的槽位尺寸不变，而且如果一个区只有它一个
胶囊（比如中间区的启动器），把它排除就会让那个区变成无法投放到的地方。

### 手势宿主不能被销毁

承载长按的 `_DraggablePill` 只要被**重建**（换了 element），拖动就废了：
Flutter 在手势识别器 `dispose` 时**不会调用 `onLongPressEnd` / `onLongPressCancel`**
（`OneSequenceGestureRecognizer.dispose` 只把指针路由摘掉），所以那个拖动**永远收不到
后续的 move / end 回调**。症状很有欺骗性：

- 被拖的胶囊被"定格"在按下位置 → 看起来是"某个胶囊卡死了"
- 布局里没有 `_DraggablePill` 包装 → **所有胶囊都没有长按处理器** → 什么都拖不动
- `_draggingId` 清不掉 → 永久卡在拖动状态，直到外壳重启

修法是每个胶囊挂一个**按 id 稳定的 GlobalKey**（`_pillKeys`）：GlobalKey 会让 Flutter
**搬迁 element 而不是重建**，识别器和进行中的手势就活下来了。这条现在承受的压力比以前
更大——不仅拖动预览要复用它，**flex 与显式定位之间来回切换时也要复用**。

另外加了一道兜底：顶栏的 `Listener` 也监听 `onPointerUp` / `onPointerCancel`，
指针在栏内抬起时无论如何都会结束拖动，避免再出现"永久卡住"。

### 常驻显式定位：让任何排序变化都能动

顶栏**平时**就用显式坐标放置（`neoDragLayout` 算出的 `main` / `cross`），
不是只在拖动时才切过去。原因很直接：显式坐标意味着每颗胶囊都是
`AnimatedPositioned`，于是**任何**顺序变化都会自己滑到位——

- 在栏上长按拖动（预览顺序来自 `moveModuleToSlot`）
- 在设置卡片里点 ↑ ↓ 或换区（`config_state` 通知之后重建）

早先只在拖动时切显式定位，从设置卡片改顺序是**瞬间跳到新位置**的，因为平时是 flex，
flex 只描述"最终排布"，没有"上一帧在哪"。现在两条路径共用同一套动画。

布局函数必须和 flex 的规则逐条一致（start 贴前缘、center 居中、end 贴后缘），
否则第一次切换布局时会跳。它是纯函数，有单测钉住。

flex 布局降级为**测量 + 溢出兜底**，两种情况仍会用它：

1. **首帧 / 尺寸变化后的那一帧**：胶囊尺寸要等布局完成才知道，所以显式定位永远慢一帧
   （`_PillSizeReporter` 在 `performLayout` 里上报，post-frame 才 `setState`，
   见下文）。两种布局在这些位置上一致，所以这一帧看不出来。
2. **放不下**：胶囊按内容自身定尺（时钟、百分比、托盘），显式定位无法重叠两个区，
   所以总量超出栏长时改回 flex，让区可以滚动。

拖动中每颗胶囊的 widget 实例按 `_moduleCache` 缓存，key 是模块上下文的
`Object.hash`（services / monitorId / side / accent / density）。指针每动一帧都会重建
widget 树，复用实例能让 Flutter 跳过整棵子树的重建（包括宿主渲染的托盘）；
它失效的唯一条件是这些上下文真的变了。模块内容本身都是 `ConsumerWidget`，
providers 变化时自己重建，不依赖父级重建。

### 胶囊自己变尺寸时，必须能叫醒布局

显式定位只和**上一次测量**一样新。而胶囊的尺寸是它自己的内容决定的——托盘图标增减、
时钟跨过 `9:59 → 10:00`、媒体曲名变长、启动器窗口增减——这些变化**只让那颗胶囊重建**，
顶栏本身没有变脏。于是"在 build 里排一次 post-frame 测量"这个机制根本不会触发：
尺寸变了，`_pillExtents` 还是旧值，布局继续按旧宽度摆放。

这个 bug 的表现非常具体，也是你报的那个：

- 关掉一个后台应用 → 托盘胶囊变窄 → 但它**原地缩**（左边缘不动），
  于是它和右边那颗胶囊之间的间隙比别处大，而且一直不消失；
- 媒体停播后，媒体胶囊渲染成 0 宽，但布局还按它播放时的宽度留位 →
  **原地留下一个大洞**（你的右区顺序是 `tray, media, battery, clock, notifications`，
  所以洞正好在托盘和电池之间）。

修法是让每颗胶囊**在布局里自己上报尺寸**（`_PillSizeReporter`，一个
`SingleChildRenderObjectWidget` + `RenderProxyBox`）：`performLayout` 是唯一一个
"不管是谁引起的、都在这一帧拿得到新尺寸"的地方，所以上报就从那里取。

- 它只在尺寸**变化**时上报，且只上报主轴那一维（横向那一维由
  `AnimatedPositioned` 显式给定，变化没有信息量）；首帧一定上报，这就是 `_pillExtents`
  的初始来源。
- 回调发生在布局期间，**不能同步重建**，所以它只写字段（写 `_pillExtents` 不涉及
  `setState`）并登记一次 post-frame 的 `setState`——下一帧才用新位置，这也是"显式定位
  永远慢一帧"的来源。
- 多个胶囊在同一帧上报会被合并成一次重建。

> 先试过 `SizeChangedLayoutNotifier` + `NotificationListener`，能用，但它把"尺寸"这个
> 事实绕成了"通知"这个约定；直接在 `performLayout` 里取尺寸少一层解释，也不再依赖
> 通知冒泡的语义。旧的"post-frame 里统一量一遍"整套机制（`_scheduleMeasure`）因此删掉了。

**零宽 = "我现在什么都不渲染"，不占位置也不占间隙。**
`neoDragLayout` 把这类胶囊放在区的边缘、宽度 0，但仍然**放在 `placed` 里**：
它必须留在树上，因为顶栏就是靠"测到它不再是 0"来知道它回来了；把它卸载掉，
它就永远回不来。`neoPillsFit`（决定用显式定位还是 flex 兜底）用同一套规则，
否则会在"放得下"和"放不下"之间来回翻。

那条"间隙"因此变成三段式的正确行为：

| 事件 | 现在的行为 |
|---|---|
| 胶囊变窄（托盘少一个图标） | 右区贴右不动，胶囊**左边缘右移**补上，间隙保持均匀 |
| 胶囊变成 0 宽（无播放器 / 托盘为空） | 连它的间隙一起收掉，前后胶囊合拢 |
| 胶囊从 0 变宽（开始播放） | 重新占位，前后胶囊让开 |

（第一版只修了"重新测量"，零宽胶囊仍会留下一个 `gap` 大小的空档；两处都修才算完整。）

### 拖动中"被拿起的那颗"必须画在最上面

`Stack` 按 children 顺序绘制，而这个被拿起的胶囊在 children 里是**按预览顺序**排的，
于是它会被排在它后面的胶囊盖住，也被最后追加的虚影盖住——你看到的就是"这颗胶囊跑到
虚影和其他胶囊底下去了"。

所以 `_buildPositionedLayout` 把它单独收集到 `lifted`，在最末尾（虚影之后）追加：

```
children = [其余胶囊（按预览顺序）, 虚影, 被拿起的那颗]
```

GlobalKey 保证把它挪到列表末尾是**搬迁 element**而不是重建，手势识别器照旧活着；
它自己的 `AnimatedPositioned` 用的是 `Duration.zero`，所以绘制顺序的变化不会带来位移。

### 拖动：冻结落点

**落点测量在拖动开始时冻结**（`_dragRects` / `_dragZones`）。
不能边拖边测：预览本身会重排布局，实时测量会让"目标位置"依赖"目标位置自己造成的
布局"，形成反馈循环，落点会在两个位置间反复跳。

**长按一到临界值就开始居中，不需要你先动鼠标。** 这里踩过一个坑：
`_moveFeedback` 原本在指针事件里就把中心**算好存起来**，而动画跑的时候没有指针事件，
所以存的值一直没变——**胶囊只有在你开始拖动（产生指针事件）时才重算并跳到位**。
现在只存**指针位置**，中心在 build 时用当前偏移现算，动画每帧重建就自己滑过去。

**只有主轴（横栏 = 水平）移动，垂直方向的量是"钉死"的。**

早先的写法里有一个隐蔽 bug：偏移是一个 `Offset`，动画结束时整块归零（包括垂直分量），
于是滑动**结束的那一刻**胶囊的垂直中心从原位跳到鼠标高度——看起来就是"水平平滑、垂直瞬移"。
现在拆成两个量：

```
_grabMain      主轴距离，动画 0→1 归零（居中到鼠标）
_anchorCross   垂直中心，抓住时记下后整个拖动过程恒定
```

垂直方向本来也不该跟着鼠标走：胶囊 45px、栏 55px，跟着鼠标只会滑出栏被裁掉。
重排是"沿栏移动"，所以只有栏的方向需要动。

滑动用的是**时长+曲线**而不是弹簧：弹簧 token 在 0.2 秒内就冲过一半，读起来是"弹一下再
慢慢爬"，不像"移过去"。现在是 `360ms` + `Motion.md3Emphasized`（Cubic(0.2,0,0,1)）：

- 刻意**没有**用 `Motion.md3EmphasizedDecelerate`：它 60ms 就走完 74%，是"快起慢收"，
  比弹簧还弹
- 缩短时长（450ms → 360ms）而不是换曲线，这才是解决"有点慢"的正确做法——"慢"来自
  总时长，不是曲线形状

```
  0ms → 160.0   原位，无跳变
 45ms → 172.8
 90ms → 190.4
180ms → 203.9
360ms → 210.0   中心与鼠标重合
```

"变大一档"用的是**同一组时长与曲线**，所以"变大 + 移过来"读起来是一个动作（拿起），
而不是两个。按下/抬起的即时反馈仍然是弹簧（`snappy` / `bouncy`），保持点击的灵敏手感。

**抓取偏移是"动画归零"的，不是一步到位**：

```
抓住时记下  _grabMain = 胶囊中心 − 按下点（主轴）
_grab       0 → 1，360ms + Motion.md3Emphasized
反馈中心    = 指针 + _grabMain × (1 − _grab)
```

两个极端都试过，最后定位到中间这个：

| 做法 | 按下瞬间 | 结果 |
|---|---|---|
| 反馈中心 = 指针 | **瞬移**半个胶囊宽 | ✗ 你最早看到的问题 |
| 反馈中心 = 指针 + 固定偏移 | 完全不跳 | ✓ 但胶囊永远停在抓取点，不会自动居中 |
| **反馈中心 = 指针 + 动画归零的偏移** | 首帧在原位，随后滑到光标下 | ✓✓ 现在的做法 |

所以长按触发拖动时：**第一帧胶囊就在你抓住它的位置**（无跳变），然后用上面那组时长曲线
在 0.36 秒内滑到光标下方，最终**胶囊中心与鼠标重合**。

只有**主轴**（横栏 = 水平方向）做居中：栏只有一颗胶囊那么高，垂直方向去对齐光标只会
把胶囊顶到栏边上被裁掉，没有意义。

落点判定用的是同一个"当前位置"（指针 + 当前偏移），所以滑动过程中判定跟着胶囊走，
而不是跟着鼠标走。

虚影是**形状**而不是胶囊的第二次构建：半透明副本会把 `ShellBackdropBlur` 包进图层
（玻璃会采到图层而不是壁纸），而且会要求宿主托盘渲染两遍。

### 排序怎么算

顶栏拖拽走 `moveModuleToSlot`（一次操作同时决定**位置和区**，由落点间隙决定）；
面板里的 ↑ ↓ 走 `moveModuleInZone`（只在区内交换）。两者都先把该区的**有效顺序**
物化出来再改，因为 `order` 是稀疏覆盖层，用户从没排过序时没有列表可交换。
跨区移动会把模块从原来那个区的 `order` 里删掉，避免文件里留下骗人的陈旧条目。

### 区内排序怎么算

`config.dart` 里的 `moveModuleInZone` 先把该区的**有效顺序**物化出来，再交换相邻两项，
最后把整份区顺序写进 `order`。必须先物化：`order` 是稀疏覆盖层，用户从没排过序时
根本没有列表可交换。越界移动是 no-op，所以 UI 的按钮在区边界可以放心地置灰。
纯逻辑，有单测覆盖（物化、前移/后移、边界 no-op、跨区不越界、未知 id）。

### 启动器里的窗口图标：顺序固定

`services.windows(monitorId)` 返回的是**宿主的 z-order**，所以点一个图标去聚焦窗口，
那个窗口被提到最前，**整排图标跟着重排**——下一次要点的东西永远不在上一次教会你的
位置上。这是"点了就变"的根因。

修法不是换个排序键，而是**记住窗口第一次出现的顺序**（`core/window_order.dart` 的
`neoStableWindowOrder`），宿主顺序只用来决定"这一帧新出现的窗口谁在前"：

```dart
稳定顺序 = [还存在的旧顺序] + [本帧新出现的，按宿主顺序]
```

三条行为都是刻意的：

| 事件 | 结果 |
|---|---|
| 点击某个窗口 | 只有高亮板变，**任何图标都不动** |
| 窗口关闭 | 其余图标**不往空位里挤**，位置肌肉记忆保留 |
| 新窗口出现 | 追加到末尾（同一帧开好几个时按宿主顺序） |

记忆放在 `_LauncherContentState._order`：这是个 `List<int>`，每帧用当前窗口 id 重算，
**消失的 id 直接丢掉**，所以长度永远不会超过当前窗口数，不需要额外的清理逻辑。
写入字段发生在 `build` 里且**不调 `setState`**——这个值当场就被这次 build 用掉了，
没有"稍后生效"的东西要调度。

因为它只对"没见过的 id"参考宿主顺序，所以**不依赖宿主顺序的语义**：
就算上游把 z-order 换成别的规则，这个胶囊依然稳定。

溢出（`kMaxWindowIcons = 10`）是从**稳定顺序**前面截的，所以能看见的永远是那十个，
后开的窗口先记进 `+N`，直到这十个里有人关闭。这是"图标不动"的代价——
如果改成轮换可见集合，开窗关窗时整排又会动。

### 组件是「实例」，不是「模块」

栏上放的是**实例**：同一个模块可以出现任意多次，落在任意区，各自有各自的设置。
实例 id 是 `模块id`（第一个）和 `模块id#2`、`模块id#3`…（之后每一个），
所以第二个时钟可以被单独排序、单独设置、单独移除。要点：

- **配置里只有「改过的」实例**。每个模块的第一个实例总是存在（文件里没有就按描述符默认值合成），
  所以新装的模块会自己出现；多出来的实例则完全来自文件。
- **只有第一个实例可以被「冗余」掉**。一个只写了 `module: clock`、什么都没别的的条目，
  对第一个实例来说是废话（等于默认），可以删；对 `clock#2` 来说**那就是它的存在证明**，
  必须写下来——判断这件事的是 `NeoModuleInstancePreference.isRedundant(instanceId)`，
  而不是「有没有字段」。
- **编号会回收**。删掉第 2 份再加一份，新的还是 2 号，不会一路涨到 4 号。
- **编号只存在于内部**。卡片标题还是「工作区胶囊」，添加列表也只写「添加」——
  两份同类组件是靠**它在哪**区分的，把编号画到界面上只是噪音。
- **schema 1 能被直接读成 schema 2**：旧文件里的 `modules: {clock: {...}}` 就是
  「clock 的第一个实例」，`order` 里的模块 id 也正好是实例 id，所以升级不需要迁移代码，
  下次保存时写成 `instances` 并删掉旧的 `modules` 键。
- **一个模块一份实现**：实例只是「哪个模块 + 它自己的设置 + 它在哪」，画法仍由模块本身决定。

### 组件设置面板：一块「区看板」

面板以前是**一行塞满**：名字 + ↑↓ + 左中右 + 开关。四个控件之后那一行已经没有位置了，
所以像控制中心这种**自己也有选项**的模块无处可放；而且「位置」和「顺序」在每个模块上
重复了一遍——那两件事本来就是**区和拖动**该表达的。现在是一块看板：

```
左侧                                             ← 区标题
┌ ⠿ 工作区胶囊                        [开关] ┐    ← 卡片：手柄 + 名字 + 开关
│   显示工作区数量、当前工作区与占用状态  [设置 ▾] │
│   ┌ 「工作区胶囊」设置 ─────────────────────┐ │    ← 展开：模块自己的选项
└───────────────────────────────────────────┘
┌ ⠿ CPU 负载                          [开关] ┐
└───────────────────────────────────────────┘
        [ + 添加组件 ]                            ← 放在这一段
中间
…
右侧
…
```

- **区决定位置**：卡片属于哪个区，实例就在哪一段；「添加组件」把**新的一份**放进这一段
  （不是把别处的搬过来），所以每行不再需要左/中/右选择器，同一个组件也能加好几个。
- **拖动决定顺序**：每个区是一个 `ReorderableListView`，拖动只在区内生效。
  落点换算成配置要的「排在谁前面」这件事很容易差一位，所以它是纯函数
  `neoBeforeIdAfterReorder`（4 种情形都有单测）。
- **手柄和整卡拖动不能嵌套**：`startItemDragReorder` 在已有拖动时会**取消**当前拖动，
  所以手柄的即时监听器和整卡的「长按拎起」监听器是**并列**的（手柄在左，其余在右），
  不是嵌套——嵌套的写法会让手柄拖到一半被自己取消。
- **移除的实例不在看板上**，只在添加列表里：它本来就不在栏上。第一个实例的「移除」
  记成 `enabled: false`（不能真删，否则会被当成没配置过的默认值又长回来），
  多出来的实例则整条删掉。
- **同一组件可以加任意多份**，卡片标题都一样；两份同类组件靠所在位置区分，
  编号只在配置里用来寻址。

- **模块自己的设置是一份「能力」，不是契约的必填项**：`NeoModule` 只负责画胶囊，
  有选项的模块另外实现 `NeoModuleSettings`（`buildSettings(context, scope)`）。
  没有选项的模块一行都不用改，面板会显示「这个组件暂时没有自己的设置」。
- **选项在配置里是不透明的**：`NeoModulePreference.options` 是一张
  `Map<String, Object?>`，配置层只负责存取和清理，**不解释内容**。
  所以某个模块加一个选项**不需要改 schema**，旧版本留下的未知选项也不会让谁报错。
- **取值一律容错**：user 手改 JSON 时可能写入错误类型，所以读取都有默认回退
  （`NeoModuleSettingsScope.boolOption`），而且只有能原样写回的值才会被接受——
  解析不出来的值**整条丢掉**，而不是修一半丢给模块。
- **toggle / 描述行的样式只有一个来源**：`neo_setting_controls.dart` 里的
  `NeoSettingRow` / `NeoSettingToggle`，面板和模块设置都用它，免得同一个卡片里
  出现三种长得略不一样的开关。
- **窄行怎么排，由行自己声明，不靠猜**：`NeoSettingRow.fit` 只有两个值——
  `beside`（默认，开关/滑条这类小控件留在右边）和 `under`（一排 chips 这种要宽度的，
  在窄卡片里落到文字下面拿整行宽度）。**第一个版本是「看 child 是不是
  `NeoSettingToggle`」来决定的，控制中心那几行把开关包在 `Builder` 里，于是同一张卡里
  上面几行堆叠、下面几行不堆叠**——看起来像两套设计。类型判断被换成显式声明，
  以后加一排 chips 记得写 `fit: NeoSettingRowFit.under`。
- **只有设置、没有开关的模块也会留下配置条目**：`withEnabled` / `withZone` / `withOption`
  三个方法都会带上其它字段。以前「开关一个模块」会顺手把它的**分区选择丢掉**，
  现在这一并修了（有单测钉住）。
- **同一个设置只有一份实现**：看板里展开的卡片和右键胶囊弹出的小卡片都用
  `NeoExpandedModuleSettings`，只是后者 `showTitle: false` / `inset: false`。
  两张卡读的都是 `placement.options`，写的都是 `state.setOption(placement.id, …)`，
  所以「同一个模块加了两份」时，两边永远改的是同一份实例，也不会有一边少一个选项。
- **按实例寻址**：右键哪一份胶囊就开哪一份的设置。卡片打开期间会跟着 `state` 重建
  （`AnimatedBuilder`），因为有些设置会决定**下面那行是否存在**（时钟的日期格式行只在
  「显示日期」打开时出现），只建一次的卡片会留住过期的形状。
- **设置卡是「指针弹出」，不是居中面板**：它和右键菜单都走新的
  `neoPointerPopupPlacement`（纯函数 + 单测）——左上角贴着鼠标，右边放不下就翻到左边，
  下边放不下就往上开，并且始终夹在自己那块输出里。

### 图标大小只看系统栏厚度，不看间距

紧凑 / 标准 / 宽松是**间距**设置：它改变胶囊之间的距离和卡片内边距，
**不应该改变胶囊里图标的大小**。之前控制中心胶囊把图标按 `density` 缩放，于是切一次间距
连图标都跟着变——这是错的，而且和别的胶囊不一致（启动器的图标本来就是按栏厚算的）。

现在统一走 `NeoModuleContext.glyphSize(fraction)`：它根据**这一帧量到的胶囊高度**
（= 丹尼奥设置里的「系统栏厚度」减去栏自己的边距）算出图标大小，并 clamp 在可读范围内。
控制中心和启动器都用它，所以调厚度时一起变大变小，调间距时一个都不动。

### 语言跟随 Denial 的语言设置

插件自己的文案不写死在 widget 里，而是集中在 `lib/src/core/l10n.dart` 的 `NeoStrings`：

- **一个短语一个 getter，中文在前、英文在后，写在同一个表达式里**——加短语时不可能只写一种语言。
- 语言从哪读？Denial 的壳在整棵场景树外面套了 `DenialLocalizationScope`（内部是真的
  `Localizations`），所以 `Localizations.maybeLocaleOf(context)?.languageCode` 就是用户选的语言。
  `l10n_context.dart` 把它包成 `context.neoStrings`（widget 里用）和 `neoStringsFor(code)`（纯逻辑/测试用）。
- **只支持中/英两种**，和 Denial 自己一致：`zh*` → 中文，其余一律英文（`neoLanguageFromCode`）。
  连 AM/PM 也收窄成这两种（`neoMeridiemLabels` 不再返回日文/韩文）。
- 组件名、组件描述、区名**不再挂在 `NeoModuleDescriptor` 上**（描述符只留布局事实：id、区、优先级），
  改为 `s.moduleLabel(id)` / `s.moduleDescription(id)` / `s.zoneLabel(zone)`，按 id 去目录里取。
  好处是描述符里不可能留一句「只有中文」的旧文案。
- 日期回退模板也分语言：`neoFallbackDatePatternFor(languageCode)`——宿主模板读不出来时，
  英文用户不该看到 `10月8日`。
- **弹窗也在语言作用域内**：设置面板走 `shellPopupControllerProvider.show`，而 `ShellPopupHost`
  挂在 `DenialLocalizationScope` **下面**（查过 `denial_shell.dart` 的挂载顺序），所以面板里
  `context.neoStrings` 拿到的是同一个语言，不是回退值。
- `test/l10n_test.dart` 守着两件事：英文里不许出现汉字；两种语言不能写出同一句话
  （只有 `volumeLabel` 的「50%」这种例外，逐个列在 `neutral` 里）。

### 竖栏（系统栏在左/右）下每个胶囊怎么排

胶囊**竖着排**是 `neo_bar.dart` 本来就有的：栏的方向来自 `PanelEdge`，位置和尺寸都按主轴/交叉轴算。
真正要每个组件自己处理的，是**胶囊内部**——竖栏的胶囊宽度就是栏的厚度（55px 的栏 → 45px 胶囊），
横排的内容一定溢出，所以 `module.horizontal == false` 时改成竖排**并精简**：

| 组件 | 横栏 | 竖栏 |
|---|---|---|
| 时钟 | 日期 + 时间一行 | **只留时间**（`20:52` 已接近 33px 可用宽度的极限），日期点开日历看 |
| CPU / GPU | 名字 + 折线 + 百分比 + 温度一行 | 名字 / 百分比 / 温度 / 折线自上而下，折线画窄一点（28px）。**名字必须留着**：GPU 的 label 本来就是紧凑厂商名（`AMD`、`NV0`），去掉之后 CPU 和 GPU 只是两个没名字的数字 |
| 媒体 | 标题 + 上一首/播放/下一首一行 | **只留三个按钮**（标题在这么窄的胶囊里只剩省略号） |
| 电池 | 横向电量条 + 百分比 | 电量条**转 90°**（`RotatedBox`，矢量绘制不会糊）+ 百分比 |
| 启动器 | 图标 + 窗口图标一行 | 图标 / 分隔线 / 窗口图标自上而下；竖栏最多叠 **5** 个（`kMaxWindowIconsVertical`），其余记在 `+N` |
| 控制中心 | 状态图标一行 | 状态图标自上而下叠 |
| 工作区 / 托盘 / 通知 | 本来就方向感知（`Axis.vertical`、`buildSystemTray(horizontal:)`、图标+角标居中） | 同左 |

还有一条**共用的内边距规则** `neoCardPadding()`：横栏只用左右内边距（高度由栏定），
竖栏反过来用上下内边距、左右收到 6px——否则 12px 的两侧会把 45px 的胶囊压到只剩 20px 可用宽度，
连一个图标都放不下。启动器（10）、托盘（10）、工作区（12）保留各自的横栏值，只在竖栏收到 6。

**这一部分是纯布局，没有 widget 测试**：只能把系统栏挪到左边或右边，用眼睛验收。

### 空间不够时：谁让步（以及为什么不会再被挤出屏幕）

栏的宽度是有限的，而胶囊的内容是用户配的。规则是**按重要性一级一级让步**，不是平均分，也不是
一刀切。让步顺序（`NeoConcession` 的阶梯，和这张表一一对应）：

| 阶梯 | 谁让步 | 怎么让 |
|---|---|---|
| 1 | 系统托盘 | 只留前 3 个图标，末尾换成**向下的箭头**（Windows 那种展开标记，个数在 tooltip 和无障碍标签里）；**点箭头弹出面板，里面只有被折叠的那几个**（宿主渲染的那套，菜单/子菜单照常可用） |
| 2 | 媒体 | 去掉曲目标题，只留传输按钮（标题在播放器里本来就看得到） |
| 3 | 时钟 | 强制只显示时间（日期点开日历就能看） |
| 4 | 启动器 | 去掉窗口图标条，只留那个图标（点它照样开启动器） |
| 5 | 工作区 | 关掉每个格子里的窗口图标，退回纯圆点 |

**一级一级让，刚好装下就停**。这一点很要紧：这台机器的内屏是竖屏（逻辑宽只有 855px），自然宽度
比栏只多几十像素；早期版本一超就"全部可选项一起丢"，于是首页那种画面（日期、曲目标题、工作区
图标、两个托盘图标全没了）只为了换回 200 多像素根本用不到的宽度。现在只会丢到刚好装下为止，
最坏情况也只是退一两次。

判定在 `core/bar_budget.dart`（纯类 + 单测）。这里有个**非做不可**的细节：不能拿"让步之后测出来
的宽度"去判断能不能把让掉的拿回来——让步之后每个模块都会变窄，所以让步态的胶囊**按定义**一定
装得下；那样判就会：拿回来 → 下一帧发现又超了 → 再让 → 无限循环，一帧进一帧出地抖，而且每一帧
都用另一套尺寸定位，胶囊看起来还会互相压。所以栏记的是**每一级让出了多少**（`savingOf(step)`）：

| 时机 | 怎么算 |
|---|---|
| 往上让一级 | 立即（内容正在被挤出屏幕），但**一帧只让一级**，因为让完的下一帧才能量到这一级值多少 |
| 往下退一级 | 只有估算（`本帧实测 + savingOf(当前级)`）比 `available - 32px` 还宽裕时才退 |

于是内容缩小（媒体停了、托盘少了图标）时估算跟着变小，栏能自己一级一级走回来；而"让掉的拿不
回来"这件事永远不会发生。让出的宽度按级记账，每一级都必须在往上爬的时候量过，所以往下退永远
有数可依（栏一定是从 0 级往上爬的）。

模块自己决定"哪一部分是可选的"（`NeoModuleContext.concession`：0 是完整栏，每上一级拿走一样
东西），栏**不会**因此隐藏整个胶囊：用户开着的模块永远在，只是变小。

#### 兜底布局（flex）必须和显式定位摆在同一位置

胶囊大小是**上一帧**量到的，所以内容一变尺寸（包括阶梯升降），这一帧就退回 flex 布局重新量一次。
这意味着两套布局会被来回切换，**它们必须把每个胶囊放在同一个位置**，否则每次切换都会看到"跳一下"。

两套布局的规则现在是同一句话（`core/bar_drag_layout.dart` 的 `neoDragLayout` 和
`_buildFlexLayout`，共享 `neoZoneRuns` / `neoCentreRoom` / `neoCentreOffset` / `neoCentreAlign`）：

- start 贴前缘，end 贴后缘；
- **center 摆在「栏的中央」**（`neoCentreOffset`：`(栏宽 - center 宽度) / 2`）——用户就是这么读
  它的，而且两边胶囊变宽变窄时它不会跟着漂；
- 这个中央位置会被**夹进** `neoCentreRoom`（start、end 两条 run 留出的空间，各隔一个 `gap`）：
  某一侧超过栏宽一半时，栏的中央会落在它里面，夹一下才不会把 center 压在邻居身上。超宽时
  flex 布局里 center 是被压进这块空间滚动的，所以它只会在空间内滑动，永远不会盖住别人；
- 相邻两区之间隔一个 `gap`，也就是 `neoPillsFit`/`neoRunExtent` 在跨区那一对胶囊之间算的那一个；
- center 是唯一"吸收剩余空间"的那一区；如果 center 区什么都没画（比如启动器模块不可用），
  用一个 `Spacer` 顶替它，否则 end 会跑到 start 旁边而不是贴后缘。

**这里踩过一个坑**：一开始把 center 改成"居中于它自己那块空间"，理由是"两套布局必须完全一致"。
结果在 2560px 宽的外屏上，start 只有 100 多像素、end 有 700 多像素，于是"空间的中央"比"屏幕的
中央"偏左一百多像素——启动器看起来被挤到一边去了。正确做法是两层：**目标是栏的中央，只有在
中央被邻居占了的时候才退回空间内夹取**。flex 布局那边不是用 `Center` 而是给 `Align` 算了一个
偏移量（`neoCentreAlign`），这样它能在自己那块空间里把 center 摆到栏的中央，两套布局逐像素一致
（`test/config_test.dart` 里有一条"两套布局对 center 的结论必须相同"的property 测试钉住）。

#### 顺带修掉的一个真 bug：兜底布局会把右端挤出屏幕

内容放不下时栏会退回 flex 布局，而它原来是 `Row(spaceBetween)[Flexible(start), Flexible(end)]
+ Stack[Center(center)]`：

- start 和 end 各拿 `flex: 1` → **end 区被限制在半个栏宽以内**，而 end 区的
  `SingleChildScrollView` 从左边开始显示，于是它**尾部**的胶囊（控制中心、时钟）被裁掉——
  这就是内屏上"时钟被挤出显示"的原因；
- center 区在 Stack 里没有宽度约束，一个很宽的媒体胶囊会直接**盖住** end 区。

现在是一个 `Row`，按优先级给宽度：**end 保持自然宽度**（时钟和状态图标是最需要一眼看到的），
center 拿剩下的并在不够时滚动，start 最多占一半（免得一堆工作区图标把别人吃掉）。

### 工作区胶囊：可选显示每个工作区的窗口图标

默认**关**（打开之后胶囊会明显变宽），在**胶囊自己的设置**里开：右键工作区胶囊 → 展开设置 →
「胶囊里显示窗口图标」。

打开后，每个工作区格子本身就是一个小胶囊。**有窗口的格子只画图标（加 `+N`），不再画圆点**——
圆点只会重复图标已经说过的话，还占掉图标想要的宽度；**空工作区保留那个小圆点**，因为那是它
唯一能画的东西（也是"这里有个工作区，只是空的"唯一读法）：

| 格子 | 内容 | 填充 |
|---|---|---|
| 当前工作区、有窗口 | 图标 + `+N` | 强调色（最亮） |
| 非当前、有窗口 | 图标 + `+N` | 淡填充 |
| 当前工作区、空 | 小圆点 | 强调色 |
| 非当前、空 | 小圆点 | 无 |

分组规则都写在 `core/workspace_windows.dart` 里（纯函数 + 单测），widget 只负责画：

| 规则 | 行为 | 为什么 |
|---|---|---|
| 上限 3 | 放不下的记成 `+N` | 一个工作区格子是「大胶囊里的小胶囊」，超过 3 个就不再像一个工作区了 |
| 排序 | 粘性窗口最前，其余按 `objectId` | 新开的窗口排到最后，已经在屏幕上的图标不会因为新开一个就重排 |
| 粘性窗口（`pinned`） | 只画在**当前工作区**那一格 | 它在每个工作区都可见，画九遍就是同一个图标重复九次 |
| 最小化窗口 | 留在它自己的工作区格里，半透明 | 胶囊报告的是「这个工作区有什么」，不只是「现在屏幕上有什么」 |
| 只画本输出的窗口 | 按 `monitorId` 过滤 | 每个栏实例只管自己那块屏 |
| 工作区已经不存在 | 直接不画 | 数量缩小时 compositor 会自己 clamp，这里只是兜底 |

- **点图标 = 切到那个工作区 + 聚焦那个窗口**（粘性窗口已经在屏幕上，不切）；点格子其余部分 =
  切工作区（原行为不变）。图标是更内层的手势，所以不会和格子的点击打架。
- **当前工作区永远有填充**，哪怕它是空的：否则"我在哪一块"就没法看了。
- **没开这项时外观和以前完全一致**（纯圆点、没有填充）。
- **只在开关打开时才订阅窗口快照**：`shellControllerProvider` 每次窗口事件都会重建，纯圆点的
  胶囊没必要付这个代价。

### 启动器的设置：图标来源与窗口列表

| 选项 | 行为 |
|---|---|
| **默认** | Material 的九宫格图标（`Icons.apps`）——**任何机器上都画得出来**，所以它是所有回退的终点 |
| **系统** | 发行版图标：读 `/etc/os-release` 的 `ID`（没写就取 `ID_LIKE` 的第一个词），再按 `neoSystemLogoCandidates` 的顺序找 `/usr/share/pixmaps/<id>-logo.svg`、`<id>.svg`、hicolor 的几个尺寸；Arch 系（arch/cachyos/endeavouros/manjaro…）还会试 `archlinux-logo.svg` |
| **自定义** | 用户自己挑的一张图片（SVG / PNG / JPEG / WebP / GIF / BMP） |
| **Denial** | **列出来但是灰的、点不动**：官方图标还没有，选项先占位（`neoLauncherIconSelectable`） |

- **每个选择都有回退**：自定义但没选文件、或文件已被删掉 → 九宫格；系统但没找到图标 →
  先用**插件自带**的那张（Arch），再不行才九宫格。回退时设置里会写一行说明，
  栏上永远不会出现空胶囊。这条链是纯函数 `neoLauncherArt`，有单测。
- **`system` 的可选性由调用方判定**：「这台机器上找得到系统图标 **或** 插件带了自带图标」。
  两者都没有才回退。所以探测是同步的（一个小文本文件 + 几次 `exists`），
  胶囊第一帧就是对的，不会先闪一下九宫格。
- **自定义图片用内置的文件浏览器挑**（`NeoFileBrowser`）：插件 SDK 既没有文件选择器也没有
  portal 客户端，所以打不开原生对话框；能做的就是自己列目录（`dart:io` 对插件是可用的），
  让用户**看着找**而不是凭记忆敲一个绝对路径。只列目录和图片、隐藏文件不显示、
  一次一层——它是设置卡片里的选择器，不是文件管理器。排序规则（目录在前、忽略大小写、
  丢掉既不是目录也不是图片的东西）是纯函数，有单测。
- **路径显示成文件名 + 目录**，因为绝对路径经常比一行还长。

第二个设置是**是否显示当前工作区的应用图标**：关掉之后胶囊只剩启动器图标，
宽度随之收窄（尺寸上报本来就会处理）。窗口数据一直订阅着，所以再打开是即时的。

### 时钟的设置：日期、24 小时制、日期格式

三个选项：**显示日期**（关掉只剩时间）、**24 小时制**、以及**日期格式**（四种）。

日期格式这件事有个坑：**「长」和「短」在不同语言里排列不同**。Denial 的本地化给的是
两个模板（`shortDate` / `longDate`），中文是 `十月8日 星期四`，英文是
`Thursday 8 October`。自己拼字符串必然在另一种语言里排错，所以：

- 模板的**排列方式是从宿主自己的输出里读回来的**（`neoDatePatternFrom`）：
  传入宿主给的 `shortDate` 文本 + 本地化的月名/星期名 + 日号，把名字摘掉，
  剩下的就是分隔符和「日」这类后缀 → 得到 month-first / weekday-first 和连接符。
- 之后按这个 pattern **重新组合**任意子集，所以「只要月日」在中文是 `十月8日`、
  在英文是 `8 October`，两种语言都对（有单测用真实的两种模板钉住）。
- 带年份的那一项用**数字格式 `2026-10-08`**：书面日期里年份放哪儿各语言不统一，
  数字形式没有歧义。
- **月用阿拉伯数字**。宿主给的是月**名**，而有些语言的名字本身就是「数字 + 单位」拼的
  （十月 / 10月 / 10월），直接用它就会出现 `十月8日` 这种中文数字和阿拉伯数字混排。
  单位是从 12 个月名里**求公共后缀**得到的：中文十二个月都以 月 结尾 → 单位是 月 →
  写成 `10月8日`；英文的 January / February / March 没有公共后缀 → 说明这个语言是给月份
  起名字的，于是继续用名字（`8 October`），因为那里写 `10` 根本不像月份。
  公共后缀如果是字母或数字组成的，判定为拼写巧合而不是单位，也退回用名字。
- 24 小时制直接用宿主的 `strings.time()`；**12 小时制得自己写**，因为 SDK 的本地化里
  没有 AM/PM 文案，所以这一处按语言给词（中文 上午/下午、日文 午前/午後、韩文 오전/오후、
  其余 AM/PM），并且 `0 → 12 AM`、`12 → 12 PM` 这两个边界有专门测试。

### 控制中心：全部走宿主 provider，不 shell out

面板里的每一项都接在 Denial **自己的** provider 上，所以它和系统别处永远一致
（硬件音量键改了音量、设置里换了主题、托盘菜单关了 Wi-Fi，面板下一帧就是对的）：

| 控件 | provider |
|---|---|
| 音量、静音 | `neoVolumeProvider`（本插件）包着 `audioServiceProvider` |
| 亮度 | `displayBrightnessProvider`（按显示器，面板控制**自己那块屏**） |
| Wi-Fi | `networkConnectivityProvider` |
| 蓝牙 | `bluetoothProvider` |
| 免打扰 | `desktopNotificationsProvider` |
| 深浅模式 | `shellSettingsProvider` |
| 锁屏 / 睡眠 / 休眠 / 注销 / 重启 / 关机 | `sessionPowerProvider` |

**一条都不 spawn 进程、不读配置文件、不直连 D-Bus。** SDK 明确写了音频这条路「The embedded Dart runtime must never spawn a CLI for this path」，而且
`wpctl` / `brightnessctl` / `nmcli` 那种做法会绕开宿主的权限与状态管理。

几个具体决定：

- **电量的样子可以选。** 胶囊上的电量读数默认直接写 `85%`；把设置里「电量」那一行**下面**
  的 **用图标代替百分比** 打开，就改成画电量图标。图标跟着电量走：充电优先，然后
  ≥90% / ≥60% / ≥30% / 有电 / 空，映射到 `battery_charging_full`、`battery_full`、
  `battery_5_bar`、`battery_3_bar`、`battery_1_bar`、`battery_alert`。**分级是纯函数**
  `neoBatteryGlyphStep`（有单测），图标本身留在 widget 层——这样阈值不靠眼睛验。
  这个开关只在「电量」读数开着的时候出现：读数都关了，问它长什么样没有意义。

- **静音 = 把音量设成 0。** 音频桥只暴露「设置百分比」一个写接口，没有 mute 调用，
  所以取消静音必须自己记住之前的音量（`neoVolumeAfterMuteToggle`，纯函数 + 单测）。
- **滑条拖动时不信回声。** 每次 `apply` 都带一个 request serial，宿主会把结果以
  `AudioLevelState` 回送；拖动期间如果照单全收，回声会把旋钮从手底下拽回去。
  所以拖动时本地值赢，松手后再接受回声（`neoVolumeEchoWindow` 之外的旧 serial 直接作废，
  这样硬件音量键的改动不会被自己的过期请求覆盖）。
- **深浅模式按钮必须写对那个「管用的」设置。** 这里有**两个**设置能决定顶栏颜色，
  谁生效取决于透明度模式：`denial_shell.dart` 里

  ```dart
  final light = appearance.transparencyMode == ShellTransparencyMode.glass
      ? appearance.glass.appearance == ShellGlassAppearance.light
      : appearance.colorSchemePreference.effectiveBrightness == Brightness.light;
  ```

  也就是说**玻璃模式下顶栏读的是 `glass.appearance`，`colorSchemePreference` 被完全忽略**。
  我前两版只写了后者，于是那个按钮改的是一个屏幕上没人读的设置——**这就是"按了没效果"的真正原因**
  （之前猜的"第三态没变化"是错的，虽然那条也确实存在）。
  规则现在抽成 `neoThemeToggle()`（纯函数 + 2 条单测）：玻璃模式下必须写 `glass.appearance`；
  两种模式**都**写 `colorSchemePreference`，因为**应用**跟随的是它，
  只改顶栏不改应用等于半个开关。
- **两态而不是三态**：Denial 存三态没错，但这个 SDK 版本里第三态
  `noPreference` 的 `effectiveBrightness` 是写死的 `denialDefaultBrightness`（深色），
  循环到它就是一次没有视觉变化的点击。
- **每个图标还能右键**：音量=静音/取消静音、网络=开关无线、蓝牙=开关适配器、电量不绑定。
  用的是和系统托盘一样的次键词汇。实现上每个图标是独立的 `Listener`（原始指针事件，
  不进手势竞技场），所以胶囊本身的左键点击照旧打开面板；胶囊的 `_isOverPill`
  让顶栏的「右键开设置面板」在这块区域不触发，不会打架。
- **有线网络单独一个图标。** 这里要绕一下：Denial 的网络快照**只描述 Wi-Fi 设备**
  （NM 后端按 `DeviceType == 2` 过滤，连通性也由那个设备的状态推出），
  所以「插着网线、无线关着」的机器在快照里是 `disconnected`，插件看不出有线。
  于是这一项直接读内核：`/sys/class/net` 的 `operstate` + 有无 `wireless` 目录 +
  有无 `device` 符号链接（后者排除 bridge/veth/bond/tunnel），再配合 `dart:io`
  的地址列表确认有可路由地址。**不 spawn 进程、不需要权限**，判定规则
  （`neoWiredLinkUp`）是纯函数、有单测。判定有线时网络那一格显示网线图标。
- **点音量/亮度的图标**展开更细的层：音量下面是输出设备（当前设备优先）和
  每个应用各自的音量滑条；亮度下面是**每块显示器**各一条滑条。
  设备与应用列表只在展开时向宿主索取（一次 D-Bus 往返），并且都按名字排序、
  有条数上限——应用列表每帧顺序都可能变，不排序的话正在拖的那一条会跑掉。
- **电源行只放四个动作**（锁屏 / 注销 / 重启 / 关机），最左边是**自定义（铅笔）**。
  睡眠和休眠实现仍在（枚举 + 确认规则都有单测），只是不上桌：六个按钮会把每个都挤到不好点，
  而且这两个动作在一个总是插电的桌面上几乎用不到。铅笔现在打开的是**组件设置**
  （先关掉面板再打开，避免两张卡片叠在一起），也就是以后给控制中心加自定义槽位的落点。
- **确认框由 provider 持有。** 注销 / 重启 / 关机需要确认这件事是
  `SessionPowerAction.requiresConfirmation` 定的，面板只调 `request()`，
  确认条读 `confirmationAction`——所以别处发起的动作在面板里也看得见、也能确认。
  锁屏和睡眠不需要确认（它们立刻可逆）。
- **开关和展开是两个热区。** 磁贴主体是「开/关这个子系统」，右上角的箭头才是
  「展开列表」。一个热区既开又展，用户永远猜不到这一下会发生什么。
- **Wi-Fi 列表按 SSID 合并。** 宿主是按 BSSID 给的，一个双频路由器会来两条；
  合并时保留已连接的那条、否则保留信号强的（`neoWifiPanelEntries`，纯函数 + 单测）。
  已保存的网络直接连，不再问密码。
- **文本输入能用**：弹出层走 `shellPopupControllerProvider`，它的默认
  `keyboardPolicy` 就是 `capture`，所以 Wi-Fi 密码框可以直接打字（用 `EditableText`，
  因为这里没有 `Material` 祖先）。

面板高度上限 620、宽 380，内容可滚动；所有列表都有条数上限，扫描结果不会把面板撑爆。

### 加一个新模块（这是标准做法）

按顺序做，缺一步都会在别处露馅：

**1. 描述符**（`module_defaults.dart`）
`NeoModuleIds` 加一个常量 + 一个 `const NeoModuleDescriptor`（label / description /
zone / priority / defaultEnabled），并把它加进 `neoTopBarDefaultModules`。
这一个文件是 id、区、优先级的**唯一**书写处，注册表、看板和测试都读它。

**2. 实现**（`src/modules/your_module.dart`）
```dart
class YourModule implements NeoModule {
  const YourModule();

  @override
  NeoModuleDescriptor get descriptor => yourModule;   // ← 必须返回你自己的那个常量
  @override
  bool isAvailable(NeoModuleContext context) => true;
  @override
  Widget build(BuildContext context, NeoModuleContext module) => ...;
}
```
- 外观一律走 `NeoCard` / `NeoCardButton`，不要自己写玻璃和圆角。
- **图标大小用 `module.glyphSize(fraction)`**，它按系统栏厚度算；
  间距、内边距才可以用 `module.density`。**永远不要用 density 缩放图标。**
- 没有数据可显示时返回 `SizedBox.shrink()`：布局会把「零宽」当成「不占位置也不占间隙」。
- 面板走 `shellPopupControllerProvider.show(...)` + `NeoPopupSurface(... anchor: neoAnchorRectOf(context))`，
  `barrierColor: Colors.transparent`；键盘默认可用，弹窗里可以直接放输入框。

**3. 注册**（`module_registry.dart`）
在 `_factories` 里加一行 `NeoModuleIds.yourModule: YourModule()`。
`_resolve` 会检查「有没有实现」和「返回的描述符是不是自己那个」——抄改文件忘记换描述符，
在这里会**直接抛错**，不会变成栏上两颗胶囊抢一个 id。

**4. 自己的设置**（可选，但请照这个模板）
```dart
class YourModule implements NeoModule, NeoModuleSettings {
  @override
  Widget buildSettings(BuildContext context, NeoModuleSettingsScope scope) => ...;
}
```
- 用 `NeoSettingRow` / `NeoSettingToggle`（`widgets/neo_setting_controls.dart`），
  这样和面板里其它行的样式完全一致。
- 选项从 `module.options` 读、从 `scope.setOption(key, value)` 写；**写 null 表示回到默认值**。
- 选项的**解析必须是纯函数**（放进 `core/`，从 `neo_top_bar_logic.dart` 导出）：
  文件是可以手改的，所以每个值都要有类型回退，未知/坏值整条丢掉而不是修一半。
- 每个选项键都写成常量，别在两边各写一遍字符串。

**5. 测试**
- 默认布局断言（`test/config_test.dart`）：新模块的 id 要在 `NeoModuleIds` 清单里，
  并决定它排在哪一区。
- 你的纯逻辑：新建 `test/your_module_test.dart`，用
  `"$DENIAL_PLUGIN_DART" --packages=.dart_tool/package_config.json test/...` 跑
  （**不能用 `dart test`**，见上文）。
- widget 层没有测试环境（没有 `flutter_tester`），所以**能抽成纯函数的规则一定要抽出来测**。

**你不用做的**：多份实例、编号、增删、跨区移动、拖动排序、选项存储、
面板里的卡片和展开区——这些都由实例模型和看板统一处理，模块只管「怎么画」和「有什么选项」。

几条硬性约束，和上面并列：

- `id` 会被写进用户配置，**改名等于丢掉用户对这个模块的选择**。
- 动画遵守 Denial 的红线：不要在 `Opacity` / `FadeTransition` 上叠 `Transform.scale`
  （要同时淡入+缩放用 `ShellFadeScale`），玻璃不要放进 fade 层，尺寸变化时改成乘 alpha。
- 卡片会被拉伸到栏的整个厚度，所以模块内容要能接受"比自己需要更高"的绘制区
  （比如固定尺寸的小图标，外面套一层 `Center`）。
- **不 spawn 进程、不读配置文件、不直连 D-Bus**：数据一律走宿主 provider 或 `services.*`
  （SDK 在音频那条路径上明确写了 must never spawn a CLI）。
- **宿主给的顺序不能直接画**：它是 z-order 之类的实时顺序，每帧都可能变。
  要显示成列表就先按稳定键排序（见启动器窗口图标、各应用音量两处）。

## 已知限制

1. ~~**工作区胶囊做不到"每个工作区各自显示图标"**~~ —— **这条已经解决了**（见上文
   「工作区胶囊：可选显示每个工作区的窗口图标」）。过程值得留个记录，因为中间有**两次**判断
   都是错的：

   - 第一次断言"`ApplicationWindow` 没有 workspace 字段，所以插件判断不了窗口属于哪个工作区，
     必须等上游加字段"。**错**：`services.windows(monitorId)` 返回的本来就是"这块屏当前工作区的
     窗口"（外加最小化和固定显示的），根本不需要那个字段：

     ```dart
     // denial_desktop/lib/src/core/shell_plugin_services.dart 的 _windows
     if (window.monitorId == monitorId &&
         (window.minimized || window.pinned ||
          window.workspaceId == desktop.activeWorkspaceFor(monitorId)))
     ```

   - 第二次断言"其它工作区的窗口拿不到，所以工作区胶囊里每个工作区各自列应用还是得等上游"。
     **也错**：完整快照一直公开着，只是不在 `services.windows()` 那条路上——

     ```dart
     ref.watch(shellControllerProvider.select((s) => s.openAppWindows));  // 所有用户窗口
     // 每个 DenialWindow 带 workspaceId / monitorId / minimized / pinned / objectId
     // state.dart 导出 shellControllerProvider，models.dart 导出 DenialWindow
     ```

     于是最终是**纯插件**实现的，没碰上游。

2. **无法添加内存 / 网络 / 磁盘模块**。`ShellTelemetryServices` 只提供
   `battery` / `cpu` / `gpus` / `clock` / `media`，插件拿不到这些数据源。
3. **排序有两种方式**：在顶栏上**长按拖动胶囊**（推荐，可以跨区），或在设置面板里
   用每行的 **↑ ↓**（一次一格，只在区内移动，到边界按钮变灰）。
   设置面板里**没有**做拖拽：它位于弹窗宿主的"点外部关闭"遮罩之下，
   拖拽手势会和遮罩抢，风险高；顶栏是普通表面，没有这个问题。
   托盘胶囊里的图标由宿主渲染、自带手势，**可能**抢走长按，那种情况下用面板里的 ↑ ↓。
4. 面板内一次最多渲染 50 条通知（避免无上限增长）。

## 动效

用 Denial 自己的动效工具，不自己写曲线：

| 场景 | 做法 | 为什么 |
|---|---|---|
| 按下任一胶囊 | 立刻 `springTo(_scale, 1.03, spring: Motion.snappy)`，抬起 `springTo(_scale, 1.0, spring: Motion.bouncy)` 回弹 | 反馈属于**胶囊**而不是里面的控件，所以点胶囊里任何一个控件都是整颗胶囊反应 |
| 长按（准备拖动） | 继续长到 `1.08`，用 `Motion.gentle`，**并保持在整个拖动过程中** | 和按下同一条"变大"语言，只是幅度更大、更缓，读起来就是"被拿起来了" |
| 悬停/聚焦高亮 | `AnimatedContainer(duration: Motion.cardSettle, curve: Motion.standard)` | 原来是一帧内直接换色，所以显得"跳"。只动 `BoxDecoration`，不产生图层 |
| 拖动时被拿起的胶囊 | `Visibility(maintainSize: true)` —— **不画**，而不是半透明 | 见下 |

### 按下反馈必须用 `Listener`，不能用 `onTapDown`

这是"看不到动画"的真正原因，浪费了一轮排查，值得写下来：

`GestureDetector.onTapDown` **不是**在指针按下时触发的，它要等 tap 识别器
**赢下手势竞技场**（或自身 100ms 超时）。而每个胶囊外面套着 `_DraggablePill` 的
长按识别器（拖拽用），竞技场不会在按下那一刻结算。于是：

```
快速点击（<100ms）：按下和抬起落在同一帧
  → onTapDown 与 onTapUp 同帧触发
  → 放大弹簧刚起步就被回弹弹簧取消
  → 净效果 = 0 动画
```

改用裸 `Listener`（`onPointerDown` / `onPointerUp` / `onPointerCancel`）：它**不参与
竞技场**，在按下事件的当帧就回调；同时它也不消费事件，所以点击照常传给胶囊。
`PointerUpEvent.buttons` 恒为 0（按键已释放），所以要用一个 `_pressed` 标志来配对。

### 放大必须挂在胶囊层，不能挂在卡片里

最初我把放大写在 `NeoCardButton` 里。问题：那只是个**可交互卡片**的实现，只有用它构建的
胶囊（启动器、时钟、电池、通知）会放大；用 `NeoCard` 的那些（媒体、工作区、托盘、
CPU/GPU）**完全没有反馈**。

正确位置是 `_DraggablePill`——它包裹**每一个**胶囊。放在这一层还顺带解决了三件事：

1. 点胶囊里**任何**控件（媒体按钮、窗口图标、工作区圆点）都是整颗胶囊反馈，
   而不是只有那个控件
2. 长按可以用同一条语言继续长到"拿起"的幅度
3. `_DraggablePill` 的 GlobalKey 让缩放状态**跟着 element 一起搬迁**到拖动反馈上，
   所以拖起来时胶囊本来就是"拿起"的尺寸（见上一节）

### 缩放绝不能包 `Opacity` 或 `ShellFadeScale`

Denial 的 `ShellFadeScale` 文档写得很明确：**内部会采样场景的内容
（`ShellBackdropBlur`、玻璃、窗口表面）不能被它包住**，否则采样到的是那个图层而不是壁纸。
每个胶囊里都有 `ShellBackdropBlur`，所以：

- 点击的放大用**纯 `Transform.scale`**——变换本身不建图层，玻璃照常采样真实背景。
- 拖动时"被拿起的胶囊"原来用的是 `Opacity(opacity: 0.35)`，**这正好违反了上面那条**
  （拖动时它的玻璃背景是坏的）。现在改成 `Visibility(maintainSize: true)`：
  槽位尺寸不变（栏不会在指针下重排、落点计算稳定），但整个子树**不绘制**——
  `Opacity` 在 0 时不建图层、直接跳过绘制，所以也没有采样问题。

### 弹出面板的出现动画：宿主的 `FadeTransition` 会把玻璃弄丢

宿主的 `ShellPopupHost` 给**每个** popup 套一层
`FadeTransition(opacity: 0→1) + ScaleTransition(0.96→1)`。而 `BackdropFilter`
在 `Opacity` 图层**里面**时，采样到的是那个（还是空的）图层，不是它后面的场景。于是：

| 时刻 | 现象 |
|---|---|
| 出现动画进行中（opacity < 1） | 没有磨砂，卡片只是一块半透明底色 |
| 动画结束（opacity == 1） | `RenderAnimatedOpacity` 到 255 时**丢掉图层** → 磨砂"啪"地一下出现 |

修法是**不要宿主那层动画**，自己做：

- **每个** `show()` 都要传 `transitionDuration: neoPopupHostTransition`（= `Duration.zero`）。
  宿主那条路径本来就被它自己的"减少动画"用过，零时长是它支持的。
  这条不写就会漏：日历先中过一次，托盘展开面板是第二例（它是直接 `show` 的，没走
  `*_panel.dart` helper）。所以现在有一条**源码级单测**（`test/popup_geometry_test.dart`）
  扫 `lib/src` 里所有同时出现 `shellPopupControllerProvider` 和 `.show(` 的文件，
  要求它同时出现 `transitionDuration: neoPopupHostTransition`——忘了就红。
- `NeoPopupSurface` 自己放一个 `_NeoPopupAppearance`，**把动画拆成两半**：
  - **缩放**放外层 `ScaleTransition`。变换对 `BackdropFilter` 无害——滤镜在变换后的
    坐标系里采样，玻璃跟着卡片一起缩放。
  - **淡入**通过 `_NeoPopupAppearanceScope` 传进卡片，只加在**盘面**上
    （`ShellBackdropBlur(separateChild: true)` 里那个 `child`）。模糊是它的**兄弟**
    （`Positioned.fill(backdrop)` 先画），所以模糊从不进 `Opacity` 图层，
    **第一帧就是满强度**，盘面再淡进来。
- 代价：**关闭是瞬时的**（宿主用的是同一个时长，没法只关掉"出现"那一半）。
  如果之后想要淡出，得让宿主支持分别指定出现/关闭时长。

### 尊重"减少动画"

`_press` / `_release` 会先查 `MediaQuery.disableAnimationsOf(context)`，
用户在 Denial 里关掉动画时直接落到目标值，不做弹簧。

## 弹出面板的写法（踩过的坑）

日历、通知、组件设置三个面板都走 `NeoPopupSurface`，它有两种模式：

```
锚定：Positioned(left/top|bottom, width) → ConstrainedBox(maxHeight)
回落：Padding(收窄到所属输出) → SafeArea → Center → ConstrainedBox
```

### 右键为什么只在空白处生效

顶栏用 `Listener` 监听指针，而 `Listener` 是**原始指针监听、不参与手势竞争**，
所以它不会拦住胶囊内部的手势——这既是好事（不影响胶囊点击），
也意味着右键托盘图标时宿主的菜单和我的面板会**同时**触发。

修法是反过来操作：`Listener` 里先做一次命中测试，**落在任何胶囊内就什么都不做**。
命中测试复用拖拽已经在测量的那批矩形（`_slots`），不引入第二份"胶囊在哪里"的真相。

**还有一个必须一起改的坑**：`Listener` 的 `behavior` 默认是 `deferToChild`——
**只有子控件被命中时它自己才算被命中**。于是"跳过胶囊"和"空白处收不到事件"叠加起来，
结果就是**哪里都打不开设置面板**（这个 bug 真发生过）。所以这个 `Listener` 显式设了
`HitTestBehavior.opaque`：让整条栏自己成为命中目标，同时事件照常传给子控件
（托盘的右键菜单不受影响）。

副作用是空白栏面不再把点击"穿透"给下层。这里没有影响：顶栏通过 `ShellWorkArea`
预留了这条区域，普通窗口本来就在它下面；全屏时顶栏会 `visible: false`，
SDK 会立即抑制它的输入，所以它连被命中都不会。

### 两种模式按用途选

**通知 / 日历用锚定模式**（贴着图标弹）：点铃铛/时钟时，`neoAnchorRectOf(context)`
取该胶囊在场景里的矩形，
卡片挂在它正下方 8px，**水平中轴对齐胶囊中轴**，只在会超出输出边缘时才整体平移
（先左后右地钳进输出）——所以最右边的时钟胶囊会往左让位，中间的铃铛就是正下方。
垂直方向自动判断（控件在输出下半屏就向上弹），底栏因此同样适用。

**组件设置用居中模式**（不传锚点）：它是配置界面，行数多、说明文字需要横向空间，
居中偏大的卡片才有地方铺开；锚定在鼠标旁边会挤成一列。传 `anchor: null` 即走回落路径。

锚定模式下若拿不到锚点，或控件旁剩余空间不足 `minimumHeight`，同样回落到居中卡片。

> 插件**无法自己开独立原生窗口**：SDK 没有这个 API（`launchApplication` 是启动外部应用，
> 不是插件自己的 UI）。要做到真正的独立窗口，只能走"额外贡献一个 `ShellSurface`
> 常驻挂载 + 用 `place()` 控制显隐"，那是另一套机制。

### 不压暗桌面

宿主的默认遮罩是 Denial 的全屏 `overviewScrim`，那是给居中的大面板用的。
贴在图标旁的小卡片观感上更接近右键菜单，为它压暗整个桌面太重，所以三个面板都传
`barrierColor: Colors.transparent`。注意是**透明而不是取消**遮罩：点外部和 Esc 仍能关闭。

### 坑 1：`Center` 不能省（居中回落模式下）

弹窗宿主把每个 popup 放在 `Stack(fit: StackFit.expand)` 里，也就是给**全屏紧约束**；
单独一个 `ConstrainedBox` 无法把紧约束放松，卡片会被拉伸成整屏大小。后果不止是难看：
被撑满的卡片会盖住宿主的"点击外部关闭"遮罩层，于是**面板点不掉**
（这就是曾经那个"全屏通知窗口、有时关不掉"的 bug）。

`SafeArea → Center → ConstrainedBox` 也正是 Denial 自己给 Wi-Fi / 蓝牙详情弹窗用的形状
（`wifi_detail_surface.dart`），所以照抄它既能修 bug，也和系统其余面板观感一致。

### 坑 2：必须在**所属输出**内居中，不能在整个场景里居中

外壳的 Flutter 场景是**所有显示器拼起来的**。`Center` 在场景里居中，双屏时卡片就会落到
两块屏中间（DP-2 + 竖着的 eDP-1 时尤其明显）。

SDK 的 `monitorBounds(monitorId)` 就是为这件事存在的——它的注释写着
"constrain overlays to their output rather than the whole multi-monitor scene"。
所以 `NeoPopupSurface` 会 `ref.watch(services.monitorBounds(monitorId))`，把居中范围
先用 `Padding` 收窄到那块输出。

### 坑 3：锚点必须在**打开面板之前**用栏自己的 context 取

`neoAnchorRectOf(context)` 量的是"调用它的那个 context"的盒子。弹窗的 `builder` 里那个
`context` **不是**栏的 context，而是弹窗宿主给的——它的盒子是整个场景（所有输出），
`neoAnchoredPopupPlacement` 在这个"锚点"旁边找不到任何可用空间（`available` 是负数），
于是返回 null，卡片回落到居中：**面板就从屏幕正中间弹出来了**。这个 bug 真发生过，就在托盘
的展开面板上（其它三个面板都是在打开之前取好锚点、再传进去的，所以只有它中招）。

规矩：`anchor: neoAnchorRectOf(context)` 写在 `show(...)` **之前**，builder 里只传变量。

### 坑 4：纯逻辑层不能碰 `dart:ui`

上面的几何计算在 `src/core/popup_geometry.dart`，它**故意不 import `dart:ui`**，
用的是自己的 `NeoSceneRect` / `NeoPopupInsets`。原因：`dart:ui` 只存在于 Flutter 引擎里，
一旦被纯逻辑层的桶文件（`neo_top_bar_logic.dart`）间接引出，**整个单测套件在 Dart VM 上
直接编译失败**（我确实这么踩了一次：三个测试文件全部无输出、退出码 1）。
`Rect` ↔ `NeoSceneRect` 的转换放在 widget 层。

### 其他

`ShellBackdropBlur` 用了 `separateChild: true`，此时**不能**覆盖 `blendMode`
（组件里有 assert 要求保持默认的 `BlendMode.src`）。

## 资源（图标）

启动器胶囊里的图标是本插件自带的资源：`assets/archlinux-logo.svg`。

- **来源**：官方 Arch Linux logo，取自系统安装的 `archlinux-logo` 包
  （`/usr/share/pixmaps/archlinux-logo.svg`），**文件逐字节原样复制、磁盘上从未改动**
  （sha256 `3ffe8ea4e98db43a3ec4dcca55fd4009cd8b8d220f0996aef7a5b427fdf65234`）。
- **显示为白色**，但不是改文件，而是绘制时套了一层
  `colorFilter: ColorFilter.mode(theme.colors.textPrimary, BlendMode.srcIn)`。
  `srcIn` 保留字形的 alpha，所以官方 SVG 里那个 **™ 标记仍然被绘制**（它在
  `archlinux-logo.svg` 里是两条独立路径）。
- **颜色用的是 `theme.colors.textPrimary`**，也就是顶栏其他图标（铃铛等）同一个前景色——
  你的深色主题下就是白色。想强制纯白把那个颜色换成 `Color(0xFFFFFFFF)` 即可；
  用主题色是为了将来换浅色主题时不会白到看不见。

### 关于 Arch 商标政策（第 4 节，2021-04-18 版）

政策原文的三条相关要求，以及本插件的对应做法：

| 政策要求 | 本插件的做法 |
|---|---|
| the Trademark declaration ( ™ ) must remain intact | 未删除任何路径，™ 随图标一起绘制 |
| scaling should retain the original proportions | `BoxFit.contain`，等比缩放 |
| 标准形态优先，但**彩色/杂乱背景上应当使用单色版**（white、black 等） | 顶栏正贴在壁纸上，属于政策点名场景，故用单色 |

也就是说：**染白是政策明确建议的用法**，前提是 ™ 不丢、比例不变。
如果你想换回官方蓝色，把 `colorFilter` 那一行删掉即可（文件本来就是蓝的）。

**商标归 Arch Linux 项目所有**，使用需遵守
[Arch 商标政策](https://terms.archlinux.org/docs/trademark-policy/)。换发行版时应换成
该发行版自己的官方标识。

### 插件自带资源的两个坑

1. **pubspec 里要声明**：`flutter: assets:` 段必须列出该文件，否则不会被打包。
2. **加载时必须带包名前缀**。插件是生成的外壳应用的**依赖包**，Flutter 会把它声明的资源
   注册成 `packages/neo_top_bar/assets/archlinux-logo.svg`。所以
   `SvgPicture.asset('assets/archlinux-logo.svg')` 会在运行时**加载失败**。两种等价写法：

   ```dart
   // 文档推荐的写法（本插件用的这个）
   SvgPicture.asset('assets/archlinux-logo.svg', package: 'neo_top_bar');

   // 或者直接把带前缀的完整键写成字面量（Denial 自己的代码用这种，
   // 例如 'packages/denial_flutter_sdk/assets/branding/denial-dark.svg'）
   SvgPicture.asset('packages/neo_top_bar/assets/archlinux-logo.svg');
   ```

   这一点已对照构建产物里的 `AssetManifest.bin` 核实（里面只有带前缀的那个键）。
   用 `Image.asset` 时同理，要走 `package:` 参数。

## 许可

本插件为独立实现，仅使用 Denial 的公开 SDK（`denial_sdk` / `denial_flutter_sdk`）。
没有复制 `denial_top_bar` 的源码。自带图标 `assets/archlinux-logo.svg` 的版权与商标
归 Arch Linux 项目所有（见上）。
