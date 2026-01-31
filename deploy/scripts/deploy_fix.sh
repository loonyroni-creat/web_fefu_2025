#!/bin/bash
# Полный скрипт развертывания FEFU Lab

set -euo pipefail
exec 2>&1

REPO_URL="https://github.com/victoreelite/web_fefu_2025.git"
APP_DIR="/var/www/fefu_lab"
ENV_FILE="/etc/fefu_lab/fefu_lab.env"
GUNICORN_LOG_DIR="/var/log/gunicorn"
VM_IP="192.168.224.140"
DB_NAME="fefu_lab_db"
DB_USER="fefu_user"

echo "=========================================="
echo "   ПОЛНОЕ РАЗВЕРТЫВАНИЕ FEFU LAB"
echo "=========================================="

echo "[1/10] Устанавливаем пакеты системы..."
apt update -y && apt upgrade -y
apt install -y git curl nginx python3 python3-venv python3-pip \
    postgresql postgresql-contrib libpq-dev libjpeg-dev libpng-dev \
    libwebp-dev zlib1g-dev

echo "[2/10] Настраиваем PostgreSQL..."
PG_VER=$(ls /etc/postgresql/ | sort -V | tail -n1)
PG_CONF="/etc/postgresql/${PG_VER}/main/postgresql.conf"
PG_HBA="/etc/postgresql/${PG_VER}/main/pg_hba.conf"

sed -i "s/^#\?listen_addresses\s*=.*/listen_addresses = 'localhost'/" "$PG_CONF"

if ! grep -q "host.*all.*all.*127.0.0.1/32.*scram-sha-256" "$PG_HBA"; then
    echo "host all all 127.0.0.1/32 scram-sha-256" >> "$PG_HBA"
fi
if ! grep -q "host.*all.*all.*::1/128.*scram-sha-256" "$PG_HBA"; then
    echo "host all all ::1/128 scram-sha-256" >> "$PG_HBA"
fi

systemctl restart postgresql

echo "[3/10] Создаем базу данных PostgreSQL..."
DB_PASSWORD=$(python3 -c "import secrets; print(secrets.token_urlsafe(18))")

sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;" 2>/dev/null || true
sudo -u postgres psql -c "DROP USER IF EXISTS $DB_USER;" 2>/dev/null || true

sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

echo "[4/10] Клонируем репозиторий в $APP_DIR..."
rm -rf "$APP_DIR"
git clone "$REPO_URL" "$APP_DIR"
cd "$APP_DIR"

echo "[5/10] Создаем виртуальное окружение..."
python3 -m venv "$APP_DIR/venv"
source "$APP_DIR/venv/bin/activate"
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt
pip install Pillow gunicorn psycopg2-binary

echo "[6/10] Создаем файл с настройками окружения..."
mkdir -p "$(dirname "$ENV_FILE")"
DJANGO_SECRET_KEY=$(python3 -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())")

cat > "$ENV_FILE" <<EOF
DJANGO_ENV=production
DJANGO_SECRET_KEY='$DJANGO_SECRET_KEY'
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=$VM_IP,localhost,127.0.0.1
DJANGO_STATIC_ROOT=$APP_DIR/staticfiles
DJANGO_MEDIA_ROOT=$APP_DIR/media
DJANGO_CSRF_TRUSTED_ORIGINS=http://$VM_IP

DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_HOST=localhost
DB_PORT=5432
EOF

chmod 600 "$ENV_FILE"

echo "[7/10] Настраиваем права доступа..."
mkdir -p "$APP_DIR/static" "$APP_DIR/staticfiles" "$APP_DIR/media" "$GUNICORN_LOG_DIR"
chown -R www-data:www-data "$APP_DIR" "$GUNICORN_LOG_DIR"
chmod -R 755 "$APP_DIR"

echo "[8/10] Применяем миграции и собираем статические файлы..."
set -a; source "$ENV_FILE"; set +a

if PGPASSWORD=$DB_PASSWORD psql -h localhost -U $DB_USER -d $DB_NAME -c "\q" 2>/dev/null; then
    echo "Подключение к PostgreSQL успешно."
else
    echo "ОШИБКА: Не удалось подключиться к PostgreSQL."
    exit 1
fi

sudo -u www-data -E "$APP_DIR/venv/bin/python" "$APP_DIR/manage.py" migrate --noinput
sudo -u www-data -E "$APP_DIR/venv/bin/python" "$APP_DIR/manage.py" collectstatic --noinput --clear

echo "[9/10] Настраиваем и запускаем Gunicorn..."
if [[ -f "$APP_DIR/deploy/systemd/gunicorn.service" ]]; then
    cp "$APP_DIR/deploy/systemd/gunicorn.service" /etc/systemd/system/
else
    cat > /etc/systemd/system/gunicorn.service <<EOF
[Unit]
Description=Gunicorn для FEFU Lab
After=network.target postgresql.service

[Service]
User=www-data
Group=www-data
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
EnvironmentFile=$ENV_FILE
ExecStart=$APP_DIR/venv/bin/gunicorn \\
    --access-logfile $GUNICORN_LOG_DIR/access.log \\
    --error-logfile $GUNICORN_LOG_DIR/error.log \\
    --workers 3 \\
    --bind unix:$APP_DIR/fefu_lab.sock \\
    web_2025.wsgi:application

[Install]
WantedBy=multi-user.target
EOF
fi

systemctl daemon-reload
systemctl enable gunicorn
systemctl restart gunicorn

echo "[10/10] Настраиваем и запускаем Nginx..."
if [[ -f "$APP_DIR/deploy/nginx/fefu_lab.conf" ]]; then
    cp "$APP_DIR/deploy/nginx/fefu_lab.conf" /etc/nginx/sites-available/
else
    cat > /etc/nginx/sites-available/fefu_lab.conf <<EOF
server {
    listen 80;
    server_name $VM_IP localhost;

    location = /favicon.ico { access_log off; log_not_found off; }

    location /static/ {
        alias $APP_DIR/staticfiles/;
    }

    location /media/ {
        alias $APP_DIR/media/;
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:$APP_DIR/fefu_lab.sock;
    }
}
EOF
fi

ln -sf /etc/nginx/sites-available/fefu_lab.conf /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl restart nginx

echo ""
echo "=========================================="
echo "          РАЗВЕРТЫВАНИЕ ЗАВЕРШЕНО"
echo "=========================================="

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost || echo "CURL_ERROR")
echo "Статус ответа от localhost: $HTTP_CODE"

echo ""
echo "Статус сервисов:"
for service in nginx gunicorn postgresql; do
    if systemctl is-active --quiet "$service"; then
        echo "  $service запущен"
    else
        echo "  $service НЕ ЗАПУЩЕН"
    fi
done

echo ""
echo "=========================================="
echo "            ДОСТУП К ПРИЛОЖЕНИЮ"
echo "=========================================="
echo "Главная страница:  http://$VM_IP"
echo "Админ-панель:      http://$VM_IP/admin"
echo ""
echo "Учетные данные администратора:"
echo "  Логин:    admin"
echo "  Пароль:   admin123"
echo ""
echo "Пароль для базы данных PostgreSQL сохранен в:"
echo "  $ENV_FILE"
echo "=========================================="