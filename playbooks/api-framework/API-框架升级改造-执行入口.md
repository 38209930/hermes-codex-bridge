# API 框架升级改造执行入口

这是一份通用 API 框架治理入口，适合交给 AI 编程代理或工程师作为第一轮施工说明。它不绑定具体业务仓库，也不包含真实密钥、真实连接串或生产数据。

## 执行原则

- 先确认项目类型、运行命令和测试命令。
- 每完成一个模块就编译或运行对应测试。
- 涉及认证、密码、短信、支付、文件上传和外部回调的改动必须额外做安全验证。
- 真实 secrets 只能放在环境变量、私有配置或部署平台密钥管理中。

## 必做模块

### 1. 鉴权与会话治理

- 统一 token 签发与校验口径。
- 避免过期时间被错误截断或反向判断。
- 推荐统一使用 UTC 时间。
- 所有 401/403 行为要与前端清登录态逻辑匹配。

搜索锚点：

```text
AuthFilter
Jwt
Token
Expires
Unauthorized
```

### 2. 敏感接口改造

- 修改密码、重置密码、验证码校验等接口不得使用 `GET + Query` 传敏感值。
- 使用 `POST + Body`，并引入 DTO 校验。
- 请求日志必须对密码、token、验证码、密钥字段脱敏。

搜索锚点：

```text
password
newPassword
confirmPassword
verificationCode
request logging
```

### 3. 测试能力与后门清理

- 生产环境不得保留匿名模拟登录、万能验证码、测试手机号白名单、未鉴权测试发送接口。
- 如确需保留测试能力，只允许在 Development 环境且受显式开关控制。

搜索锚点：

```text
mock
simulate
test
debug
bypass
```

### 4. 配置与 secrets 治理

- 公开配置文件只保留结构和非敏感默认值。
- 真实数据库、Redis、对象存储、短信、支付、地图、天气等密钥必须迁移到 secrets。
- 推荐配置加载顺序：
  1. `appsettings.json`
  2. `appsettings.{Environment}.json`
  3. `appsettings.Secrets.json`
  4. `appsettings.{Environment}.Secrets.json`
  5. environment variables

搜索锚点：

```text
AddJsonFile
ConnectionString
UseMySql
UseSqlServer
Redis
Secret
ApiKey
```

### 5. CORS 与公开接口边界

- 不允许 `AllowCredentials` 搭配任意来源。
- 使用精确来源白名单或可信域名后缀白名单。
- 区分后台管理 API、公开展示 API、第三方回调 API。

搜索锚点：

```text
AddCors
AllowCredentials
SetIsOriginAllowed
AllowedOrigins
```

### 6. 缓存与系统配置容错

- 系统配置表为空时，首次保存应自动创建默认记录。
- 读缓存失败时回退数据库。
- 写缓存或删缓存失败只记录 warning，不中断主业务。

搜索锚点：

```text
ConfigService
SystemConfig
Redis
Cache
```

## 可选业务模块

### 内容系统

- 多栏目发布。
- 公开分页按多个栏目检索。
- 详情返回栏目列表。
- 首页展示配置后端化。

### 天气/外部 API

- 外部 API 失败不得导致首页或公开接口 500。
- 对实时数据做短期缓存。
- API key 和私钥路径必须走 secrets。

### 短信/通知

- 建立统一发送入口。
- 业务层不直接依赖供应商 SDK。
- 群发要去重、校验、限流，并区分提交态与最终回执态。

## 统一验收

- 构建通过。
- 测试通过或记录未覆盖原因。
- 仓库中无真实密钥。
- 日志中不出现明文密码、token、验证码。
- 生产环境无未鉴权测试接口。
- CORS 只允许可信来源。
- 缓存不可用时核心业务仍可降级运行。

## 可直接给 AI 的指令模板

```text
请按以下顺序对当前 API 项目做框架级治理。每完成一项都运行构建或对应测试，并说明是否存在兼容风险：

1. 统一 token 有效期判断与签发口径。
2. 将敏感接口从 GET Query 改为 POST Body，并补日志脱敏。
3. 清理生产环境认证绕过、万能验证码、测试发送接口。
4. 增加 secrets 配置加载，移除仓库中的真实密钥与硬编码连接串。
5. 收紧 CORS，只允许配置中的可信来源。
6. 修复系统配置与缓存容错。
7. 如项目包含内容、天气、短信等模块，按模块做独立改造与验收。
```

