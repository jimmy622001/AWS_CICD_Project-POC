import json
import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Send notifications when a new report is available.
    This Lambda is triggered by S3 events when a report is created.
    """
    # Get environment variables
    sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
    project_name = os.environ.get('PROJECT_NAME')
    environment = os.environ.get('ENVIRONMENT')
    
    # Initialize AWS clients
    sns = boto3.client('sns')
    s3 = boto3.client('s3')
    
    try:
        # Process S3 event
        if 'Records' not in event:
            logger.error("No Records in event")
            return {
                'statusCode': 400,
                'body': 'No Records in event'
            }
        
        for record in event['Records']:
            if record['eventSource'] != 'aws:s3':
                continue
                
            # Get bucket and key
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            
            logger.info(f"New report detected: s3://{bucket}/{key}")
            
            # Extract report type and date from key
            report_parts = key.split('/')
            if len(report_parts) < 4:
                continue
            
            report_filename = report_parts[-1]
            report_type = "unknown"
            
            if "daily" in report_filename:
                report_type = "daily"
            elif "weekly" in report_filename:
                report_type = "weekly"
            elif "monthly" in report_filename:
                report_type = "monthly"
            
            # Get file metadata
            try:
                response = s3.head_object(Bucket=bucket, Key=key)
                file_size = response.get('ContentLength', 0)
                last_modified = response.get('LastModified', '').strftime('%Y-%m-%d %H:%M:%S') if response.get('LastModified') else "Unknown"
            except Exception as e:
                logger.warning(f"Error getting S3 object metadata: {str(e)}")
                file_size = 0
                last_modified = "Unknown"
            
            # Prepare notification message
            message = f"""
            New {report_type.capitalize()} Report Available
            
            Project: {project_name}
            Environment: {environment}
            Report Location: s3://{bucket}/{key}
            Generated: {last_modified}
            File Size: {file_size / 1024:.1f} KB
            
            You can access this report through the AWS Console or by using the AWS CLI:
            aws s3 cp s3://{bucket}/{key} ./report.pdf
            """
            
            # Send SNS notification
            try:
                sns.publish(
                    TopicArn=sns_topic_arn,
                    Subject=f"New {report_type.capitalize()} Report - {project_name} ({environment})",
                    Message=message
                )
                logger.info(f"Notification sent for report: {key}")
            except Exception as e:
                logger.error(f"Error sending SNS notification: {str(e)}")
        
        return {
            'statusCode': 200,
            'body': 'Notification(s) sent successfully'
        }
    
    except Exception as e:
        logger.error(f"Error processing event: {str(e)}")
        return {
            'statusCode': 500,
            'body': f'Error processing event: {str(e)}'
        }