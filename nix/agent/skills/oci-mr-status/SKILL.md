---
name: oci-mr-status
description: 查询工蜂 MR 在 Orange CI 上的检查状态，下载完整流水线日志并定位失败原因。用户提到 MR、CI、OCI 日志、push 后查看流水线或检查失败时使用。
---

# 查询 MR 与 Orange CI 日志

代码 push 后，先用 commit SHA 锁定这次构建，再用工蜂检查表找到 Orange CI 的流水线，最后把完整日志保存到 `/tmp` 并在本地读取。这样可以把「哪一项检查失败」「失败发生在哪个 job」「代码应该改哪里」连成一条链。

本 Skill 负责串联工具。`.orange-ci.yml` 的写法、构建触发和凭证配置沿用 [oci-skill](../oci-skill/SKILL.md)；需要等待一段时间再检查时，使用现有的 `loop` Skill。

## 处理流程

### 1. 先确定本次检查的 SHA

把 SHA 作为整次排查的唯一锚点。

- 当前工作区可用 `git rev-parse HEAD` 获取 SHA。
- 只有 MR 链接时，先用工蜂的 `search_merge_request` 获取仓库完整路径、源分支、目标分支和最新 SHA。
- 仓库名要写完整路径，例如 `namespace/repository`。短仓库名可能查不到项目。
- 每次重新 push 后都要重新获取 SHA。旧 SHA 的检查结果不能代表新提交。

### 2. 用工蜂获取检查表

工蜂 MCP 的命名空间是 `gongfeng`。调用前先用 `GetDynamicTools` 获取工具参数，再用 `CallDynamicTool` 调用工具。

MR 的 CI 状态使用 `get_commit_combined_status`：

```json
{
  "project_id": "namespace/repository",
  "ref": "<当前提交 SHA>",
  "target_branch": "<MR 目标分支>",
  "per_page": 100
}
```

重点保存每条状态中的：

- `context`：检查名称；
- `state`：检查状态，例如 `pending`、`success`、`error`；
- `block`：是否会阻止合入；
- `target_url`：Orange CI 构建页面，通常包含流水线 SN。

刚 push 后出现 `pending` 属于正常排队状态。用户要求稍后再看时，使用 `loop` Skill 设置一次唤醒；唤醒后重新执行本步骤。等待期间不把 `pending` 写成失败。

### 2.1 用 loop 轮询状态

需要每隔一段时间检查时，使用 `loop` 建立一个带有固定 SHA 的轮询任务。默认间隔是 5 分钟；用户明确指定间隔时，以用户指定的时间为准。用户只说「稍后再看」且没有给出时间时，使用 5 分钟。

例如，默认配置可以写成：

```text
/loop 5m 检查 namespace/repository 的 MR CI。当前 SHA 是 <sha>，目标分支是 <target>。
每次调用 gongfeng.get_commit_combined_status。
没有 error/failed 且仍有 pending 时，继续等待下一轮。
出现 error/failed 时，立即调查已经结束的失败检查，忽略仍为 pending 的流水线。
当前 SHA 的阻塞检查全部 success 时，取消这个 loop。
```

每次唤醒都重新查询同一个 SHA，并按下面的状态处理：

- **只有 `pending`**：流水线仍在执行，重新安排下一轮检查。此时不下载日志，也不开始修复。
- **同时有 `error/failed` 和 `pending`**：立即处理已经失败的检查。`pending` 只记录为未完成，不等待它结束，也不把它当成失败原因。
- **有多个 `error/failed`**：全部记录下来。相同 SN 的检查合并读取一次日志，再分别确认失败的 job。
- **当前 SHA 的阻塞检查全部 `success`**：按照 `loop` Skill 的停止流程取消定时任务，不再安排下一轮。

发现失败后，当前轮轮询进入调查阶段。调查期间不重复等待同一个失败结果；修复并 push 新提交后，停止旧 SHA 的 loop，再为新 SHA 建立新的 loop。这样可以避免旧提交和新提交的状态混在一起。

### 3. 从检查表找到 Orange CI 的 SN

检查项的 `target_url` 通常类似：

```text
https://orange-ci.woa.com/build/log/oci-xxxx
```

最后的 `oci-xxxx` 是流水线 SN。同一条 SN 可能对应多个检查项，例如 CCK、编译和测试。先按 SN 合并这些检查项，再判断哪些 job 失败。

只分析当前 SHA 对应的检查。检查表里可能同时出现旧流水线，不能因为旧流水线成功就判定当前提交通过。

### 4. 将完整日志下载到 `/tmp`

完整日志使用 `oci-skill` 已有的 `oci-log.sh`。下载时把输出写入本地文件，保留原始日志，后续再定位和读取。

