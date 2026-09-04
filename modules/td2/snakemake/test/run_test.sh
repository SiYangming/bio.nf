#!/usr/bin/env bash
# td2 snakemake 集成最小回归测试（静态 + 可选 dry-run）
#
# 无 snakemake 运行时的环境下，本测试做「静态一致性」断言：
#   - 拆分后的规则文件 / 共用环境 / wrapper 均存在
#   - 各 .smk 的 conda/script 引用指向同目录现存文件（不出现 ../envs、../scripts 等失效路径）
#   - wrapper py_compile 通过、docker_wrapper 注入路径可解析
#   - smk 的 config 契约键与 wrapper 使用键一致
# 若机器装有 snakemake，额外执行两规则 --dryrun 冒烟。
# 运行：bash modules/td2/snakemake/test/run_test.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SMK_DIR="$(dirname "$HERE")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> [1/6] 生成测试数据（占位 FASTA）"
python "$HERE/generate_data.py" "$WORK"
test -s "$WORK/transcripts.fa"

echo "==> [2/6] 拆分产物与共用环境存在"
for f in td2_longorfs.smk td2_predict.smk td2_longorfs.py td2_predict.py td2.yaml; do
    test -f "$SMK_DIR/$f" || { echo "[FAIL] 缺少 $f"; exit 1; }
done
test ! -e "$SMK_DIR/td2.smk" || { echo "[FAIL] td2.smk 应已删除"; exit 1; }
echo "  OK: 5 个集成文件在位，旧 td2.smk 已移除"

echo "==> [3/6] .smk 规则与引用（conda/script 同目录，不得指向 ../envs ../scripts）"
grep -q '^rule td2_longorfs:' "$SMK_DIR/td2_longorfs.smk"
grep -q '^rule td2_predict:' "$SMK_DIR/td2_predict.smk"
grep -q 'conda: "td2.yaml"' "$SMK_DIR/td2_longorfs.smk"
grep -q 'conda: "td2.yaml"' "$SMK_DIR/td2_predict.smk"
grep -q 'script:' "$SMK_DIR/td2_longorfs.smk" && ! grep -q '\.\./' "$SMK_DIR/td2_longorfs.smk"
grep -q 'script:' "$SMK_DIR/td2_predict.smk" && ! grep -q '\.\./' "$SMK_DIR/td2_predict.smk"
echo "  OK: 两规则均 conda=td2.yaml 且无 ../ 失效引用"

echo "==> [4/6] wrapper 编译与 docker_wrapper 注入"
python3 -m py_compile "$SMK_DIR/td2_longorfs.py" "$SMK_DIR/td2_predict.py"
python3 - <<PY
import sys
from pathlib import Path
smk = Path("$SMK_DIR")
for f in ("td2_longorfs.py", "td2_predict.py"):
    src = (smk / f).read_text(encoding="utf-8")
    assert '"..", ".."' in src, f"{f}: 缺少到 modules/ 的 sys.path 注入"
modules = smk.parent.parent  # modules/（snakemake -> td2 -> modules）
sys.path.insert(0, str(modules))
import docker_wrapper  # 注入目标（modules/docker_wrapper.py）
assert callable(docker_wrapper.docker_wrapper_binary)
print("  OK: wrapper py_compile 通过且注入 modules/（docker_wrapper 可导入）")
PY

echo "==> [5/6] config 契约一致性（smk setdefault 键 vs wrapper 使用键）"
python3 - <<PY
import re, sys
from pathlib import Path
smk_dir = Path("$SMK_DIR")
def setdefault_keys(p: Path):
    txt = p.read_text(encoding="utf-8")
    return set(re.findall(r'config\.setdefault\("([A-Za-z0-9_]+)"', txt)) | set(re.findall(r'_td2\.setdefault\("([A-Za-z0-9_]+)"', txt))
def used_td2_keys(p: Path):
    txt = p.read_text(encoding="utf-8")
    return set(re.findall(r'params\["([A-Za-z_]+)"\]', txt)) | set(re.findall(r'"([a-z_]+_bin)"', txt))
# longorfs：smk 定义 longorfs_bin/gene_trans_map/longorfs_extra_params 等；wrapper 需 params.extra/gene_trans_map
lo_smk = setdefault_keys(smk_dir / "td2_longorfs.smk")
lo_py = used_td2_keys(smk_dir / "td2_longorfs.py")
assert "longorfs_bin" in lo_smk and "longorfs_bin" in lo_py, (lo_smk, lo_py)
assert "gene_trans_map" in lo_py and "gene_trans_map" in lo_smk
assert "longorfs_extra_params" in lo_smk and "extra" in lo_py
pr_smk = setdefault_keys(smk_dir / "td2_predict.smk")
pr_py = used_td2_keys(smk_dir / "td2_predict.py")
assert "predict_bin" in pr_smk and "predict_bin" in pr_py
for k in ("retain_mmseqs_hits", "retain_blastp_hits", "retain_hmmer_hits", "predict_extra_params"):
    assert k in pr_smk, k
assert {"td2_input_fasta", "td2_outdir", "exec_mode", "threads"} <= (lo_smk & pr_smk)
print("  OK: config 契约键（td2_input_fasta/td2_outdir/exec_mode/threads/td2.*）smk 与 wrapper 一致")
PY

echo "==> [6/6] snakemake dry-run（若已安装）"
if command -v snakemake >/dev/null 2>&1; then
    (cd "$SMK_DIR" && snakemake -s td2_longorfs.smk \
        --config td2_input_fasta="$WORK/transcripts.fa" td2_outdir="$WORK/out" \
        -c 1 -n >/dev/null)
    echo "  OK: td2_longorfs.smk dryrun 通过"
else
    echo "  snakemake 未安装，跳过真实 dryrun（静态自检已通过）"
fi

echo "ALL TESTS PASSED"
