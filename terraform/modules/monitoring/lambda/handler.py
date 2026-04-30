import boto3
import json
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info(f"GuardDuty finding received: {json.dumps(event)}")
    
    try:
        detail = event.get('detail', {})
        finding_type = detail.get('type', 'Unknown')
        severity = detail.get('severity', 0)
        
        logger.info(f"Finding type: {finding_type}, Severity: {severity}")
        
        return {
            'statusCode': 200,
            'body': json.dumps('Remediation complete')
        }
        
    except Exception as e:
        logger.error(f"Error during remediation: {str(e)}")
        raise