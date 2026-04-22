#!/bin/bash
set -e

PASSWORD='Alaska@33'

# install required packages
DEPS=""
if ! command -v curl >/dev/null 2>&1; then
  DEPS="$DEPS curl"
fi
if ! command -v docker >/dev/null 2>&1; then
  DEPS="$DEPS docker.io"
fi
if ! command -v ufw >/dev/null 2>&1; then
  DEPS="$DEPS ufw"
fi

if [ -n "$DEPS" ]; then
  apt update -y
  apt install -y $DEPS
fi

# ensure docker is running
if command -v docker >/dev/null 2>&1; then
  systemctl enable docker >/dev/null 2>&1 || true
  systemctl start docker >/dev/null 2>&1 || true
fi

# auto-detect public IP if WG_HOST not provided
WG_HOST=${WG_HOST:-$(curl -fsSL ifconfig.me)}

# remove previous container if exists
docker rm -f wg-easy 2>/dev/null || true

HASH=$(docker run --rm ghcr.io/wg-easy/wg-easy wgpw "$PASSWORD" | cut -d"'" -f2)

docker run -d \
  --name=wg-easy \
  -e WG_HOST="$WG_HOST" \
  -e PASSWORD_HASH="$HASH" \
  -v ~/.wg-easy:/etc/wireguard \
  -p 51820:51820/udp \
  -p 51821:51821/tcp \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  --restart unless-stopped \
  ghcr.io/wg-easy/wg-easy

# open firewall ports
ufw allow 51820/udp || true
ufw allow 51821/tcp || true

echo -e "\nWireGuard UI: http://$WG_HOST:51821"
echo "user: admin"
echo "pass: $PASSWORD"
