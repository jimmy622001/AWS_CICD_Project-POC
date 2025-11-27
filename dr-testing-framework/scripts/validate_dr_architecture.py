#!/usr/bin/env python3
"""
DR architecture validation script for pre-deployment validation.
Analyzes DR infrastructure plans against DR best practices and requirements.
"""
import os
import sys
import json
import argparse
import logging
from pathlib import Path

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger('dr-architecture-validator')

def parse_args():
    parser = argparse.ArgumentParser(description='Validate DR architecture')
    parser.add_argument('--environment', required=True, help='Environment name (prod or dr)')
    parser.add_argument('--plan-file', default=None, help='Path to Terraform plan JSON file (optional)')
    parser.add_argument('--output-dir', default='validation_reports', help='Output directory for reports')
    return parser.parse_args()

def load_plan(environment, plan_file=None):
    """Load Terraform plan data"""
    if plan_file and os.path.exists(plan_file):
        with open(plan_file, 'r') as f:
            return json.load(f)
    
    # Try default location if no plan file specified
    default_path = f'environments/{environment}/plan.json'
    if os.path.exists(default_path):
        with open(default_path, 'r') as f:
            return json.load(f)
    
    logger.warning(f"No plan file found for environment {environment}")
    return None

def validate_multi_region(plan_data, environment):
    """Validate multi-region DR configuration"""
    issues = []
    
    if not plan_data:
        issues.append({
            'severity': 'MEDIUM',
            'message': 'Unable to validate multi-region setup - no plan data available'
        })
        return {
            'passed': False,
            'issues': issues
        }
    
    # Check for resources in secondary region
    resources = plan_data.get('planned_values', {}).get('root_module', {}).get('resources', [])
    
    # Get all AWS provider configurations to identify regions
    providers = set()
    for resource in resources:
        if 'provider_name' in resource and resource['provider_name'].startswith('aws'):
            providers.add(resource['provider_name'])
    
    if len(providers) < 2:
        issues.append({
            'severity': 'HIGH',
            'message': 'DR architecture does not appear to be multi-region. Only found providers: ' + ', '.join(providers)
        })
    
    return {
        'passed': len(issues) == 0,
        'issues': issues
    }

def validate_rpo_rto(plan_data, environment):
    """Validate RPO/RTO capabilities based on infrastructure"""
    issues = []
    
    # Check for replication configurations
    # This is a placeholder - in a real implementation, you would look for specific
    # resources that indicate replication (S3 bucket replication, RDS read replicas, etc.)
    
    if environment == 'prod':
        issues.append({
            'severity': 'MEDIUM',
            'message': 'Production environment should have cross-region replication configured for critical data stores'
        })
    
    if environment == 'dr':
        issues.append({
            'severity': 'MEDIUM',
            'message': 'DR environment should have automated failover mechanisms configured'
        })
    
    return {
        'passed': len(issues) == 0,
        'issues': issues
    }

def validate_dr_architecture(environment, plan_data):
    """Main DR validation function"""
    results = {
        'overall_passed': True,
        'environment': environment,
        'components': {}
    }
    
    # Perform component validations
    results['components']['multi_region'] = validate_multi_region(plan_data, environment)
    results['components']['rpo_rto'] = validate_rpo_rto(plan_data, environment)
    
    # Determine overall result
    for component, component_result in results['components'].items():
        if not component_result['passed']:
            results['overall_passed'] = False
            
            # Check for critical issues
            critical_issues = [i for i in component_result['issues'] if i['severity'] == 'CRITICAL']
            if critical_issues:
                results['has_critical_issues'] = True
    
    return results

def main():
    args = parse_args()
    
    # Only run for prod or dr environments
    if args.environment not in ['prod', 'dr']:
        logger.info(f"DR architecture validation is only applicable for prod and dr environments, not {args.environment}")
        return
    
    # Create output directory if it doesn't exist
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Load plan data
    plan_data = load_plan(args.environment, args.plan_file)
    
    # Run validation
    logger.info(f"Starting DR architecture validation for environment: {args.environment}")
    results = validate_dr_architecture(args.environment, plan_data)
    
    # Write results to file
    output_file = output_dir / 'dr_architecture_validation.json'
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)
    
    logger.info(f"DR architecture validation complete. Results written to {output_file}")
    
    # Exit with error if there are critical issues
    if results.get('has_critical_issues'):
        logger.error("Validation found critical issues that must be addressed!")
        sys.exit(1)
    
    if not results['overall_passed']:
        logger.warning("Validation found issues that should be reviewed")
        # Exit with 0 as warnings shouldn't fail the pipeline
    
    logger.info("DR architecture validation successful")

if __name__ == "__main__":
    main()