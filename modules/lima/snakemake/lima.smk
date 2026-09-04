# lima.smk —— lima demultiplex 单规则（Snakemake，td2 式）
#
# 环境：同目录 lima.yaml（conda 相对本文件目录解析）；wrapper：同目录 lima.py。
# 设计：config 驱动、单任务通用规则（reads BAM + 引物 FASTA -> 去引物/按条形码拆分 BAM），
#       不依赖 workflow 的 SAMPLES / {sample} / chunk 目录层级；由原聚合 lima.smk（ccs/{sample}/
#       {sample}.chunk{n}.bam 流程版）重构。lima 单条命令、无额外逻辑（报告文件由 lima 按输出
#       前缀自动派生，无需搬运/条件分支），docker/native/conda 三模式统一走同目录 wrapper
#       lima.py（分派经共享 modules/docker_wrapper.py 的 docker_wrapper_binary(config,
#       "lima", "lima_bin", "lima")，参考 modules/samtools/snakemake/samtools_sort.py）。
#
# 独立运行示例：
#   snakemake -s modules/lima/snakemake/lima.smk \
#       --config lima_input_reads=sample.reads.bam lima_input_primers=primers.fasta \
#       lima_output=demux/sample.demux.bam 'lima.extra_params=--isoseq --peek-guess' \
#       --cores 8 --use-conda
# 流程内使用（与 pbccs.smk 串接：令 lima_input_reads == ccs 产物即自动建依赖）：
#   include: "modules/lima/snakemake/lima.smk"
#   rule all:
#       input: config["lima_output"]
#
# config 契约（均有默认；独立运行时用 --config 覆盖；嵌套键 CLI 点号写法 'lima.extra_params=...'）：
#   exec_mode                : conda(默认) | docker | native
#   lima.docker_image        : exec_mode=docker 时必填（镜像名）
#   lima.lima_bin            : exec_mode=native 时的 lima 路径（默认 lima，走 PATH）
#   lima_input_reads          : 必填 输入 reads BAM（CCS / ccs 产物 *.bam）
#   lima_input_primers        : 必填 引物 FASTA（*.fasta）
#   lima_output               : 主输出文件（默认 <输入去扩展名>.demux.bam）
#   lima.extra_params         : 透传 lima 额外参数（默认 ""；Iso-Seq 建议 "--isoseq --peek-guess"）
#   threads                   : 规则调度线程（默认 8；-j 透传 lima）
#
# 产物（BAM 主路径）：<out>（拆分 reads）与同目录 <out>.pbi、<stem>.lima.{report,summary,counts}；
#   官方命名 prefix = 输出去扩展名（lima.how/output）；另按参数产生 .lima.clips / .removed.bam
#   等 side-product（非 output）。FASTA/FASTQ 输入请改走 modules/lima/native/main.py（输出扩展名
#   随输入推断且无 .pbi，本规则按 BAM 输出声明）。

import os

config.setdefault("exec_mode", "conda")
config.setdefault("lima_input_reads", "")
config.setdefault("lima_input_primers", "")
config.setdefault("threads", 8)
_lima = config.setdefault("lima", {})
_lima.setdefault("extra_params", "")
_lima.setdefault("docker_image", "")
_lima.setdefault("lima_bin", "lima")

# 主输出默认 <输入去 .bam 扩展名>.demux.bam（与 native main.py 前缀派生一致）
_lima_in = config["lima_input_reads"]
_lima_in_stem = os.path.splitext(_lima_in)[0] if _lima_in else ""
config.setdefault("lima_output", _lima_in_stem + ".demux.bam" if _lima_in_stem else "")
_lima_out = config["lima_output"]
_lima_out_stem = os.path.splitext(_lima_out)[0] if _lima_out else ""

rule lima:
    """lima：reads + 引物 FASTA -> 去引物/按条形码拆分 reads（Iso-Seq 第二步；BAM 主路径）。"""
    input:
        reads=config["lima_input_reads"],
        primers=config["lima_input_primers"]
    output:
        bam=_lima_out,
        pbi=_lima_out + ".pbi",
        report=_lima_out_stem + ".lima.report",
        summary=_lima_out_stem + ".lima.summary",
        counts=_lima_out_stem + ".lima.counts"
    params:
        extra=_lima["extra_params"]
    conda: "lima.yaml"
    log:
        os.path.join(os.path.dirname(_lima_out), "lima.log")
    threads:
        config["threads"]
    message:
        "lima: {input.reads} + {input.primers} -> {output.bam}"
    script:
        "lima.py"
