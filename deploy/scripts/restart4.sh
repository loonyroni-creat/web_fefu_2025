# ========== DJANGO ==========
echo "СТАДИЯ 4: DJANGO"
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install pillow gunicorn psycopg2-binary

# Применяем миграции
python manage.py migrate --noinput
python manage.py collectstatic --noinput

# Создаем суперпользователя
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@fefu.ru', 'admin123')" | python manage.py shell