# dorado_basecall.smk —— dorado basecaller 单规则（Snakemake，td2 式）
#
# 环境：dorado 不在 bioconda（无 conda env）；docker 模式用 rule container（nanoporetech
#       dorado 官方镜像，config dorado.docker_image），native 模式宿主机 PATH 直跑 dorado 二进制。
# 设计：config 驱动、单任务规则（POD5/FAST5 -> FASTQ），不依赖 workflow 的 SAMPLES / config
#       层级（源 dorado.smk 的 rule dorado_basecall 输入直接引用 SAMPLES[wc.sample]，已改为
#       config['dorado_input_pod5']）。
#
# 独立运行示例（native；dorado 二进制需在 PATH，模型首次运行自动下载）：
#   snakemake -s modules/dorado/snakemake/dorado_basecall.smk \
#       --config dorado_input_pod5=pod5/ dorado_fastq=basecall.fastq --cores 8
# docker 模式（需 --use-container 且本机有 docker）：
#   snakemake -s modules/dorado/snakemake/dorado_basecall.smk \
#       --config exec_mode=docker dorado_input_pod5=pod5/ dorado_fastq=basecall.fastq \
#       --cores 8 --use-container
# 流程内使用：
#   include: "modules/dorado/snakemake/dorado_basecall.smk"
#   rule all:
#       input: config["dorado_fastq"]
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode           : native(默认) | docker（dorado 不在 bioconda，无 conda 模式）
#   dorado.docker_image : exec_mode=docker 时必填（默认 docker.1ms.run/nanoporetech/dorado:latest）
#   dorado.model        : basecall 模型（默认 rna004_130bps_sup@v5.1.0）
#   dorado.extra_params : 透传 basecaller 附加参数（默认 "--estimate-poly-a"）
#   dorado_input_pod5   : 必填 输入 POD5/FAST5 目录或文件
#   dorado_fastq        : 输出 FASTQ（默认 dorado_out/basecall.fastq）
#   threads             : 规则调度线程（默认 8；dorado 内部自管 GPU/CPU，命令不注入线程参数）
#
# 建议：首次运行 dorado 会自动下载模型（体积较大），docker 模式挂载 ~/.cache/dorado 复用。

import os

config.setdefault("exec_mode", "native")
config.setdefault("dorado_input_pod5", "")
config.setdefault("dorado_fastq", os.path.join("dorado_out", "basecall.fastq"))
config.setdefault("threads", 8)
_do = config.setdefault("dorado", {})
_do.setdefault("docker_image", "docker.1ms.run/nanoporetech/dorado:latest")
_do.setdefault("model", "rna004_130bps_sup@v5.1.0")
_do.setdefault("extra_params", "--estimate-poly-a")

if not config["dorado_input_pod5"]:
    raise ValueError("dorado_basecall.smk: 需提供 config['dorado_input_pod5']（POD5/FAST5 目录或文件）")

rule dorado_basecall:
    """dorado basecaller：POD5/FAST5 原始信号 -> FASTQ（stdout 直出，stderr 进 log）。"""
    input:
        pod5=config["dorado_input_pod5"]
    output:
        fastq=config["dorado_fastq"]
    params:
        model=_do["model"],
        extra=_do["extra_params"],
        docker_image=_do["docker_image"],
        exec_mode=config["exec_mode"]
    container:
        lambda wc, output, params: params.docker_image if params.exec_mode == "docker" else None
    log:
        os.path.join(os.path.dirname(config["dorado_fastq"]), "dorado_basecall.log")
    threads:
        config["threads"]
    message:
        "dorado basecaller: {input.pod5} -> {output.fastq}"
    shell:
        """
        mkdir -p "$(dirname {output.fastq})" "$(dirname {log})"
        dorado basecaller {params.model} {input.pod5} {params.extra} > {output.fastq} 2>> {log}
        test -s {output.fastq}
        """
