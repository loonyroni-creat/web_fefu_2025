# ========== NGINX ==========
echo "СТАДИЯ 6: NGINX"
cat > /etc/nginx/sites-available/fefu_lab << 'EOF'
server {
    listen 80;
    server_name 192.168.224.140;
    
    location /static/ {
        alias /var/www/fefu_lab/staticfiles/;
    }
    
    location /media/ {
        alias /var/www/fefu_lab/media/;
    }
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

ln -sf /etc/nginx/sites-available/fefu_lab /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx