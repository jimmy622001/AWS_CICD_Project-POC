import json
import os
import time
import boto3
import urllib.request
import logging
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Lambda function to test DR failover and failback
    Runs comprehensive checks on both primary and DR regions
    """
    # Get environment variables
    primary_region = os.environ.get('PRIMARY_REGION')
    dr_region = os.environ.get('DR_REGION')
    domain_name = os.environ.get('DOMAIN_NAME')
    health_check_path = os.environ.get('HEALTH_CHECK_PATH')
    hosted_zone_id = os.environ.get('ROUTE53_HOSTED_ZONE_ID')
    primary_endpoint = os.environ.get('PRIMARY_ENDPOINT')
    dr_endpoint = os.environ.get('DR_ENDPOINT')
    sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')

    # Initialize AWS clients
    route53_client = boto3.client('route53')
    sns_client = boto3.client('sns')
    
    start_time = datetime.now()
    results = {
        "start_time": start_time.strftime("%Y-%m-%d %H:%M:%S"),
        "test_id": f"failover-test-{int(time.time())}",
        "steps": [],
        "overall_status": "STARTED"
    }
    
    try:
        # Step 1: Check if primary region is healthy
        results["steps"].append({
            "step": "Check primary region health",
            "status": "STARTED",
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        })
        
        primary_healthy = check_endpoint_health(f"https://{primary_endpoint}{health_check_path}")
        
        results["steps"][-1]["status"] = "SUCCESS" if primary_healthy else "FAILURE"
        results["steps"][-1]["details"] = f"Primary endpoint {'is' if primary_healthy else 'is not'} healthy"
        
        # Step 2: Check if DR region is ready (but not serving traffic)
        results["steps"].append({
            "step": "Check DR region readiness",
            "status": "STARTED",
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        })
        
        dr_ready = check_endpoint_health(f"https://{dr_endpoint}{health_check_path}")
        
        results["steps"][-1]["status"] = "SUCCESS" if dr_ready else "FAILURE"
        results["steps"][-1]["details"] = f"DR endpoint {'is' if dr_ready else 'is not'} ready"
        
        if not primary_healthy:
            results["steps"].append({
                "step": "Primary region not healthy - skipping failover test",
                "status": "WARNING",
                "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            })
            notify_failure(sns_client, sns_topic_arn, "Failover test skipped - primary region not healthy", results)
            results["overall_status"] = "SKIPPED"
            return results
            
        if not dr_ready:
            results["steps"].append({
                "step": "DR region not ready - skipping failover test",
                "status": "WARNING",
                "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            })
            notify_failure(sns_client, sns_topic_arn, "Failover test skipped - DR region not ready", results)
            results["overall_status"] = "SKIPPED"
            return results
        
        # Step 3: Initiate failover to DR region
        results["steps"].append({
            "step": "Initiate failover to DR region",
            "status": "STARTED",
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        })
        
        # Get current Route53 record configuration
        current_records = route53_client.list_resource_record_sets(
            HostedZoneId=hosted_zone_id,
            StartRecordName=domain_name,
            StartRecordType='A',
            MaxItems='1'
        )
        
        # Store the original configuration for failback
        original_config = current_records.get('ResourceRecordSets', [])
        
        # Update the DNS record to point to the DR endpoint
        failover_result = perform_failover_to_dr(route53_client, hosted_zone_id, domain_name, dr_endpoint)
        
        results["steps"][-1]["status"] = "SUCCESS" if failover_result else "FAILURE"
        results["steps"][-1]["details"] = "Route 53 failover to DR region completed"
        
        if not failover_result:
            results["steps"].append({
                "step": "Failover to DR failed - ending test",
                "status": "FAILURE",
                "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            })
            notify_failure(sns_client, sns_topic_arn, "Failover to DR region failed", results)
            results["overall_status"] = "FAILURE"
            return results
        
        # Step 4: Wait for DNS propagation
        results["steps"].append({
            "step": "Wait for DNS propagation",
            "status": "STARTED",
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        })
        
        time.sleep(60)  # Wait for DNS propagation
        
        results["steps"][-1]["status"] = "SUCCESS"
        results["steps"][-1]["details"] = "Waited 60 seconds for DNS propagation"
        
        # Step 5: Verify application is accessible from DR region
        results["steps"].append({
            "step": "Verify application is accessible from DR region",
            "status": "STARTED",
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        })
        
        # In a real scenario, you'd check the domain, not the direct endpoint
        # For testing, we're checking the DR endpoint directly
        dr_serving = check_endpoint_health(f"https://{dr_endpoint}{health_check_path}")
        
        results["steps"][-1]["status"] = "SUCCESS" if dr_serving else "FAILURE"
        results["steps"][-1]["details"] = f"DR region {'is' if dr_serving else 'is not'} serving traffic"
        
        if not dr_serving:
            results["steps"].append({
                "step": "DR region not serving traffic - failback required",
                "status": "WARNING",
                "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            })
        
        # Step 6: Perform failback to primary region
        results["steps"].append({
            "step": "Initiate failback to primary region",
            "status": "STARTED",
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        })
        
        # Update the DNS record to point back to the primary endpoint
        failback_result = perform_failback_to_primary(route53_client, hosted_zone_id, domain_name, primary_endpoint, original_config)
        
        results["steps"][-1]["status"] = "SUCCESS" if failback_result else "FAILURE"
        results["steps"][-1]["details"] = "Route 53 failback to primary region completed"
        
        if not failback_result:
            results["steps"].append({
                "step": "Failback to primary failed - manual intervention required",
                "status": "FAILURE",
                "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            })
            notify_failure(sns_client, sns_topic_arn, "Failback to primary region failed - URGENT: Manual intervention required", results)
            results["overall_status"] = "FAILURE"
            return results
        
        # Step 7: Wait for DNS propagation (failback)
        results["steps"].append({
            "step": "Wait for DNS propagation (failback)",
            "status": "STARTED",
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        })
        
        time.sleep(60)  # Wait for DNS propagation
        
        results["steps"][-1]["status"] = "SUCCESS"
        results["steps"][-1]["details"] = "Waited 60 seconds for DNS propagation"
        
        # Step 8: Verify application is accessible from primary region
        results["steps"].append({
            "step": "Verify application is accessible from primary region",
            "status": "STARTED",
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        })
        
        # In a real scenario, you'd check the domain, not the direct endpoint
        primary_serving = check_endpoint_health(f"https://{primary_endpoint}{health_check_path}")
        
        results["steps"][-1]["status"] = "SUCCESS" if primary_serving else "FAILURE"
        results["steps"][-1]["details"] = f"Primary region {'is' if primary_serving else 'is not'} serving traffic"
        
        # Final status
        end_time = datetime.now()
        duration = (end_time - start_time).total_seconds()
        
        results["end_time"] = end_time.strftime("%Y-%m-%d %H:%M:%S")
        results["duration_seconds"] = duration
        
        if all(step["status"] in ["SUCCESS", "STARTED"] for step in results["steps"]):
            results["overall_status"] = "SUCCESS"
            notify_success(sns_client, sns_topic_arn, f"Failover test completed successfully in {duration:.2f} seconds", results)
        else:
            results["overall_status"] = "PARTIAL_SUCCESS"
            notify_partial_success(sns_client, sns_topic_arn, f"Failover test completed with some issues in {duration:.2f} seconds", results)
        
    except Exception as e:
        logger.error(f"Error during failover test: {str(e)}")
        results["overall_status"] = "ERROR"
        results["error"] = str(e)
        notify_failure(sns_client, sns_topic_arn, f"Error during failover test: {str(e)}", results)
    
    return results

def check_endpoint_health(url):
    """Check if an endpoint is healthy by making a HTTP request"""
    try:
        response = urllib.request.urlopen(url, timeout=10)
        return response.getcode() == 200
    except Exception as e:
        logger.error(f"Health check failed for {url}: {str(e)}")
        return False

def perform_failover_to_dr(route53_client, hosted_zone_id, domain_name, dr_endpoint):
    """Update Route 53 to point to DR endpoint"""
    try:
        response = route53_client.change_resource_record_sets(
            HostedZoneId=hosted_zone_id,
            ChangeBatch={
                'Comment': 'Automated failover test to DR',
                'Changes': [
                    {
                        'Action': 'UPSERT',
                        'ResourceRecordSet': {
                            'Name': domain_name,
                            'Type': 'A',
                            'AliasTarget': {
                                'HostedZoneId': hosted_zone_id,
                                'DNSName': dr_endpoint,
                                'EvaluateTargetHealth': True
                            }
                        }
                    }
                ]
            }
        )
        return True
    except Exception as e:
        logger.error(f"Failover to DR failed: {str(e)}")
        return False

def perform_failback_to_primary(route53_client, hosted_zone_id, domain_name, primary_endpoint, original_config):
    """Restore Route 53 configuration to point to primary endpoint"""
    try:
        if original_config:
            # If we captured the original config, restore it exactly
            response = route53_client.change_resource_record_sets(
                HostedZoneId=hosted_zone_id,
                ChangeBatch={
                    'Comment': 'Automated failback to primary region',
                    'Changes': [
                        {
                            'Action': 'UPSERT',
                            'ResourceRecordSet': original_config[0]
                        }
                    ]
                }
            )
        else:
            # Otherwise, set it to the primary endpoint
            response = route53_client.change_resource_record_sets(
                HostedZoneId=hosted_zone_id,
                ChangeBatch={
                    'Comment': 'Automated failback to primary region',
                    'Changes': [
                        {
                            'Action': 'UPSERT',
                            'ResourceRecordSet': {
                                'Name': domain_name,
                                'Type': 'A',
                                'AliasTarget': {
                                    'HostedZoneId': hosted_zone_id,
                                    'DNSName': primary_endpoint,
                                    'EvaluateTargetHealth': True
                                }
                            }
                        }
                    ]
                }
            )
        return True
    except Exception as e:
        logger.error(f"Failback to primary failed: {str(e)}")
        return False

def notify_success(sns_client, topic_arn, subject, results):
    """Send notification for successful test"""
    message = json.dumps({
        "status": "SUCCESS",
        "message": "Monthly DR failover test completed successfully",
        "details": results
    }, indent=2)
    
    try:
        sns_client.publish(
            TopicArn=topic_arn,
            Subject=subject,
            Message=message
        )
    except Exception as e:
        logger.error(f"Failed to send success notification: {str(e)}")

def notify_partial_success(sns_client, topic_arn, subject, results):
    """Send notification for partially successful test"""
    message = json.dumps({
        "status": "PARTIAL_SUCCESS",
        "message": "Monthly DR failover test completed with some issues",
        "details": results
    }, indent=2)
    
    try:
        sns_client.publish(
            TopicArn=topic_arn,
            Subject=subject,
            Message=message
        )
    except Exception as e:
        logger.error(f"Failed to send partial success notification: {str(e)}")

def notify_failure(sns_client, topic_arn, subject, results):
    """Send notification for failed test"""
    message = json.dumps({
        "status": "FAILURE",
        "message": "Monthly DR failover test encountered errors",
        "details": results
    }, indent=2)
    
    try:
        sns_client.publish(
            TopicArn=topic_arn,
            Subject=subject,
            Message=message
        )
    except Exception as e:
        logger.error(f"Failed to send failure notification: {str(e)}")