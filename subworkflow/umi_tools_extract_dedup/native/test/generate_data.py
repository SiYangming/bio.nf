#!/usr/bin/env python3
"""生成 umi_tools_extract_dedup 编排测试用占位输入（不需要真实内容，dry-run 不读文件）。"""
from __future__ import annotations

import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print(f"用法: {sys.argv[0]} <outdir>", file=sys.stderr)
        return 2
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    (out / "s1_R1.fastq.gz").write_bytes(b"")
    (out / "s1_R2.fastq.gz").write_bytes(b"")
    (out / "s1.aligned.bam").write_bytes(b"")
    print(f"已生成 umi_tools_extract_dedup 测试占位输入 -> {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
