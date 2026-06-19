# Windows 一键答辩演示设计

## 目标

为不熟悉计算机和 Git 的答辩演示者提供一个可双击运行的 Windows 演示入口。演示者不需要创建仓库、提交代码、配置环境变量或输入命令，脚本自动完成示例代码准备、AI 代码评审、报告推送和微信通知。

## 使用体验

演示者只需要双击：

```text
一键演示.bat
```

脚本窗口按阶段显示中文进度：

1. 检查演示配置
2. 检查 Java 和 Git
3. 准备临时示例仓库
4. 创建初始提交
5. 制造待评审代码并创建第二次提交
6. 调用 AI 完成代码评审
7. 推送 Markdown 评审报告
8. 发送微信模板消息
9. 显示成功结果并等待用户按键退出

出现错误时窗口不会闪退，会显示失败阶段、常见原因和建议处理方式。

## 文件结构

```text
demo/
├── 一键演示.bat                   # 双击入口
├── run-demo.ps1                  # 主流程脚本
├── demo-config.example.ps1       # 不含密钥的配置模板
├── demo-config.ps1               # 本机真实配置，不提交 Git
├── README.md                     # 给准备演示的人看的简短说明
├── assets/
│   ├── initial/                  # 第一版正常示例代码
│   └── changed/                  # 第二版包含明显问题的代码
└── runtime/                      # 首次运行下载的便携运行环境，忽略提交
```

临时 Git 仓库、下载缓存和运行日志均写入 `demo/work/`，每次运行前自动清理，避免上一次演示影响本次结果。

## 配置与密钥

真实参数保存在 `demo/demo-config.ps1`：

- 评审日志 GitHub 仓库地址
- GitHub Token
- ChatGLM API 地址与 Key
- 微信 AppID、Secret、接收用户和模板 ID
- 可选的演示项目名、分支名、提交人和提交说明

`demo-config.ps1` 加入 `.gitignore`，仓库只保存 `demo-config.example.ps1`。答辩电脑或交付给室友的离线演示包可以包含真实配置文件，但 Git 历史不保存密钥。

脚本启动时检查所有必需字段。字段缺失时列出配置项名称，不输出已填写的密钥内容。

## 环境准备

### Java

脚本优先使用系统中已安装的 Java 11 或更高版本。如果不可用，则下载 Windows x64 便携 JRE 11 到 `demo/runtime/java/`，解压后仅供本演示使用，不修改系统环境变量。

### Git

脚本优先使用系统 Git。如果不可用，则下载 Windows x64 PortableGit 到 `demo/runtime/git/`，仅在当前脚本进程中使用。

### SDK JAR

答辩稳定性优先，演示脚本使用固定版本的 SDK JAR：

- 仓库中存在 `demo/lib/openai-code-review-sdk-1.0.jar` 时直接使用；
- 不存在时从配置中的固定下载地址获取并缓存；
- 下载完成后检查文件非空，失败则停止并提示。

脚本不在答辩现场运行 Maven 构建，避免 Maven 缺失、依赖下载或编译失败。

## 临时示例仓库

室友不需要创建 Git 仓库。脚本在 `demo/work/sample-project/` 自动执行：

1. 写入 `assets/initial/` 中的 Java 示例代码；
2. `git init` 并配置仅用于临时仓库的用户名和邮箱；
3. 创建第一次提交，内容为可正常工作的初始版本；
4. 用 `assets/changed/` 覆盖示例代码；
5. 创建第二次提交，加入便于答辩讲解的问题，例如：
   - 明文硬编码密码；
   - 空指针风险；
   - 未关闭资源；
   - 无效输入导致异常；
   - 低效循环或重复查询；
6. 确认 `HEAD^` 和 `HEAD` 均存在，展示 diff 摘要；
7. 在临时仓库根目录运行评审 JAR。

这样当前 SDK 的 `git diff HEAD^ HEAD` 能稳定获得内容，而且每次答辩展示的代码问题一致。

## 真实评审链路

PowerShell 脚本为 JAR 进程注入现有程序要求的全部环境变量：

- `GITHUB_REVIEW_LOG_URI`
- `GITHUB_TOKEN`
- `COMMIT_PROJECT`
- `COMMIT_BRANCH`
- `COMMIT_AUTHOR`
- `COMMIT_MESSAGE`
- `WEIXIN_APPID`
- `WEIXIN_SECRET`
- `WEIXIN_TOUSER`
- `WEIXIN_TEMPLATE_ID`
- `CHATGLM_APIHOST`
- `CHATGLM_APIKEYSECRET`

随后在临时仓库中运行：

```text
java -jar openai-code-review-sdk-1.0.jar
```

SDK 依次获取第二次提交的 diff、调用 ChatGLM、将 Markdown 报告提交到评审日志仓库，并发送微信通知。

## 结果判断

当前 SDK 的 `exec()` 会捕获内部异常，进程仍可能返回退出码 0，因此一键脚本不能只依赖退出码判断成功。

脚本同时检查：

- 标准输出中是否包含 `openai-code-review done!`；
- 是否包含 Git 推送成功日志；
- 是否包含微信模板消息响应；
- 是否出现 `openai-code-review error`；
- 本地是否生成完整运行日志。

成功时使用绿色文字显示“代码评审演示完成”，给出评审日志仓库地址，并提示查看微信消息。失败时使用红色文字显示失败阶段和日志文件路径。

## 网络与重复运行

- 所有下载设置超时、重试次数和明确的下载地址。
- Java、Git 和 JAR 下载后缓存，第二次运行不再下载。
- 每次运行重新创建临时示例仓库。
- 删除 SDK 在临时仓库中克隆的 `repo/` 目录，避免重复克隆失败。
- 运行日志按时间保存到 `demo/work/logs/`。
- 脚本只清理 `demo/work/` 下自己创建的临时目录，不操作用户其他文件。

## 安全边界

- 不在终端打印 Token、Secret 或 API Key。
- 不将真实配置提交到 Git。
- GitHub Token 仅需评审日志仓库的写权限，不使用全账户高权限 Token。
- 微信和 ChatGLM 密钥仅通过当前 Java 进程的环境变量传递。
- 临时仓库使用固定示例代码，不读取或上传答辩电脑上的其他项目。

## 验收标准

- Windows 用户双击批处理文件即可开始演示。
- 系统未安装 Java 或 Git 时可以自动准备便携版本。
- 脚本自动创建恰好两次提交，并能生成非空 diff。
- 无需 Maven、IDE 或手动 Git 操作。
- 真实链路能生成 GitHub Markdown 报告并发送微信通知。
- 缺少配置、网络失败或外部服务失败时不会闪退，且提示可理解。
- 第二次及后续运行不会因缓存或残留 `repo/` 目录失败。
- 仓库中不存在真实密钥。
