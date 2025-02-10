#!/bin/bash

VER=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')

ARCH=$(uname -m)
TYPE=""

if [ "$ARCH" == "x86_64" ]; then
  TYPE="amd64"
elif [ "$ARCH" == "arm5l" ]; then
  TYPE="armv5"
elif [ "$ARCH" == "armv6l" ]; then
  TYPE="armv6"
elif [ "$ARCH" == "armv7l" ]; then
  TYPE="armv7"
elif [ "$ARCH" == "aarch64" ]; then
  TYPE="arm64"
fi

# Stop node_exporter service
systemctl stop node_exporter

# Wait for the service to stop
while [ "$(systemctl is-active node_exporter)" == "active" ]; do
  sleep 1
done

# Download the newest node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v${VER}/node_exporter-${VER}.linux-${TYPE}.tar.gz

# Copy the node_exporter
tar -zxvf node_exporter*.tar.gz && cp ./node_exporter-${VER}.linux-${TYPE}/node_exporter /usr/local/bin

# Remove old files and directories
rm node_exporter*.tar.gz node_exporter*/* && rmdir node_exporter-${VER}.linux-${TYPE}

# Create systemd service file
cat > /etc/systemd/system/node_exporter.service << "EOF"
[Unit]
Description=Node Exporter Service
Documentation=https://github.com/prometheus/node_exporter
 
[Service]
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:9100
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Reload units
systemctl daemon-reload

# Enable node_exporter service to start on boot
systemctl enable node_exporter

# Restart node_exporter service
systemctl start node_exporter
