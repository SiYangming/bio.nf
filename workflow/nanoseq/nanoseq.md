# workflow/nanoseq — Nanopore RNA-seq 复合流程

Nanopore 长读 RNA-seq 分析流程：可选 SRA 下载 / dorado 碱基识别 → minimap2 比对 → samtools 排序与 QC → FLAIR consensus → StringTie 组装 → TransDecoder/TD2 ORF 预测。

* 元数据：本目录同级 [meta.yaml](meta.yaml)（stages / inputs / outputs / execution）。

* 本流程为**目录形态**（对齐 [riboseq/](../riboseq/riboseq.md)）：**多步组合**经典脚本集中于 [native/](native/)（`run_*.sh`），流程编排入口 [native/main.py](native/main.py)；单一命令批处理脚本（`batch_*.sh`）留于所属模块 `sra-tools/native/`；单步原子能力在 `modules/<sw>/`（main.py / snakemake 规则）；Snakemake 集成内容已并入本文档（原 `snakemake/` 目录已移除）。

## 原始来源与致谢

* 各软件阶段拆分为原子模块技能（`modules/`）：**多步组合脚本**（`run_*.sh`）统一归档于本目录 [native/](native/)（见「历史留存」），**单一命令批处理**（`batch_*.sh`）与单步辅助脚本（如 `fix_gtf.awk`、`alignment_summary.py`）留在所属模块。

