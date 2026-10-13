# OpenWrt Builder


* **Xiaomi AX3600** (`qualcommax / ipq807x`, SPI-NAND Dual-Boot)
* **Xiaomi Router AX6000 RA72** (`qualcommax / ipq50xx`, порт 2.5G)
* **Xiaomi AX6S** (`mediatek / mt7622`, 256MB RAM)

**Базовая система:** OpenWrt 25.12-SNAPSHOT (commit `58efa9917d4cc53fceed173529a286187649e827`, Linux 6.12).

---

## 1. Параметры по умолчанию

* **IP-адрес LAN:** `192.168.10.1` (маска `255.255.255.0`)
* **Wi-Fi:** включён (SSID по имени устройства: `ax3600`, `ax6000` или `ax6s`; пароль: `12345678`, WPA2-PSK, регион RU, )
* **ZRAM:**  LZ4 ядра Linux 6.12 (256 МБ свопа для AX3600/AX6000, 128 МБ с лимитами памяти для AX6S)
* **Сетевой  стек:** Packet Steering (RPS на все ядра), Flow Offloading ,  BBR
* **Изоляция ядер (SMP Affinity):** Диспетчер `/etc/init.d/smp-tune` изолирует сетевые прерывания (Wi-Fi `ath11k`/`mt76`, Ethernet) на ядрах CPU 0–1, вытесняя сервисы шифрования на ядра приложений (CPU 2–3)
* **Интерфейс:** Тема оформления `OpenWrt 2020`, русская локализация LuCI

---

## 2. Базовые компоненты 

### Обход блокировок (DPI)
* [**Zapret 1**](https://github.com/bol-van/zapret) ([пакет от remittor](https://github.com/remittor/openwrt-zapret)):  `nfqws`, веб-интерфейс `luci-app-zapret`
* [**Zapret 2**](https://github.com/bol-van/zapret) ([пакет от 1andrevich](https://github.com/1andrevich/openwrt-zapret2)):  `nfqws2`, веб-интерфейс `luci-app-zapret2`

### VPN
* [**AmneziaWG (AWG)**](https://github.com/amnezia-vpn/amneziawg-openwrt) ([фид 2Grey](https://github.com/2Grey/openwrt-amneziawg)): модули ядра `kmod-amneziawg`, `amneziawg-tools`, протокол `luci-proto-amneziawg`
* [**WireGuard**](https://www.wireguard.com/): протокол ядра `kmod-wireguard`, инструменты `wireguard-tools`, протокол `luci-proto-wireguard`
* [**OpenVPN**](https://openvpn.net/): пакет `openvpn-openssl`, веб-интерфейс `luci-app-openvpn`

### Системные протоколы и маршрутизация
* **IPv6 туннелирование:** 6in4 (RFC4213), 6rd, 6to4 (`luci-proto-ipv6`)
* **L2/L3 туннели:** GRE, GRETAP (`luci-proto-gre`), PPtP, L2TP-Static (`xl2tpd`, `ppp-mod-pppol2tp`)
* **Mesh и мосты:** B.A.T.M.A.N. Advanced (`kmod-batman-adv`, `batctl-default`), Relay Bridge (`relayd`)
* **Управление качеством связи:** SQM QoS (`luci-app-sqm`, `sqm-scripts`) с планировщиком **Cake** (`kmod-sched-cake`) для устранения Bufferbloat в среде `nftables`
* **Мониторинг и защита:** Учёт трафика хостов (`luci-app-nlbwmon`), веб-терминал (`ttyd`), контроль доступа (`luci-app-access-control`), блокировка рекламы (`luci-app-adblock-fast`), сторожевой таймер (`luci-app-watchcat`), автономная утилита TLS `openssl-util`

---

## 3. Пожеланию (`install-extras` в `/overlay`)

Тяжеловесные  клиенты Go/Rust   `/usr/bin/install-extras`:

* `install-extras mosdns` — [**MosDNS v5**](https://github.com/sbwml/luci-app-mosdns) (DNS и гео с LuCI)
* `install-extras fptn` — клиент [**FPTN**](https://github.com/fptn-project/fptn) 
* `install-extras lalune` — клиент [**LaLune**](https://github.com/Endlad2/LaLune) (`csqtt` и бэкенд на порту `:1062` с procd-службой)
* `install-extras ssclash` — [**SSClash-Go**](https://github.com/zerolabnet/SSClash-Go) (панель управления на порту `:9091`, ядро Mihomo/Clash, адаптер `clash-tun`)
* `install-extras netbird` — [**NetBird**](https://github.com/netbirdio/netbird), [**luci-app-netbird**](https://github.com/looong-cat/luci-app-netbird) (Mesh VPN с веб-интерфейсом)
* `install-extras all` — комплексная установка всех сервисов сразу

---
