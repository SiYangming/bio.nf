# sra-tools 软件模块

> 汇总说明：本 README 合并各实现（native/snakemake/nextflow）的用法；安装方式见下方各节，容器与 conda 环境信息记录于此。

***

## native 实现

# sra-tools / native — 自包含 SRA 数据获取驱动

NCBI SRA Toolkit 的本地自包含实现（`source_type: custom`、`type: native`），命令逻辑对应
`native/batch_prefetch.sh`（prefetch 下载）与
`batch_sra_to_fastq.sh` / `batch_sra_to_fastq_parallel.sh`（fastq-dump 转 FASTQ），
并补充官方推荐的高速版 fasterq-dump。

## 功能

三个子命令对应 bioconda sra-tools 包内的三个可执行：

| 子命令            | 可执行            | 作用                                                   |
| -------------- | -------------- | ---------------------------------------------------- |
| `prefetch`     | `prefetch`     | SRA accession → 本地 .sra（nanoseq 默认 `-f yes -t http`） |
| `fasterq-dump` | `fasterq-dump` | .sra → FASTQ（官方推荐高速版，`-e` 线程 / `-t` 临时目录）            |
| `fastq-dump`   | `fastq-dump`   | .sra → FASTQ（兼容旧版，nanoseq 脚本原用法 `--split-3 --gzip`）  |

## 用法

```bash
# CLI 直跑
python main.py prefetch SRR12345678 -O sra/ --threads 2
python main.py fasterq-dump sra/SRR12345678/SRR12345678.sra -O fastq/ --threads 8
python main.py fastq-dump sra/SRR12345678/SRR12345678.sra --split-3 --gzip -O fastq/

# Agent / Schema 自省
python main.py --schema
python main.py --list-commands
```

每个子命令支持 `--threads` / `--tmpdir` 运行期覆盖。

## 环境安装（官方镜像优先，不维护本地配方）

官方已维护（bioconda → quay.io/biocontainers → depot.galaxyproject.org），直接拉取官方镜像运行工具二进制；main.py 驱动在宿主机跑。

### 1. Conda（宿主机直跑 main.py / HPC 无 root）

```bash
mamba env create -f environment.yml   # name: sra-tools-native（含 prefetch/fasterq-dump/fastq-dump；配方见文末「Conda 环境」节）
conda activate sra-tools-native
```

### 2. Docker（官方镜像）

```bash
docker pull quay.io/biocontainers/sra-tools:3.4.1--2_linux_64
# 注意：必须 -u $(id -u):$(id -g) 挂载宿主用户，否则产物归 root
docker run --rm -u $(id -u):$(id -g) -v $PWD:/data -w /data \
    quay.io/biocontainers/sra-tools:3.4.1--2_linux_64 prefetch SRR12345678 -O sra/
```

### 3. Apptainer / Singularity

```bash
apptainer pull sra-tools.sif docker://quay.io/biocontainers/sra-tools:3.4.1--2_linux_64
apptainer run -B $PWD:/data -H /data sra-tools.sif fastq-dump \
    /data/sra/SRR12345678/SRR12345678.sra --split-3 --gzip -O /data/fastq/
```

## 测试

```bash
bash test/run_test.sh   # prefetch/dump 需要网络 + 真实 SRA，本脚本退化为 argv 构造验证
```

## 版本

* sra-tools latest（示例 pin 3.4.1，bioconda；包内可执行 prefetch / fasterq-dump / fastq-dump）

* 构建路线：官方镜像/conda 提供（quay.io/biocontainers/sra-tools / depot.galaxyproject.org；本地不再自建容器）

* 版本锚点对照：nf-core 子模块 pin sra-tools=3.2.1；snakemake-wrappers bio/sra-tools/fasterq-dump pin 3.4.1

## 历史留存

原始批处理脚本 `batch_prefetch.sh` / `batch_sra_to_fastq.sh` / `batch_sra_to_fastq_parallel.sh`（单一命令的批量循环：prefetch 下载 / fastq-dump 转 FASTQ，串行或 GNU parallel）保留于本模块 `native/`（硬编码项目路径，仅供追溯对照 / 一键运行，正式能力请走 `main.py` 的 prefetch / fasterq-dump / fastq-dump 原子子命令）。

***

## snakemake 实现

# sra-tools / snakemake / local — 自维护 Snakemake 规则

