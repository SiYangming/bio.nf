# minimap2 软件模块

> 汇总说明：本 README 合并各实现（native/snakemake/nextflow）的用法；安装方式见下方各节，容器与 conda 环境信息记录于此。

---

## native 实现

# minimap2 / native

自包含的 minimap2 驱动实现（`source_type: custom`）。

## 能力

| 子命令 | 说明 |
|--------|------|
| `align` | reads → 参考基因组比对；`--bam` 输出 BAM（`minimap2 -a | samtools sort | samtools view -b -h`），否则输出 PAF |

支持 `--cigar-paf`（PAF 输出 CIGAR，`-c`）与 `--cigar-bam`（长 CIGAR 写 CG 标签，`-L`）；
不提供 `--reference` 时退化为 reads vs reads 自比对；命令逻辑与 nf-core `minimap2/align` 核心行为一致。

## 快速开始

### 1. 安装环境

```bash
mamba env create -f environment.yml
conda activate minimap2-native
```

### 2. CLI 调用

```bash
# PAF 输出
python main.py align --reads flnc.fa --reference ref.fa --outdir aln --prefix sample --threads 8

# BAM 输出（依赖 samtools）
python main.py align --reads flnc.fa --reference ref.fa --outdir aln --bam --threads 8

# 透传 minimap2 参数（splice 模式示例）
python main.py align --reads flnc.fa --reference ref.fa --outdir aln \
    --args "-x splice -uf -k14" --bam --threads 8
```

### 3. Agent / Schema 自省

```bash
python main.py --schema              # 输出 JSON Schema
python main.py --list-commands       # 列出支持的子命令
python main.py align --reads x.fa --reference r.fa --dry-run   # 只打印构建出的命令
```

### 4. 容器运行（官方镜像优先，不维护本地配方）

官方已维护（bioconda → quay.io/biocontainers → depot.galaxyproject.org），直接拉取官方镜像运行工具二进制：

```bash
# Docker：工具直跑（官方镜像内只含 minimap2，main.py 驱动在宿主机运行）
docker pull quay.io/biocontainers/minimap2:<tag>        # tag 见 quay 页面
docker run --rm -u $(id -u):$(id -g) -v "$PWD":/data quay.io/biocontainers/minimap2:<tag> \
  minimap2 -x splice -uf -k14 -t 8 -o /data/aln.paf /data/ref.fa /data/flnc.fa

# Singularity/Apptainer
apptainer pull minimap2.sif docker://quay.io/biocontainers/minimap2:<tag>
# 或直链 depot.galaxyproject.org/singularity/minimap2%3A<tag>（与 quay 同 build tag）
```

> 容器内为原生工具入口（PAF 直出；BAM 输出 `minimap2 | samtools sort | samtools view` 需宿主侧另装 samtools）；
> 需要 Schema/自省/参数注入时在**宿主机**（已装 minimap2 或 conda env）运行 `python main.py align ...`。

### 5. 测试

```bash
bash test/run_test.sh
```

## 版本说明

- **native 二进制**：`minimap2 2.24`，由**官方镜像/conda 提供**（quay.io/biocontainers/minimap2、bioconda minimap2=2.24；宿主机安装用 mamba/conda；BAM 管线另需 samtools）。
- **与流程原配差异**：原流程配 bioconda `minimap2=2.28`（`quay.io/biocontainers/minimap2:2.28--h577a1d6_4`）。
  2.24 与 2.28 对本流程（Iso-Seq FLNC 比对）行为一致；若需完全对齐 2.28，拉取对应官方镜像 tag
  或宿主机用 conda/mamba 装 `bioconda::minimap2=2.28`。
- nf-core / snakemake-wrappers 侧版本见软件级 `meta.yaml` 的 `software_versions`。

## 性能优化约定

- **线程**：`align` 默认 8 线程（CPU 密集），用户显式 `--threads` 永远优先；`-t` 注入 minimap2，
  samtools sort/view 同步使用。
- **临时目录**：`--tmpdir` 覆盖 `$TMPDIR`；中间 SAM 走管道不落盘（`pipefail` 保证失败传导）。
- **内存**：通过 `meta.yaml.optimization.default_mem_mb` 声明，供上层调度器读取。

## 历史留存（legacy/）

供追溯对照的原始实现脚本与 `main.py` 同存于 `native/`，**正式入口为 `main.py`**。

- `minimap2_align.py`


---

## snakemake 实现

# minimap2 / snakemake（本地规则 + 官方 wrappers 参考）

### 本地拆分规则（type: snakemake_local，源 isoseq 流程）

`snakemake/` 下规则按「每 rule 一个 config 驱动 .smk」拆分（td2 式，源 isoseq 流程的
`minimap2_align` 自维护版），规则不依赖流程级 `SAMPLES`/`samples` 表与 `config[paths]`
上下文，可脱离流程独立 dry-run：

