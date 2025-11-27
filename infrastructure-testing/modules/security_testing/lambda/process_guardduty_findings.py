import json
import boto3
import os
import logging
import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Process GuardDuty findings when new findings are detected.
    Generates a summary report and stores it in S3.
    """
    logger.info(f"Processing GuardDuty findings: {json.dumps(event)}")
    
    # Get environment variables
    report_bucket = os.environ.get('REPORT_BUCKET')
    notification_email = os.environ.get('NOTIFICATION_EMAIL')
    project_name = os.environ.get('PROJECT_NAME')
    environment = os.environ.get('ENVIRONMENT')
    
    # Initialize AWS clients
    guardduty = boto3.client('guardduty')
    s3 = boto3.client('s3')
    ses = boto3.client('ses')
    
    try:
        # Extract finding details from the event
        if 'detail' not in event:
            logger.error("No details in event")
            return {
                'statusCode': 400,
                'body': 'Invalid event format'
            }
        
        finding_details = event['detail']
        finding_id = finding_details.get('id', 'unknown')
        finding_type = finding_details.get('type', 'unknown')
        severity = finding_details.get('severity', 0)
        detector_id = finding_details.get('detectorId', 'unknown')
        
        # Convert severity from a float to a category
        severity_category = 'INFORMATIONAL'
        if severity >= 7.0:
            severity_category = 'HIGH'
        elif severity >= 4.0:
            severity_category = 'MEDIUM'
        elif severity >= 1.0:
            severity_category = 'LOW'
        
        # Create report
        timestamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        report = {
            'findingId': finding_id,
            'timestamp': timestamp,
            'project': project_name,
            'environment': environment,
            'severity': severity,
            'severityCategory': severity_category,
            'findingType': finding_type,
            'description': finding_details.get('description', ''),
            'detectorId': detector_id,
            'region': finding_details.get('region', ''),
            'service': finding_details.get('service', {}),
            'resource': finding_details.get('resource', {})
        }
        
        # Store report in S3
        report_key = f"security-reports/{project_name}/{environment}/guardduty-{timestamp}.json"
        s3.put_object(
            Bucket=report_bucket,
            Key=report_key,
            Body=json.dumps(report, indent=2),
            ContentType='application/json'
        )
        
        logger.info(f"GuardDuty report stored at s3://{report_bucket}/{report_key}")
        
        # Send email notification for high or medium severity findings
        if severity_category in ['HIGH', 'MEDIUM']:
            try:
                email_body = f"""
                Security Alert - GuardDuty Finding
                
                Project: {project_name}
                Environment: {environment}
                Finding ID: {finding_id}
                Type: {finding_type}
                Severity: {severity_category} ({severity})
                
                Description: {finding_details.get('description', '')}
                
                Region: {finding_details.get('region', '')}
                
                Resource Type: {finding_details.get('resource', {}).get('resourceType', '')}
                
                The complete finding details are available at:
                s3://{report_bucket}/{report_key}
                
                Please investigate this security issue immediately.
                """
                
                ses.send_email(
                    Source=notification_email,  # You should verify this email in SES
                    Destination={
                        'ToAddresses': [notification_email]
                    },
                    Message={
                        'Subject': {
                            'Data': f"SECURITY ALERT - {severity_category} GuardDuty Finding in {environment}"
                        },
                        'Body': {
                            'Text': {
                                'Data': email_body
                            }
                        }
                    }
                )
            except Exception as e:
                logger.error(f"Error sending email notification: {str(e)}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'reportPath': f"s3://{report_bucket}/{report_key}",
                'findingId': finding_id,
                'severity': severity_category
            })
        }
    
    except Exception as e:
        logger.error(f"Error processing GuardDuty finding: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f"Error processing GuardDuty finding: {str(e)}"
            })
        }