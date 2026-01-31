# ========== ПРОВЕРКА ==========
echo "СТАДИЯ 7: ПРОВЕРКА"
sleep 2
echo "Проверяем сервисы:"
systemctl is-active nginx && echo "Nginx: ЗАПУЩЕН" || echo "Nginx: ОШИБКА"
pgrep gunicorn && echo "Gunicorn: ЗАПУЩЕН" || echo "Gunicorn: ОШИБКА"

echo ""
echo "Проверяем доступность:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://192.168.224.140 || echo "000")
echo "HTTP код: $HTTP_CODE"

echo ""
echo "=========================================="
if [[ "$HTTP_CODE" =~ ^(200|301|302)$ ]]; then
    echo "УСПЕХ! Приложение работает."
    echo "Ссылка: http://192.168.224.140"
    echo "Админка: http://192.168.224.140/admin"
    echo "Логин: admin"
    echo "Пароль: admin123"
else
    echo "ОШИБКА! Проверь логи:"
    echo "1. ps aux | grep gunicorn"
    echo "2. journalctl -u nginx -n 20"
    echo "3. curl -v http://127.0.0.1:8000"
fi
echo "=========================================="