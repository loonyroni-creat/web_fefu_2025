# ========== БАЗА ДАННЫХ ==========
echo "СТАДИЯ 3: БАЗА ДАННЫХ"
sudo -u postgres psql -c "CREATE USER fefu_user WITH PASSWORD 'fefu123';"
sudo -u postgres psql -c "CREATE DATABASE fefu_lab_db OWNER fefu_user;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE fefu_lab_db TO fefu_user;"