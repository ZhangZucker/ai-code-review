# OpenAI Code Review

基于 ChatGLM 的自动代码评审 SDK。项目通过 GitHub Actions 或本地命令获取最近一次提交的 `git diff`，调用大模型生成代码评审报告，将报告提交到独立的 GitHub 日志仓库，并通过微信公众号模板消息发送评审链接和提交信息。

## 项目结构

```text
.
├── openai-code-review-sdk       # 代码评审 SDK，包含主入口、Git 操作、ChatGLM 调用、微信通知
├── openai-code-review-test      # 示例/测试模块，依赖 SDK
├── docs/curl                    # ChatGLM API 调试脚本
└── .github/workflows            # GitHub Actions 示例流水线
```

## 核心流程

`openai-code-review-sdk` 的入口类是 `plus.gaga.middleware.sdk.OpenAiCodeReview`，执行流程如下：

1. `GitCommand.diff()` 获取当前仓库最近一次提交的 diff。
2. `OpenAiCodeReviewService.codeReview()` 将 diff 和评审提示词发送给 ChatGLM，默认模型为 `glm-4-flash`。
3. `GitCommand.commitAndPush()` 克隆评审日志仓库，将大模型返回的 Markdown 评审报告写入 `yyyy-MM-dd/` 目录，并提交推送。
4. `WeiXin.sendTemplateMessage()` 发送微信公众号模板消息，消息中包含评审报告链接、仓库名、分支、提交人和提交说明。

## 模块说明

### openai-code-review-sdk

核心 SDK 模块，最终会打包为可执行 JAR。

主要类：

- `OpenAiCodeReview`：程序入口，读取环境变量并装配依赖。
- `AbstractOpenAiCodeReviewService`：定义代码评审模板流程。
- `OpenAiCodeReviewService`：实现 diff 获取、模型评审、报告记录、消息推送。
- `GitCommand`：执行 `git diff`，克隆日志仓库，写入并推送评审报告。
- `ChatGLM`：调用智谱 AI Chat Completions 接口。
- `WeiXin`：调用微信接口发送模板消息。

### openai-code-review-test

示例/测试模块，依赖 `openai-code-review-sdk`。当前模块中包含一个简单的 Spring Boot 配置和示例测试类，主要用于触发代码变更并验证评审链路。

## 环境要求

- JDK 8 及以上，GitHub Actions 示例使用 JDK 11。
- Maven 3.x。
- Git 命令可用。
- 可访问智谱 AI ChatGLM API。
- 可访问一个用于保存评审报告的 GitHub 仓库。
- 如需微信通知，需要配置微信公众号测试号或正式号模板消息。

## 环境变量

运行 SDK 前必须提供以下环境变量。入口类通过 `System.getenv` 读取配置，缺少任意变量都会抛出 `value is null`。

| 变量名 | 说明 |
| --- | --- |
| `GITHUB_REVIEW_LOG_URI` | 评审日志仓库地址，不带 `.git` 后缀，例如 `https://github.com/owner/openai-code-review-log` |
| `GITHUB_TOKEN` | 可向评审日志仓库 push 的 GitHub Token |
| `COMMIT_PROJECT` | 当前被评审仓库名 |
| `COMMIT_BRANCH` | 当前被评审分支名 |
| `COMMIT_AUTHOR` | 最近一次提交作者 |
| `COMMIT_MESSAGE` | 最近一次提交说明 |
| `WEIXIN_APPID` | 微信公众号 AppID |
| `WEIXIN_SECRET` | 微信公众号 Secret |
| `WEIXIN_TOUSER` | 微信模板消息接收用户 OpenID |
| `WEIXIN_TEMPLATE_ID` | 微信模板 ID |
| `CHATGLM_APIHOST` | ChatGLM 接口地址，例如 `https://open.bigmodel.cn/api/paas/v4/chat/completions` |
| `CHATGLM_APIKEYSECRET` | 智谱 AI API Key，格式通常为 `apiKey.apiSecret` |

## 本地构建

在仓库根目录执行：

```bash
mvn clean package -DskipTests
```

构建完成后，SDK 可执行 JAR 位于：

```text
openai-code-review-sdk/target/openai-code-review-sdk-1.0.jar
```

`openai-code-review-sdk` 使用 `maven-shade-plugin` 打包运行所需依赖，并将主类配置为：

```text
plus.gaga.middleware.sdk.OpenAiCodeReview
```

## 本地运行

建议在需要被评审的 Git 仓库根目录运行 JAR，因为 SDK 会在当前工作目录执行 `git log` 和 `git diff`。

