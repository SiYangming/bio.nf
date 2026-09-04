#!/usr/bin/env bash
# isoseq 流程编排器最小回归测试（dry-run 形态）
#
# 编排器只做流程串联，dry-run 打印各 stage 将调用的命令（不真实执行工具），
# 因此本测试断言：自省可用 + dry-run 输出覆盖 01~09 全部 stage 命令构造不崩溃。
# 运行：bash native/test/run_test.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE="$(dirname "$HERE")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> [1/4] 生成测试数据（占位）"
python "$HERE/generate_data.py" "$WORK"

echo "==> [2/4] 自省：--list-stages"
out="$(python "$NATIVE/main.py" --list-stages)"
echo "$out" | grep -q '"stages"'
echo "$out" | grep -q 'gstama_merge'
echo "  OK: list-stages"

echo "==> [3/4] dry-run（minimap2 路径，chunk-total=1）"
out="$(python "$NATIVE/main.py" \
    --samplesheet "$WORK/samplesheet.csv" --primers "$WORK/primers.fa" \
    --reference "$WORK/reference.fa" --gtf "$WORK/annot.gtf" \
    --aligner minimap2 --chunk-total 1 --outdir "$WORK/out" --threads 2)"
for tok in "pbccs" "lima" "refine" "bamtools_convert" "polyacleanup" \
           "minimap2_align" "collapse" "filelist" "merge"; do
    echo "$out" | grep -q "$tok" || { echo "  [FAIL] 缺少 token: $tok"; exit 1; }
done
echo "  OK: dry-run 覆盖 CCS->lima->refine->bamtools->polyA->比对->collapse/filelist/merge"

echo "==> [4/4] python 级断言：plan 结构与 stage 计数"
python3 - <<PY
import sys
sys.path.insert(0, "$NATIVE")
from main import plan_stages
from types import SimpleNamespace
args = SimpleNamespace(
    samplesheet="$WORK/samplesheet.csv", primers="$WORK/primers.fa",
    reference="$WORK/reference.fa", gtf="$WORK/annot.gtf",
    outdir="$WORK/out2", chunk_total=1, threads=2, aligner="minimap2")
plan = plan_stages(args)
labels = [p[0] for p in plan]
assert len(plan) >= 9, labels
for need in ("pbccs", "lima", "isoseq3_refine", "gstama_polyacleanup",
             "minimap2_align", "gstama_collapse", "gstama_filelist", "gstama_merge"):
    assert need in labels, labels
print("  OK: plan_stages 返回 %d 个 stage" % len(plan))
PY

echo "ALL TESTS PASSED"
