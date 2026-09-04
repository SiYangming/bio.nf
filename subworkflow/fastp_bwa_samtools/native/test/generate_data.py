#!/usr/bin/env python3
"""生成 fastp_bwa_samtools 流程编排器测试用合成输入（文本占位）。

编排器 dry-run 只做 stage 命令拼装与打印，不真实调用任何工具，
因此 reads / 参考文件只需存在、内容可为占位文本。
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

    (out / "s1_R1.fastq.gz").write_text(
        "# PLACEHOLDER: R1 FASTQ.GZ\n", encoding="utf-8"
    )
    (out / "s1_R2.fastq.gz").write_text(
        "# PLACEHOLDER: R2 FASTQ.GZ\n", encoding="utf-8"
    )
    (out / "reference.fa").write_text(
        ">chr1\n" + "ACGT" * 50 + "\n", encoding="utf-8"
    )
    print(f"已生成 fastp_bwa_samtools 测试占位数据 -> {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
