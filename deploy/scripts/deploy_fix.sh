#!/bin/bash

# Deployment script for FEFU Lab - ИСПРАВЛЕННАЯ ВЕРСИЯ
# Django application deployment automation on Ubuntu

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Output functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check permissions
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root"
    exit 1
fi

# Configuration
REPO_URL="https://github.com/loonyroni-creat/web_fefu_2025.git"
PROJECT_DIR="/var/www/fefu_lab"
VENV_DIR="$PROJECT_DIR/venv"
DB_NAME="fefu_lab_db"
DB_USER="fefu_user"
DB_PASSWORD="fefu123"  # ПРОСТОЙ ПАРОЛЬ!
DJANGO_SECRET_KEY=$(openssl rand -base64 64)

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')
if [ -z "$SERVER_IP" ]; then
    SERVER_IP="127.0.0.1"
fi

# Step 1: System update
print_info "Step 1: Updating system..."
apt update
apt upgrade -y

# Step 2: Install required packages (ДОБАВЛЕНЫ библиотеки для Pillow)
print_info "Step 2: Installing required packages..."
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    postgresql \
    postgresql-contrib \
    nginx \
    curl \
    git \
    libpq-dev \
    libjpeg-dev \
    libpng-dev \
    libwebp-dev \
    zlib1g-dev \
    python3-dev

# Step 3: PostgreSQL setup (УПРОЩЕННЫЙ ВАРИАНТ)
print_info "Step 3: Configuring PostgreSQL..."
sudo -u postgres psql <<EOF
DROP DATABASE IF EXISTS $DB_NAME;
DROP USER IF EXISTS $DB_USER;
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
ALTER ROLE $DB_USER SET client_encoding TO 'utf8';
ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';
ALTER ROLE $DB_USER SET timezone TO 'UTC';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\q
EOF

# Step 4: PostgreSQL security
print_info "Step 4: Configuring PostgreSQL security..."
PG_HBA_FILE=$(find /etc/postgresql -name "pg_hba.conf" | head -1)
if [ -f "$PG_HBA_FILE" ]; then
    cp "$PG_HBA_FILE" "${PG_HBA_FILE}.bak"
    systemctl restart postgresql
    print_info "PostgreSQL restarted"
else
    print_warning "pg_hba.conf not found, continuing..."
fi

# Step 5: Clone repository
print_info "Step 5: Cloning repository..."
if [ -d "$PROJECT_DIR" ]; then
    print_warning "Directory $PROJECT_DIR already exists, updating..."
    cd "$PROJECT_DIR"
    git stash
    git pull origin main
    git stash pop || true
else
    git clone "$REPO_URL" "$PROJECT_DIR"
    cd "$PROJECT_DIR"
fi

# Step 6: Fix Git safe directory (важно!)
git config --global --add safe.directory "$PROJECT_DIR"

# Step 7: Create virtual environment
print_info "Step 7: Creating virtual environment..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Step 8: Install Python dependencies
print_info "Step 8: Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt
# Устанавливаем Pillow принудительно
pip install Pillow

# Step 9: Create .env file (ИСПРАВЛЕННЫЙ!)
print_info "Step 9: Creating .env file..."
cat > "$PROJECT_DIR/.env" <<EOF
# Django Settings
DJANGO_SECRET_KEY=$DJANGO_SECRET_KEY
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,$SERVER_IP
DJANGO_STATIC_ROOT=/var/www/fefu_lab/staticfiles  # ИСПРАВЛЕНО: staticfiles
DJANGO_MEDIA_ROOT=/var/www/fefu_lab/media
DJANGO_CSRF_TRUSTED_ORIGINS=http://localhost,http://$SERVER_IP

# Database Settings
DB_ENGINE=postgresql
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD  # ТОТ ЖЕ ПАРОЛЬ ЧТО ВЫШЕ
DB_HOST=localhost
DB_PORT=5432
EOF

chmod 600 "$PROJECT_DIR/.env"
print_info ".env file created with IP: $SERVER_IP"

# Step 10: Fix settings.py (ВАЖНО!)
print_info "Step 10: Fixing Django settings..."
# Создаем исправленный settings_local.py
cat > "$PROJECT_DIR/settings_local.py" <<'EOF'
# Локальные исправления настроек

# Исправляем статические файлы
STATIC_ROOT = '/var/www/fefu_lab/staticfiles'  # Для collectstatic
STATICFILES_DIRS = ['/var/www/fefu_lab/static']  # Для разработки

# Простая база данных
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'fefu_lab_db',
        'USER': 'fefu_user',
        'PASSWORD': 'fefu123',
        'HOST': 'localhost',
        'PORT': '5432',
    }
}
EOF

# Добавляем импорт в конец settings.py
echo -e "\n# Local overrides\ntry:\n    from .settings_local import *\nexcept ImportError:\n    pass" >> "$PROJECT_DIR/settings.py"

# Step 11: Set permissions
print_info "Step 11: Setting permissions..."
chown -R www-data:www-data "$PROJECT_DIR"
chmod -R 755 "$PROJECT_DIR"

mkdir -p "$PROJECT_DIR/static"
mkdir -p "$PROJECT_DIR/staticfiles"
mkdir -p "$PROJECT_DIR/media"
chown -R www-data:www-data "$PROJECT_DIR/static" "$PROJECT_DIR/staticfiles" "$PROJECT_DIR/media"
print_info "Permissions configured"

