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

### Вшитые сервисы (из коробки)
* **SSClash-Go** (веб-панель `:9091`, *по умолчанию выключен*)
* **FPTN** (веб-интерфейс в LuCI: *VPN → FPTN*, *по умолчанию выключен*)
* **Zapret 1** и **Zapret 2** (`luci-app-zapret`, `luci-app-zapret2`, *по умолчанию выключены*)
* **Watchcat** (*по умолчанию выключен*)
* **Динамический DNS** (*по умолчанию выключен*)
* **OpenVPN** (`luci-app-openvpn`, `openvpn-openssl`)
* **WireGuard** (`luci-app-wireguard`, `kmod-wireguard`)
* **AmneziaWG** (`luci-proto-amneziawg`, `kmod-amneziawg`, `amneziawg-tools`)
* **L2TP-Static** (`xl2tpd`, `ppp-mod-pppol2tp`)
* **6in4** (`6in4`, `luci-proto-ipv6`)
* **Терминал** (`luci-app-ttyd`)
* **uHTTPd** (`uhttpd`, `uhttpd-mod-ubus`)
* **UPnP IGD и PCP** (`luci-app-upnp`, `miniupnpd`)
* **Тема LuCI:** `luci-theme-openwrt-2020`
* **Русская локализация:** `luci-i18n-*-ru`
* **Утилиты:** `curl`, `htop`, `nano`

---

### Дополнительные сервисы по запросу
Для экономии Flash-памяти клиенты NetBird и LaLune устанавливаются в постоянную память `/overlay` одной командой через терминал роутера:
```bash
install-extras netbird  # Установить NetBird
install-extras lalune   # Установить LaLune
install-extras all      # Установить оба
