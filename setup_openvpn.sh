#!/bin/bash

# Default values for command line arguments
PORT=1194
PROTOCOL=udp
DEV_TYPE=tun

# Process command line arguments
while getopts ":p:t:m:client:" opt; do
  case $opt in
    p) PORT=$OPTARG;;
    t) PROTOCOL=$OPTARG;;
    m) DEV_TYPE=$OPTARG;;
    client) CLIENTS=$OPTARG;;
    \?) echo "Invalid option -$OPTARG" >&2; exit 1;;
  esac
done

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Step 1: Install UFW and Setup Initial Rules
apt update && apt install ufw -y
ufw allow OpenSSH
ufw enable
ufw allow $PORT/$PROTOCOL

# Step 2: Install OpenVPN and Easy-RSA
apt install openvpn easy-rsa -y

# Step 3: Set up Easy-RSA
make-cadir ~/openvpn-ca
cd ~/openvpn-ca
./easyrsa init-pki
./easyrsa build-ca nopass

# Create server certificate
./easyrsa gen-req server nopass
./easyrsa sign-req server server

# Function to create client certificates
create_clients() {
    local existing_count=$(ls pki/issued | grep 'client_' | wc -l)
    local end=$(($existing_count + $1))
    for (( i=$existing_count+1; i<=$end; i++ )); do
        ./easyrsa gen-req client_$i nopass
        ./easyrsa sign-req client client_$i
    done
}

# Check if script is called with client argument
if [[ ! -z $CLIENTS ]]; then
    create_clients $CLIENTS
else
    echo -n "Enter number of initial clients to create: "
    read CLIENT_COUNT
    create_clients $CLIENT_COUNT
fi

# Step 4: Configure the OpenVPN Server
gunzip -c /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz > /etc/openvpn/server.conf
sed -i "s/port 1194/port $PORT/" /etc/openvpn/server.conf
sed -i "s/proto udp/proto $PROTOCOL/" /etc/openvpn/server.conf
sed -i "s/dev tun/dev $DEV_TYPE/" /etc/openvpn/server.conf
sed -i 's/;user nobody/user nobody/' /etc/openvpn/server.conf
sed -i 's/;group nogroup/group nogroup/' /etc/openvpn/server.conf

# Step 5: Adjust Server Networking Configuration
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p

# Start and Enable the OpenVPN Service
systemctl start openvpn@server
systemctl enable openvpn@server

echo "OpenVPN installation and configuration complete. You may now configure client machines."
