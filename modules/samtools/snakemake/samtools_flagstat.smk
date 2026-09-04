# samtools_flagstat.smk —— samtools flagstat 单规则（Snakemake，td2 式）
#
# 环境：同目录 samtools.yaml（conda 相对本文件目录解析）；wrapper：同目录 samtools_flagstat.py。
# 设计：config 驱动、单任务通用规则（BAM -> flagstat 文本），不依赖 workflow 的 samples /
#       config[paths]；单条命令按 AGENT「执行指令选择」经 script wrapper（samtools_flagstat.py）
#       做 docker/native/conda 三模式分派（exec_mode），命令串与原 shell 语义一致
#       （`flagstat {input} > {output}`，无额外参数/线程）。
#
# 独立运行示例：
#   snakemake -s modules/samtools/snakemake/samtools_flagstat.smk \
#       --config samtools_flagstat_input=aln.sorted.bam samtools_flagstat_output=aln.flagstat.txt \
#       --cores 1 --use-conda
# 流程内使用（每样本一个 flagstat 文件；批量汇总见 alignment_summary.smk）：
#   include: "modules/samtools/snakemake/samtools_flagstat.smk"
#   rule all:
#       input: config["samtools_flagstat_output"]
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode                    : conda(默认) | docker | native
#   samtools.docker_image        : exec_mode=docker 时必填（镜像名）
#   samtools.samtools_bin        : exec_mode=native 时 samtools 路径（默认走 PATH）
#   samtools_flagstat_input  : 必填 输入 BAM/CRAM
#   samtools_flagstat_output : 输出统计文本（默认 <输入去扩展名>.flagstat.txt）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("samtools_flagstat_input", "")
_samtools_fs_in = config["samtools_flagstat_input"]
_samtools_fs_stem = os.path.splitext(_samtools_fs_in)[0] if _samtools_fs_in else ""
config.setdefault("samtools_flagstat_output", _samtools_fs_stem + ".flagstat.txt" if _samtools_fs_stem else "")
_sam = config.setdefault("samtools", {})
_sam.setdefault("docker_image", "")
_sam.setdefault("samtools_bin", "samtools")

rule samtools_flagstat:
    """samtools flagstat：输出比对 flag 统计（总 reads/比对率等）。"""
    input:
        bam=config["samtools_flagstat_input"]
    output:
        txt=config["samtools_flagstat_output"]
    conda: "samtools.yaml"
    log:
        os.path.join(os.path.dirname(config["samtools_flagstat_output"]), "samtools_flagstat.log")
    message:
        "samtools flagstat: {input.bam} -> {output.txt}"
    script: "samtools_flagstat.py"
