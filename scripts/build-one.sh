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

# 3. Формирование полного .config
echo "[3/5] генерация .config..."
cat << CONF > "$TREE/.config"
CONFIG_TARGET_${TARGET}=y
CONFIG_TARGET_${TARGET}_${SUBTARGET}=y
CONFIG_TARGET_${TARGET}_${SUBTARGET}_DEVICE_${PROFILE}=y
CONF

# Добавляем список сервисов
if [ -f "$BUILDER_DIR/config/packages.conf" ]; then
  echo "      внедрение сервисов из config/packages.conf..."
  cat "$BUILDER_DIR/config/packages.conf" >> "$TREE/.config"
fi

( cd "$TREE" && make defconfig )

# 4. Preflight
echo "[4/5] preflight..."
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
