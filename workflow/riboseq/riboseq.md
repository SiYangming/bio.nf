# workflow/riboseq — 核糖体足迹（Ribo-seq / RPF）+ 总 RNA 测序复合流程

核糖体足迹（Ribosome Profiling）分析流程：同时处理 **RPFs（核糖体保护片段，Ribosome Protected Footprints）** 与配套的**总 RNA 测序（Total RNA-seq）**，用于翻译组定量、差异表达与翻译效率（TE）分析、密码子占据率统计及周期性质控。

* 元数据：同级 [meta.yaml](meta.yaml)（stages / inputs / outputs / software\_versions）。

* 本流程为**目录形态**（因含 `native/` 经典完整实现脚本，目录保留）。

## 原始来源与致谢

* **上游原始出处**：[Bushell-lab/Ribo-seq](https://github.com/Bushell-lab/Ribo-seq) —— 经典 Shell + Python + R 流程（RPFs + Totals）的原始作者仓库，native/ 脚本由此整理而来。

* **Snakemake 执行形态**：见本文档「执行方式 B」（本 workflow 不内置 `snakemake/` 目录，集成文件在项目内按需重建）。

* **官方 nf-core 流程参考**：[nf-core/riboseq](https://github.com/nf-core/riboseq) —— 官方已有完整流程，按规则**不建** **`nextflow/`** **目录**，仅在本文档登记引用（见「执行方式 C」）。

## 目录结构

```
workflow/riboseq/
├── meta.yaml            # 流程级元数据（stages / inputs / outputs / software_versions）
├── riboseq.md           # 本文件：总览 + 执行方式 + Snakemake 集成说明
└── native/              # 【经典实现】Shell/Python/R 脚本（唯一副本；完整运行指南见 native/README.md）
    ├── run.sh           # 一键编排入口（Conda / Local 两种模式）
    ├── main.py          # 流程编排入口（--pipeline/--list-stages/--dry-run/--real；逻辑由本库 Shell/Python/R 脚本提取）
    ├── README.md        # 运行指南：测试数据、参考数据、依赖安装、环境配置、参数、运行顺序、GSEA 来源
    ├── RNAseq_env.yml / RiboSeq_env.yml / R_analysis_env.yml   # 配套 Conda 环境定义
    ├── Shell_scripts/   # 数据准备（Data_Preparation）、Totals/RPFs 主线、Downstream 下游、索引构建与公共变量
    ├── Python_scripts/  # GENCODE 过滤/重格式化 + RPF 计数与区域统计脚本
    └── R_scripts/       # DESeq2 / QC / meta_plots / gsea / feature_properties / codon_occupancy
```

> 测试数据（fastq 获取方式）与参考数据（chr20 fa/gtf、rsem\_index、tRNA/rRNA 库）的说明见 [native/README.md](native/README.md)（§1 测试数据 / §2 参考数据），本文件不重复。

## 三种执行方式

### A. 经典脚本（native/，人工分步或一键编排）

```bash
cd workflow/riboseq/native
bash run.sh                 # 一键编排（默认 Conda 模式；--help 查看参数与命令示例）
```

也可用统一编排入口 [native/main.py](native/main.py)（逻辑由 Shell\_scripts / Python\_scripts / R\_scripts 提取，dry-run 预览 / real 执行）：

```bash
python native/main.py --list-stages                             # 查看各 pipeline 与单步脚本
python native/main.py --pipeline RPFs --dry-run                  # 预览 RPFs 链（默认）
python native/main.py --pipeline Totals --real --env-mode conda  # 真实执行（需先配好环境/数据）
python native/main.py --pipeline Downstream --step Downstream_2_DESeq2.sh --dry-run  # 单步
```

也可手动分步：先按实验修改 `Shell_scripts/common_variables.sh`，执行 `makeDirs.sh` 建目录，再按 `Totals_*` / `RPFs_*` 顺序逐脚本运行，最后用 `R_scripts/` 做下游分析。**测试数据、参考数据、依赖与环境的完整说明见** **[native/README.md](native/README.md)。**

**UMI 环节（extract → 比对 → dedup）可复用** **[subworkflow/umi\_tools\_extract\_dedup](../../../subworkflow/umi_tools_extract_dedup/umi_tools_extract_dedup.md)**：经典 `RPFs_2_extract_UMIs.sh` / `RPFs_4_deduplication.sh` / `Totals_2/4a/4b_*.sh` 是该阶段在 Shell 侧的等价实现（直接调 umi\_tools）；需要统一编排时可改用其 native 编排入口（委托 `modules/umi_tools/native/main.py`，RPF 链用 regex 模式，见上）：

```bash
python ../../../subworkflow/umi_tools_extract_dedup/native/main.py --sample-id {sample} \
    --reads-r1 fastq/{sample}_cutadapt.fastq.gz \
    --bc-pattern '^(?P<umi_1>.{4}).+(?P<umi_2>.{4})$' --extract-method regex \
    --aligned-bam alignment_results_bam/sorted_bam/{sample}_pc_sorted.bam --stats
```

### B. Snakemake（按需在项目内重建；仓库不再内置 snakemake/ 目录）

本 workflow 不内置 `snakemake/` 集成层；Snakefile / common.smk / utils.smk / config.yaml / config.schema.yaml / samples.schema.yaml 的文件要点见下。需要 Snakemake 执行时，在**项目目录**内重建集成层：

1. 建立项目目录并放置流程集成文件（Snakefile 主文件 + `common.smk` + `utils.smk` + `config.yaml` + 两个 schema）：

   * `Snakefile`：`configfile: "config.yaml"`，`include: "common.smk"`、`include: "utils.smk"`，再按顺序 `include:` 各原子模块规则（模块内路径相对仓库）——`../../../modules/{fastqc,cutadapt,umi_tools,bowtie2,star,bbmap,samtools,rsem}/snakemake/*.smk`（注意 include 顺序与上下文依赖：config.paths / config.containers / samples / is\_pe / get\_config\_by\_path 等在 common.smk 建立，不可颠倒），并以 `rule all` 聚合输出目标；UMI 的 extract/dedup 规则亦可改经 `include: "../../../subworkflow/umi_tools_extract_dedup/snakemake/umi_tools_extract_dedup.smk"` 聚合引入（该文件已 include umi\_tools 三个单规则 smk）；若采用聚合方式，请从上方 glob 中移除 `umi_tools`，避免规则重复定义；

   * `common.smk`：样本表解析（`samplesheet_local.csv`）、wildcard constraints、线程计算、config 格式化；

   * `utils.smk`：流程级规则辅助函数；

   * `config.yaml`：全流程参数（protocol / 样本表 / 输出目录 / 各工具版本与 docker 镜像 / UMI 模式 / 参考路径；`exec_mode: docker|conda|apptainer`）；

   * `config.schema.yaml` / `samples.schema.yaml`：`validate()` 用 schema。
2. 各工具规则在 `modules/<sw>/snakemake/` 下维护（规则自带同目录 `conda: "*.yaml"` 与 `container:`），Snakefile 通过 `include:` 引用；独立部署时请**一并携带**相关模块的 `snakemake/` 目录（各 wrapper 经 sys.path 注入引用共享的 `modules/docker_wrapper.py`，亦需一并携带），或改用官方 `wrapper:` 句柄。
3. 数据流：

```
fastqc ─┬─> cutadapt ─> umi_tools extract ─┬─> riboseq: bbmap rRNA→tRNA→转录组 ─> umi_tools dedup ─> samtools sort/index
        │                                  ├─> rnaseq: bowtie2 转录组 ──────────> umi_tools dedup ─> RSEM 定量
        │                                  └─> rnaseq: STAR 基因组（可选）──────> umi_tools dedup
```

1. 运行（执行入口为仓库共享 [scripts/run\_smk.sh](../../scripts/run_smk.sh)）：

```bash
cd project/snakemake
bash <repo>/scripts/run_smk.sh -n          # dry-run（预演）
bash <repo>/scripts/run_smk.sh             # 执行（默认 docker；exec_mode 可切 conda/apptainer）
```

### C. 官方 nf-core/riboseq（引用官方流程，不在本仓库自建目录）

Ribo-seq 的 **Nextflow 官方实现已存在**（[nf-core/riboseq](https://github.com/nf-core/riboseq)），按本仓库「官方已有流程不单独构建目录」规则，不再为其建 `nextflow/` 文件夹，仅在本文档登记引用与差异：

* **官方流程**：[nf-core/riboseq](https://github.com/nf-core/riboseq) —— 高度模块化、物种无关，支持 UMI 与 TE（Ribo-seq + RNA-seq + tiseq）；主要使用 nf-core modules：fastp/TrimGalore、fastqc、STAR、Salmon、SortMeRNA/bbsplit、ribowaltz、ribotish、ribotricer、anota2seq、multiqc；

* **测试数据**：[nf-core/test-datasets](https://github.com/nf-core/test-datasets/tree/riboseq)（`riboseq` 分支）；

* **运行方式**：`nextflow run nf-core/riboseq -profile test,docker`（详见官方 docs/usage.md）；

* **各实现定位**：`native/`（经典脚本，本仓库维护）为唯一本地实现；Nextflow 直接走官方，缺失/需定制时再自建（此时才建 `nextflow/` 目录，参考各模块 `nextflow/local` 组装）。

> **通用规则**：官方已有的流程 / 软件实现不单独建目录（信息并入流程或模块的 README/meta 登记引用）；只有官方不存在的**自定义**实现才建目录。

## 依赖的原子模块（modules/）

| 工具        | 模块                  | 用途                               |
| --------- | ------------------- | -------------------------------- |
| FastQC    | `modules/fastqc`    | 原始与中间读段质控                        |
| cutadapt  | `modules/cutadapt`  | 3' 接头去除 + 质控剪切 + 长度过滤            |
| UMI-tools | `modules/umi_tools` | UMI 提取（string / regex 两种模式）与去重   |
| Bowtie2   | `modules/bowtie2`   | 总 RNA 测序转录组比对（兼容 RSEM 索引）        |
| STAR      | `modules/star`      | 可选：总 RNA 测序基因组比对                 |
| BBMap     | `modules/bbmap`     | Ribo-seq 分步比对（rRNA → tRNA → 转录组） |
| Samtools  | `modules/samtools`  | BAM 排序 / 索引 / 格式转换               |
| RSEM      | `modules/rsem`      | 总 RNA 测序基因/转录本定量                 |

各模块 native 容器与官方 wrapper（snakemake-wrappers / nf-core）的版本差异见对应 `modules/<sw>/meta.yaml` 的 software\_versions 段。

## 容器与执行注意

* docker 模式经共享 `modules/docker_wrapper.py`（docker\_run 含 `-u $(id -u):$(id -g)` 与 `$(pwd)` 挂载）；`docker run` 必须带 `-u` 参数。

* STAR 为可选（仅 IGV 可视化需要）；UMI 步骤在建库无 UMI 时可跳过。