官方 `snakemake-wrappers` 的 `bio/sra-tools` 目前只有 `fasterq-dump` 一个 wrapper，
因此本目录为 prefetch（下载）与 fastq-dump / fasterq-dump（转换）提供自维护 rule，
作为 Snakemake 场景的**主执行路径**（`source_type: custom`、`type: snakemake_local`）。
td2 式：每 rule 一个 config 驱动 `.smk`，共用同目录 conda env `sra-tools.yaml`
（bioconda `sra-tools=3.4.1`）。

## 规则文件

- `sra_prefetch.smk` — `rule sra_prefetch`（下载）：`prefetch -f yes -t http -O <dir> <srr_id>`
- `sra_fastq_dump.smk` — `rule sra_fastq_dump`（转换）：`fastq-dump --split-3 --gzip -O <dir> <sra>`
- `sra_fasterq_dump.smk` — `rule sra_fasterq_dump`（高速转换）：`fasterq-dump <sra> --split-3 -O <dir> -e N -t <tmpdir>`（官方推荐高速版）
- `sra-tools.yaml` — conda env（bioconda `sra-tools=3.4.1`，提供 prefetch / fasterq-dump / fastq-dump）

去除 while 串行循环 / GNU parallel 外部依赖 / 绝对路径
（`./sratoolkit.3.2.0-centos_linux64/bin/`）；失败 SRR 列表由 Snakemake 的重试/日志机制覆盖，
不再写 `failed_*.txt`。dump 规则输出为 `directory()`——`--split-3` 的产物按文库布局命名
（SE 单文件 / PE `_1`/`_2`），无法静态预知文件名，详见两 .smk 头注。

## 用法（config 契约见各 .smk 头注与软件级 meta.yaml `snakemake_include_hint`）

```python
# Snakefile 中（按需 include）
include: "modules/sra-tools/snakemake/sra_prefetch.smk"
include: "modules/sra-tools/snakemake/sra_fastq_dump.smk"
include: "modules/sra-tools/snakemake/sra_fasterq_dump.smk"

rule all:
    input: config["sra_prefetch_sra"]   # 或 sra_dump_dir（转换产物目录）
```

```bash
# 独立运行
snakemake -s modules/sra-tools/snakemake/sra_prefetch.smk \
    --config sra_srr_id=SRR12345678 sra_outdir=sra_out --cores 2 --use-conda
snakemake -s modules/sra-tools/snakemake/sra_fastq_dump.smk \
    --config sra_input_sra=sra_out/SRR12345678/SRR12345678.sra --cores 4 --use-conda
```

## 依赖环境

conda env 文件同目录 `sra-tools.yaml`（`conda:` 相对 .smk 目录解析，`--use-conda` 时自动创建）：

```yaml
# snakemake/sra-tools.yaml
name: sra-tools
channels: [conda-forge, bioconda, defaults]
dependencies:
  - bioconda::sra-tools==3.4.1
```

## 与其它实现的关系

- `fasterq-dump` 场景也可直接切到官方 wrapper：`wrapper: "v3.13.0/bio/sra-tools/fasterq-dump"`
- 非 Snakemake 场景（独立 CLI / Agent Function Calling）请走 `../../native/`

***

## Conda 环境（原 native/environment.yml）

```yaml
# sra-tools native Conda 环境配方
# 创建：mamba env create -f environment.yml
# 说明：sra-tools 不在 Debian bookworm apt；本文件是 Conda 兜底（HPC 无 root / 离线场景）。
#      官方镜像（quay.io/biocontainers/sra-tools）即由 bioconda 本环境构建；本地不再自建 Dockerfile/Apptainer.def（见上「环境安装」）。
name: sra-tools-native
channels:
  - conda-forge
  - bioconda
dependencies:
  - python=3.11
  - sra-tools=3.4.1    # 提供 prefetch / fasterq-dump / fastq-dump
  - pyyaml>=6.0
  - pip
```

## 容器与 Conda 链接

* **Bioconda 页面**：<https://anaconda.org/channels/bioconda/packages/sra-tools/overview>

* **Docker**：`docker pull quay.io/biocontainers/sra-tools:3.4.1--2_linux_64`

* **Singularity**：<https://depot.galaxyproject.org/singularity/sra-tools%3A3.4.1--2_linux_64>

* 安装方式（本地）：`mamba create -n sra-tools -c conda-forge -c bioconda sra-tools=3.4.1`

