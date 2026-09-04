# isoseq3_refine.smk —— isoseq3 refine 单规则（Snakemake，td2 式）
#
# 环境：同目录 isoseq3.yaml（conda 相对本文件目录解析）；wrapper：同目录 isoseq3_refine.py。
# 设计：config 驱动、单样本通用流程，不依赖 workflow 的 SAMPLES / {sample} 目录层级；
#       输出前缀默认取输入 bam 文件名去 .bam（与 native main.py _derive_prefix_from_bam 一致），
#       refine 产物（.bam/.pbi/.consensusreadset.xml/.filter_summary.report.json/.report.csv）
#       平铺于 <isoseq3_outdir>/ 下。
#
# 独立运行示例：
#   snakemake -s modules/isoseq3/snakemake/isoseq3_refine.smk \
#       --config isoseq3_input_bam=lima/s1/s1.chunk1.bam isoseq3_primers=primers.fasta \
#       --cores 8 --use-conda
# 流程内使用（输入为 lima 产物，可与 pbccs / lima 规则串联）：
#   include: "modules/isoseq3/snakemake/isoseq3_refine.smk"
#   rule all:
#       input: "isoseq3_out/s1.chunk1.bam"   # = <isoseq3_outdir>/<prefix>.bam（prefix 默认取 bam 名）
#
# config 契约（均有默认；独立运行时用 --config 覆盖顶层键，isoseq3.* 在 Snakefile
# 的 config/config.yaml 预设，与 td2 式规范一致）：
#   exec_mode                : conda(默认) | docker | native
#   isoseq3.docker_image     : exec_mode=docker 时必填（镜像名）
#   isoseq3.isoseq3_bin      : exec_mode=native 时的 isoseq3 路径（默认 isoseq3，走 PATH）
#   isoseq3_input_bam        : 必填 输入 BAM（lima 清理后的 ccs BAM）
#   isoseq3_primers          : 必填 引物 FASTA（*.fasta）
#   isoseq3_outdir           : 输出目录（默认 isoseq3_out；refine 产物平铺其下，log 在 <outdir>/logs/）
#   isoseq3_prefix           : 输出前缀（默认从输入 bam 文件名去 .bam 推断）
#   isoseq3.require_polya    : 仅保留检测到 polyA 尾的 reads（默认 true → 传 --require-polya；
#                              false 则不传该旗标，等价 native --no-require-polya）
#   isoseq3.min_polya_length : polyA 尾最小长度（默认空 → 不传 --min-polya-length）
#   isoseq3.extra_args       : 透传 isoseq3 refine 额外参数（高级用法，慎用）
#   threads                  : 规则调度线程（默认 8；-j 透传 isoseq3 refine）
#
# 执行指令选择：refine 为单条命令、无额外逻辑（mkdir 仅建目录）→ 同目录 wrapper
#   isoseq3_refine.py（docker/native/conda 三模式分派经共享 modules/docker_wrapper.py 的
#   docker_wrapper_binary(config, "isoseq3", "isoseq3_bin", "isoseq3")）。

import os

config.setdefault("exec_mode", "conda")
config.setdefault("isoseq3_input_bam", "")
config.setdefault("isoseq3_primers", "")
config.setdefault("isoseq3_outdir", "isoseq3_out")
config.setdefault("isoseq3_prefix", "")
config.setdefault("threads", 8)
_isoseq3 = config.setdefault("isoseq3", {})
_isoseq3.setdefault("require_polya", True)
_isoseq3.setdefault("min_polya_length", "")
_isoseq3.setdefault("extra_args", "")
_isoseq3.setdefault("docker_image", "")
_isoseq3.setdefault("isoseq3_bin", "isoseq3")


def _bam_prefix(path_str: str) -> str:
    """输入 bam 文件名去 .bam（如 m64291e_ccs.chunk1.bam -> m64291e_ccs.chunk1；与 native main.py 一致）。"""
    base = os.path.basename(path_str)
    return base[:-4] if base.endswith(".bam") else os.path.splitext(base)[0]


_isoseq3_prefix = config["isoseq3_prefix"] or _bam_prefix(config["isoseq3_input_bam"])
_isoseq3_out = config["isoseq3_outdir"]
_isoseq3_bam = os.path.join(_isoseq3_out, _isoseq3_prefix + ".bam")

# 参数旗标：require_polya 默认 true；min_polya_length 为空/None 时不传；空串直接内联无副作用
_polya_flag = "--require-polya" if _isoseq3["require_polya"] else ""
_min_polya_length = _isoseq3["min_polya_length"]
_min_polya_flag = f"--min-polya-length {_min_polya_length}" if _min_polya_length not in ("", None) else ""

rule isoseq3_refine:
    """isoseq3 refine：lima 产物 → 精炼 reads（去 polyA 尾与人工连接体；产物同前缀平铺于 <isoseq3_outdir>/）。"""
    input:
        bam=config["isoseq3_input_bam"],
        primers=config["isoseq3_primers"]
    output:
        bam=_isoseq3_bam,
        pbi=_isoseq3_bam + ".pbi",
        consensus=os.path.join(_isoseq3_out, f"{_isoseq3_prefix}.consensusreadset.xml"),
        summary=os.path.join(_isoseq3_out, f"{_isoseq3_prefix}.filter_summary.report.json"),
        report=os.path.join(_isoseq3_out, f"{_isoseq3_prefix}.report.csv")
    params:
        polya=_polya_flag,
        min_polya=_min_polya_flag,
        extra=_isoseq3["extra_args"]
    conda: "isoseq3.yaml"
    log:
        os.path.join(_isoseq3_out, "logs", "isoseq3_refine.log")
    threads:
        config["threads"]
    message:
        "isoseq3 refine: {input.bam} -> {output.bam}"
    script:
        "isoseq3_refine.py"
