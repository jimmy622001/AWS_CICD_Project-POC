import json
import os
import boto3
import logging
import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Main orchestrator function for the testing framework.
    Coordinates the execution of different testing components.
    """
    logger.info(f"Starting test orchestration for environment: {os.environ.get('ENVIRONMENT', 'unknown')}")
    
    # Get configuration for different testing components
    try:
        security_config = json.loads(os.environ.get('SECURITY_TESTING_CONFIG', '{}'))
        functionality_config = json.loads(os.environ.get('FUNCTIONALITY_TESTING_CONFIG', '{}'))
        architecture_config = json.loads(os.environ.get('ARCHITECTURE_VALIDATION_CONFIG', '{}'))
        observability_config = json.loads(os.environ.get('OBSERVABILITY_CONFIG', '{}'))
        reporting_config = json.loads(os.environ.get('REPORTING_CONFIG', '{}'))
    except json.JSONDecodeError as e:
        logger.error(f"Error parsing configuration: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps('Configuration error')
        }
    
    # Initialize AWS clients
    lambda_client = boto3.client('lambda')
    inspector_client = boto3.client('inspector')
    s3_client = boto3.client('s3')
    
    # Record test run start
    test_run_id = f"{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}-{os.environ.get('ENVIRONMENT')}"
    
    # Store test run metadata
    try:
        s3_client.put_object(
            Bucket=os.environ.get('TEST_ARTIFACTS_BUCKET'),
            Key=f"test-runs/{test_run_id}/metadata.json",
            Body=json.dumps({
                'testRunId': test_run_id,
                'startTime': datetime.datetime.now().isoformat(),
                'environment': os.environ.get('ENVIRONMENT'),
                'components': {
                    'security': security_config,
                    'functionality': functionality_config,
                    'architecture': architecture_config,
                    'observability': observability_config,
                    'reporting': reporting_config
                }
            })
        )
    except Exception as e:
        logger.error(f"Error storing test run metadata: {str(e)}")
    
    # Execute security tests
    try:
        if security_config.get('inspector_assessment_template_arn'):
            logger.info("Starting Inspector assessment")
            inspector_client.start_assessment_run(
                assessmentTemplateArn=security_config.get('inspector_assessment_template_arn'),
                assessmentRunName=f"Test-Run-{test_run_id}"
            )
    except Exception as e:
        logger.error(f"Error starting Inspector assessment: {str(e)}")
    
    # Record test results
    results = {
        'testRunId': test_run_id,
        'status': 'STARTED',
        'message': f"Test orchestration started for environment {os.environ.get('ENVIRONMENT')}",
        'timestamp': datetime.datetime.now().isoformat()
    }
    
    # Store test results
    try:
        s3_client.put_object(
            Bucket=os.environ.get('TEST_ARTIFACTS_BUCKET'),
            Key=f"test-runs/{test_run_id}/status.json",
            Body=json.dumps(results)
        )
    except Exception as e:
        logger.error(f"Error storing test results: {str(e)}")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'testRunId': test_run_id,
            'message': 'Test orchestration initiated'
        })
    }