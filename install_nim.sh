#!/bin/bash

# ECAusente
# V1: Bash script to install NGINX Plus, ClickHouse, and NGINX Management Suite on CentOS
# V2: With improved error handling and skip logic

# Exit immediately if a command exits with a non-zero status.
set -e

# Define a function to install wget if it's not already installed
ensure_wget() {
    if ! command -v wget &> /dev/null; then
        echo "Installing wget..."
        sudo yum install -y wget
    fi
}

# Define a function to check if a service is active
check_service_active() {
    systemctl is-active --quiet "$1"
}

# Step 1: Setup and copying the certificates
if [ ! -d /etc/ssl/nginx ]; then
    echo "Creating /etc/ssl/nginx directory..."
    sudo mkdir -p /etc/ssl/nginx
fi

echo "Please provide the path to your nginx-repo.crt file:"
read crt_path
echo "Please provide the path to your nginx-repo.key file:"
read key_path

sudo cp "$crt_path" /etc/ssl/nginx/nginx-repo.crt
sudo cp "$key_path" /etc/ssl/nginx/nginx-repo.key

# Step 2: Install NGINX Plus
echo "Checking for ca-certificates..."
sudo yum install -y ca-certificates

ensure_wget
echo "Adding NGINX Plus repository..."
if ! grep -q "nginx-plus" /etc/yum.repos.d/nginx-plus.repo; then
    sudo wget -P /etc/yum.repos.d https://cs.nginx.com/static/files/nginx-plus-7.4.repo
fi

if ! rpm -q nginx-plus &> /dev/null; then
    sudo yum install -y nginx-plus
fi

if ! check_service_active nginx.service; then
    echo "Enabling and starting NGINX..."
    sudo systemctl enable nginx.service
    sudo systemctl start nginx
fi

nginx -v

# Step 3: Install ClickHouse
ensure_wget
echo "Installing ClickHouse..."
sudo yum install -y yum-utils
if ! grep -q "clickhouse" /etc/yum.repos.d/clickhouse.repo; then
    sudo yum-config-manager --add-repo https://packages.clickhouse.com/rpm/clickhouse.repo
fi
sudo yum install -y clickhouse-server clickhouse-client

if ! check_service_active clickhouse-server; then
    echo "Enabling and starting ClickHouse server..."
    sudo systemctl enable clickhouse-server
    sudo systemctl start clickhouse-server
fi

sudo systemctl status clickhouse-server

# Step 4: Install NGINX Management Suite
echo "Adding NGINX Management Suite repository and installing..."
ensure_wget
if ! grep -q "nms" /etc/yum.repos.d/nms.repo; then
    sudo wget -P /etc/yum.repos.d https://cs.nginx.com/static/files/nms.repo
fi

if ! rpm -q nms-instance-manager &> /dev/null; then
    sudo yum install -y nms-instance-manager
fi

echo "Enabling NGINX Management Suite services..."
sudo systemctl enable nms nms-core nms-dpm nms-ingestion nms-integrations --now

if systemctl is-enabled nginx; then
    echo "Restarting NGINX..."
    sudo systemctl restart nginx
else
    echo "NGINX is not installed or not enabled."
fi

echo "Installation complete! Review the log for more details."
