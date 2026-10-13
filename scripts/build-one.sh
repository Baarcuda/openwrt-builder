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

[ -n "$REF" ] || REF="58efa9917d4cc53fceed173529a286187649e827"

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
git -C "$TREE" checkout -f --detach "$REF"

# Активация бэкендов LZ4 и ZSTD в ядре Linux 6.12 для ZRAM
for kcfg in "$TREE/target/linux/$TARGET/config-6.12" "$TREE/target/linux/generic/config-6.12"; do
  if [ -f "$kcfg" ]; then
    for opt in CONFIG_ZRAM_BACKEND_LZ4 CONFIG_ZRAM_BACKEND_ZSTD CONFIG_LZ4_COMPRESS CONFIG_LZ4_DECOMPRESS; do
      sed -i "/# ${opt} is not set/d" "$kcfg"
      grep -q "^${opt}=y" "$kcfg" || echo "${opt}=y" >> "$kcfg"
    done
  fi
done

# 2. Подключение сторонних фидов
if [ -f "$BUILDER_DIR/custom_feeds.conf" ]; then
  echo "[2/5] добавление custom_feeds.conf..."
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      src-git*)
        FEED_NAME=$(echo "$line" | awk '{print $2}')
        if ! grep -q "^src-[^ ]\+[[:space:]]\+${FEED_NAME}\([[:space:]]\|$\)" "$TREE/feeds.conf.default"; then
          echo "$line" >> "$TREE/feeds.conf.default"
        fi
        ;;
    esac
  done < "$BUILDER_DIR/custom_feeds.conf"
fi

echo "[2/5] обновление и установка feeds..."
( cd "$TREE" && ./scripts/feeds update -a && ./scripts/feeds install -a && ./scripts/feeds uninstall luci-app-weechat 2>/dev/null || true )

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

# 4. Подготовка файлов образа (чистый оверлей)
echo "[4/5] подготовка файлов образа..."
rm -rf "$TREE/files"
mkdir -p "$TREE/files/etc/init.d" "$TREE/files/usr/bin"

if [ -d "$BUILDER_DIR/files" ]; then
  cp -a "$BUILDER_DIR/files/." "$TREE/files/"
fi

# Гарантированная нормализация прав доступа оверлея
[ -d "$TREE/files/etc/init.d" ] && chmod 0755 "$TREE/files/etc/init.d"/* 2>/dev/null || true
[ -d "$TREE/files/etc/uci-defaults" ] && chmod 0755 "$TREE/files/etc/uci-defaults"/* 2>/dev/null || true
[ -d "$TREE/files/usr/bin" ] && chmod 0755 "$TREE/files/usr/bin"/* 2>/dev/null || true

sh scripts/preflight.sh "$CARD" "$TREE"

# 5. Сборка
if [ "$DO_BUILD" -eq 1 ]; then
  echo "[5/5] компиляция..."
  if [ -n "$JOBS" ]; then
    ( cd "$TREE" && make -j"$JOBS" ) || {
      echo "::warning::Параллельная сборка упала. Fallback на V=s..."
      ( cd "$TREE" && make package/install V=s ) || ( cd "$TREE" && make -j1 V=s )
    }
  else
    ( cd "$TREE" && make )
  fi
fi
