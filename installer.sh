#!/bin/bash

# Clone the repositories
git clone https://github.com/GameServerManagers/docker-gameserver.git

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


