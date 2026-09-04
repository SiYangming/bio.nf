# stringtie_assemble.smk —— stringtie assemble 单规则（Snakemake，td2 式）
#
# 环境：同目录 stringtie.yaml（conda 相对本文件目录解析）；wrapper：同目录 stringtie_assemble.py。
# 设计：config 驱动、单样本通用规则（BAM -> 转录本 GTF），不依赖 workflow 的 SAMPLES /
#       config[output_dir] / {sample} 目录层级。执行经同目录 wrapper 走 docker/native/conda
#       三模式分派：docker 用 stringtie.docker_image 镜像内 stringtie；native 用 config 的
#       stringtie.stringtie_bin；conda 走 PATH（--use-conda 用同目录 yaml）。
#
# 独立运行示例：
#   snakemake -s modules/stringtie/snakemake/stringtie_assemble.smk \
#       --config stringtie_bam=sample.sorted.bam \
#           stringtie_gtf_annotation=gencode.v49.annotation.gtf \
#       --cores 8 --use-conda
# 流程内使用（每样本一个 assemble 输出；配合 stringtie_fix_gtf.smk / stringtie_merge.smk）：
#   include: "modules/stringtie/snakemake/stringtie_assemble.smk"
#   rule all:
#       input: config["stringtie_assembled_gtf"]
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode                    : conda(默认) | docker | native
#   stringtie.docker_image       : exec_mode=docker 时必填（镜像名）
#   stringtie.stringtie_bin      : exec_mode=native 时 stringtie 路径（默认走 PATH）
#   stringtie_bam                : 必填 输入 BAM
#   stringtie_assembled_gtf      : 输出 GTF（默认 stringtie_out/assemble/<bam 名去扩展>.stringtie.gtf）
#   stringtie_gtf_annotation     : 可选 参考注释 GTF（-G；空则不传）
#   stringtie_label              : 可选 转录本前缀标签 -l（默认 bam 名去 .sorted/.bam）
#   stringtie_min_transcript_len : 最小转录本长度 -m（默认 200）
#   stringtie_conservative       : --conservative（默认 true，置 false/0/no 关闭）
#   stringtie_long_reads         : -L 长读模式（默认 true）
#   stringtie_rf_stranded        : -R RF 链特异性（默认 true）
#   stringtie_extra_args         : 透传 stringtie 附加参数（默认空）
#   threads                      : 规则调度线程 -p（默认 8）

import os

config.setdefault("exec_mode", "conda")
_st = config.setdefault("stringtie", {})
_st.setdefault("docker_image", "")
_st.setdefault("stringtie_bin", "stringtie")

config.setdefault("stringtie_bam", "")
config.setdefault("stringtie_gtf_annotation", "")
config.setdefault("stringtie_label", "")
config.setdefault("stringtie_min_transcript_len", 200)
config.setdefault("stringtie_extra_args", "")
config.setdefault("threads", 8)

_bam = config["stringtie_bam"]
_bam_base = os.path.basename(_bam)
for _suffix in (".sorted.bam", ".bam"):
    if _bam_base.endswith(_suffix):
        _bam_base = _bam_base[: -len(_suffix)]
        break
config.setdefault(
    "stringtie_assembled_gtf",
    os.path.join("stringtie_out", "assemble", _bam_base + ".stringtie.gtf") if _bam else "",
)


# 布尔开关：容忍 --config 字符串传参（"false"/"0"/"no"/"off" 视为关）
def _flag_on(key, default=True):
    val = config.setdefault(key, default)
    if isinstance(val, str):
        return val.strip().lower() not in ("", "0", "false", "no", "off")
    return bool(val)


_flags = []
if _flag_on("stringtie_conservative"):
    _flags.append("--conservative")
if _flag_on("stringtie_long_reads"):
    _flags.append("-L")
if _flag_on("stringtie_rf_stranded"):
    _flags.append("-R")

_ann = config["stringtie_gtf_annotation"]
_gtf_arg = f"-G {_ann}" if _ann else ""
_label = config["stringtie_label"] or _bam_base

rule stringtie_assemble:
    """stringtie assemble：BAM -> 样本级转录本 GTF（nanoseq 长读模式默认 --conservative -L -R）。"""
    input:
        bam=config["stringtie_bam"]
    output:
        gtf=config["stringtie_assembled_gtf"]
    params:
        flags=" ".join(_flags),
        gtf_arg=_gtf_arg,
        label=_label,
        min_len=config["stringtie_min_transcript_len"],
        extra=config["stringtie_extra_args"]
    conda: "stringtie.yaml"
    log:
        os.path.join(os.path.dirname(config["stringtie_assembled_gtf"]), "stringtie_assemble.log")
    threads:
        config["threads"]
    message:
        "stringtie assemble: {input.bam} -> {output.gtf}"
    script: "stringtie_assemble.py"
