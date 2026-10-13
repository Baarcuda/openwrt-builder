#!/bin/sh
# preflight.sh — проверка ОДНОЙ карточки devices/*.yml против .config и дерева OpenWrt.
# Зависимости: sh, sed, grep. Ничего больше.
#
# Использование:
#   sh scripts/preflight.sh [карточка] [дерево-OpenWrt]
# По умолчанию: devices/xiaomi-ax3600.yml  и  openwrt
#
# Примеры:
#   sh scripts/preflight.sh                                  # ax3600
#   sh scripts/preflight.sh devices/xiaomi-ax6s.yml          # ax6s
#   sh scripts/preflight.sh devices/xiaomi-ax6000.yml openwrt-mediatek-mt7622
#
# Раздел 2 проверяет .config так:
#   - если дерево $TREE_DIR/.config существует — проверяется оно (это то, что соберётся);
#   - иначе — корневой .config (режим "до появления дерева").

set -eu

CARD="${1:-devices/xiaomi-ax3600.yml}"
TREE_DIR="${2:-openwrt}"

FAIL=0
ok()   { printf '  ok    %s\n' "$*"; }
bad()  { printf '  FAIL  %s\n' "$*"; FAIL=1; }
note() { printf '        %s\n' "$*"; }

# --- одно поле: только по началу строки, отрезать комментарий и хвостовые пробелы
get_field() {
  sed -n "s/^${2}:[[:space:]]*//p" "$1" \
    | head -n 1 \
    | sed 's/[[:space:]]*#.*//' \
    | sed 's/[[:space:]]*$//' \
    | sed 's/^["'"'"']//; s/["'"'"']$//'
}

echo "== 0. Карточка =="
if [ -f "$CARD" ]; then ok "$CARD"; else bad "$CARD — нет файла"; echo; echo "PREFLIGHT: FAIL"; exit 1; fi

device=$(get_field "$CARD" device)
target=$(get_field "$CARD" target)
subtarget=$(get_field "$CARD" subtarget)
profile=$(get_field "$CARD" profile)
arch=$(get_field "$CARD" arch)
ref=$(get_field "$CARD" ref)

echo
echo "== 1. Поля заполнены =="
for pair in "device=$device" "target=$target" "subtarget=$subtarget" \
            "profile=$profile" "arch=$arch" "ref=$ref"; do
  k=${pair%%=*}; v=${pair#*=}
  if [ -n "$v" ]; then ok "$k = $v"; else bad "$k — пусто"; fi
done
[ "$FAIL" -eq 0 ] || { echo; echo "PREFLIGHT: FAIL"; exit 1; }

echo
echo "== 2. .config соответствует этой карточке =="
# Какой .config проверяем: если есть дерево и в нём есть .config — проверяем его
# (именно он пойдёт в make), иначе корневой (режим "без дерева").
if [ -f "$TREE_DIR/.config" ]; then
  CFG="$TREE_DIR/.config"
else
  CFG=".config"
fi
note "проверяемый файл: $CFG"

if [ ! -f "$CFG" ]; then
  bad "$CFG нет (запускать из корня сборщика; для дерева — после сборки конфига)"
else
  for want in \
    "CONFIG_TARGET_${target}=y" \
    "CONFIG_TARGET_${target}_${subtarget}=y" \
    "CONFIG_TARGET_${target}_${subtarget}_DEVICE_${profile}=y"
  do
    if grep -qxF "$want" "$CFG"; then ok "имеет $want"
    else bad "НЕ имеет $want"; fi
  done

  # arch карточки vs CONFIG_TARGET_ARCH_PACKAGES в проверяемом .config
  card_arch=$(get_field "$CARD" arch)
  cfg_arch=$(sed -n 's/^CONFIG_TARGET_ARCH_PACKAGES="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "$CFG" | head -n1)

  if [ -z "$cfg_arch" ]; then
    note "arch: CONFIG_TARGET_ARCH_PACKAGES в $CFG не найден — сверка пропущена"
  elif [ -z "$card_arch" ]; then
    note "arch: в карточке поле arch пустое — сверка пропущена"
  elif [ "$card_arch" = "$cfg_arch" ]; then
    ok "arch совпадает: $card_arch"
  else
    bad "arch НЕ совпадает: карточка '$card_arch', $CFG '$cfg_arch'"
  fi

  echo
  note "CONFIG_TARGET_..._DEVICE_... в $CFG, НЕ относящиеся к $device:"
  grep -E '^CONFIG_TARGET_[A-Za-z0-9_]+_DEVICE_[A-Za-z0-9_-]+=y' "$CFG" 2>/dev/null \
    | grep -vF "CONFIG_TARGET_${target}_${subtarget}_DEVICE_${profile}=y" \
    | sed 's/^/        ЛИШНЯЯ: /' || true
  note "(пусто — конфиг собран ровно под это устройство; непусто — в нём чужой профиль)"
fi

echo
echo "== 3. ref существует и сводится к коммиту =="
if [ -d "$TREE_DIR/.git" ]; then
  resolved=$(git -C "$TREE_DIR" rev-parse "${ref}^{commit}" 2>/dev/null || echo "MISSING")
  if [ "$resolved" = "MISSING" ]; then
    bad "ref='$ref' не разрешается в коммит в $TREE_DIR (нет тега/ветки/объекта)"
  else
    ok "ref '$ref' -> commit $resolved"
  fi
else
  note "дерева $TREE_DIR/.git нет — пропуск (нормально: дерево тянется на шаге сборки)"
  resolved=""
fi

echo
echo "== 4. дерево OpenWrt на этом коммите? =="
if [ -d "$TREE_DIR/.git" ] && [ -n "$resolved" ] && [ "$resolved" != "MISSING" ]; then
  head=$(git -C "$TREE_DIR" rev-parse HEAD 2>/dev/null || echo "?")
  if [ "$head" = "$resolved" ]; then ok "HEAD = $resolved"
  else bad "HEAD=$head, а карточка сводится к $resolved"; fi
else
  note "пропуск"
fi

echo
if [ "$FAIL" -eq 0 ]; then echo "PREFLIGHT: OK ($device)"; else echo "PREFLIGHT: FAIL ($device)"; fi
exit "$FAIL"