* **Nextflow**：nf-core 官方已有 [nf-core/nanoseq](https://github.com/nf-core/nanoseq)（Nanopore DNA/RNA 分析，v3.1.0）——按「官方已有流程不建目录」规则**不建本地 nextflow/ 目录**，需 Nextflow 时直接用官方流程（本地路线为 FLAIR/StringTie/TransDecoder，与官方 bambu 不同；需定制时经各模块 `nextflow/local` 自组装）。

## 流程结构与数据流

```
[SRA prep: sra-tools prefetch+fasterq-dump]（可选，需 srr_id）
[dorado basecall: fast5 -> fastq]（可选，rna004_130bps_sup@v5.1.0）
fastq ──[minimap2 align -x splice -uf -k14]──> BAM
  ──[samtools sort/index/flagstat]──> 01_MINIMAP2_ALIGN/sorted_bam/{sample}.sorted.bam
  ──[flair bam2bed12 -> annotate -> collapse]──> 02_FLAIR_CONSENSUS/CONSENSUS_FASTA/{sample}.flair.collapse.fasta
  ──[stringtie assemble -> fix_gtf -> merge（跨样本）]──> 03_STRINGTIE/MERGED_GTF/stringtie_merged_nonredundant.gtf
  ──[transdecoder 或 td2 longorfs -> predict]──> 04_1_TRANSDECODER… / 04_2_TD2…（pep/cds/gff3）
```

## 依赖的原子模块（modules/）

| 阶段         | 软件                 | 模块实现（native 入口）                                                 |
| ---------- | ------------------ | --------------------------------------------------------------- |
| SRA 下载（可选） | sra-tools          | `modules/sra-tools`（prefetch / fasterq-dump）                    |
| 碱基识别（可选）   | dorado             | `modules/dorado`（basecall，rna004\_130bps\_sup\@v5.1.0）          |
| 比对         | minimap2           | `modules/minimap2`（`-x splice -uf -k14`）                        |
| 排序/QC      | samtools           | `modules/samtools`（sort / index / flagstat）                     |
| consensus  | flair              | `modules/flair`（bam2Bed12 → identify\_gene\_isoform → collapse） |
| 组装         | stringtie          | `modules/stringtie`（assemble → fix\_gtf → merge）                |
| ORF 预测     | transdecoder / td2 | `modules/transdecoder`、`modules/td2`（longorfs / predict）        |

各模块含流程级原子规则与单步辅助（`<sw>/snakemake/` 规则 + 脚本）；**阶段级多步经典脚本**不再散落于模块，统一归档于本流程 [native/](native/)（见「历史留存」）。

## 执行方式

### A. 编排入口 main.py（dry-run 预览；--real 执行）

流程编排入口为 [native/main.py](native/main.py)（约 286 行样本循环编排器）：

```bash
python workflow/nanoseq/native/main.py --list-stages   # 列出 stages（按 meta.yaml）
python workflow/nanoseq/native/main.py --dry-run        # 打印各 stage 将调用的命令（默认）
python workflow/nanoseq/native/main.py --real           # 真实执行（需各工具已安装）
```

逐 stage 手工串联（命令在**仓库根**执行，前一阶段输出即后一阶段输入）：

```bash
python modules/minimap2/native/main.py align --help     # 先查看各模块参数
python modules/flair/native/main.py collapse --help
```

**编排要点（原编排器逻辑，已记录于此）**：

* 每个样本循环执行；比对后固定产出 `sorted_bam`，供 samtools QC、FLAIR 与 StringTie 共用；

* FLAIR 链路：`bam2Bed12 → identify_gene_isoform → collapse`（依赖参考 fasta 与 GTF）；StringTie 先逐样本 assemble + `fix_gtf` 修复坐标，最后**跨样本 merge** 产出非冗余 GTF；

* ORF 预测二选一：TransDecoder（`longorfs → predict`）或 TD2（`longorfs → predict`，可选 orffinder）；

* 可选前置：`sra-tools prefetch + fasterq-dump`（样本表需 `srr_id`）或 `dorado basecall`（fast5 输入时）；

* 输出目录约定：01\_MINIMAP2\_ALIGN / 02\_FLAIR\_CONSENSUS / 03\_STRINGTIE / 04\_1\_TRANSDECODER / 04\_2\_TD2（见 [meta.yaml](meta.yaml) outputs）。

* 03/04 尾段（StringTie 组装 → ORF 预测）也可用本流程 [native/](native/) 经典脚本一键串联：`01_run_alignment_bam.sh`（可选，比对）→ `02_run_flair_consensus.sh` → `03_run_stringtie.sh` → `04_run_td2_orf_prediction.sh`（需按项目修改硬编码路径）；逐原子步骤仍走 `modules/<sw>/native/main.py`。

> 流程编排入口 [native/main.py](native/main.py)（`--list-stages` / `--dry-run` / `--real`）即上文编排逻辑的实现；原 `snakemake/` 集成目录内容并入下文「执行方式 B」。

### B. Snakemake（按需在项目内重建；仓库不再内置 snakemake/ 目录）

原 `workflow/nanoseq/snakemake/`（Snakefile / Snakefile.template / common.smk / config.yaml / samples.schema.yaml / scripts/samplesheet\_group\_summary.py）已按「目录仅剩文档则并至 workflow 根」规则并入本文档并移除。需要 Snakemake 执行时，在**项目目录**内重建集成层：

1. 建立 `project/snakemake/`，放入主文件与公共件：

   * `Snakefile`：`include: "rules/common.smk"` + 各工具规则（将 `modules/{minimap2,samtools,flair,stringtie,transdecoder,td2,dorado,sra-tools}/snakemake/` 的规则拷入项目 `rules/`，或改 include 指向模块绝对路径）；

   * `common.smk`：样本表解析（列 `group,replicate,barcode,input_file,fasta,gtf`）；

   * `config.yaml` 关键项：`samplesheet`（指向项目 samplesheet\_local.csv）、`exec_mode: docker|conda|native`、`output_dir`、工具版本（minimap2 2.30 / samtools 1.23 / flair 3.0.0b1 / stringtie 3.0.3 / transdecoder 5.7.1 / td2 1.0.6）；

   * `samples.schema.yaml`：samplesheet 校验 schema。
2. （可选）分组汇总脚本 `samplesheet_group_summary.py`（snakemake-global 脚本：读 samplesheet 按 `group/replicate` 汇总，输出 per-group / combined / report）——需用时在项目规则中按此逻辑重建。
3. 运行（执行入口为仓库共享 [scripts/run\_smk.sh](../../scripts/run_smk.sh)）：

```bash
cd project/snakemake
bash <repo>/scripts/run_smk.sh -n        # dry-run（预演）
bash <repo>/scripts/run_smk.sh           # 执行（exec_mode 见 config.yaml，默认 docker）
```

### C. Nextflow（nf-core 官方已有 → 不建本地目录）

直接运行 [nf-core/nanoseq](https://github.com/nf-core/nanoseq)（`nextflow run nf-core/nanoseq -profile test,docker`）；本地路线（FLAIR/StringTie/TransDecoder）需 Nextflow 时用各模块 `nextflow/local` 自组装。

## 历史留存

**阶段级多步组合脚本**（流程范围，非单步原子调用；硬编码项目路径，真实运行前需按项目修改）→ 统一存放于本目录 [native/](native/)：

| 脚本                          | 对应阶段         | 内容                                                                                                                     |
| --------------------------- | ------------ | ---------------------------------------------------------------------------------------------------------------------- |
| `01_run_alignment_bam.sh`    | 01 比对        | minimap2 比对 → sorted BAM（产出 `alignment_results_bam/sorted_bam/`，供 StringTie/FLAIR）                                     |
| `02_run_flair_consensus.sh`  | 02 FLAIR     | bam2Bed12 → identify\_gene\_isoform → collapse（direct RNA-seq 参数）                                                      |
| `03_run_stringtie.sh`        | 03 StringTie | 逐样本 assemble + 坐标修复 + 跨样本 merge（产出 `fixed_gtf/*.stringtie.fixed.gtf` 与 `merged_gtf/stringtie_merged_nonredundant.gtf`） |
| `04_run_td2_orf_prediction.sh` | 04 TD2（输出目录 04\_2\_TD2） | 样本/merged 双模式：GTF→cDNA（借 TransDecoder `gtf_genome_to_cdna_fasta.pl`）→ TD2.LongOrfs → TD2.Predict → 编码区统计               |

**单步辅助脚本 / 规则配套**（原子能力；正式入口为 `modules/<sw>/native/main.py` 或 `<sw>/snakemake/` 规则，仍留在对应模块）：

| 资产                                      | 位置                                                                                                     |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| flagstat 汇总 helper                      | `modules/samtools/native/alignment_stats.sh`、`modules/samtools/snakemake/alignment_summary.py` |
| StringTie 坐标修复                          | `modules/stringtie/snakemake/fix_gtf.awk`                                                          |
| FLAIR BED12 辅助                          | `modules/flair/snakemake/bed12_add_trailing_commas.py`                                              |
| SRA 单一命令批处理（prefetch / fastq-dump 批量循环） | `modules/sra-tools/native/batch_prefetch.sh`、`batch_sra_to_fastq.sh`、`batch_sra_to_fastq_parallel.sh`  |

## 测试数据（不随仓库存储，按需下载）

数据来源：**nf-core/test-datasets** **`nanoseq`** **分支** **`modification_fast5_fastq`** **路径**（<https://github.com/nf-core/test-datasets/tree/nanoseq/modification_fast5_fastq> ），含 HEK293T-METTL3-KO-rep1 与 HEK293T-WT-rep1 两个样本的原始 fast5 与 basecalled fastq（Nanopore RNA-seq）。上游无版本标签，以分支 `nanoseq` + 路径为准；文件为官方原样二进制，未作任何修改。

> 本仓库曾内置两个样本各 5 个 fast5 的精简子集（KO 5 + WT 5）用于快速冒烟；按「测试数据不随仓库存储」规则已移除，均可从下方链接获取完整数据后自行截取。

下载完整数据：

```bash
# 方式一：git clone 只取 nanoseq 分支（仓库较大，建议 sparse-checkout）
git clone --branch nanoseq --depth 1 --filter=blob:none --sparse \
    https://github.com/nf-core/test-datasets.git
cd test-datasets
git sparse-checkout set modification_fast5_fastq

# 方式二：单文件 raw 下载（示例）
curl -sfL \
  https://raw.githubusercontent.com/nf-core/test-datasets/nanoseq/modification_fast5_fastq/HEK293T-METTL3-KO-rep1/fastq/HEK293T-METTL3-KO-rep1.fastq.gz \
  -o HEK293T-METTL3-KO-rep1.fastq.gz
```

用法：

* **fastq**：可直接作为流程输入（Snakemake，或按上文「执行方式 A」直接串联 minimap2 / FLAIR / StringTie / TransDecoder 等模块）。

* **fast5**：供 dorado basecall 冒烟测试（需解压 fast5 至目录）。

```bash
# 冒烟：用下载的 fastq 直接调用 minimap2 模块（仓库根执行，参考「执行方式 A」）
python modules/minimap2/native/main.py align \
    --reads "$PWD/testdata/HEK293T-METTL3-KO-rep1/fastq/HEK293T-METTL3-KO-rep1.fastq.gz" \
    --reference ref.fa --outdir /tmp/nano_test
```

## 容器与执行注意

* 各模块容器为 Debian bookworm-slim 最小化；`docker run` 必须带 `-u $(id -u):$(id -g)` 避免 root 持有输出文件。

* shell 启动统一使用共享 [scripts/run\_smk.sh](../scripts/run_smk.sh)。

