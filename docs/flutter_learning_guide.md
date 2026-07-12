# Flutter 开发学习资料整理

## 一、官方中文文档

### 1. Flutter 官方中文文档
- 网址：https://docs.flutter.cn/
- 说明：Flutter 官方出品的中文文档，由官方和社区共同维护。内容涵盖安装、入门、UI 构建、状态管理、路由导航、测试、发布等。

### 2. Flutter Cookbook（中文）
- 网址：https://docs.flutter.cn/cookbook
- 说明：大量"如何做"的实战示例，适合查阅具体功能实现。

### 3. Dart 官方中文文档
- 网址：https://dart.cn/
- 说明：学习 Dart 语言本身的语法、异步、类、库等。

---

## 二、建议学习路线

### 第 1 步：Dart 语言基础
- 文档：https://dart.cn/guides/language/language-tour
- 重点内容：
  - 变量、函数、类
  - 异步编程：`async` / `await`
  - 集合类型：List、Map、Set

### 第 2 步：Flutter 入门
- 文档：https://docs.flutter.cn/get-started/install
- 重点内容：
  - 安装开发环境
  - 创建第一个 Flutter 应用
  - 理解 Widget 概念

### 第 3 步：Flutter UI 构建
- 文档：https://docs.flutter.cn/ui
- 重点内容：
  - 无状态 Widget：`StatelessWidget`
  - 有状态 Widget：`StatefulWidget`
  - 常用布局：Row、Column、Stack、ListView、GridView
  - 常用组件：Text、Button、Image、TextField、Card、Dialog

### 第 4 步：状态管理
- 进阶内容，建议后面再看
- 常见方案：
  - `setState`
  - `Provider`
  - `BLoC`
  - `Riverpod`

---

## 三、如何读懂本项目的 Flutter 页面代码

### 1. 先看 Widget 树的整体结构
Flutter 页面本质上是一棵嵌套的 Widget 树。看代码时，先找最外层和关键分支：

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(           // 页面骨架：顶部栏、底部栏、浮动按钮
    appBar: AppBar(...),    // 顶部标题栏
    body: Column(           // 垂直排列
      children: [
        SearchBar(...),     // 搜索栏
        Expanded(           // 占据剩余空间
          child: GridView(...), // 网格列表
        ),
      ],
    ),
  );
}
```

- `Scaffold`：整个页面框架
- `AppBar`：顶部标题栏
- `body`：页面主体内容
- `Column` / `Row`：垂直 / 水平排列
- `Expanded`：让子组件占满剩余空间

### 2. 用 VS Code 的 Flutter 工具直观查看
- **Flutter Outline**：在 VS Code 左侧边栏打开，能看到当前文件的 Widget 层级结构。
- **Widget Inspector**：运行应用后打开 DevTools，点击 Inspector，在手机上点哪个 UI 元素，代码里就会高亮对应的 Widget。
- **Flutter DevTools**：可查看页面渲染树、性能、网络请求等。

### 3. 定位某个 UI 元素在代码中的位置
如果你看到界面上某个按钮/文字，但不知道代码在哪：
1. 找到它的文字内容（比如"搜索"）。
2. 用 VS Code 全局搜索 `Ctrl + Shift + F` 搜这个文字。
3. 找到后，向上看几层，就能知道它属于哪个 Widget。

### 4. 常见 Widget 与 UI 元素对照

| 代码里的 Widget | 在页面上是什么 |
|---|---|
| `Text("标题")` | 一段文字 |
| `ElevatedButton(...)` | 凸起按钮 |
| `IconButton(...)` | 图标按钮 |
| `TextField(...)` | 输入框 |
| `ListView(...)` | 可滚动列表 |
| `GridView(...)` | 网格 |
| `Image(...)` / `Image.network(...)` | 图片 |
| `Container(...)` | 带样式（颜色、边距、圆角）的盒子 |
| `Card(...)` | 卡片 |
| `Dialog` / `AlertDialog(...)` | 弹窗 |

### 5. 从具体页面文件入手
本项目 `lib/ui/` 目录下按页面分文件：
- `home_screen.dart`：首页
- `media_screen.dart`：媒体页
- `settings_screen.dart`：设置页
- `album_screen.dart`：相册页
- `tag_screen.dart`：标签页
- `search_screen.dart`：搜索页

想看哪个页面，就打开对应文件，直接找 `build()` 方法。

---

## 四、结合官方文档查 Widget

看到项目代码中不认识的 Widget 时，可以去官方文档搜索：

| Widget | 搜索关键词 |
|---|---|
| `Scaffold` | Flutter Scaffold |
| `AppBar` | Flutter AppBar |
| `ListView` | Flutter ListView |
| `GridView` | Flutter GridView |
| `BlocBuilder` | Flutter BLoC |
| `GoRouter` | Flutter GoRouter |

---

## 五、其他中文社区资源

- Flutter 中文社区：https://flutter-io.cn/
- CSDN、掘金、知乎：有很多 Flutter 中文教程
- B站：有很多 Flutter 中文视频教程

---

## 六、下一步建议

如果想快速理解本项目，建议先选一个最感兴趣的页面，比如：
- 首页 `lib/ui/home/home_screen.dart`
- 媒体页 `lib/ui/media/media_screen.dart`
- 设置页 `lib/ui/settings/settings_screen.dart`

逐层阅读 `build()` 方法，对照模拟器/真机上的界面，把每个 Widget 和屏幕上的区域对应起来。

如有需要，可以指定具体页面，让我帮你逐行解释代码和 UI 的对应关系。
