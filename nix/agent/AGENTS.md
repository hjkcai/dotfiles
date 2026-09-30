以下是全局公共规则，与具体项目无关，必须遵守。如果与项目规则冲突，与项目规则为准。

# Do

- 使用简体中文沟通
- 所有文本（包括与用户日常的沟通、注释、文档等）**必须**遵循 writing-style skill，不可不遵循
- 尽可能复用存量代码，不要重复造轮子，Don't Repeat Yourself
- 编写代码时必须优先照顾读者体验
  - 关键的常量放在文件最前面
  - 使用阅读顺序：使用在定义的前面。导出的符号应该优先往前放
- 如果要向我提问，一次只能提一个问题
- 考虑如何使用优秀的开源第三方库来解决问题，而不是一上来什么都自己写
- 代码 push 后如果用户要求要开 MR, 使用 gongfeng MCP create_merge_request 而不是尝试访问 push 后的 git.woa.com 链接
- 运行命令的时候，虽然用 head/tail 节省上下文是好事，但是万一没有出现你想看的日志，那就会反复执行浪费时间。使用 tee 把完整日志写入临时文件然后再反复分析
- Design/Plan/Brainstorming 阶段，逐项对齐包括需求澄清、架构设计、流程设计、接口设计，使用 Markdown 有序列表给我选项让我选择

# Don't

- 禁止在 import、function 参数声明、解构对象等位置断行，给我一行排开
- index.[jt]sx? 只做导出不要写逻辑
- 不要主动进入 Brainstorming
- Design/Plan/Brainstorming 阶段不要大面积写代码，用接口定义、流程图或简单伪代码表达方案
- 原则上不允许使用 `any`、`@ts-ignore`、`eslint-disable` 等手段绕过类型系统
- 用户没有主动要求时不允许 `git push`、Git Worktree
- 严禁使用 `git stash`，必须每次都得到用户确认。通常项目中都有多个 Agent 同时运行，`git stash` 会让其它 Agent 失效
- 禁止使用 AskUserQuestion 工具
- 用户没有主动要求时，严禁任何修改系统的行为，包括安装/卸载全局软件包、动态链接库、npm/pip 包等
- 一般情况下禁止手工修改 lockfile，这种都需要使用对应的包管理器生成
