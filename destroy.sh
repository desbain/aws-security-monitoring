#!/bin/bash

# ============================================================
# AWS Portfolio Infrastructure — Destroy Script
# George Awa — DevSecOps Portfolio
# Region: us-east-2 (Ohio)
# Account: 905418310734
# ============================================================
# Usage: chmod +x destroy.sh && ./destroy.sh
# ============================================================

set -e

REGION="us-east-2"
ACCOUNT_ID="905418310734"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "============================================================"
echo "  AWS Portfolio Infrastructure — Destroy Script"
echo "  Region: $REGION"
echo "============================================================"
echo -e "${NC}"

echo -e "${RED}⚠️  WARNING: This will destroy the following resources:${NC}"
echo "  - Auto Scaling Group"
echo "  - Application Load Balancer + Target Group"
echo "  - EC2 Instances (Bastion + App servers)"
echo "  - RDS PostgreSQL instance"
echo "  - NAT Gateway + Elastic IP (most expensive!)"
echo "  - GuardDuty sample findings"
echo "  - Lambda function"
echo "  - EventBridge rule"
echo "  - SNS Topic + Subscription"
echo ""
read -p "Are you sure you want to destroy? Type 'yes' to confirm: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo -e "${GREEN}Aborted. No resources were destroyed.${NC}"
  exit 0
fi

echo ""
echo -e "${YELLOW}Starting destroy sequence...${NC}"
echo ""

# ============================================================
# 1. DISABLE AUTO SCALING GROUP (set min/desired to 0)
# ============================================================
echo -e "${BLUE}[1/12] Scaling down Auto Scaling Group...${NC}"
ASG_NAME=$(aws autoscaling describe-auto-scaling-groups \
  --region $REGION \
  --query "AutoScalingGroups[*].AutoScalingGroupName" \
  --output text 2>/dev/null | tr '\t' '\n' | grep -i portfolio | head -1)

if [ -n "$ASG_NAME" ]; then
  aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name "$ASG_NAME" \
    --min-size 0 \
    --desired-capacity 0 \
    --region $REGION
  echo -e "${GREEN}  ✅ ASG scaled to 0: $ASG_NAME${NC}"

  echo -e "${BLUE}  Waiting for instances to terminate...${NC}"
  sleep 30

  aws autoscaling delete-auto-scaling-group \
    --auto-scaling-group-name "$ASG_NAME" \
    --force-delete \
    --region $REGION
  echo -e "${GREEN}  ✅ ASG deleted${NC}"
else
  echo -e "${YELLOW}  ⚠️  No portfolio ASG found, skipping${NC}"
fi

# ============================================================
# 2. DELETE APPLICATION LOAD BALANCER
# ============================================================
echo -e "${BLUE}[2/12] Deleting Application Load Balancer...${NC}"
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --region $REGION \
  --query "LoadBalancers[*].LoadBalancerArn" \
  --output text 2>/dev/null | tr '\t' '\n' | head -1)

if [ -n "$ALB_ARN" ]; then
  aws elbv2 delete-load-balancer \
    --load-balancer-arn "$ALB_ARN" \
    --region $REGION
  echo -e "${GREEN}  ✅ ALB deleted${NC}"
  sleep 10
else
  echo -e "${YELLOW}  ⚠️  No ALB found, skipping${NC}"
fi

# ============================================================
# 3. DELETE TARGET GROUP
# ============================================================
echo -e "${BLUE}[3/12] Deleting Target Group...${NC}"
TG_ARN=$(aws elbv2 describe-target-groups \
  --region $REGION \
  --query "TargetGroups[*].TargetGroupArn" \
  --output text 2>/dev/null | tr '\t' '\n' | head -1)

if [ -n "$TG_ARN" ]; then
  aws elbv2 delete-target-group \
    --target-group-arn "$TG_ARN" \
    --region $REGION
  echo -e "${GREEN}  ✅ Target Group deleted${NC}"
else
  echo -e "${YELLOW}  ⚠️  No Target Group found, skipping${NC}"
fi

