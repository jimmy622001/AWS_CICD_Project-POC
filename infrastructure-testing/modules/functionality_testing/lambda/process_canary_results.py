import json
import boto3
import os
import logging
import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Process CloudWatch Synthetics Canary results.
    """
    # Get environment variables
    code_bucket = os.environ.get('CODE_BUCKET')
    project_name = os.environ.get('PROJECT_NAME')
    environment = os.environ.get('ENVIRONMENT')
    
    # Initialize AWS clients
    synthetics = boto3.client('synthetics')
    cloudwatch = boto3.client('cloudwatch')
    s3 = boto3.client('s3')
    
    try:
        # Extract canary name from event
        if 'detail' not in event or 'canary-name' not in event['detail']:
            logger.error("No canary name found in event")
            return {
                'statusCode': 400,
                'body': 'Invalid event format'
            }
        
        canary_name = event['detail']['canary-name']
        logger.info(f"Processing results for canary: {canary_name}")
        
        # Get canary details
        canary = synthetics.get_canary(
            Name=canary_name
        )
        
        # Get the latest run
        runs = synthetics.get_canary_runs(
            Name=canary_name,
            MaxResults=1
        )
        
        if 'CanaryRuns' not in runs or not runs['CanaryRuns']:
            logger.warning(f"No runs found for canary: {canary_name}")
            return {
                'statusCode': 200,
                'body': 'No canary runs found'
            }
        
        latest_run = runs['CanaryRuns'][0]
        status = latest_run.get('Status', {}).get('State')
        
        # Get metrics for the canary
        end_time = datetime.datetime.now()
        start_time = end_time - datetime.timedelta(hours=1)
        
        success_metric = cloudwatch.get_metric_statistics(
            Namespace="CloudWatchSynthetics",
            MetricName="SuccessPercent",
            Dimensions=[
                {
                    'Name': 'CanaryName',
                    'Value': canary_name
                }
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=60,
            Statistics=['Average']
        )
        
        duration_metric = cloudwatch.get_metric_statistics(
            Namespace="CloudWatchSynthetics",
            MetricName="Duration",
            Dimensions=[
                {
                    'Name': 'CanaryName',
                    'Value': canary_name
                }
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=60,
            Statistics=['Average']
        )
        
        # Extract values from metrics
        success_rate = 0
        if 'Datapoints' in success_metric and success_metric['Datapoints']:
            success_rate = success_metric['Datapoints'][0].get('Average', 0)
        
        duration = 0
        if 'Datapoints' in duration_metric and duration_metric['Datapoints']:
            duration = duration_metric['Datapoints'][0].get('Average', 0)
        
        # Create a results object
        timestamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        result = {
            'canaryName': canary_name,
            'timestamp': timestamp,
            'status': status,
            'successRate': success_rate,
            'duration': duration,
            'runId': latest_run.get('Id'),
            'artifacts': latest_run.get('ArtifactS3Location')
        }
        
        # Store the result in S3
        result_key = f"functionality-results/{project_name}/{environment}/{canary_name}/{timestamp}.json"
        s3.put_object(
            Bucket=code_bucket,
            Key=result_key,
            Body=json.dumps(result, indent=2),
            ContentType='application/json'
        )
        
        logger.info(f"Canary result stored at s3://{code_bucket}/{result_key}")
        
        # If the canary failed, you might want to trigger alerts or other actions
        if status != 'PASSED':
            logger.warning(f"Canary {canary_name} failed with status {status}")
            # Add your alerting logic here
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'canaryName': canary_name,
                'status': status,
                'resultPath': f"s3://{code_bucket}/{result_key}"
            })
        }
    
    except Exception as e:
        logger.error(f"Error processing canary results: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f"Error processing canary results: {str(e)}"
            })
        }