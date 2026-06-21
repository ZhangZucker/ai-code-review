@{
    # 评审报告仓库地址：不要带末尾的 .git。
    GithubReviewLogUri = "https://github.com/your-account/openai-code-review-log"
    # 建议使用只允许写入上述仓库的 Fine-grained Personal Access Token。
    GithubToken = "REPLACE_WITH_GITHUB_TOKEN"

    ChatGlmApiHost = "https://open.bigmodel.cn/api/paas/v4/chat/completions"
    ChatGlmApiKeySecret = "REPLACE_WITH_CHATGLM_API_KEY_SECRET"

    WeixinAppId = "REPLACE_WITH_WEIXIN_APP_ID"
    WeixinSecret = "REPLACE_WITH_WEIXIN_SECRET"
    WeixinToUser = "REPLACE_WITH_WEIXIN_OPEN_ID"
    WeixinTemplateId = "REPLACE_WITH_WEIXIN_TEMPLATE_ID"

    # 这些文字会显示在微信模板消息中。请避免使用 Windows 文件名非法字符。
    ProjectName = "ai-code-review-demo"
    BranchName = "main"
    CommitAuthor = "demo-student"
    CommitMessage = "答辩演示：提交一段待评审代码"

    # Eclipse Adoptium 官方 API：自动获取最新 Java 11 Windows x64 JRE。
    JavaDownloadUrl = "https://api.adoptium.net/v3/binary/latest/11/ga/windows/x64/jre/hotspot/normal/eclipse?project=jdk"
    # Git for Windows 官方 GitHub Release API：脚本自动选择 MinGit 64-bit ZIP。
    GitHubReleaseApiUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"

    # 优先使用本地 JAR；不存在时使用下面的固定下载地址。
    SdkJarPath = (Join-Path $PSScriptRoot "lib\openai-code-review-sdk-1.0.jar")
    SdkJarDownloadUrl = "https://github.com/fuzhengwei/openai-code-review-log/releases/download/v1.0/openai-code-review-sdk-1.0.jar"
    # 可选：填写下载 JAR 的 SHA-256（64 位十六进制）可启用完整性校验。
    SdkJarSha256 = ""
}
