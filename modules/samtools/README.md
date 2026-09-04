# samtools 软件模块

> 汇总说明：本 README 合并各实现（native/snakemake/nextflow）的用法；安装方式见下方各节，容器与 conda 环境信息记录于此。

***

## native 实现

# samtools / native

自包含的 samtools 驱动实现（`source_type: custom`）。

## 能力

覆盖 samtools 高频子命令，自动注入线程与临时目录优化：

| 子命令          | 说明                 | 线程 |
| ------------ | ------------------ | -- |
| `view`       | SAM/BAM/CRAM 互转与过滤 | ✅  |
| `sort`       | 坐标 / read name 排序  | ✅  |
| `index`      | 建立 bai/csi 索引      | —  |
| `flagstat`   | flag 统计            | —  |
| `idxstats`   | 按参考序列统计            | —  |
| `stats`      | 全量统计报告             | —  |
| `depth`      | 测序深度               | —  |
| `mpileup`    | pileup 生成          | ✅  |
| `faidx`      | FASTA 索引           | —  |
| `merge`      | 合并 BAM             | ✅  |
| `quickcheck` | 完整性校验              | —  |

## 快速开始

### 1. 安装环境

```bash
mamba env create -f environment.yml
conda activate samtools-native
```

### 2. CLI 调用

```bash
python main.py view -bS input.sam -o out.bam --threads 8
python main.py sort input.bam -o sorted.bam --threads 8
python main.py index sorted.bam
python main.py flagstat sorted.bam
python main.py faidx refs.fa
```

### 3. Agent / Schema 自省

```bash
python main.py --schema              # 输出 JSON Schema
python main.py --list-commands       # 列出支持的子命令
```

### 4. 容器运行（官方镜像优先，不维护本地配方）

官方已维护（bioconda → quay.io/biocontainers → depot.galaxyproject.org），直接拉取官方镜像运行工具二进制：

```bash
# Docker：工具直跑（官方镜像内只含 samtools，main.py 驱动在宿主机运行）
docker pull quay.io/biocontainers/samtools:1.21--h96c455f_1        # tag 见 quay 页面
docker run --rm -u $(id -u):$(id -g) -v "$PWD":/data quay.io/biocontainers/samtools:1.21--h96c455f_1 \
  sort /data/input.bam -o /data/sorted.bam --threads 8

# Singularity/Apptainer
apptainer pull samtools.sif docker://quay.io/biocontainers/samtools:1.21--h96c455f_1
# 或直链 depot.galaxyproject.org/singularity/samtools%3A1.21--h96c455f_1（与 quay 同 build tag）
```

> 容器内为原生工具入口；需要 Schema/自省/参数注入时在**宿主机**（conda env 装 samtools）运行 `python main.py <subcommand> ...`。

### 5. 测试

```bash
bash test/run_test.sh
```

## 性能优化约定

* **线程**：`sort` 默认 8 线程（CPU 密集），其他默认 4；用户显式 `--threads` 永远优先。

* **临时目录**：`sort` 自动使用 `$TMPDIR` 下的临时前缀，避免污染工作目录。

* **内存**：通过 `meta.yaml.optimization.default_mem_mb` 声明，供上层调度器读取。

***

## snakemake 实现

# samtools / snakemake（本地规则 + 官方 wrappers 参考）

> 本目录为 snakemake-wrappers 缺失或需要本地定制时的 **Snakemake 自维护 rule**（`source_type: custom`、`type: snakemake_local`），td2 式布局：**每 rule 一个 config 驱动** **`.smk`**。

### 本地拆分规则（td2 式：每 rule 一个 .smk，config 驱动）

