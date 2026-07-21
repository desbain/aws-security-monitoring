# aws-security-monitoring
cat > ~/Downloads/aws-security-monitoring/README.md << 'EOF'
# AWS DevSecOps Portfolio Project
> **George Awa** | DevSecOps Engineer



A production-grade, cloud-native web application built entirely on AWS,
demonstrating end-to-end DevSecOps skills including infrastructure design,
security automation, incident response, and Infrastructure as Code.

---

## Architecture
Internet → Route53 → ACM (HTTPS) → ALB → Auto Scaling Group (EC2)
│
Node.js API + Nginx
│
RDS PostgreSQL 16
(private subnet)
---

## What Was Built

### Networking
- Custom VPC (10.0.0.0/16)
- 2 Public + 2 Private subnets (multi-AZ us-east-2a/2b)
- Internet Gateway + NAT Gateway
- Route Tables (public → IGW, private → NAT)

### Compute
- EC2 Bastion Host (public subnet)
- Launch Template (auto-configure instances)
- Auto Scaling Group (min:1, desired:2, max:4)
- Node.js API with 5 endpoints
- Nginx reverse proxy
- systemctl services (auto-restart on boot)

### Database
- RDS PostgreSQL 16 (private subnet)
- DB Subnet Group
- Secrets Manager (credentials)
- Live contact form → saves to PostgreSQL
- Live visitor counter

### Load Balancing & DNS
- Application Load Balancer
- Target Group with health checks
- Route53 → desbain.com → ALB
- ACM Certificate (HTTPS/TLS)
- HTTP → HTTPS redirect (301)

### Security
- IAM Roles (EC2, RDS monitoring, Lambda)
- Security Groups (ALB, Bastion, RDS)
- GuardDuty (threat detection, all protection plans)
- EventBridge (routes GuardDuty findings)
- SNS (email alerts)
- Lambda auto-remediation (isolates compromised EC2s)
- CloudWatch logging

### Security Pipeline
Threat detected by GuardDuty
│
▼
EventBridge (guardduty-findings-rule)
│
├──▶ SNS → email alert
└──▶ Lambda → auto-remediation
└── Isolate EC2 (replace SG with DENY-ALL)
---

## Infrastructure as Code (Terraform)

All infrastructure is codified using Terraform with a modular structure:
---

## Infrastructure as Code (Terraform)

All infrastructure is codified using Terraform with a modular structure:
### Remote State
Terraform state is stored in S3 for team collaboration:
```hcl
backend "s3" {
  bucket  = "portfolio-terraform-state-905418310734"
  key     = "dev/terraform.tfstate"
  region  = "us-east-2"
  encrypt = true
}
```

---

## CI/CD Pipeline (GitHub Actions)
Pull Request → terraform plan  (preview changes)
Merge to master → terraform apply (deploy to AWS)
Manual trigger → terraform destroy (teardown)
### Pipeline Features
- AWS credentials stored as GitHub Secrets
- tfvars generated securely at runtime
- terraform fmt + validate on every PR
- Auto-deploy on merge to master
- Manual destroy with dropdown selection

---

## AWS Services Used
VPC · EC2 · RDS · ALB · ASG · Route53 · ACM
IAM · Secrets Manager · GuardDuty · EventBridge
SNS · Lambda · CloudWatch · S3 · Nginx · Node.js
---

## Security Metrics

| Metric | Result |
|--------|--------|
| Threat Detection | Real-time (GuardDuty ML) |
| Alert Delivery | < 2 minutes (SNS) |
| EC2 Containment | < 60 seconds (Lambda) |
| Coverage | 24/7, all regions |
| IaC Coverage | 100% (Terraform) |
| HTTPS | ✅ TLS 1.2+ |
| Encryption at rest | ✅ RDS encrypted |

---

## Deployment

```bash
# Clone repo
git clone https://github.com/desbain/aws-security-monitoring.git
cd aws-security-monitoring/terraform

# Configure AWS CLI
aws configure

# Deploy
terraform init
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

---

## Author

**George Awa** | DevSecOps Engineer
[GitHub](https://github.com/desbain) · [Live Site](https://desbain.com)
EOF
