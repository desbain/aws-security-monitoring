# Incident Response Runbook
## AWS Security Monitoring — GuardDuty Auto-Remediation

---

## Overview

This runbook documents the automated and manual response procedures for
security findings detected by GuardDuty, Security Hub, and CloudTrail.

---

## Automated Response Flow

```
GuardDuty Finding (severity >= 7)
          │
          ▼
    EventBridge Rule
          │
          ├── EC2 Threat ──► isolate-ec2 Lambda
          │                      ├── Creates isolation SG (deny all)
          │                      ├── Replaces instance SGs
          │                      └── Sends SNS alert
          │
          └── IAM Threat ──► revoke-iam Lambda
                                 ├── Attaches deny-all inline policy
                                 ├── Deactivates all access keys
                                 └── Sends SNS alert
```

---

## Severity Reference

| GuardDuty Score | Severity | Automated Response |
|-----------------|----------|--------------------|
| 7.0 – 8.9       | HIGH     | Yes — Lambda triggered |
| 9.0 – 10.0      | CRITICAL | Yes — Lambda triggered |
| 4.0 – 6.9       | MEDIUM   | SNS alert only |
| 1.0 – 3.9       | LOW      | Logged only |

---

## EC2 Isolation — Manual Steps After Auto-Remediation

When you receive an SNS alert for an isolated EC2 instance:

### Step 1 — Confirm isolation
```bash
# Verify the isolation SG is applied
aws ec2 describe-instances \
  --instance-ids <INSTANCE_ID> \
  --query 'Reservations[].Instances[].SecurityGroups'

# Confirm no ingress/egress on isolation SG
aws ec2 describe-security-groups \
  --group-ids <ISOLATION_SG_ID>
```

### Step 2 — Capture forensic evidence (before termination)
```bash
# Create a snapshot of the EBS volume for forensics
aws ec2 create-snapshot \
  --volume-id <VOLUME_ID> \
  --description "FORENSIC-SNAPSHOT-$(date +%Y%m%d)"

# Pull memory dump if SSM agent is running
aws ssm send-command \
  --instance-ids <INSTANCE_ID> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["sudo dd if=/dev/mem of=/tmp/memdump.raw bs=1M count=512"]'
```

### Step 3 — Review GuardDuty finding
```bash
# Get finding details
aws guardduty get-findings \
  --detector-id <DETECTOR_ID> \
  --finding-ids <FINDING_ID>
```

### Step 4 — Review CloudTrail for malicious activity
```bash
# Look for API calls from the compromised instance in the last 24h
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=<INSTANCE_ID> \
  --start-time $(date -d '24 hours ago' --utc +%Y-%m-%dT%H:%M:%SZ)
```

### Step 5 — Terminate and restore
```bash
# After forensics, terminate the instance
aws ec2 terminate-instances --instance-ids <INSTANCE_ID>

# Launch a clean replacement from your Terraform/AMI pipeline
```

---

## IAM Credential Compromise — Manual Steps After Auto-Remediation

When you receive an SNS alert for a revoked IAM identity:

### Step 1 — Confirm deny policy is applied
```bash
aws iam list-user-policies --user-name <USERNAME>
aws iam get-user-policy --user-name <USERNAME> --policy-name <EMERGENCY_POLICY_NAME>
```

### Step 2 — Review all API calls made with compromised key
```bash
# Search CloudTrail for the access key (last 7 days)
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=<USERNAME> \
  --start-time $(date -d '7 days ago' --utc +%Y-%m-%dT%H:%M:%SZ) \
  --query 'Events[].{Time:EventTime,Event:EventName,Source:EventSource}'
```

### Step 3 — Check for unauthorized resources
```bash
# Check for new IAM users/roles created
aws iam list-users --query 'Users[?CreateDate>=`<DATE>`]'

# Check for new EC2 instances across regions
for region in us-east-1 us-west-2 eu-west-1; do
  echo "=== $region ==="
  aws ec2 describe-instances --region $region \
    --query 'Reservations[].Instances[?LaunchTime>=`<DATE>`].[InstanceId,LaunchTime]'
done

# Check S3 for exfiltration
aws s3api list-buckets
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=GetObject
```

### Step 4 — Rotate credentials and restore access
```bash
# Remove the deny policy once investigation is complete
aws iam delete-user-policy --user-name <USERNAME> --policy-name <EMERGENCY_POLICY_NAME>

# Create new access key for the user
aws iam create-access-key --user-name <USERNAME>

# Ensure MFA is enforced
aws iam enable-mfa-device --user-name <USERNAME> \
  --serial-number <MFA_SERIAL> \
  --authentication-code1 <CODE1> \
  --authentication-code2 <CODE2>
```

---

## MTTD Tracking (Mean Time to Detect)

Track these metrics before and after deployment to demonstrate impact:

| Metric | Before | After |
|--------|--------|-------|
| Time from threat to alert | Manual review (hours/days) | < 5 minutes (EventBridge) |
| Time from alert to containment | Manual (hours) | < 60 seconds (Lambda) |
| Coverage | Manual log review | 24/7 automated, all regions |
| False positive rate | N/A | Track in Security Hub |

Record these in your portfolio case study to show quantifiable impact.

---

## Frameworks Addressed

| Control | Framework | Implementation |
|---------|-----------|----------------|
| IR-4: Incident Handling | NIST 800-53 | EventBridge + Lambda auto-remediation |
| IR-5: Incident Monitoring | NIST 800-53 | GuardDuty + Security Hub |
| AU-2: Audit Events | NIST 800-53 | CloudTrail multi-region |
| AU-9: Protection of Audit Info | NIST 800-53 | S3 SSE-KMS + bucket policy |
| Req 10: Track and monitor access | PCI-DSS | CloudTrail + CloudWatch |
| Req 11.5: Intrusion detection | PCI-DSS | GuardDuty |
| CIS 3.x: Logging | CIS Benchmark | CloudTrail metric filters + alarms |
