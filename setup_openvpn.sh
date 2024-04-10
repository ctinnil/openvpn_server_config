#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Step 1: Update System Packages
apt update && apt upgrade -y

# Step 2: Install OpenVPN and Easy-RSA
apt install openvpn easy-rsa -y

# Step 3: Set up Easy-RSA
make-cadir ~/openvpn-ca
cd ~/openvpn-ca
./easyrsa init-pki
./easyrsa build-ca nopass

# Step 4: Create Server and Client Certificates
./easyrsa gen-req server nopass
./easyrsa sign-req server server

# Client setup
# Change 'client' to your client's name
./easyrsa gen-req client nopass
./easyrsa sign-req client client

# Step 5: Configure the OpenVPN Server
gunzip -c /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz > /etc/openvpn/server/server.conf
sed -i 's/;tls-auth ta.key 0/tls-auth ta.key 0/' /etc/openvpn/server/server.conf
sed -i 's/;cipher AES-256-CBC/cipher AES-256-CBC/' /etc/openvpn/server/server.conf
sed -i 's/;user nobody/user nobody/' /etc/openvpn/server/server.conf
sed -i 's/;group nogroup/group nogroup/' /etc/openvpn/server/server.conf

# Step 6: Adjust Server Networking Configuration
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p

# Set up firewall
ufw allow 1194/udp
ufw allow OpenSSH
ufw disable
ufw enable

# Step 7: Start and Enable the OpenVPN Service
systemctl start openvpn@server
systemctl enable openvpn@server

echo "OpenVPN installation and configuration complete. You may now configure client machines."
