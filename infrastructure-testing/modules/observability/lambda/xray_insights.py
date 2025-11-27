import json
import boto3
import os
import logging
import datetime
from datetime import timedelta

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Process AWS X-Ray traces and generate performance insights.
    """
    # Get environment variables
    project_name = os.environ.get('PROJECT_NAME')
    environment = os.environ.get('ENVIRONMENT')
    
    # Initialize AWS clients
    xray = boto3.client('xray')
    cloudwatch = boto3.client('cloudwatch')
    
    # Calculate time range (last 24 hours)
    end_time = datetime.datetime.now()
    start_time = end_time - timedelta(hours=24)
    
    # Fetch trace summaries
    try:
        logger.info(f"Fetching X-Ray trace summaries for {project_name} ({environment})")
        
        # Get trace summaries
        response = xray.get_trace_summaries(
            StartTime=start_time,
            EndTime=end_time,
            Sampling=False,
            FilterExpression=f"service(\"{project_name}\") AND annotation.environment = \"{environment}\""
        )
        
        trace_summaries = response.get('TraceSummaries', [])
        logger.info(f"Found {len(trace_summaries)} traces")
        
        if not trace_summaries:
            logger.info("No traces found for the specified criteria")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'No traces found'
                })
            }
        
        # Analyze trace data
        response_times = []
        error_count = 0
        fault_count = 0
        throttle_count = 0
        
        for summary in trace_summaries:
            response_times.append(summary.get('ResponseTime', 0))
            
            if summary.get('HasError', False):
                error_count += 1
            
            if summary.get('HasFault', False):
                fault_count += 1
            
            if summary.get('HasThrottle', False):
                throttle_count += 1
        
        # Calculate statistics
        avg_response_time = sum(response_times) / len(response_times) if response_times else 0
        max_response_time = max(response_times) if response_times else 0
        min_response_time = min(response_times) if response_times else 0
        p95_response_time = sorted(response_times)[int(len(response_times) * 0.95)] if len(response_times) >= 20 else max_response_time
        
        # Get service graph for deeper analysis
        service_graph = xray.get_service_graph(
            StartTime=start_time,
            EndTime=end_time
        )
        
        services = service_graph.get('Services', [])
        service_insights = []
        
        for service in services:
            service_insights.append({
                'name': service.get('Name', 'Unknown'),
                'type': service.get('Type', 'Unknown'),
                'requestCount': service.get('TotalCount', 0),
                'errorCount': service.get('ErrorStatistics', {}).get('TotalCount', 0),
                'faultCount': service.get('FaultStatistics', {}).get('TotalCount', 0),
                'averageResponseTime': service.get('SummaryStatistics', {}).get('ResponseTime', {}).get('Average', 0)
            })
        
        # Create insights report
        insights = {
            'project': project_name,
            'environment': environment,
            'timeRange': {
                'start': start_time.isoformat(),
                'end': end_time.isoformat()
            },
            'summary': {
                'traceCount': len(trace_summaries),
                'averageResponseTime': avg_response_time,
                'p95ResponseTime': p95_response_time,
                'maxResponseTime': max_response_time,
                'minResponseTime': min_response_time,
                'errorCount': error_count,
                'faultCount': fault_count,
                'throttleCount': throttle_count
            },
            'serviceInsights': service_insights
        }
        
        # Publish metrics to CloudWatch
        try:
            cloudwatch.put_metric_data(
                Namespace=f"XRayInsights/{project_name}/{environment}",
                MetricData=[
                    {
                        'MetricName': 'AverageResponseTime',
                        'Value': avg_response_time,
                        'Unit': 'Milliseconds'
                    },
                    {
                        'MetricName': 'P95ResponseTime',
                        'Value': p95_response_time,
                        'Unit': 'Milliseconds'
                    },
                    {
                        'MetricName': 'ErrorRate',
                        'Value': (error_count / len(trace_summaries)) * 100 if trace_summaries else 0,
                        'Unit': 'Percent'
                    },
                    {
                        'MetricName': 'FaultRate',
                        'Value': (fault_count / len(trace_summaries)) * 100 if trace_summaries else 0,
                        'Unit': 'Percent'
                    }
                ]
            )
        except Exception as e:
            logger.warning(f"Failed to publish CloudWatch metrics: {str(e)}")
        
        return {
            'statusCode': 200,
            'body': json.dumps(insights)
        }
    
    except Exception as e:
        logger.error(f"Error processing X-Ray traces: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f"Error processing X-Ray traces: {str(e)}"
            })
        }