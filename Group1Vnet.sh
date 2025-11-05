#!/bin/bash

# ==========================================
# GROUP 1 CAPSTONE PROJECT
# ==========================================

# Variables
RG="Group1CapstoneRG"
LOC="uksouth"
VNET="Group1VNet"
WEB_SUBNET="WebSubnet"
APP_SUBNET="AppSubnet"
DB_SUBNET="DBSubnet"
WEB_NSG="Web_nsg"
APP_NSG="App_nsg"
DB_NSG="DB_nsg"

WEB_VM="WEB_VM"
APP_VM="APP_VM"
DB_VM="DB_VM"
ADMIN_USER="your_username"
ADMIN_PASS="Gloriaayool@99" #password should contain at least a symbol, a capital letter and not less than 12 characters
VM_SIZE="Standard_B1s"

#  Create Resource Group
echo "Creating Resource Group in $LOC..."
az group create --name $RG --location $LOC

#  Create Virtual Network and Subnets
echo "Creating VNet and Subnets..."
az network vnet create -g $RG -n $VNET --address-prefix 10.0.0.0/16 --subnet-name $WEB_SUBNET --subnet-prefix 10.0.1.0/24
az network vnet subnet create -g $RG --vnet-name $VNET -n $APP_SUBNET --address-prefix 10.0.2.0/24
az network vnet subnet create -g $RG --vnet-name $VNET -n $DB_SUBNET --address-prefix 10.0.3.0/24
#  Create Network Security Groups
echo "Creating NSGs..."
az network nsg create -g $RG -n $WEB_NSG --location $LOC
az network nsg create -g $RG -n $APP_NSG --location $LOC
az network nsg create -g $RG -n $DB_NSG --location $LOC

#  Configure NSG Rules
echo "Configuring NSG Rules..."

# --- Web Tier Rules ---
az network nsg rule create -g $RG --nsg-name $WEB_NSG -n AllowWebHTTP --priority 100 --protocol Tcp --destination-port-ranges 80 --access Allow --direction Inbound

az network nsg rule create -g $RG --nsg-name $WEB_NSG -n AllowWebSSH --priority 110 --protocol Tcp --destination-port-ranges 22 --access Allow --direction Inbound

# --- App Tier Rules ---
az network nsg rule create -g $RG --nsg-name $APP_NSG -n AllowWebToApp --priority 100 --protocol Tcp --source-address-prefixes 10.0.1.0/24 --destination-port-ranges 80 --access Allow --direction Inbound

# Allow SSH from Web subnet (optional)
az network nsg rule create -g $RG --nsg-name $APP_NSG -n AllowSSHFromWeb --priority 120 --protocol Tcp --source-address-prefixes 10.0.1.0/24 --destination-port-ranges 22 --access Allow --direction Inbound

# --- DB Tier Rules ---
az network nsg rule create -g $RG --nsg-name $DB_NSG -n AllowAppToDB --priority 100 --protocol Tcp --source-address-prefixes 10.0.2.0/24 --destination-port-ranges 3306 --access Allow --direction Inbound

# Allow SSH from App subnet (optional)
az network nsg rule create -g $RG --nsg-name $DB_NSG -n AllowSSHFromApp --priority 120 --protocol Tcp --source-address-prefixes 10.0.2.0/24 --destination-port-ranges 22 --access Allow --direction Inbound
#  Create NICs and Attach NSGs
echo "Creating NICs..."
az network nic create -g $RG -n WebNIC --vnet-name $VNET --subnet $WEB_SUBNET --network-security-group $WEB_NSG
az network nic create -g $RG -n AppNIC --vnet-name $VNET --subnet $APP_SUBNET --network-security-group $APP_NSG
az network nic create -g $RG -n DbNIC --vnet-name $VNET --subnet $DB_SUBNET --network-security-group $DB_NSG

#  Create Public IP for Web VM
echo "Creating Public IP for Web_VM..."
az network public-ip create -g $RG -n Web_VMPublicIP --sku Standard --allocation-method Static

#  Update Web NIC with Public IP
echo "Attaching Public IP to WebNIC..."
az network nic ip-config update -g $RG --nic-name WebNIC --name ipconfig1 --public-ip-address WebVMPublicIP

#  Deploy Linux VMs
echo "Deploying Linux VMs in $LOC..."
az vm create -g $RG -n $WEB_VM --nics WebNIC --image Ubuntu2204 --size $VM_SIZE --admin-username $ADMIN_USER --admin-password $ADMIN_PASS --public-ip-sku Standard --location $LOC

az vm create -g $RG -n $APP_VM --nics AppNIC --image Ubuntu2204 --size $VM_SIZE --admin-username $ADMIN_USER --admin-password $ADMIN_PASS --location $LOC

az vm create -g $RG -n $DB_VM --nics DbNIC --image Ubuntu2204 --size $VM_SIZE --admin-username $ADMIN_USER --admin-password $ADMIN_PASS --location $LOC

#  Output Public and Private IPs
echo "Deployment Complete! Fetching IP Addresses..."
az vm list-ip-addresses -g $RG -o table

#  Final Instructions
echo ""
echo "Deployment successful!"
echo "Use SSH to connect and verify connectivity:"
echo "   ssh $ADMIN_USER@<Web_VM_Public_IP>"
echo "Then test private connections from inside WebVM:"
echo "   ping 10.0.2.4   # App_VM"
echo "   ping 10.0.3.4 # DB_VM"