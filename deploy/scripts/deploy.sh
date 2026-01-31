#!/bin/bash

# Скрипт деплоя для FEFU Lab
# Автоматизация развертывания Django приложения на Ubuntu

set -e  # Выход при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функции для вывода
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка прав
if [[ $EUID -ne 0 ]]; then
    print_error "Этот скрипт должен запускаться с правами root"
    exit 1
fi

# ============ КОНФИГУРАЦИЯ ============
REPO_URL="https://github.com/loonyroni-creat/web_fefu_2025.git"
PROJECT_DIR="/var/www/fefu_lab"
VENV_DIR="$PROJECT_DIR/venv"
DB_NAME="fefu_lab_db"
DB_USER="fefu_user"
DB_PASSWORD=$(openssl rand -base64 32)
DJANGO_SECRET_KEY=$(openssl rand -base64 64)
# ======================================

# Шаг 1: Обновление системы
print_info "Шаг 1: Обновление системы..."
apt update
apt upgrade -y

# Шаг 2: Установка необходимых пакетов
print_info "Шаг 2: Установка необходимых пакетов..."
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    postgresql \
    postgresql-contrib \
    nginx \
    curl \
    git \
    libpq-dev

# Шаг 3: Настройка PostgreSQL
print_info "Шаг 3: Настройка PostgreSQL..."
sudo -u postgres psql <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
ALTER ROLE $DB_USER SET client_encoding TO 'utf8';
ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';
ALTER ROLE $DB_USER SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\q
EOF

# Шаг 4: Настройка безопасности PostgreSQL
print_info "Шаг 4: Настройка безопасности PostgreSQL..."
PG_VERSION=$(psql --version 2>/dev/null | awk '{print $3}' | cut -d'.' -f1)
if [ -z "$PG_VERSION" ]; then
    PG_VERSION=14
fi
PG_HBA_FILE="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"

if [ -f "$PG_HBA_FILE" ]; then
    cp "$PG_HBA_FILE" "${PG_HBA_FILE}.bak"
    
    sed -i 's/^host\s\+all\s\+all\s\+0\.0\.0\.0\/0.*/# &/' "$PG_HBA_FILE"
    sed -i 's/^host\s\+all\s\+all\s\+::\/0.*/# &/' "$PG_HBA_FILE"
    
    systemctl restart postgresql
    print_info "PostgreSQL перезапущен. Доступ только с localhost."
else
    print_warning "Файл pg_hba.conf не найден по пути: $PG_HBA_FILE"
    print_info "Проверьте установлен ли PostgreSQL: systemctl status postgresql"
fi

# Шаг 5: Клонирование репозитория
print_info "Шаг 5: Клонирование репозитория..."
if [ -d "$PROJECT_DIR" ]; then
    print_warning "Директория $PROJECT_DIR уже существует, выполняем обновление..."
    cd "$PROJECT_DIR"
    git pull origin main
else
    git clone "$REPO_URL" "$PROJECT_DIR"
    cd "$PROJECT_DIR"
fi

# Шаг 6: Создание виртуального окружения
print_info "Шаг 6: Создание виртуального окружения..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi

# Активация виртуального окружения
source "$VENV_DIR/bin/activate"

# Шаг 7: Установка зависимостей Python
print_info "Шаг 7: Установка зависимостей Python..."
pip install --upgrade pip
pip install -r requirements.txt

# Шаг 8: Создание .env файла
print_info "Шаг 8: Создание .env файла..."
SERVER_IP=$(hostname -I | awk '{print $1}')
if [ -z "$SERVER_IP" ]; then
    SERVER_IP="127.0.0.1"
fi

cat > "$PROJECT_DIR/.env" <<EOF
# Django Settings
DJANGO_SECRET_KEY=$DJANGO_SECRET_KEY
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,$SERVER_IP
DJANGO_STATIC_ROOT=/var/www/fefu_lab/static
DJANGO_MEDIA_ROOT=/var/www/fefu_lab/media
DJANGO_CSRF_TRUSTED_ORIGINS=http://localhost,http://$SERVER_IP

# Database Settings
DB_ENGINE=postgresql
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_HOST=localhost
DB_PORT=5432
EOF

chmod 600 "$PROJECT_DIR/.env"
print_info ".env файл создан с IP: $SERVER_IP"

# Шаг 9: Настройка прав доступа
print_info "Шаг 9: Настройка прав доступа..."
chown -R www-data:www-data "$PROJECT_DIR"
chmod -R 755 "$PROJECT_DIR"

mkdir -p "$PROJECT_DIR/static"
mkdir -p "$PROJECT_DIR/media"
chown -R www-data:www-data "$PROJECT_DIR/static" "$PROJECT_DIR/media"
print_info "Права доступа настроены"

# Шаг 10: Применение миграций
print_info "Шаг 10: Применение миграций..."
python manage.py migrate --noinput

# Шаг 11: Сбор статических файлов
print_info "Шаг 11: Сбор статических файлов..."
python manage.py collectstatic --noinput --clear

# Шаг 12: Создание суперпользователя
print_info "Шаг 12: Создание суперпользователя Django..."
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@fefu.ru', 'admin123') if not User.objects.filter(username='admin').exists() else None" | python manage.py shell
print_info "Создан суперпользователь: admin / admin123"

