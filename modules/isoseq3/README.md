# isoseq3 软件模块

> 汇总说明：本 README 合并各实现（native/snakemake/nextflow）的用法；安装方式见下方各节，容器与 conda 环境信息记录于此。

---

## native 实现

# isoseq3 / native — 自包含 isoseq3 refine 驱动

PacBio **IsoSeq3 refine**（去 polyA 尾与人工连接体）的本地自包含实现
（`source_type: custom`、`type: native`）。
> ⚠️ 命名差异：bioconda 包名为 **`isoseq`**，可执行二进制为 **`isoseq3`**
> （PacBio IsoSeq 套件入口，内含 refine / cluster / polish 等子命令）。本技能聚焦 `refine`。

## 功能

- `isoseq3 refine <bam> <primers> <out.bam>`：lima 产物 → 精炼 reads（polyA 修剪、去连接体）
- 默认 `--require-polya`（可用 `--no-require-polya` 关闭）
- `--min-polya-length`：polyA 尾最小长度
- 自动注入线程（`-j`，与 `--num-threads` 等价）
- 报告：`.consensusreadset.xml` / `.filter_summary.report.json` / `.report.csv` / `.pbi`（与输出同前缀）

## 用法

```bash
# CLI 直跑
python main.py refine --bam in.bam --primers primers.fasta --outdir out --prefix sample --threads 8

# Agent / Schema 自省
python main.py --schema
python main.py --list-commands
```

子命令 `refine` 支持 `--threads` / `--tmpdir` 运行期覆盖。

## 环境安装（三选一）

### 1. Conda（HPC 无 root / 离线兜底）

```bash
mamba env create -f environment.yml   # name: isoseq3-native
conda activate isoseq3-native
```

### 2. Docker（官方镜像直拉，不维护本地 Dockerfile）

```bash
docker pull quay.io/biocontainers/isoseq3:<tag>        # tag 见 quay 页面（或文末「容器与 Conda 链接」）
# 注意：必须 -u $(id -u):$(id -g) 挂载宿主用户，否则产物归 root
docker run --rm -u $(id -u):$(id -g) -v $PWD:/data quay.io/biocontainers/isoseq3:<tag> \
    isoseq3 refine -j 8 /data/in.bam /data/primers.fasta /data/out.bam
```

### 3. Apptainer / Singularity（官方镜像直拉，不维护本地 Apptainer.def）

```bash
apptainer pull isoseq3.sif docker://quay.io/biocontainers/isoseq3:<tag>
# 或直链 depot.galaxyproject.org/singularity/isoseq3%3A<tag>（与 quay 同 build tag）
apptainer run -B $PWD:/data -H /data isoseq3.sif \
    isoseq3 refine -j 8 /data/in.bam /data/primers.fasta /data/out.bam
```

> 官方镜像内为原生 isoseq3 入口（仅工具，无 main.py）；需要 Schema/自省/参数注入时在**宿主机**（已装 isoseq3 或 conda env）运行 `python main.py refine ...`。

## 测试

```bash
bash test/run_test.sh   # 合成最小 BAM；isoseq3 未安装时退化为 argv 构造验证
```

## 版本

- isoseq 4.0.0（bioconda::isoseq=4.0.0，binary `isoseq3`；由官方镜像/conda 提供，宿主机安装用 mamba/conda）
- 构建路线：official biocontainer（quay.io/biocontainers/isoseq3 / depot.galaxyproject.org，tag 见文末「容器与 Conda 链接」）；本地不再自建容器

## 历史留存（legacy/）

供追溯对照的原始实现脚本与 `main.py` 同存于 `native/`，**正式入口为 `main.py`**。

- `isoseq3_refine.py`


---

## snakemake 实现

# isoseq3 / snakemake / local — 自维护 Snakemake 规则（td2 式：每 rule 一个 config 驱动 .smk）

官方 `snakemake-wrappers` 无 `bio/isoseq3`（抓取 404），因此本目录提供自维护 rule，
作为 Snakemake 场景的**主执行路径**（`source_type: custom`、`type: snakemake_local`）。

### 本地拆分规则（td2 式：每 rule 一个 .smk，config 驱动）

| 文件 | 规则 | 作用 | 执行指令 |
|------|------|------|----------|
| `snakemake/isoseq3_refine.smk` | `isoseq3_refine` | lima 产物 BAM → 精炼 reads（去 polyA 尾与人工连接体；产物 `.bam` / `.pbi` / `.consensusreadset.xml` / `.filter_summary.report.json` / `.report.csv` 同前缀平铺） | `script:`（isoseq3_refine.py） |

