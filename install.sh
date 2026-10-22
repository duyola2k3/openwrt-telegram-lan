#!/bin/sh
# Cài Telegram LAN monitor trên OpenWrt.
# Dùng: wget -O- https://raw.githubusercontent.com/duyola2k3/openwrt-telegram-lan/main/install.sh | sh

set -e

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/duyola2k3/openwrt-telegram-lan/main}"
BIN="/usr/bin/telegram-lan.sh"
CONF="/etc/telegram-lan.conf"
CRON="/etc/crontabs/root"

command -v wget >/dev/null 2>&1 || {
    echo "Đang cài wget..."
    opkg update >/dev/null 2>&1
    opkg install wget >/dev/null 2>&1
}

mkdir -p /usr/bin /etc
wget -qO "$BIN" "$REPO_RAW/telegram-lan.sh"
chmod 700 "$BIN"

if [ ! -s "$CONF" ]; then
    echo "=== Cấu hình Telegram OpenWrt ==="
    printf "BOT_TOKEN: "
    read -r BOT_TOKEN
    printf "CHAT_IDS (cách nhau bằng dấu cách): "
    read -r CHAT_IDS

    [ -n "$BOT_TOKEN" ] || { echo "BOT_TOKEN không được rỗng" >&2; exit 1; }
    [ -n "$CHAT_IDS" ] || { echo "CHAT_IDS không được rỗng" >&2; exit 1; }

    umask 077
    cat > "$CONF" <<EOF
BOT_TOKEN='$BOT_TOKEN'
CHAT_IDS='$CHAT_IDS'
EOF
    chmod 600 "$CONF"
else
    echo "Giữ nguyên cấu hình hiện tại: $CONF"
fi

# Chạy vào phút 00 mỗi giờ, không tạo dòng trùng.
touch "$CRON"
grep -v '/usr/bin/telegram-lan.sh' "$CRON" > "$CRON.tmp" 2>/dev/null || true
printf '%s\n' '0 * * * * /usr/bin/telegram-lan.sh >/tmp/telegram-lan.log 2>&1' >> "$CRON.tmp"
mv "$CRON.tmp" "$CRON"
/etc/init.d/cron restart >/dev/null 2>&1 || true

echo "Đã cài xong. Đang gửi tin nhắn kiểm tra..."
if "$BIN"; then
    echo "Thành công. Báo cáo sẽ được gửi mỗi giờ."
else
    echo "Cài đặt xong nhưng gửi thử thất bại. Kiểm tra: logread | tail -30" >&2
    exit 1
fi
