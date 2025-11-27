import json
import boto3
import os
import logging
import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Process AWS Trusted Advisor check results.
    """
    # Get environment variables
    report_bucket = os.environ.get('REPORT_BUCKET')
    project_name = os.environ.get('PROJECT_NAME')
    environment = os.environ.get('ENVIRONMENT')
    
    # Initialize AWS clients
    support = boto3.client('support')
    s3 = boto3.client('s3')
    
    # Process event (could be a scheduled event or direct invocation)
    logger.info(f"Processing Trusted Advisor results for {project_name} ({environment})")
    
    try:
        # Get all Trusted Advisor check results
        checks_response = support.describe_trusted_advisor_checks(
            language='en'
        )
        
        # Get results for each check
        all_results = []
        check_summaries = {
            'ok': 0,
            'warning': 0,
            'error': 0,
            'not_available': 0
        }
        
        for check in checks_response.get('checks', []):
            check_id = check.get('id')
            
            try:
                result = support.describe_trusted_advisor_check_result(
                    checkId=check_id,
                    language='en'
                )
                
                # Get the check status
                status = result.get('result', {}).get('status')
                if status in check_summaries:
                    check_summaries[status] += 1
                
                # Add to results if not OK
                if status != 'ok':
                    all_results.append({
                        'id': check_id,
                        'name': check.get('name'),
                        'category': check.get('category'),
                        'description': check.get('description'),
                        'status': status,
                        'resourcesSummary': result.get('result', {}).get('resourcesSummary', {}),
                        'flaggedResources': result.get('result', {}).get('flaggedResources', [])
                    })
            except Exception as e:
                logger.warning(f"Error getting results for check {check.get('name')}: {str(e)}")
        
        # Create the report
        timestamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        report = {
            'project': project_name,
            'environment': environment,
            'timestamp': timestamp,
            'summary': check_summaries,
            'flaggedChecks': all_results
        }
        
        # Store report in S3
        report_key = f"architecture-reports/{project_name}/{environment}/trusted-advisor-results-{timestamp}.json"
        s3.put_object(
            Bucket=report_bucket,
            Key=report_key,
            Body=json.dumps(report, indent=2),
            ContentType='application/json'
        )
        
        logger.info(f"Trusted Advisor report stored at s3://{report_bucket}/{report_key}")
        
        # Generate HTML summary for better readability
        html_summary = generate_html_summary(report)
        html_key = f"architecture-reports/{project_name}/{environment}/trusted-advisor-summary-{timestamp}.html"
        
        s3.put_object(
            Bucket=report_bucket,
            Key=html_key,
            Body=html_summary,
            ContentType='text/html'
        )
        
        logger.info(f"Trusted Advisor HTML summary stored at s3://{report_bucket}/{html_key}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'reportPath': f"s3://{report_bucket}/{report_key}",
                'htmlSummaryPath': f"s3://{report_bucket}/{html_key}",
                'summary': check_summaries
            })
        }
    
    except Exception as e:
        logger.error(f"Error processing Trusted Advisor results: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f"Error processing Trusted Advisor results: {str(e)}"
            })
        }

def generate_html_summary(report):
    """Generate HTML summary of Trusted Advisor results"""
    project_name = report.get('project', '')
    environment = report.get('environment', '')
    timestamp = report.get('timestamp', '')
    summary = report.get('summary', {})
    flagged_checks = report.get('flaggedChecks', [])
    
    # Basic styling and header
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Trusted Advisor Results - {project_name} ({environment})</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 20px; }}
            h1, h2 {{ color: #0066cc; }}
            .summary {{ display: flex; margin: 20px 0; }}
            .summary-box {{ padding: 10px; margin: 10px; border-radius: 5px; min-width: 100px; text-align: center; }}
            .ok {{ background-color: #dff0d8; color: #3c763d; }}
            .warning {{ background-color: #fcf8e3; color: #8a6d3b; }}
            .error {{ background-color: #f2dede; color: #a94442; }}
            .not-available {{ background-color: #f5f5f5; color: #666; }}
            table {{ border-collapse: collapse; width: 100%; }}
            th, td {{ text-align: left; padding: 8px; border-bottom: 1px solid #ddd; }}
            th {{ background-color: #f2f2f2; }}
            tr:hover {{ background-color: #f5f5f5; }}
            .category {{ font-weight: bold; }}
        </style>
    </head>
    <body>
        <h1>Trusted Advisor Results</h1>
        <p><strong>Project:</strong> {project_name}</p>
        <p><strong>Environment:</strong> {environment}</p>
        <p><strong>Generated:</strong> {timestamp}</p>
        
        <h2>Summary</h2>
        <div class="summary">
            <div class="summary-box ok">
                <h3>OK</h3>
                <p>{summary.get('ok', 0)}</p>
            </div>
            <div class="summary-box warning">
                <h3>Warning</h3>
                <p>{summary.get('warning', 0)}</p>
            </div>
            <div class="summary-box error">
                <h3>Error</h3>
                <p>{summary.get('error', 0)}</p>
            </div>
            <div class="summary-box not-available">
                <h3>Not Available</h3>
                <p>{summary.get('not_available', 0)}</p>
            </div>
        </div>
        
        <h2>Flagged Checks</h2>
    """
    
    # Group checks by category
    checks_by_category = {}
    for check in flagged_checks:
        category = check.get('category', 'Other')
        if category not in checks_by_category:
            checks_by_category[category] = []
        checks_by_category[category].append(check)
    
    # Add checks by category
    for category, checks in checks_by_category.items():
        html += f"""
        <h3>{category}</h3>
        <table>
            <tr>
                <th>Check</th>
                <th>Status</th>
                <th>Resources</th>
                <th>Description</th>
            </tr>
        """
        
        for check in checks:
            status = check.get('status', '')
            resources_summary = check.get('resourcesSummary', {})
            resources_count = resources_summary.get('resourcesFlagged', 0)
            resources_total = resources_summary.get('resourcesProcessed', 0)
            
            html += f"""
            <tr>
                <td>{check.get('name', '')}</td>
                <td>{status.upper()}</td>
                <td>{resources_count} / {resources_total}</td>
                <td>{check.get('description', '')}</td>
            </tr>
            """
        
        html += "</table>"
    
    # Close the HTML document
    html += """
    </body>
    </html>
    """
    
    return html