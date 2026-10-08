#!/bin/bash

set -o pipefail

ADDR="0x84200000"
WIDTH="h"
ON_VALUE="0x1ff"
OFF_VALUE="0x0"
COUNT=10
ON_DELAY=10
OFF_DELAY=10
LOG_FILE="power_cycle_$(date +%Y%m%d_%H%M%S).log"
VERIFY=1
POWER_OFF_ON_EXIT=1
DEVMEM2=""
SUDO_PASSWORD="123456"

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  -c, --count N          Number of power cycles. Default: $COUNT
  --on-delay SEC         Delay after power on. Default: $ON_DELAY
  --off-delay SEC        Delay after power off. Default: $OFF_DELAY
  --addr ADDR            Physical address. Default: $ADDR
  --width WIDTH          devmem2 width: b, h, w. Default: $WIDTH
  --on-value VALUE       Power-on value. Default: $ON_VALUE
  --off-value VALUE      Power-off value. Default: $OFF_VALUE
  --log FILE             Log file. Default: $LOG_FILE
  --no-verify            Do not check devmem2 readback value
  --no-exit-off          Do not force power off when script exits
  -h, --help             Show this help

Example:
  $0 -c 100 --on-delay 5 --off-delay 5
EOF
}

log() {
    local message="$1"
    printf '%s %s\n' "$(date '+%F %T')" "$message" >>"$LOG_FILE"
}

say() {
    local message="$1"
    printf '%s\n' "$message" | tee -a "$LOG_FILE"
}

log_blank_line() {
    printf '\n' | tee -a "$LOG_FILE"
}

log_separator() {
    local cycle="$1"
    printf '\n========== 第 %s/%s 次 ==========\n' "$cycle" "$COUNT" | tee -a "$LOG_FILE"
}

sudo_run() {
    printf '%s\n' "$SUDO_PASSWORD" | sudo -S -p '' "$@"
}

error_exit() {
    say "ERROR: $1"
    exit 1
}

need_arg() {
    local option="$1"
    local value="${2:-}"

    if [ -z "$value" ]; then
        usage
        error_exit "$option requires a value"
    fi
}

is_positive_int() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

is_non_negative_number() {
    [[ "$1" =~ ^([0-9]+)(\.[0-9]+)?$ ]]
}

normalize_hex() {
    local value="$1"
    printf '0x%x' "$((value))"
}

parse_readback() {
    local output="$1"

    if [[ "$output" =~ readback[[:space:]]+(0x[0-9A-Fa-f]+) ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi

    return 1
}

devmem_write() {
    local label="$1"
    local value="$2"
    local expected
    local output
    local readback

    expected="$(normalize_hex "$value")"

    log "$label: write $value to $ADDR width=$WIDTH"
    if ! output=$(sudo_run "$DEVMEM2" "$ADDR" "$WIDTH" "$value" 2>&1); then
        printf '%s\n' "$output" >>"$LOG_FILE"
        error_exit "$label devmem2 command failed"
    fi

    printf '%s\n' "$output" >>"$LOG_FILE"

    if [ "$VERIFY" -eq 1 ]; then
        if ! readback=$(parse_readback "$output"); then
            error_exit "$label cannot parse readback"
        fi

        if [ "$(normalize_hex "$readback")" != "$expected" ]; then
            error_exit "$label readback mismatch: expected $expected, got $(normalize_hex "$readback")"
        fi

        log "$label: readback OK ($expected)"
    fi
}

power_off_for_exit() {
    local status=$?

    trap - EXIT INT TERM

    if [ "$POWER_OFF_ON_EXIT" -eq 1 ]; then
        log "exit cleanup: power off with $OFF_VALUE"
        sudo_run "$DEVMEM2" "$ADDR" "$WIDTH" "$OFF_VALUE" >>"$LOG_FILE" 2>&1
    fi

    exit "$status"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -c|--count)
            need_arg "$1" "${2:-}"
            COUNT="$2"
            shift 2
            ;;
        --on-delay)
            need_arg "$1" "${2:-}"
            ON_DELAY="$2"
            shift 2
            ;;
        --off-delay)
            need_arg "$1" "${2:-}"
            OFF_DELAY="$2"
            shift 2
            ;;
        --addr)
            need_arg "$1" "${2:-}"
            ADDR="$2"
            shift 2
            ;;
        --width)
            need_arg "$1" "${2:-}"
            WIDTH="$2"
            shift 2
            ;;
        --on-value)
            need_arg "$1" "${2:-}"
            ON_VALUE="$2"
            shift 2
            ;;
        --off-value)
            need_arg "$1" "${2:-}"
            OFF_VALUE="$2"
            shift 2
            ;;
        --log)
            need_arg "$1" "${2:-}"
            LOG_FILE="$2"
            shift 2
            ;;
        --no-verify)
            VERIFY=0
            shift
            ;;
        --no-exit-off)
            POWER_OFF_ON_EXIT=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage
            error_exit "unknown option: $1"
            ;;
    esac
done

if ! is_positive_int "$COUNT"; then
    error_exit "--count must be a positive integer"
fi

if ! is_non_negative_number "$ON_DELAY"; then
    error_exit "--on-delay must be a non-negative number"
fi

if ! is_non_negative_number "$OFF_DELAY"; then
    error_exit "--off-delay must be a non-negative number"
fi

case "$WIDTH" in
    b|h|w)
        ;;
    *)
        error_exit "--width must be b, h, or w"
        ;;
esac

if ! command -v devmem2 >/dev/null 2>&1; then
    error_exit "devmem2 not found"
fi
DEVMEM2="$(command -v devmem2)"

touch "$LOG_FILE" || exit 1

log "power cycle test start: count=$COUNT addr=$ADDR width=$WIDTH on=$ON_VALUE off=$OFF_VALUE on_delay=${ON_DELAY}s off_delay=${OFF_DELAY}s verify=$VERIFY"

sudo_run -v || error_exit "sudo authentication failed"
trap power_off_for_exit EXIT INT TERM

for ((cycle = 1; cycle <= COUNT; cycle++)); do
    log_separator "$cycle"
    log "cycle $cycle/$COUNT start"
    say "上电"
    devmem_write "cycle $cycle power on" "$ON_VALUE"
    say "上电完成，等待 ${ON_DELAY} 秒后下电"
    sleep "$ON_DELAY"
    say "下电"
    devmem_write "cycle $cycle power off" "$OFF_VALUE"
    if [ "$cycle" -lt "$COUNT" ]; then
        say "下电完成，等待 ${OFF_DELAY} 秒后进入下一轮"
        sleep "$OFF_DELAY"
    else
        say "下电完成"
    fi
    log "cycle $cycle/$COUNT done"
    log_blank_line
done

trap - EXIT INT TERM
log "power cycle test completed"
say "结束"