# Шаг 13: Настройка Gunicorn
print_info "Шаг 13: Настройка Gunicorn..."
mkdir -p /var/log/gunicorn
chown -R www-data:www-data /var/log/gunicorn

mkdir -p /var/www/fefu_lab/deploy/gunicorn
cp "$PROJECT_DIR/deploy/gunicorn/config.py" /var/www/fefu_lab/deploy/gunicorn/ || true
cp "$PROJECT_DIR/deploy/systemd/gunicorn.service" /etc/systemd/system/

systemctl daemon-reload
systemctl enable gunicorn
systemctl start gunicorn
print_info "Сервис Gunicorn запущен"

# Шаг 14: Настройка Nginx
print_info "Шаг 14: Настройка Nginx..."
cp "$PROJECT_DIR/deploy/nginx/fefu_lab.conf" /etc/nginx/sites-available/

ln -sf /etc/nginx/sites-available/fefu_lab.conf /etc/nginx/sites-enabled/

rm -f /etc/nginx/sites-enabled/default

print_info "Проверка конфигурации Nginx..."
if nginx -t; then
    systemctl restart nginx
    systemctl enable nginx
    print_info "Nginx успешно настроен и запущен"
else
    print_error "Ошибка в конфигурации Nginx"
    nginx -t
    exit 1
fi

# Шаг 15: Настройка фаервола
print_info "Шаг 15: Настройка фаервола..."
if ! command -v ufw &> /dev/null; then
    apt install -y ufw
fi

ufw allow 80/tcp
echo "y" | ufw enable 2>/dev/null || true
print_info "Фаервол настроен: открыт порт 80 (HTTP)"

# Шаг 16: Проверка работоспособности
print_info "Шаг 16: Проверка работоспособности..."
sleep 5

print_info "=== ПРОВЕРКА СЕРВИСОВ ==="

echo ""
print_info "1. Статус Nginx:"
systemctl status nginx --no-pager | head -10

echo ""
print_info "2. Статус Gunicorn:"
systemctl status gunicorn --no-pager | head -10

echo ""
print_info "3. Статус PostgreSQL:"
systemctl status postgresql --no-pager | head -10

echo ""
print_info "4. Проверка открытых портов:"
netstat -tulpn | grep -E ':(80|5432|8000)' || true

echo ""
print_info "5. Проверка доступности приложения..."
if curl -f http://localhost > /dev/null 2>&1; then
    print_info "ПРИЛОЖЕНИЕ ДОСТУПНО: http://localhost"
    print_info "ВНЕШНИЙ ДОСТУП: http://$SERVER_IP"
else
    print_error "Приложение недоступно. Проверьте логи..."
    echo ""
    print_info "Последние логи Gunicorn:"
    journalctl -u gunicorn --no-pager -n 20
    echo ""
    print_info "Последние логи Nginx:"
    journalctl -u nginx --no-pager -n 20
fi

# Шаг 17: Итоговая информация
print_info "========================================"
print_info "ДЕПЛОЙ УСПЕШНО ЗАВЕРШЕН!"
print_info "========================================"
print_info "ДАННЫЕ ДЛЯ ДОСТУПА:"
print_info "Приложение: http://$SERVER_IP"
print_info "Админка: http://$SERVER_IP/admin"
print_info "Логин: admin"
print_info "Пароль: admin123"
print_info ""
print_info "БАЗА ДАННЫХ:"
print_info "Имя БД: $DB_NAME"
print_info "Пользователь: $DB_USER"
print_info "Пароль: $DB_PASSWORD"
print_info ""
print_info "ПУТИ К ФАЙЛАМ:"
print_info "Проект: $PROJECT_DIR"
print_info "Статика: $PROJECT_DIR/static"
print_info "Медиа: $PROJECT_DIR/media"
print_info "Логи Gunicorn: /var/log/gunicorn/"
print_info "Логи Nginx: /var/log/nginx/"
print_info "========================================"

cat > /root/fefu_lab_credentials.txt <<EOF
FEFU Lab - Данные для доступа
================================
Время развертывания: $(date)
IP сервера: $SERVER_IP

ВЕБ-ПРИЛОЖЕНИЕ:
URL: http://$SERVER_IP
Админка: http://$SERVER_IP/admin
Логин: admin
Пароль: admin123

БАЗА ДАННЫХ PostgreSQL:
Имя БД: $DB_NAME
Пользователь: $DB_USER
Пароль: $DB_PASSWORD
Подключение: psql -h localhost -U $DB_USER -d $DB_NAME
================================
EOF

chmod 600 /root/fefu_lab_credentials.txt
print_info "Все данные сохранены в /root/fefu_lab_credentials.txt"

print_info ""
print_info "ДЛЯ ОТЧЕТА:"
print_info "1. Скриншот работающего приложения: http://$SERVER_IP"
print_info "2. Скриншот команды: sudo netstat -tulpn"
print_info "3. Скриншот команды с хоста: nmap -p 80,5432,8000 $SERVER_IP"
print_info "4. Скриншот админки: http://$SERVER_IP/admin"
print_info ""
print_info "Деплой завершен!"