#!/bin/sh
set -eu

CARD=""
JOBS=""
TREE="openwrt"
DO_BUILD=1
BUILDER_DIR="$(pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --jobs) shift; JOBS="${1:-}" ;;
    --no-build) DO_BUILD=0 ;;
    -h|--help) exit 0 ;;
    *) [ -z "$CARD" ] && CARD="$1" ;;
  esac
  shift
done

[ -n "$CARD" ] || { echo "укажите карточку: sh scripts/build-one.sh devices/<file>.yml" >&2; exit 2; }

get_field() {
  sed -n "s/^${2}:[[:space:]]*//p" "$1" | head -n 1 | sed 's/[[:space:]]*#.*//' | tr -d ' '
}

DEVICE=$(get_field "$CARD" device)
TARGET=$(get_field "$CARD" target)
SUBTARGET=$(get_field "$CARD" subtarget)
PROFILE=$(get_field "$CARD" profile)
REF=$(get_field "$CARD" ref)

echo "=========================================================="
echo " Сборка: $DEVICE ($TARGET/$SUBTARGET - $PROFILE)"
echo " коммит: $REF"
echo "=========================================================="

# 1. Дерево OpenWrt
if [ -d "$TREE/.git" ]; then
  echo "[1/5] дерево уже есть — checkout $REF"
  git -C "$TREE" fetch --all --tags --prune
else
  echo "[1/5] клонирую OpenWrt..."
  git clone https://git.openwrt.org/openwrt/openwrt.git "$TREE"
fi
git -C "$TREE" checkout --detach "$REF"

# 2. Подключение сторонних фидов
if [ -f "$BUILDER_DIR/custom_feeds.conf" ]; then
  echo "[2/5] добавление custom_feeds.conf..."
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      src-git*)
        FEED_NAME=$(echo "$line" | awk '{print $2}')
        if ! grep -q " $FEED_NAME " "$TREE/feeds.conf.default"; then
          echo "$line" >> "$TREE/feeds.conf.default"
        fi
        ;;
    esac
  done < "$BUILDER_DIR/custom_feeds.conf"
fi

echo "[2/5] обновление и установка feeds..."
( cd "$TREE" && ./scripts/feeds update -a && ./scripts/feeds install -a )

# 3. Формирование .config
echo "[3/5] генерация .config..."
cat << CONF > "$TREE/.config"
CONFIG_TARGET_${TARGET}=y
CONFIG_TARGET_${TARGET}_${SUBTARGET}=y
CONFIG_TARGET_${TARGET}_${SUBTARGET}_DEVICE_${PROFILE}=y
CONF

if [ -f "$BUILDER_DIR/config/packages.conf" ]; then
  cat "$BUILDER_DIR/config/packages.conf" >> "$TREE/.config"
fi

( cd "$TREE" && make defconfig )

# 4. Подготовка файлов образа
echo "[4/5] подготовка файлов образа..."
mkdir -p "$TREE/files/opt/clash/bin" "$TREE/files/etc/init.d" "$TREE/files/usr/bin"

if [ -d "$BUILDER_DIR/files" ]; then
  cp -r "$BUILDER_DIR/files/"* "$TREE/files/"
fi

# Скачивание SSClash-Go
echo "      загрузка SSClash-Go..."
curl -sL https://github.com/zerolabnet/SSClash-Go/releases/latest/download/ssclash-linux-arm64 -o "$TREE/files/opt/clash/bin/ssclash"
chmod +x "$TREE/files/opt/clash/bin/ssclash"
curl -sL https://github.com/zerolabnet/SSClash-Go/releases/latest/download/ssclash-openwrt-service.tar.gz | tar -xz -C "$TREE/files/"
chmod +x "$TREE/files/etc/init.d/ssclash"

# Загрузка и распаковка официального пакета FPTN под OpenWrt ARM64
echo "      загрузка FPTN Client (OpenWrt 25.12 arm64)..."
FPTN_URL=$(curl -s https://api.github.com/repos/fptn-project/fptn/releases/latest | grep "browser_download_url.*openwrt-25.12.*aarch64.*\.apk" | head -n 1 | cut -d '"' -f 4 || true)
if [ -n "$FPTN_URL" ]; then
  curl -sL "$FPTN_URL" -o /tmp/fptn.apk
  tar -xzf /tmp/fptn.apk -C "$TREE/files/" 2>/dev/null || tar -xf /tmp/fptn.apk -C "$TREE/files/" 2>/dev/null || true
  rm -f /tmp/fptn.apk
fi

# Сборка LaLune (Go binary для ARM64)
echo "      сборка LaLune из GitHub..."
rm -rf /tmp/lalune
if git clone --depth 1 https://github.com/Endlad2/LaLune.git /tmp/lalune 2>/dev/null; then
  ( cd /tmp/lalune && CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags="-s -w" -o "$TREE/files/usr/bin/lalune" . 2>/dev/null ) || true
  chmod +x "$TREE/files/usr/bin/lalune" 2>/dev/null || true
  rm -rf /tmp/lalune
fi

sh scripts/preflight.sh "$CARD" "$TREE"

# 5. Сборка
if [ "$DO_BUILD" -eq 1 ]; then
  echo "[5/5] компиляция..."
  if [ -n "$JOBS" ]; then
    ( cd "$TREE" && make -j"$JOBS" )
  else
    ( cd "$TREE" && make )
  fi
fi