- 配套文件（平铺 `snakemake/`，`.smk` 同目录相对引用）：`isoseq3.yaml`（conda env：`bioconda::isoseq=4.0.0`，提供二进制 `isoseq3`）、`isoseq3_refine.py`（wrapper）。
- 规则 **config 驱动、可独立运行**（不依赖流程 `SAMPLES` / `{sample}` 目录层级；输出前缀取自 `isoseq3_input_bam` 文件名去 `.bam`，可用 `isoseq3_prefix` 覆盖），契约见 `.smk` 头注。要点：
  - `isoseq3_input_bam`（必填输入）/ `isoseq3_primers`（必填引物 FASTA）/ `isoseq3_outdir`（默认 `isoseq3_out`）/ `isoseq3_prefix` / `threads`（默认 8）/ `exec_mode`（默认 conda）
  - 嵌套 `isoseq3.*`：`require_polya=true`（默认开启 → `--require-polya`）、`min_polya_length`（默认空 → 不传 `--min-polya-length`）、`extra_args`（透传）、`docker_image`（docker 模式）、`isoseq3_bin`（native 模式，默认 `isoseq3`）
- 独立运行示例：
  ```bash
  snakemake -s modules/isoseq3/snakemake/isoseq3_refine.smk \
      --config isoseq3_input_bam=lima/s1/s1.chunk1.bam isoseq3_primers=primers.fasta \
      --cores 8 --use-conda
  ```
- 流程内使用（输入为 lima 产物，可与 `pbccs` / lima 规则串联；单样本规则对每块输入各跑一次 refine）：
  ```python
  # Snakefile 中
  include: "modules/isoseq3/snakemake/isoseq3_refine.smk"
  # rule all:
  #     input: "isoseq3_out/s1.chunk1.bam"   # = <isoseq3_outdir>/<prefix>.bam（prefix 默认取 bam 名）
  ```
- 执行指令说明：refine 为**单条命令、无额外逻辑**（mkdir 仅建目录）→ 同目录 wrapper `isoseq3_refine.py`
  （docker/native/conda 三模式经共享 `modules/docker_wrapper.py` 的 `docker_wrapper_binary(config,
  "isoseq3", "isoseq3_bin", "isoseq3")` 分派）。`exec_mode` 默认 conda，docker/native 需在
  config.yaml 预设 `isoseq3.docker_image` / `isoseq3.isoseq3_bin`。
- 原聚合 `isoseq3.smk`（依赖 workflow 级 `envs/isoseq3.yaml` 与 `lima/{sample}/`、`logs/` 约定）已按上述单规则文件重新组织并删除；`envs/`、`logs/` 幽灵引用已消除。

## 与其它实现的关系

- 官方 wrapper 若未来出现（重新抓取 bio/isoseq3 有目录），可切换回 snakemake-wrappers 登记层（见 `meta.yaml` / `software_versions`）
- 非 Snakemake 场景（独立 CLI / Agent Function Calling）请走 `../../native/`



---

## Conda 环境（原 native/environment.yml）

```yaml
# isoseq3 native Conda 环境配方
# 创建：mamba env create -f environment.yml
# 说明：isoseq（PacBio IsoSeq 套件，binary isoseq3）不在 Debian bookworm apt；
#      本文件是 Conda 兜底（HPC 无 root / 离线场景）。
#      容器默认路线：官方镜像优先（quay.io/biocontainers/isoseq3），不再维护 Dockerfile/Apptainer.def。
name: isoseq3-native
channels:
  - conda-forge
  - bioconda
dependencies:
  - python=3.11
  - isoseq=4.0.0       # 提供二进制 isoseq3
  - pyyaml>=6.0
  - pip
```

## 容器与 Conda 链接

- **Bioconda 页面**：https://anaconda.org/channels/bioconda/packages/isoseq3/overview
- **Docker**：`docker pull quay.io/biocontainers/isoseq3:4.0.0--h9ee0642_0`
- **Singularity**：https://depot.galaxyproject.org/singularity/isoseq3%3A4.0.0--h9ee0642_0
- 安装方式（本地）：`mamba create -n isoseq3 -c conda-forge -c bioconda isoseq3=4.0.0`
