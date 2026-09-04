# star 软件模块

> 汇总说明：本 README 合并各实现（native/snakemake）的用法；官方 snakemake-wrappers 与 nf-core 子模块信息记录于此（不建目录，仅说明层）。安装方式见下方各节，容器与 conda 环境信息记录于此。

---

## native 实现

# star / native

自包含的 STAR 驱动实现（`source_type: custom`）。官方镜像优先（bioconda → quay.io/biocontainers → depot.galaxyproject.org 已有 star 官方镜像），本地不再维护 Dockerfile/Apptainer.def。
注意：STAR 可执行文件名为 `STAR`；native 锚点版本 2.7.10b（Debian apt 曾打包为 rna-star），与 bioconda 包名 `star` 流程常用版本 2.7.11b 不同，差异见文末「版本差异声明」。

## 能力

| 子命令 | 说明 | 线程 |
|--------|------|------|
| `index` | STAR `--runMode genomeGenerate`：参考 FASTA（+可选 GTF）→ STAR 索引目录 | ✅（默认 8） |
| `align` | STAR `--runMode alignReads`：SE(`-U`)/PE(`-1/-2`) reads → SAM/BAM | ✅（默认 4） |

## 快速开始

### 1. 安装环境

```bash
# 途径 1：conda（宿主机直跑 main.py；HPC 无 root 场景；配方见文末「Conda 环境」节）
mamba env create -f environment.yml
conda activate star-native
# 途径 2：官方容器（bioconda 官方镜像，只含 STAR 工具；用法见第 4 节）
docker pull quay.io/biocontainers/star:2.7.11b--h5ca1c30_8
```

### 2. CLI 调用

```bash
# 建索引（参考 FASTA -> genomeDir/ 下的 Genome/SA/SAindex；含 GTF 时生成剪接位点索引）
python main.py index refs.fa genomeDir --gtf ann.gtf --sjdb-overhang 100 --threads 8
# 小基因组（<2^14 bp）必须调小 genomeSAindexNbases：
python main.py index refs.fa genomeDir --genome-sa-index-nbases 5 --threads 8
# 双端比对 -> BAM（默认 --out-sam-type "BAM SortedByCoordinate"）
python main.py align --genome-dir genomeDir -1 r1.fq.gz -2 r2.fq.gz -o out.bam --threads 8
# 单端比对 -> SAM（SAM 走 stdout 不可靠时一律 -o 落盘）
python main.py align --genome-dir genomeDir -U single.fq.gz -o out.sam \
    --out-sam-type SAM --threads 4
```

### 3. Agent / Schema 自省

```bash
python main.py --schema              # 输出 JSON Schema
python main.py --list-commands       # 列出支持的子命令
```

### 4. 容器运行（官方镜像优先，不维护本地配方）

官方已维护（bioconda → quay.io/biocontainers → depot.galaxyproject.org），直接拉取官方镜像运行工具二进制：

```bash
# Docker：工具直跑（官方镜像内只含 STAR，main.py 驱动在宿主机运行）
docker pull quay.io/biocontainers/star:2.7.11b--h5ca1c30_8        # 与 riboseq 流程一致；tag 见 quay 页面
docker run --rm -u $(id -u):$(id -g) -v "$PWD":/data quay.io/biocontainers/star:2.7.11b--h5ca1c30_8 \
  index /data/refs.fa /data/genomeDir --genome-sa-index-nbases 5 --threads 8
docker run --rm -u $(id -u):$(id -g) -v "$PWD":/data quay.io/biocontainers/star:2.7.11b--h5ca1c30_8 \
  align --genome-dir /data/genomeDir -1 /data/r1.fq.gz -2 /data/r2.fq.gz \
  -o /data/out.bam --threads 8

# Singularity/Apptainer
apptainer pull star.sif docker://quay.io/biocontainers/star:2.7.11b--h5ca1c30_8
# 或直链 depot.galaxyproject.org/singularity/star%3A2.7.11b--h5ca1c30_8（与 quay 同 build tag）
```

