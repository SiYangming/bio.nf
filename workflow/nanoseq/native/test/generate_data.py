#!/usr/bin/env python3
"""生成 nanoseq 流程编排器测试用合成输入（文本占位）。

编排器 dry-run 只做 stage 命令拼装与打印，不真实调用任何工具，
因此样本表 / 参考文件只需存在、内容可为占位文本。
"""
from __future__ import annotations

import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print(f"用法: {sys.argv[0]} <outdir>", file=sys.stderr)
        return 2
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)

    (out / "samplesheet.csv").write_text(
        "sample,input_file\n"
        f"sample1,{out}/sample1.fastq.gz\n",
        encoding="utf-8",
    )
    (out / "reference.fa").write_text(
        ">chr1\n" + "ACGT" * 50 + "\n", encoding="utf-8"
    )
    (out / "annot.gtf").write_text(
        "# PLACEHOLDER GTF\n"
        'chr1\ttest\texon\t101\t150\t.\t+\t.\tgene_id "g1"; transcript_id "t1";\n',
        encoding="utf-8",
    )
    (out / "sample1.fastq.gz").write_text(
        "# PLACEHOLDER: 真实 raw reads FASTQ.GZ\n", encoding="utf-8"
    )
    print(f"已生成 nanoseq 测试占位数据 -> {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
