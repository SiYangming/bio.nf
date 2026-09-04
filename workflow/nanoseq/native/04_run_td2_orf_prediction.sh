#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Stage 04 · TD2 ORF 预测：GTF→cDNA（gtf_genome_to_cdna_fasta.pl）→ TD2.LongOrfs → TD2.Predict
# 输入：stringtie_results/（03 StringTie 产物：merged_gtf 或 assembled_gtf/fixed_gtf，merged/sample 双模式）
# 产物：td2_orf_prediction/{merged,sample}_results/final_peptides.fasta（输出目录对应 04_2_TD2 段）
# ---------------------------------------------------------------------------

###########################################################################
# 终极防重跑版 TD2 编码区预测脚本
# 新增功能：status / stop / clean 子命令 + 锁文件 + PID 双保险
###########################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
LOCK_FILE="${SCRIPT_DIR}/.${SCRIPT_NAME}.lock"
OUTPUT_ROOT="${SCRIPT_DIR}/td2_orf_prediction"
PID_FILE="${OUTPUT_ROOT}/td2_pid.pid"
MASTER_LOG="${OUTPUT_ROOT}/td2_master.log"

# =============== 锁机制 ===============
acquire_lock() {
    if ! mkdir "${LOCK_FILE}" 2>/dev/null; then
        echo "错误：检测到另一个 $SCRIPT_NAME 正在运行！"
        [ -f "$PID_FILE" ] && echo "旧进程 PID: $(cat "$PID_FILE")"
        echo "解决方法："
        echo "   $0 status     # 查看状态"
        echo "   $0 stop       # 正常停止"
        echo "   $0 clean      # 强制清理并重新运行"
        exit 1
    fi
}

release_lock() {
    rm -rf "${LOCK_FILE}" 2>/dev/null || true
}

trap release_lock EXIT

# =============== 子命令 ===============
show_status() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "任务运行中 → PID: $(cat "$PID_FILE")"
        echo "实时日志 → tail -f \"$MASTER_LOG\""
    else
        echo "无运行中的任务"
        [ -f "$PID_FILE" ] && echo "发现残留 PID 文件，可执行 $0 clean 清理"
    fi
}

stop_task() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "正在终止进程 $pid ..."
            kill -9 "$pid" && echo "已终止"
        else
            echo "进程 $pid 已不存在"
        fi
        rm -f "$PID_FILE"
    fi
    release_lock
    echo "任务已停止，锁已释放"
}

clean_all() {
    echo "正在强制停止并彻底清理 td2_orf_prediction 目录..."
    stop_task
    rm -rf "${OUTPUT_ROOT}"
    release_lock
    echo "清理完成！现在可以安全重新运行：./$SCRIPT_NAME"
}

case "${1:-}" in
    status) show_status; exit 0 ;;
    stop|kill) stop_task; exit 0 ;;
    clean) clean_all; exit 0 ;;
    "") ;;  # 继续正常启动
    run) ;; # 后台真正执行入口
    *) echo "用法: $0 [status|stop|clean]"; exit 1 ;;
esac

# =============== 正常启动入口 ===============
if [ "${1:-}" != "run" ]; then
    acquire_lock
    mkdir -p "$OUTPUT_ROOT"
    echo "===== TD2 编码区预测启动（$(date)）=====" | tee "$MASTER_LOG"
    echo "输出目录：$OUTPUT_ROOT" | tee -a "$MASTER_LOG"
    echo "日志实时查看：tail -f \"$MASTER_LOG\""

    nohup "$0" run > "$MASTER_LOG" 2>&1 &
    echo $! > "$PID_FILE"
    echo "后台任务已启动！PID: $(cat "$PID_FILE")"
    echo "常用命令："
    echo "   $0 status    # 查看状态"
    echo "   $0 stop      # 停止任务"
    echo "   $0 clean     # 强制清理并重跑（最常用！）"
    exit 0
fi

# =============== 真正干活的后台进程从这里开始 ===============
acquire_lock  # 再次确认锁

###########################################################################
# 下面是你原来的全部核心代码（几乎零改动，只是删除了旧的后台启动部分）
###########################################################################
export GTF_TO_FASTA=${GTF_TO_FASTA:-gtf_genome_to_cdna_fasta.pl}   # TransDecoder util：支持 export 绝对路径，缺省从 PATH 检测
export TD2_LONGORFS=${TD2_LONGORFS:-TD2.LongOrfs}                  # 支持 export 绝对路径；缺省从 PATH 检测（未安装会提示）
export TD2_PREDICT=${TD2_PREDICT:-TD2.Predict}
export INPUT_GTF_DIR=${INPUT_GTF_DIR:-./stringtie_results/assembled_gtf/fixed_gtf}     # sample 模式输入
export MERGED_GTF=${MERGED_GTF:-./stringtie_results/merged_gtf/stringtie_merged_nonredundant.gtf}  # merged 模式输入
export GENOME_FASTA=${GENOME_FASTA:-./hg38}                         # 参考基因组（GTF->cDNA 用）
export SAMPLE_OUTPUT_DIR="${OUTPUT_ROOT}/sample_results"
export MERGED_OUTPUT_DIR="${OUTPUT_ROOT}/merged_results"
export LOG_DIR="${OUTPUT_ROOT}/logs"
export THREADS=9
export TD2_THREADS=20
export MIN_PROT_LEN=50
export SINGLE_BEST=1
export GENETIC_CODE=1
export DEFAULT_MODE="merged"

