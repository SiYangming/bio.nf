#!/usr/bin/env python3
"""生成 cutadapt native 测试用的合成 FASTQ。

产出（均为未压缩 .fastq，便于直接 grep 断言）：
  <outdir>/reads_R1.fastq   8 条 SE/PE 的 R1：
                             read1-4  3' 端精确含接头 AACCGGTT + 10bp 拖尾（-a 可裁掉）
                             read5-8  5' 端精确含接头 TTGGCCAA + 主体（-g 可裁掉）
  <outdir>/reads_R2.fastq   8 条与 R1 配对的 R2（read 名一致），3' 端含 AACCGGTT + 拖尾（-A 可裁掉）

设计约束：主体序列使用 ACGT/TGCA 循环串，保证不含 AACCGGTT / TTGGCCAA 子串，
因此修剪后可稳定断言“输出序列行不再出现接头全长”。
"""
from __future__ import annotations

import sys
from pathlib import Path

# 42bp 主体：ACGT / TGCA 循环，无 AA/TT/CC/GG 双连（更不可能出现两个 8mer 接头）
BODY1 = ("ACGT" * 12)[:44]
BODY2 = ("TGCA" * 12)[:44]

ADAPTER_3P = "AACCGGTT"    # 3' adapter（-a / -A）
ADAPTER_5P = "TTGGCCAA"    # 5' adapter（-g）
TAIL = "ACGTACGTAC"        # adapter 之后的 10bp 拖尾


def fastq_record(name: str, seq: str, qual: str = "I") -> str:
    return f"@{name}\n{seq}\n+\n{qual * len(seq)}\n"


def build_r1() -> list[str]:
    recs: list[str] = []
    for i in range(1, 5):  # read1-4：3' adapter
        body = BODY1 if i % 2 else BODY2
        seq = body + ADAPTER_3P + TAIL
        recs.append(fastq_record(f"read{i}", seq))
    for i in range(5, 9):  # read5-8：5' adapter
        body = BODY1 if i % 2 else BODY2
        seq = ADAPTER_5P + body
        recs.append(fastq_record(f"read{i}", seq))
    return recs


def build_r2() -> list[str]:
    recs: list[str] = []
    for i in range(1, 9):  # 与 R1 配对；R2 全部 3' adapter
        body = BODY1 if i % 2 else BODY2
        seq = body + ADAPTER_3P + TAIL
        recs.append(fastq_record(f"read{i}", seq))
    return recs


def main() -> int:
    if len(sys.argv) != 2:
        print(f"用法: {sys.argv[0]} <outdir>", file=sys.stderr)
        return 2
    outdir = Path(sys.argv[1])
    outdir.mkdir(parents=True, exist_ok=True)
    (outdir / "reads_R1.fastq").write_text("".join(build_r1()), encoding="utf-8")
    (outdir / "reads_R2.fastq").write_text("".join(build_r2()), encoding="utf-8")
    print(f"已生成测试数据 -> {outdir}/reads_R1.fastq, reads_R2.fastq")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
