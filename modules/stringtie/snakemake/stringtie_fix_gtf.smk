# stringtie_fix_gtf.smk —— stringtie fix_gtf 单规则（Snakemake，td2 式）
#
# 执行：script: 同目录 wrapper stringtie_fix_gtf.py（以 Path(__file__).parent 定位同目录
#       helper fix_gtf.awk，调系统 awk 做坐标修复 $4<=$5）。纯文本处理，不需要 stringtie
#       二进制，不挂 conda（awk 走系统 PATH），亦不依赖 workflow 的 SAMPLES / {sample} 层级。
#
# 独立运行示例：
#   snakemake -s modules/stringtie/snakemake/stringtie_fix_gtf.smk \
#       --config stringtie_gtf=sample.stringtie.gtf \
#           stringtie_fixed_gtf=sample.stringtie.fixed.gtf
# 流程内使用（逐样本坐标修复；配合 stringtie_assemble.smk / stringtie_merge.smk）：
#   include: "modules/stringtie/snakemake/stringtie_fix_gtf.smk"
#   rule all:
#       input: config["stringtie_fixed_gtf"]
#
# config 契约（均有默认；独立运行时用 --config 覆盖）：
#   stringtie_gtf        : 必填 输入 GTF
#   stringtie_fixed_gtf  : 输出修复后 GTF（默认 <输入去扩展>.fixed.gtf）

import os

config.setdefault("stringtie_gtf", "")
_gtf_in = config["stringtie_gtf"]
_gtf_stem = os.path.splitext(_gtf_in)[0] if _gtf_in else ""
config.setdefault("stringtie_fixed_gtf", _gtf_stem + ".fixed.gtf" if _gtf_stem else "")

rule stringtie_fix_gtf:
    """fix_gtf：修复 GTF 坐标颠倒（$4>$5 交换；awk 实现，纯文本，无需 stringtie）。"""
    input:
        gtf=config["stringtie_gtf"]
    output:
        fixed_gtf=config["stringtie_fixed_gtf"]
    log:
        os.path.join(os.path.dirname(config["stringtie_fixed_gtf"]), "stringtie_fix_gtf.log")
    message:
        "fix_gtf: {input.gtf} -> {output.fixed_gtf}"
    script:
        "stringtie_fix_gtf.py"
