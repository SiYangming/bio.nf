# gunzip.smk —— gunzip 解压 单规则（Snakemake，td2 式）
#
# 环境：gzip/gunzip 为系统基础工具，本规则不内置 conda env——conda 模式二进制默认走系统 PATH
#       （Debian bookworm apt gzip=1.12 / conda-forge::gzip，bioconda 无独立 gunzip 包）；
#       需要 --use-conda 时可调用方自行提供含 gzip 的环境。
# 执行：script: 同目录 wrapper gunzip.py（gzip -cd <in.gz> > <out>，stdout=解压内容进输出文件、
#       stderr 进 log）；docker/native/conda 三模式分派：docker 用 gunzip.docker_image 镜像内
#       gzip；native 用 config 的 gunzip.gzip_bin；conda 走 PATH。
# 设计：config 驱动、单任务通用规则（.gz -> 明文），不依赖 workflow 的 SAMPLES /
#       {filepath} 通配层级（源 gunzip.smk 的 wildcard 规则已改为显式 config 键；
#       isoseq 流程中逐文件解压由调用方为每个文件赋 config 即可）。
#
# 独立运行示例：
#   snakemake -s modules/gunzip/snakemake/gunzip.smk \
#       --config gunzip_input=ref.fa.gz gunzip_output=ref.fa --cores 1
# 流程内使用：
#   include: "modules/gunzip/snakemake/gunzip.smk"
#   rule all:
#       input: config["gunzip_output"]
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode            : conda(默认) | docker | native
#   gunzip_input         : 必填 输入 .gz 文件
#   gunzip_output        : 输出文件（默认 <输入去 .gz 后缀>）
#   gunzip.docker_image  : exec_mode=docker 时必填（镜像名，内含 gzip）
#   gunzip.gzip_bin      : gzip 路径（默认 gzip，走 PATH；也可置 gunzip）
#
# 注：gzip -cd 为单线程解压，无 -@ 类线程参数，规则不设 threads。

import os

config.setdefault("exec_mode", "conda")
config.setdefault("gunzip_input", "")
_gz = config.setdefault("gunzip", {})
_gz.setdefault("docker_image", "")
_gz.setdefault("gzip_bin", "gzip")

_gunzip_in = config["gunzip_input"]
_gunzip_stem = os.path.splitext(_gunzip_in)[0] if _gunzip_in else ""
config.setdefault("gunzip_output", _gunzip_stem if _gunzip_stem else "")

if not _gunzip_in:
    raise ValueError("gunzip.smk: 需提供 config['gunzip_input']（输入 .gz 文件）")

rule gunzip:
    """gunzip：gzip -cd <in.gz> > <out>（解压 .gz 到明文文件）。"""
    input:
        gz=config["gunzip_input"]
    output:
        out=config["gunzip_output"]
    log:
        os.path.join(os.path.dirname(config["gunzip_output"]), "gunzip.log")
    message:
        "gunzip: {input.gz} -> {output.out}"
    script: "gunzip.py"
