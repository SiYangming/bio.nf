# transdecoder 软件模块

> 汇总说明：本 README 合并各实现（native/snakemake/nextflow）的用法；安装方式见下方各节，容器与 conda 环境信息记录于此。

---

## native 实现

# transdecoder / native — 自包含 ORF 预测驱动

**TransDecoder**（转录本 CDS 预测）的本地自包含实现（`source_type: custom`、`type: native`）。
conda 包 `transdecoder=5.7.1` 提供两个二进制：**`TransDecoder.LongOrfs`** 与 **`TransDecoder.Predict`**。

## 功能

* `longorfs`：提取候选最长 ORF → 生成 `<prefix>.transdecoder_dir/` 中间目录（longest_orfs.pep/cds/gff3）

  `TransDecoder.LongOrfs -t <fasta> -O <dir> [--gene_trans_map <gtm>] [-m <aa>] [-G <code>] [-S] [--complete_orfs_only]`

* `predict`：基于序列组成模型预测最终 CDS → 输出 `<prefix>.transdecoder.{pep,cds,gff3,bed}`

  `TransDecoder.Predict -t <fasta> -O <dir> [--retain_pfam_hits] [--retain_blastp_hits] [--single_best_only] [--no_refine_starts] --cpu <N>`

* 自动解压 `.gz` 输入、自动注入线程（`--cpu`）与 `TMPDIR`

## 用法

```bash
# CLI 直跑
python main.py longorfs -t transcripts.fa -O out --min-protein-length 50 --genetic-code Universal --strand-specific --complete-orfs-only
python main.py predict  -t transcripts.fa -O out --retain-pfam-hits pfam.domtblout --retain-blastp-hits blastp.outfmt6 --no-refine-starts --threads 8

# Agent / Schema 自省
python main.py --schema
python main.py --list-commands
```

子命令 `longorfs` / `predict` 均支持 `--threads` / `--tmpdir` 运行期覆盖。

## 环境安装

### 1. Conda（HPC 无 root / 离线兜底）

```bash
mamba env create -f environment.yml   # name: transdecoder-native（transdecoder=5.7.1 + perl + parallel）
conda activate transdecoder-native
```

### 2. 容器运行（官方镜像优先，不维护本地配方）

官方已维护（bioconda → quay.io/biocontainers → depot.galaxyproject.org），直接拉取官方镜像运行工具二进制：

```bash
# Docker：工具直跑（官方镜像内只含 transdecoder，main.py 驱动在宿主机运行）
docker pull quay.io/biocontainers/transdecoder:<tag>        # tag 见 quay 页面
docker run --rm -u $(id -u):$(id -g) -v "$PWD":/data quay.io/biocontainers/transdecoder:<tag> \
  TransDecoder.LongOrfs -t /data/transcripts.fa -O /data/out
docker run --rm -u $(id -u):$(id -g) -v "$PWD":/data quay.io/biocontainers/transdecoder:<tag> \
  TransDecoder.Predict -t /data/transcripts.fa -O /data/out --cpu 8

# Singularity/Apptainer
apptainer pull transdecoder.sif docker://quay.io/biocontainers/transdecoder:<tag>
# 或直链 depot.galaxyproject.org/singularity/transdecoder%3A<tag>（与 quay 同 build tag）
```

> 容器内为原生工具入口；需要 Schema/自省/参数注入时在**宿主机**（已装 transdecoder 或 conda env）运行 `python main.py <subcommand> ...`。

## 测试

```bash
bash test/run_test.sh   # 无需真实转录本 FASTA；工具未装时退化为 argv 构造验证
```

## 版本

* transdecoder 5.7.1（bioconda::transdecoder=5.7.1，二进制 TransDecoder.LongOrfs / TransDecoder.Predict）

* 提供方式：官方镜像 / conda 提供（quay.io/biocontainers/transdecoder / depot.galaxyproject.org；宿主机安装用 mamba/conda 装 bioconda transdecoder=5.7.1）

## 历史留存（legacy/）

供追溯对照的原始 Snakemake wrapper 脚本与 `main.py` 同存于 `native/`，**正式入口为 `main.py`**。

