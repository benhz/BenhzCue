# 生物识别登录功能

## 概述

Image to Calendar 应用现在支持使用 Face ID 或 Touch ID 进行生物识别认证，为您的日程数据提供额外的安全保护。

## 功能特性

### 🔐 支持的认证方式

- **Face ID**: iPhone X 及更新机型
- **Touch ID**: 支持 Touch ID 的 iPhone 和 iPad 机型
- **设备密码**: 当生物识别不可用时的备选方案

### 🎨 登录界面

登录界面采用渐变背景设计，提供优雅的用户体验：

- 应用图标和名称展示
- 根据设备类型显示相应的生物识别图标
- 自动触发认证（启动后 0.5 秒）
- 备用密码登录选项
- 隐私保护提示

### ⚡ 自动认证

为了提升用户体验，应用具有以下智能特性：

- **会话管理**: 成功登录后 5 分钟内无需重新认证
- **自动触发**: 打开应用时自动弹出认证对话框
- **优雅降级**: 生物识别不可用时自动提供密码选项

### ⚙️ 设置选项

在设置界面的"安全"部分，您可以：

1. **查看生物识别类型**
   - 显示设备支持的认证方式（Face ID 或 Touch ID）

2. **启用/禁用启动认证**
   - 切换开关以控制是否需要登录
   - 默认启用以保护隐私

3. **登出**
   - 清除当前会话
   - 下次启动时需要重新认证

## 使用流程

### 首次使用

1. 启动应用
2. 系统提示请求 Face ID 或 Touch ID 权限
3. 点击"允许"授予权限
4. 完成首次认证

### 日常使用

1. 打开应用
2. 自动弹出认证对话框
3. 使用 Face ID/Touch ID 验证
4. 或点击"使用密码"使用设备密码
5. 认证成功后进入主界面

### 登出

1. 打开应用设置（点击右上角齿轮图标）
2. 滚动到"安全"部分
3. 点击红色"Logout"按钮
4. 应用返回登录界面

## 安全特性

### 🛡️ 本地认证

- 所有认证都在设备本地完成
- 不会上传任何生物识别数据
- 使用 iOS 原生 LocalAuthentication 框架

### ⏱️ 会话超时

- 认证后 5 分钟内保持会话
- 超时后需要重新认证
- 可在设置中完全禁用认证

### 🔒 数据保护

- 认证状态仅存储在设备上
- 使用 UserDefaults 安全存储
- 登出时清除会话信息

## 错误处理

应用会优雅地处理各种认证错误：

| 错误类型 | 说明 | 用户操作 |
|---------|------|---------|
| 认证失败 | 生物识别不匹配 | 重试或使用密码 |
| 用户取消 | 主动取消认证 | 可重新触发 |
| 未设置 | 未配置生物识别 | 引导至系统设置 |
| 锁定 | 多次失败被锁定 | 使用密码解锁 |
| 不支持 | 设备不支持 | 仅显示密码选项 |

## 权限说明

### Info.plist 配置

应用需要以下权限：

```xml
<key>NSFaceIDUsageDescription</key>
<string>使用 Face ID 验证您的身份以保护您的日程数据安全。</string>
```

### 权限请求时机

- **不在启动时请求**: 遵循最佳实践
- **首次认证时请求**: 用户触发登录时才请求
- **清晰的说明**: 告知用户为何需要此权限

## 开发者信息

### 文件结构

```
ImageToCalendar/
├── Services/
│   └── BiometricAuthService.swift    # 生物识别服务
├── Views/
│   ├── LoginView.swift                # 登录界面
│   └── SettingsView.swift             # 设置界面（已更新）
└── App/
    └── ImageToCalendarApp.swift       # 应用入口（已更新）
```

### 关键组件

#### BiometricAuthService

提供生物识别认证功能的服务类：

```swift
// 检查生物识别可用性
func isBiometricAvailable() -> (available: Bool, biometryType: LABiometryType, error: String?)

// 执行生物识别认证
func authenticate(reason: String?) async throws -> Bool

// 使用设备密码认证
func authenticateWithPasscode(reason: String?) async throws -> Bool
```

#### AppState

管理全局认证状态：

```swift
class AppState: ObservableObject {
    @Published var isAuthenticated: Bool

    func logout()  // 登出方法
}
```

