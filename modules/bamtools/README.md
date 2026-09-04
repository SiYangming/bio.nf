# bamtools 软件模块

> 汇总说明：本 README 合并各实现（native/snakemake/nextflow）的用法；安装方式见下方各节，容器与 conda 环境信息记录于此。

***

## native 实现

# bamtools / native

自包含的 bamtools 驱动实现（`source_type: custom`）。

## 能力

覆盖 bamtools 高频子命令，Iso-Seq 场景下 BAM → FASTA/FASTQ 转换首选：

| 子命令       | 说明                                             |
| --------- | ---------------------------------------------- |
| `convert` | BAM → fasta/fastq/sam/bed/json/pileup/yaml（核心） |
| `count`   | 统计 BAM 比对数量                                    |
| `stats`   | 输出 BAM 基本统计                                    |
| `header`  | 打印 BAM header                                  |
| `index`   | 建立 .bai 索引                                     |
| `sort`    | 按 region/name/size 排序 BAM                      |

## 快速开始

### 1. 安装环境

```bash
mamba env create -f environment.yml
conda activate bamtools-native
```

### 2. CLI 调用

```bash
python main.py convert --bam refine.bam --outdir flnc --format fasta --prefix sample
python main.py stats --bam refine.bam
python main.py sort --bam in.bam --out sorted.bam --threads 8
python main.py index --bam sorted.bam
```

### 3. Agent / Schema 自省

```bash
python main.py --schema              # 输出 JSON Schema
python main.py --list-commands       # 列出支持的子命令
python main.py convert --bam x.bam --dry-run   # 只打印构建出的命令
```

### 4. 容器运行（官方镜像优先，不维护本地配方）

官方已维护（bioconda → quay.io/biocontainers → depot.galaxyproject.org），直接拉取官方镜像运行工具二进制：

```bash
# Docker：工具直跑（官方镜像内只含 bamtools，main.py 驱动在宿主机运行）
docker pull quay.io/biocontainers/bamtools:<tag>        # tag 见 quay 页面
docker run --rm -u $(id -u):$(id -g) -v "$PWD":/data quay.io/biocontainers/bamtools:<tag> \
  convert -format fasta -in /data/refine.bam -out /data/sample.fasta

# Singularity/Apptainer
apptainer pull bamtools.sif docker://quay.io/biocontainers/bamtools:<tag>
# 或直链 depot.galaxyproject.org/singularity/bamtools%3A<tag>（与 quay 同 build tag）
```

> 容器内为原生工具入口；需要 Schema/自省/参数注入时在**宿主机**（已装 bamtools 或 conda env）运行 `python main.py <subcommand> ...`。

### 5. 测试

```bash
bash test/run_test.sh
```

测试数据由 `test/generate_data.py` 用纯 Python 标准库动态生成合法 BGZF/BAM，
不依赖 samtools/pysam。

## 版本说明

* **native 二进制**：`bamtools 2.5.2`，由**官方镜像/conda 提供**（quay.io/biocontainers/bamtools、bioconda bamtools=2.5.2；宿主机安装用 mamba/conda）。

* 与流程原配版本一致（`quay.io/biocontainers/bamtools:2.5.2--hdcf5f25_2`）；
  snakemake-wrappers 侧已 bump 到 2.5.3，2.5.x API 兼容。

## 性能优化约定

* **线程**：bamtools CLI 无通用 `-@` 参数，`--threads` 作为契约字段接收，
  并在 `optimization.per_subcommand_threads` 中给出 sort 8 线程的调度建议。

* **临时目录**：`--tmpdir` 可覆盖 `TMPDIR`；`sort` 中间文件写入 `$TMPDIR`。

* **内存**：通过 `meta.yaml.optimization.default_mem_mb` 声明，供上层调度器读取。

## 历史留存

BAM 转 FASTA/FASTQ 等能力由 `main.py convert` 覆盖（正式入口为 `main.py`）。

***

## snakemake 实现

# bamtools / snakemake / local — 自维护 Snakemake rule

td2 式单规则实现（config 驱动、自包含，不依赖 `workflow/lib/helpers.py`）；BAM 转换 + 写 `versions.yml` 属多步逻辑，用 `script:` + 同目录 wrapper（docker/native/conda 经共享 `modules/docker_wrapper.py` 解析）。

## 文件

| 文件                     | 作用                                                                   |
| ---------------------- | -------------------------------------------------------------------- |
| `bamtools_convert.smk` | 单规则：`bamtools convert -format <fmt> -in <bam> -out <out>`（config 驱动） |
| `bamtools_convert.py`  | wrapper（两级注入 `modules/`；docker/native/conda 三模式 + 写 versions.yml）    |
| `bamtools.yaml`        | conda env（bioconda `bamtools=2.5.2`，与 native 版本锚点一致）                 |

## 使用（config 契约见 bamtools\_convert.smk 头注与软件级 meta.yaml `snakemake_include_hint`）

在 Snakefile 中：

```python
include: "modules/bamtools/snakemake/bamtools_convert.smk"

rule all:
    input: config["bamtools_output"]   # 输出：<outdir>/<BAM 名>.<format> + .versions.yml
```

独立运行：

```bash
snakemake -s modules/bamtools/snakemake/bamtools_convert.smk \
    --config bamtools_input_bam=refine.bam --cores 2 --use-conda
```

可选 `config["bamtools"]`（缺省自动跳过；`exec_mode` 支持 conda/docker/native）：

```yaml
# config.yaml
exec_mode: conda
bamtools:
  format: "fastq"          # convert 目标格式（默认 fasta）
  extra_params: ""         # 透传附加参数
```

## 规则设计说明

* docker/native 模式由 wrapper 的 `docker_wrapper` 分派（无需流程级 `BAMTOOLS_DOCKER_IMAGE` 配置）；
  输入路径用显式 config 键 `bamtools_input_bam`（无固定 `results/refine/{sample}/{sample}.chunk{n}.bam` 模板）。

* `bamtools.bin` / `format` 由 `config["bamtools"]` 读取并内联默认值：

  * `bamtools_bin: "bamtools"`、`format: "fasta"`

* 规则写 `versions.yml`（与 nf-core 模块风格一致）。

***

## Conda 环境（离线 / 非容器兜底备选）

```yaml
# bamtools native Conda 环境配方
# 创建：mamba env create -f environment.yml
# 说明：容器走官方镜像（quay.io/biocontainers/bamtools），不再维护本地配方；
#      本文件仅作 HPC 无 root 场景 / 非容器场景的 Conda 兜底。
name: bamtools-native
channels:
  - conda-forge
  - bioconda
dependencies:
  - python=3.11
  - bamtools=2.5.2
  - pyyaml>=6.0
  - pip
```

## 容器与 Conda 链接

* **Bioconda 页面**：<https://anaconda.org/channels/bioconda/packages/bamtools/overview>

* **Docker（最新）**：`docker pull quay.io/biocontainers/bamtools:2.5.3--he132191_0`

* **Singularity（最新）**：<https://depot.galaxyproject.org/singularity/bamtools%3A2.5.3--he132191_0>

* 安装方式（本地）：`mamba create -n bamtools -c conda-forge -c bioconda bamtools=2.5.3`

* 注：流程原配版本见上文（bamtools 历史版本），本链接为 bioconda 最新容器。