| 文件                                  | 规则                    | 作用                                           | 执行指令                                 |
| ----------------------------------- | --------------------- | -------------------------------------------- | ------------------------------------ |
| `snakemake/samtools_sort.smk`       | `samtools_sort`       | BAM/SAM/CRAM → sorted BAM（内存均摊 + 输出目录内临时前缀）  | `script:`（samtools\_sort.py）         |
| `snakemake/samtools_index.smk`      | `samtools_index`      | sorted BAM → `.bai` 索引                       | `script:`（samtools\_index.py）        |
| `snakemake/samtools_view.smk`       | `samtools_view`       | FLAG/MAPQ/region 过滤或格式转换                     | `script:`（samtools\_view\.py）        |
| `snakemake/samtools_sam_to_bam.smk` | `samtools_sam_to_bam` | SAM → BAM（`samtools view -b`，temp 中间产物）      | `script:`（samtools\_sam\_to\_bam.py） |
| `snakemake/samtools_flagstat.smk`   | `samtools_flagstat`   | BAM → flagstat 统计文本                          | `script:`（samtools\_flagstat.py）     |
| `snakemake/alignment_summary.smk`   | `alignment_summary`   | 多 flagstat → Sample/Total/Mapped/Rate 汇总 TSV | `script:`（alignment\_summary.py）     |

* 配套文件（平铺 `snakemake/`，`.smk` 同目录相对引用）：`samtools.yaml`（conda env）、5 个规则 wrapper `samtools_sort.py` / `samtools_index.py` / `samtools_view.py` / `samtools_sam_to_bam.py` / `samtools_flagstat.py`（单命令规则，经两级 `sys.path` 注入共享 `modules/docker_wrapper.py`，按 `config exec_mode` 做 docker/native/conda 三模式分派：docker 用镜像内 samtools（`samtools.docker_image`）、native 用 `samtools.samtools_bin`、conda 走 PATH）与 `alignment_summary.py`（有解析逻辑的 helper）。

* 规则 **config 驱动、可独立运行**（不依赖流程 `samples` / `config["paths"]` / `SAMPLES`），契约见各 `.smk` 头注。独立运行示例：

  ```bash
  snakemake -s modules/samtools/snakemake/samtools_sort.smk \
      --config samtools_sort_input=aln.sam samtools_sort_output=aln.sorted.bam --cores 8 --use-conda
  ```

* 串联：include `samtools_sort.smk` + `samtools_index.smk` 并令 `samtools_index_input == samtools_sort_output` 即自动建立 sort→index 依赖；批量 flagstat 汇总在流程内赋值 `config["alignment_summary_flagstats"] = [...]` 后 include `alignment_summary.smk`。

* samtools 子命令规则（`sort` / `index` / `view` / `sam_to_bam` / `flagstat` / `alignment_summary`）按上述单规则文件组织（无 `scripts/`、`envs/`、`../` 幽灵引用）。

### 官方 snakemake-wrappers（说明层，运行时靠 `wrapper:` 句柄解析）

> 本模块**不重写官方 wrapper 源码**。官方仓库 `bio/samtools/` 提供 sort/index/view/flagstat 等 wrapper（软件级 `software_versions.samtools_snakemake_wrappers` 记录 `wrapper_tag`、samtools pin 与差异）；离线/私有环境缺失或需本地定制时用上方 `snakemake/samtools_*.smk` 本地规则兜底。

***

## Conda 环境（离线 / 非容器兜底备选）

```yaml
# samtools native Conda 环境配方
# 创建：mamba env create -f environment.yml
name: samtools-native
channels:
  - conda-forge
  - bioconda
dependencies:
  - python=3.11
  - samtools=1.21
  - htslib=1.21
  - pyyaml>=6.0
  - pip
  - pip:
      - -e .  # 若把 native/ 打包为可安装包（可选）
```

## 容器与 Conda 链接

* **Bioconda 页面**：<https://anaconda.org/channels/bioconda/packages/samtools/overview>

* **Docker**：`docker pull quay.io/biocontainers/samtools:1.21--h96c455f_1`

* **Singularity**：<https://depot.galaxyproject.org/singularity/samtools%3A1.21--h96c455f_1>

* 安装方式（本地）：`mamba create -n samtools -c conda-forge -c bioconda samtools=1.21`

