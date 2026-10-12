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

# 2. Подключение сторонних фидов и пакетов
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

# Клонируем исходники luci-app-netbird прямо в дерево пакетов
if [ ! -d "$TREE/package/luci-app-netbird" ]; then
  echo "      клонирование пакета luci-app-netbird в package/..."
  git clone --depth 1 https://github.com/looong-cat/luci-app-netbird.git "$TREE/package/luci-app-netbird"
fi

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

# Загрузка и распаковка FPTN (бинарник + LuCI в одном пакете)
echo "      загрузка FPTN (ARM64 + LuCI)..."
FPTN_TAG=$(curl -sIL -o /dev/null -w "%{url_effective}" https://github.com/fptn-project/fptn/releases/latest | tr -d "\r" | awk -F"/" "{print \$NF}")
[ -z "$FPTN_TAG" ] && FPTN_TAG="0.4.6"

FPTN_IPK="https://github.com/fptn-project/fptn/releases/download/${FPTN_TAG}/fptn-client-${FPTN_TAG}-openwrt-24.10.x-aarch64_cortex-a53.ipk"
mkdir -p /tmp/fptn_extract
if curl -sL "$FPTN_IPK" -o /tmp/fptn_extract/fptn.ipk; then
    ( cd /tmp/fptn_extract && ar -x fptn.ipk 2>/dev/null || tar -xzf fptn.ipk 2>/dev/null || true )
    if [ -f /tmp/fptn_extract/data.tar.gz ]; then
        tar -xzf /tmp/fptn_extract/data.tar.gz -C "$TREE/files/"
        echo "      FPTN успешно распакован в files/"
    elif [ -f /tmp/fptn_extract/data.tar ]; then
        tar -xf /tmp/fptn_extract/data.tar -C "$TREE/files/"
        echo "      FPTN успешно распакован в files/"
    fi
fi
rm -rf /tmp/fptn_extract

sh scripts/preflight.sh "$CARD" "$TREE"

# 5. Сборка
if [ "$DO_BUILD" -eq 1 ]; then
  echo "[5/5] компиляция..."
  if [ -n "$JOBS" ]; then
    ( cd "$TREE" && make -j"$JOBS" ) || {
      echo "::warning::Параллельная сборка завершилась ошибкой. Запуск с V=s для выявления точной причины..."
      ( cd "$TREE" && make package/install V=s ) || ( cd "$TREE" && make -j1 V=s )
    }
  else
    ( cd "$TREE" && make )
  fi
fi
