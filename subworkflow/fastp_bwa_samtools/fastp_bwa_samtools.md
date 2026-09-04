# subworkflow/fastp_bwa_samtools — 短读 DNA 比对+QC 组合（示例骨架）

最小的短读 DNA 复合流程示例骨架（fastp → bwa-mem2 mem → samtools sort/index → QC 可选），用于演示 **subworkflow 组合如何按仓库规则存档**。

- 元数据：同级 [meta.yaml](meta.yaml)（stages / inputs / outputs / execution）。
- 本组合为**目录形态**：`subworkflow/fastp_bwa_samtools/` 下含 [fastp_bwa_samtools.md](fastp_bwa_samtools.md) + [meta.yaml](meta.yaml) + [native/main.py](native/main.py)（`--list-stages` / `--dry-run` / `--real` 流程编排入口）。
- 注意：这是**存档 + 模板 + 编排骨架示例**，不是生产级可直接跑的 pipeline；`fastp` / `bwa-mem2` / `multiqc` 目前为**占位软件**（modules/ 尚未构建其 native），落地前需补齐。

## Stage 图（DAG）

```
reads_R1,R2 ──► fastp (trim + QC)
                   │
                   ▼ clean_fq
               bwa-mem2 mem (reference.idx)
                   │
                   ▼ BAM
              samtools sort + index
                   │
                   ▼ sorted.bam + .bai
             (可选) multiqc 汇总
```

stages 声明见 [meta.yaml](meta.yaml)：`fastp`（去接头/质控）→ `bwa_mem2`（比对）→ `samtools_sort_index`（sort + index）→ `qc_optional`（multiqc 占位）。

## 编排入口（native/main.py）

入口：`python subworkflow/fastp_bwa_samtools/native/main.py --list-stages | --dry-run（默认）| --real`（仓库根执行）。编排器提供三种模式（`--list-stages` / `--dry-run` 默认 / `--real`），本质是**逐 stage 构造命令并调用 `modules/<sw>/native/main.py`**：

- 命令形态：`python modules/<sw>/native/main.py <subcmd> … --threads N`；若模块未构建则提示 `<MISSING>` 路径；
- `fastp`：`main.py run -i R1 [-I R2] -o {outdir}/fastp/{sample}_R1.clean.fq.gz -O … -h … -j …`；
- `bwa-mem2`：`main.py mem -R "@RG\tID:{sample}\tSM:{sample}\tLB:{sample}" ref R1 [R2] --threads N`，SAM 管道给 `samtools view -O BAM -o {outdir}/bam/{sample}.bam`；
- `samtools`：`main.py sort raw.bam -o {outdir}/bam/{sample}.sorted.bam --threads N` → `main.py index sorted.bam`。

> 按「纯编排器不入库」规则该脚本曾被移除，现已恢复为 [native/main.py](native/main.py)（内容即上文三种模式逻辑）；演示用 `--dry-run`（默认），真实执行 `--real`。

## Snakemake 骨架（原 snakemake/Snakefile.template 要点）

复制到真实项目改 `workflow/Snakefile` 使用；规则经 `python <repo>/modules/<sw>/native/main.py` 直调：

```python
SAMPLES = ["s001"]
rule all:
    input:
        expand("results/bam/{sample}.sorted.bam.bai", sample=SAMPLES),

rule fastp:            # raw/{sample}_R{1,2}.fq.gz -> results/fastp/... ; threads 8; mem 16G
    shell: "python ../../fastp/native/main.py run -i {input.r1} -I {input.r2} -o {output.r1_clean} -O {output.r2_clean} -h {output.html} --threads {threads}"

rule bwa_mem2_align:   # clean_fq + ref/ref.fa -> results/bam/{sample}.bam ; threads 8
    shell: "python ../../bwa-mem2/native/main.py mem -R '@RG\\tID:{wildcards.sample}\\tSM:{wildcards.sample}\\tLB:{wildcards.sample}' {input.ref} {input.r1} {input.r2} --threads {threads} | samtools view -O BAM -o {output.bam}"

rule samtools_sort_index:  # bam -> sorted.bam + .bai ; threads 4
    shell: "python ../../samtools/native/main.py sort {input} -o {output.bam} --threads {threads} && python ../../samtools/native/main.py index {output.bam}"
```

> 完整规则示例（含 input/output 声明）已随目录移除；落地时按模块实际参数补齐 `input/output/threads/resources`。

## Nextflow 骨架（原 nextflow/main.nf.template 要点）

复制到真实项目并安装 nf-core / local 模块后使用（DSL2）：

```groovy
include { FASTP         } from './modules/nf-core/fastp/main'
include { BWAMEM2_MEM   } from './modules/local/bwa-mem2/mem/main'   // nf-core 暂无 bwa-mem2，用 local
include { SAMTOOLS_SORT } from './modules/nf-core/samtools/sort/main'
include { SAMTOOLS_INDEX} from './modules/nf-core/samtools/index/main'

workflow {
    ch_reads = Channel.fromSamplesheet(params.samplesheet, header: ['sample','fastq_1','fastq_2','fasta'])
    ch_reads.map { meta, r1, r2, ref -> [ meta, [r1,r2] ] } | FASTP
    BWAMEM2_MEM( FASTP.out.reads.join(ch_reads.map { m,r1,r2,ref -> [m, ref] }) )
    SAMTOOLS_SORT( BWAMEM2_MEM.out.bam.map { m, b -> [ m, b, [] ] } )
    SAMTOOLS_INDEX( SAMTOOLS_SORT.out.bam )
}
```

## 如何把该组合变成“真正能跑”的流程

1. 在 `modules/fastp/`、`modules/bwa-mem2/`、`modules/multiqc/` 补齐 native 三件套（samtools 已有）；
2. 按上文命令形态实现循环/规则（原生调用或 Snakemake `wrapper:` / Nextflow 模块引用）；
3. 根据 HPC / LSF / Slurm / Kubernetes 加 Snakemake `--profile` 或 Nextflow 配置；
4. 检查对应 `modules/<sw>/meta.yaml` 的 `software_versions` 与容器（docker 须带 `-u $(id -u):$(id -g)`）。
