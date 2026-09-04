#!/usr/bin/env bash
# nanoseq 流程编排器最小回归测试（dry-run 形态）
#
# 编排器只做流程串联，dry-run 打印各 stage 将调用的命令（不真实执行工具），
# 因此本测试断言：自省可用 + dry-run 输出覆盖全部 stage 命令构造不崩溃。
# 运行：bash native/test/run_test.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE="$(dirname "$HERE")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> [1/5] 生成测试数据（占位）"
python "$HERE/generate_data.py" "$WORK"

echo "==> [2/5] 自省：--list-stages"
out="$(python "$NATIVE/main.py" --list-stages)"
echo "$out" | grep -q '"stages"'
echo "$out" | grep -q 'orf_prediction'
echo "  OK: list-stages"

echo "==> [3/5] dry-run #1：--orf-tool td2"
out="$(python "$NATIVE/main.py" \
    --samplesheet "$WORK/samplesheet.csv" \
    --reference "$WORK/reference.fa" --gtf "$WORK/annot.gtf" \
    --outdir "$WORK/out" --orf-tool td2 --threads 2)"
echo "$out" | grep -q 'minimap2_align'
echo "$out" | grep -q 'samtools_flagstat'
echo "$out" | grep -q 'flair_collapse'
echo "$out" | grep -q 'stringtie_merge'
echo "$out" | grep -q 'td2_longorfs'
echo "$out" | grep -q 'td2_predict'
echo "  OK: dry-run(td2) 覆盖 align/QC/FLAIR/StringTie/TD2 各 stage"

echo "==> [4/5] dry-run #2：默认 ORF 工具（transdecoder）"
out="$(python "$NATIVE/main.py" \
    --samplesheet "$WORK/samplesheet.csv" \
    --reference "$WORK/reference.fa" --gtf "$WORK/annot.gtf" \
    --outdir "$WORK/out2" --threads 2)"
echo "$out" | grep -q 'transdecoder_longorfs'
echo "$out" | grep -q 'transdecoder_predict'
echo "  OK: dry-run(transdecoder)"

echo "==> [5/5] python 级断言：plan 结构与 stage 计数"
python3 - <<PY
import sys
sys.path.insert(0, "$NATIVE")
from main import plan_stages
from types import SimpleNamespace
args = SimpleNamespace(
    samplesheet="$WORK/samplesheet.csv", reference="$WORK/reference.fa",
    gtf="$WORK/annot.gtf", outdir="$WORK/out3", threads=2,
    with_prep=False, with_dorado=False, orf_tool="td2")
plan = plan_stages(args)
labels = [p[0] for p in plan]
assert len(plan) >= 5, labels
for need in ("minimap2_align", "flair_collapse", "stringtie_merge", "td2_predict"):
    assert need in labels, labels
print("  OK: plan_stages 返回 %d 个 stage" % len(plan))
PY

echo "ALL TESTS PASSED"
