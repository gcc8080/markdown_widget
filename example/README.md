# example

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Custom Selection Demo

新增页面：`Sample: Custom Selection`，用于对比默认选区与自定义选区模式。

### 验收说明

1. 运行示例：
   ```bash
   flutter run -d chrome
   ```
2. 在左侧菜单进入 `Sample: Custom Selection`。
3. 先看 **默认模式**：分别选择标题、正文、列表、引用、代码块，确认默认选区正常。
4. 切换到 **自定义模式**：
   - 保留系统选择菜单项（如复制/全选）。
   - 额外新增菜单项 **“统计字数”**。
   - 点击后弹出自定义渐变样式浮窗，展示当前选中文字字符数与预览。

> 说明：当前仓库未配置自动截图产物管线，请在验收时按以上步骤手动截图。
