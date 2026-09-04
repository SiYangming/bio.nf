# bbmap_index.smk —— BBMap 索引 单规则（Snakemake，td2 式）
#
# 环境：同目录 bbmap.yaml；wrapper：同目录 bbtools.py（command=bbmap.sh）。
# 独立运行：snakemake -s modules/bbmap/snakemake/bbmap_index.smk \
#       --config bbmap_input_fasta=ref.fa bbmap_index_dir=bbmap_out/index --cores 8 --use-conda
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   exec_mode               : conda(默认) | docker | native
#   bbmap.docker_image      : exec_mode=docker 时必填
#   bbmap.bbmap_bin         : exec_mode=native 时 bbmap.sh 路径（默认走 PATH）
#   bbmap.bbmap_build_extra : 透传 bbmap.sh 附加参数（建索引）
#   bbmap_input_fasta       : 必填 参考 FASTA
#   bbmap_index_dir         : 索引输出目录（默认 bbmap_out/index）
#   threads                 : 规则调度线程（默认 8）

import os

config.setdefault("exec_mode", "conda")
config.setdefault("bbmap_input_fasta", "")
config.setdefault("bbmap_index_dir", os.path.join("bbmap_out", "index"))
config.setdefault("threads", 8)
_bm = config.setdefault("bbmap", {})
_bm.setdefault("docker_image", "")
_bm.setdefault("bbmap_bin", "bbmap.sh")
_bm.setdefault("bbmap_build_extra", "")

rule bbmap_index:
    """bbmap.sh：参考 FASTA -> BBMap 索引目录。"""
    input:
        ref=config["bbmap_input_fasta"]
    output:
        path=directory(config["bbmap_index_dir"])
    params:
        command="bbmap.sh",
        extra=_bm["bbmap_build_extra"]
    conda: "bbmap.yaml"
    log:
        os.path.join(config["bbmap_index_dir"], "bbmap_index.log")
    threads:
        config["threads"]
    message:
        "bbmap index: {input.ref} -> {output.path}"
    script:
        "bbtools.py"
