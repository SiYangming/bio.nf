# bamtools_convert.smk —— bamtools convert 单规则（Snakemake，td2 式）
#
# 环境：同目录 bamtools.yaml（conda 相对本文件目录解析）；wrapper：同目录 bamtools_convert.py
#       （写 versions.yml 属多步逻辑，按 AGENT「执行指令选择」用 script: + wrapper）。
# 设计：config 驱动、单任务通用规则（BAM -> <format>），不依赖 workflow 的 SAMPLES /
#       results/refine/{sample}.chunk{n} 层级（源 bamtools_convert.smk 的固定输入/输出路径
#       已改为显式 config 键；Iso-Seq refine 产物转 FLNC 序列场景由调用方赋 config 即可）。
#
# 独立运行示例（默认 fasta；其他格式如 fastq 用 config.yaml 的 bamtools.format 覆盖）：
#   snakemake -s modules/bamtools/snakemake/bamtools_convert.smk \
#       --config bamtools_input_bam=refine.bam --cores 2 --use-conda
# 流程内使用（每任务一个 convert；产物 out + versions.yml）：
#   include: "modules/bamtools/snakemake/bamtools_convert.smk"
#   rule all:
#       input: config["bamtools_output"]
#
# config 契约（均有默认；独立运行时用 --config 覆盖顶层键，bamtools.* 在 Snakefile 的
# config/config.yaml 预设，与 td2 式规范一致）：
#   exec_mode                  : conda(默认) | docker | native
#   bamtools.docker_image      : exec_mode=docker 时必填（镜像名）
#   bamtools.bamtools_bin      : exec_mode=native 时的 bamtools 路径（默认 bamtools，走 PATH）
#   bamtools.format            : convert 目标格式 bed/fasta/fastq/json/pileup/sam/yaml（默认 fasta）
#   bamtools.extra_params      : 透传 bamtools convert 附加参数
#   bamtools_input_bam         : 必填 输入 BAM
#   bamtools_outdir            : 输出目录（默认 bamtools_out）
#   bamtools_output            : 转换产物（默认 <outdir>/<BAM 名去扩展>.<format>）
#   bamtools_versions          : versions.yml（默认 <output>.versions.yml）
#
# 说明：bamtools convert 为单线程工具，无 -@ 类线程参数，规则不设 threads。

import os

config.setdefault("exec_mode", "conda")
config.setdefault("bamtools_input_bam", "")
config.setdefault("bamtools_outdir", "bamtools_out")
_bt = config.setdefault("bamtools", {})
_bt.setdefault("docker_image", "")
_bt.setdefault("bamtools_bin", "bamtools")
_bt.setdefault("format", "fasta")
_bt.setdefault("extra_params", "")

if not config["bamtools_input_bam"]:
    raise ValueError("bamtools_convert.smk: 需提供 config['bamtools_input_bam']（输入 BAM）")


def _strip_bam_ext(path_str: str) -> str:
    base = os.path.basename(path_str)
    for suf in (".bam", ".sam", ".cram"):
        if base.endswith(suf):
            return base[: -len(suf)]
    return os.path.splitext(base)[0]


_bt_outdir = config["bamtools_outdir"]
_bt_stem = _strip_bam_ext(config["bamtools_input_bam"]) or "converted"
config.setdefault("bamtools_output", os.path.join(_bt_outdir, _bt_stem + "." + _bt["format"]))
config.setdefault("bamtools_versions", config["bamtools_output"] + ".versions.yml")

rule bamtools_convert:
    """bamtools convert：BAM -> <format>（默认 fasta），并写 versions.yml。"""
    input:
        bam=config["bamtools_input_bam"]
    output:
        out=config["bamtools_output"],
        versions=config["bamtools_versions"]
    params:
        format=_bt["format"],
        extra=_bt["extra_params"]
    conda: "bamtools.yaml"
    log:
        os.path.join(_bt_outdir, "bamtools_convert.log")
    message:
        "bamtools convert: {input.bam} -> {output.out}"
    script:
        "bamtools_convert.py"
