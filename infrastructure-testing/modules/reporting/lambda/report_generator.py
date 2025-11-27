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
    Generate comprehensive reports from various testing results.
    """
    # Get environment variables
    reports_bucket = os.environ.get('REPORTS_BUCKET')
    notification_email = os.environ.get('NOTIFICATION_EMAIL')
    project_name = os.environ.get('PROJECT_NAME')
    environment = os.environ.get('ENVIRONMENT')
    
    # Extract report type from event
    report_type = "weekly"  # Default to weekly
    if event and isinstance(event, dict):
        report_type = event.get('reportType', 'weekly')
    
    logger.info(f"Generating {report_type} report for {project_name} ({environment})")
    
    # Initialize AWS clients
    s3 = boto3.client('s3')
    inspector = boto3.client('inspector')
    cloudwatch = boto3.client('cloudwatch')
    
    # Define time range based on report type
    end_time = datetime.datetime.now()
    if report_type == "daily":
        start_time = end_time - timedelta(days=1)
    elif report_type == "weekly":
        start_time = end_time - timedelta(days=7)
    elif report_type == "monthly":
        start_time = end_time - timedelta(days=30)
    else:
        start_time = end_time - timedelta(days=7)  # Default to weekly
    
    # Create the report structure
    report = {
        "reportType": report_type,
        "project": project_name,
        "environment": environment,
        "generatedAt": end_time.isoformat(),
        "timeRange": {
            "start": start_time.isoformat(),
            "end": end_time.isoformat()
        },
        "sections": {
            "security": collect_security_data(s3, reports_bucket, project_name, environment, start_time, end_time),
            "functionality": collect_functionality_data(s3, reports_bucket, cloudwatch, project_name, environment, start_time, end_time),
            "architecture": collect_architecture_data(s3, reports_bucket, project_name, environment, start_time, end_time),
            "observability": collect_observability_data(s3, cloudwatch, project_name, environment, start_time, end_time)
        }
    }
    
    # Generate executive summary
    report["executiveSummary"] = generate_executive_summary(report)
    
    # Store report in S3
    timestamp = end_time.strftime("%Y%m%d-%H%M%S")
    report_key = f"reports/{project_name}/{environment}/{report_type}-report-{timestamp}.json"
    
    try:
        s3.put_object(
            Bucket=reports_bucket,
            Key=report_key,
            Body=json.dumps(report, indent=2),
            ContentType='application/json'
        )
        logger.info(f"Report stored at s3://{reports_bucket}/{report_key}")
    except Exception as e:
        logger.error(f"Error storing report in S3: {str(e)}")
    
    # Generate PDF version (placeholder - this would require additional libraries)
    pdf_key = f"reports/{project_name}/{environment}/{report_type}-report-{timestamp}.pdf"
    
    # For now, just store a placeholder message
    try:
        s3.put_object(
            Bucket=reports_bucket,
            Key=pdf_key,
            Body="PDF report would be generated here with a library like ReportLab or by invoking a separate service.",
            ContentType='text/plain'
        )
        logger.info(f"PDF report placeholder stored at s3://{reports_bucket}/{pdf_key}")
    except Exception as e:
        logger.error(f"Error storing PDF placeholder in S3: {str(e)}")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': f"{report_type.capitalize()} report generated successfully",
            'jsonReportPath': f"s3://{reports_bucket}/{report_key}",
            'pdfReportPath': f"s3://{reports_bucket}/{pdf_key}"
        })
    }

def collect_security_data(s3, bucket, project, environment, start_time, end_time):
    """Collect security testing data from S3"""
    try:
        # List security reports in the specified time range
        response = s3.list_objects_v2(
            Bucket=bucket,
            Prefix=f"security-reports/{project}/{environment}/"
        )
        
        security_reports = []
        if 'Contents' in response:
            for item in response['Contents']:
                # Check if the report falls within our time range
                if start_time.timestamp() <= item['LastModified'].timestamp() <= end_time.timestamp():
                    try:
                        # Get the report content
                        report_obj = s3.get_object(Bucket=bucket, Key=item['Key'])
                        report_data = json.loads(report_obj['Body'].read().decode('utf-8'))
                        security_reports.append(report_data)
                    except Exception as e:
                        logger.warning(f"Error processing security report {item['Key']}: {str(e)}")
        
        # Aggregate findings
        findings_by_severity = {
            'High': 0,
            'Medium': 0,
            'Low': 0,
            'Informational': 0
        }
        
        for report in security_reports:
            if 'severitySummary' in report:
                for severity, count in report['severitySummary'].items():
                    if severity in findings_by_severity:
                        findings_by_severity[severity] += count
        
        # Return aggregated security data
        return {
            "reportCount": len(security_reports),
            "findingsBySeverity": findings_by_severity,
            "totalFindings": sum(findings_by_severity.values()),
            "criticalFindings": findings_by_severity.get('High', 0)
        }
    
    except Exception as e:
        logger.error(f"Error collecting security data: {str(e)}")
        return {
            "error": str(e)
        }

def collect_functionality_data(s3, bucket, cloudwatch, project, environment, start_time, end_time):
    """Collect functionality testing data from CloudWatch"""
    try:
        # Get canary statistics from CloudWatch
        namespace = "CloudWatchSynthetics"
        metric_name = "SuccessPercent"
        
        response = cloudwatch.get_metric_statistics(
            Namespace=namespace,
            MetricName=metric_name,
            Dimensions=[
                {
                    'Name': 'Environment',
                    'Value': environment
                },
                {
                    'Name': 'Project',
                    'Value': project
                }
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=86400,  # 1 day
            Statistics=['Average', 'Minimum']
        )
        
        datapoints = response.get('Datapoints', [])
        
        # Calculate overall success rate
        avg_success_rate = 0
        min_success_rate = 100
        
        if datapoints:
            avg_success_rate = sum(dp.get('Average', 0) for dp in datapoints) / len(datapoints)
            min_success_rate = min(dp.get('Minimum', 100) for dp in datapoints)
        
        # Return functionality data
        return {
            "averageSuccessRate": avg_success_rate,
            "lowestSuccessRate": min_success_rate,
            "datapointCount": len(datapoints)
        }
    
    except Exception as e:
        logger.error(f"Error collecting functionality data: {str(e)}")
        return {
            "error": str(e)
        }

def collect_architecture_data(s3, bucket, project, environment, start_time, end_time):
    """Collect architecture validation data from S3"""
    try:
        # List architecture reports
        response = s3.list_objects_v2(
            Bucket=bucket,
            Prefix=f"architecture-reports/{project}/{environment}/"
        )
        
        architecture_reports = []
        if 'Contents' in response:
            for item in response['Contents']:
                # Check if the report falls within our time range
                if start_time.timestamp() <= item['LastModified'].timestamp() <= end_time.timestamp():
                    try:
                        # Get the report content
                        report_obj = s3.get_object(Bucket=bucket, Key=item['Key'])
                        report_data = json.loads(report_obj['Body'].read().decode('utf-8'))
                        architecture_reports.append(report_data)
                    except Exception as e:
                        logger.warning(f"Error processing architecture report {item['Key']}: {str(e)}")
        
        # Return architecture data
        return {
            "reportCount": len(architecture_reports),
            "lastReportTimestamp": max(report.get('timestamp', '1970-01-01T00:00:00') 
                                      for report in architecture_reports) if architecture_reports else None
        }
    
    except Exception as e:
        logger.error(f"Error collecting architecture data: {str(e)}")
        return {
            "error": str(e)
        }

def collect_observability_data(s3, cloudwatch, project, environment, start_time, end_time):
    """Collect observability data from CloudWatch"""
    try:
        # Get X-Ray metrics
        namespace = f"XRayInsights/{project}/{environment}"
        metrics = ['AverageResponseTime', 'P95ResponseTime', 'ErrorRate']
        
        metrics_data = {}
        for metric in metrics:
            response = cloudwatch.get_metric_statistics(
                Namespace=namespace,
                MetricName=metric,
                StartTime=start_time,
                EndTime=end_time,
                Period=86400,  # 1 day
                Statistics=['Average']
            )
            
            datapoints = response.get('Datapoints', [])
            
            if datapoints:
                # Calculate average across all datapoints
                metrics_data[metric] = sum(dp.get('Average', 0) for dp in datapoints) / len(datapoints)
            else:
                metrics_data[metric] = 0
        
        # Return observability data
        return {
            "averageResponseTime": metrics_data.get('AverageResponseTime', 0),
            "p95ResponseTime": metrics_data.get('P95ResponseTime', 0),
            "errorRate": metrics_data.get('ErrorRate', 0)
        }
    
    except Exception as e:
        logger.error(f"Error collecting observability data: {str(e)}")
        return {
            "error": str(e)
        }

def generate_executive_summary(report):
    """Generate an executive summary based on the collected data"""
    security_data = report.get('sections', {}).get('security', {})
    functionality_data = report.get('sections', {}).get('functionality', {})
    architecture_data = report.get('sections', {}).get('architecture', {})
    observability_data = report.get('sections', {}).get('observability', {})
    
    # Calculate overall health score (0-100)
    security_score = 0
    if 'totalFindings' in security_data and security_data['totalFindings'] > 0:
        # Calculate security score - penalize for high findings
        high_findings = security_data.get('findingsBySeverity', {}).get('High', 0)
        medium_findings = security_data.get('findingsBySeverity', {}).get('Medium', 0)
        
        # Each high finding reduces score by 10, each medium by 3
        security_deduction = min(100, high_findings * 10 + medium_findings * 3)
        security_score = 100 - security_deduction
    else:
        security_score = 100
    
    # Functionality score based on success rate
    functionality_score = functionality_data.get('averageSuccessRate', 0)
    
    # Observability score based on error rate
    error_rate = observability_data.get('errorRate', 0)
    observability_score = 100 - error_rate
    
    # Overall score is an average
    overall_score = (security_score + functionality_score + observability_score) / 3
    
    # Determine health status
    if overall_score >= 90:
        health_status = "Excellent"
    elif overall_score >= 80:
        health_status = "Good"
    elif overall_score >= 70:
        health_status = "Fair"
    else:
        health_status = "Needs Attention"
    
    # Generate summary text
    summary_text = f"""
    {report.get('project')} ({report.get('environment')}) {report.get('reportType').capitalize()} Report
    
    Overall Health: {health_status} ({overall_score:.1f}%)
    
    Security: {security_score:.1f}% - {security_data.get('totalFindings', 0)} findings ({security_data.get('findingsBySeverity', {}).get('High', 0)} high, {security_data.get('findingsBySeverity', {}).get('Medium', 0)} medium)
    
    Functionality: {functionality_score:.1f}% - Average API success rate
    
    Performance: Response Time: {observability_data.get('averageResponseTime', 0):.2f}ms (avg), {observability_data.get('p95ResponseTime', 0):.2f}ms (p95)
    
    Report Period: {report.get('timeRange', {}).get('start')} to {report.get('timeRange', {}).get('end')}
    """
    
    return {
        "overallScore": overall_score,
        "healthStatus": health_status,
        "securityScore": security_score,
        "functionalityScore": functionality_score,
        "observabilityScore": observability_score,
        "summaryText": summary_text.strip()
    }