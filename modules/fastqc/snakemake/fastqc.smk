# fastqc.smk —— FastQC 质量评估 单规则（Snakemake，td2 式）
#
# 环境：同目录 fastqc.yaml（conda 相对本文件目录解析，bioconda::fastqc==0.12.1）；
#       执行：script: 同目录 fastqc.py（exec_mode 三模式分派；nf-core 风格 wrapper）。
# 设计：config 驱动、单任务通用规则（reads/seq 文件 -> *_fastqc.html/.zip），不依赖流程
#       samples / config["paths"] / common.smk。由原 rule.smk.template（通用模板）与
#       fastqc_riboseq.smk（riboseq 流程版，已删）合并而来，{sample}/{protocol}/{stage}
#       通配与流程级 containers 不再保留，多样本展开由调用方逐文件赋 config。
#
# 独立运行示例：
#   snakemake -s modules/fastqc/snakemake/fastqc.smk \
#       --config fastqc_input=s1_R1.fastq.gz --cores 4 --use-conda
# 流程内使用：
#   include: "modules/fastqc/snakemake/fastqc.smk"
#   rule all:
#       input: config["fastqc_html"]   # 产物 *_fastqc.html/.zip 在 fastqc_outdir/
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode                  : conda(默认) | docker | native
#   fastqc.docker_image        : exec_mode=docker 时必填
#   fastqc.fastqc_bin          : exec_mode=native 时 fastqc 路径（默认 fastqc）
#   fastqc.extra               : 透传 fastqc 附加参数（如 "-f fastq_bismark"）
#   fastqc.mem_overhead_factor : 内存开销比例（默认 0.1）
#   fastqc.mem_mb              : 总内存预算 MB（默认 8192；均摊到各线程 --memory）
#   fastqc_input               : 必填 输入 FASTQ/FASTA/BAM/SAM（单文件）
#   fastqc_outdir              : 输出目录（默认 fastqc_out；html/zip 默认
#                                <outdir>/<输入去扩展名>_fastqc.{html,zip}）
#   threads                    : 规则调度线程（默认 4）

import os
import re

config.setdefault("exec_mode", "conda")
config.setdefault("fastqc_input", "")
config.setdefault("fastqc_outdir", "fastqc_out")
config.setdefault("threads", 4)
_fq = config.setdefault("fastqc", {})
_fq.setdefault("docker_image", "")
_fq.setdefault("fastqc_bin", "fastqc")
_fq.setdefault("extra", "")
_fq.setdefault("mem_overhead_factor", 0.1)
_fq.setdefault("mem_mb", 8192)

_fqc_in = config["fastqc_input"]
if not _fqc_in:
    raise ValueError("fastqc.smk: 需提供 config['fastqc_input']（单输入 reads/seq 文件）")


def _fastqc_base(file_path: str) -> str:
    """与 fastqc.py basename_without_ext 一致：剥 .gz/.bz2/.txt/.fastq/.fq/.sam/.bam。"""
    b = os.path.basename(file_path)
    for suf in (r"\.gz$", r"\.bz2$", r"\.txt$", r"\.fastq$", r"\.fq$", r"\.sam$", r"\.bam$"):
        b = re.sub(suf, "", b)
    return b


_fqc_base = _fastqc_base(_fqc_in)
config.setdefault("fastqc_html", os.path.join(config["fastqc_outdir"], f"{_fqc_base}_fastqc.html"))
config.setdefault("fastqc_zip", os.path.join(config["fastqc_outdir"], f"{_fqc_base}_fastqc.zip"))

rule fastqc:
    """FastQC：reads 质量评估 -> *_fastqc.html/.zip（tempdir 内运行后搬回，避免并发竞争）。"""
    input:
        fastq=_fqc_in
    output:
        html=config["fastqc_html"],
        zip=config["fastqc_zip"]
    params:
        extra=_fq["extra"],
        mem_overhead_factor=_fq["mem_overhead_factor"]
    conda: "fastqc.yaml"
    log:
        os.path.join(config["fastqc_outdir"], "fastqc.log")
    threads:
        config["threads"]
    resources:
        mem_mb=_fq["mem_mb"]
    message:
        "fastqc: {input.fastq} -> {output.html}"
    script:
        "fastqc.py"