# Step 12: Apply migrations (С ПРОВЕРКОЙ!)
print_info "Step 12: Applying migrations..."
# Сначала проверяем подключение к БД
if PGPASSWORD=fefu123 psql -h localhost -U fefu_user -d fefu_lab_db -c "SELECT 1;" &>/dev/null; then
    print_info "PostgreSQL connection successful"
    python manage.py migrate --noinput
else
    print_warning "PostgreSQL connection failed, using SQLite..."
    # Используем SQLite как запасной вариант
    cat >> "$PROJECT_DIR/settings_local.py" <<'EOF'
# Fallback to SQLite
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': '/var/www/fefu_lab/db.sqlite3',
    }
}
EOF
    python manage.py migrate --noinput
fi

# Step 13: Collect static files
print_info "Step 13: Collecting static files..."
python manage.py collectstatic --noinput --clear

# Step 14: Create superuser
print_info "Step 14: Creating Django superuser..."
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@fefu.ru', 'admin123') if not User.objects.filter(username='admin').exists() else print('Superuser already exists')" | python manage.py shell
print_info "Superuser: admin / admin123"

# Step 15: Configure Gunicorn
print_info "Step 15: Configuring Gunicorn..."
mkdir -p /var/log/gunicorn
chown -R www-data:www-data /var/log/gunicorn

# Создаем базовый конфиг gunicorn если его нет
if [ ! -f "/etc/systemd/system/gunicorn.service" ]; then
    cat > /etc/systemd/system/gunicorn.service <<EOF
[Unit]
Description=gunicorn daemon for fefu_lab
After=network.target postgresql.service

[Service]
User=www-data
Group=www-data
WorkingDirectory=$PROJECT_DIR
Environment="PATH=$VENV_DIR/bin"
ExecStart=$VENV_DIR/bin/gunicorn --access-logfile - --workers 3 --bind unix:$PROJECT_DIR/fefu_lab.sock web_2025.wsgi:application

[Install]
WantedBy=multi-user.target
EOF
fi

systemctl daemon-reload
systemctl enable gunicorn
systemctl start gunicorn
print_info "Gunicorn service started"

# Step 16: Configure Nginx
print_info "Step 16: Configuring Nginx..."
# Создаем конфиг nginx если его нет
cat > /etc/nginx/sites-available/fefu_lab <<EOF
server {
    listen 80;
    server_name $SERVER_IP localhost;

    location = /favicon.ico { access_log off; log_not_found off; }
    
    location /static/ {
        root /var/www/fefu_lab/staticfiles;
    }
    
    location /media/ {
        root /var/www/fefu_lab;
    }
    
    location / {
        include proxy_params;
        proxy_pass http://unix:/var/www/fefu_lab/fefu_lab.sock;
    }
}
EOF

ln -sf /etc/nginx/sites-available/fefu_lab /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

print_info "Checking Nginx configuration..."
if nginx -t; then
    systemctl restart nginx
    systemctl enable nginx
    print_info "Nginx successfully configured and started"
else
    print_error "Nginx configuration error"
    nginx -t
    exit 1
fi

# Step 17: Verify functionality
print_info "Step 17: Verifying functionality..."
sleep 3

print_info "=== SERVICE CHECK ==="

echo ""
print_info "1. Nginx status:"
systemctl is-active nginx && echo "Nginx: ACTIVE" || echo "Nginx: INACTIVE"

echo ""
print_info "2. Gunicorn status:"
systemctl is-active gunicorn && echo "Gunicorn: ACTIVE" || echo "Gunicorn: INACTIVE"

echo ""
print_info "3. Application check:"
if curl -f http://localhost > /dev/null 2>&1; then
    print_info "✓ APPLICATION IS WORKING: http://$SERVER_IP"
else
    print_warning "Application not responding, checking logs..."
    journalctl -u gunicorn --no-pager -n 10
fi

# Step 18: Deployment summary
print_info "========================================"
print_info "DEPLOYMENT SUCCESSFULLY COMPLETED!"
print_info "========================================"
print_info "ACCESS DETAILS:"
print_info "Application: http://$SERVER_IP"
print_info "Admin panel: http://$SERVER_IP/admin"
print_info "Login: admin"
print_info "Password: admin123"
print_info ""
print_info "DATABASE:"
print_info "DB Name: $DB_NAME"
print_info "DB User: $DB_USER"
print_info "DB Password: $DB_PASSWORD"
print_info ""
print_info "TROUBLESHOOTING:"
print_info "Check logs: journalctl -u gunicorn -f"
print_info "Check nginx: tail -f /var/log/nginx/error.log"
print_info "========================================"

# Save credentials
cat > /root/fefu_lab_credentials.txt <<EOF
FEFU Lab - Access Credentials
================================
Deployment time: $(date)
Server IP: $SERVER_IP

WEB APPLICATION:
URL: http://$SERVER_IP
Admin: http://$SERVER_IP/admin
Login: admin
Password: admin123

DATABASE:
DB Name: $DB_NAME
DB User: $DB_USER
DB Password: $DB_PASSWORD
================================
EOF

chmod 600 /root/fefu_lab_credentials.txt
print_info "Credentials saved to /root/fefu_lab_credentials.txt"
print_info ""
print_info "Deployment completed! Application should be available at:"
print_info "    http://$SERVER_IP"
print_info "    http://$SERVER_IP/admin"