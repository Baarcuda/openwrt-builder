# OpenWrt Builder

Модульный мета-оркестратор оптимизированных сборок OpenWrt для устройств:
* **Xiaomi AX3600** (`qualcommax / ipq807x`, SPI-NAND Dual-Boot)
* **Xiaomi Router AX6000 RA72** (`qualcommax / ipq50xx`, 2.5G Port)
* **Xiaomi AX6S** (`mediatek / mt7622`, 256MB RAM)

**Базовая система:** OpenWrt 25.12-SNAPSHOT (commit `58efa9917d4cc53fceed173529a286187649e827`, Linux 6.12, пакетный менеджер `apk-tools v3`).

---

## 1. Параметры по умолчанию

* **IP-адрес LAN:** `192.168.10.1` (маска `255.255.255.0`)
* **DHCP:** подсеть `.100` – `.250`, аренда 12ч, расширенный DNS-кэш (2048 записей, 1000 параллельных запросов)
* **Wi-Fi:** включён (SSID по модели: `ax3600`, `ax6000` или `ax6s`; пароль: `12345678`, шифрование WPA2-PSK, регион RU, WMM включён)
* **ZRAM:** аппаратное сжатие LZ4 ядра Linux 6.12 (256 МБ свопа для AX3600/AX6000, 128 МБ с лимитами памяти для AX6S)
* **Сетевой разгон и стек:** Packet Steering (RPS), Flow Offloading (Hardware NAT), Google TCP BBR, оптимизация сетевых очередей (буферы до 16 МБ)
* **Изоляция ядер (SMP Affinity):** Диспетчер `/etc/init.d/smp-tune` изолирует сетевые прерывания (Wi-Fi `ath11k`/`mt76`, Ethernet) на сетевых ядрах CPU 0–1, вытесняя сервисы шифрования на ядра приложений
* **Интерфейс:** Тема оформления `OpenWrt 2020`, полная русская локализация LuCI

---

## 2. Базовые компоненты (вкомпилированы в образ SquashFS)

Образ содержит только критические системные зависимости и низкоуровневые модули ядра. Размер базового образа для AX3600 составляет **21 МБ** при аппаратном лимите **35.75 МБ** (запас свободного места Flash: **>14.7 МБ**).

### Обход блокировок (DPI)
* [**Zapret 1**](https://github.com/bol-van/zapret) ([OpenWrt пакет от remittor](https://github.com/remittor/openwrt-zapret)): бинарник `nfqws`, LuCI-интерфейс `luci-app-zapret`
* [**Zapret 2**](https://github.com/bol-van/zapret) ([OpenWrt пакет от 1andrevich](https://github.com/1andrevich/openwrt-zapret2)): бинарник `nfqws2`, LuCI-интерфейс `luci-app-zapret2`, расширенный анализ очередей

### VPN и защищённые туннели
* [**AmneziaWG (AWG)**](https://github.com/amnezia-vpn/amneziawg-openwrt) ([фид 2Grey](https://github.com/2Grey/openwrt-amneziawg)): модули ядра `kmod-amneziawg`, `amneziawg-tools`, протокол `luci-proto-amneziawg`
* [**WireGuard**](https://www.wireguard.com/): протокол ядра `kmod-wireguard`, инструменты `wireguard-tools`, протокол `luci-proto-wireguard`
* [**OpenVPN**](https://openvpn.net/): пакет `openvpn-openssl`, веб-интерфейс `luci-app-openvpn`

### Системные протоколы и маршрутизация
* **IPv6 туннелирование:** 6in4 (RFC4213), 6rd, 6to4 (`luci-proto-ipv6`)
* **L2/L3 туннели:** GRE, GRETAP (`luci-proto-gre`), PPtP, L2TP-Static (`xl2tpd`, `ppp-mod-pppol2tp`)
* **Mesh и мосты:** B.A.T.M.A.N. Advanced (`kmod-batman-adv`, `batctl-default`), Relay Bridge (`relayd`)
* **Управление качеством связи:** SQM QoS (`luci-app-sqm`, `sqm-scripts`) с алгоритмом планирования **Cake** (`kmod-sched-cake`) для устранения Bufferbloat в среде `nftables`
* **Мониторинг и защита:** Учёт трафика хостов (`luci-app-nlbwmon`), веб-терминал (`ttyd`), контроль доступа (`luci-app-access-control`), блокировка рекламы (`luci-app-adblock-fast`), сторожевой таймер (`luci-app-watchcat`), автономная утилита TLS `openssl-util`

---

## 3. Модульные расширения (`install-extras` в `/overlay`)

Тяжеловесные бинарные клиенты Go/Rust суммарным объёмом >100 МБ вынесены из SquashFS для предотвращения переполнения Flash-памяти. Разворачиваются в постоянный раздел роутера командой `/usr/bin/install-extras`:

```bash
install-extras mosdns    # [MosDNS v5](https://github.com/sbwml/luci-app-mosdns)
install-extras fptn      # [FPTN](https://github.com/fptn-project/fptn) клиент
install-extras lalune    # [LaLune](https://github.com/Endlad2/LaLune) клиент
install-extras ssclash   # [SSClash-Go](https://github.com/zerolabnet/SSClash-Go) (Mihomo core + UI)
install-extras netbird   # [NetBird](https://github.com/netbirdio/netbird),[luci-app-netbird](https://github.com/looong-cat/luci-app-netbird) Mesh VPN
install-extras all # Установить все сервисы
```

