# fastp_se.smk —— fastp SE 清洗 单规则（Snakemake，td2 式）
#
# 环境：同目录 fastp.yaml（conda 相对本文件目录解析）；wrapper：同目录 fastp.py。
# 说明：fastp 只有 run 一个子命令；SE/PE 为同一 wrapper 的两种输入形态，
#       故拆为 fastp_pe.smk / fastp_se.smk（每文件一规则，同目录 fastp.py 共用）。
# 设计：config 驱动、单任务通用规则，不依赖 workflow 的 SAMPLES / reads/{sample} 层级。
#
# 独立运行示例：
#   snakemake -s modules/fastp/snakemake/fastp_se.smk \
#       --config fastp_read1=s1.fastq.gz fastp_outdir=fastp_out --cores 8 --use-conda
# 流程内使用：
#   include: "modules/fastp/snakemake/fastp_se.smk"
#   rule all:
#       input: [config["fastp_out1"], config["fastp_html"], config["fastp_json"]]
#
# config 契约（均有默认；独立运行时用 --config 覆盖顶层键，fastp.* 在 Snakefile 的
# config/config.yaml 预设，与 td2 式规范一致）：
#   exec_mode                  : conda(默认) | docker | native
#   fastp.docker_image         : exec_mode=docker 时必填（镜像名）
#   fastp.fastp_bin            : exec_mode=native 时的 fastp 路径（默认 fastp，走 PATH）
#   fastp.adapter_sequence     : R1 3' 接头（IUPAC；不设则 fastp 自动检测）
#   fastp.qualified_quality_phred : -q 阈值（默认不传 = fastp 内建 15）
#   fastp.unqualified_percent_limit: -u 阈值（默认不传 = fastp 内建 40）
#   fastp.length_required      : -l 最短 read 长度（默认不传 = fastp 内建 15）
#   fastp.extra                : 透传 fastp 附加参数（如 "--cut_front --cut_tail --cut_right 1"）
#   fastp_read1                : 必填 输入 R1（支持 .gz）
#   fastp_outdir               : 输出根（默认 fastp_out）
#   fastp_out1                 : 输出 clean R1（默认 <outdir>/<输入名去扩展>.clean.fastq.gz）
#   fastp_html / fastp_json    : QC 报告（默认 <outdir>/<样本>_fastp.html / .json）
#   threads                    : 规则调度线程（默认 8；fastp 0.20+ 为 -w）
#
# 注：fastp 0.20+ 线程参数为 -w/--thread（-t 已被 --trim_tail1 占用），勿用 -t 传线程。

import os

config.setdefault("exec_mode", "conda")
config.setdefault("fastp_read1", "")
config.setdefault("fastp_outdir", "fastp_out")
config.setdefault("threads", 8)
_fp = config.setdefault("fastp", {})
_fp.setdefault("docker_image", "")
_fp.setdefault("fastp_bin", "fastp")
_fp.setdefault("adapter_sequence", "")
_fp.setdefault("qualified_quality_phred", None)
_fp.setdefault("unqualified_percent_limit", None)
_fp.setdefault("length_required", None)
_fp.setdefault("extra", "")

if not config["fastp_read1"]:
    raise ValueError("fastp_se.smk: 需提供 config['fastp_read1']（输入 R1 FASTQ）")


def _strip_ext(path_str: str) -> str:
    """去除 .gz/.fastq/.fq/.fasta/.fa 扩展名，返回裸名（如 s1.fastq.gz -> s1）。"""
    base = os.path.basename(path_str)
    for suf in (".gz", ".bz2"):
        if base.endswith(suf):
            base = base[: -len(suf)]
    for suf in (".fastq", ".fq", ".fasta", ".fa"):
        if base.endswith(suf):
            base = base[: -len(suf)]
    return base


_fp_outdir = config["fastp_outdir"]
_fp_r1_stem = _strip_ext(config["fastp_read1"])
_fp_sample = _fp_r1_stem[:-3] if _fp_r1_stem.endswith("_R1") else _fp_r1_stem
config.setdefault("fastp_out1", os.path.join(_fp_outdir, _fp_r1_stem + ".clean.fastq.gz"))
config.setdefault("fastp_html", os.path.join(_fp_outdir, _fp_sample + "_fastp.html"))
config.setdefault("fastp_json", os.path.join(_fp_outdir, _fp_sample + "_fastp.json"))

rule fastp_se:
    """fastp（SE）：单端 FASTQ(gz) 去接头/质控/长度过滤，输出 clean R1 + HTML/JSON 报告。"""
    input:
        fq1=config["fastp_read1"]
    output:
        out1=config["fastp_out1"],
        html=config["fastp_html"],
        json=config["fastp_json"]
    params:
        adapter_sequence=_fp["adapter_sequence"],
        qualified_quality_phred=_fp["qualified_quality_phred"],
        unqualified_percent_limit=_fp["unqualified_percent_limit"],
        length_required=_fp["length_required"],
        extra=_fp["extra"]
    conda: "fastp.yaml"
    log:
        os.path.join(_fp_outdir, "logs", "fastp_se.log")
    threads:
        config["threads"]
    message:
        "fastp (SE): {input.fq1} -> {output.out1}"
    script:
        "fastp.py"
