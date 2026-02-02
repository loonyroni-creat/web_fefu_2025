#!/bin/bash

set -e

PROJECT_DIR="/var/www/fefu_lab"
REPO="https://github.com/loonyroni-creat/web_fefu_2025.git"

echo "========== DEPLOY START =========="

echo "=== Installing system packages ==="
sudo apt update
sudo apt install -y python3-venv python3-pip git nginx postgresql postgresql-contrib curl

echo "=== Cloning project ==="
sudo rm -rf $PROJECT_DIR
sudo git clone $REPO $PROJECT_DIR
sudo chown -R $USER:$USER $PROJECT_DIR

cd $PROJECT_DIR

echo "=== Creating venv ==="
python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install -r requirements.txt

echo "=== Setup env ==="
cp .env.example .env

echo "=== Django migrate ==="
python manage.py migrate
python manage.py collectstatic --noinput

echo "=== Gunicorn logs ==="
sudo mkdir -p /var/log/gunicorn
sudo chown -R www-data:www-data /var/log/gunicorn

echo "=== Installing systemd service ==="
sudo cp deploy/systemd/gunicorn.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable gunicorn
sudo systemctl restart gunicorn

echo "=== Installing nginx config ==="
sudo cp deploy/nginx/fefu_lab.conf /etc/nginx/sites-available/
sudo ln -sf /etc/nginx/sites-available/fefu_lab.conf /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

sudo nginx -t
sudo systemctl restart nginx

echo "=== Checking app ==="
sleep 3
curl -I http://localhost || true

echo "========== DEPLOY DONE =========="
