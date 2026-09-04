#!/usr/bin/env bash
# fastp_bwa_samtools 流程编排器最小回归测试（dry-run 形态）
#
# 编排器只做流程串联，dry-run 打印各 stage 将调用的命令（不真实执行工具），
# 因此本测试断言：自省可用 + dry-run 输出覆盖 fastp/bwa-mem2/samtools 各 stage。
# 运行：bash native/test/run_test.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE="$(dirname "$HERE")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> [1/4] 生成测试数据（占位）"
python "$HERE/generate_data.py" "$WORK"

echo "==> [2/4] 自省：--list-stages（附占位参数）"
out="$(python "$NATIVE/main.py" \
    --sample-id s1 --reads-r1 "$WORK/s1_R1.fastq.gz" --reads-r2 "$WORK/s1_R2.fastq.gz" \
    --reference "$WORK/reference.fa" --outdir "$WORK/out" \
    --list-stages)"
echo "$out" | grep -q '"stages"'
echo "$out" | grep -q '"fastp"'
echo "$out" | grep -q 'bwa-mem2'
echo "  OK: list-stages"

echo "==> [3/4] dry-run（双端 reads）"
out="$(python "$NATIVE/main.py" \
    --sample-id s1 --reads-r1 "$WORK/s1_R1.fastq.gz" --reads-r2 "$WORK/s1_R2.fastq.gz" \
    --reference "$WORK/reference.fa" --outdir "$WORK/out" --threads 2)"
echo "$out" | grep -q '\[fastp\]:'
echo "$out" | grep -q '\[bwa-mem2\]:'
echo "$out" | grep -q '\[samtools\] #1'
echo "$out" | grep -q '\.sorted\.bam'
echo "  OK: dry-run 覆盖 fastp/bwa-mem2/samtools(sort+index)"

echo "==> [4/4] python 级断言：stage 命令结构"
python3 - <<PY
import sys
sys.path.insert(0, "$NATIVE")
import main as m
from types import SimpleNamespace
args = SimpleNamespace(
    sample_id="s1", reads_r1="$WORK/s1_R1.fastq.gz", reads_r2="$WORK/s1_R2.fastq.gz",
    reference="$WORK/reference.fa", outdir="$WORK/out2", threads=2)
# stage_samtools 返回两段命令（sort + index）
name, cmds = m.stage_samtools(args.sample_id, args.outdir, args.threads)
assert name == "samtools" and len(cmds) == 2, (name, cmds)
assert "-o" in cmds[0] and cmds[0][cmds[0].index("-o") + 1].endswith(".sorted.bam"), cmds[0]
print("  OK: stage_samtools 返回 sort+index 两段命令")
PY

echo "ALL TESTS PASSED"
