# lima 软件模块

> 汇总说明：本 README 合并各实现（native/snakemake/nextflow）的用法；安装方式见下方各节，容器与 conda 环境信息记录于此。

---

## native 实现

# lima / native — 自包含驱动

PacBio **条形码拆分与引物去除**的本地自包含实现（`source_type: custom`、`type: native`）。
二进制名与 conda 包名均为 **`lima`**。

## 功能

- `lima <reads> <primers> <out>`：去引物 / 按条形码拆分（reads 支持 bam/fasta/fasta.gz/fastq/fastq.gz）
- 输出扩展名按输入格式自动推断（bam→bam、fastq.gz→fastq.gz …）
- Iso-Seq 模式：`--isoseq` / `--peek-guess`
- 质量阈值：`--min-score`
- 报告产物：`.counts` / `.report` / `.summary` / `.json` / `.xml` / `.clips`（与输出同前缀）
- 自动注入线程（`-j`）与 `TMPDIR`

## 用法

```bash
# CLI 直跑
python main.py lima reads.bam primers.fasta out/demux.bam --isoseq --threads 8

# Agent / Schema 自省
python main.py --schema
python main.py --list-commands
```

子命令 `lima` 支持 `--threads` / `--tmpdir` 运行期覆盖。

## 环境安装（三选一）

### 1. Conda（HPC 无 root / 离线兜底）

```bash
mamba env create -f environment.yml   # name: lima-native
conda activate lima-native
```

### 2. Docker（官方镜像直拉，不维护本地 Dockerfile）

```bash
docker pull quay.io/biocontainers/lima:<tag>        # tag 见 quay 页面（或文末「容器与 Conda 链接」）
# 注意：必须 -u $(id -u):$(id -g) 挂载宿主用户，否则产物归 root
docker run --rm -u $(id -u):$(id -g) -v $PWD:/data quay.io/biocontainers/lima:<tag> \
    lima --isoseq /data/reads.bam /data/primers.fasta /data/demux.bam
```

### 3. Apptainer / Singularity（官方镜像直拉，不维护本地 Apptainer.def）

```bash
apptainer pull lima.sif docker://quay.io/biocontainers/lima:<tag>
# 或直链 depot.galaxyproject.org/singularity/lima%3A<tag>（与 quay 同 build tag）
apptainer run -B $PWD:/data -H /data lima.sif \
    lima --isoseq /data/reads.bam /data/primers.fasta /data/demux.bam
```

> 官方镜像内为原生 lima 入口（仅工具，无 main.py）；需要 Schema/自省/参数注入时在**宿主机**（已装 lima 或 conda env）运行 `python main.py lima ...`。

## 测试

```bash
bash test/run_test.sh   # 合成最小 BAM；lima 未安装时退化为 argv 构造验证
```

## 版本

- lima 2.9.0（bioconda::lima=2.9.0，由官方镜像/conda 提供：quay.io/biocontainers/lima、bioconda lima=2.9.0）
- 构建路线：official biocontainer（quay.io/biocontainers/lima / depot.galaxyproject.org）；本地不再自建容器

## 历史留存

供追溯对照的原始实现脚本与 `main.py` 同存于 `native/`，**正式入口为 `main.py`**。

- `lima_analysis.py`


---

## snakemake 实现

# lima / snakemake / local — 自维护 Snakemake 规则（td2 式）

官方 `snakemake-wrappers` 无 `bio/lima`（抓取 404），因此本目录提供自维护 rule，
作为 Snakemake 场景的**主执行路径**（`source_type: custom`、`type: snakemake_local`），td2 式布局：
**每 rule 一个 config 驱动 `.smk`**（lima 仅一个子命令 → 单规则文件）。

### 本地规则（td2 式：config 驱动、可独立运行）

