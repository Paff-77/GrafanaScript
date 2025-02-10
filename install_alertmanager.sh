#!/bin/bash

# Get the latest version number of alertmanager
VER=$(wget -qO- https://api.github.com/repos/prometheus/alertmanager/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')

# Determine the system architecture
ARCH=$(uname -m)
TYPE=""

# Match the architecture to the corresponding alertmanager binary
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

# Stop alertmanager service
systemctl stop alertmanager

# Download the alertmanager binary for the detected architecture
wget -P /tmp https://github.com/prometheus/alertmanager/releases/download/v${VER}/alertmanager-${VER}.linux-${TYPE}.tar.gz

# Unpack the downloaded binary
tar -zxvf /tmp/alertmanager-${VER}.linux-${TYPE}.tar.gz -C /tmp

# Create a user for alertmanager without a home directory and with /bin/false as shell
useradd -rs /bin/false alertmanager

# Create configuration and data directories for alertmanager
mkdir -p /etc/alertmanager/templates
mkdir /etc/alertmanager
mkdir /var/lib/alertmanager

# Set ownership of the directories to the alertmanager user
chown alertmanager:alertmanager /etc/alertmanager
chown alertmanager:alertmanager /var/lib/alertmanager
chown -R alertmanager:alertmanager /etc/alertmanager/templates

# Check if the alertmanager.yml configuration file already exists
if [ ! -f /etc/alertmanager/alertmanager.yml ]; then
    # Copy the new alertmanager configuration file to the /etc/alertmanager directory
    cp /tmp/alertmanager-${VER}.linux-${TYPE}/alertmanager.yml /etc/alertmanager/alertmanager.yml
else
    echo "The configuration file /etc/alertmanager/alertmanager.yml already exists and will not be overwritten."
fi

# Copy the binaries to their respective locations
cp /tmp/alertmanager-${VER}.linux-${TYPE}/alertmanager /usr/local/bin/
cp /tmp/alertmanager-${VER}.linux-${TYPE}/amtool /usr/local/bin/

# Remove old files and directories
rm /tmp/alertmanager-${VER}.linux-${TYPE}.tar.gz && rm -rf /tmp/alertmanager-${VER}.linux-${TYPE}

# Set ownership of the binaries to the alertmanager user
chown alertmanager:alertmanager /usr/local/bin/alertmanager
chown alertmanager:alertmanager /usr/local/bin/amtool
chown alertmanager:alertmanager /etc/alertmanager/alertmanager.yml

# Create a systemd service file for alertmanager
cat > /etc/systemd/system/alertmanager.service << EOF
[Unit]
Description=AlertManager Service
Documentation=https://github.com/prometheus/alertmanager
Wants=network-online.target
After=network-online.target

[Service]
User=alertmanager
Group=alertmanager
Type=simple
Restart=on-failure
ExecStart=/usr/local/bin/alertmanager \\
    --config.file=/etc/alertmanager/alertmanager.yml \\
    --storage.path=/var/lib/alertmanager/ \\
    --web.external-url=https://************************************/alertmanager/ \\
    --web.listen-address=localhost:9093 \\
    --web.route-prefix=/

[Install]
WantedBy=multi-user.target
EOF

# Reload the systemd manager configuration
systemctl daemon-reload

# Enable the alertmanager service to start on boot
systemctl enable alertmanager

# Start the alertmanager service
systemctl start alertmanager
