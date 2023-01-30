#!/bin/sh

# Stop on failures
set -e

# Update package lists
echo "Updating package list"
sudo apt-get update

# Note that already installed packages will be ignored
echo "Installing packages"
sudo apt-get install -y docker.io docker-compose curl jq openssl

# Configured user groups includes docker?
if id -Gn "$USER" | grep -q '\bdocker\b'; then
    echo "Current user '$USER' already part of 'docker' group"
else
    echo "Adding current user '$USER' to the 'docker' group"
    sudo gpasswd -a "$USER" docker
fi

# Installation of HLF Binaries
if [ -f "bin/fabric-ca-server" ] && [ -f "config/configtx.yaml" ]; then
    echo "HLF binaries already installed"
else
    echo "Installing HLF binaries"
    curl https://raw.githubusercontent.com/hyperledger/fabric/master/scripts/bootstrap.sh \
        | bash -s -- 2.2.0 1.4.8 -d -s
fi

# Currently logged in user session includes docker group?
if id -Gn | grep -q '\bdocker\b'; then
    echo "Prerequisites installed!"
else
    cat <<EOF

*
* Logout and in again to complete the installation of docker before proceeding.
*
EOF
fi
