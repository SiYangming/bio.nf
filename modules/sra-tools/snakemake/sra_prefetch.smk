# sra_prefetch.smk —— sra-tools prefetch 单规则（Snakemake，td2 式）
#
# 环境：同目录 sra-tools.yaml（conda 相对本文件目录解析，bioconda::sra-tools=3.4.1）；
#       执行：script: 同目录 sra_prefetch.py（exec_mode 三模式分派）。
# 设计：config 驱动、单任务规则（SRA accession -> .sra 文件），不依赖 workflow 的
#       SRR_Acc_List.txt / {srr_id} 目录层级（源 sra_tools.smk 的 rule sra_prefetch
#       输入为流程级 srr 列表文件，已改为显式 config 键；while 串行循环由 Snakemake
#       调度/重试覆盖，不再写 failed_*.txt）。
#
# 独立运行示例：
#   snakemake -s modules/sra-tools/snakemake/sra_prefetch.smk \
#       --config sra_srr_id=SRR12345678 sra_outdir=sra_out --cores 2 --use-conda
# 流程内使用（每 accession 一个任务；产物 sra_out/<srr_id>/<srr_id>.sra）：
#   include: "modules/sra-tools/snakemake/sra_prefetch.smk"
#   rule all:
#       input: config["sra_prefetch_sra"]   # 或由调用方按 sra_out/<srr_id>/<srr_id>.sra 构造
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode                 : conda(默认) | docker | native
#   sra_srr_id                : 必填 SRA accession（如 SRR12345678）
#   sra_outdir                : 下载根目录（默认 sra_out；产物 <outdir>/<srr_id>/<srr_id>.sra）
#   sra_tools.docker_image    : exec_mode=docker 时必填
#   sra_tools.prefetch_bin    : exec_mode=native 时 prefetch 路径（默认 prefetch）
#   sra_tools.prefetch_options: 下载选项（默认 "-f yes -t http"：强制重下 + HTTP 协议）
#   threads                   : 规则调度线程（默认 2）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("sra_srr_id", "")
config.setdefault("sra_outdir", "sra_out")
config.setdefault("threads", 2)
_st = config.setdefault("sra_tools", {})
_st.setdefault("docker_image", "")
_st.setdefault("prefetch_bin", "prefetch")
_st.setdefault("prefetch_options", "-f yes -t http")

_sra_id = config["sra_srr_id"]
if not _sra_id:
    raise ValueError("sra_prefetch.smk: 需提供 config['sra_srr_id']（SRA accession）")

_sra_file = os.path.join(config["sra_outdir"], _sra_id, _sra_id + ".sra")
config.setdefault("sra_prefetch_sra", _sra_file)

rule sra_prefetch:
    """prefetch：下载 SRA 到 <sra_outdir>/<srr_id>/<srr_id>.sra（失败可重试，日志在旁）。"""
    output:
        sra=config["sra_prefetch_sra"]
    params:
        options=_st["prefetch_options"],
        srr_id=_sra_id
    conda: "sra-tools.yaml"
    log:
        os.path.join(os.path.dirname(_sra_file), "sra_prefetch.log")
    threads:
        config["threads"]
    message:
        "prefetch: {params.srr_id} -> {output.sra}"
    script:
        "sra_prefetch.py"
