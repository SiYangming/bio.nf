# subworkflow/umi\_tools\_extract\_dedup — 可复用 UMI 阶段编排

将 UMI 处理提炼为可复用组合：**umi\_tools extract（SE/PE）→（中间比对由调用流程提供）→ umi\_tools dedup**。参照 [subworkflow/fastp\_bwa\_samtools](../fastp_bwa_samtools/fastp_bwa_samtools.md) 的 subworkflow 形态（md + meta.yaml + native/main.py + snakemake 聚合）。

* 元数据：同级 [meta.yaml](meta.yaml)（stages / inputs / outputs / execution）。

* **为什么不含比对器**：UMI extract/dedup 与比对器解耦——riboseq 的 RPF 走 bbmap（rRNA→tRNA→PC 分层），rnaseq(Totals) 走 bowtie2 转录组 / STAR 基因组；把"extract→比对→dedup"固化成单一套路会绑定比对器，反而不可复用。故本组合只编排 UMI 两阶段，`aligned_bam` 由调用流程在 extract 后产出。

## Stage 图（DAG）

```
reads_R1[,R2] ──► umi_tools extract（--bc-pattern / regex；UMI 写入 read name）
                     │
                     ▼ *_umi.fastq[.gz]
              [调用流程自行比对：bbmap / bowtie2 / STAR / …]
                     │
                     ▼ aligned.bam（read name 含 UMI）
              umi_tools dedup（--method / --paired / [--output-stats]）
                     │
                     ▼ dedup.bam（去 PCR 重复）
```

stages 声明见 [meta.yaml](meta.yaml)：`umi_extract` → `umi_dedup`。

## native 编排（native/main.py）

入口：`python subworkflow/umi_tools_extract_dedup/native/main.py --list-stages | --dry-run（默认）| --real`（仓库根执行）。逐 stage 委托 `modules/umi_tools/native/main.py`：

```bash
# SE 示例（dry-run 预览）
python subworkflow/umi_tools_extract_dedup/native/main.py --sample-id s1 \
    --reads-r1 raw/s1_R1.fastq.gz --bc-pattern NNNNNNNN \
    --aligned-bam align/s1.sorted.bam --stats

# PE + regex（Ribo-seq 惯用；中间比对后接 dedup --paired）
python subworkflow/umi_tools_extract_dedup/native/main.py --sample-id s1 \
    --reads-r1 raw/s1_R1.fastq.gz --reads-r2 raw/s1_R2.fastq.gz --paired \
    --bc-pattern '^(?P<umi_1>.{4}).+(?P<umi_2>.{4})$' --extract-method regex \
    --aligned-bam align/s1.pc.sorted.bam --stats
```

* extract 输出：`<outdir>/extract/<sample>.umi.fastq.gz`（SE）/ `<sample>_{R1,R2}.umi.fastq.gz`（PE）；

* dedup 输出：`<outdir>/dedup/<sample>.dedup.bam`（`--stats` 时另出 `<outdir>/stats/<sample>_*`）。

## Snakemake 聚合（snakemake/umi\_tools\_extract\_dedup.smk）

[umi\_tools\_extract\_dedup.smk](snakemake/umi_tools_extract_dedup.smk) 相对 include 模块层三个单规则 smk（`umi_tools_extract_se / _pe / umi_tools_dedup`），供 Snakemake 主文件一键 include：

```python
include: "subworkflow/umi_tools_extract_dedup/snakemake/umi_tools_extract_dedup.smk"
```

* config 契约即各模块 smk 头注（`umi_input_fastq[2]` / `umi_output_fastq[2]` / `umi_tools.bc_pattern…` / `umi_input_bam` / `umi_output_bam` / `umi_dedup_stats_prefix`）；

* 若主 Snakefile 已按 `modules/umi_tools/snakemake/*.smk` glob include，请二选一（避免规则重复定义）；

* 规则本身不执行比对：调用流程把比对后 BAM 接到 `umi_input_bam` 即可（见 workflow/riboseq 的接线说明）。

## workflow/riboseq 引用（接线）

* native 路线：经典 `Shell_scripts/{RPFs_2_extract_UMIs.sh, RPFs_4_deduplication.sh, Totals_2/4a/4b_*.sh}` 是 UMI 阶段的**等价实现**（直接调 umi\_tools，含各自 bc-pattern/正则与 --output-stats）；新的可复用形态由本 subworkflow 编排入口提供（命令同上方示例），两者产物语义一致。

* snakemake 路线：Snakefile 可改用本组合 include（或在 glob 之外额外 include 本聚合文件并按需给 config），UMI 规则与其它比对/定量规则以 `rule all` 串联（参见 workflow/riboseq 数据流图）。

