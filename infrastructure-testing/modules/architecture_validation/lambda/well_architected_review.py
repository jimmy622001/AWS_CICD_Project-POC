import json
import boto3
import os
import logging
import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Perform automated Well-Architected review and generate a report.
    """
    # Get environment variables
    report_bucket = os.environ.get('REPORT_BUCKET')
    project_name = os.environ.get('PROJECT_NAME')
    environment = os.environ.get('ENVIRONMENT')
    
    # Initialize AWS clients
    wellarchitected = boto3.client('wellarchitected')
    s3 = boto3.client('s3')
    
    logger.info(f"Starting Well-Architected review for {project_name} ({environment})")
    
    try:
        # Find existing workload or create a new one
        workload_id = None
        workload_arn = None
        
        # List workloads to find if one exists for this project/environment
        list_response = wellarchitected.list_workloads()
        for workload in list_response.get('WorkloadSummaries', []):
            if (workload.get('WorkloadName') == f"{project_name}-{environment}" or 
                workload.get('WorkloadName') == project_name):
                workload_id = workload.get('WorkloadId')
                workload_arn = workload.get('WorkloadArn')
                logger.info(f"Found existing workload: {workload_id}")
                break
        
        # If no workload exists, create one (in a real implementation)
        if not workload_id:
            logger.info(f"No existing workload found for {project_name}-{environment}")
            
            # This would create a new workload - commented out as this requires more setup
            # including properly defining lenses, pillars, etc.
            """
            create_response = wellarchitected.create_workload(
                WorkloadName=f"{project_name}-{environment}",
                Description=f"Workload for {project_name} in {environment} environment",
                Environment='PRODUCTION' if environment == 'prod' else 'PREPRODUCTION',
                AwsRegions=[boto3.session.Session().region_name],
                Lenses=['wellarchitected']
            )
            workload_id = create_response.get('WorkloadId')
            workload_arn = create_response.get('WorkloadArn')
            """
            
            # For now, we'll just create a placeholder report
            timestamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
            report = {
                'project': project_name,
                'environment': environment,
                'timestamp': timestamp,
                'message': 'No Well-Architected workload found. Please create one manually in the Well-Architected Tool.',
                'summary': {
                    'pillars': [
                        {
                            'name': 'Operational Excellence',
                            'riskCounts': {'HIGH': 0, 'MEDIUM': 0, 'LOW': 0, 'NONE': 0, 'NOT_APPLICABLE': 0},
                            'recommendations': []
                        },
                        {
                            'name': 'Security',
                            'riskCounts': {'HIGH': 0, 'MEDIUM': 0, 'LOW': 0, 'NONE': 0, 'NOT_APPLICABLE': 0},
                            'recommendations': []
                        },
                        {
                            'name': 'Reliability',
                            'riskCounts': {'HIGH': 0, 'MEDIUM': 0, 'LOW': 0, 'NONE': 0, 'NOT_APPLICABLE': 0},
                            'recommendations': []
                        },
                        {
                            'name': 'Performance Efficiency',
                            'riskCounts': {'HIGH': 0, 'MEDIUM': 0, 'LOW': 0, 'NONE': 0, 'NOT_APPLICABLE': 0},
                            'recommendations': []
                        },
                        {
                            'name': 'Cost Optimization',
                            'riskCounts': {'HIGH': 0, 'MEDIUM': 0, 'LOW': 0, 'NONE': 0, 'NOT_APPLICABLE': 0},
                            'recommendations': []
                        },
                        {
                            'name': 'Sustainability',
                            'riskCounts': {'HIGH': 0, 'MEDIUM': 0, 'LOW': 0, 'NONE': 0, 'NOT_APPLICABLE': 0},
                            'recommendations': []
                        }
                    ]
                }
            }
            
            # Store the placeholder report
            report_key = f"architecture-reports/{project_name}/{environment}/well-architected-review-{timestamp}.json"
            s3.put_object(
                Bucket=report_bucket,
                Key=report_key,
                Body=json.dumps(report, indent=2),
                ContentType='application/json'
            )
            
            logger.info(f"Placeholder Well-Architected report stored at s3://{report_bucket}/{report_key}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'No Well-Architected workload found',
                    'reportPath': f"s3://{report_bucket}/{report_key}"
                })
            }
        
        # If a workload exists, get the review data
        timestamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        report = {
            'project': project_name,
            'environment': environment,
            'timestamp': timestamp,
            'workloadId': workload_id,
            'summary': {
                'pillars': []
            }
        }
        
        # Get lens reviews (in a real implementation, you would iterate through all lenses)
        lens_review = wellarchitected.get_lens_review(
            WorkloadId=workload_id,
            LensAlias='wellarchitected'
        )
        
        # Process pillar reviews
        for pillar_review in lens_review.get('PillarReviews', []):
            pillar_name = pillar_review.get('PillarReviewSummary', {}).get('PillarName', 'Unknown')
            risk_counts = pillar_review.get('PillarReviewSummary', {}).get('RiskCounts', {})
            
            pillar_data = {
                'name': pillar_name,
                'riskCounts': risk_counts,
                'recommendations': []
            }
            
            # Get high risk items
            for question in pillar_review.get('Questions', []):
                risk = question.get('Risk')
                if risk in ['HIGH', 'MEDIUM']:
                    pillar_data['recommendations'].append({
                        'question': question.get('QuestionTitle', ''),
                        'risk': risk,
                        'improvement': question.get('ImprovementPlan', {}).get('ImprovementPlanUrl', '')
                    })
            
            report['summary']['pillars'].append(pillar_data)
        
        # Store the report
        report_key = f"architecture-reports/{project_name}/{environment}/well-architected-review-{timestamp}.json"
        s3.put_object(
            Bucket=report_bucket,
            Key=report_key,
            Body=json.dumps(report, indent=2),
            ContentType='application/json'
        )
        
        logger.info(f"Well-Architected report stored at s3://{report_bucket}/{report_key}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'reportPath': f"s3://{report_bucket}/{report_key}"
            })
        }
    
    except Exception as e:
        logger.error(f"Error performing Well-Architected review: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f"Error performing Well-Architected review: {str(e)}"
            })
        }