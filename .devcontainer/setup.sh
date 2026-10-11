#!/usr/bin/env bash
# .devcontainer/setup.sh
# Ubuntu 24.04 (noble). Codespaces: sudo без пароля.
# Ставит gawk + gcc-14/g++-14 и делает gcc-14 системным gcc.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "== base =="
. /etc/os-release
echo "   $PRETTY_NAME"
if [ "${ID:-}" != "ubuntu" ]; then
  echo "!! Этот setup.sh написан под Ubuntu; обнаружен '${ID:-?}'. Прекращаю." >&2
  exit 1
fi

echo
echo "== apt update =="
sudo apt-get update -y

echo
echo "== пакеты сборки OpenWrt =="
sudo apt-get install -y --no-install-recommends \
  build-essential \
  gcc-14 g++-14 \
  gawk \
  clang \
  flex bison \
  gettext \
  git \
  libncurses-dev \
  libssl-dev \
  libelf-dev \
  python3 python3-setuptools python3-pip \
  unzip zip \
  zlib1g-dev \
  file \
  wget curl \
  rsync \
  subversion \
  patch bc time \
  ca-certificates locales

echo
echo "== локали (нужны для ряда шагов сборки) =="
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8 || true

echo
echo "== gcc/g++ -> 14 (update-alternatives, приоритет 114) =="
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 114
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-14 114
sudo update-alternatives --set gcc /usr/bin/gcc-14
sudo update-alternatives --set g++ /usr/bin/g++-14

echo
echo "== проверка версий =="
gcc --version | head -n1
g++ --version | head -n1
gawk --version | head -n1
clang --version | head -n1
python3 --version
git --version

echo
echo "== место на диске (сборка OpenWrt хочет ~20-30 ГБ) =="
df -h / | sed 's/^/   /'

echo
echo "setup.sh: готово."