# ============================================================
# 4. TERMINATE EC2 INSTANCES (Bastion)
# ============================================================
echo -e "${BLUE}[4/12] Terminating EC2 instances...${NC}"
INSTANCE_IDS=$(aws ec2 describe-instances \
  --region $REGION \
  --filters "Name=instance-state-name,Values=running,stopped" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text 2>/dev/null)

if [ -n "$INSTANCE_IDS" ]; then
  aws ec2 terminate-instances \
    --instance-ids $INSTANCE_IDS \
    --region $REGION
  echo -e "${GREEN}  ✅ EC2 instances terminating: $INSTANCE_IDS${NC}"
  echo -e "${BLUE}  Waiting for termination...${NC}"
  aws ec2 wait instance-terminated \
    --instance-ids $INSTANCE_IDS \
    --region $REGION
  echo -e "${GREEN}  ✅ All EC2 instances terminated${NC}"
else
  echo -e "${YELLOW}  ⚠️  No running EC2 instances found, skipping${NC}"
fi

# ============================================================
# 5. DELETE RDS INSTANCE
# ============================================================
echo -e "${BLUE}[5/12] Deleting RDS PostgreSQL instance...${NC}"
RDS_ID=$(aws rds describe-db-instances \
  --region $REGION \
  --query "DBInstances[*].DBInstanceIdentifier" \
  --output text 2>/dev/null | tr '\t' '\n' | head -1)

if [ -n "$RDS_ID" ]; then
  aws rds delete-db-instance \
    --db-instance-identifier "$RDS_ID" \
    --skip-final-snapshot \
    --delete-automated-backups \
    --region $REGION
  echo -e "${GREEN}  ✅ RDS deletion initiated: $RDS_ID (takes ~5 min)${NC}"
else
  echo -e "${YELLOW}  ⚠️  No RDS instance found, skipping${NC}"
fi

# ============================================================
# 6. DELETE NAT GATEWAY (most expensive resource!)
# ============================================================
echo -e "${BLUE}[6/12] Deleting NAT Gateway...${NC}"
NAT_IDS=$(aws ec2 describe-nat-gateways \
  --region $REGION \
  --filter "Name=state,Values=available" \
  --query "NatGateways[*].NatGatewayId" \
  --output text 2>/dev/null)

if [ -n "$NAT_IDS" ]; then
  for NAT_ID in $NAT_IDS; do
    aws ec2 delete-nat-gateway \
      --nat-gateway-id "$NAT_ID" \
      --region $REGION
    echo -e "${GREEN}  ✅ NAT Gateway deleted: $NAT_ID${NC}"
  done
  echo -e "${BLUE}  Waiting for NAT Gateway to fully delete...${NC}"
  sleep 60
else
  echo -e "${YELLOW}  ⚠️  No NAT Gateway found, skipping${NC}"
fi

# ============================================================
# 7. RELEASE ELASTIC IPs
# ============================================================
echo -e "${BLUE}[7/12] Releasing Elastic IPs...${NC}"
ALLOC_IDS=$(aws ec2 describe-addresses \
  --region $REGION \
  --query "Addresses[?AssociationId==null].AllocationId" \
  --output text 2>/dev/null)

if [ -n "$ALLOC_IDS" ]; then
  for ALLOC_ID in $ALLOC_IDS; do
    aws ec2 release-address \
      --allocation-id "$ALLOC_ID" \
      --region $REGION
    echo -e "${GREEN}  ✅ Elastic IP released: $ALLOC_ID${NC}"
  done
else
  echo -e "${YELLOW}  ⚠️  No unassociated Elastic IPs found, skipping${NC}"
fi

# ============================================================
# 8. DELETE LAMBDA FUNCTION
# ============================================================
echo -e "${BLUE}[8/12] Deleting Lambda function...${NC}"
aws lambda delete-function \
  --function-name "guardduty-isolate-ec2" \
  --region $REGION 2>/dev/null \
  && echo -e "${GREEN}  ✅ Lambda deleted: guardduty-isolate-ec2${NC}" \
  || echo -e "${YELLOW}  ⚠️  Lambda not found, skipping${NC}"