#### LoginView

登录界面视图，支持：
- Face ID / Touch ID 认证
- 设备密码备选
- 自动触发认证
- 错误处理和重试

### 自定义配置

#### 修改会话超时时间

在 `ImageToCalendarApp.swift` 的 `AppState.init()` 中：

```swift
// 当前：5 分钟 (300 秒)
isAuthenticated = timeSinceAuth < 300

// 修改为 10 分钟
isAuthenticated = timeSinceAuth < 600

// 修改为 1 分钟
isAuthenticated = timeSinceAuth < 60
```

#### 禁用自动认证

在 `LoginView.swift` 的 `.onAppear` 中：

```swift
// 注释掉以下代码即可
// DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//     viewModel.authenticate()
// }
```

#### 修改延迟触发时间

```swift
// 当前：0.5 秒
deadline: .now() + 0.5

// 修改为 1 秒
deadline: .now() + 1.0

// 修改为立即触发
deadline: .now()
```

## 测试建议

### 模拟器测试

iOS 模拟器支持 Face ID/Touch ID 模拟：

1. 运行应用到模拟器
2. 当出现认证对话框时
3. 菜单：**Features** → **Face ID** → **Enrolled**
4. 菜单：**Features** → **Face ID** → **Matching Face**（成功）
5. 菜单：**Features** → **Face ID** → **Non-matching Face**（失败）

### 真机测试

1. 在真实 iPhone/iPad 上测试
2. 确保设备已设置 Face ID 或 Touch ID
3. 测试各种场景：
   - 成功认证
   - 认证失败
   - 取消认证
   - 使用密码
   - 会话超时
   - 登出功能

### 错误场景测试

1. **未设置生物识别**
   - 在系统设置中禁用 Face ID
   - 应用应显示密码登录选项

2. **多次失败锁定**
   - 故意多次认证失败
   - 应提示使用密码解锁

3. **权限被拒绝**
   - 首次拒绝权限
   - 应显示引导至设置的提示

## 最佳实践

### 用户体验

✅ **推荐做法**:
- 自动触发认证，减少用户操作
- 提供清晰的错误提示
- 支持密码备选方案
- 会话管理减少频繁认证

❌ **避免做法**:
- 过于频繁的认证请求
- 没有备选方案
- 错误提示不清晰
- 强制要求生物识别

### 安全性

✅ **推荐做法**:
- 使用系统原生认证框架
- 不存储生物识别数据
- 实现会话超时
- 提供登出选项

❌ **避免做法**:
- 自己实现生物识别
- 永久保持登录状态
- 在网络传输认证信息
- 缺少登出机制

## 常见问题

### Q: 为什么需要登录？

A: 为了保护您的日程和提醒数据，防止未授权访问。您可以在设置中禁用此功能。

### Q: Face ID 不工作怎么办？

A: 点击"使用密码"按钮，使用您的设备密码登录。同时检查系统设置中 Face ID 是否已配置。

### Q: 会话超时时间能修改吗？

A: 目前默认 5 分钟。如需修改，请参考上方"自定义配置"部分。

### Q: 可以完全禁用登录吗？

A: 可以。进入设置 → 安全 → 关闭"Require authentication on launch"开关。

### Q: 登出后数据会丢失吗？

A: 不会。登出仅清除认证会话，所有日程和提醒数据都保存在 iOS 系统中。

### Q: 支持哪些设备？

A:
- Face ID: iPhone X 及更新机型
- Touch ID: iPhone 5s 至 iPhone 8/SE，以及支持的 iPad
- 密码: 所有设备都可使用密码登录

## 更新日志

### v1.1.0 (2025-11-11)

- ✨ 新增 Face ID / Touch ID 登录界面
- 🔒 添加生物识别认证服务
- ⏱️ 实现 5 分钟会话管理
- ⚙️ 设置中添加安全选项
- 🌏 中文本地化
- 📱 优雅的 UI 设计
- 🛡️ 完善的错误处理

## 反馈

如遇到问题或有改进建议，欢迎反馈：

- 在设置中查看应用版本信息
- 检查系统设置中的权限状态
- 尝试重启应用或设备
- 查看本文档的故障排除部分

---

**安全提示**: 生物识别认证是保护您隐私的额外措施，但请妥善保管您的设备。