> 容器内为原生工具入口；需要 Schema/自省/参数注入时在**宿主机**（conda env 装 star）运行 `python main.py <subcommand> ...`。

### 5. 测试

```bash
bash test/run_test.sh
```

## 性能优化约定

- **线程**：`index` 默认 8 线程（CPU 密集），`align` 默认 4；用户显式 `--threads` 永远优先。
- **临时目录**：align 默认在隔离 run_dir（输出同目录或 `$TMPDIR`）下运行，`Log.out` / `SJ.out.tab` 等副产物不污染工作目录；`TMPDIR` 通过 `meta.yaml.optimization.env_vars`（占位符 `{tmpdir}`）注入。
- **内存**：STAR 需将索引载入内存，通过 `meta.yaml.optimization.default_mem_mb`（16384 MB）声明，供上层调度器读取；人类基因组流程建议按索引类型单独放大。


---

## snakemake 实现

# star / snakemake（本地规则 + 官方 wrappers 参考）

### 本地拆分规则（type: snakemake_local，源为 riboseq 流程）

`snakemake/` 下规则按「每 rule 一个 config 驱动 .smk」拆分（td2 式，源 riboseq 的
`riboseq.smk workflow/rules/star.smk`），规则不依赖流程级 `SAMPLES`/`samples` 表与
`config[paths]` 上下文，可脱离流程独立 dry-run：

| 文件 | 规则 | 作用 |
|------|------|------|
| `star_index.smk` | `star_index` | 参考 FASTA（+可选 GTF）→ STAR 索引目录（`--runMode genomeGenerate`），产物 `<star_outdir>/star_index/` |
| `star_align.smk` | `star_align` | SE(`-U`)/PE(`-1/-2`) reads → 基因组比对 BAM（`--runMode alignReads`），产物 `<star_outdir>/align/` |

- 配套文件平铺在 `snakemake/` 根（无 `envs/`、`scripts/` 子目录，`.smk` 内 `conda:`/`script:` 用同目录相对名）：`star.yaml`（bioconda star==2.7.11b，与 riboseq 一致）、`star_index.py` / `star_align.py`（docker/native/conda 三模式经共享 `modules/docker_wrapper.py` 的 `docker_wrapper_binary(config, "star", "star_bin", "STAR")` 分派）。
- 每个 `.smk` 顶部 `config.setdefault` 给默认、头注含独立运行示例与 config 契约；独立运行用 `--config` 提供输入（如 `star_genome_fasta` / `star_reads1,star_reads2`(PE) 或 `star_reads`(SE) / `star_outdir`），`star.*`（docker_image/star_bin/sjdb_overhang/index_extra/align_extra）在 Snakefile 的 config/config.yaml 预设。
- 组装完整流程时分别 `include` 两个 `.smk` 并用 `rule all` 指向产物（见各 `.smk` 头注与 `meta.yaml` 的 `snakemake_include_hint`）。

### 官方 snakemake-wrappers（说明层，运行时靠 `wrapper:` 句柄解析）

> 本模块**不重写官方 wrapper 源码**。官方仓库 `bio/star/` 子模块如下（2026-09 抓取，以官方在线目录为准）：

| wrapper | wrapper 句柄 | 环境 pin（v3.13.0 与 master 一致） |
|---------|--------------|-----------------------------------|
| align | `vX.Y.Z/bio/star/align` | star=2.7.11b |
| index | `vX.Y.Z/bio/star/index` | star=2.7.11b |

引用示例（Snakefile）：

```python
rule star_align:
    input:
        reads=["reads_1.fastq", "reads_2.fastq"],
        idx=directory("refs/star_index"),
    output:
        "mapped.bam"
    log: "logs/star_align.log"
    params:
        extra="--outSAMtype BAM SortedByCoordinate"
    threads: 16
    wrapper: "v3.13.0/bio/star/align"
```

