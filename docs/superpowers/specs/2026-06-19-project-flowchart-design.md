# AI Code Review 项目流程图设计

## 目标

为第一次接触本项目的开发者提供一张可在几十秒内读懂的总览流程图。图中展示项目如何被触发、SDK 如何完成代码评审，以及评审结果如何保存和通知。

## 表达方案

采用用户确认的「横向分阶段」单图布局，从左到右阅读，并用背景分组区分三个阶段：

1. 触发与准备
2. SDK 核心流程
3. 结果交付

主流程使用实线箭头，异常使用虚线箭头汇聚到统一的「记录错误并结束」节点。节点标题描述业务动作，副标题标注关键类或外部系统。

## 流程内容

主链路如下：

1. GitHub 仓库发生 `push` 或 `pull_request`，也可由开发者在本地运行 JAR。
2. GitHub Actions 检出至少两个提交、构建或获取 SDK JAR，并注入项目、GitHub、ChatGLM、微信配置。
3. `OpenAiCodeReview.main()` 校验环境变量并装配 `GitCommand`、`ChatGLM`、`WeiXin` 和 `OpenAiCodeReviewService`。
4. `AbstractOpenAiCodeReviewService.exec()` 按模板方法依次编排后续步骤。
5. `GitCommand.diff()` 获取最近一次提交及其父提交之间的 diff。
6. `OpenAiCodeReviewService.codeReview()` 组装评审提示词，通过 `ChatGLM` 调用 `glm-4-flash`，生成 Markdown 评审报告。
7. `GitCommand.commitAndPush()` 克隆评审日志仓库，将报告写入日期目录，提交并推送，返回报告 URL。
8. `WeiXin.sendTemplateMessage()` 将报告 URL、仓库、分支、作者和提交说明发送给微信用户。
9. 流程正常结束。

## 异常表达

图中不展开每种网络和 Git 异常，避免主图失焦。以下关键步骤通过虚线连接统一异常出口：

- 环境变量缺失
- Git diff 获取失败
- ChatGLM 请求或响应失败
- 日志仓库克隆、写入或推送失败
- 微信 access token 或模板消息发送失败

统一异常出口对应当前实现：`AbstractOpenAiCodeReviewService.exec()` 捕获异常、写入错误日志并结束本次执行。

## 视觉规范

- 横向画布，适合在 README、文档和飞书画板中查看。
- 蓝色表示 CI/触发，紫色表示 SDK 编排，绿色表示模型评审，黄色表示报告存储，红色表示消息通知。
- 每个节点最多两行文字，类名使用等宽或副标题样式。
- 主流程箭头保持单方向，避免交叉线。
- 只保留帮助新人理解系统的关键类，不展示 DTO、工具类和所有环境变量名称。

## 项目产物

确认后生成到项目的 `diagrams/<本地时间>/` 目录：

- `diagram.mmd`：可继续编辑的 Mermaid 源码
- `diagram.png`：便于直接预览和嵌入文档的图片
- `diagram.json`：供飞书画板导入或后续转换使用的 OpenAPI JSON

如提供飞书画板 token，可在不改变本地源文件的前提下将同一张图写入飞书画板。

## 验收标准

- 图中主流程与当前 README、GitHub Actions 和 Java 实现一致。
- 新开发者无需阅读源码即可说清楚触发、评审、保存、通知四个核心阶段。
- Mermaid 可以成功渲染。
- PNG 中不存在文字溢出、节点重叠或难以辨认的连线。
- 本地产物可单独使用，不依赖飞书链接。
