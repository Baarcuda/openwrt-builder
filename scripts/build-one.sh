#!/bin/sh
# build-one.sh — собрать OpenWrt по одной карточке devices/*.yml
#
# Использование:
#   sh scripts/build-one.sh devices/xiaomi-ax6s.yml
#   sh scripts/build-one.sh devices/xiaomi-ax6s.yml --jobs 4
#   sh scripts/build-one.sh devices/xiaomi-ax6s.yml --no-build   # остановиться после preflight
#   sh scripts/build-one.sh devices/xiaomi-ax6s.yml --tree openwrt
#
# Дерево выбирается так: --tree  >  поле tree: в карточке  >  openwrt.
# Запускать из корня сборщика. Зависимости: git, make, nproc/grep, sed, sh.

set -eu

CARD=""
JOBS=""
TREE=""          # пусто = ещё не выбрано: подставится из карточки, иначе openwrt
DO_BUILD=1
DO_FEEDS=1
DO_CONFIG=1

while [ $# -gt 0 ]; do
  case "$1" in
    --jobs) shift; JOBS="${1:-}" ;;
    --tree) shift; TREE="${1:-}" ;;
    --no-build) DO_BUILD=0 ;;
    --no-feeds) DO_FEEDS=0 ;;
    --no-config) DO_CONFIG=0 ;;
    -h|--help)
      sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    -*)
      echo "неизвестный аргумент: $1" >&2; exit 2 ;;
    *)
      [ -z "$CARD" ] && CARD="$1" || { echo "лишний аргумент: $1" >&2; exit 2; } ;;
  esac
  shift
done

[ -n "$CARD" ] || { echo "укажите карточку: sh scripts/build-one.sh devices/<file>.yml" >&2; exit 2; }
[ -f "$CARD" ] || { echo "!! карточка не найдена: $CARD" >&2; exit 2; }
[ -f scripts/preflight.sh ] || { echo "!! нет scripts/preflight.sh — запускать из корня сборщика" >&2; exit 2; }

get_field() {
  sed -n "s/^${2}:[[:space:]]*//p" "$1" | head -n 1 \
    | sed 's/[[:space:]]*#.*//' | sed 's/[[:space:]]*$//'
}

DEVICE=$(get_field "$CARD" device)
TARGET=$(get_field "$CARD" target)
SUBTARGET=$(get_field "$CARD" subtarget)
PROFILE=$(get_field "$CARD" profile)
ARCH=$(get_field "$CARD" arch)
REF=$(get_field "$CARD" ref)
CARD_TREE=$(get_field "$CARD" tree)

for v in DEVICE TARGET SUBTARGET PROFILE REF; do
  eval "val=\$$v"
  [ -n "$val" ] || { echo "!! в карточке не задано поле: $v" >&2; exit 2; }
done

# приоритет выбора дерева: --tree  >  tree: в карточке  >  openwrt
TREE_SOURCE="--tree"
if [ -z "$TREE" ]; then
  if [ -n "$CARD_TREE" ]; then
    TREE="$CARD_TREE"; TREE_SOURCE="карточка"
  else
    TREE="openwrt";    TREE_SOURCE="по умолчанию"
  fi
fi

echo "=========================================================="
echo " build-one: $DEVICE"
echo "   card    : $CARD"
echo "   target  : $TARGET/$SUBTARGET"
echo "   profile : $PROFILE"
echo "   arch    : $ARCH"
echo "   ref     : $REF"
echo "   tree    : $TREE  ($TREE_SOURCE)"
echo "   jobs    : ${JOBS:-<по умолчанию: make сам>}"
echo "=========================================================="

# --- 1. дерево ---
if [ -d "$TREE/.git" ]; then
  echo "[1/6] дерево уже есть — fetch и checkout $REF"
  git -C "$TREE" fetch --all --tags --prune
else
  if [ -e "$TREE" ]; then
    echo "!! '$TREE' существует, но это не git-дерево ($TREE/.git нет)." >&2
    echo "   Уберите его или укажите другое имя через --tree. Не затираю." >&2
    exit 2
  fi
  echo "[1/6] клонирую OpenWrt в '$TREE'"
  git clone https://git.openwrt.org/openwrt/openwrt.git "$TREE"
fi

echo "      checkout $REF"
git -C "$TREE" checkout --detach "$REF"

HEAD_SHA=$(git -C "$TREE" rev-parse HEAD)
if [ "$HEAD_SHA" = "$REF" ] || [ "$HEAD_SHA" = "$(git -C "$TREE" rev-parse "$REF")" ]; then
  echo "      ok  HEAD = $HEAD_SHA"
else
  echo "      FAIL HEAD = $HEAD_SHA, ожидался $REF" >&2
  exit 1
fi

# --- 2. config ---
if [ "$DO_CONFIG" -eq 1 ]; then
  echo "[2/6] готовлю .config под профиль $TARGET/$SUBTARGET/$PROFILE"
  if [ -f "$TREE/.config" ]; then
    if grep -q "^CONFIG_TARGET_${TARGET}=y" "$TREE/.config" 2>/dev/null; then
      echo "      .config уже под $TARGET — дособеру поверх"
    else
      echo "      в .config чужой таргет — откладываю в .config.bak"
      mv "$TREE/.config" "$TREE/.config.bak"
    fi
  fi
    cat << EOF > "$TREE/.config"
CONFIG_TARGET_${TARGET}=y
CONFIG_TARGET_${TARGET}_${SUBTARGET}=y
CONFIG_TARGET_${TARGET}_${SUBTARGET}_DEVICE_${PROFILE}=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-ssl=y
EOF
    ( cd "$TREE" && make defconfig )
else
  echo "[2/6] пропуск конфигурации (--no-config)"
fi

# --- 3. feeds ---
if [ "$DO_FEEDS" -eq 1 ]; then
  echo "[3/6] feeds update/install"
  ( cd "$TREE" && ./scripts/feeds update -a && ./scripts/feeds install -a )
else
  echo "[3/6] пропуск feeds (--no-feeds)"
fi

# --- 4. preflight на этом дереве (разделы 3-4) ---
echo "[4/6] preflight на дереве '$TREE'"
sh scripts/preflight.sh "$CARD" "$TREE" || {
  echo "!! preflight упал — сборку не запускаю" >&2
  exit 1
}

# --- 5. make ---
if [ "$DO_BUILD" -eq 1 ]; then
  echo "[5/6] make"
  if [ -n "$JOBS" ]; then
    ( cd "$TREE" && make -j"$JOBS" )
  else
    ( cd "$TREE" && make )
  fi
else
  echo "[5/6] пропуск сборки (--no-build)"
fi

# --- 6. итог ---
echo "[6/6] образы: $TREE/bin/targets/$TARGET/$SUBTARGET/"
ls -1 "$TREE/bin/targets/$TARGET/$SUBTARGET/" 2>/dev/null | sed 's/^/      /' || \
  echo "      (каталога ещё нет — сборка не дошла до образов)"
echo "=========================================================="
echo " build-one: DONE ($DEVICE)"
echo "=========================================================="
