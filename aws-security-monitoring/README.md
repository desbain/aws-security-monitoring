# AWS Security Monitoring & Automated Threat Response

> **Portfolio Project 2** | George Awa, CISSP | DevSecOps Engineer

A production-grade AWS security monitoring stack built entirely with Terraform.
Deploys GuardDuty, Security Hub, and CloudTrail with EventBridge rules that
trigger Lambda functions to automatically contain threats — isolating compromised
EC2 instances and revoking IAM credentials within 60 seconds of detection.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    DETECTION LAYER                          │
│                                                             │
│  GuardDuty          Security Hub          CloudTrail        │
│  (threat intel)     (compliance)          (API audit)       │
│  S3 · K8s · EC2     CIS · PCI · FSBP     Multi-region      │
│  malware scan       standards             log validation    │
└──────────────────────────┬──────────────────────────────────┘
                           │
                    EventBridge Rules
                           │
         ┌─────────────────┴─────────────────┐
         │                                   │
         ▼                                   ▼
┌─────────────────┐                ┌──────────────────────┐
│  EC2 Threat     │                │  IAM Threat          │
│                 │                │                      │
│ isolate-ec2     │                │ revoke-iam           │
│ Lambda          │                │ Lambda               │
│                 │                │                      │
│ 1. Create       │                │ 1. Attach deny-all   │
│    isolation SG │                │    inline policy     │
│ 2. Replace      │                │ 2. Deactivate all    │
│    instance SGs │                │    access keys       │
│ 3. SNS alert    │                │ 3. SNS alert         │
└─────────────────┘                └──────────────────────┘
         │                                   │
         └─────────────────┬─────────────────┘
                           ▼
                    SNS Topic → Email Alert
                           +
                    CloudWatch Dashboards
                    (VPC Flow Logs · API anomalies)
```

---

## Security Controls Deployed

| Service | What It Does | Standard |
|---------|-------------|---------|
| GuardDuty | Detects threats using ML — port scans, crypto mining, credential abuse, malware | NIST IR-5, PCI 11.5 |
| Security Hub | Aggregates findings, runs CIS/PCI/FSBP compliance checks continuously | CIS Benchmark, PCI-DSS |
| CloudTrail | Logs every API call across all regions with log file validation (tamper detection) | NIST AU-2, PCI Req 10 |
| EventBridge | Routes HIGH/CRITICAL findings to Lambda within seconds | NIST IR-4 |
| Lambda (isolate-ec2) | Automatically isolates compromised EC2 by swapping to a deny-all security group | NIST IR-4 |
| Lambda (revoke-iam) | Attaches deny-all policy and deactivates all access keys for compromised IAM user | NIST IR-4 |
| CloudWatch Alarms | Alerts on root account usage, console sign-in without MFA, IAM policy changes | CIS 3.x |
| SNS | Delivers real-time email alerts with full finding details and remediation steps | — |
| KMS | Encrypts GuardDuty findings and CloudTrail logs at rest | NIST SC-28 |

---

## Project Structure

```
aws-security-monitoring/
├── terraform/
│   ├── main.tf                        # Root — EventBridge, SNS, CloudWatch alarms
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── guardduty/
│       │   └── main.tf                # Detector + S3 findings + KMS
│       ├── security-hub/
│       │   └── main.tf                # CIS + PCI + FSBP standards
│       ├── cloudtrail/
│       │   └── main.tf                # Multi-region trail + CIS metric filters
│       └── lambda-remediation/
│           └── main.tf                # IAM roles + Lambda deploy + permissions
├── lambda/
│   └── functions/
│       ├── isolate-ec2/
│       │   └── handler.py             # EC2 isolation with forensic logging
│       └── revoke-iam/
│           └── handler.py             # IAM credential revocation
├── .github/
│   └── workflows/
│       └── deploy.yml                 # Bandit + Checkov + Terraform apply
├── docs/
│   └── incident-response-runbook.md  # Step-by-step manual response guide
└── README.md
```

---

## Prerequisites

- AWS account with admin permissions
- Tools: `terraform >= 1.5`, `aws-cli`, `python 3.12`
- An email address to receive alerts

---

## Step-by-Step Deployment

### 1. Clone and configure
```bash
git clone https://github.com/YOUR_USERNAME/aws-security-monitoring.git
cd aws-security-monitoring
```

Create `terraform/terraform.tfvars` (never commit this file):
```hcl
alert_email = "your-email@example.com"
environment = "production"
aws_region  = "us-east-1"
```

### 2. Update the S3 backend
In `terraform/main.tf`, replace:
```hcl
bucket = "your-terraform-state-bucket"
```
With your actual S3 bucket name. Create it first:
```bash
aws s3 mb s3://your-terraform-state-bucket --region us-east-1
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled
```

### 3. Deploy
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 4. Confirm SNS subscription
Check your email and click the confirmation link from AWS SNS.

### 5. Test the setup — simulate a GuardDuty finding
```bash
# Generate a sample GuardDuty finding (no real threat)
aws guardduty create-sample-findings \
  --detector-id $(terraform output -raw guardduty_detector_id) \
  --finding-types "UnauthorizedAccess:EC2/SSHBruteForce"
```
You should receive an SNS email alert within 1–2 minutes.

---

## Demonstrating MTTD Improvement

| Metric | Before (manual) | After (automated) |
|--------|----------------|-------------------|
| Threat detection | Hours to days | Real-time (GuardDuty ML) |
| Alert delivery | Manual log review | < 2 minutes (SNS) |
| EC2 containment | Manual (hours) | < 60 seconds (Lambda) |
| IAM revocation | Manual (hours) | < 60 seconds (Lambda) |
| Compliance reporting | Manual spreadsheets | Continuous (Security Hub) |
| Coverage | Business hours only | 24/7, all regions |

---

## GitHub Actions Pipeline

Every pull request runs:
1. **Bandit** — SAST scan on all Lambda Python code
2. **Checkov** — IaC security scan on all Terraform — blocks misconfigurations before deploy
3. **Terraform validate** — syntax and schema validation
4. **Terraform apply** — deploys to AWS on merge to main

---

## Frameworks This Project Addresses

- **NIST 800-53**: IR-4, IR-5, AU-2, AU-9, SC-28
- **PCI-DSS**: Req 10 (logging), Req 11.5 (intrusion detection)
- **CIS AWS Foundations Benchmark**: Controls 3.1–3.14 (CloudTrail alarms)
- **HIPAA**: §164.312(b) — Audit controls

---

## Author

**George Awa, CISSP** | DevSecOps Engineer  
[LinkedIn](https://linkedin.com/in/georgeawa) · [GitHub](https://github.com/desbain)
