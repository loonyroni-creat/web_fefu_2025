#!/bin/bash

echo "=== FEFU Lab Deploy ==="

# ======================
# Postgres
# ======================
echo "Postgres..."
sudo -u postgres psql -c "CREATE USER fefu_user WITH PASSWORD 'strongpassword';" 2>/dev/null || true
sudo -u postgres psql -c "ALTER USER fefu_user CREATEDB;" 2>/dev/null || true
sudo -u postgres createdb -O fefu_user fefu_lab_db 2>/dev/null || true


# ======================
# Dirs
# ======================
echo "Dirs..."
sudo mkdir -p /run/gunicorn
sudo mkdir -p /var/www/fefu_lab/staticfiles
sudo mkdir -p /var/www/fefu_lab/media

sudo chown -R www-data:www-data /run/gunicorn /var/www/fefu_lab
sudo chmod -R 755 /var/www/fefu_lab


# ======================
# Django
# ======================
echo "Migrations..."
source venv/bin/activate
python manage.py migrate
python manage.py collectstatic --noinput


# ======================
# Configs
# ======================
echo "Configs..."
sudo cp deploy/nginx/fefu_lab.conf /etc/nginx/sites-available/
sudo ln -sf /etc/nginx/sites-available/fefu_lab.conf /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

sudo cp deploy/systemd/gunicorn.service /etc/systemd/system/


# ======================
# Restart
# ======================
echo "Restart..."
sudo systemctl daemon-reload
sudo systemctl enable gunicorn
sudo systemctl restart gunicorn
sudo systemctl restart nginx


# ======================
# Status
# ======================
echo ""
systemctl status gunicorn --no-pager | head -5
systemctl status nginx --no-pager | head -5

echo ""
echo " DONE → http://192.168.224.