> ⚠️ 本模块未内置官方 wrapper 的 wrapper.py：Snakemake 运行时按 `wrapper:` 句柄解析（联网拉取中央 wrapper 缓存）；离线/私有环境缺失时请改用本模块 `snakemake/star_index.smk` + `snakemake/star_align.smk` 本地规则。
> 更新子模块清单的抓取命令：
> `curl -s https://api.github.com/repos/snakemake/snakemake-wrappers/contents/bio/star | python3 -c "import json,sys; [print(x['name']) for x in json.load(sys.stdin)]"`

### nf-core 官方参考（Nextflow，说明层）

本模块未建 `nextflow/` 目录；nf-core 官方 `modules/nf-core/star/` 子模块（2026-09 抓取，以官方在线目录为准）：

| 子模块 | environment.yml 关键 pin（以 align 为代表） |
|--------|---------------------------------------------|
| align | bioconda::star=2.7.11b, htslib=1.21, samtools=1.21, gawk=5.1.0 |
| genomegenerate | star=2.7.11b（同家族 pin） |
| indexversion | star=2.7.11b（同家族 pin） |
| starsolo | star=2.7.11b（同家族 pin，另含 solo 相关依赖） |

组装 Nextflow DSL2 流程时执行 `nf modules install nf-core star align genomegenerate indexversion starsolo`（安装到项目自身 `modules/nf-core/`，不要直接 include 本仓库文件），随后：

```nextflow
include { STAR_ALIGN }           from '../modules/nf-core/star/align/main'
include { STAR_GENOMEGENERATE }  from '../modules/nf-core/star/genomegenerate/main'
```

> 抓取命令：`curl -s https://api.github.com/repos/nf-core/modules/contents/modules/nf-core/star | python3 -c "import json,sys; [print(x['name']) for x in json.load(sys.stdin)]"`


---

## 版本差异声明（native / snakemake-wrappers / nf-core）

| 实现 | star 版本 | 来源 |
|------|-----------|------|
| native（官方镜像/conda） | **2.7.10b** | quay.io/biocontainers/star + bioconda（native 锚点版本；Debian apt 曾打包为 `rna-star=2.7.10b+dfsg-2+b2`，可执行文件为 STAR） |
| snakemake 本地规则 env | 2.7.11b | bioconda（riboseq 流程 `envs/star.yaml`） |
| snakemake-wrappers v3.13.0 / master | 2.7.11b | bioconda（bio/star/{align,index}/environment.yaml） |
| nf-core master | 2.7.11b | bioconda（modules/nf-core/star/*/environment.yml） |

> native 锚点 2.7.10b 与 bioconda/流程常用 2.7.11b 存在字母级差异：bioconda（conda 与 quay 镜像）两组版本均有，2.7.10b 对应 native 锚点、2.7.11b 为 riboseq/流程同款。对索引格式/比对细节敏感的流程建议用官方容器/conda 固定 2.7.11b（如 quay.io/biocontainers/star:2.7.11b--h5ca1c30_8），与 riboseq 流程一致。


---

## Conda 环境（原 native/environment.yml）

```yaml
# star native Conda 环境配方（HPC 无 root / 非容器兜底）
# 创建：mamba env create -f environment.yml
name: star-native
channels:
  - conda-forge
  - bioconda
dependencies:
  - python=3.11
  - star=2.7.11b       # 与 riboseq 流程一致；native 锚点 2.7.10b 可用 conda star=2.7.10b（见版本差异声明）
  - pyyaml>=6.0
```

## 容器与 Conda 链接

- **Bioconda 页面**：https://anaconda.org/bioconda/star
- **Docker**：`docker pull quay.io/biocontainers/star:2.7.11b--h5ca1c30_8`（riboseq 流程同款）
- **Singularity**：https://depot.galaxyproject.org/singularity/star%3A2.7.11b--h5ca1c30_8
- 安装方式（本地）：`mamba create -n star -c conda-forge -c bioconda star=2.7.11b`（Debian apt 包名 rna-star 与可执行文件说明见上「版本差异声明」）
- 上游 GitHub：https://github.com/alexdobin/STAR
