# ========== ПОЛНЫЙ СБРОС ==========
echo "СТАДИЯ 1: ПОЛНАЯ ОЧИСТКА"
systemctl stop nginx gunicorn postgresql 2>/dev/null || true
pkill -f gunicorn 2>/dev/null || true
pkill -f "python.*manage.py" 2>/dev/null || true

rm -rf /var/www/fefu_lab
rm -f /etc/nginx/sites-available/fefu_lab.conf
rm -f /etc/nginx/sites-enabled/fefu_lab.conf
rm -f /etc/systemd/system/gunicorn.service
rm -f /etc/fefu_lab/fefu_lab.env
rm -rf /var/log/gunicorn

sudo -u postgres psql -c "DROP DATABASE IF EXISTS fefu_lab_db;" 2>/dev/null || true
sudo -u postgres psql -c "DROP USER IF EXISTS fefu_user;" 2>/dev/null || true

systemctl daemon-reload
systemctl start nginx postgresql
echo "Очистка завершена. Система чистая."