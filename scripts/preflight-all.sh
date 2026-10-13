#!/bin/sh
# preflight-all.sh — прогнать preflight.sh по ВСЕМ карточкам devices/*.yml
# и напечатать единый вердикт. Возвращает ненулевой код, если хоть одна упала.
#
#   sh scripts/preflight-all.sh                # строгий режим (по умолчанию)
#   sh scripts/preflight-all.sh --soft         # мягкий: чужой target = SKIP, не FAIL
#   sh scripts/preflight-all.sh --tree openwrt # передать дерево (разделы 3-4)

set -eu

SOFT=0
TREE="openwrt"
while [ $# -gt 0 ]; do
  case "$1" in
    --soft) SOFT=1 ;;
    --tree) shift; TREE="${1:-}" ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "неизвестный аргумент: $1" >&2; exit 2 ;;
  esac
  shift
done

[ -d scripts ] || { echo "!! нет каталога scripts/ — запускать из корня сборщика" >&2; exit 2; }
[ -d devices ] || { echo "!! нет каталога devices/" >&2; exit 2; }

CARDS=""
for f in devices/*.yml; do
  [ -e "$f" ] || continue
  CARDS="$CARDS $f"
done
[ -z "$CARDS" ] && { echo "!! в devices/ нет *.yml" >&2; exit 2; }

get_field() {
  sed -n "s/^${2}:[[:space:]]*//p" "$1" | head -n 1 \
    | sed 's/[[:space:]]*#.*//' | sed 's/[[:space:]]*$//' \
    | sed 's/^["'"'"']//; s/["'"'"']$//'
}

config_host_device() {
  cfg=".config"
  [ -n "$TREE" ] && [ -f "$TREE/.config" ] && cfg="$TREE/.config"
  [ -f "$cfg" ] || return 0
  grep -E '^CONFIG_TARGET_[A-Za-z0-9_]+_DEVICE_[A-Za-z0-9_-]+=y$' "$cfg" 2>/dev/null \
    | head -n 1 | sed 's/^CONFIG_TARGET_.*_DEVICE_//; s/=y$//' || true
}

HOST_DEVICE=$(config_host_device)
MODE=$([ "$SOFT" -eq 1 ] && echo "мягкий" || echo "строгий")

echo "=========================================================="
echo " preflight-all   режим: $MODE"
[ -n "$HOST_DEVICE" ] \
  && echo " .config собран под профиль: $HOST_DEVICE" \
  || echo " .config: не найден или не выбран конкретный профиль"
echo "=========================================================="

TOTAL=0 OKN=0 FAILN=0 SKIPN=0
SUMMARY=""

for card in $CARDS; do
  TOTAL=$((TOTAL + 1))
  cdev=$(get_field "$card" device)
  cprofile=$(get_field "$card" profile)

  if [ "$SOFT" -eq 1 ] && [ -n "$HOST_DEVICE" ] && [ -n "$cprofile" ] \
     && [ "$cprofile" != "$HOST_DEVICE" ]; then
    SKIPN=$((SKIPN + 1))
    SUMMARY="$SUMMARY
  SKIP  $cdev ($card) — .config под '$HOST_DEVICE', карточка '$cprofile'"
    echo
    echo ">> $card : SKIP (профиль '$cprofile' != .config '$HOST_DEVICE')"
    continue
  fi

  echo
  echo ">> $card"
  if [ -n "$TREE" ]; then
    set +e; out=$(sh scripts/preflight.sh "$card" "$TREE" 2>&1); rc=$?; set -e
  else
    set +e; out=$(sh scripts/preflight.sh "$card" 2>&1); rc=$?; set -e
  fi
  echo "$out" | sed 's/^/   /'

  if [ "$rc" -eq 0 ]; then
    OKN=$((OKN + 1)); SUMMARY="$SUMMARY
  OK    $cdev ($card)"
  else
    FAILN=$((FAILN + 1)); SUMMARY="$SUMMARY
  FAIL  $cdev ($card)"
  fi
done

echo
echo "=========================================================="
echo " СВОДКА"
echo "=========================================================="
echo "$SUMMARY"
echo "----------------------------------------------------------"
printf ' всего %d:  OK %d   FAIL %d' "$TOTAL" "$OKN" "$FAILN"
[ "$SKIPN" -gt 0 ] && printf '   SKIP %d' "$SKIPN"
printf '\n'
echo "=========================================================="

[ "$FAILN" -gt 0 ] && { echo "ИТОГ: FAIL — есть несобранные/несоответствующие профили"; exit 1; }
echo "ИТОГ: OK — все проверенные карточки прошли"
exit 0
