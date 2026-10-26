#!/usr/bin/env bash
# ==============================================================================
# SANGITA TRAVELS PUNE — AWS EC2 DEPLOYMENT SCRIPT
# One-command deployment: Upload code → Install deps → Setup services → Go live
#
# Usage:
#   chmod +x deploy/aws-deploy.sh
#   ./deploy/aws-deploy.sh <EC2_PUBLIC_IP>
#
# Example:
#   ./deploy/aws-deploy.sh 13.234.56.78
# ==============================================================================

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
EC2_IP="${1:-}"
EC2_USER="ubuntu"
PEM_KEY="Sangitatravelpune.pem"
REMOTE_APP_DIR="/var/www/punemumbaicab"
DOMAIN="sangitatravelspune.com"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Validate Input ──────────────────────────────────────────────────────────
if [ -z "$EC2_IP" ]; then
    echo -e "${RED}❌ Error: Please provide your EC2 public IP address${NC}"
    echo -e "${YELLOW}Usage: ./deploy/aws-deploy.sh <EC2_PUBLIC_IP>${NC}"
    echo -e "${YELLOW}Example: ./deploy/aws-deploy.sh 13.234.56.78${NC}"
    exit 1
fi

# Find project root (script is in deploy/)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

if [ ! -f "$PEM_KEY" ]; then
    echo -e "${RED}❌ Error: PEM key file '$PEM_KEY' not found in project root${NC}"
    echo -e "${YELLOW}Make sure Sangitatravelpune.pem is in: $PROJECT_ROOT${NC}"
    exit 1
fi

# ─── Functions ────────────────────────────────────────────────────────────────
ssh_cmd() {
    ssh -i "$PEM_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${EC2_USER}@${EC2_IP}" "$@"
}

scp_cmd() {
    scp -i "$PEM_KEY" -o StrictHostKeyChecking=no "$@"
}

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       🚗 SANGITA TRAVELS PUNE — AWS DEPLOYMENT 🚗          ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Server:  ${EC2_IP}                                "
echo "║  User:    ${EC2_USER}                                       "
echo "║  App Dir: ${REMOTE_APP_DIR}                         "
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ─── Step 1: Test SSH Connection ──────────────────────────────────────────────
echo -e "${CYAN}[1/7] 🔐 Testing SSH connection to EC2...${NC}"
if ! ssh_cmd "echo 'SSH connection successful'"; then
    echo -e "${RED}❌ Cannot connect to ${EC2_IP}. Check:${NC}"
    echo "  1. EC2 instance is running"
    echo "  2. Security Group allows SSH (port 22) from your IP"
    echo "  3. PEM key is correct"
    echo "  4. Username might be 'ec2-user' instead of 'ubuntu'"
    exit 1
fi
echo -e "${GREEN}✅ SSH connection verified${NC}"

# ─── Step 2: Install System Dependencies on EC2 ──────────────────────────────
echo -e "${CYAN}[2/7] 📦 Installing system dependencies on EC2...${NC}"
ssh_cmd << 'REMOTE_SETUP'
set -euo pipefail

echo ">>> Updating system packages..."
sudo apt-get update -qq

echo ">>> Installing Python 3.11, pip, venv..."
sudo apt-get install -y -qq python3 python3-pip python3-venv sqlite3 curl git

echo ">>> Installing Node.js 20.x..."
if ! command -v node &> /dev/null || [[ "$(node -v | cut -d. -f1 | tr -d 'v')" -lt 20 ]]; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y -qq nodejs
fi

echo ">>> Installing Nginx..."
sudo apt-get install -y -qq nginx

echo ">>> Installing Certbot for SSL..."
sudo apt-get install -y -qq certbot python3-certbot-nginx

echo ">>> System dependencies installed:"
echo "  Python: $(python3 --version)"
echo "  Node:   $(node --version)"
echo "  npm:    $(npm --version)"
echo "  Nginx:  $(nginx -v 2>&1)"
echo "  SQLite: $(sqlite3 --version)"
REMOTE_SETUP
echo -e "${GREEN}✅ System dependencies installed${NC}"

# ─── Step 3: Create Application Directory on EC2 ─────────────────────────────
echo -e "${CYAN}[3/7] 📁 Preparing application directory on EC2...${NC}"
ssh_cmd << REMOTE_DIR
set -euo pipefail

