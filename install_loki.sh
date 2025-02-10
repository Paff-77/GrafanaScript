# Get the latest version number of Loki
VER=$(wget -qO- https://api.github.com/repos/grafana/loki/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')

# Determine the system architecture
ARCH=$(uname -m)
TYPE=""

# Match the architecture to the corresponding Loki and Promtail binary files
if [ "$ARCH" == "x86_64" ]; then
  TYPE="amd64"
elif [ "$ARCH" == "armv7l" ]; then
  TYPE="arm"
elif [ "$ARCH" == "aarch64" ]; then
  TYPE="arm64"
fi

# Exit the script if the architecture is not supported
if [ -z "$TYPE" ]; then
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

# Stop Loki and Promtail service
systemctl stop loki
systemctl stop promtail

# Create system users for Loki and Promtail
useradd -rs /bin/false loki
useradd -rs /bin/false promtail

# Download the Loki and Promtail binary files to the /tmp directory
wget https://github.com/grafana/loki/releases/download/v$VER/loki-linux-$TYPE.zip -O /tmp/loki.zip
wget https://github.com/grafana/loki/releases/download/v$VER/promtail-linux-$TYPE.zip -O /tmp/promtail.zip

# Unzip Loki and Promtail to /usr/local/bin/
unzip /tmp/loki.zip -d /usr/local/bin/
unzip /tmp/promtail.zip -d /usr/local/bin/
mv /usr/local/bin/loki-linux-$TYPE /usr/local/bin/loki
mv /usr/local/bin/promtail-linux-$TYPE /usr/local/bin/promtail

# Remove the downloaded zip files
rm /tmp/loki.zip
rm /tmp/promtail.zip

# Grant execution permissions
chmod +x /usr/local/bin/loki
chmod +x /usr/local/bin/promtail

# Download the configuration files
wget https://raw.githubusercontent.com/grafana/loki/main/cmd/loki/loki-local-config.yaml -O /etc/loki/loki.yaml
wget https://raw.githubusercontent.com/grafana/loki/main/clients/cmd/promtail/promtail-local-config.yaml -O /etc/promtail/promtail.yaml

# Create directories for configuration files
mkdir -p /etc/loki
mkdir -p /etc/promtail

# Set up the Loki service
cat > /etc/systemd/system/loki.service << EOF
[Unit]
Description=Loki Service
Documentation=https://github.com/grafana/loki
After=network.target

[Service]
User=loki
Type=simple
Restart=on-failure
ExecStart=/usr/local/bin/loki -config.file=/etc/loki/loki.yaml

[Install]
WantedBy=multi-user.target
EOF

# Set up the Promtail service
cat > /etc/systemd/system/promtail.service << EOF
[Unit]
Description=Promtail Service
Documentation=https://github.com/grafana/loki
After=network.target

[Service]
User=promtail
Type=simple
Restart=on-failure
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/promtail.yaml

[Install]
WantedBy=multi-user.target
EOF

# since it uses Promtail to read system log files, 
# the promtail user won't yet have permissions to read them.
usermod -a -G adm promtail

# Start and enable the services
systemctl daemon-reload

systemctl enable loki
systemctl start loki

systemctl enable promtail
systemctl start promtail