- `transdecoder_longorfs.py` — TransDecoder.LongOrfs 原始 wrapper（snakemake.shell + docker_wrapper）
- `transdecoder_predict.py` — TransDecoder.Predict 原始 wrapper（snakemake.shell + docker_wrapper）

## 历史单元测试（test/unit/）

`test/unit/` 存放原始单元测试（test_transdecoder_longorfs.py / test_transdecoder_predict.py + common.py/conftest.py），供追溯对照与 pytest 回归；`test/run_test.sh` 为技能自带的最小回归。


---

## snakemake 实现

# transdecoder / snakemake / local — 自维护 Snakemake 规则

官方 `snakemake-wrappers` 虽有 `bio/transdecoder/{longorfs,predict}`，但本目录提供
自维护实现（`source_type: custom`、`type: snakemake_local`），
用于本地定制 / 与历史流程行为对齐的场景。

## 规则文件

- `transdecoder.smk` — 两条规则：
  - `rule transdecoder_longorfs`：转录本 FASTA → `transdecoder/{sample}/longorfs/`（候选最长 ORF）
  - `rule transdecoder_predict`：`transdecoder/{sample}/predict/{sample}.{pep,cds,gff3,bed}`（最终 CDS）

去除对 Snakefile 顶部全局变量（SAMPLES / os / config）与 `docker_wrapper.py` 的依赖：
- 输入路径模板：`long_read/{sample}.fasta`
- 参数内联：
  - longorfs: `-m 50 -G Universal -S --complete_orfs_only`（可经 `params.gene_trans_map` 加映射）
  - predict: `--no_refine_starts`（可经 `params.retain_pfam_hits / retain_blastp_hits` 加证据）
- docker/container 分支移除，直接调用 `TransDecoder.LongOrfs` / `TransDecoder.Predict` 二进制

## 用法

```python
# Snakefile 中
include: "modules/transdecoder/snakemake/transdecoder.smk"

# 运行
snakemake -j 8 transdecoder/sample1/predict/sample1.pep
```

## 依赖环境

规则内 `conda: "envs/transdecoder.yaml"`，需要自备：

```yaml
# envs/transdecoder.yaml
channels: [conda-forge, bioconda]
dependencies:
  - transdecoder=5.7.1
  - perl
  - parallel
```

## 与其它实现的关系

- 官方 wrapper（`../snakemake-wrappers/` 登记层，`v3.13.0/bio/transdecoder/{longorfs,predict}`）为推荐 Snakemake 路径
- 非 Snakemake 场景（独立 CLI / Agent Function Calling）请走 `../../native/`


---

## Conda 环境（原 native/environment.yml）

```yaml
# transdecoder native Conda 环境配方
# 创建：mamba env create -f environment.yml
# 说明：transdecoder 不在 Debian bookworm apt；本文件是 Conda 兜底（HPC 无 root / 离线场景）。
#      容器默认路线：官方镜像（quay.io/biocontainers/transdecoder），本地不再自建 Dockerfile / Apptainer.def。
# 环境：transdecoder=5.7.1 + perl + parallel。
name: transdecoder-native
channels:
  - conda-forge
  - bioconda
dependencies:
  - python=3.11
  - transdecoder=5.7.1    # 提供二进制 TransDecoder.LongOrfs / TransDecoder.Predict
  - perl                  # TransDecoder 运行时依赖
  - parallel              # LongOrfs 内部并行依赖（GNU parallel）
  - pyyaml>=6.0
  - pip
```

## 容器与 Conda 链接

- **Bioconda 页面**：https://anaconda.org/channels/bioconda/packages/transdecoder/overview
- **Docker**：`docker pull quay.io/biocontainers/transdecoder:6.0.0--pl5321hdfd78af_0`
- **Singularity**：https://depot.galaxyproject.org/singularity/transdecoder%3A6.0.0--pl5321hdfd78af_0
- 安装方式（本地）：`mamba create -n transdecoder -c conda-forge -c bioconda transdecoder=6.0.0`
