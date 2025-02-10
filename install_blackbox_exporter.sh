#!/bin/bash

# Get the latest version number of blackbox_exporter
VER=$(wget -qO- https://api.github.com/repos/prometheus/blackbox_exporter/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')

# Determine the system architecture
ARCH=$(uname -m)
TYPE=""

# Match the architecture to the corresponding blackbox_exporter binary
if [ "$ARCH" == "x86_64" ]; then
  TYPE="amd64"
elif [ "$ARCH" == "armv5l" ]; then
  TYPE="armv5"
elif [ "$ARCH" == "armv6l" ]; then
  TYPE="armv6"
elif [ "$ARCH" == "armv7l" ]; then
  TYPE="armv7"
elif [ "$ARCH" == "aarch64" ]; then
  TYPE="arm64"
fi

# Stop blackbox_exporter service
systemctl stop blackbox_exporter

# Download the blackbox_exporter binary for the detected architecture
wget -P /tmp https://github.com/prometheus/blackbox_exporter/releases/download/v${VER}/blackbox_exporter-${VER}.linux-${TYPE}.tar.gz

# Unpack the downloaded binary
tar -zxvf /tmp/blackbox_exporter-${VER}.linux-${TYPE}.tar.gz -C /tmp

# Create configuration and data directories for blackbox_exporter
mkdir /etc/blackbox_exporter

# Check if the blackbox.yml configuration file already exists
if [ ! -f /etc/blackbox_exporter/blackbox.yml ]; then
    # Copy the new blackbox_exporter configuration file to the /etc/blackbox_exporter directory
    cp /tmp/blackbox_exporter-${VER}.linux-${TYPE}/blackbox.yml /etc/blackbox_exporter/blackbox.yml
else
    echo "The configuration file /etc/blackbox_exporter/blackbox.yml already exists and will not be overwritten."
fi

# Copy the binaries to their respective locations
cp /tmp/blackbox_exporter-${VER}.linux-${TYPE}/blackbox_exporter /usr/local/bin/

# Remove old files and directories
rm /tmp/blackbox_exporter-${VER}.linux-${TYPE}.tar.gz && rm -rf /tmp/blackbox_exporter-${VER}.linux-${TYPE}

# Create a systemd service file for blackbox_exporter
cat > /etc/systemd/system/blackbox_exporter.service << EOF
[Unit]
Description=Blackbox Exporter Service
Documentation=https://github.com/prometheus/blackbox_exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
Restart=on-failure
ExecStart=/usr/local/bin/blackbox_exporter \\
    --config.file=/etc/blackbox_exporter/blackbox.yml \\
    --web.listen-address=:9115

[Install]
WantedBy=multi-user.target
EOF

# Reload the systemd manager configuration
systemctl daemon-reload

# Enable the blackbox_exporter service to start on boot
systemctl enable blackbox_exporter

# Start the blackbox_exporter service
systemctl start blackbox_exporter
systemctl status blackbox_exporter
