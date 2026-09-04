# gnu_sort.smk —— GNU sort 排序 单规则（Snakemake，td2 式）
#
# 环境：sort 为系统基础工具（GNU coreutils），本规则不内置 conda env——conda 模式二进制默认走系统
#       PATH（Debian bookworm apt coreutils=9.1 / conda-forge::coreutils，bioconda 无独立 gnu_sort
#       包）；需要 --use-conda 时可调用方自行提供含 coreutils 的环境。
# 执行：script: 同目录 wrapper gnu_sort.py（sort <args> <in> > <out>，stdout=排序结果进输出文件、
#       stderr 进 log）；docker/native/conda 三模式分派：docker 用 gnu_sort.docker_image 镜像内
#       sort；native 用 config 的 gnu_sort.sort_bin；conda 走 PATH。
# 设计：config 驱动、单任务通用规则（文本/SAM/GTF/BED -> 排序文件），不依赖 workflow 的
#       SAMPLES / {filepath} 通配层级（源 gnu_sort.smk 的 wildcard 规则已改为显式 config 键；
#       isoseq 流程中 GTF 按染色体+起始位点排序由调用方赋 args 即可）。
#
# 独立运行示例：
#   snakemake -s modules/gnu_sort/snakemake/gnu_sort.smk \
#       --config gnu_sort_input=transcripts.gtf gnu_sort_output=transcripts.sorted.gtf \
#       --cores 4
#   带键排序（如 GTF 按染色体+起始位点）：config.yaml 预设 gnu_sort: {args: "-k1,1 -k4,4n"}
# 流程内使用：
#   include: "modules/gnu_sort/snakemake/gnu_sort.smk"
#   config.setdefault("gnu_sort", {}).setdefault("args", "-k1,1 -k4,4n")
#   rule all:
#       input: config["gnu_sort_output"]
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode             : conda(默认) | docker | native
#   gnu_sort_input        : 必填 输入文件（文本/SAM/GTF/BED 等）
#   gnu_sort_output       : 输出文件（默认 <输入>.sorted）
#   gnu_sort.docker_image : exec_mode=docker 时必填（镜像名，内含 GNU sort）
#   gnu_sort.sort_bin     : sort 路径（默认 sort，走 PATH）
#   gnu_sort.args         : 透传 sort 附加参数（如 "-k1,1 -k4,4n"、"-n"、"-S 2G --parallel 8"；默认空）
#
# 注：--parallel 仅 GNU coreutils 提供（BSD sort 忽略）；sort 自身多线程，规则不另设 threads
#   （如需限流可在调用方用 use rule 覆盖 threads:）。

import os

config.setdefault("exec_mode", "conda")
config.setdefault("gnu_sort_input", "")
_gs = config.setdefault("gnu_sort", {})
_gs.setdefault("docker_image", "")
_gs.setdefault("sort_bin", "sort")
_gs.setdefault("args", "")

_gs_in = config["gnu_sort_input"]
config.setdefault("gnu_sort_output", _gs_in + ".sorted" if _gs_in else "")

if not _gs_in:
    raise ValueError("gnu_sort.smk: 需提供 config['gnu_sort_input']（输入文件）")

rule gnu_sort:
    """GNU sort：sort <args> <in> > <out>.sorted（args 由 config 透传）。"""
    input:
        unsorted=config["gnu_sort_input"]
    output:
        sorted=config["gnu_sort_output"]
    params:
        args=_gs["args"]
    log:
        os.path.join(os.path.dirname(config["gnu_sort_output"]), "gnu_sort.log")
    message:
        "sort: {input.unsorted} -> {output.sorted}"
    script: "gnu_sort.py"
