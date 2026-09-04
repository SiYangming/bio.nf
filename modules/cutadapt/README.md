# cutadapt 软件模块

> 汇总说明：本 README 合并各实现（native/snakemake）的用法；安装方式见下方各节，容器与 conda 环境信息记录于此。
> 官方实现（snakemake-wrappers / nf-core）在本仓库不建源码目录，其链接、submodules、版本差异记录在本 README 与软件级 `meta.yaml.software_versions`。

---

## native 实现

# cutadapt / native 自包含实现

基于 cutadapt CLI 的 Python 驱动包装（`source_type: custom`）。按 **cutadapt 实际 CLI** 暴露参数（`-a/-g/-b/-q/-m/-M/-o/-p/--cores/--nextseq-trim`），自动注入线程与临时目录：

| 子命令 | 说明 | 线程 |
|--------|------|------|
| `trim` | 通用 reads 裁剪：3'/5'/anywhere 接头（SE/PE）+ 质量修剪 + 长度过滤 | ✅（--cores） |
| `adapter-removal` | 纯接头去除快捷入口（只给接头序列即可） | ✅（--cores） |

- 运行时需本地安装 `cutadapt` 二进制：推荐 `mamba create -n cutadapt-native -c conda-forge -c bioconda cutadapt=5.2`
- 容器/conda 由**官方镜像**提供（quay.io/biocontainers/cutadapt / bioconda cutadapt=5.2；本地不再自建容器，native 记录版本 4.2-1 与 bioconda 5.2 的差异见 `meta.yaml.software_versions.cutadapt_native.note`）

## CLI 用法示例

```bash
# SE：去 3' adapter
python main.py trim -a AACCGGTT -o out.fastq in.fastq --threads 4

# PE：R1/R2 各自去 3' adapter
python main.py trim -a AGATCGGAAGAGC -A AGATCGGAAGAGC \
    -o out_R1.fastq.gz -p out_R2.fastq.gz in_R1.fastq.gz in_R2.fastq.gz --threads 8

# 5' adapter（锚定起始）+ 质量修剪 + 最短长度
python main.py trim -g '^ACACTCTTTCCCTACACG' -q 20 -m 30 \
    -o out.fastq in.fastq

# 纯接头去除（adapter-removal）
python main.py adapter-removal -a AACCGGTT -o out.fastq in.fastq

# Agent / Schema 自省
python main.py --schema              # 输出 JSON Schema
python main.py --list-commands       # 列出支持的子命令
```

## 容器运行（官方镜像优先，不维护本地配方）

官方已维护（bioconda → quay.io/biocontainers → depot.galaxyproject.org），直接拉取官方镜像运行工具二进制：

```bash
# Docker：工具直跑（官方镜像内只含 cutadapt，main.py 驱动在宿主机运行）
docker pull quay.io/biocontainers/cutadapt:<tag>        # tag 见文末「容器与 Conda 链接」（如 5.2--py312hfabe715_2）
docker run --rm -u $(id -u):$(id -g) -v "$PWD":/data quay.io/biocontainers/cutadapt:<tag> \
    cutadapt -a AACCGGTT -o /data/out.fastq /data/in.fastq

# Singularity/Apptainer
apptainer pull cutadapt.sif docker://quay.io/biocontainers/cutadapt:<tag>
# 或直链 depot.galaxyproject.org/singularity/cutadapt%3A<tag>（与 quay 同 build tag）
```

> 容器内为原生工具入口（cutadapt）；需要 Schema/自省/参数注入（trim / adapter-removal 子命令）时在**宿主机**（conda 装 cutadapt）运行 `python main.py <subcommand> ...`。

## 运行测试

```bash
bash test/run_test.sh
```

> 本机未装 cutadapt 时只跑驱动自省（`--list-commands` / `--schema`），脚本结尾 `ALL TESTS PASSED`。

---

## snakemake 实现

本模块 `snakemake/` 目录同时承担两件事，使用前请区分：

### 1) 官方 snakemake-wrappers（说明层登记，不写源码）

> ⚠️ **强提示**：官方 `bio/cutadapt` wrapper 仅在本仓库做**说明 + 版本登记**（见软件级 `meta.yaml.software_versions.cutadapt_snakemake_wrappers`），**没有**把官方 wrapper 源码复制到本目录。真正执行靠 Snakemake 运行时解析 `wrapper:` 句柄（自动从中央 wrapper 缓存解析）：
>
> ```snakefile
> rule cutadapt_se:
>     input: "reads/{sample}.fastq.gz"
>     output: "trimmed/{sample}.fastq.gz", "qc/{sample}.txt"
>     params: adapters="-a AACCGGTT", extra=""
>     threads: 4
>     wrapper: "v9.17.0/bio/cutadapt/se"
> ```
>
> 请**不要**将本目录 `scripts/cutadapt.py` 作为 `wrapper_path` 传给 Snakemake——它是 riboseq 流程拆分的本地规则脚本（见下节）。

