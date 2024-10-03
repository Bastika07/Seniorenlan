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
      dockerfile: dockerfiles/Dockerfile.mh
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

# Define constants
SSH_PORT=22
LOCAL_SUBNET="10.13.37.0/24"

block_internet() {
    echo "Blocking all internet traffic except SSH and internal subnet ($LOCAL_SUBNET)..."
    iptables -F
    iptables -X
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A INPUT -p tcp --dport $SSH_PORT -j ACCEPT
    iptables -A OUTPUT -p tcp --sport $SSH_PORT -j ACCEPT
    iptables -A INPUT -s $LOCAL_SUBNET -j ACCEPT
    iptables -A OUTPUT -d $LOCAL_SUBNET -j ACCEPT
    iptables -P INPUT DROP
    iptables -P OUTPUT DROP
    iptables -P FORWARD DROP
    echo "All internet traffic blocked, but SSH and internal subnet traffic are allowed."
}

enable_internet() {
    echo "Enabling all internet traffic..."
    iptables -F
    iptables -X
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT
    echo "All internet traffic is now enabled."
}

if [ "$1" == "block" ]; then
    block_internet
elif [ "$1" == "enable" ]; then
    enable_internet
else
    echo "Usage: $0 {block|enable}"
    exit 1
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

