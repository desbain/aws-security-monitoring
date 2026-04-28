"""
isolate-ec2/handler.py

Triggered by EventBridge when GuardDuty raises a HIGH/CRITICAL finding
on an EC2 instance. Automatically:
  1. Creates an isolation security group (deny all ingress/egress)
  2. Replaces the instance's security groups with the isolation group
  3. Sends an SNS alert with full finding details
  4. Logs all actions for audit trail
"""

import boto3
import json
import logging
import os
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client("ec2")
sns = boto3.client("sns")

SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
ENVIRONMENT   = os.environ["ENVIRONMENT"]
ISOLATION_SG_NAME = f"{ENVIRONMENT}-ISOLATION-DO-NOT-USE"


def lambda_handler(event, context):
    """
    Entry point. Expects a GuardDuty finding event from EventBridge.
    """
    logger.info("Received event: %s", json.dumps(event, default=str))

    finding  = event.get("detail", {})
    severity = finding.get("severity", 0)
    title    = finding.get("title", "Unknown Finding")
    finding_id = finding.get("id", "unknown")
    account_id = finding.get("accountId", "unknown")
    region     = finding.get("region", "unknown")

    # Extract EC2 instance details from the finding
    resource = finding.get("resource", {})
    instance_details = resource.get("instanceDetails", {})
    instance_id = instance_details.get("instanceId")

    if not instance_id:
        logger.warning("No EC2 instance ID found in finding. Sending alert only.")
        _send_alert(title, finding_id, severity, account_id, region,
                    instance_id=None, action="alert-only")
        return {"status": "alert-sent", "reason": "no-instance-id"}

    logger.info("Isolating EC2 instance: %s (severity: %s)", instance_id, severity)

    try:
        # Step 1: Get or create isolation security group
        vpc_id = instance_details.get("networkInterfaces", [{}])[0].get("vpcId")
        isolation_sg_id = _get_or_create_isolation_sg(vpc_id)

        # Step 2: Replace instance security groups with isolation SG
        _isolate_instance(instance_id, isolation_sg_id)

        # Step 3: Send SNS alert
        _send_alert(title, finding_id, severity, account_id, region,
                    instance_id=instance_id, action="isolated",
                    isolation_sg_id=isolation_sg_id)

        logger.info("Successfully isolated instance %s", instance_id)
        return {
            "status": "isolated",
            "instance_id": instance_id,
            "isolation_sg_id": isolation_sg_id,
            "finding_id": finding_id
        }

    except Exception as e:
        logger.error("Failed to isolate instance %s: %s", instance_id, str(e))
        _send_alert(title, finding_id, severity, account_id, region,
                    instance_id=instance_id, action="isolation-failed",
                    error=str(e))
        raise


def _get_or_create_isolation_sg(vpc_id):
    """
    Returns the ID of the isolation security group, creating it if needed.
    The isolation SG has no ingress or egress rules — complete network deny.
    """
    # Check if it already exists
    try:
        response = ec2.describe_security_groups(
            Filters=[
                {"Name": "group-name", "Values": [ISOLATION_SG_NAME]},
                {"Name": "vpc-id",     "Values": [vpc_id]}
            ]
        )
        if response["SecurityGroups"]:
            sg_id = response["SecurityGroups"][0]["GroupId"]
            logger.info("Using existing isolation SG: %s", sg_id)
            return sg_id
    except Exception:
        pass

    # Create new isolation SG with no rules
    response = ec2.create_security_group(
        GroupName=ISOLATION_SG_NAME,
        Description="AUTOMATED ISOLATION — GuardDuty auto-remediation. Do not modify.",
        VpcId=vpc_id,
        TagSpecifications=[{
            "ResourceType": "security-group",
            "Tags": [
                {"Key": "Name",        "Value": ISOLATION_SG_NAME},
                {"Key": "Purpose",     "Value": "automated-isolation"},
                {"Key": "CreatedBy",   "Value": "guardduty-lambda"},
                {"Key": "Environment", "Value": ENVIRONMENT}
            ]
        }]
    )
    sg_id = response["GroupId"]

    # Remove default egress rule (allow all) to achieve full deny
    ec2.revoke_security_group_egress(
        GroupId=sg_id,
        IpPermissions=[{
            "IpProtocol": "-1",
            "IpRanges": [{"CidrIp": "0.0.0.0/0"}]
        }]
    )

    logger.info("Created isolation SG: %s", sg_id)
    return sg_id


def _isolate_instance(instance_id, isolation_sg_id):
    """
    Replaces all security groups on the instance with the isolation SG only.
    """
    ec2.modify_instance_attribute(
        InstanceId=instance_id,
        Groups=[isolation_sg_id]
    )
    logger.info("Applied isolation SG %s to instance %s", isolation_sg_id, instance_id)


def _send_alert(title, finding_id, severity, account_id, region,
                instance_id, action, isolation_sg_id=None, error=None):
    """
    Publishes a formatted security alert to SNS.
    """
    timestamp = datetime.utcnow().strftime("%Y-%m-%d %Human:%M:%S UTC")

    message_lines = [
        "=" * 60,
        "SECURITY ALERT — GuardDuty Auto-Remediation",
        "=" * 60,
        f"Timestamp:   {timestamp}",
        f"Environment: {ENVIRONMENT}",
        f"Account:     {account_id}",
        f"Region:      {region}",
        f"Finding:     {title}",
        f"Finding ID:  {finding_id}",
        f"Severity:    {severity}",
        f"Action:      {action.upper()}",
    ]

    if instance_id:
        message_lines.append(f"Instance:    {instance_id}")
    if isolation_sg_id:
        message_lines.append(f"Isolation SG: {isolation_sg_id}")
    if error:
        message_lines.append(f"Error:       {error}")

    message_lines += [
        "",
        "Next Steps:",
        "1. Review the GuardDuty finding in AWS Console",
        "2. Verify the isolated instance in EC2",
        "3. Investigate the threat and capture forensic evidence",
        "4. Follow the incident response runbook in /docs/",
        "=" * 60,
    ]

    subject = f"[{ENVIRONMENT.upper()}] GuardDuty Auto-Remediation: {action.upper()} — {title[:50]}"

    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=subject,
        Message="\n".join(message_lines)
    )
    logger.info("SNS alert sent: %s", subject)
