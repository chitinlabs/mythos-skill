# mythos-skill

> [English](./README.md) · 中文

受 OpenMythos 探索的 Recurrent-Depth Transformer 架构思路启发，通过 prompt-layer 协议在 Claude Code 中行为上近似潜空间推理。

## 这是什么

[OpenMythos](https://github.com/kyegomez/OpenMythos) 是社区开源的**假说性**项目，灵感来自循环深度 Transformer 架构的公开讨论。它**与 Anthropic 无任何关联，也未获其背书**，对任何真实 Claude 模型的实际架构不作可验证声明。它探索的假说是：一个 Transformer 通过同一组权重多次循环运行来实现"静默深度思考"，所有推理在连续潜空间中发生，循环之间不产生中间 token。

**mythos-skill** 把这个假说映射到 Claude Code 的 prompt 层：通过结构化的 **Prelude → Recurrent Block → Coda** 协议，从**行为上**——而非架构上——近似潜空间推理。每轮注入原始问题（`e`-injection）防止漂移，根据问题复杂度路由到三种执行模式之一。

## 这个项目不是什么

为了避免误解，先把边界划清楚：

- **不是 Anthropic 的产品**，也与 Anthropic 没有任何关联。
- **不是逆向工程**任何线上模型的产物。这里没有人掌握 Claude 真实架构的内部信息。
- **不是架构层面的声明**。这是在输入层强加的提示工程纪律。"循环深度"只是从社区假说里借来组织协议的隐喻，不是对模型内部行为的描述。
- **没有跑过基准测试**对比原生 CoT 或其他推理框架。质量靠 calibration 用例人工判断，没有严格 eval 证明它在固定任务集上更优。
- **没有魔法**。简单问题上它反而是额外开销——这就是为什么复杂度 1 的问题走 Direct 模式直接跳过整个协议。

## 安装

skill 已在 `.claude/skills/mythos/` 下，Claude Code 自动发现。无需额外安装。

如需安装到其他项目或用户级（全局所有项目生效），运行 init 脚本：

```bash
# Windows
.claude/skills/mythos/scripts/init.ps1 --user           # 用户级（所有项目）
.claude/skills/mythos/scripts/init.ps1 D:\Work\MyGame   # 项目级
.claude/skills/mythos/scripts/init.ps1 --both           # 两者都装

# macOS / Linux
bash .claude/skills/mythos/scripts/init.sh --user
bash .claude/skills/mythos/scripts/init.sh /path/to/project
```

或直接复制目录：

```bash
cp -r .claude/skills/mythos /path/to/other-project/.claude/skills/
```

## 使用

### 基础用法

```
/mythos <你的问题>
```

**示例：**

```
/mythos 我们的策略游戏该用事件溯源还是传统CRUD做存档系统？
/mythos 分析为什么我们游戏好评率82%但日活从5000跌到800
/mythos 评估三个技术方案：自研引擎 vs Godot vs Unity
```

### 三模式路由（v4）

skill 根据复杂度评分（1-5）自动选择执行模式：

| 模式 | 默认触发 | 用户可见内容 | 特点 |
|---|---|---|---|
| **Direct** | 复杂度 1 | 直接答案 | 零开销，跳过 Recurrent Block |
| **Silent**（默认） | 复杂度 2-3 | 仅 Coda（答案 + 单行轨迹注） | 推理在 internal/extended-thinking 中进行；无 token 间承诺 |
| **Trace** | `trace` 关键字触发 | Prelude + 每轮 insight chain + Answer | 可审计，适合教学/调试/深度分析 |
| **Agent** | 复杂度 4-5 | Prelude + 并行 subagent 结果 + 合并 + Answer | 多 lens 作为独立 subagent **并行**探索后合并 |

**复杂度评分（每项 1 分）：** 多跳依赖、模糊权衡、隐藏假设、新颖领域、高风险决策。

### 模式关键字（覆盖默认路由）

```
/mythos trace 我们应该采用 Conventional Commits 吗？     # 强制 Trace（可见轮次）
/mythos deep 是否应该重写渲染管线？                       # 强制 Agent（并行 fan-out）
/mythos agent 评估这个架构                                # 同上（deep 的别名）
/mythos quick 这个变量名好不好？                          # 强制 Silent（即使复杂度高）
```

关键字大小写不敏感，多关键字时**最后出现者胜**。

### 自动触发

skill 配置了触发条件——当问题涉及以下场景时自动激活：
- 多层推理或分层次的问题
- 设计权衡或架构决策
- 需要多视角的战略分析
- 需要挖掘和挑战隐藏假设的问题

## 工作原理

```
[你的问题]
     ↓
[PRELUDE]        理解、拆解、复杂度评分、识别主驱动因素、分配每镜头预算
     ↓
[RECURRENT × N]  三种执行方式之一
  silent: 镜头轮转在 internal reasoning 中进行，无逐轮发射
  trace:  镜头轮转发射可见轮次，含 insight chain 跨轮记忆
  agent:  镜头作为 N 个并行 subagent 独立探索，merge 阶段合并
     ↓
[CODA]           交叉验证、标识残留不确定性、按模式格式输出
```

### 推理镜头（Lens）

每轮应用一个特定的分析镜头，模拟 Mythos 的 loop-index embedding：

| 轮次 | 镜头 | 核心问题 |
|---|---|---|
| 1 | **Clarify** | 问题到底是什么？消除歧义，定义术语 |
| 2 | **Deepen** | 更深一层是什么？根因、第一性原理 |
| 3 | **Challenge** | 我做了什么假设？最强反驳是什么？ |
| 4 | **Expand** | 还有什么替代方案？不同领域的专家会怎么看？ |
| 5 | **Synthesize** | 所有视角如何整合成一个连贯答案？ |

专用镜头：System-Think、Edge-Hunt、Tradeoff-Map、Invert、Scar-Tissue、First-Principles、Steelman。

### 自适应预算分配

Prelude 识别 1-3 个**主复杂度驱动因素**，对应镜头获得 ×2 预算：

| 主驱动 | 加倍镜头 |
|---|---|
| 模糊性 | Clarify |
| 隐藏假设 | Challenge, Steelman |
| 多跳推理 | Deepen, System-Think |
| 权衡 | Tradeoff-Map, Expand |
| 新颖领域 | First-Principles, Expand |
| 系统动力 | System-Think, Edge-Hunt |

总轮数：silent/trace 通常 4-8 轮；agent 模式 3-5 个并行 subagent。

### 关键机制

- **原始上下文注入（e-injection）**：每轮前重读你的原始问题——这是 Mythos 架构中防止推理漂移的核心机制
- **收敛检测**：5 条严格标准（无 delta / 微小 delta / 自洽 / 达最大轮 / 负 delta 即过度思考）
- **中途模式升级**：每个 session 限一次 re-Prelude；如 Round 2 暴露被遗漏的主驱动，可重新评分并切换到更高模式
- **三模式映射**：silent 近似"层间无 token 承诺"，agent 近似"潜空间多路径并行"，trace 牺牲架构忠实换取可审计性

## 与原生 Claude 的区别

|  | 普通 Claude 回答 | mythos-skill |
|---|---|---|
| 推理方式 | 单次前向传播 | 多轮迭代精炼 / 并行多路径 |
| 思维链 | 线性 token 输出 | 结构化多视角分析 |
| 上下文保持 | 随 token 增长漂移 | 每轮重新注入原始问题 |
| 推理深度 | 固定 | 复杂度自适应 + 主驱动加权 |
| 可审计性 | 只有最终答案 | trace 模式完整可见；silent 模式提供 lens path 注脚 |

## 文件结构

```
.claude/skills/mythos/
├── SKILL.md                         # 主入口 — 三模式路由 + 完整流程
├── references/
│   ├── lenses.md                    # 12 个推理镜头 + 问题类型选择 + 驱动→镜头映射
│   ├── prompt-templates.md          # Prelude/Recurrent/Coda 内部模板（含退化 Coda）
│   ├── agent-blueprint.md           # Agent 模式并行 subagent 完整 prompt + 失败回退
│   ├── examples.md                  # 注释示例
│   └── mythos-init.md               # init 脚本生成的注入片段
└── scripts/
    ├── init.ps1 / init.sh           # 安装到其他项目或用户级
    └── calibrate.ps1 / calibrate.sh # 5 个标定用例的交互式跑测
```

## 校准

`scripts/calibrate.ps1` / `bash scripts/calibrate.sh` 提供 5 个标定用例（涵盖技术决策、战略权衡、缓存设计、流程改进、伦理争议），逐题交互式验证三种模式的结构性属性（lens 路径、轮数、并行 vs 串行 dispatch），生成时间戳报告 `calibration-report-YYYYMMDD-HHMM.md`。

校准是**人工设计**的——mythos 推理质量无法纯程序化验证，只能验证结构性属性（镜头存在、轮数、并行调度）。FAIL 计数应作为重读 SKILL.md 的信号，而非 ground truth。

## 理论背景

灵感来源于以下研究和社区开源工作。其中没有任何一项是 Anthropic 的官方发布，下文协议属于行为上的近似，不构成架构性声明：

- [OpenMythos](https://github.com/kyegomez/OpenMythos) — RDT 风格架构的社区开源假说（非官方，与 Anthropic 无关联）
- [Parcae](https://arxiv.org/abs/2604.12946) — 循环语言模型的稳定训练 scaling laws
- [Reasoning with Latent Thoughts](https://arxiv.org/abs/2502.17416) — 循环 Transformer 的推理能力
- [COCONUT](https://arxiv.org/abs/2412.06769) — 连续潜空间推理训练

完整论文见 `papers/`（gitignored，本地保留）。

## License

MIT