**官方子模块清单**（2026-09 抓取 https://github.com/snakemake/snakemake-wrappers/tree/master/bio/cutadapt ）：

| 子模块 | 用途 | 官方 conda pin |
|--------|------|----------------|
| `se` | single-end reads 接头裁剪 | `cutadapt =5.2` |
| `pe` | paired-end reads 接头裁剪（-o/-p/-A） | `cutadapt =5.2` |

- 官方仓库：https://github.com/snakemake/snakemake-wrappers/tree/master/bio/cutadapt
- wrapper 无 `snakemake-wrapper-utils` 依赖（仅 `snakemake.shell`）；官方最新 tag **v9.17.0**（2026-09 核实；本仓库全局登记 v3.13.0）
- 刷新子模块清单的命令样例：
  ```bash
  curl -s https://api.github.com/repos/snakemake/snakemake-wrappers/contents/bio/cutadapt | python3 -c 'import json,sys; print("\n".join(sorted(x["name"] for x in json.load(sys.stdin))))'
  ```

### 2) 本地自定义规则（td2 式，拆自 riboseq 流程）

cutadapt 只有 trim 一个子命令；SE/PE 为同一 wrapper（`cutadapt.py`）的两种输入形态 → `snakemake/cutadapt_se.smk`（rule `cutadapt_se`）/ `snakemake/cutadapt_pe.smk`（rule `cutadapt_pe`），每文件一规则、config 驱动、可独立 dry-run：

- 配套文件（均平铺 `snakemake/`，`.smk` 同目录相对引用）：`cutadapt.yaml`（`bioconda::cutadapt==5.2`）、`cutadapt.py`（docker/native/conda 分支由共享 `modules/docker_wrapper.py` 提供）。
- config 契约与独立运行示例见各 `.smk` 头注；不再依赖流程 `config["paths"]`/`containers`/`common.smk` 的 `samples`/`is_pe`。
  ```snakefile
  include: "modules/cutadapt/snakemake/cutadapt_se.smk"
  include: "modules/cutadapt/snakemake/cutadapt_pe.smk"
  ```

---

## nextflow / nf-core（说明层登记，不建目录）

官方 **nf-core 单模块 `CUTADAPT`**（modules/nf-core/cutadapt：`main.nf` + `meta.yml` + `environment.yml` + `tests/`，无按工具版本的子目录）：

> ⚠️ **强提示**：真正执行需在项目内执行 `nf-core modules install cutadapt`（安装到项目自身 `modules/nf-core/cutadapt/`），再 `include { CUTADAPT }`；本仓库不提供可 include 的 nf-core 代码。

- 官方目录：https://github.com/nf-core/modules/tree/master/modules/nf-core/cutadapt
- `environment.yml` pin：`bioconda::cutadapt=5.2`（与 snakemake-wrappers 一致）
- 模块维护：`environment.yml`/`meta.yml` 更新于 2025-12（PR #9551），`main.nf` 更新于 2026-04（PR #11260，apptainer 支持）
- 刷新信息：`curl -s https://api.github.com/repos/nf-core/modules/contents/modules/nf-core/cutadapt`

---

## Conda 环境

```yaml
# snakemake 规则 conda 环境（modules/cutadapt/snakemake/cutadapt.yaml）
name: cutadapt
channels:
  - conda-forge
  - bioconda
  - defaults
dependencies:
  - bioconda::cutadapt==5.2
```

```yaml
# native 本地 Conda 环境配方（可选；创建：mamba env create -n cutadapt-native ...）
name: cutadapt-native
channels:
  - conda-forge
  - bioconda
dependencies:
  - python=3.11
  - cutadapt=5.2
  - pyyaml>=6.0
```

## 容器与 Conda 链接

- **Bioconda 页面**：https://anaconda.org/bioconda/cutadapt（`cutadapt=5.2`，2026-03 _1 / 2026-07 _2 重建）
- **Docker（quay.io / biocontainers）**：`docker pull quay.io/biocontainers/cutadapt:5.2--py312hfabe715_2`（tag 示例，以 quay.io 实际列表为准；国内加速 `docker.1ms.run/biocontainers/cutadapt:5.2--py312hfabe715_2`）
- **Singularity**：https://depot.galaxyproject.org/singularity/cutadapt%3A5.2--py312hfabe715_2
- **本模块容器**：官方镜像优先，本地不再维护 Dockerfile/Apptainer.def（见 native 节）
- 安装方式（本地）：`mamba create -n cutadapt -c conda-forge -c bioconda cutadapt=5.2`
