# minimap2_align.smk —— minimap2 比对 单规则（Snakemake，td2 式）
#
# 环境：同目录 minimap2.yaml（conda 相对本文件目录解析）；wrapper：同目录 minimap2_align.py。
# 设计：config 驱动、reads（可选 reference）→ 排序 BAM + 索引 + versions.yml，
#       不依赖 workflow 的 SAMPLES / {sample} 层级（源 isoseq 流程 minimap2_align
#       自维护版，已去掉 config["minimap2"]["fasta"] 隐式参考与
#       results/gstama/... 固定 reads 路径，改为显式 config 键）。
#
# 独立运行示例：
#   snakemake -s modules/minimap2/snakemake/minimap2_align.smk \
#       --config minimap2_reads=flnc.fa.gz minimap2_reference=ref.fa threads=8 \
#       --cores 8 --use-conda
# 流程内使用：
#   include: "modules/minimap2/snakemake/minimap2_align.smk"
#   rule all:
#       input: "minimap2_out/flnc.bam"   # = <minimap2_outdir>/<prefix>.bam（prefix 默认取 reads 名）
#
# config 契约（均有默认；独立运行时用 --config 覆盖顶层键，minimap2.* 在 Snakefile
# 的 config/config.yaml 预设，与 td2 式规范一致）：
#   exec_mode                  : conda(默认) | docker | native
#   minimap2.docker_image      : exec_mode=docker 时必填（镜像名）
#   minimap2.minimap2_bin      : exec_mode=native 时的 minimap2 路径（默认 minimap2，走 PATH）
#   minimap2.samtools_bin      : exec_mode=native 时的 samtools 路径（默认 samtools，走 PATH）
#   minimap2.args              : 透传 minimap2 参数（如 "-x splice -uf -k14"；默认空 = 通用比对）
#   minimap2.cigar_bam         : BAM 长 CIGAR 写 CG 标签（-L，默认 False）
#   minimap2_reads             : 必填 输入 reads（FASTA/FASTQ，支持 .gz）
#   minimap2_reference         : 可选 参考 FASTA（缺省退化为 reads vs reads 自比对）
#   minimap2_outdir            : 输出根（默认 minimap2_out；align 产物在 <outdir>/）
#   minimap2_prefix            : 输出前缀（默认从 reads 文件名去扩展名推断）
#   threads                    : 规则调度线程（默认 8）
#
# 执行指令选择：BAM 管线为多步（minimap2 -a | samtools sort | samtools view -b -h，
#   samtools index → .bai，写 versions.yml）+ docker/native/conda 三模式分派 →
#   用 script: 同目录 minimap2_align.py；单条命令（PAF 直出等）场景可用官方
#   wrapper: "vX.Y.Z/bio/minimap2/aligner"（见模块 README「官方 snakemake-wrappers」节）。

import os

config.setdefault("exec_mode", "conda")
config.setdefault("minimap2_reads", "")
config.setdefault("minimap2_reference", "")
config.setdefault("minimap2_outdir", "minimap2_out")
config.setdefault("minimap2_prefix", "")
config.setdefault("threads", 8)
_mm2 = config.setdefault("minimap2", {})
_mm2.setdefault("docker_image", "")
_mm2.setdefault("minimap2_bin", "minimap2")
_mm2.setdefault("samtools_bin", "samtools")
_mm2.setdefault("args", "")
_mm2.setdefault("cigar_bam", False)


def _strip_ext(path_str: str) -> str:
    """去除常见 fasta/fastq 扩展名（含 gz），返回不带扩展的文件基名（与 native main.py 一致）。"""
    base_name = os.path.basename(path_str)
    for suf in (".fa.gz", ".fasta.gz", ".fastq.gz", ".fa", ".fasta", ".fastq"):
        if base_name.endswith(suf):
            return base_name[: -len(suf)]
    return os.path.splitext(base_name)[0]


_mm2_prefix = config["minimap2_prefix"] or _strip_ext(config["minimap2_reads"])
_mm2_bam = os.path.join(config["minimap2_outdir"], _mm2_prefix + ".bam")


def _minimap2_align_input(wildcards):
    """rule 输入：reference 可选，未配置时不占 input 槽位（wrapper 内 .get("reference") 兜底）。"""
    d = {"reads": config["minimap2_reads"]}
    if config["minimap2_reference"]:
        d["reference"] = config["minimap2_reference"]
    return d


rule minimap2_align:
    """minimap2：reads → 参考基因组（缺省 reads vs reads）比对，输出排序 BAM + .bai + versions.yml。"""
    input:
        unpack(_minimap2_align_input)
    output:
        bam=_mm2_bam,
        bai=_mm2_bam + ".bai",
        versions=os.path.join(config["minimap2_outdir"], _mm2_prefix + ".versions.yml")
    params:
        extra=_mm2["args"],
        cigar_bam=_mm2["cigar_bam"]
    conda: "minimap2.yaml"
    log:
        os.path.join(config["minimap2_outdir"], "logs", "minimap2_align.log")
    threads:
        config["threads"]
    message:
        "minimap2 align: {input.reads} -> {output.bam}"
    script:
        "minimap2_align.py"
