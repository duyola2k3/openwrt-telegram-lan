# Telegram bot thông báo trạng thái mạng OpenWrt

Tool này gửi báo cáo định kỳ qua Telegram cho các giao diện `br-lan`, `eth0` và `usb0`, gồm trạng thái, MAC, RX/TX, số packet, uptime, IPv4 và IPv6.

## 1. Tạo bot và lấy Chat ID

1. Mở Telegram, nhắn `/newbot` cho `@BotFather` và lưu `BOT_TOKEN`.
2. Nhắn một tin bất kỳ vào bot. Sau đó mở:
   `https://api.telegram.org/botBOT_TOKEN/getUpdates`
3. Tìm giá trị `message.chat.id` và dùng làm `CHAT_ID`.

Nếu gửi vào group, hãy thêm bot vào group rồi nhắn một tin trong group trước khi gọi `getUpdates`. Với group thường, `CHAT_ID` thường là số âm.

## 2. Cài trên OpenWrt

Từ máy tính trong cùng mạng, chạy:

```sh
scp telegram-lan.sh root@10.0.0.1:/root/telegram-lan.sh
ssh root@10.0.0.1
```

Trên router:

```sh
mv /root/telegram-lan.sh /usr/bin/telegram-lan.sh
chmod 700 /usr/bin/telegram-lan.sh
vi /etc/telegram-lan.conf
chmod 600 /etc/telegram-lan.conf
```

Nội dung `/etc/telegram-lan.conf` nếu muốn gửi cho nhiều người/group:

```sh
BOT_TOKEN='123456789:xxxxxxxxxxxxxxxxxxxxxxxxxxxx'
CHAT_IDS='123456789 -1009876543210'
```

Các Chat ID đặt trên cùng một dòng, cách nhau bằng dấu cách. Ví dụ trên sẽ gửi cùng một báo cáo đến user `123456789` và group `-1009876543210`. Nếu chỉ gửi đến một nơi, có thể dùng `CHAT_ID='123456789'` như cấu hình cũ; script vẫn hỗ trợ.

Router cần có `wget` và kết nối Internet. Nếu thiếu wget:

```sh
opkg update
opkg install wget
```

## 3. Test ngay

```sh
/usr/bin/telegram-lan.sh
```

Nếu thành công, bot sẽ gửi ngay một tin nhắn. Không thấy tin thì kiểm tra token, chat ID và log lỗi:

```sh
/usr/bin/telegram-lan.sh
logread | tail -30
```

## 4. Chạy mỗi giờ

Mở cron:

```sh
vi /etc/crontabs/root
```

Thêm dòng sau để gửi vào phút thứ 00 mỗi giờ:

```cron
0 * * * * /usr/bin/telegram-lan.sh >/tmp/telegram-lan.log 2>&1
```

Khởi động lại cron:

```sh
/etc/init.d/cron restart
```

Có thể xem cron đã được nạp:

```sh
logread | grep -i cron
```

## Lưu ý

RX/TX trong `/sys/class/net/.../statistics` là tổng từ lúc interface được khởi tạo; chúng sẽ quay về 0 sau reboot hoặc khi interface bị reset. Vì vậy đây là báo cáo counter hiện tại, không phải lưu lượng của đúng một giờ. Nếu muốn báo cáo phần tăng thêm theo từng giờ, có thể mở rộng script để lưu counter cũ vào `/tmp` hoặc `/overlay`.
