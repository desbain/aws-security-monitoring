#Creating EC2  bastion instance-------------------------------------------------------------
resource "aws_instance" "bastion_host" {
  ami           = var.ami_id
  instance_type = var.instance_type
  iam_instance_profile = var.instance_profile_name # IAM instance profile for the EC2 instance
   key_name      = var.key_name
  subnet_id     = var.public_subnet_ids[0] # Assuming the first public subnet is used for the bastion host
  vpc_security_group_ids = [var.bastion_host_sg] # Security group for the bastion host 
  tags = {
    Name = "${var.project_name}-${var.environment}-bastion-host"
  }
}

#Creating EC2 launch template for portfolio application instances-------------------------------------------------------------

resource "aws_launch_template" "portfolio_launch_template" {
  name          = "${var.project_name}-${var.environment}-portfolio-launch-template"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = var.instance_profile_name
  }

  network_interfaces {
     security_groups = [var.app_sg]
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
exec > /var/log/user-data.log 2>&1

# Update and install
apt-get update -y
apt-get install -y curl nginx

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Create app directory
mkdir -p /app
cd /app

# Download app files from GitHub
curl -o /app/server.js https://raw.githubusercontent.com/desbain/aws-security-monitoring/master/server.js
curl -o /app/index.html https://raw.githubusercontent.com/desbain/aws-security-monitoring/master/index.html

# Create package.json using Python to avoid heredoc issues
python3 -c "
import json
pkg = {
  'name': 'portfolio-api',
  'version': '1.0.0',
  'main': 'server.js',
  'dependencies': {
    'express': '^4.18.2',
    'pg': '^8.11.0',
    'cors': '^2.8.5',
    'dotenv': '^16.0.3'
  }
}
open('/app/package.json', 'w').write(json.dumps(pkg))
"

# Create .env using Python
python3 -c "
env = '''DB_HOST=${var.db_endpoint}
DB_PORT=5432
DB_NAME=portfoliodb
DB_USER=postgres
DB_PASSWORD=${var.db_password}
PORT=3000
'''
open('/app/.env', 'w').write(env)
"

# Install dependencies
cd /app && npm install

# Create systemd service using Python
python3 -c "
svc = '''[Unit]
Description=Portfolio API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/app
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
EnvironmentFile=/app/.env

[Install]
WantedBy=multi-user.target
'''
open('/etc/systemd/system/portfolio.service', 'w').write(svc)
"

# Configure Nginx using Python
python3 -c "
nginx = '''server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
'''
open('/etc/nginx/sites-enabled/default', 'w').write(nginx)
"

# Start services
systemctl daemon-reload
systemctl enable portfolio
systemctl start portfolio
systemctl restart nginx

echo "Setup complete!"
EOF
)
  
  tags = {
    Name = "${var.project_name}-${var.environment}-portfolio-launch-template"
  }
}