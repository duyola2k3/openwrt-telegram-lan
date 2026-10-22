#!/bin/sh
# Gửi báo cáo trạng thái mạng OpenWrt qua Telegram.
# Tương thích BusyBox ash. Cấu hình: /etc/telegram-lan.conf

CONFIG="${CONFIG:-/etc/telegram-lan.conf}"
[ -r "$CONFIG" ] || { echo "Thiếu $CONFIG" >&2; exit 1; }
. "$CONFIG"

[ -n "$BOT_TOKEN" ] || { echo "Thiếu BOT_TOKEN" >&2; exit 1; }
# Có thể dùng CHAT_IDS='id1 id2 id3'. CHAT_ID cũ vẫn được hỗ trợ.
CHAT_IDS="${CHAT_IDS:-$CHAT_ID}"
[ -n "$CHAT_IDS" ] || { echo "Thiếu CHAT_IDS hoặc CHAT_ID" >&2; exit 1; }

API="https://api.telegram.org/bot${BOT_TOKEN}/sendMessage"

urlencode() {
    # Encode đủ các ký tự thường gặp trong báo cáo để gửi dạng form.
    printf '%s' "$1" | sed \
        -e 's/%/%25/g' \
        -e 's/ /%20/g' \
        -e 's/#/%23/g' \
        -e 's/&/%26/g' \
        -e 's/+/%2B/g' \
        -e 's/?/%3F/g' \
        -e 's/=/%3D/g' \
        -e 's/:/%3A/g' \
        -e 's/,/%2C/g'
}

value() {
    # value <interface> <rx_bytes|tx_bytes|rx_packets|tx_packets>
    cat "/sys/class/net/$1/statistics/$2" 2>/dev/null || printf '0'
}

fmt_bytes() {
    awk -v b="$1" 'BEGIN {
        if (b >= 1073741824) printf "%.2f GB", b/1073741824;
        else if (b >= 1048576) printf "%.2f MB", b/1048576;
        else if (b >= 1024) printf "%.2f KB", b/1024;
        else printf "%d B", b;
    }'
}

ipv4() { ip -4 addr show dev "$1" 2>/dev/null | awk '/inet / {print $2; exit}'; }
ipv6() { ip -6 addr show dev "$1" scope global 2>/dev/null | awk '/inet6 / {print $2; exit}'; }

interface_report() {
    iface="$1"
    title="$2"
    [ -e "/sys/class/net/$iface" ] || {
        printf '🔌 %s (%s)\nKhông tồn tại\n' "$title" "$iface"
        return
    }
    rx=$(value "$iface" rx_bytes)
    tx=$(value "$iface" tx_bytes)
    rxp=$(value "$iface" rx_packets)
    txp=$(value "$iface" tx_packets)
    mac=$(cat "/sys/class/net/$iface/address" 2>/dev/null || echo N/A)
    state=$(cat "/sys/class/net/$iface/operstate" 2>/dev/null || echo unknown)
    printf '🔌 %s (%s)\nTrạng thái: %s\nMAC: %s\nRX: %s (%s pkts.)\nTX: %s (%s pkts.)\n' \
        "$title" "$iface" "$state" "$mac" "$(fmt_bytes "$rx")" "$rxp" "$(fmt_bytes "$tx")" "$txp"
}

uptime_human() {
    awk '{s=int($1); d=int(s/86400); s%=86400; h=int(s/3600); s%=3600; m=int(s/60); s%=60; if(d>0) printf "%dd %dh %dm %ds",d,h,m,s; else printf "%dh %dm %ds",h,m,s}' /proc/uptime
}

hostname_value=$(uci -q get system.@system[0].hostname 2>/dev/null || hostname)
message="📡 OpenWrt LAN report

🕒 $(date '+%Y-%m-%d %H:%M:%S %z')
🖥 Host: $hostname_value
⏱ Uptime: $(uptime_human)

$(interface_report br-lan 'LAN bridge')
IPv4: $(ipv4 br-lan)
IPv6: $(ipv6 br-lan)

$(interface_report eth0 'Ethernet adapter')

$(interface_report usb0 'WAN / USB modem')
IPv4: $(ipv4 usb0)"

failed=0
for chat_id in $CHAT_IDS; do
    [ -n "$chat_id" ] || continue
    result=$(wget -qO- --no-check-certificate \
        --post-data="chat_id=$(urlencode "$chat_id")&text=$(urlencode "$message")" \
        "$API" 2>/dev/null)

    case "$result" in
        *'"ok":true'*) echo "Đã gửi Telegram đến $chat_id" ;;
        *) echo "Telegram API lỗi với chat $chat_id: $result" >&2; failed=1 ;;
    esac
done

exit "$failed"
