#!/bin/bash

# Deployment script for FEFU Lab
# Django application deployment automation on Ubuntu

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Output functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check permissions
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root"
    exit 1
fi

# Configuration
REPO_URL="https://github.com/loonyroni-creat/web_fefu_2025.git"
PROJECT_DIR="/var/www/fefu_lab"
VENV_DIR="$PROJECT_DIR/venv"
DB_NAME="fefu_lab_db"
DB_USER="fefu_user"
DB_PASSWORD=$(openssl rand -base64 32)
DJANGO_SECRET_KEY=$(openssl rand -base64 64)

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')
if [ -z "$SERVER_IP" ]; then
    SERVER_IP="127.0.0.1"
fi

# Step 1: System update
print_info "Step 1: Updating system..."
apt update
apt upgrade -y

# Step 2: Install required packages
print_info "Step 2: Installing required packages..."
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

# Step 3: PostgreSQL setup
print_info "Step 3: Configuring PostgreSQL..."
sudo -u postgres psql <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
ALTER ROLE $DB_USER SET client_encoding TO 'utf8';
ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';
ALTER ROLE $DB_USER SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\q
EOF

# Step 4: PostgreSQL security
print_info "Step 4: Configuring PostgreSQL security..."
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
    print_info "PostgreSQL restarted. Access only from localhost."
else
    print_warning "pg_hba.conf not found at: $PG_HBA_FILE"
    print_info "Check if PostgreSQL is installed: systemctl status postgresql"
fi

# Step 5: Clone repository
print_info "Step 5: Cloning repository..."
if [ -d "$PROJECT_DIR" ]; then
    print_warning "Directory $PROJECT_DIR already exists, updating..."
    cd "$PROJECT_DIR"
    git pull origin main
else
    git clone "$REPO_URL" "$PROJECT_DIR"
    cd "$PROJECT_DIR"
fi

# Step 6: Create virtual environment
print_info "Step 6: Creating virtual environment..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Step 7: Install Python dependencies
print_info "Step 7: Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Step 8: Create .env file
print_info "Step 8: Creating .env file..."
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
print_info ".env file created with IP: $SERVER_IP"

# Step 9: Set permissions
print_info "Step 9: Setting permissions..."
chown -R www-data:www-data "$PROJECT_DIR"
chmod -R 755 "$PROJECT_DIR"

mkdir -p "$PROJECT_DIR/static"
mkdir -p "$PROJECT_DIR/media"
chown -R www-data:www-data "$PROJECT_DIR/static" "$PROJECT_DIR/media"
print_info "Permissions configured"

# Step 10: Apply migrations
print_info "Step 10: Applying migrations..."
python manage.py migrate --noinput

# Step 11: Collect static files
print_info "Step 11: Collecting static files..."
python manage.py collectstatic --noinput --clear

# Step 12: Create superuser
print_info "Step 12: Creating Django superuser..."
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@fefu.ru', 'admin123') if not User.objects.filter(username='admin').exists() else None" | python manage.py shell
print_info "Superuser created: admin / admin123"

# Step 13: Configure Gunicorn
print_info "Step 13: Configuring Gunicorn..."
mkdir -p /var/log/gunicorn
chown -R www-data:www-data /var/log/gunicorn

mkdir -p /var/www/fefu_lab/deploy/gunicorn
cp "$PROJECT_DIR/deploy/gunicorn/config.py" /var/www/fefu_lab/deploy/gunicorn/ || true
cp "$PROJECT_DIR/deploy/systemd/gunicorn.service" /etc/systemd/system/

systemctl daemon-reload
systemctl enable gunicorn
systemctl start gunicorn
print_info "Gunicorn service started"

# Step 14: Configure Nginx
print_info "Step 14: Configuring Nginx..."
cp "$PROJECT_DIR/deploy/nginx/fefu_lab.conf" /etc/nginx/sites-available/

ln -sf /etc/nginx/sites-available/fefu_lab.conf /etc/nginx/sites-enabled/

rm -f /etc/nginx/sites-enabled/default

print_info "Checking Nginx configuration..."
if nginx -t; then
    systemctl restart nginx
    systemctl enable nginx
    print_info "Nginx successfully configured and started"
else
    print_error "Nginx configuration error"
    nginx -t
    exit 1
fi

# Step 15: Configure firewall
print_info "Step 15: Configuring firewall..."
if ! command -v ufw &> /dev/null; then
    apt install -y ufw
fi

ufw allow 80/tcp
echo "y" | ufw enable 2>/dev/null || true
print_info "Firewall configured: port 80 (HTTP) open"

# Step 16: Verify functionality
print_info "Step 16: Verifying functionality..."
sleep 5

print_info "=== SERVICE CHECK ==="

echo ""
print_info "1. Nginx status:"
systemctl status nginx --no-pager | head -10

echo ""
print_info "2. Gunicorn status:"
systemctl status gunicorn --no-pager | head -10

echo ""
print_info "3. PostgreSQL status:"
systemctl status postgresql --no-pager | head -10

echo ""
print_info "4. Open ports check:"
netstat -tulpn | grep -E ':(80|5432|8000)' || true

echo ""
print_info "5. Application availability check..."
if curl -f http://localhost > /dev/null 2>&1; then
    print_info "APPLICATION AVAILABLE: http://localhost"
    print_info "EXTERNAL ACCESS: http://$SERVER_IP"
else
    print_error "Application not available. Checking logs..."
    echo ""
    print_info "Recent Gunicorn logs:"
    journalctl -u gunicorn --no-pager -n 20
    echo ""
    print_info "Recent Nginx logs:"
    journalctl -u nginx --no-pager -n 20
fi

# Step 17: Deployment summary
print_info "========================================"
print_info "DEPLOYMENT SUCCESSFULLY COMPLETED!"
print_info "========================================"
print_info "ACCESS DETAILS:"
print_info "Application: http://$SERVER_IP"
print_info "Admin panel: http://$SERVER_IP/admin"
print_info "Login: admin"
print_info "Password: admin123"
print_info ""
print_info "DATABASE:"
print_info "DB Name: $DB_NAME"
print_info "DB User: $DB_USER"
print_info "DB Password: $DB_PASSWORD"
print_info ""
print_info "FILE PATHS:"
print_info "Project: $PROJECT_DIR"
print_info "Static files: $PROJECT_DIR/static"
print_info "Media files: $PROJECT_DIR/media"
print_info "Gunicorn logs: /var/log/gunicorn/"
print_info "Nginx logs: /var/log/nginx/"
print_info "========================================"

cat > /root/fefu_lab_credentials.txt <<EOF
FEFU Lab - Access Credentials
================================
Deployment time: $(date)
Server IP: $SERVER_IP

WEB APPLICATION:
URL: http://$SERVER_IP
Admin: http://$SERVER_IP/admin
Login: admin
Password: admin123

PostgreSQL DATABASE:
DB Name: $DB_NAME
DB User: $DB_USER
DB Password: $DB_PASSWORD
Connection: psql -h localhost -U $DB_USER -d $DB_NAME
================================
EOF

chmod 600 /root/fefu_lab_credentials.txt
print_info "All credentials saved to /root/fefu_lab_credentials.txt"

print_info ""
print_info "FOR REPORT:"
print_info "1. Screenshot of working application: http://$SERVER_IP"
print_info "2. Screenshot of command: sudo netstat -tulpn"
print_info "3. Screenshot from host: nmap -p 80,5432,8000 $SERVER_IP"
print_info "4. Screenshot of admin panel: http://$SERVER_IP/admin"
print_info ""
print_info "Deployment completed!"