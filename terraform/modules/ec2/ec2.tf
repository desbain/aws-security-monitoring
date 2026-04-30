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
    security_groups = [var.bastion_host_sg]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Update system
    apt-get update -y
    apt-get install -y nodejs npm nginx awscli python3

    # Get RDS endpoint
    DB_HOST="${var.db_endpoint}"
    DB_NAME="portfoliodb"
    DB_USER="postgres"
    DB_PASSWORD="${var.db_password}"

    # Create app directory
    mkdir -p /app
    cd /app

    # Create server.js
    cat > /app/server.js << 'SERVEREOF'
${file("${path.module}/../../server.js")}
    SERVEREOF

    # Create package.json
    cat > /app/package.json << 'PKGEOF'
    {
      "name": "portfolio-api",
      "version": "1.0.0",
      "main": "server.js",
      "dependencies": {
        "express": "^4.18.2",
        "pg": "^8.11.0",
        "cors": "^2.8.5",
        "dotenv": "^16.0.3"
      }
    }
    PKGEOF

    # Create .env file
    cat > /app/.env << ENVEOF
DB_HOST=$DB_HOST
DB_PORT=5432
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
PORT=3000
    ENVEOF

    # Install dependencies
    cd /app && npm install

    # Create systemd service
    cat > /etc/systemd/system/portfolio.service << 'SVCEOF'
[Unit]
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
    SVCEOF

    # Configure Nginx
    cat > /etc/nginx/sites-enabled/default << 'NGINXEOF'
server {
    listen 80;
    server_name _;

    location /health {
        proxy_pass http://localhost:3000/health;
    }

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
    NGINXEOF

    # Start services
    systemctl daemon-reload
    systemctl enable portfolio
    systemctl start portfolio
    systemctl restart nginx
  EOF
  )

  tags = {
    Name = "${var.project_name}-${var.environment}-portfolio-launch-template"
  }
}