# pbccs.smk —— pbccs ccs 单规则（Snakemake，td2 式）
#
# 环境：同目录 pbccs.yaml（conda 相对本文件目录解析）；wrapper：同目录 pbccs.py。
# 设计：config 驱动、单命令 ccs 分块规则（subreads BAM -> 单块 HiFi/CCS BAM），不依赖 workflow 的
#       SAMPLES / {sample} 目录层级；块号走输出目标 {chunk} 通配符（1..chunk_total），样本名由输入
#       subreads 文件名去 .subreads 推导（与 native main.py 一致）。单块 = 单条命令、无额外逻辑
#       （mkdir 仅建目录），docker/native/conda 三模式统一走同目录 wrapper pbccs.py
#       （分派经共享 modules/docker_wrapper.py 的 docker_wrapper_binary(config, "pbccs",
#       "ccs_bin", "ccs")，参考 modules/samtools/snakemake/samtools_sort.py）。
#
# 独立运行示例（chunk_total=2 时请求 chunk1/chunk2 两个目标即可并行调度）：
#   snakemake -s modules/pbccs/snakemake/pbccs.smk \
#       --config pbccs_subreads=sample.subreads.bam pbccs_outdir=ccs_out pbccs_chunk_total=2 \
#       --cores 8 --use-conda \
#       ccs_out/sample.chunk1.bam ccs_out/sample.chunk2.bam
# 流程内使用（多块目标用 expand/目标列表展开；chunk_total=1 即不分块）：
#   include: "modules/pbccs/snakemake/pbccs.smk"
#   rule all:
#       input: [os.path.join(config["pbccs_outdir"], f"{sample}.chunk{n}.bam")
#               for n in range(1, config["pbccs_chunk_total"] + 1)]   # sample 自行替换为样本名
#
# config 契约（均有默认；独立运行时用 --config 覆盖；嵌套键 CLI 点号写法如 'pbccs.min_rq=0.95'）：
#   exec_mode                : conda(默认) | docker | native
#   pbccs.docker_image       : exec_mode=docker 时必填（镜像名）
#   pbccs.ccs_bin            : exec_mode=native 时的 ccs 路径（默认 ccs，走 PATH）
#   pbccs_subreads          : 必填 输入 subreads BAM（*.subreads.bam）
#   pbccs_outdir            : 输出目录（默认 ccs_out；<sample>.chunk{n}.bam/.pbi/.report.txt/
#                             .report.json/.metrics.json.gz 平铺其下，另含 .ccs.log）
#   pbccs_chunk_total       : 总分块数（默认 4；--chunk {chunk}/{chunk_total}）
#   pbccs.min_rq            : 最小读取质量阈值（默认 0.9）
#   pbccs.min_passes        : 最小 subread 通过次数（默认 3）
#   pbccs.min_snr           : 最小信噪比（默认 2.5）
#   pbccs.min_length        : 最小序列长度（默认 10）
#   pbccs.max_length        : 最大序列长度（默认 50000）
#   pbccs.top_passes        : 每个 ZMW 最多使用的 subread 通过次数（默认 60）
#   pbccs.ccs_extra_params  : 透传 ccs 额外参数（高级用法，慎用）
#   threads                 : 规则调度线程（默认 8；-j 透传 ccs）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("pbccs_subreads", "")
config.setdefault("pbccs_outdir", "ccs_out")
config.setdefault("pbccs_chunk_total", 4)
config.setdefault("threads", 8)
_pbccs = config.setdefault("pbccs", {})
_pbccs.setdefault("min_rq", 0.9)
_pbccs.setdefault("min_passes", 3)
_pbccs.setdefault("min_snr", 2.5)
_pbccs.setdefault("min_length", 10)
_pbccs.setdefault("max_length", 50000)
_pbccs.setdefault("top_passes", 60)
_pbccs.setdefault("ccs_extra_params", "")
_pbccs.setdefault("docker_image", "")
_pbccs.setdefault("ccs_bin", "ccs")

# 样本名：subreads 文件名去 .subreads/.bam（如 sample.subreads.bam -> sample）
_pbccs_sample = os.path.splitext(os.path.basename(config["pbccs_subreads"]))[0].replace(".subreads", "")
_pbccs_base = os.path.join(config["pbccs_outdir"], f"{_pbccs_sample}.chunk{{chunk}}")

rule pbccs:
    """ccs：subreads BAM -> 单块 HiFi/CCS BAM（--chunk {chunk}/{chunk_total}，含报告与过滤阈值）。"""
    input:
        subreads=config["pbccs_subreads"]
    output:
        bam=f"{_pbccs_base}.bam",
        pbi=f"{_pbccs_base}.bam.pbi",
        report=f"{_pbccs_base}.report.txt",
        report_json=f"{_pbccs_base}.report.json",
        metrics=f"{_pbccs_base}.metrics.json.gz"
    params:
        chunk_total=config["pbccs_chunk_total"],
        min_rq=_pbccs["min_rq"],
        min_passes=_pbccs["min_passes"],
        min_snr=_pbccs["min_snr"],
        min_length=_pbccs["min_length"],
        max_length=_pbccs["max_length"],
        top_passes=_pbccs["top_passes"],
        extra=_pbccs["ccs_extra_params"]
    conda: "pbccs.yaml"
    log:
        f"{_pbccs_base}.ccs.log"
    threads:
        config["threads"]
    message:
        "pbccs ccs: {input.subreads} -> {output.bam} (chunk {wildcards.chunk}/{params.chunk_total})"
    script:
        "pbccs.py"
