# Windows 一键答辩演示

这套演示会自动创建一个临时 Git 仓库和两次提交，然后运行真实的 AI 代码评审链路：ChatGLM 生成评审、GitHub 保存报告、微信发送通知。

答辩者不需要使用 Git、Maven 或命令行，只需双击 `一键演示.bat`。

## 演示前准备

1. 将 `demo-config.example.ps1` 复制为 `demo-config.ps1`。
2. 在 `demo-config.ps1` 中填写：
   - GitHub 评审日志仓库地址；
   - 仅能写入该仓库的 GitHub Token；
   - ChatGLM API Key；
   - 微信 AppID、Secret、OpenID 和模板 ID。
3. 推荐把已构建的 SDK JAR 放到：

   ```text
   demo\lib\openai-code-review-sdk-1.0.jar
   ```

   如果未放入，脚本会使用配置中的固定地址下载并缓存。
4. 在实际答辩 Windows 电脑上双击 `一键演示.bat`。

系统没有 Java 11 或 Git 时，脚本会自动下载便携版本到 `demo\runtime\`，不会修改系统环境变量。首次运行耗时较长，之后会复用缓存。

## 建议的答辩讲解顺序

1. 展示脚本正在自动创建两次提交。
2. 展示终端中的 Git diff 摘要。
3. 说明 ChatGLM 正在检查硬编码密码、空指针、资源泄漏、输入异常和低效循环。
4. 打开 GitHub 评审日志仓库查看 Markdown 报告。
5. 展示收到的微信模板消息。

## 重要提醒

- 必须提前在答辩电脑上完整彩排一次。
- `demo-config.ps1` 含真实密钥，已被 Git 忽略；不要提交，也不要随意发送给他人。
- 答辩结束后如需转交演示包，请确认接收者有权使用其中的账号和密钥。
- 如果演示失败，窗口不会闪退。根据红色提示检查，并查看 `demo\work\logs\` 下的日志。