| 文件 | 规则 | 作用 | 执行指令 |
|------|------|------|----------|
| `snakemake/lima.smk` | `lima` | reads BAM + 引物 FASTA → 去引物/拆分 BAM（含 `.pbi` / `.lima.report` / `.lima.summary` / `.lima.counts`） | `script:`（lima.py） |

- 配套文件（平铺 `snakemake/`，`.smk` 同目录相对引用）：`lima.yaml`（conda env：`bioconda::lima=2.9.0`）、`lima.py`（wrapper）。
  lima 为单条命令、无搬运/条件分支逻辑，docker/native/conda 三模式统一走同目录 wrapper `lima.py`
  （分派经共享 `modules/docker_wrapper.py` 的 `docker_wrapper_binary(config, "lima", "lima_bin", "lima")`，
  参考 `modules/samtools/snakemake/samtools_sort.py`）。
- 规则 **config 驱动、不依赖流程 `SAMPLES` / `{sample}` / `chunk` 目录层级**，config 契约见 `.smk` 头注（
  `lima_input_reads` / `lima_input_primers` 必填；`lima_output` 默认 `<输入去扩展名>.demux.bam`；
  `exec_mode` 默认 conda，docker/native 需在 config.yaml 预设 `lima.docker_image` / `lima.lima_bin`；
  `lima.extra_params` 透传，Iso-Seq 建议 `--isoseq --peek-guess`；`threads` 默认 8）。独立运行示例：

```bash
snakemake -s modules/lima/snakemake/lima.smk \
    --config lima_input_reads=sample.reads.bam lima_input_primers=primers.fasta \
    lima_output=demux/sample.demux.bam 'lima.extra_params=--isoseq --peek-guess' \
    --cores 8 --use-conda
```

- 流程内使用：`include: "modules/lima/snakemake/lima.smk"` 后在 `rule all` 引用 `config["lima_output"]`；
  与 `pbccs.smk` 串接时令 `lima_input_reads` == ccs 产物即自动建立依赖。
- 产物命名（BAM 主路径）：`<out>`（拆分 reads）与同目录 `<out>.pbi`、`<stem>.lima.{report,summary,counts}`
  （官方 prefix = 输出去扩展名）；`.lima.clips` / `.removed.bam` 等 side-product 按参数产生、非规则 output。
- 规则为 config 驱动单文件（无 `ccs/{sample}/{sample}.chunk{n}.bam` 模板依赖）；`conda:` 用同目录
  相对名 `"lima.yaml"`，无 `envs/` / `scripts/` 幽灵引用。

### 与其它实现的关系

- 官方 wrapper 若未来出现（重新抓取 `bio/lima` 有目录），可切换回官方 `wrapper:` 句柄登记层
  （软件级 meta.yaml 的 `lima_snakemake_wrappers` 条目；官方说明层不建本地目录）
- 非 Snakemake 场景（独立 CLI / Agent Function Calling / FASTA·FASTQ 输入）请走 `../../native/`
  （`python main.py lima ...`，输出扩展名随输入推断）


---

## Conda 环境（离线 / 非容器兜底备选）

```yaml
# lima native Conda 环境配方
# 创建：mamba env create -f environment.yml
# 说明：lima 不在 Debian bookworm apt；本文件是 Conda 兜底（HPC 无 root / 离线场景）。
#      容器默认路线：官方镜像优先（quay.io/biocontainers/lima），不再维护 Dockerfile/Apptainer.def。
name: lima-native
channels:
  - conda-forge
  - bioconda
dependencies:
  - python=3.11
  - lima=2.9.0
  - pyyaml>=6.0
  - pip
```

## 容器与 Conda 链接

- **Bioconda 页面**：https://anaconda.org/channels/bioconda/packages/lima/overview
- **Docker**：`docker pull quay.io/biocontainers/lima:2.13.0--h9ee0642_0`
- **Singularity**：https://depot.galaxyproject.org/singularity/lima%3A2.13.0--h9ee0642_0
- 安装方式（本地）：`mamba create -n lima -c conda-forge -c bioconda lima=2.13.0`
