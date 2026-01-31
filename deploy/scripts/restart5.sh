# ========== GUNICORN ==========
echo "СТАДИЯ 5: GUNICORN"
# Запускаем Gunicorn в фоне
venv/bin/gunicorn --workers 3 --bind 127.0.0.1:8000 web_2025.wsgi:application &
sleep 3

# Проверяем что Gunicorn работает
curl -s http://127.0.0.1:8000 > /dev/null && echo "Gunicorn запущен" || echo "Ошибка Gunicorn"