#!/bin/sh
# @gate script=lut.sh opens=rwdirect one_shot=0 gate=none pconly=0
#=====================================================================
# lut.sh — 3D LUT 滤镜（改登记表 + 写空闲槽 A18），独立于 filmlab
#=====================================================================
# 设计（2026-10-18 实机定案）：
#   · 表放 A18（0x81119F00，A17 的邻居槽），原地写入，重启即复原
#   · View4[1]/[3] + Still6[6] + BV12[12] 全部指向 A18 ⇒ 取景器与成片都生效
#     （Still 有两条互斥分支，见 apply 段注释；两条都要改）
#   · 与 filmlab 互不干扰：filmlab 走 PW 7 维标量（档位池 0xdc..0xe2），
#     本脚本走 3D LUT 槽 + 登记表；两者可叠加
#   · begin 备份、off 还原；apply 不覆盖首次备份
#
# 用法：
#   lut.sh list                 列出滤镜库
#   lut.sh begin                预检 + 备份（不写相机内存）
#   lut.sh apply <name>         应用（.cube 自动转换）
#   lut.sh off                  还原
#   lut.sh status               当前状态
#=====================================================================
set -u

D=/opt/usr/nx-ks
BB=$D/busybox
TD=$D/lut                       # 工具目录（随包安装：scripts/lut -> /opt/usr/nx-ks/lut）
LAB=/mnt/mmc/looks              # 滤镜库：*.cube / *.bin
PREF=$D/nxui-state  # Internal filesystem: avoid replacing files on camera exFAT
LOCK=/tmp/metol-lut.lock
ST=/mnt/mmc/lut/state           # 备份与状态（放 SD，随卡走）
SLOT=0x81119F00                 # A18
BAKDIR=/mnt/mmc/nxwa_regtab_20261018   # 原厂登记表备份（Still6 / BV12）
STILLBAK=$BAKDIR/still6_orig.bin
BVBAK=$BAKDIR/bv12_orig.bin

# 工具查找：优先随包安装的 $TD，其次手工部署的 /mnt/mmc/lut
pick_tool() {
    for d in "$TD" /mnt/mmc/lut; do
        [ -x "$d/$1" ] && { echo "$d/$1"; return 0; }
    done
    return 1
}
SLOTW=$(pick_tool nx_slotwrite.arm)
REGT=$(pick_tool nx_regtabwrite.arm)
CUBE=$(pick_tool cube2lut.arm)

die() { echo "ERR $*"; exit 1; }

need_tools() {
    [ -n "$SLOTW" ] && [ -x "$SLOTW" ] || die "missing nx_slotwrite.arm (looked in $TD and /mnt/mmc/lut)"
    [ -n "$REGT" ]  && [ -x "$REGT" ]  || die "missing nx_regtabwrite.arm (looked in $TD and /mnt/mmc/lut)"
}

