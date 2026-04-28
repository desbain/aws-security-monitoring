"""
revoke-iam/handler.py

Triggered by EventBridge when GuardDuty raises an IAM credential
compromise finding. Automatically:
  1. Identifies the affected IAM user or role
  2. Attaches a deny-all policy to block all actions immediately
  3. Deactivates all active access keys for the identity
  4. Sends an SNS alert with full details
"""

import boto3
import json
import logging
import os
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

iam = boto3.client("iam")
sns = boto3.client("sns")

SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
ENVIRONMENT   = os.environ["ENVIRONMENT"]

# Inline deny-all policy to attach immediately
DENY_ALL_POLICY = json.dumps({
    "Version": "2012-10-17",
    "Statement": [{
        "Effect":   "Deny",
        "Action":   "*",
        "Resource": "*"
    }]
})


def lambda_handler(event, context):
    """
    Entry point. Expects a GuardDuty finding event from EventBridge.
    """
    logger.info("Received event: %s", json.dumps(event, default=str))

    finding    = event.get("detail", {})
    severity   = finding.get("severity", 0)
    title      = finding.get("title", "Unknown Finding")
    finding_id = finding.get("id", "unknown")
    account_id = finding.get("accountId", "unknown")
    region     = finding.get("region", "unknown")

    # Extract IAM identity from finding
    resource = finding.get("resource", {})
    access_key_details = resource.get("accessKeyDetails", {})
    user_name  = access_key_details.get("userName")
    user_type  = access_key_details.get("userType", "IAMUser")
    access_key = access_key_details.get("accessKeyId")

    if not user_name:
        logger.warning("No IAM user found in finding. Sending alert only.")
        _send_alert(title, finding_id, severity, account_id, region,
                    user_name=None, action="alert-only")
        return {"status": "alert-sent", "reason": "no-user"}

    logger.info("Revoking IAM credentials for: %s (type: %s)", user_name, user_type)

    actions_taken = []

    try:
        # Step 1: Attach deny-all inline policy
        _attach_deny_policy(user_name, user_type)
        actions_taken.append("deny-all-policy-attached")

        # Step 2: Deactivate all access keys
        deactivated_keys = _deactivate_access_keys(user_name)
        if deactivated_keys:
            actions_taken.append(f"deactivated-keys: {', '.join(deactivated_keys)}")

        # Step 3: Send SNS alert
        _send_alert(title, finding_id, severity, account_id, region,
                    user_name=user_name, access_key=access_key,
                    action="credentials-revoked",
                    actions_taken=actions_taken)

        logger.info("Successfully revoked credentials for %s", user_name)
        return {
            "status": "revoked",
            "user_name": user_name,
            "actions_taken": actions_taken,
            "finding_id": finding_id
        }

    except Exception as e:
        logger.error("Failed to revoke credentials for %s: %s", user_name, str(e))
        _send_alert(title, finding_id, severity, account_id, region,
                    user_name=user_name, action="revocation-failed", error=str(e))
        raise


def _attach_deny_policy(user_name, user_type):
    """
    Attaches an inline deny-all policy to the IAM user or role.
    This immediately blocks all API calls by this identity.
    """
    policy_name = f"EMERGENCY-DENY-ALL-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}"

    if user_type in ("IAMUser", "User"):
        iam.put_user_policy(
            UserName=user_name,
            PolicyName=policy_name,
            PolicyDocument=DENY_ALL_POLICY
        )
        logger.info("Attached deny-all policy to user: %s", user_name)
    else:
        iam.put_role_policy(
            RoleName=user_name,
            PolicyName=policy_name,
            PolicyDocument=DENY_ALL_POLICY
        )
        logger.info("Attached deny-all policy to role: %s", user_name)


def _deactivate_access_keys(user_name):
    """
    Lists and deactivates all active access keys for the IAM user.
    Returns list of deactivated key IDs.
    """
    deactivated = []
    try:
        response = iam.list_access_keys(UserName=user_name)
        for key in response.get("AccessKeyMetadata", []):
            if key["Status"] == "Active":
                iam.update_access_key(
                    UserName=user_name,
                    AccessKeyId=key["AccessKeyId"],
                    Status="Inactive"
                )
                deactivated.append(key["AccessKeyId"])
                logger.info("Deactivated key: %s", key["AccessKeyId"])
    except Exception as e:
        logger.warning("Could not deactivate access keys for %s: %s", user_name, e)

    return deactivated


def _send_alert(title, finding_id, severity, account_id, region,
                user_name, action, access_key=None,
                actions_taken=None, error=None):
    """
    Publishes a formatted security alert to SNS.
    """
    timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")

    message_lines = [
        "=" * 60,
        "SECURITY ALERT — IAM Credential Revocation",
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

    if user_name:
        message_lines.append(f"IAM User:    {user_name}")
    if access_key:
        message_lines.append(f"Access Key:  {access_key}")
    if actions_taken:
        message_lines.append(f"Steps Taken: {'; '.join(actions_taken)}")
    if error:
        message_lines.append(f"Error:       {error}")

    message_lines += [
        "",
        "Next Steps:",
        "1. Confirm the user is aware and change credentials",
        "2. Review CloudTrail for actions taken with compromised key",
        "3. Check for unauthorized resources created in all regions",
        "4. Follow the incident response runbook in /docs/",
        "=" * 60,
    ]

    subject = f"[{ENVIRONMENT.upper()}] IAM Credential Revocation: {user_name or 'Unknown'} — {action.upper()}"

    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=subject,
        Message="\n".join(message_lines)
    )
    logger.info("SNS alert sent: %s", subject)
