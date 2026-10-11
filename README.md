# OpenWrt Builder

Сборщик прошивок OpenWrt для устройств:
* **Xiaomi AX3600** (`qualcommax / ipq807x`)
* **Xiaomi Router AX6000 RA72** (`qualcommax / ipq50xx`)
* **Xiaomi AX6S** (`mediatek / mt7622`)

---

### Параметры по умолчанию
* **IP-адрес:** `192.168.10.1`
* **Wi-Fi:** включён
* **Пароль Wi-Fi:** `12345678`
* **Тема оформления:** `OpenWrt 2020`

---

### Вшитые пакеты и сервисы
* **OpenVPN** (`luci-app-openvpn`, `openvpn-openssl`)
* **WireGuard** (`luci-app-wireguard`, `kmod-wireguard`)
* **AmneziaWG** (`luci-proto-amneziawg`, `kmod-amneziawg`, `amneziawg-tools`)
* **NetBird** (`netbird`, `luci-app-netbird`)
* **L2TP-Static** (`xl2tpd`, `ppp-mod-pppol2tp`)
* **6in4** (`6in4`, `luci-proto-ipv6`)
* **Zapret / Zapret2** (`zapret`, `luci-app-zapret`)
* **Watchcat** (`luci-app-watchcat`)
* **Терминал** (`luci-app-ttyd`)
* **uHTTPd** (`uhttpd`, `uhttpd-mod-ubus`)
* **UPnP IGD и PCP** (`luci-app-upnp`, `miniupnpd`)
* **Динамический DNS** (`luci-app-ddns`, `ddns-scripts-cloudflare`)
* **Тема LuCI:** `luci-theme-openwrt-2020`
* **Русская локализация:** `luci-i18n-*-ru`
* **Утилиты:** `curl`, `htop`, `nano`