sudo mkdir -p ${REMOTE_APP_DIR}
sudo chown -R ${EC2_USER}:${EC2_USER} ${REMOTE_APP_DIR}
mkdir -p ${REMOTE_APP_DIR}/backend/data
mkdir -p ${REMOTE_APP_DIR}/backend/data/logs
REMOTE_DIR
echo -e "${GREEN}✅ Application directory ready${NC}"

# ─── Step 4: Upload Project Files to EC2 ──────────────────────────────────────
echo -e "${CYAN}[4/7] 📤 Uploading project files to EC2 (this may take a minute)...${NC}"

# Create a tar excluding unnecessary files, then upload & extract
echo "  Creating deployment archive..."
tar czf /tmp/punemumbaicab-deploy.tar.gz \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='frontend/dist' \
    --exclude='__pycache__' \
    --exclude='.pytest_cache' \
    --exclude='.mypy_cache' \
    --exclude='.ruff_cache' \
    --exclude='*.pyc' \
    --exclude='*.pem' \
    --exclude='.DS_Store' \
    --exclude='bookings.db' \
    --exclude='bookings.db-wal' \
    --exclude='bookings.db-shm' \
    --exclude='backend/.venv' \
    -C "$PROJECT_ROOT" .

echo "  Uploading archive to EC2..."
scp_cmd /tmp/punemumbaicab-deploy.tar.gz "${EC2_USER}@${EC2_IP}:/tmp/"

echo "  Extracting on server..."
ssh_cmd << REMOTE_EXTRACT
set -euo pipefail
cd ${REMOTE_APP_DIR}
tar xzf /tmp/punemumbaicab-deploy.tar.gz
rm -f /tmp/punemumbaicab-deploy.tar.gz
REMOTE_EXTRACT

rm -f /tmp/punemumbaicab-deploy.tar.gz
echo -e "${GREEN}✅ Project files uploaded${NC}"

# ─── Step 5: Setup Backend (Python deps, env, migrations) ────────────────────
echo -e "${CYAN}[5/7] 🐍 Setting up backend (Python dependencies + database)...${NC}"
ssh_cmd << REMOTE_BACKEND
set -euo pipefail
cd ${REMOTE_APP_DIR}

echo ">>> Creating Python virtual environment..."
python3 -m venv backend/.venv
source backend/.venv/bin/activate

echo ">>> Installing Python dependencies..."
pip install --upgrade pip -q
pip install -r backend/requirements.txt -q

echo ">>> Configuring production environment..."
cd backend
# Update .env for production
sed -i 's/ENVIRONMENT=development/ENVIRONMENT=production/' .env 2>/dev/null || true

echo ">>> Running database migrations..."
python migrate.py up

echo ">>> Backend setup complete!"
deactivate
REMOTE_BACKEND
echo -e "${GREEN}✅ Backend configured${NC}"

# ─── Step 6: Build Frontend & Configure Nginx ────────────────────────────────
echo -e "${CYAN}[6/7] 🎨 Building frontend + configuring Nginx...${NC}"
ssh_cmd << 'REMOTE_FRONTEND'
set -euo pipefail
REMOTE_APP_DIR="/var/www/punemumbaicab"
cd ${REMOTE_APP_DIR}/frontend

echo ">>> Installing npm dependencies..."
npm ci --silent 2>/dev/null || npm install --silent

echo ">>> Updating frontend .env for production..."
sed -i 's|VITE_API_URL=http://localhost:8080|VITE_API_URL=|' .env 2>/dev/null || true
sed -i 's/VITE_APP_ENV=development/VITE_APP_ENV=production/' .env 2>/dev/null || true

echo ">>> Building production frontend bundle..."
npm run build