```bash
export GITHUB_REVIEW_LOG_URI="https://github.com/owner/openai-code-review-log"
export GITHUB_TOKEN="your_github_token"
export COMMIT_PROJECT="$(basename "$(git rev-parse --show-toplevel)")"
export COMMIT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
export COMMIT_AUTHOR="$(git log -1 --pretty=format:'%an <%ae>')"
export COMMIT_MESSAGE="$(git log -1 --pretty=format:'%s')"
export WEIXIN_APPID="your_weixin_appid"
export WEIXIN_SECRET="your_weixin_secret"
export WEIXIN_TOUSER="your_weixin_touser"
export WEIXIN_TEMPLATE_ID="your_weixin_template_id"
export CHATGLM_APIHOST="https://open.bigmodel.cn/api/paas/v4/chat/completions"
export CHATGLM_APIKEYSECRET="your_api_key.your_api_secret"

java -jar openai-code-review-sdk/target/openai-code-review-sdk-1.0.jar
```

运行成功后，程序会：

- 读取最近一次提交的 diff。
- 生成 Markdown 格式代码评审报告。
- 将报告推送到 `GITHUB_REVIEW_LOG_URI` 指向的仓库。
- 发送微信模板消息。

## GitHub Actions 接入

仓库内提供了三份工作流示例：

- `.github/workflows/main-maven-jar.yml`：在 `master` 分支 push 或 pull request 时，使用 Maven 构建 SDK JAR 并运行评审。
- `.github/workflows/main-remote-jar.yml`：在 `master-close` 分支触发，下载远程发布的 SDK JAR 后运行。
- `.github/workflows/main-local.yml`：在 `master-close` 分支触发，演示直接编译运行 Java 入口类。

推荐使用 `main-maven-jar.yml`。使用前需要在 GitHub 仓库的 `Settings -> Secrets and variables -> Actions` 中配置以下 Secrets：

| Secret | 映射到运行变量 |
| --- | --- |
| `CODE_REVIEW_LOG_URI` | `GITHUB_REVIEW_LOG_URI` |
| `CODE_TOKEN` | `GITHUB_TOKEN` |
| `WEIXIN_APPID` | `WEIXIN_APPID` |
| `WEIXIN_SECRET` | `WEIXIN_SECRET` |
| `WEIXIN_TOUSER` | `WEIXIN_TOUSER` |
| `WEIXIN_TEMPLATE_ID` | `WEIXIN_TEMPLATE_ID` |
| `CHATGLM_APIHOST` | `CHATGLM_APIHOST` |
| `CHATGLM_APIKEYSECRET` | `CHATGLM_APIKEYSECRET` |

工作流中 `actions/checkout` 使用 `fetch-depth: 2`，用于保证最近一次提交可以和父提交做 diff。

## 微信模板

代码中发送的模板数据字段为：

| 字段 | 含义 |
| --- | --- |
| `repo_name` | 仓库名 |
| `branch_name` | 分支名 |
| `commit_author` | 提交人 |
| `commit_message` | 提交说明 |

模板内容可按如下结构配置：

```text
项目：{{repo_name.DATA}}
分支：{{branch_name.DATA}}
作者：{{commit_author.DATA}}
说明：{{commit_message.DATA}}
```

消息 URL 会指向生成的代码评审 Markdown 报告。

## 常见问题

### `value is null`

缺少必需环境变量。检查 `OpenAiCodeReview` 中读取的所有变量是否已经在本地 shell 或 GitHub Actions Secrets 中配置。

### `Failed to get diff`

SDK 通过 `git diff <latestCommit>^ <latestCommit>` 获取最近一次提交的差异。请确认：

- 当前目录是 Git 仓库。
- 仓库至少有两次提交。
- CI checkout 时保留了足够提交历史，例如 `fetch-depth: 2`。

### 重复运行时克隆日志仓库失败

`GitCommand.commitAndPush()` 会把评审日志仓库克隆到当前目录下的 `repo` 文件夹。重复本地运行前可以删除该目录，或在干净的 CI 工作目录中运行。

### Maven 命令不可用

本地需要先安装 Maven，或使用 IDE 自带 Maven 执行构建。当前仓库没有提交 Maven Wrapper。

## 开发说明

- 新增模型服务时，可实现 `IOpenAI` 接口并替换 `OpenAiCodeReview` 中的装配逻辑。
- 调整评审提示词时，修改 `OpenAiCodeReviewService.codeReview()` 中发送给模型的 prompt。
- 调整消息渠道时，可替换或扩展 `WeiXin` 通知实现。
- 当前 POM 中测试执行被设置为跳过，构建命令默认不会运行测试。

## 安全提示

不要在代码、脚本或 README 中提交真实的 GitHub Token、微信 Secret、ChatGLM API Key。生产使用时应统一通过环境变量或 GitHub Actions Secrets 注入。
