# Ribo-seq 分析流程运行指南

本指南详细介绍了如何使用 `run.sh` 脚本高效运行 Ribo-seq 分析流程。该脚本整合了 RPFs、Totals 和 Downstream 分析的各个步骤，并提供了环境管理功能，简化了操作流程。

仓库本身只存放代码与文档，**测试数据与参考数据均不随仓库分发**（已在 `.gitignore` 中忽略），需要按下面说明自行下载或重建。建议按顺序：先准备[测试数据](#1-测试数据)与[参考数据](#2-参考数据)，再按[依赖安装](#3-依赖安装)建好环境，最后通过 `run.sh` 运行（见[4 环境配置](#4-环境配置)～[7 运行顺序](#7-运行顺序)）。

## 1. 测试数据

本仓库的测试数据是 GEO 数据集 GSE182201（RNA-seq + Ribo-seq）中部分样本经 **chr20 抽样**（down-sample）得到的子集 FASTQ，样本清单见 `info.csv`。

### 数据来源

- 子集 FASTQ（与 `info.csv` 一一对应）来自 [nf-core/test-datasets](https://github.com/nf-core/test-datasets/tree/riboseq) 的 `riboseq` 分支，目录 `testdata/GSE182201/`；

- 完整数据集（含全部样本的 RNA-seq 与 Ribo-seq 原始数据）来自 [GEO: GSE182201](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE182201)（PM2.5 处理下的人支气管上皮细胞）。

### 方式一：从 nf-core/test-datasets 直接下载（推荐）

在仓库根目录执行以下命令，将 FASTQ 下载到 `GSE182201/`（文件名与 `info.csv` 一致）：

```bash
base="https://raw.githubusercontent.com/nf-core/test-datasets/riboseq/testdata/GSE182201"
mkdir -p GSE182201
awk -F, 'NR>1{print $2; if ($3!="") print $3}' info.csv \
  | sort -u \
  | while read -r f; do
      wget -P GSE182201 "$base/$(basename "$f")"
    done
```

### 方式二：从 GEO 完整数据自行制作

1. 从 [GSE182201](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE182201) 下载所需样本的原始 FASTQ 并完成比对；
2. 将比对上 chr20 的 reads 取回并与原始 FASTQ 对照抽样，得到测试子集。制作流程可参考 nf-core/test-datasets 同分支下的 [`testdata/make_test_data.sh`](https://github.com/nf-core/test-datasets/blob/riboseq/testdata/make_test_data.sh)。

### Snakemake 层使用的样本表（放置于项目内 testdata/）

若按 [riboseq.md](../riboseq.md)「执行方式 B」在项目内重建 Snakemake 集成层并跑同一批测试数据，样本表沿用下列三件（放置于项目 `testdata/`，与本节 `test/info.csv` 描述同一批 GSE182201 chr20 子集）：

| 文件                    | 说明                                                                                                                              |
| :---------------------- | :-------------------------------------------------------------------------------------------------------------------------------- |
| `samplesheet_local.csv` | 样本表（`sample, fastq_1, fastq_2, strandedness, type=riboseq/rnaseq, ...`）；Snakemake `config.yaml` 的 `samples.sheet` 指向此处 |
| `contrasts_local.csv`   | DESeq2 差异分析对照表（`config.samples.contrasts`）                                                                               |
| `make_test_data.sh`     | GSE182201 → chr20 下采样的制作脚本（取自 nf-core/test-datasets 同分支同名脚本）                                                   |

> 说明：native 层 `run.sh` 以 `test/info.csv` 组织样本，Snakemake 层以 `samplesheet_local.csv` 组织——二者含义相同、互为对应。FASTQ 下载与上节「方式一」一致；除逐文件下载外，也可整体拉取 nf-core 分支后复制：
>
> ```bash
> git clone --single-branch --branch riboseq \
>     https://github.com/nf-core/test-datasets.git <dest>
> cp -r <dest>/testdata/GSE182201 .
> ```

## 2. 参考数据

Ribo-seq 流程运行需要参考序列与比对索引，同样不随仓库分发；仓库仅保留制作 chr20 参考子集的脚本 [test/extract\_chr20\_transcripts.py](test/extract_chr20_transcripts.py)。

`Shell_scripts/common_variables.sh` 中默认路径均为 `reference/...`（可通过环境变量 `RIBO_SEQ_FASTA_DIR`、`RIBO_SEQ_*` 系列覆盖，指向仓库外独立的参考目录），需按下述结构自行准备：

### 目录结构（运行测试数据所需）

```
reference/
├── GENCODE/
│   └── v49/                                  # 人源 GENCODE release 49（chr20 子集）
│       ├── gencode.v49.dna_chr20.fa(.gz)     # chr20 基因组序列（STAR 比对用）
│       ├── gencode.v49.annotation_chr20.gtf  # chr20 注释（STAR 索引及计数用）
│       ├── gencode.v49.pc_transcripts_chr20.fa           # chr20 蛋白编码转录本
│       ├── gencode.v49.pc_transcripts_chr20_reformatted.fa
│       ├── gencode.v49.pc_transcripts_chr20_filtered.fa  # RPFs 比对用转录组（bbmap）
│       ├── gencode.v49.pc_translations_chr20.fa(.reformatted.fa)
│       ├── transcript_info/                  # Reformatting 脚本输出的 csv
│       │   └── gencode.v49.pc_transcripts_chr20_{gene_IDs,protein_IDs,region_lengths}.csv
│       ├── rsem_bowtie2_index/               # RSEM(bowtie2) 索引，本地生成
│       └── STAR_index/                       # STAR 索引，本地生成
├── rRNA/sortmerna_rrna.fasta                 # rRNA 序列（bbmap 过滤核糖体 RNA）
└── tRNA/hg38-mature-tRNAs-dna.fasta          # 人成熟 tRNA 序列（bbmap 过滤 tRNA）
```

### 数据来源

| 文件                          | 来源                                                                                                                                                                                |
| :---------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| GENCODE v49 系列              | [GENCODE Human Release 49](https://www.gencodegenes.org/human/release_49.html)（原始文件也见 [GENCODE FTP](https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_49/)） |
| `sortmerna_rrna.fasta`        | [sortmerna](https://github.com/biocore/sortmerna) 自带 rRNA 数据库（`data/rRNA_databases/`，拼接而成）                                                                              |
| `hg38-mature-tRNAs-dna.fasta` | [GtRNAdb Hsapi38](http://gtrnadb.ucsc.edu/genomes/eukaryota/Hsapi38/Hsapi38-seq.html)                                                                                               |
| chr20 测试 FASTQ              | 见上文[测试数据](#1-测试数据)（属测试数据，不属于参考数据）                                                                                                                         |

### 重建步骤

**1) GENCODE v49 chr20 子集**

1. 下载 GENCODE v49 原始文件（解压后使用）：

   - `gencode.v49.annotation.gtf.gz`

   - `GRCh38.primary_assembly.genome.fa.gz`

   - `gencode.v49.pc_transcripts.fa.gz`、`gencode.v49.pc_translations.fa.gz`

2. 用保留脚本按 chr20 提取转录本/翻译序列（输出放到 `reference/GENCODE/v49/`）：

   ```bash
   python3 test/extract_chr20_transcripts.py \
       --gtf   gencode.v49.annotation.gtf \
       --fasta gencode.v49.pc_transcripts.fa \
       --output reference/GENCODE/v49/gencode.v49.pc_transcripts_chr20.fa \
       --chrom 20
   ```

3. 基因组序列与 GTF 只需按染色体行提取 chr20（用 `awk`/`samtools faidx`/`seqkit` 等工具即可）。
4. 后续 `*_reformatted.fa`、`*_filtered.fa`、`transcript_info/*.csv` 由
   [Python\_scripts/Reformatting\_GENCODE\_FASTA.py](Python_scripts/Reformatting_GENCODE_FASTA.py) 与
   [Python\_scripts/Filtering\_GENCODE\_FASTA.py](Python_scripts/Filtering_GENCODE_FASTA.py) 生成
   （这两个脚本只适用于 GENCODE 格式 FASTA；过滤与重格式化的原理及注意事项见下文「FASTA 过滤与重格式化」小节）。

**2) rRNA / tRNA**

- `sortmerna_rrna.fasta`：下载 [sortmerna](https://github.com/biocore/sortmerna) 的 rRNA 数据库后拼接；

- `hg38-mature-tRNAs-dna.fasta`：从 [GtRNAdb](http://gtrnadb.ucsc.edu/genomes/eukaryota/Hsapi38/Hsapi38-seq.html) 下载 human hg38 mature tRNA 序列。

**3) 比对索引**

`run.sh` 每次运行前会自动调用 `Shell_scripts/check_and_build_indices.sh`：当检测到 `rsem_bowtie2_index` 或 `STAR_index` 缺失时，会基于上述 FASTA/GTF 自动构建，无需手工操作。如需手动构建：

```bash
# RSEM (bowtie2) 索引
rsem-prepare-reference --bowtie2 --num-threads 4 \
    reference/GENCODE/v49/gencode.v49.pc_transcripts_chr20_filtered.fa \
    reference/GENCODE/v49/rsem_bowtie2_index/gencode.v49.pc_transcripts_filtered

# STAR 索引
STAR --runMode genomeGenerate --runThreadN 4 \
    --genomeDir reference/GENCODE/v49/STAR_index \
    --genomeFastaFiles reference/GENCODE/v49/gencode.v49.dna_chr20.fa \
    --sjdbGTFfile reference/GENCODE/v49/gencode.v49.annotation_chr20.gtf \
    --sjdbOverhang 100
```

### 注意事项

- 对完整（非 chr20 测试）项目，建议把参考序列与索引放到独立的参考目录（不放在仓库内），再通过 `RIBO_SEQ_FASTA_DIR` 等环境变量或直接修改 `common_variables.sh` 指定路径。

- 在项目内建立参考目录时，将可重建的数据文件加入 `.gitignore`，避免误提交大文件。

### Snakemake 层参考目录与配置（config.yaml reference 字段）

Snakemake 集成（见 [riboseq.md](../riboseq.md)「执行方式 B」，在项目内重建）同样**不随仓库分发大体积参考数据**；其 `config.yaml` 通过 `rnaseq.fasta/gtf`、`align.*.index`、`riboseq.align.bbmap.rRNA_ref/tRNA_ref`、`rsem.index` 等字段（默认指向项目内 `../reference/...`）配置本地路径，并在规则运行时检查文件是否存在。通用约定：

- 大文件不入库：全基因组 FASTA、完整 GTF/GFF、STAR/RSEM/bowtie2 等索引均按「获取说明 + 本地路径」方式处理；
- 推荐的本地参考目录结构：

```
reference/
├── genome/       # 基因组 FASTA
├── annotation/   # GTF/GFF 注释
├── rrna_trna/    # rRNA / tRNA 序列库
└── indices/      # 索引（star / rsem / bowtie2 等按工具分目录）
```

- 版本控制建议：小体积、常复用的注释表（region lengths、简化注释表）可直接入库，并在文件名中标明物种与版本；大文件仅记录获取方式与下载命令。

> 说明：两套路线最终指向同一份参考数据，仅路径组织不同——native 层用 `RIBO_SEQ_FASTA_DIR` 等环境变量（`common_variables.sh`），Snakemake（按 [riboseq.md](../riboseq.md) 执行方式 B 在项目内重建）层用 `config.yaml` 的 reference 字段；具体文件的来源表与重建步骤见上方「2. 参考数据」。

## 3. 依赖安装

本流程分为三类运行环境：**RiboSeq**（RPFs）、**RNAseq**（Totals）与 **R\_analysis**（Downstream）。仓库根目录提供了三个可直接使用的 Conda 环境定义文件：

| 环境定义文件         | 环境名      | 用途                                                                               |
| :------------------- | :---------- | :--------------------------------------------------------------------------------- |
| `RiboSeq_env.yml`    | RiboSeq     | 处理 RPFs（fastqc, cutadapt, umi_tools, bbmap, samtools, pysam, biopython 等）    |
| `RNAseq_env.yml`     | RNAseq      | 处理 Totals / 常规 RNA-seq（额外含 rsem, bowtie2, star, bioconductor-tximport 等） |
| `R_analysis_env.yml` | R\_analysis | 下游统计分析与绘图（DESeq2, tximport, fgsea, rrvgo 等）                            |

推荐直接用 `conda env create -f <文件>` 创建（创建后 `conda activate` 即可用）：

```console
conda env create -f RiboSeq_env.yml
conda env create -f RNAseq_env.yml
conda env create -f R_analysis_env.yml
```

### 手工创建环境（可选）

以下为手工逐步安装命令（适用于不想用 yml、或需要按历史版本约束精确安装的情况）。
**不要一次性把多行粘贴进终端，部分命令会要求交互确认（如输入 y 继续）。**

先安装 Conda/Mamba：[conda 安装说明](https://conda.io/projects/conda/en/latest/user-guide/install/linux.html)。更多参考见 [Getting started with conda](https://towardsdatascience.com/getting-started-with-python-environments-using-conda-32e9f2779307) 与 [Conda cheat sheet](https://docs.conda.io/projects/conda/en/4.6.0/_downloads/52a95608c49671267e40c689e0bc00ca/conda-cheatsheet.pdf)。

**RiboSeq 环境（处理 RPFs）**——依赖 fastQC、cutadapt、UMI-tools、bbmap、SAMtools(需 v1.9)、pysam、biopython：

```console
conda create --name RiboSeq
conda activate RiboSeq
conda install -c bioconda fastqc
conda install -c bioconda cutadapt
conda install -c bioconda umi_tools
conda install -c bioconda bbmap
conda install -c bioconda samtools=1.9
conda install -c bioconda pysam
conda install -c anaconda biopython
conda deactivate
```

**RNAseq 环境（处理 Totals）**——额外使用 RSEM + bowtie2（也可用 STAR）。RSEM 会顺带安装 samtools，需强制固定为 1.9，避免 `libcrypto.so.1.0.0` 加载错误；bowtie2 安装时曾出现需要把 tbb 降级到 2020.2 的问题（见 [biostars 讨论](https://www.biostars.org/p/494922/)）：

```console
conda create --name RNAseq
conda activate RNAseq
conda install -c bioconda fastqc
conda install -c bioconda cutadapt
conda install -c bioconda umi_tools
conda install -c bioconda rsem
conda install -c bioconda samtools=1.9 --force-reinstall
conda install -c bioconda bowtie2
conda install tbb=2020.2
conda install -c bioconda bbmap
conda install -c anaconda biopython
conda deactivate
```

## 4. 环境配置

本流程支持 **Conda** 和 **Local** 两种环境模式。

### Conda 模式 (默认/推荐)

在此模式下，`run.sh` 会自动检查并激活相应的 Conda 环境。请先按[第 3 节](#3-依赖安装)创建以下环境：

- **RiboSeq**: 用于 RPFs 流程

- **RNAseq**: 用于 Totals 流程

- **R\_analysis**: 用于 Downstream 流程

### Local 模式

如果您希望使用系统自带的工具或已在当前 Shell 中手动激活了环境，请使用 `--env-mode local` 参数。
在此模式下，脚本不会尝试激活 Conda 环境，而是直接调用系统 PATH 中的工具。请确保所有必要的工具（如 `fastqc`, `cutadapt`, `Rscript` 等）均可用。

## 5. 运行方法

### 基础用法

```bash
./run.sh --pipeline [RPFs|Totals|Downstream] [选项]
```

### 常用命令示例

**1. 运行 RPFs 完整流程 (使用 Conda 环境)**

```bash
./run.sh --pipeline RPFs
```

**2. 运行 Totals 完整流程 (使用 Local 环境)**

```bash
./run.sh --pipeline Totals --env-mode local
```

**3. 运行 Downstream 分析**

```bash
./run.sh --pipeline Downstream
```

**4. 查看特定流程的步骤列表**

```bash
./run.sh --pipeline RPFs --list-steps
```

**5. 仅运行特定步骤**
例如，仅运行 RPFs 流程中的接头去除步骤：

```bash
./run.sh --pipeline RPFs --step RPFs_1_adaptor_removal.sh
```

## 6. 详细参数说明

| 参数               | 说明                                                         | 默认值                  |
| :----------------- | :----------------------------------------------------------- | :---------------------- |
| `--pipeline`       | **\[必选]** 选择要运行的流程: `RPFs`, `Totals`, `Downstream` | -                       |
| `--env-mode`       | 环境模式: `conda` (自动激活环境) 或 `local` (使用当前环境)   | `conda`                 |
| `--step`           | 仅运行指定步骤的脚本 (例如 `RPFs_1_adaptor_removal.sh`)      | 运行所有步骤            |
| `--list-steps`     | 列出所选流程的所有可用步骤并退出                             | -                       |
| `--output-dir`     | 指定输出目录                                                 | `./results`             |
| `--input-csv`      | 指定样本信息文件                                             | `./info.csv`            |
| `--threads`        | 线程数                                                       | `4`                     |
| `--rpf-adaptor`    | RPF 接头序列                                                 | `TGGAATTCTCGGGTGCCAAGG` |
| `--totals-adaptor` | Totals 接头序列                                              | `AGATCGGAAGAG`          |

## 7. 运行顺序

`run.sh` 会按照预定义的顺序依次执行脚本。

- **RPFs 流程**: QC -> 接头去除 -> UMI 提取 -> 比对 -> 去重 -> 计数 -> 汇总

- **Totals 流程**: QC -> 接头去除 -> UMI 提取 -> 比对 -> 去重 -> 定量

- **Downstream 流程**: 各种 R 语言统计分析与绘图脚本

建议初次运行时使用默认设置跑通完整流程。

## 8. GSEA 基因集来源（MSigDB）

下游 GSEA（fgsea）分析使用的人源（human）基因集 `.gmt` 文件存放在
[R\_scripts/gsea/MSigDB/](R_scripts/gsea/MSigDB/)，版本为 **v2026.1**，包含：
Hallmark（`h.all`）、KEGG（`c2.cp.kegg_legacy` / `c2.cp.kegg_medicus`）、
GO 生物过程 / 细胞组分 / 分子功能（`c5.go.bp` / `c5.go.cc` / `c5.go.mf`）。

- 来源：[MSigDB Collections - Human](https://www.gsea-msigdb.org/gsea/msigdb/human/collections.jsp)；
  在 MSigDB 官网注册账号后即可免费下载对应的 `.gmt` 文件；

- 如需更新或改用其他版本，请保持文件名与
  [read\_human\_GSEA\_pathways.R](R_scripts/gsea/read_human_GSEA_pathways.R)
  中匹配的模式一致（`h.all.*`、`c5.(go.)?bp|mf|cc.*`、`c2.cp.kegg.*` 等）。

---

# 流程说明与手动执行详解

> 本部分为流程的原理说明、分步执行要点与常见问题排查，与上文第 1～8 节的「运行指南」互为补充：
> 第 5/7 节讲的是用 `run.sh` 一键运行，本节讲的是每个脚本“做了什么、为何这样做、何时需要改”，便于按实验细节定制或排查问题。

## 9. 脚本分工与项目组织

### 9.1 流程设计总览

本流程面向具备基础生信能力的用户，设计上让**每个脚本都能独立阅读、按实验修改**，以适配不同建库方式（不同接头序列、是否使用 UMI 等）。数据处理分三层：

- **Shell 脚本**（`Shell_scripts/`）：调用外部工具与自定义 Python 脚本，逐步完成数据处理的全部环节；
- **Python 脚本**（`Python_scripts/`）：承担 RPF 计数、区域汇总、格式转换等纯计算工作，一般无需修改，可跨项目复用；
- **R 脚本**（`R_scripts/`）：读取处理后统一格式的数据，生成文库 QC 图、用 DESeq2 做差异表达（DE）/ 翻译效率（TE）分析，或评估核糖体占据沿 mRNA 的位置富集（meta plots、密码子占据率等）。

> 说明：本仓库整理版额外提供了 `run.sh` 一键编排（见第 4～7 节），并把环境管理自动化；需要细粒度控制或排查问题时，仍可按本节与第 10 节手动分步执行。

### 9.2 FASTA 过滤与重格式化（Filtering / Reformatting 原理）

用于比对的 FASTA 由用户按物种选择。小鼠/人类的蛋白编码转录组可从 GENCODE 官网下载，但其中含大量**没有 UTR、或 CDS 长度不能被 3 整除**的转录本——这类转录本注释质量往往欠佳，也未必进行典型的帽依赖翻译起始，因此不建议直接用于比对。

`Filtering_GENCODE_FASTA.py` 会按以下条件过滤，仅保留：

- 由 HAVANA 人工注释的转录本；
- 同时具有 5'UTR 与 3'UTR 的转录本；
- CDS 长度可被 3 整除的转录本；
- CDS 以起始密码子（nUG）开头的转录本；
- CDS 以终止密码子结束的转录本；
- 排除所有 PAR_Y 转录本。

> 效果示例：对人 v38 蛋白编码 FASTA 运行后，转录本由 106,143 条（20,361 个基因）过滤到 52,059 条（18,995 个基因）。

GENCODE FASTA 的 header 行包含大量附加信息，例如：

> `ENST00000641515.2|ENSG00000186092.7|OTTHUMG00000001094.4|OTTHUMT00000003223.4|OR4F5-201|OR4F5|2618|UTR5:1-60|CDS:61-1041|UTR3:1042-2618|`

`Reformatting_GENCODE_FASTA.py` 会把 header 中的附加信息提取为便于 R 读取的 csv（如转录本 ID ↔ gene/protein ID、region lengths 等），同时把 FASTA 头重写为仅含转录本 ID——这样比对后的下游分析只需携带转录本 ID，更简洁。

**建议**：下载 GENCODE FASTA 后先依次运行上述两个脚本，得到“过滤 + 重格式化”的 FASTA 再用于比对。注意：**这两个脚本只适用于 GENCODE 官网下载的 FASTA**；对应产物（`*_filtered.fa`、`*_reformatted.fa`、`transcript_info/*.csv`）的生成与参考目录布局见第 2 节。

### 9.3 项目目录与公共变量（手动模式约定）

运行任何脚本之前，建议先为实验建立一个**独立的父目录**（存放该实验的原始数据、处理产物与全部图形），再按以下方式组织（脚本输出路径基于该结构设计，改动会影响可追溯性）：

1. 在父目录下创建子目录，存放本仓库的 Shell（`.sh`）与 R（`.R`）脚本；把 `Python_scripts/` 加入 `$PATH`（在 `~/.bashrc` 中追加 `export PATH=$PATH:path/to/Python_scripts`），以便任意目录直接调用 Python 脚本；
2. 运行任何其他脚本前，先编辑 `Shell_scripts/common_variables.sh` 与 `R_scripts/common_variables.R`：写入 RPF 与 Totals 的 fastq 文件名（不含 `.fastq` 后缀）、父目录路径、接头序列、比对用的 FASTA 与 RSEM 索引路径；同一物种的项目通常共享 FASTA/索引，建议将其放在项目目录之外；
3. 另需一个**区域长度（region lengths）csv**：无表头，按 `transcript_ID, 5'UTR length, CDS length, 3'UTR length` 顺序列出蛋白编码 FASTA 中全部转录本（`RiboSeq_env` 中的 Reformatting 产物即可生成），并在 `common_variables.sh` 中指向该文件；
4. 编辑完成后运行 `makeDirs.sh`（或手工）建立目录结构，把原始 fastq 放入 fastq 目录（可从 GEO 下载，或对自有 bcl 数据用 demultiplex 脚本，均以 `.gz` 亦可——fastQC 与 cutadapt 支持压缩输入，但脚本内文件名需带 `.gz` 后缀）。

> 说明：在本仓库整理版中，上述项目级参数已被 `run.sh` 的 `--output-dir / --input-csv / --threads / --rpf-adaptor / --totals-adaptor` 等选项取代（见第 6 节）；手动逐脚本运行时仍适用本节约定。数据下载/拼接/改名/解压等辅助功能整理在 `Shell_scripts/Data_Preparation/`（`DataPrep_1_Download.sh`、`DataPrep_1_Demultiplex.sh`、`DataPrep_2_Concatenate.sh`、`DataPrep_3_Rename.sh`、`DataPrep_4_Unzip.sh`，或 `DataPrep_all.sh` 一次完成）。

## 10. 分步执行说明

> 通用提醒：每个步骤的输出都应**用 FastQC 人工目检**，确认结果符合预期再进入下一步。

### 10.1 Totals（常规 RNA-seq）主线

RPF 需要比对到「每基因仅一条代表转录本」的转录组。RSEM 会估计基因内各 isoform 的相对表达，可用于挑选每基因最丰的转录本；RSEM 运行较慢（视 reads 数与转录组大小，通常超过 24 h），**建议先处理 Totals**。

运行 Totals 相关脚本前激活环境：`conda activate RNAseq`。

1. **测序 QC —— `Totals_0_QC.sh`**：对全部 Totals fastq 运行 fastQC，输出到 fastQC 目录；报告给出每个 fastq 的 reads 数及基础质控。
2. **去接头 —— `Totals_1_adaptor_removal.sh`**：建库时 3' 接头（及 UMI）会紧接片段被测序，须去除以免影响比对。脚本用 cutadapt 去除 `common_variables.sh` 指定的接头及其下游序列，同时从 3' 端按质量阈值（示例 q20）剪切低质量碱基，并丢弃短于/长于设定长度的 reads（示例 ≥30 nt）；之后对输出 fastq 再跑 fastQC 并人工目检。
3. **UMI 提取 —— `Totals_2_extract_UMIs.sh`**：若建库用了 UMI（如 CORALL Total RNA-Seq 试剂盒为 5' 端 12 nt），先用 umi_tools 提取并写入 read 名。
4. **比对与去重**：`Totals_3a_align_reads_transcriptome.sh` 用 bowtie2 把 reads 比对到参考转录组；随后 `Totals_4a_deduplication_transcriptome.sh` 用 umi_tools 对 BAM 去 PCR 重复。**若建库无 UMI**，跳过第 3 步与第 4a 步，并相应修改 `Totals_3a` 与 `Totals_5` 的输入 fastq 文件名。
5. **基因/转录本定量 —— `Totals_5_isoform_quantification.sh`**：以去重 BAM 为输入运行 RSEM，输出每个基因（`.genes`）与每条转录本（`.isoforms`）的预测 counts 与 TPM；可作为 DESeq2 的输入，也可用于挑选最丰转录本。
6. **（可选）基因组比对 —— `Totals_3b_align_reads_genome.sh` + `Totals_4b_deduplication_genome.sh`**：需用 IGV 等基因组浏览器可视化时，用 STAR 将 reads 比对到基因组（建议为 STAR 单独建环境）。
7. **计算最丰转录本 —— `calculate_most_abundant_transcript.R` + `Totals_6a_write_most_abundant_transcript_fasta.sh`**：前者从 RSEM 结果生成最丰转录本 csv（含 gene ID/symbol）与纯文本 ID 列表；后者用 `filter_FASTA.py` 按 ID 列表过滤蛋白编码 FASTA。
8. **Reads 统计 —— `Totals_6b_extract_read_counts.sh` + `Totals_read_counts.R`**：提取各阶段 reads 数量与比对率并绘图。

> 首次使用或处理外部数据时，强烈建议按上述分步执行；熟悉后可改用一键脚本 **`Totals_all.sh`**（注意：它不对中间文件跑 fastQC，注释也更简略）。

### 10.2 RPFs 主线

运行 RPF 相关脚本前激活环境：`conda activate RiboSeq`。

1. **测序 QC —— `RPFs_0_QC.sh`**：对全部 RPF fastq 运行 fastQC。**判断 fastq 是否已被预处理**：长度分布是关键线索——完全未处理的 reads 长度应等于测序循环数（如 75 cycles 即全为 75 bp）；对标准 RPF 文库（RPF ~30 nt + 两端各 4 nt UMI + 3' 接头），去接头后长度分布应呈一段范围、峰值约 38 nt；若峰靠近 30 nt 则说明 UMI 也可能已去除。接头含量（adaptor content）模块同样可作佐证（约第 38 nt 后出现污染说明未去接头）。
2. **去接头 —— `RPFs_1_adaptor_removal.sh`**：cutadapt 去除 3' 接头（含 UMI 场景需按文库把最小长度设为 ≥30 nt 以便去重工具正确工作；无 UMI 时改为 20–40 nt），同时按 q20 剪切低质量碱基、过滤长度范围（示例 30–50 nt）。输出再跑 fastQC 目检。
3. **UMI 提取 —— `RPFs_2_extract_UMIs.sh`**：以 nextflex 试剂盒为例，UMI 为 read 两端各 4 nt。
4. **比对与去重**：`RPFs_3_align_reads.sh` 用 bbmap **先比对 rRNA，再比对 tRNA**，每次比对都输出「比对成功/未比对」两个 fastq；未比对上 rRNA/tRNA 的 reads 再比对到蛋白编码转录组。随后 `RPFs_4_deduplication.sh` 用 umi_tools 去重。**若建库无 UMI**，跳过第 3 步与第 4 步并修改 `RPFs_3` 与 `RPFs_5` 的输入文件名。
   - **转录组选择与多重比对**：强烈建议用 Totals 结果先算每基因最丰转录本并过滤 FASTA（见 10.1 第 7 步），再供 RPF 比对；蛋白编码转录组还应先用 `Filtering_GENCODE_FASTA.py` 过滤（HAVANA 注释、双 UTR、CDS %3 且含起始/终止密码子，见 9.2）。
   - 三个阶段的产物都建议用 fastQC 检查：蛋白编码比对 reads 预期在 28–32 nt 出现明显峰，rRNA/未比对 reads 长度分布更宽（反映切胶范围）。
5. **计数 —— `RPFs_5_Extract_counts_all_lengths.sh`**：对每个样本、每个读长（脚本内循环设定）调用 `counting_script.py`（改写自 [RiboPlot](https://pythonhosted.org/riboplot/ribocount.html)）生成 `.counts` 文件。`.counts` 为纯文本：每两行一个转录本——第一行转录本 ID，第二行为制表符分隔的逐位置起始计数，值的个数与转录本长度一致。输入为排序 BAM，且同目录需有对应的 `.bai` 索引。
6. **文库 QC**：
   - `RPFs_6a_summing_region_counts.sh` → `region_counts.R`；
   - `RPFs_6b_summing_spliced_counts.sh` → `heatmaps.R` / `offset_plots.R`（剪接边界、起始/终止位点 profile）；
   - `RPFs_6c_periodicity.sh` → `periodicity.R`；
   - `RPFs_6d_extract_read_counts.sh` → `RPFs_read_counts.R`。

   由 QC 图判断文库是否为「真 RPF」的三个判据：① read 长度分布峰值在 28–32 nt；② 明显的三核苷酸周期性；③ CDS 区域富集而 3'UTR 相对缺失。据此决定下游 DE/密码子分析纳入哪些 read 长度。**offset 图**用于确定 P-site 偏移：观察起始密码子上游首个 read 峰（对应 P 位点位于起始密码子的 RPF），典型值 12–13 nt，不同读长可能需微调；该值用于 `RPFs_7` 使最终 counts 指向 P 位点密码子第 1 个碱基而非 read 起点。

7. **最终计数 —— `RPFs_7_Extract_final_counts.sh`**：按选定的 read 长度与 offset，生成仅含指定长度、已应用偏移的最终 `.counts`。
8. **CDS 汇总 —— `RPFs_8a_CDS_counts.sh`**（`summing_CDS_counts.py`）：**输出即 DESeq2 的输入**。默认去掉 CDS 前 20 与后 10 个密码子以减小起始/终止位点偏倚，只统计活跃延伸的核糖体；另可只保留 in-frame reads——建议 DE 分析纳入全部 reading frame（out-of-frame 仍多为真 RPF），密码子水平分析才只用 in-frame reads（out-of-frame 无法高置信解读到密码子层）。
9. **5'UTR 汇总 —— `RPFs_8b_UTR5_counts.sh`**（`summing_UTR5_counts.py`）：统计整个 5'UTR 内的计数（用于 uORF 层面观察，非单 uORF 粒度）。
10. **转 csv —— `RPFs_8c_counts_to_csv.sh`**（`counts_to_csv.py`）：便于 R 读取。
11. **密码子占据 —— `RPFs_8d_count_codon_occupancy.sh`**（`count_codon_occupancy.py`）：对每条 RPF 判定 A/P/E 位点及其上下游各 2 个密码子并累加；`codon_occupancy.R` 据此估计各密码子的相对延伸速率（A 位出现次数 / 7 个位点总出现次数），从而在转录组范围内校正 mRNA 丰度与起始速率差异。

> 首次使用或处理外部数据时建议分步执行；熟悉后可改用一键脚本 **`RPFs_all.sh`**（不对中间文件跑 fastQC，注释更简略）。
> 数据确认处理无误后，可删除不再需要的中间文件；**原始 `.fastq` 切勿删除**。

## 11. 常见问题排查

### 11.1 行尾 `\r` 报错

Windows 行尾为 `\r`，Linux/mac 为 `\n`；在 Windows 文本编辑器里编辑过的脚本可能同时带上 `\n` 与 `\r`，在 Linux/mac 下会报：

`/usr/bin/env: 'bash\r': No such file or directory`

检查与修复：Notepad++ → View → Show symbol → Show all characters 查看隐藏字符；若行尾有 `\r`，用查找替换（勾选正则）把所有 `\r` 删除，仅保留 `\n`。

### 11.2 路径不一致

`common_variables.sh`（Linux 路径）与 `common_variables.R`（PC 路径）中的父目录路径必须指向同一目录、写法不同：终端进入该目录用 `pwd` 得到完整 Linux 路径后填入 shell 脚本；R 端用 `getwd()` 获取当前目录，父目录通常在其上两级。
