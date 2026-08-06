#!/usr/bin/env bash
set -e

INSTALL_DIR="${INSTALL_DIR:-/opt/openconnect-head}"

echo "Setting up openconnect-head in $INSTALL_DIR..."
sudo mkdir -p "$INSTALL_DIR"
sudo chown "$(id -u):$(id -g)" "$INSTALL_DIR"
cd "$INSTALL_DIR"


# .env
if [ ! -f .env ]; then
cat > .env <<'EOF'
OPENCONNECT_HOST=vpn.yourcompany.com
OPENCONNECT_USER=yourname
OPENCONNECT_PASSWORD=yourpassword
OPENCONNECT_TOTP=YOURTOTPBASE32SECRET

# Optional: route to your local LAN through this container
LOCAL_NETWORK=10.0.0.0/24
LOCAL_GATEWAY=172.17.0.1
EOF
echo "Created .env"
else
echo ".env already exists, skipping"
fi

chmod 600 .env

# Dockerfile
cat > Dockerfile <<'EOF'
FROM bibica/microsocks:latest AS microsocks

FROM mawenqiandev/openconnect-head:latest

COPY --from=microsocks /microsocks /usr/local/bin/microsocks

RUN mkdir -p /etc/vpnc/post-connect.d/ && \
    printf '#!/bin/sh\nip route add "${LOCAL_NETWORK:-10.0.0.0/24}" via "${LOCAL_GATEWAY:-172.17.0.1}"\n' \
        > /etc/vpnc/post-connect.d/add-routes.sh && \
    chmod +x /etc/vpnc/post-connect.d/add-routes.sh
EOF

# docker-compose.yaml
cat > docker-compose.yaml <<'EOF'
services:
  openconnect:
    build: .
    container_name: openconnect
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    ports:
      - "1080:1080"
    env_file:
      - .env
    command: >
      sh -c '
      microsocks -i 0.0.0.0 -p 1080 &
      while true; do
      echo "$$OPENCONNECT_PASSWORD" | openconnect --protocol=anyconnect
      "https://$$OPENCONNECT_HOST/"
      -u "$$OPENCONNECT_USER"
      --passwd-on-stdin --force-dpd=30
      --token-mode=totp
      --token-secret=base32:$$OPENCONNECT_TOTP
      --useragent="AnyConnect" -l --timestamp;
      echo "OpenConnect connection expired. Restarting ...";
      sleep 2;
      done'
      healthcheck:
      test: ["CMD-SHELL", "curl -sf --max-time 3 https://1.1.1.1 -o /dev/null || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 40s
EOF

echo ""
echo "Done. Now edit $INSTALL_DIR/.env with your VPN details, then run:"
echo "  cd $INSTALL_DIR && docker compose up -d --build"
echo ""
echo "If you want your LAN to reach this proxy, edit LOCAL_NETWORK / LOCAL_GATEWAY in .env."
echo "If only this machine will use it, you can ignore those two."
echo ""
echo "More info: https://github.com/ma-wenqian/dockerfiles/tree/main/openconnect"