import json
import os
import boto3
import logging
import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Process AWS Inspector findings when an assessment run completes.
    Generates a summary report and stores it in S3.
    """
    logger.info(f"Processing Inspector findings: {json.dumps(event)}")
    
    # Get environment variables
    report_bucket = os.environ.get('REPORT_BUCKET')
    notification_email = os.environ.get('NOTIFICATION_EMAIL')
    project_name = os.environ.get('PROJECT_NAME')
    environment = os.environ.get('ENVIRONMENT')
    
    # Initialize AWS clients
    inspector = boto3.client('inspector')
    s3 = boto3.client('s3')
    ses = boto3.client('ses')
    
    # Extract assessment run ARN from the event
    try:
        assessment_run_arn = event['detail']['run-arn']
    except KeyError:
        logger.error("Could not extract assessment run ARN from event")
        return {
            'statusCode': 400,
            'body': 'Invalid event format'
        }
    
    # Get findings for this assessment run
    try:
        findings_response = inspector.list_findings(
            assessmentRunArns=[assessment_run_arn],
            maxResults=100
        )
        finding_arns = findings_response.get('findingArns', [])
        
        # If there are findings, get their details
        findings_details = []
        if finding_arns:
            details_response = inspector.describe_findings(
                findingArns=finding_arns
            )
            findings_details = details_response.get('findings', [])
    except Exception as e:
        logger.error(f"Error retrieving Inspector findings: {str(e)}")
        return {
            'statusCode': 500,
            'body': f'Error retrieving findings: {str(e)}'
        }
    
    # Generate report
    timestamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    report = {
        'assessmentRunArn': assessment_run_arn,
        'timestamp': timestamp,
        'project': project_name,
        'environment': environment,
        'findingsCount': len(finding_arns),
        'findings': []
    }
    
    # Process findings by severity
    severity_counts = {
        'High': 0,
        'Medium': 0,
        'Low': 0,
        'Informational': 0
    }
    
    for finding in findings_details:
        severity = finding.get('severity', 'Unknown')
        if severity in severity_counts:
            severity_counts[severity] += 1
        
        report['findings'].append({
            'arn': finding.get('arn'),
            'title': finding.get('title'),
            'description': finding.get('description'),
            'severity': severity,
            'recommendedActions': finding.get('recommendation', {}).get('text', '')
        })
    
    report['severitySummary'] = severity_counts
    
    # Store report in S3
    report_key = f"security-reports/{project_name}/{environment}/inspector-{timestamp}.json"
    try:
        s3.put_object(
            Bucket=report_bucket,
            Key=report_key,
            Body=json.dumps(report, indent=2),
            ContentType='application/json'
        )
        logger.info(f"Inspector report stored at s3://{report_bucket}/{report_key}")
    except Exception as e:
        logger.error(f"Error storing report in S3: {str(e)}")
    
    # Send email notification if there are high or medium severity findings
    if severity_counts['High'] > 0 or severity_counts['Medium'] > 0:
        try:
            email_body = f"""
            Security Testing Report - {project_name} ({environment})
            
            Assessment completed at: {timestamp}
            
            Finding Summary:
            - High: {severity_counts['High']}
            - Medium: {severity_counts['Medium']}
            - Low: {severity_counts['Low']}
            - Informational: {severity_counts['Informational']}
            
            The complete report is available at:
            s3://{report_bucket}/{report_key}
            
            Please review the findings and take appropriate action.
            """
            
            ses.send_email(
                Source=notification_email,  # You should verify this email in SES
                Destination={
                    'ToAddresses': [notification_email]
                },
                Message={
                    'Subject': {
                        'Data': f"Security Testing Report - {severity_counts['High']} High, {severity_counts['Medium']} Medium Findings"
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
            'findingCounts': severity_counts
        })
    }