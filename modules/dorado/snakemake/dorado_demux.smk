# dorado_demux.smk —— dorado demux 单规则（Snakemake，td2 式）
#
# 环境：dorado 不在 bioconda（无 conda env）；docker 模式用 rule container（nanoporetech
#       dorado 官方镜像，config dorado.docker_image），native 模式宿主机 PATH 直跑 dorado 二进制。
# 设计：config 驱动、单任务规则（FASTQ -> 按 barcode 拆分的 FASTQ 目录），不依赖 workflow 的
#       SAMPLES / 01_DORADO_BASECALL/demux/{sample} 层级（源 dorado.smk 的 rule dorado_demux
#       输出为带尾斜杠的占位目录且 --output-dir 指向其父目录，已改为真正的输出目录键）。
#
# 独立运行示例（native）：
#   snakemake -s modules/dorado/snakemake/dorado_demux.smk \
#       --config dorado_input_reads=basecall.fastq dorado_demux_outdir=dorado_out/demux \
#       --cores 4
# docker 模式（需 --use-container 且本机有 docker）：
#   snakemake -s modules/dorado/snakemake/dorado_demux.smk \
#       --config exec_mode=docker dorado_input_reads=basecall.fastq \
#       dorado_demux_outdir=dorado_out/demux --cores 4 --use-container
# 流程内使用（接在 dorado_basecall.smk 产物之后）：
#   include: "modules/dorado/snakemake/dorado_basecall.smk"
#   include: "modules/dorado/snakemake/dorado_demux.smk"
#   rule all:
#       input: config["dorado_demux_outdir"]   # 目录内为 <barcode>.fastq（barcode 名依试剂盒而定）
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode            : native(默认) | docker（dorado 不在 bioconda，无 conda 模式）
#   dorado.docker_image  : exec_mode=docker 时必填（默认 docker.1ms.run/nanoporetech/dorado:latest）
#   dorado.kit_name      : barcode 试剂盒名（默认 SQK-RNA004-24）
#   dorado.extra_params  : 透传 demux 附加参数（默认空）
#   dorado_input_reads   : 必填 输入 FASTQ（basecall 产物；dorado demux 也支持 SAM/BAM/POD5）
#   dorado_demux_outdir  : 输出目录（默认 dorado_out/demux；内含各 barcode FASTQ）
#   threads              : 规则调度线程（默认 4）

import os

config.setdefault("exec_mode", "native")
config.setdefault("dorado_input_reads", "")
config.setdefault("dorado_demux_outdir", os.path.join("dorado_out", "demux"))
config.setdefault("threads", 4)
_do = config.setdefault("dorado", {})
_do.setdefault("docker_image", "docker.1ms.run/nanoporetech/dorado:latest")
_do.setdefault("kit_name", "SQK-RNA004-24")
_do.setdefault("extra_params", "")

if not config["dorado_input_reads"]:
    raise ValueError("dorado_demux.smk: 需提供 config['dorado_input_reads']（输入 FASTQ）")

rule dorado_demux:
    """dorado demux：按 barcode 拆分 reads（FASTQ），输出目录内含各 barcode FASTQ。"""
    input:
        reads=config["dorado_input_reads"]
    output:
        demux_dir=directory(config["dorado_demux_outdir"])
    params:
        kit_name=_do["kit_name"],
        extra=_do["extra_params"],
        docker_image=_do["docker_image"],
        exec_mode=config["exec_mode"]
    container:
        lambda wc, output, params: params.docker_image if params.exec_mode == "docker" else None
    log:
        os.path.join(os.path.dirname(config["dorado_demux_outdir"]), "dorado_demux.log")
    threads:
        config["threads"]
    message:
        "dorado demux: {input.reads} -> {output.demux_dir}"
    shell:
        """
        mkdir -p {output.demux_dir} "$(dirname {log})"
        dorado demux {input.reads} --kit-name {params.kit_name} \
            --output-dir {output.demux_dir} {params.extra} >> {log} 2>&1
        """
