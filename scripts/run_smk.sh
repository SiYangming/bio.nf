#!/bin/bash
# bioskills 通用 Snakemake 流程执行入口（scripts/ 共享版，替代各 workflow 内 run_smk.sh）
# 用法（在流程目录下执行，自动探测 Snakefile / config.yaml）：
#   bash scripts/run_smk.sh [-n]            # 推荐：在 workflow/<flow>/snakemake/ 下执行
#   bash scripts/run_smk.sh [--resume] [-c N] [其它 snakemake 参数]
# 兼容两种布局：
#   1) <cwd>/Snakefile + <cwd>/config.yaml            （部署到项目的流程 snakemake/ 目录）
#   2) <cwd>/workflow/Snakefile + <cwd>/config/config.yaml （流程根目录）
# exec_mode 由 config.yaml 的 exec_mode 决定：docker | conda | apptainer
set -e

SNAKEMAKE_CMD="snakemake"

# 0. （可选）Conda 环境激活：如需固定环境请取消注释下行
if command -v conda >/dev/null 2>&1; then
    eval "$(conda shell.bash hook)"
    # conda activate snakemake
fi

# 1. 定位 Snakefile 与 config.yaml
if [[ -f "Snakefile" && -f "config.yaml" ]]; then
    SNAKEFILE="Snakefile"
    CONFIG="config.yaml"
elif [[ -f "workflow/Snakefile" && -f "config/config.yaml" ]]; then
    SNAKEFILE="workflow/Snakefile"
    CONFIG="config/config.yaml"
else
    echo "[ERROR] 未找到 Snakefile / config.yaml" >&2
    echo "        请在 workflow/<flow>/snakemake/ 或流程根目录执行本脚本" >&2
    exit 1
fi
echo "Working directory: $(pwd)"
echo "Snakefile: $SNAKEFILE | Config: $CONFIG"

# 2. 读取执行参数
EXEC_MODE=$(grep -E '^exec_mode:' "$CONFIG" | head -n 1 | sed -E 's/.*:[[:space:]]*"?([^"]*)"?.*/\1/')
echo "Execution mode: ${EXEC_MODE:-docker}"

OUTPUT_DIR=$(grep -E '^\s*output_dir:' "$CONFIG" | head -n 1 | sed -E 's/.*:[[:space:]]*"?([^"]*)"?.*/\1/')
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="testdata_results"
fi
echo "Output directory: $OUTPUT_DIR"

SNAKEMAKE_OPTS=""
case "$EXEC_MODE" in
    conda)     SNAKEMAKE_OPTS="$SNAKEMAKE_OPTS --use-conda" ;;
    docker)    : ;;
    apptainer) SNAKEMAKE_OPTS="$SNAKEMAKE_OPTS --use-apptainer --apptainer-prefix .snakemake/apptainer/cache --apptainer-args '--bind $PWD:$PWD'" ;;
esac

for arg in "$@"; do
    if [ "$arg" == "--resume" ]; then
        echo "Resume mode enabled: adding --rerun-incomplete"
        SNAKEMAKE_OPTS="$SNAKEMAKE_OPTS --rerun-incomplete"
    else
        SNAKEMAKE_OPTS="$SNAKEMAKE_OPTS $arg"
    fi
done

# 3. 运行 Snakemake（-p 打印命令；-c all 使用全部核；--latency-wait 等待文件系统延迟）
$SNAKEMAKE_CMD -s "$SNAKEFILE" \
    --configfile "$CONFIG" \
    -c all -p \
    --latency-wait 60 \
    $SNAKEMAKE_OPTS

# 4. 报告生成（dry-run 跳过）
if [[ "$SNAKEMAKE_OPTS" == *"-n"* ]] || [[ "$SNAKEMAKE_OPTS" == *"--dry-run"* ]]; then
    echo "Dry run detected. Skipping report generation."
else
    echo "Generating execution report..."
    mkdir -p "$OUTPUT_DIR"
    $SNAKEMAKE_CMD -s "$SNAKEFILE" \
        --configfile "$CONFIG" \
        --report "$OUTPUT_DIR/report.html" \
        -c all \
        $SNAKEMAKE_OPTS
    echo "Analysis complete. Results are in the '$OUTPUT_DIR' directory."
    echo "Report generated: $OUTPUT_DIR/report.html"
fi
