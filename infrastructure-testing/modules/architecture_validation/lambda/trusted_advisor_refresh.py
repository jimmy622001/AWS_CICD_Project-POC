import json
import boto3
import os
import logging
import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Refresh AWS Trusted Advisor checks.
    """
    # Get environment variables
    report_bucket = os.environ.get('REPORT_BUCKET')
    project_name = os.environ.get('PROJECT_NAME')
    environment = os.environ.get('ENVIRONMENT')
    
    # Initialize AWS clients
    support = boto3.client('support')
    s3 = boto3.client('s3')
    
    # Get list of Trusted Advisor check IDs
    try:
        checks_response = support.describe_trusted_advisor_checks(
            language='en'
        )
        
        checks = checks_response.get('checks', [])
        logger.info(f"Found {len(checks)} Trusted Advisor checks")
        
        # Record which checks we're refreshing
        check_info = []
        for check in checks:
            check_info.append({
                'id': check.get('id'),
                'name': check.get('name'),
                'category': check.get('category'),
                'description': check.get('description')
            })
        
        # Store check information
        timestamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        info_key = f"architecture-reports/{project_name}/{environment}/trusted-advisor-checks-{timestamp}.json"
        s3.put_object(
            Bucket=report_bucket,
            Key=info_key,
            Body=json.dumps(check_info, indent=2),
            ContentType='application/json'
        )
        
        # Refresh all checks
        refresh_count = 0
        for check in checks:
            try:
                support.refresh_trusted_advisor_check(
                    checkId=check.get('id')
                )
                refresh_count += 1
            except Exception as e:
                logger.warning(f"Failed to refresh check {check.get('name')}: {str(e)}")
        
        logger.info(f"Successfully refreshed {refresh_count} Trusted Advisor checks")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f"Refreshed {refresh_count} Trusted Advisor checks",
                'checkInfoPath': f"s3://{report_bucket}/{info_key}"
            })
        }
    
    except Exception as e:
        logger.error(f"Error refreshing Trusted Advisor checks: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f"Error refreshing Trusted Advisor checks: {str(e)}"
            })
        }