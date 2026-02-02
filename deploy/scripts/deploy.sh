#!/bin/bash
# Минимальный скрипт настройки для FEFU Lab
# Предполагает, что всё уже установлено

echo "=== Настройка FEFU Lab ==="

# 1. Настройка PostgreSQL доступов
echo "1. Настройка доступа к PostgreSQL..."
sudo -u postgres psql -c "CREATE USER fefu_user WITH PASSWORD 'strongpassword';" 2>/dev/null || true
sudo -u postgres psql -c "ALTER USER fefu_user CREATEDB;" 2>/dev/null || true
sudo -u postgres createdb -O fefu_user fefu_lab_db 2>/dev/null || true

# 2. Копирование конфигов
echo "2. Копирование конфигураций..."
sudo cp deploy/nginx/fefu_lab.conf /etc/nginx/sites-available/
sudo ln -sf /etc/nginx/sites-available/fefu_lab.conf /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

sudo cp deploy/systemd/gunicorn.service /etc/systemd/system/

# 3. Создание директорий
echo "3. Создание рабочих директорий..."
sudo mkdir -p /run/gunicorn /var/www/fefu_lab/staticfiles /var/www/fefu_lab/media
sudo chown -R www-data:www-data /run/gunicorn /var/www/fefu_lab
sudo chmod -R 755 /var/www/fefu_lab

# 4. Перезапуск сервисов
echo "4. Перезапуск сервисов..."
sudo systemctl daemon-reload
sudo systemctl restart gunicorn
sudo systemctl enable gunicorn
sudo systemctl restart nginx

# 5. Проверка
echo "5. Проверка..."
echo "Сервисы:"
sudo systemctl status gunicorn --no-pager | head -5
sudo systemctl status nginx --no-pager | head -5

echo ""
echo "=== Готово! ==="
echo "Приложение доступно по: http://192.168.224.141"