| 文件 | 规则 | 作用 |
|------|------|------|
| `minimap2_align.smk` | `minimap2_align` | reads（可选 reference）→ 排序 BAM + `.bai` + versions.yml（`minimap2 -a \| samtools sort \| samtools view -b -h` + `samtools index`），产物 `<minimap2_outdir>/<prefix>.bam` |
| `minimap2_align.py` | — | 上述规则的同目录 script wrapper（docker/native/conda 三模式经共享 `modules/docker_wrapper.py` 的 `docker_wrapper_binary(config, "minimap2", ...)` 分派） |
| `minimap2.yaml` | — | conda env：bioconda minimap2==2.31 + samtools==1.24（与官方 wrapper v3.13.0 bio/minimap2/aligner 锚点一致） |

- 配套文件平铺在 `snakemake/` 根（无 `envs/`、`scripts/` 子目录，`.smk` 内 `conda:`/`script:` 用同目录相对名）。
- 规则 config 驱动：`minimap2_reads`（必填）/`minimap2_reference`（可选，缺省 reads vs reads 自比对）/`minimap2_outdir`/`minimap2_prefix` 由 `--config` 提供；`exec_mode`（conda 默认/docker/native）、`threads` 与 `minimap2.*`（docker_image/minimap2_bin/samtools_bin/args/cigar_bam）在 Snakefile 的 config/config.yaml 预设。config 契约与独立运行示例见 `.smk` 头部，例如：

```bash
snakemake -s modules/minimap2/snakemake/minimap2_align.smk \
    --config minimap2_reads=flnc.fa.gz minimap2_reference=ref.fa threads=8 \
    --cores 8 --use-conda
```

- 组装完整流程时 `include` 该 `.smk` 并用 `rule all` 指向产物（见 `.smk` 头注与软件级 `meta.yaml` 的 `execution.snakemake_include_hint`）。
- BAM 管线为多步（minimap2 | samtools sort | samtools view + index + versions 写入）且有执行模式分派 → 用 `script:` 同目录 wrapper；若只需单条命令（PAF 直出等），用官方 `wrapper:` 句柄（见下）或自行写 `shell:` 一行规则。

### 官方 snakemake-wrappers（说明层，运行时靠 `wrapper:` 句柄解析）

> 本模块**不重写官方 wrapper 源码**。官方仓库 `bio/minimap2/` 子模块如下（2026-08 抓取，以官方在线目录为准）：

| wrapper | wrapper 句柄 | 环境 pin（v3.13.0，见软件级 meta.yaml software_versions） |
|---------|--------------|----------------------------------------------------------|
| aligner | `vX.Y.Z/bio/minimap2/aligner` | minimap2=2.31 + samtools=1.24 + snakemake-wrapper-utils=0.9.0 |
| index | `vX.Y.Z/bio/minimap2/index` | 同上 |

引用示例（Snakefile）：

```python
rule minimap2_align:
    input:
        ref="refs/genome.fa",
        reads="reads.fastq.gz"
    output:
        "mapped.bam"
    log: "logs/minimap2_align.log"
    params:
        extra="-x splice -uf -k14 -a"
    threads: 16
    wrapper: "v3.13.0/bio/minimap2/aligner"
```

> ⚠️ 本模块未内置官方 wrapper 的 wrapper.py：Snakemake 运行时按 `wrapper:` 句柄解析（联网拉取中央 wrapper 缓存）；离线/私有环境缺失时请改用本模块 `snakemake/minimap2_align.smk` 本地规则。
> 更新子模块清单的抓取命令：
> `curl -s https://api.github.com/repos/snakemake/snakemake-wrappers/contents/bio/minimap2 | python3 -c "import json,sys; [print(x['name']) for x in json.load(sys.stdin)]"`

---

## Conda 环境（原 native/environment.yml）

```yaml
# minimap2 native Conda 环境配方
# 创建：mamba env create -f environment.yml
# 说明：容器走官方镜像（quay.io/biocontainers/minimap2），不再维护本地配方；
#      本文件仅作 HPC 无 root 场景 / 非容器场景的 Conda 兜底。
#      如需与历史流程原配完全对齐，可把 minimap2 pin 改为 2.28。
name: minimap2-native
channels:
  - conda-forge
  - bioconda
dependencies:
  - python=3.11
  - minimap2=2.24
  - samtools=1.21
  - pyyaml>=6.0
  - pip
```

## 容器与 Conda 链接

- **Bioconda 页面**：https://anaconda.org/channels/bioconda/packages/minimap2/overview
- **Docker（最新）**：`docker pull quay.io/biocontainers/minimap2:2.31--h118bc1c_0`
- **Singularity（最新）**：https://depot.galaxyproject.org/singularity/minimap2%3A2.31--h118bc1c_0
- 安装方式（本地）：`mamba create -n minimap2 -c conda-forge -c bioconda minimap2=2.31`
- 注：流程原配版本见上文（minimap2 历史版本），本链接为 bioconda 最新容器。
