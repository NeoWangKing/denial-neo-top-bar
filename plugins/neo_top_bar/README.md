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
| 工作区胶囊 | `workspaces` | 左 | 开 | 每个工作区一个圆点，当前工作区高亮，占用状态变实心；点击切换 |
| 应用启动器 | `launcher` | 中 | 开 | Arch Linux 图标，点击调 `services.toggleLauncher()`；启动器界面由 Denial 自己提供 |
| 系统托盘 | `tray` | 右 | 开 | StatusNotifier 图标；托盘隐藏或为空时整块自动消失 |
| 通知 | `notifications` | 右 | 开 | 未读徽章 + 历史面板（逐条忽略 / 全部清除 / 免打扰） |
| 媒体播放 | `media` | 右 | **关** | 曲目 + 上一首 / 播放暂停 / 下一首；无播放时自动消失 |
| 电池与电源 | `battery` | 右 | 开 | 电量与充电状态，点击打开电源设置；无电池的机器自动消失 |
| CPU 负载 | `cpu` | 右 | **关** | 折线 + 百分比 + 温度 |
| GPU 负载 | `gpu` | 右 | **关** | 每块显卡一条，含温度 |
| 时钟与日期 | `clock` | 右 | 开 | 点击打开日历面板（上/下月、回到今天） |

可选模块默认关闭，所以第一眼接近系统原来的样子。想开就在下面说的设置面板里打开。

## 交互

- **左键**：模块各自的行为（切工作区、开启动器、开电源页、开日历、开通知面板、媒体控制）。
- **长按胶囊拖动**：直接在顶栏上拖拽排序。拖动时有三重反馈，所以落点不用猜：
  1. 跟随指针的提示胶囊写着 **「模块名 → 目标区」**，直接告诉你它会归到哪一段
  2. 目标位置的**插入竖线**（主题强调色）标出它会在哪两个胶囊之间
  3. 将要被插队的那个胶囊**高亮一圈**
  松手即写入配置。**拖到别的区就会改区**——落点所在的区决定它归哪一段。
  长按（不是立即拖动）是为了不抢走每个胶囊原本的点击行为。
- **右键顶栏的空白处**：打开**组件设置面板**。里面可以逐个开关模块、选择它停在左/中/右、
  用每行的 **↑ ↓ 调整同一区内的先后顺序**，以及调整整条栏的间距（紧凑 / 标准 / 宽松）。
  改动立即生效并立刻写入配置。

  ⚠️ **右键点在胶囊上不会打开设置面板**，这是故意的：系统托盘的图标由宿主渲染，
  右键是它们的**上下文菜单**，设置面板一起弹出来会和它们抢。
  空白栏面才是设置面板的地盘。
- **快捷键**：插件额外提供一个动作 `neo_top_bar.openSettings`（顶栏组件设置）。
  在 **设置 → 快捷键 → Denial 动作** 里绑一个键（比如 `Super+Shift+T`），
  这是打开设置面板最可靠的方式——不用去找空白处，也不会碰到托盘。

  这个面板是**屏幕正中偏大的居中卡片**（760×720），不是贴着鼠标的小菜单：它是配置界面，
  行数多、需要横向空间放说明文字，居中才有地方铺开。日历和通知两个才是贴着图标弹的。

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
"$DENIAL_PLUGIN_DART" --packages=.dart_tool/package_config.json test/popup_geometry_test.dart
"$DENIAL_PLUGIN_DART" --packages=.dart_tool/package_config.json test/preferences_test.dart
```

## 代码结构

```
lib/
  neo_top_bar.dart          @Plugin() 入口：ShellSurface + ShellWorkArea 两个贡献
  neo_top_bar_logic.dart    纯 Dart 导出，供测试使用（不引 Flutter widget）
  src/core/
    module_descriptor.dart  模块身份类型（id / 标签 / 区 / 优先级 / 默认开关）
    module_defaults.dart    ★ 默认布局的唯一来源：id 字符串 + 9 个描述符常量
    module.dart             模块契约 + NeoModuleContext
    module_registry.dart    注册表：描述符 id → 实现，`all` 由默认常量派生
    config.dart             配置模型、JSON 解析、区/排序解析（NeoDensity）
    config_state.dart       运行时配置状态（内存生效 + 后台持久化）
    preferences.dart        配置文件读写（原子写、保留未知键、写合并）
    calendar_data.dart      日历的纯日期逻辑
  src/modules/              每个模块一个文件
  src/widgets/
    neo_bar.dart            三个区的布局、右键菜单接线
    neo_card.dart           药丸卡片外观（玻璃 / 渐变 / hover / 聚焦）
    neo_popup_surface.dart  弹出面板外观
    module_settings_panel.dart  组件设置面板
```

### 默认布局只有一个来源

`module_defaults.dart` 是 id、区、优先级的**唯一**书写处：9 个模块实现、
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

### 加一个新模块

1. 在 `module_defaults.dart`：`NeoModuleIds` 加 id 常量，并写一个
   `const NeoModuleDescriptor`（标签、说明、区、优先级、默认开关）。
2. 在 `src/modules/` 新建文件实现 `NeoModule`：`descriptor` 直接返回那个常量，
   再实现 `isAvailable` 和 `build`。
3. 在 `module_registry.dart` 的 `_factories` 里加一行 `id: YourModule()`。
4. 在 `test/config_test.dart` 的默认布局断言里决定它排在哪。

`id` 会被写进用户配置，**改名等于丢掉用户对这个模块的选择**。

外观一律走 `NeoCard` / `NeoCardButton`，不要自己写玻璃和圆角。动画遵守 Denial 的红线：
不要在 `Opacity` / `FadeTransition` 上叠 `Transform.scale`（要同时淡入+缩放用
`ShellFadeScale`），玻璃不要放进 fade 层，尺寸变化时改成乘 alpha。
卡片会被拉伸到栏的整个厚度，所以模块内容要能接受"比自己需要更高"的绘制区
（比如固定尺寸的小图标，外面套一层 `Center`）。

## 已知限制

1. **工作区胶囊暂不显示应用图标**。SDK 暴露了 `services.windows(monitorId)` 和
   `buildApplicationIcon`，但 `ApplicationWindow` **没有 workspace 字段**，无法判断某个窗口
   属于哪个工作区，所以"每个工作区里显示该区应用图标、点击聚焦"这件事需要上游补一个
   工作区字段或新的 `@ExtensionPoint`。当前工作区胶囊只做数量/当前/占用/切换。
2. **无法添加内存 / 网络 / 磁盘模块**。`ShellTelemetryServices` 只提供
   `battery` / `cpu` / `gpus` / `clock` / `media`，插件拿不到这些数据源。
3. **排序有两种方式**：在顶栏上**长按拖动胶囊**（推荐，可以跨区），或在设置面板里
   用每行的 **↑ ↓**（一次一格，只在区内移动，到边界按钮变灰）。
   设置面板里**没有**做拖拽：它位于弹窗宿主的"点外部关闭"遮罩之下，
   拖拽手势会和遮罩抢，风险高；顶栏是普通表面，没有这个问题。
   托盘胶囊里的图标由宿主渲染、自带手势，**可能**抢走长按，那种情况下用面板里的 ↑ ↓。
4. 面板内一次最多渲染 50 条通知（避免无上限增长）。

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

### 坑 3：纯逻辑层不能碰 `dart:ui`

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