```sh
SN="oci-xxxx"
LOG_DIR="/tmp/oci-${SN}"
mkdir -p "$LOG_DIR"

OCI_ENV_FILE="$HOME/.cursor/orange-ci.env" \
  bash "$HOME/.claude/skills/oci-skill/scripts/oci-log.sh" \
  "$SN" --all --output "$LOG_DIR/build.log"
```

`--all` 会依次尝试 `001`、`002` 等日志序号。成功后通常会生成：

```text
/tmp/oci-xxxx/build.log.001
/tmp/oci-xxxx/build.log.002
```

并行 job 可能有多个文件。只需要一个序号时，可以改用：

```sh
OCI_ENV_FILE="$HOME/.cursor/orange-ci.env" \
  bash "$HOME/.claude/skills/oci-skill/scripts/oci-log.sh" \
  "$SN" --seq 001 --output "/tmp/oci-${SN}.log"
```

`OCI_ENV_FILE` 可以换成实际的凭证文件路径。`oci-log.sh` 会读取 `oci-skill` 约定的环境变量，当前脚本使用 `ORANGE_CI_GITLAB_TOKEN`，并要求环境文件提供 `ORANGE_CI_USER`。不要把 token 写进命令参数、提交内容或日志摘要。

下载失败时先确认三件事：SN 属于当前 SHA、凭证文件路径正确、凭证具备目标仓库权限。不要把 GraphQL 的状态查询结果当成完整日志；完整 stdout 走 `oci-log.sh`。

### 5. 读取本地日志并定位失败 job

日志可能很大。先搜索，再读取命中位置附近的上下文：

```sh
rg -n -i 'error|failed|fatal|exit code: [1-9]|total errors found|ctest' \
  "/tmp/oci-${SN}"
```

然后使用 `ReadFile` 读取对应文件和行号附近的内容。需要查看日志开头或结尾时，也从 `/tmp` 文件读取；不要把 20 MB 日志一次性复制到对话中。

重点确认：

1. 哪个 stage 或 job 返回失败；
2. 失败命令是什么；
3. 第一条有意义的错误是什么；
4. 后续错误是根因还是前置失败产生的连锁输出；
5. 失败属于代码、测试数据、构建环境还是 CI 配置。

日志中的 `exit code: 0` 表示命令成功。只有结合 job 状态、失败命令和上下文后，才能判断整条检查是否失败。

### 6. 对照仓库配置和本地变更

找到失败命令后，回到当前仓库的 `.orange-ci.yml` 及其引用文件，确认这个 job 实际执行的脚本、镜像和工作目录。流水线页面上的中文名称只能帮助定位，不能代替配置文件中的真实命令。

静态检查需要使用与 CI 相同的变更文件列表。通常按目标分支计算：

```sh
git diff --name-only "origin/<目标分支>...<当前 SHA>"
```

再使用仓库已有的配置文件和工具复跑。这样可以捕获「这次虽然只改了一行，但整个文件被增量检查重新扫描」的情况。

### 7. 修复后重新验证

修复、提交并 push 后：

1. 获取新的 SHA；
2. 停止旧 SHA 对应的 loop；
3. 为新 SHA 建立新的 loop；
4. 重新调用 `get_commit_combined_status`；
5. 从新的 `target_url` 提取 SN；
6. 把新流水线日志下载到新的 `/tmp/oci-<SN>/` 目录；
7. 直到当前 SHA 上会阻止合入的检查全部通过，再取消 loop。

## 工具职责

| 工具 | 用途 |
| --- | --- |
| `GetDynamicTools` | 获取工蜂 MCP 工具的最新参数定义 |
| `CallDynamicTool` | 调用 `gongfeng.search_merge_request`、`gongfeng.get_commit_combined_status` 等工具 |
| `Shell` | 执行 Git 命令和 `oci-log.sh`，将日志下载到 `/tmp` |
| `rg` | 在本地完整日志中定位错误、失败命令和测试用例 |
| `ReadFile` | 读取日志命中位置的上下文 |
| `loop` Skill | 在用户指定的时间后重新查询当前 SHA |
| `oci-skill` | 提供 Orange CI 的脚本、凭证约定和 API 细节 |

## 交付排查结果

向用户汇报时按以下顺序说明：

1. 当前 SHA 和 MR；
2. 失败检查的 `context`、流水线 SN 和失败 job；
3. 日志中支持判断的关键证据；
4. 根因与代码问题的对应关系；
5. 已完成的修复、验证结果和下一次需要关注的检查。

状态仍为 `pending` 时，只说明流水线还在运行。状态为 `success` 时，说明对应检查已经结束并通过；如果同一 SHA 还有其他阻塞检查处于 `pending` 或 `error`，MR 仍未完成验证。
