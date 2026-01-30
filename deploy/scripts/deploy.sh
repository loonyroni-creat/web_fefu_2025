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

# Конфигурация
REPO_URL="https://github.com/ваш-username/ваш-репозиторий.git"  # Замените на ваш репозиторий
PROJECT_DIR="/var/www/fefu_lab"
VENV_DIR="$PROJECT_DIR/venv"
DB_NAME="fefu_lab_db"
DB_USER="fefu_user"
DB_PASSWORD=$(openssl rand -base64 32)  # Генерация случайного пароля
DJANGO_SECRET_KEY=$(openssl rand -base64 64)

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
    build-essential \
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
PG_HBA_FILE="/etc/postgresql/14/main/pg_hba.conf"
if [ -f "$PG_HBA_FILE" ]; then
    # Резервная копия
    cp "$PG_HBA_FILE" "${PG_HBA_FILE}.bak"
    
    # Настройка доступа только с localhost
    sed -i 's/host    all             all             127.0.0.1\/32            scram-sha-256/host    all             all             127.0.0.1\/32            scram-sha-256/g' "$PG_HBA_FILE"
    sed -i 's/host    all             all             ::1\/128                 scram-sha-256/host    all             all             ::1\/128                 scram-sha-256/g' "$PG_HBA_FILE"
    
    systemctl restart postgresql
else
    print_warning "Файл pg_hba.conf не найден, проверьте версию PostgreSQL"
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
cat > "$PROJECT_DIR/.env" <<EOF
# Django Settings
DJANGO_SECRET_KEY=$DJANGO_SECRET_KEY
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1
DJANGO_STATIC_ROOT=/var/www/fefu_lab/static
DJANGO_MEDIA_ROOT=/var/www/fefu_lab/media
DJANGO_CSRF_TRUSTED_ORIGINS=http://localhost

# Database Settings
DB_ENGINE=postgresql
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_HOST=localhost
DB_PORT=5432
EOF

# Защита .env файла
chmod 600 "$PROJECT_DIR/.env"

# Шаг 9: Настройка прав доступа
print_info "Шаг 9: Настройка прав доступа..."
chown -R www-data:www-data "$PROJECT_DIR"
chmod -R 755 "$PROJECT_DIR"

# Создание директорий для статики и медиа
mkdir -p "$PROJECT_DIR/static"
mkdir -p "$PROJECT_DIR/media"
chown -R www-data:www-data "$PROJECT_DIR/static" "$PROJECT_DIR/media"

# Шаг 10: Применение миграций
print_info "Шаг 10: Применение миграций..."
python manage.py migrate --noinput

# Шаг 11: Сбор статических файлов
print_info "Шаг 11: Сбор статических файлов..."
python manage.py collectstatic --noinput --clear

# Шаг 12: Создание суперпользователя (опционально)
read -p "Создать суперпользователя Django? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    python manage.py createsuperuser
fi

# Шаг 13: Настройка Gunicorn
print_info "Шаг 13: Настройка Gunicorn..."
# Создание директории для логов
mkdir -p /var/log/gunicorn
chown -R www-data:www-data /var/log/gunicorn

# Копирование конфигурационных файлов
cp "$PROJECT_DIR/deploy/gunicorn/config.py" /var/www/fefu_lab/deploy/gunicorn/ || true
cp "$PROJECT_DIR/deploy/systemd/gunicorn.service" /etc/systemd/system/

# Перезагрузка systemd и запуск сервиса
systemctl daemon-reload
systemctl enable gunicorn
systemctl start gunicorn

# Шаг 14: Настройка Nginx
print_info "Шаг 14: Настройка Nginx..."
# Копирование конфига
cp "$PROJECT_DIR/deploy/nginx/fefu_lab.conf" /etc/nginx/sites-available/

# Создание символической ссылки
ln -sf /etc/nginx/sites-available/fefu_lab.conf /etc/nginx/sites-enabled/

# Удаление дефолтного конфига
rm -f /etc/nginx/sites-enabled/default

# Проверка конфигурации Nginx
if nginx -t; then
    systemctl restart nginx
    systemctl enable nginx
else
    print_error "Ошибка в конфигурации Nginx"
    exit 1
fi

# Шаг 15: Настройка фаервола (опционально)
print_info "Шаг 15: Настройка фаервола..."
# Разрешаем только HTTP (порт 80)
ufw allow 80/tcp
ufw --force enable || true

# Шаг 16: Проверка работоспособности
print_info "Шаг 16: Проверка работоспособности..."
sleep 5  # Даем время сервисам запуститься

# Проверка сервисов
print_info "Проверка статуса сервисов:"
systemctl status nginx --no-pager
echo ""
systemctl status gunicorn --no-pager
echo ""
systemctl status postgresql --no-pager

# Проверка доступности приложения
print_info "Проверка доступности приложения..."
if curl -f http://localhost > /dev/null 2>&1; then
    print_info "Приложение успешно запущено и доступно по http://localhost"
    print_info "Доступно также по вашему IP адресу в сети"
else
    print_error "Приложение недоступно. Проверьте логи."
    journalctl -u gunicorn --no-pager -n 20
    journalctl -u nginx --no-pager -n 20
fi

# Шаг 17: Информация о деплое
print_info "========================================"
print_info "ДЕПЛОЙ УСПЕШНО ЗАВЕРШЕН!"
print_info "========================================"
print_info "Данные для доступа:"
print_info "Приложение: http://ваш-ip-адрес"
print_info "База данных: PostgreSQL"
print_info "  Имя БД: $DB_NAME"
print_info "  Пользователь: $DB_USER"
print_info "  Пароль: $DB_PASSWORD"
print_info "Статические файлы: $PROJECT_DIR/static"
print_info "Медиа файлы: $PROJECT_DIR/media"
print_info "Логи Gunicorn: /var/log/gunicorn/"
print_info "Логи Nginx: /var/log/nginx/"
print_info "========================================"

# Сохранение паролей в файл (для безопасности храните отдельно)
cat > /root/fefu_lab_credentials.txt <<EOF
FEFU Lab Deployment Credentials
================================
Application URL: http://ваш-ip-адрес
Database:
  Name: $DB_NAME
  User: $DB_USER
  Password: $DB_PASSWORD
PostgreSQL Connection: psql -h localhost -U $DB_USER -d $DB_NAME
EOF

chmod 600 /root/fefu_lab_credentials.txt
print_info "Данные для доступа сохранены в /root/fefu_lab_credentials.txt"