echo ">>> Copying built frontend to Nginx serve directory..."
sudo rm -rf /var/www/html/punemumbaicab
sudo mkdir -p /var/www/html/punemumbaicab
sudo cp -r dist/* /var/www/html/punemumbaicab/
REMOTE_FRONTEND

# Upload Nginx config
echo "  Configuring Nginx reverse proxy..."
ssh_cmd << 'NGINX_CONFIG'
set -euo pipefail

# Create Nginx site configuration
sudo tee /etc/nginx/sites-available/punemumbaicab > /dev/null << 'NGINX_CONF'
upstream cab_backend {
    server 127.0.0.1:8080;
    keepalive 32;
}

server {
    listen 80;
    listen [::]:80;
    server_name sangitatravelspune.com www.sangitatravelspune.com punemumbaicab.com www.punemumbaicab.com _;

    root /var/www/html/punemumbaicab;
    index index.html;

    # Gzip Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/json image/svg+xml;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # API Reverse Proxy → Python Backend
    location /api/ {
        proxy_pass http://cab_backend;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 10s;
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
    }

    # Static Assets (immutable caching)
    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, max-age=31536000, immutable";
        try_files $uri =404;
    }

    # SPA Fallback — serve index.html for all unknown routes
    location / {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        try_files $uri $uri/ /index.html;
    }

    # Favicon & robots
    location = /favicon.svg { expires 30d; }
    location = /robots.txt { allow all; log_not_found off; access_log off; }
}
NGINX_CONF

# Enable site and remove default
sudo ln -sf /etc/nginx/sites-available/punemumbaicab /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
sudo systemctl enable nginx
NGINX_CONFIG
echo -e "${GREEN}✅ Frontend built & Nginx configured${NC}"

# ─── Step 7: Setup systemd Service & Start Backend ───────────────────────────
echo -e "${CYAN}[7/7] 🚀 Setting up systemd service & starting application...${NC}"
ssh_cmd << 'REMOTE_SERVICE'
set -euo pipefail
REMOTE_APP_DIR="/var/www/punemumbaicab"

# Create systemd service for the Python backend
sudo tee /etc/systemd/system/sangita-cab.service > /dev/null << SYSTEMD_CONF
[Unit]
Description=Sangita Travels Pune — Production API Server
After=network.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=${REMOTE_APP_DIR}/backend
Environment=ENVIRONMENT=production
Environment=PORT=8080
ExecStart=${REMOTE_APP_DIR}/backend/.venv/bin/python ${REMOTE_APP_DIR}/backend/server.py
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=sangita-cab

# Security Sandboxing
ProtectSystem=full
ProtectHome=true
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
SYSTEMD_CONF

# Reload systemd, enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable sangita-cab
sudo systemctl restart sangita-cab

# Wait for backend to start
echo ">>> Waiting for backend to start..."
sleep 3

# Check service status
if sudo systemctl is-active --quiet sangita-cab; then
    echo "✅ Backend service is RUNNING"
else
    echo "❌ Backend service failed to start. Checking logs..."
    sudo journalctl -u sangita-cab --no-pager -n 20
    exit 1
fi

# Health check
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/health 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Health check PASSED (HTTP 200)"
else
    echo "⚠️  Health check returned status: $HTTP_STATUS (backend may still be initializing)"
fi
REMOTE_SERVICE
echo -e "${GREEN}✅ Application service started${NC}"

# ─── Final Summary ───────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          🎉 DEPLOYMENT SUCCESSFUL! 🎉                      ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                            ║"
echo "║  🌐 Website:  http://${EC2_IP}                       "
echo "║  🌐 Domain:   http://${DOMAIN}                "
echo "║  🔧 API:      http://${EC2_IP}/api/health            "
echo "║  🔑 Admin:    http://${EC2_IP}/login.html            "
echo "║                                                            ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  NEXT STEPS:                                               ║"
echo "║  1. Visit http://${EC2_IP} to verify the site  "
echo "║  2. Run SSL setup (see below)                              ║"
echo "║  3. Change default admin password!                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${YELLOW}📌 To enable HTTPS/SSL (recommended), run:${NC}"
echo -e "   ssh -i $PEM_KEY ${EC2_USER}@${EC2_IP}"
echo -e "   sudo certbot --nginx -d ${DOMAIN} -d www.${DOMAIN} --non-interactive --agree-tos --email shitalupadhye287@gmail.com --redirect"
echo ""
echo -e "${YELLOW}📌 Useful commands on the server:${NC}"
echo -e "   ${CYAN}sudo systemctl status sangita-cab${NC}   — Check backend status"
echo -e "   ${CYAN}sudo journalctl -u sangita-cab -f${NC}   — View live backend logs"
echo -e "   ${CYAN}sudo systemctl restart sangita-cab${NC}  — Restart backend"
echo -e "   ${CYAN}sudo systemctl restart nginx${NC}        — Restart Nginx"
echo -e "   ${CYAN}sudo nginx -t${NC}                       — Test Nginx config"
echo ""