# ============================================================
# 9. DELETE EVENTBRIDGE RULE
# ============================================================
echo -e "${BLUE}[9/12] Deleting EventBridge rule...${NC}"

# Remove targets first
aws events remove-targets \
  --rule "guardduty-findings-rule" \
  --ids "1" "2" \
  --region $REGION 2>/dev/null || true

aws events delete-rule \
  --name "guardduty-findings-rule" \
  --region $REGION 2>/dev/null \
  && echo -e "${GREEN}  ✅ EventBridge rule deleted${NC}" \
  || echo -e "${YELLOW}  ⚠️  EventBridge rule not found, skipping${NC}"

# ============================================================
# 10. DELETE SNS TOPIC
# ============================================================
echo -e "${BLUE}[10/12] Deleting SNS topic...${NC}"
SNS_ARN="arn:aws:sns:$REGION:$ACCOUNT_ID:portfolio-security-alerts"
aws sns delete-topic \
  --topic-arn "$SNS_ARN" \
  --region $REGION 2>/dev/null \
  && echo -e "${GREEN}  ✅ SNS topic deleted${NC}" \
  || echo -e "${YELLOW}  ⚠️  SNS topic not found, skipping${NC}"

# ============================================================
# 11. DISABLE GUARDDUTY (optional — saves ~$3/month)
# ============================================================
echo ""
read -p "Disable GuardDuty? (saves ~\$3/month) [y/N]: " DISABLE_GD

if [ "$DISABLE_GD" = "y" ] || [ "$DISABLE_GD" = "Y" ]; then
  DETECTOR_ID=$(aws guardduty list-detectors \
    --region $REGION \
    --query "DetectorIds[0]" \
    --output text 2>/dev/null)

  if [ -n "$DETECTOR_ID" ] && [ "$DETECTOR_ID" != "None" ]; then
    aws guardduty delete-detector \
      --detector-id "$DETECTOR_ID" \
      --region $REGION
    echo -e "${GREEN}  ✅ GuardDuty disabled${NC}"
  fi
else
  echo -e "${YELLOW}  ⚠️  GuardDuty left enabled${NC}"
fi

# ============================================================
# 12. DELETE SECRETS MANAGER SECRET
# ============================================================
echo -e "${BLUE}[12/12] Deleting Secrets Manager secret...${NC}"
SECRET_NAME=$(aws secretsmanager list-secrets \
  --region $REGION \
  --query "SecretList[*].Name" \
  --output text 2>/dev/null | tr '\t' '\n' | grep -i portfolio | head -1)

if [ -n "$SECRET_NAME" ]; then
  aws secretsmanager delete-secret \
    --secret-id "$SECRET_NAME" \
    --force-delete-without-recovery \
    --region $REGION
  echo -e "${GREEN}  ✅ Secret deleted: $SECRET_NAME${NC}"
else
  echo -e "${YELLOW}  ⚠️  No portfolio secret found, skipping${NC}"
fi

# ============================================================
# SUMMARY
# ============================================================
echo ""
echo -e "${GREEN}"
echo "============================================================"
echo "  ✅ Destroy sequence complete!"
echo "============================================================"
echo -e "${NC}"
echo "Resources destroyed:"
echo "  ✅ Auto Scaling Group"
echo "  ✅ Application Load Balancer + Target Group"
echo "  ✅ EC2 Instances"
echo "  ✅ RDS PostgreSQL (deletion in progress ~5 min)"
echo "  ✅ NAT Gateway (billing stops within the hour)"
echo "  ✅ Elastic IPs released"
echo "  ✅ Lambda function"
echo "  ✅ EventBridge rule"
echo "  ✅ SNS topic"
echo ""
echo "Still running (low/no cost):"
echo "  - VPC + Subnets + Route Tables (free)"
echo "  - Security Groups (free)"
echo "  - IAM Roles (free)"
echo "  - Route53 hosted zone (~\$0.50/month)"
echo "  - ACM Certificate (free)"
echo ""
echo -e "${BLUE}Ready to rebuild with Terraform! 🚀${NC}"
echo "Sleep well, George. Resume with Step 17 when ready."
echo ""
