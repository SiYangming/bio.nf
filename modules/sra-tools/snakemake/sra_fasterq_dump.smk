# sra_fasterq_dump.smk —— sra-tools fasterq-dump 单规则（Snakemake，td2 式）
#
# 环境：同目录 sra-tools.yaml（conda 相对本文件目录解析，bioconda::sra-tools=3.4.1）；
#       执行：script: 同目录 sra_fasterq_dump.py（exec_mode 三模式分派；fasterq-dump
#       --split-3，官方推荐高速版）。
# 设计：config 驱动、单任务规则（.sra -> FASTQ 输出目录）。fasterq-dump --split-3 按文库
#       布局产出 *_1/_2.fastq 或单 .fastq（文件名无法静态预知），故 rule 输出为
#       directory()，命令与旧 sra_tools.smk rule sra_fasterq_dump 一致（不传 --gzip，
#       需要压缩时给 sra_tools.dump_options 加 --gzip 并改输出扩展名约定）。
#
# 独立运行示例：
#   snakemake -s modules/sra-tools/snakemake/sra_fasterq_dump.smk \
#       --config sra_input_sra=sra_out/SRR12345678/SRR12345678.sra \
#       --cores 8 --use-conda
# 流程内使用（每任务一个 dump）：
#   include: "modules/sra-tools/snakemake/sra_prefetch.smk"
#   include: "modules/sra-tools/snakemake/sra_fasterq_dump.smk"
#   rule all:
#       input: config["sra_dump_dir"]   # 目录内含 <srr>*.fastq（SE/PE 布局由 SRA 决定）
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode                  : conda(默认) | docker | native
#   sra_input_sra              : 必填 输入 .sra 文件
#   sra_dump_dir               : 输出目录（默认 <输入 sra 所在目录>/fastq；内含 fastq）
#   sra_tools.docker_image     : exec_mode=docker 时必填
#   sra_tools.fasterq_dump_bin : exec_mode=native 时 fasterq-dump 路径（默认 fasterq-dump）
#   sra_tools.dump_options     : dump 附加选项（默认 "--split-3"）
#   sra_tools.tmpdir           : fasterq-dump 临时目录（默认 /tmp）
#   threads                    : 规则调度线程（默认 8；注入 -e）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("sra_input_sra", "")
config.setdefault("sra_tmpdir", "/tmp")
config.setdefault("threads", 8)
_st = config.setdefault("sra_tools", {})
_st.setdefault("docker_image", "")
_st.setdefault("fasterq_dump_bin", "fasterq-dump")
_st.setdefault("dump_options", "--split-3")

_sra_in = config["sra_input_sra"]
if not _sra_in:
    raise ValueError("sra_fasterq_dump.smk: 需提供 config['sra_input_sra']（.sra 文件）")

config.setdefault("sra_dump_dir", os.path.join(os.path.dirname(_sra_in), "fastq"))
_dump_dir = config["sra_dump_dir"]

rule sra_fasterq_dump:
    """fasterq-dump：.sra -> FASTQ（--split-3 -e N -t <tmpdir>；输出目录内含 SE/PE 布局文件）。"""
    input:
        sra=_sra_in
    output:
        dir=directory(_dump_dir)
    params:
        options=_st["dump_options"],
        tmpdir=config["sra_tmpdir"]
    conda: "sra-tools.yaml"
    log:
        os.path.join(os.path.dirname(_dump_dir), "sra_fasterq_dump.log")
    threads:
        config["threads"]
    message:
        "fasterq-dump: {input.sra} -> {output.dir}"
    script:
        "sra_fasterq_dump.py"
