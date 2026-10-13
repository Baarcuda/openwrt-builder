# OpenWrt Builder

Модульный сборщик оптимизированных прошивок OpenWrt для устройств:
* **Xiaomi AX3600** (`qualcommax / ipq807x`)
* **Xiaomi Router AX6000 RA72** (`qualcommax / ipq50xx`)
* **Xiaomi AX6S** (`mediatek / mt7622`)

**База:** OpenWrt 25.12 (Linux 6.12, пакетный менеджер `apk-tools v3`).

---

### Параметры по умолчанию
* **IP-адрес LAN:** `192.168.10.1` (маска `255.255.255.0`)
* **DHCP:** подсеть `.100` – `.250`, аренда 12ч, расширенный DNS-кэш (2048 записей, 1000 параллельных запросов)
* **Wi-Fi:** включён (SSID по имени устройства: `ax3600`, `ax6000` или `ax6s`; пароль: `12345678`, WPA2-PSK, регион RU, WMM включён)
* **ZRAM:** сжатие LZ4 (256 МБ свопа для AX3600/AX6000, 128 МБ для AX6S) с нативным бэкендом ядра Linux 6.12
* **Многопоточность и разгон сети:** Packet Steering (все ядра CPU), Flow Offloading (включая HW NAT), Google TCP BBR, сетевые буферы 16 МБ
* **Интерфейс:** Тема `OpenWrt 2020`, полная русская локализация

---

### Вшитые сервисы и обход DPI
* **SSClash-Go** (автономная панель на порту `:9091`, *по умолчанию выключен*)
* **Zapret 1** и **Zapret 2** (`luci-app-zapret`, `luci-app-zapret2`, с утилитой `bind-dig`, *по умолчанию выключены*)
* **FPTN** (веб-интерфейс в LuCI: *VPN → FPTN*, *по умолчанию выключен*)
* **NetBird Web UI** (веб-интерфейс в LuCI: *Services → NetBird*)
* **WireGuard** (`luci-app-wireguard`, `luci-proto-wireguard`, `kmod-wireguard`)
* **AmneziaWG** (`luci-proto-amneziawg`, `kmod-amneziawg`, `amneziawg-tools`)
* **OpenVPN** (`luci-app-openvpn`, `openvpn-openssl`)

---

### Сетевые протоколы и маршрутизация
* **Туннелирование IPv6:** 6in4 (RFC4213), 6rd, 6to4
* **Туннелирование L2/L3:** GRE, GRETAP, PPtP, L2TP-Static (`xl2tpd`, `ppp-mod-pppol2tp`)
* **Mesh и мосты:** Batman-adv (`kmod-batman-adv`, `batctl-default`), Relay Bridge (`relayd`)
* **Модемы:** 3G / 4G / LTE (`luci-proto-3g`, `comgt`)

---

### Системное управление и мониторинг
* **Трафик:** SQM QoS (`luci-app-sqm`, `kmod-sched-cake`), мониторинг клиентов (`luci-app-nlbwmon`)
* **Безопасность:** Access Control (`luci-app-access-control`), блокировка рекламы (`luci-app-adblock-fast`)
* **Хранилище:** Точки монтирования fstab (`block-mount`, `kmod-fs-ext4/vfat/ntfs3`, `kmod-usb-storage`)
* **Управление:** Файловый менеджер (`luci-app-filemanager`), терминал (`ttyd`), пользовательские команды (`luci-app-commands`), Watchcat, DDNS
