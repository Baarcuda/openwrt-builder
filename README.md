# OpenWrt Builder

Сборщик прошивок OpenWrt для устройств:
* **Xiaomi AX3600** (`qualcommax / ipq807x`)
* **Xiaomi Router AX6000 RA72** (`qualcommax / ipq50xx`)
* **Xiaomi AX6S** (`mediatek / mt7622`)

---

### Параметры по умолчанию
* **IP-адрес:** `192.168.10.1`
* **Wi-Fi:** включён (пароль: `12345678`)
* **Тема оформления:** `OpenWrt 2020`
* **Оптимизация:** BBR, Packet Steering (все ядра), Flow Offloading, кэш DNS 2048

---

### Вшитые пакеты и сервисы
* **SSClash-Go** (панель `:9091`, *по умолчанию выключен*)
* **FPTN** (веб-интерфейс в LuCI: VPN → FPTN, *по умолчанию выключен*)
* **LaLune** (DPI/TURN обход блокировок, *по умолчанию выключен*)
* **Zapret / Zapret2** (*по умолчанию выключен*)
* **Watchcat** (*по умолчанию выключен*)
* **Динамический DNS** (*по умолчанию выключен*)
* **OpenVPN** (`luci-app-openvpn`, `openvpn-openssl`)
* **WireGuard** (`luci-app-wireguard`, `kmod-wireguard`)
* **AmneziaWG** (`luci-proto-amneziawg`, `kmod-amneziawg`, `amneziawg-tools`)
* **NetBird** (`netbird`, `luci-app-netbird`)
* **L2TP-Static** (`xl2tpd`, `ppp-mod-pppol2tp`)
* **6in4** (`6in4`, `luci-proto-ipv6`)
* **Терминал** (`luci-app-ttyd`)
* **uHTTPd** (`uhttpd`, `uhttpd-mod-ubus`)
* **UPnP IGD и PCP** (`luci-app-upnp`, `miniupnpd`)
* **Тема LuCI:** `luci-theme-openwrt-2020`
* **Русская локализация:** `luci-i18n-*-ru`
* **Утилиты:** `curl`, `htop`, `nano`
