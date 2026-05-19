# PromptMeter

[English](README.md) · [한국어](README.ko.md) · [日本語](README.ja.md) · **中文**

PromptMeter 是一款面向每天使用 AI 编码助手的开发者的 macOS 菜单栏应用。无需打开多个仪表盘或翻找 CLI 输出，就能时刻看到当前可用配额、重置时间和本地 token 用量。

目前支持 Codex、Claude Code 和 Gemini CLI。

## 为什么做这个

AI 编码工具很强大，但其额度很容易失控：

- 当前 Codex 会话还剩多少？
- Claude Code 的窗口什么时候重置？
- Gemini CLI 是否已安装并登录？
- 今天用了多少 token？
- 哪个 provider 最快用完？

PromptMeter 把这些答案放在菜单栏和一个紧凑的弹出窗口里，让你无需切换上下文也能继续工作。

## 功能

- **菜单栏状态**：显示剩余最少的 provider 会话。
- 针对 Codex、Claude Code 和 Gemini CLI 的 **provider 卡片**。
- 从本地 Codex 与 Claude Code JSONL 日志统计的 **今日用量**。
- 基于按模型识别的本地费率估算的 **预计 token 成本**。
- 以时钟或倒计时形式展示的 **配额重置**。
- Provider 窗口接近阈值时的 **低配额通知**。
- 在设置中显示安装/登录命令的 **缺失 CLI 检测**。
- 在 UI 中隐藏账户邮箱的 **隐私开关**。
- 让菜单栏静默常驻的 **开机自启**。
- 仅读取新追加日志的 **增量日志扫描**。

## Provider 支持

| Provider | 状态 | PromptMeter 读取的数据 |
| --- | --- | --- |
| Codex | 已支持 | 本地 CLI / app-server 配额、套餐、账户、会话限制、本地 token 使用日志 |
| Claude Code | 已支持 | OAuth 用量、订阅、重置窗口、本地 token 使用日志 |
| Gemini CLI | 已支持 | 本地 CLI 的 `/stats model` 配额输出 |

PromptMeter 与 OpenAI、Anthropic、Google 没有任何关联。它仅读取本地已安装工具和本地会话日志中可获取的数据。

## 隐私

PromptMeter 以本地优先为设计原则：

- 提示词文本在本地进行 token 估算。
- 本地 token 用量根据你机器上的文件计算。
- 用量扫描缓存只保存聚合计数、文件签名、偏移量和解析器状态。
- 账户邮箱可在设置 UI 中隐藏。

Claude Code 的 OAuth 凭证通过 macOS Keychain 读取，需要刷新 token 时会缓存到 PromptMeter 自己的 Keychain 项中。

## 项目结构

```text
PromptMeter/
  App/        应用入口、应用代理、弹出窗口宿主
  Core/       主应用模型、设置、提示词指标、通知
  Menu/       菜单栏弹出窗口视图与菜单数据模型
  Providers/  Codex、Claude Code、Gemini CLI 客户端与用量映射
  Settings/   设置窗口、标签页、可复用设置组件
  Usage/      本地 token 用量扫描器、价格、文件缓存、快照
```

Xcode 项目采用与文件系统同步的根分组，因此磁盘上的目录结构即源代码布局。

## 构建

要求：

- macOS
- Xcode
- SwiftUI / AppKit 工具链
- 可选的 provider CLI：
  - `codex`
  - `claude`
  - `gemini`

克隆并打开：

```bash
git clone git@github.com:minhee0000/PromptMeter.git
cd PromptMeter
open PromptMeter.xcodeproj
```

然后在 Xcode 中构建并运行 `PromptMeter` scheme。

当前项目配置为 macOS 菜单栏应用（`LSUIElement`），目标平台为仓库中 Xcode 项目所使用的 macOS SDK。

## 使用方式

1. 安装并登录你要使用的 provider CLI。
2. 启动 PromptMeter。
3. 打开菜单栏弹出窗口查看配额、重置窗口和今日用量。
4. 打开"设置"以配置刷新频率、显示模式、隐私和开机自启。

如果某个 CLI 未安装，PromptMeter 仍会在设置中保留对应的 provider 条目，但不会在主弹出窗口中显示其小部件。

## 注意事项

- 用量和成本数值是基于本地日志和按模型识别的费率表得出的估算值。
- Provider 的 API 与 CLI 输出可能发生变化，因此 PromptMeter 对不可用或被限流的响应采取防御性处理。
- 对于 Claude 的 HTTP 429 响应，PromptMeter 会保留上一次成功的快照，并在退避后再次尝试。

## 路线图

- 每周用量总结。
- 可选的每日用量趋势图视图。
- 更多 provider 集成。
- 已签名的发布版本。
- 用于支持的诊断信息导入 / 导出。
