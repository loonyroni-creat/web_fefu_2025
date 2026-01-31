# ========== СКАЧИВАНИЕ И УСТАНОВКА ==========
echo "СТАДИЯ 2: СКАЧИВАНИЕ И УСТАНОВКА"
cd /var/www
git clone https://github.com/victoreelite/web_fefu_2025.git fefu_lab
cd fefu_lab

# Устанавливаем зависимости системы
apt update -y
apt install -y python3 python3-venv python3-pip nginx postgresql libpq-dev