show_help() {
    echo "===== TD2编码区预测脚本（支持双模式）====="
    echo "使用方式："
    echo "  ./$SCRIPT_NAME              # 默认 merged 模式"
    echo "  ./$SCRIPT_NAME --mode sample # 样本单独模式"
    echo "  ./$SCRIPT_NAME clean        # 一键清理并重跑（推荐）"
    echo "  ./$SCRIPT_NAME stop         # 停止运行"
    echo "  ./$SCRIPT_NAME status       # 查看状态"
    echo "日志查看：tail -f $MASTER_LOG"
}

RUN_MODE="${DEFAULT_MODE}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) show_help; exit 0 ;;
        --mode) RUN_MODE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [[ "$RUN_MODE" != "merged" && "$RUN_MODE" != "sample" ]]; then
    echo "ERROR: 模式必须是 merged 或 sample"
    exit 1
fi

echo "[$(date +%Y-%m-%d_%H:%M:%S)] 开始运行（模式：$RUN_MODE）" | tee -a "$MASTER_LOG"

check_dependency() { # $1=可执行名/路径  $2=env 变量名  $3=安装提示
    local exe="$1" var="${2:-}" hint="${3:-}"
    if command -v "$exe" &> /dev/null; then return 0; fi
    echo "[$(date +%Y-%m-%d_%H:%M:%S)] ERROR: 未找到工具: $exe" | tee -a "$MASTER_LOG" >&2
    [ -n "$var" ] && echo "  提示: export ${var}=/绝对/路径/${exe##*/}" >&2
    [ -n "$hint" ] && echo "  安装: ${hint}" >&2
    exit 1
}

check_dependency perl perl "conda install -c conda-forge perl"
check_dependency "${GTF_TO_FASTA}" GTF_TO_FASTA "安装 TransDecoder 后将其 util/ 加入 PATH（或 export GTF_TO_FASTA=/绝对/路径/gtf_genome_to_cdna_fasta.pl）"
check_dependency "${TD2_LONGORFS}" TD2_LONGORFS "安装 td2（TD2.LongOrfs），环境参考 modules/td2"
check_dependency "${TD2_PREDICT}" TD2_PREDICT "安装 td2（TD2.Predict），环境参考 modules/td2"
check_dependency awk awk "awk 通常随系统自带"
[ "$RUN_MODE" = "sample" ] && check_dependency parallel parallel "conda install -c conda-forge parallel"

# 输入守卫（缺失提示 export 绝对路径）
[ -f "$GENOME_FASTA" ] || {
    echo "[ERROR] 参考基因组不存在: $GENOME_FASTA（export GENOME_FASTA=/绝对/路径/hg38）" | tee -a "$MASTER_LOG" >&2
    exit 1
}
if [ "$RUN_MODE" = "merged" ]; then
    [ -f "$MERGED_GTF" ] || {
        echo "[ERROR] merged GTF 不存在: $MERGED_GTF（export MERGED_GTF=/绝对/路径/merged.gtf）" | tee -a "$MASTER_LOG" >&2
        exit 1
    }
else
    [ -d "$INPUT_GTF_DIR" ] || {
        echo "[ERROR] 目录不存在: $INPUT_GTF_DIR（export INPUT_GTF_DIR=/绝对/路径/fixed_gtf）" | tee -a "$MASTER_LOG" >&2
        exit 1
    }
fi

mkdir -p "$LOG_DIR" "$SAMPLE_OUTPUT_DIR" "$MERGED_OUTPUT_DIR"

process_td2_single() {
    local gtf_file="$1"
    local out_prefix="$2"
    local out_dir="${OUTPUT_ROOT}/${out_prefix}_results"
    local log_file="${LOG_DIR}/${out_prefix}.log"
    mkdir -p "$out_dir"
    touch "$log_file"

    echo "===== 开始处理 $out_prefix =====" >> "$log_file"
    local cdna_fasta="${out_dir}/${out_prefix}.cdna.fasta"
    perl "${GTF_TO_FASTA}" "$gtf_file" "${GENOME_FASTA}" > "$cdna_fasta" 2>> "$log_file"
    [ -s "$cdna_fasta" ] || { echo "ERROR: CDNA为空 $out_prefix" >> "$log_file"; exit 1; }

    "${TD2_LONGORFS}" -t "$cdna_fasta" -O "$out_dir" -m "$MIN_PROT_LEN" --top "$SINGLE_BEST" -G "$GENETIC_CODE" -@ "$TD2_THREADS" -v >> "$log_file" 2>&1
    "${TD2_PREDICT}" -t "$cdna_fasta" -O "$out_dir" -G "$GENETIC_CODE" -v >> "$log_file" 2>&1

    local final_pep="${out_dir}/final_peptides.fasta"
    local count=$(grep -c "^>" "$final_pep" 2>/dev/null || echo 0)
    echo "===== $out_prefix 完成！编码区数量：$count =====" >> "$log_file"
    echo "[$(date +%Y-%m-%d_%H:%M:%S)] $out_prefix 完成（$count 个）" | tee -a "$MASTER_LOG"
}
export -f process_td2_single
export GTF_TO_FASTA GENOME_FASTA TD2_LONGORFS TD2_PREDICT MIN_PROT_LEN SINGLE_BEST GENETIC_CODE TD2_THREADS OUTPUT_ROOT LOG_DIR MASTER_LOG

if [ "$RUN_MODE" = "merged" ]; then
    process_td2_single "$MERGED_GTF" "merged"
else
    GTF_FILES=("$INPUT_GTF_DIR"/*.stringtie.fixed.gtf)
    printf "%s\n" "${GTF_FILES[@]}" | parallel -j "$THREADS" --progress bash -c 'process_td2_single "$0" "$(basename "$0" .stringtie.fixed.gtf)"'
fi

echo "[$(date +%Y-%m-%d_%H:%M:%S)] ===== TD2 编码区预测全部完成！=====" | tee -a "$MASTER_LOG"
release_lock
