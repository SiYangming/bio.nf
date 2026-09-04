# cutadapt_se.smk —— cutadapt SE 去接头 单规则（Snakemake，td2 式）
#
# 环境：同目录 cutadapt.yaml；wrapper：同目录 cutadapt.py。
# 说明：cutadapt 只有 trim 一个子命令；SE/PE 为同一 wrapper 的两种输入形态，
# 故拆为 cutadapt_se.smk / cutadapt_pe.smk（每文件一规则）。
#
# 独立运行：snakemake -s modules/cutadapt/snakemake/cutadapt_se.smk \
#       --config cutadapt_read1=s_R1.fastq.gz 'cutadapt_adapters=-a AGATCGGAAGAG' \
#       cutadapt_fastq=out_R1.fastq.gz --cores 8 --use-conda
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode              : conda(默认) | docker | native
#   cutadapt.docker_image  : exec_mode=docker 时必填
#   cutadapt.cutadapt_bin  : exec_mode=native 时 cutadapt 路径（默认走 PATH）
#   cutadapt.adapters      : 引物串（透传给 wrapper params.adapters）
#   cutadapt.extra         : 透传 cutadapt 附加参数
#   cutadapt_read1         : 必填 输入 R1（SE）
#   cutadapt_fastq         : 输出 cleaned fastq（默认 cutadapt_out/s.fastq.gz）
#   cutadapt_qc            : 输出 QC 文本（默认 cutadapt_out/s.qc.txt）
#   threads                : 规则调度线程（默认 8）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("cutadapt_read1", "")
config.setdefault("cutadapt_fastq", os.path.join("cutadapt_out", "s.fastq.gz"))
config.setdefault("cutadapt_qc", os.path.join("cutadapt_out", "s.qc.txt"))
config.setdefault("threads", 8)
_ca = config.setdefault("cutadapt", {})
_ca.setdefault("docker_image", "")
_ca.setdefault("cutadapt_bin", "cutadapt")
_ca.setdefault("adapters", "")
_ca.setdefault("extra", "")

rule cutadapt_se:
    """cutadapt：单端 reads 去接头/质控。"""
    input:
        fastq1=config["cutadapt_read1"]
    output:
        fastq=config["cutadapt_fastq"],
        qc=config["cutadapt_qc"]
    params:
        adapters=_ca["adapters"],
        extra=_ca["extra"]
    conda: "cutadapt.yaml"
    log:
        os.path.join(os.path.dirname(config["cutadapt_fastq"]), "cutadapt_se.log")
    threads:
        config["threads"]
    message:
        "cutadapt (SE): {input.fastq1} -> {output.fastq}"
    script:
        "cutadapt.py"