# All mutating entry points share a lock with startup restore.
valid_name() {
    case "$1" in ''|*/*|*'|'*|*'
'*) return 1 ;; esac
    return 0
}
factory_ready() {
    "$REGT" view-status 2>/dev/null | $BB grep -qi \
      '810fd100.*81101e00.*81106b00.*81115200'
}
action_id() { cat "$PREF/action-id" 2>/dev/null || echo 0; }
mark_manual() {
    seq=$(action_id)
    case "$seq" in ''|*[!0-9]*) seq=0 ;; esac
    printf '%s\n' "$((seq+1))" > "$PREF/action-id.tmp" &&
        mv -f "$PREF/action-id.tmp" "$PREF/action-id" || die "cannot record manual action"
}
restore_ready() {
    factory_ready && return 0
    # A resumed camera may retain our pointers. Only reuse backups from the
    # same kernel session, and never capture patched pointers as factory data.
    [ "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$ST/boot-id" 2>/dev/null)" ] || return 1
    [ -f "$ST/ready" ] && [ -s "$ST/a18_orig.bin" ] &&
        [ -s "$STILLBAK" ] && [ -s "$BVBAK" ] || return 1
    "$REGT" view-status 2>/dev/null | $BB grep -qi \
        '81119f00.*81119f00.*81119f00.*81119f00'
}
prepare_session() {
    $BB mkdir -p "$ST" "$PREF" "$BAKDIR" || die "cannot create LUT state"
    boot=$(cat /proc/sys/kernel/random/boot_id) || die "cannot read boot id"
    oldboot=$(cat "$ST/boot-id" 2>/dev/null)
    if [ "$boot" != "$oldboot" ] || { [ "$mode" = restore-saved ] && factory_ready; }; then
        # A previous boot's RAM backup must never be restored into this boot.
        # On first upgrade, refuse to adopt an already modified registry.
        factory_ready || die "camera not at factory LUT baseline; restart camera and retry"
        $BB rm -f "$ST/ready" "$ST/current" "$ST/keep" "$ST/a18_orig.bin" \
            "$ST/touched" "$STILLBAK" "$BVBAK" || die "cannot reset stale session"
        printf '%s\n' "$boot" > "$ST/boot-id" || die "cannot record boot id"
    fi
}
begin_session() {
    [ ! -f "$ST/ready" ] || return 0
    "$SLOTW" read "$SLOT" "$ST/a18_orig.bin" > "$ST/begin.log" 2>&1 \
        || { cat "$ST/begin.log"; die "slot backup failed"; }
    $BB grep -q 'SLOT dumped' "$ST/begin.log" || die "slot backup not confirmed"
    : > "$ST/ready" || die "cannot record backup"
}
remember() {
    printf '%s\n' "$name" > "$PREF/saved-lut.tmp" && \
        mv -f "$PREF/saved-lut.tmp" "$PREF/saved-lut" || die "LUT applied but preference save failed"
    printf '%s\n' "$name" > "$PREF/last-lut.tmp" && \
        mv -f "$PREF/last-lut.tmp" "$PREF/last-lut" || die "cannot save menu position"
    $BB sync
}
mode=${1:-status}
case "$mode" in
  begin|apply|off|restore-saved)
    grep -qx NX500 /etc/version.info && grep -qx 1.12 /etc/version.info \
        || die "LUT writes require NX500 firmware 1.12"
    $BB mkdir "$LOCK" 2>/dev/null || die "LUT operation already running"
    trap '$BB rmdir "$LOCK" 2>/dev/null' EXIT
    trap 'exit 1' HUP INT TERM
    need_tools
    if [ "$mode" = restore-saved ]; then
        [ "$(action_id)" = "${2:-}" ] || { echo "SKIP newer manual action"; exit 0; }
    fi
    prepare_session
    case "$mode" in apply|off) mark_manual ;; esac
    ;;
esac
case "$mode" in
list)
    [ -d "$LAB" ] || die "no $LAB"
    $BB ls "$LAB" 2>/dev/null | $BB grep -E '\.(cube|bin)$' | $BB sed 's/\.[^.]*$//' | $BB sort -u
    ;;
begin)
    begin_session
    echo "OK backup ready"
    ;;
boot)
    $BB mkdir -p "$PREF" || die "cannot create internal LUT state"
    exec > "$PREF/boot.log" 2>&1
    # Copy without rename; keep this separate from the old SD preference directory.
    trap '[ ! -d "$LAB" ] || { $BB mkdir -p /mnt/mmc/lut && $BB cp "$PREF/boot.log" /mnt/mmc/lut/boot-r5.log; $BB sync; }' EXIT
    echo "START LUT auto restore r5"
    # Readiness checks are read-only. Do not block key scanning or force ISP reload.
    grep -qx NX500 /etc/version.info && grep -qx 1.12 /etc/version.info || exit 0
    [ -s "$PREF/saved-lut" ] || { echo "SKIP no internal saved LUT; apply one after update"; exit 0; }
    echo "SAVED $(cat "$PREF/saved-lut")"
    need_tools
    expected_action=$(action_id)
    tries=0; stable=0
    while [ "$tries" -lt 30 ]; do
        # Only actions after THIS startup attempt cancel it, not old boot IDs.
        [ "$(action_id)" = "$expected_action" ] || { echo "SKIP newer manual action"; exit 0; }
        if [ -d "$LAB" ] && $BB pidof di-camera-app >/dev/null && restore_ready; then
            stable=$((stable+1))
        else
            stable=0
        fi
        if [ "$stable" -ge 3 ]; then
            echo "READY restoring saved LUT"
            sh "$0" restore-saved "$expected_action"
            result=$?
            echo "RESULT $result"
            exit "$result"
        fi
        echo "WAIT attempt=$tries card=$([ -d "$LAB" ] && echo ready || echo absent) stable=$stable"
        tries=$((tries+1))
        sleep 2
    done
    die "startup LUT restore timed out; select LUT manually"
    ;;

apply|restore-saved)
    if [ "$mode" = restore-saved ]; then
        [ -s "$PREF/saved-lut" ] || exit 0
        IFS= read -r name < "$PREF/saved-lut" || exit 1
    else
        name=${2:-}
        : > "$ST/touched"
    fi
    valid_name "$name" || die "invalid LUT name"
    [ -n "$name" ] || die "usage: lut.sh apply <name>"
    need_tools
    [ -d "$LAB" ] || die "no $LAB"

    src=
    [ -f "$LAB/$name.cube" ] && src=$LAB/$name.cube
    [ -z "$src" ] && [ -f "$LAB/$name.bin" ] && src=$LAB/$name.bin
    [ -n "$src" ] || die "not found: $name (.cube or .bin)"

    $BB mkdir -p "$ST"

    # 首次进入时若未备份，先建立本次会话的还原点（不写 LUT）
    begin_session

    # .cube 需要机上转换
    table=$src
    case "$src" in
        *.cube)
            [ -x "$CUBE" ] || die "missing $CUBE"
            table=$ST/current.bin
            "$CUBE" "$src" "$table" > "$ST/convert.log" 2>&1 \
                || { cat "$ST/convert.log"; die "cube conversion failed"; }
            $BB grep -q '=== done ===' "$ST/convert.log" || { cat "$ST/convert.log"; die "conversion not confirmed"; }
            ;;
    esac

    # 写槽（不覆盖首次备份）
    "$SLOTW" write "$SLOT" "$table" > "$ST/write.log" 2>&1 \
        || { cat "$ST/write.log"; die "slot write failed"; }
    $BB grep -q 'READBACK ok' "$ST/write.log" || { cat "$ST/write.log"; die "slot write not verified"; }

    # View4 四项一次写全（色彩空间 × 屏幕色彩 四种组合都会命中）：
    #   [0] A12 AdobeRGB+开   [1] A13 sRGB+开
    #   [2] A14 AdobeRGB+关   [3] A17 sRGB+关
    # 只写 [1]/[3] 会让 AdobeRGB 下取景仍是原厂表。
    "$REGT" view-set "$SLOT" > "$ST/view.log" 2>&1 || { cat "$ST/view.log"; die "view registry write failed (stale nx_regtabwrite.arm?)"; }
    $BB grep -q 'READBACK ok' "$ST/view.log" || { cat "$ST/view.log"; die "view registry write not verified"; }
    # Still（成片）有两条互斥的选表分支（p7 0x80382B30）：
    #   +0x21 == 1（屏幕色彩开启）→ BV12 十二项
    #   否则                        → Still6 六项
    # 只改 Still6 会出现「取景有滤镜、照片没有」，所以两条都指向工作槽。
    $BB mkdir -p "$BAKDIR" || die "cannot create $BAKDIR"
    if [ -f "$STILLBAK" ]; then
        "$REGT" still-write "$SLOT" > "$ST/still.log" 2>&1
    else
        "$REGT" still-set  "$SLOT" > "$ST/still.log" 2>&1
    fi
    $BB grep -q 'READBACK ok' "$ST/still.log" || { cat "$ST/still.log"; die "still6 registry write failed"; }
    if [ -f "$BVBAK" ]; then
        "$REGT" bv-write "$SLOT" > "$ST/bv.log" 2>&1
    else
        "$REGT" bv-set  "$SLOT" > "$ST/bv.log" 2>&1
    fi
    $BB grep -q 'READBACK ok' "$ST/bv.log" || { cat "$ST/bv.log"; die "bv12 registry write failed (stale nx_regtabwrite.arm?)"; }

    # ★ 不自动触发硬件 Load。
    #   从 ARM 侧裸写 +0x00c + 脉冲会让 ISP 读到它"口袋体系"外的地址组合，
    #   表现为严重偏色花屏（3DLUT_API_GUIDE 的历史结论），且必须靠半按快门
    #   让 p7 自己走完选表流程才能复位。
    #   p7 只在自己的事件（半按/切档）里重新读取登记表，所以这里只改表与指针，
    #   由用户半按一次完成装载。半按在 LUT 模式下不会关闭面板。
    printf '%s\n' "$name" > "$ST/current"
    : > "$ST/touched"
    remember
    echo "OK applied $name"
    echo "NEXT half-press once to load LUT"
    ;;

off)
    # Disable persistence even if hardware restore fails: reboot should stay stock.
    $BB rm -f "$PREF/saved-lut" "$PREF/saved-lut.tmp" || die "cannot disable auto restore"
    : > "$ST/touched"
    $BB sync
    need_tools
    if [ ! -f "$ST/a18_orig.bin" ]; then
        echo "OK nothing to restore"
        exit 0
    fi
    rc=0
    # View4 四项写回原厂（[0]A12 [1]A13 [2]A14 [3]A17）
    "$REGT" view-restore > "$ST/off-view.log" 2>&1 || rc=1
    if [ -f "$STILLBAK" ]; then
        "$REGT" still-restore > "$ST/off-still.log" 2>&1 || rc=1
    fi
    if [ -f "$BVBAK" ]; then
        "$REGT" bv-restore > "$ST/off-bv.log" 2>&1 || rc=1
    fi
    "$SLOTW" restore "$SLOT" "$ST/a18_orig.bin" > "$ST/off-slot.log" 2>&1 || rc=1
    if [ $rc -ne 0 ]; then
        echo "ERR restore incomplete; see $ST/off-*.log"
        exit 1
    fi
    # ★ 同样不自动 reload（理由见 apply 分支）。
    #   登记表已回原厂，下一次 p7 自己的 Load（半按/切档/拍照）就会取到原厂表。
    #   若此刻画面仍停在上一张表上，半按一次即可。
    $BB rm -f "$ST/ready" "$ST/current" "$ST/keep"
    echo "OK restored (view=4 factory, still=BV12+Still6 factory, A18=original)"
    ;;

status)
    need_tools
    if [ "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$ST/boot-id" 2>/dev/null)" ] && [ -f "$ST/current" ]; then
        echo "ACTIVE $(cat "$ST/current")"
    else
        echo "IDLE"
    fi
    echo "BACKUP $([ -f "$ST/a18_orig.bin" ] && echo present || echo absent)"
    "$REGT" status 2>/dev/null | $BB sed -n '2,4p'
    ;;

*)
    echo "usage: lut.sh list|begin|apply <name>|off|status|boot"
    exit 2
    ;;
esac
