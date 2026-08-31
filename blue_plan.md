# 生信技能库（Skill Library）架构与构建方案

（截至 2026 年 8 月 · 最终演进版）

## 一、 定位与目标

构建一个以软件/工具为中心、高度自包含（Self-contained）、标准化解耦，且同时原生支持“人类工程师手动调用”与“大模型/AI Agent 自动编排”的自动化生信技能库（Bioinformatics Skill Infrastructure）。

### 核心指标

- **以软件为归档主键**：统一入口，彻底解决跨流程语言（Nextflow / Snakemake / Shell）的代码碎片化问题。
- **零外部网络依赖**：代码、镜像/容器定义、测试数据与标准 Schema 全量本地化（Offline-first）。
- **双模调用兼容**：既能作为独立的 CLI 工具运行，也能作为 JSON-Schema 驱动的 Function Calling / Tool Definition 供 AI Agent 解析。
- **极速环境隔离**：原生支持 Docker / Apptainer / Conda 映射，保障跨集群/跨云部署的环境可重复性。

## 二、 核心设计原则

1. **软件名归档（Software-centric Registry）**：顶级目录按照软件 Canonical Name 命名，规范统一小写（如 `samtools`, `bwa-mem2`）。
2. **三位一体自包含（Standardized Triumvirate）**：每个 Native 技能必须包含：`声明式元数据 (meta.yaml)` + `轻量封装代码 (main.py/run.sh)` + `自测试套件 (test/)`。
3. **多实现并行（Multi-Implementation Native Architecture）**：同一软件目录下，以 Native 为核心主干，同时兼容并存流程引擎风格实现（`nfcore_style`, `snakemake_style`）。
4. **Agent 优先的描述规范（Agent-Native Prompting）**：元数据中的 `description` 必须严格遵循 **"Function + Context + When-to-use + Edge Cases"** 的 Prompt 工程范式，而非简单的功能介绍。
5. **强类型数据流契约（Strict I/O Schema）**：明确区分 **Path-like (File/Dir)** 与 **Primitive (Int/Float/String/Bool)** 参数，严格约束输入输出格式（如 BAM/FASTQ/VCF 等扩展名）。

## 三、 完整目录结构规范

Bash

```
skills/
├── registry.yaml                # 动态生成的注册表索引缓存（可由 CLI 工具自动解析构建）
├── base.py                      # Python Skill Runner 基类与 JSON Schema 导出工具
├── bin/                         # 技能库 CLI 管理工具（如 `skill-cli validate`, `skill-cli run`）
│
├── fastqc/                      # 软件归档主目录
│   ├── meta.yaml                # 软件级总览元数据
│   ├── native/                  # [必须] 自维护标准 Native 实现
│   │   ├── meta.yaml            # 技能实现级元数据（含 Schema）
│   │   ├── main.py              # 标准入口程序（统一 CLI 参数处理与日志打印）
│   │   ├── Environment.def      # Apptainer / Singularity 构建文件
│   │   ├── Dockerfile           # Docker 构建文件
│   │   ├── test/                # 最小自动化测试集
│   │   │   ├── test_data/       # 极简测试输入（< 1MB）
│   │   │   └── run_test.sh      # 一键校验脚本
│   │   └── README.md            # 人类开发者阅读文档
│   ├── nfcore_style/            # [可选] nf-core 风格本地化 Process
│   │   ├── meta.yaml
│   │   ├── main.nf
│   │   └── README.md
│   └── snakemake_style/         # [可选] Snakemake 风格本地化 Wrapper
│       ├── meta.yaml
│       ├── wrapper.py
│       └── README.md
│
├── custom/                      # 复合业务技能（不属于单一软件的 Pipeline 或脚本）
│   └── eccdna_cluster_merge/    # 示例：自定义的复合分析逻辑
│       ├── meta.yaml
│       └── main.py
```

## 四、 升级版元数据与 Schema 规范

### 1. 软件级元数据 (`fastqc/meta.yaml`)

YAML

```
software: fastqc
version_latest: "0.12.1"
category: quality_control
keywords: [qc, fastq, raw_reads, sequence_quality]
homepage: https://www.bioinformatics.babraham.ac.uk/projects/fastqc/
summary: High throughput sequence data quality control check.
implementations:
  - id: native
    path: native/
    recommended: true
    status: stable
  - id: nfcore_style
    path: nfcore_style/
    status: maintained
```

### 2. 技能实现级元数据 (`fastqc/native/meta.yaml`)

> **完善点**：增加了显式的类型约束、校验规则（`pattern`）、Agent 使用指南（`agent_guidance`）以及资源限制策略。

YAML

