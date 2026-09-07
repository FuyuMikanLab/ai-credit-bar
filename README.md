<div style="display: flex;">
  <img src="https://github.com/user-attachments/assets/37fec583-9bf1-4714-90fb-e4d346fa5783" alt="fuyumikanlab-icon" />
</div>

# AICreditBar

✧ 余额 / Balance Bar for AI API

原生 macOS 菜单栏小工具：实时显示各家 AI API **还剩多少钱**。

- 简洁：仅显示 Logo + 余额
- 原生：Swift + SwiftUI
- 安全：API Key 存储在钥匙串

## 数据源概览

- Deepseek
- Moonshot/KIMI
- Zhipu/GLM
- OpenRouter
- SiliconFlow
- OpenAI

<img alt="screenshot" src="https://github.com/user-attachments/assets/5d798b98-ddda-4fc7-b582-df4d21472014" />

## 使用说明

1. 本项目名称为：
   - bundleIdentifier = "com.fuyumikanlab.aicreditbar"
   - name = "AICreditBar"
   - display_name= "余额" | "Balance"
2. 初次使用时，会弹出提示：

   > `AICreditBar`想要使用你储存在钥匙串的`“com.fuyumikanlab.aicreditbar”`中的机密信息。

   选择`始终允许`即可。
   （如果名字不是上列名字，则说明是别的app。请不要许可访问。）

3. 设置：`数据源的API Key`，`状态栏显示`，`刷新间隔设置`，`登录时启动`。

## 已支持数据源详情

| 数据源               | 展示内容                          | Key 要求                           |
| -------------------- | --------------------------------- | ---------------------------------- |
| DeepSeek             | 可用余额（¥）、赠送/充值拆分      | 普通 API Key                       |
| Moonshot / Kimi      | 可用余额、赠送/现金拆分           | 普通 API Key（CN 站 ¥，海外站 $）  |
| OpenRouter           | 可用额度、本月已用                | API Key（403 时换 Management Key） |
| SiliconFlow 硅基流动 | 账户余额（¥）                     | 普通 API Key                       |
| OpenAI               | 本月 Token 与请求数（无余额接口） | Organization 管理员 Key            |
| 智谱 GLM             | 账户额度（总额/已用/可用）        | 标准版 API Key                     |

同一厂商多个账号：改 Base URL 后多开一份配置即可。


## 快速开发

```bash
swift build
swift run AICreditBar --selftest   # 离线自测，不发网络请求
./scripts/build-app.sh             # 产物：build/AICreditBar.app 与 zip
open build/AICreditBar.app
```

## 新增数据源

1. `ProviderKind` 加一个 case，语言包补 `provider.<case>.name / .capability / .setup_hint`
2. `Adapters/` 新建 Adapter，实现 `ProviderFetching`，把响应映射成 `ProviderMetrics`
3. 在 `ProviderRegistry` 登记；可选放入 `ProviderLogos/<case>.svg`

## 数据与隐私

请求从本机直连各厂商官方接口，无中转、无统计。API Key 只进钥匙串，偏好不含 Key。

## 感谢

- 非常有趣的、上班必备的插件：钱条 [Lakr233/MoneyProgress](https://github.com/Lakr233/MoneyProgress)
- 烧钱很快的[deepseek-harness](https://github.com/deepseek-ai/deepseek-harness)，这是一切都起因。

## 其他

如果你追求更详细的信息展示，请查看别的更完善的项目，或者给这个项目提Issue。感谢。
