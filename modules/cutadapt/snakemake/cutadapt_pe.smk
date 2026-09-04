# cutadapt_pe.smk —— cutadapt PE 去接头 单规则（Snakemake，td2 式）
#
# 环境：同目录 cutadapt.yaml；wrapper：同目录 cutadapt.py。
# 说明：与 cutadapt_se.smk 为同一 wrapper 的双端形态（R1+R2，-o/-p 输出）。
#
# 独立运行：snakemake -s modules/cutadapt/snakemake/cutadapt_pe.smk \
#       --config cutadapt_read1=s_R1.fastq.gz cutadapt_read2=s_R2.fastq.gz \
#       'cutadapt_adapters=-a AGATCGGAAGAG -A AGATCGGAAGAG' \
#       cutadapt_fastq1=out_R1.fastq.gz cutadapt_fastq2=out_R2.fastq.gz \
#       --cores 8 --use-conda
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode              : conda(默认) | docker | native
#   cutadapt.docker_image  : exec_mode=docker 时必填
#   cutadapt.cutadapt_bin  : exec_mode=native 时 cutadapt 路径（默认走 PATH）
#   cutadapt.adapters      : 引物串（SE 前缀 -a / PE 需自行含 -A，透传 params.adapters）
#   cutadapt.extra         : 透传 cutadapt 附加参数
#   cutadapt_read1/read2   : 必填 输入 R1 / R2
#   cutadapt_fastq1/2      : 输出 cleaned fastq（默认 cutadapt_out/s_R1/R2.fastq.gz）
#   cutadapt_qc            : 输出 QC 文本（默认 cutadapt_out/s.qc.txt）
#   threads                : 规则调度线程（默认 8）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("cutadapt_read1", "")
config.setdefault("cutadapt_read2", "")
config.setdefault("cutadapt_fastq1", os.path.join("cutadapt_out", "s_R1.fastq.gz"))
config.setdefault("cutadapt_fastq2", os.path.join("cutadapt_out", "s_R2.fastq.gz"))
config.setdefault("cutadapt_qc", os.path.join("cutadapt_out", "s.qc.txt"))
config.setdefault("threads", 8)
_ca = config.setdefault("cutadapt", {})
_ca.setdefault("docker_image", "")
_ca.setdefault("cutadapt_bin", "cutadapt")
_ca.setdefault("adapters", "")
_ca.setdefault("extra", "")

rule cutadapt_pe:
    """cutadapt：双端 reads 去接头/质控（-o/-p）。"""
    input:
        fastq1=config["cutadapt_read1"],
        fastq2=config["cutadapt_read2"]
    output:
        fastq1=config["cutadapt_fastq1"],
        fastq2=config["cutadapt_fastq2"],
        qc=config["cutadapt_qc"]
    params:
        adapters=_ca["adapters"],
        extra=_ca["extra"]
    conda: "cutadapt.yaml"
    log:
        os.path.join(os.path.dirname(config["cutadapt_fastq1"]), "cutadapt_pe.log")
    threads:
        config["threads"]
    message:
        "cutadapt (PE): {input.fastq1} {input.fastq2} -> {output.fastq1} {output.fastq2}"
    script:
        "cutadapt.py"