```
id: fastqc_native
version: "0.12.1-v1.0"
software: fastqc
type: native

# Agent 语义增强
summary: "Performs quality control checks on raw sequence data coming from High Throughput Sequencing pipelines."
description: |
  FastQC reads raw sequencing files (FASTQ) and provides a set of analyses on quality scores, 
  GC content, sequence length distribution, and adapter contamination.
agent_guidance:
  when_to_use: "Always execute on raw reads immediately after sequencing or unarchiving, BEFORE any alignment, trimming, or downstream assembly."
  when_not_to_use: "Do NOT use on BAM/SAM files directly (use samtools stats instead) or downstream quantification tables."
  common_pitfalls: "Large gzipped files may require increasing thread count. Check if the output folder exists before running."

# 输入契约
inputs:
  reads:
    type: file
    format: [fastq, fastq.gz, fq, fq.gz]
    required: true
    description: "Input raw sequencing file in FASTQ format (gzipped supported)."
    cli_arg: "--input"
  threads:
    type: integer
    default: 2
    minimum: 1
    maximum: 16
    description: "Number of parallel processing threads."
    cli_arg: "--threads"

# 输出契约
outputs:
  html_report:
    type: file
    format: html
    path_pattern: "{outdir}/{basename}_fastqc.html"
    description: "Interactive HTML summary report."
  zip_data:
    type: file
    format: zip
    path_pattern: "{outdir}/{basename}_fastqc.zip"
    description: "Zipped raw data tables and images for MultiQC aggregation."

# 运行环境定义
environment:
  container:
    docker: "biocontainers/fastqc:v0.12.1_cv1"
    singularity: "docker://biocontainers/fastqc:v0.12.1_cv1"
  conda: "bioconda::fastqc=0.12.1"
  resources:
    default_cpus: 2
    default_mem_mb: 4096

# 自动化测试与执行规范
execution:
  entrypoint: "python main.py"
  test_command: "bash test/run_test.sh"
```

## 五、 Agent 接口自动生成协议（Agent Bridge）

为了让 AI Agent 能够零成本调取 Skill 库，无需手动为大模型编写 Function Call 代码，可以设计 `base.py` 提供自动转换机制，将 `meta.yaml` 直接转译为 OpenAI Tool Definition / JSON Schema。

### Agent Schema 导出逻辑机制

Python

```
# base.py 核心逻辑概念示范
import yaml
import json

def export_to_agent_tool(meta_path: str) -> dict:
    with open(meta_path) as f:
        meta = yaml.safe_load(f)
    
    properties = {}
    required = []
    
    for arg_name, arg_info in meta.get("inputs", {}).items():
        properties[arg_name] = {
            "type": arg_info["type"],
            "description": arg_info["description"]
        }
        if arg_info.get("required", False):
            required.append(arg_name)
            
    # 结合 agent_guidance 拼接极致的 Tool Description
    guidance = meta.get("agent_guidance", {})
    full_description = f"{meta['summary']}\n\nWHEN TO USE: {guidance.get('when_to_use', '')}\nCAUTION: {guidance.get('common_pitfalls', '')}"

    tool_def = {
        "type": "function",
        "function": {
            "name": meta["id"],
            "description": full_description,
            "parameters": {
                "type": "object",
                "properties": properties,
                "required": required
            }
        }
    }
    return tool_def
```

## 六、 规范化实施步骤与里程碑

```
阶段 1: 基础设施与 MVP (1-2周)
├── 制定注册表 CLI 校验脚本 (skill-cli)
├── 搭建 Base Schema 验证逻辑 (Pydantic / Cerberus)
└── 交付 8 个核心基础软件的 Native 版本

阶段 2: 交付标准测试套件与 CI/CD (2-3周)
├── 为所有 Skill 补充最小 test_data (<1MB)
├── 配置 GitHub Actions / Local CI 运行一键测试
└── 补充 Agent Guidance 提示词元数据

阶段 3: 生态扩展与 Agent 挂载 (长期)
├── 扩展单细胞、变异检测等高阶工具 (GATK, CellRanger)
├── 接入 LLM Agent (如 LangChain, AutoGen, 个人 Agent 框架)
└── 自动化将 Nextflow Modules / Snakemake Wrappers 转化为 Skill 模板
```

### 第一批归档核心软件清单（优先 Native 实现）

1. **基础 QC/质控**：`fastqc`, `fastp`, `multiqc`
2. **比对/ Alignment**：`bwa-mem2`, `hisat2`, `star`
3. **SAM/BAM 处理**：`samtools`
4. **VCF/变异处理**：`bcftools`
5. **定量分析**：`featurecounts`, `salmon`

## 七、 校验与集成自动化（CI/CD 规范）

为了保证技能库在后续多人开发或 Agent 频繁调用时“不崩溃”，增加自动化校验机制：

1. **Schema 合规性校验**：每个 `native/meta.yaml` 必须通过 `skill-cli validate` 测试（必须包含 `agent_guidance` 和合法的 `inputs/outputs`）。
2. **轻量自动化回归测试**：在 CI 或本地提交前自动触发 `bash test/run_test.sh`，确保代码与镜像处于 Ready 状态，运行时间严控在 10 秒以内。
3. **动态 Registry 生成**：不再手动维护根目录下的 `registry.yaml`，而是由 CLI 根据子目录下的 `meta.yaml` 自动扫描合成，保证单一事实来源（Single Source of Truth）。