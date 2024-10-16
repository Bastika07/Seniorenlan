#!/bin/bash

# Clone the repositories
git clone https://github.com/GameServerManagers/docker-gameserver.git
git clone https://github.com/Poeschl/docker-eti-sync-server.git

# Create the required directories and subdirectories
mkdir -p docker-gameserver/mordhau/serverfiles
mkdir -p docker-gameserver/cs2/serverfiles

# Create the Docker Compose file for Mordhau
cat <<EOL > docker-gameserver/mordhau/docker-compose.yml
version: "3.8"
services:
  linuxgsm:
    build:
      context: /root/docker-gameserver
      dockerfile: dockerfiles/Dockerfile.mh
    container_name: mhserver
    restart: unless-stopped
    network_mode: host
    volumes:
      - /root/docker-gameserver/mordhau/serverfiles:/data
EOL

# Create the Docker Compose file for CS2
cat <<EOL > docker-gameserver/cs2/docker-compose.yml
version: "3.8"
services:
  linuxgsm:
    build:
      context: /root/docker-gameserver
      dockerfile: dockerfiles/Dockerfile.cs2
    container_name: cs2server
    restart: unless-stopped
    network_mode: host
    volumes:
      - /root/docker-gameserver/mordhau/serverfiles:/data
EOL

# Set permissions for Mordhau and CS2 directories
chmod -R 777 docker-gameserver/mordhau
chmod -R 777 docker-gameserver/cs2

# Create or update the Docker Compose file for docker-eti-sync-server
cat <<EOL > docker-eti-sync-server/docker-compose.yml
version: "3"

services:
  eti-sync-server:
    build:
      context: .  # Use the current directory where the Dockerfile is located
      dockerfile: Dockerfile  # Use the custom Dockerfile for the build
    network_mode: host
    privileged: true
    volumes:
      - ./lan:/lan:rw
EOL

# Create iptables_control.sh script
cat <<'EOL' > iptables_control.sh
#!/bin/bash

# Variables for interfaces and networks
ZEROTIER_INTERFACE="ztcfwzikth"           # Your specific ZeroTier interface
ZEROTIER_PORT="9993"                       # ZeroTier's default UDP port for management
INTERNAL_SUBNET="10.13.37.0/24"            # Replace with your internal network range
BROADCAST_ADDRESS="192.168.1.255"          # Local broadcast address
MULTICAST_ADDRESS="239.192.0.0"            # Multicast IP address for UDP traffic
MULTICAST_PORT="3838"                      # Multicast port to allow

# Function to block internet traffic but allow ZeroTier, SSH, internal network, multicast, and broadcast
block_internet() {
    echo "Blocking internet traffic but allowing ZeroTier, SSH, internal network ($INTERNAL_SUBNET), multicast, and broadcast..."

    # Reset all iptables rules to avoid conflicts
    iptables -F
    iptables -t nat -F
    iptables -t mangle -F
    iptables -X

    # Default drop policy for INPUT, OUTPUT, and FORWARD chains
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT DROP

    # Allow loopback traffic
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT

    # Allow SSH (port 22) traffic
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    iptables -A OUTPUT -p tcp --sport 22 -j ACCEPT

    # Allow all traffic on the ZeroTier interface
    iptables -A INPUT -i "$ZEROTIER_INTERFACE" -j ACCEPT
    iptables -A OUTPUT -o "$ZEROTIER_INTERFACE" -j ACCEPT

    # Allow ZeroTier communication ports (UDP 9993 by default)
    iptables -A INPUT -p udp -m udp --sport "$ZEROTIER_PORT" -j ACCEPT
    iptables -A OUTPUT -p udp -m udp --dport "$ZEROTIER_PORT" -j ACCEPT

    # Allow DNS queries (UDP port 53)
    iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
    iptables -A INPUT -p udp --sport 53 -j ACCEPT

    # Allow HTTPS traffic for ZeroTier communication (if needed)
    iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
    iptables -A INPUT -p tcp --sport 443 -j ACCEPT

    # Allow all traffic within the internal subnet
    iptables -A INPUT -s "$INTERNAL_SUBNET" -j ACCEPT
    iptables -A OUTPUT -d "$INTERNAL_SUBNET" -j ACCEPT

    # Allow Multicast UDP traffic to the specified address and port
    iptables -A INPUT -d "$MULTICAST_ADDRESS" -p udp --dport "$MULTICAST_PORT" -j ACCEPT
    iptables -A OUTPUT -d "$MULTICAST_ADDRESS" -p udp --sport "$MULTICAST_PORT" -j ACCEPT

    # Allow Broadcast traffic to the specified address
    iptables -A INPUT -d "$BROADCAST_ADDRESS" -j ACCEPT
    iptables -A OUTPUT -d "$BROADCAST_ADDRESS" -j ACCEPT

    echo "Internet traffic blocked. ZeroTier, SSH, internal network, multicast, and broadcast traffic are allowed."
}

# Function to enable all internet traffic while keeping SSH, internal network, multicast, and broadcast access
enable_internet() {
    echo "Enabling all internet traffic..."

    # Flush all rules
    iptables -F
    iptables -t nat -F
    iptables -t mangle -F
    iptables -X

    # Set default policies to ACCEPT
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT

    echo "All internet traffic enabled. SSH, internal network, multicast, and broadcast access retained."
}

# Check for command-line argument and run the corresponding function
if [ "$1" == "block" ]; then
    block_internet
elif [ "$1" == "enable" ]; then
    enable_internet
else
    echo "Usage: $0 {block|enable}"
fi
EOL

# Make the iptables script executable
chmod +x iptables_control.sh

# Create an alias for Gameserver
echo "alias cs2_details='docker exec -it --user linuxgsm cs2server ./cs2server details'" >> ~/.bashrc
echo "alias cs2_stop='docker exec -it --user linuxgsm cs2server ./cs2server stop'" >> ~/.bashrc
echo "alias cs2_start='docker exec -it --user linuxgsm cs2server ./cs2server start'" >> ~/.bashrc
echo "alias cs2_restart='docker exec -it --user linuxgsm cs2server ./cs2server restart'" >> ~/.bashrc
echo "alias mh_details='docker exec -it --user linuxgsm mhserver ./mhserver details'" >> ~/.bashrc
echo "alias mh_stop='docker exec -it --user linuxgsm mhserver ./mhserver stop'" >> ~/.bashrc
echo "alias mh_start='docker exec -it --user linuxgsm mhserver ./mhserver start'" >> ~/.bashrc
echo "alias mh_restart='docker exec -it --user linuxgsm mhserver ./mhserver restart'" >> ~/.bashrc

# Load the new aliases
source ~/.bashrc

echo "Setup complete. Aliases added, and setup finished. Now navigate to the 'docker-eti-sync-server' folder and run 'docker-compose up --build'."

