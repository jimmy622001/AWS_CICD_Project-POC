#!/usr/bin/env python3
"""
Architecture validation script for pre-deployment validation.
Analyzes Terraform plan files against architectural best practices.
"""
import os
import sys
import json
import argparse
import logging
from pathlib import Path

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger('architecture-validator')

def parse_args():
    parser = argparse.ArgumentParser(description='Validate architecture based on Terraform plan')
    parser.add_argument('--plan-file', required=True, help='Path to Terraform plan JSON file')
    parser.add_argument('--report-path', required=True, help='Path to output validation reports')
    return parser.parse_args()

def load_plan(plan_file):
    try:
        with open(plan_file, 'r') as f:
            return json.load(f)
    except Exception as e:
        logger.error(f"Failed to load plan file: {e}")
        return None

def validate_networking(plan_data, results):
    """Validate networking components in the architecture"""
    issues = []
    
    # Check for VPC configuration
    resources = plan_data.get('planned_values', {}).get('root_module', {}).get('resources', [])
    vpc_resources = [r for r in resources if r.get('type') == 'aws_vpc']
    
    if not vpc_resources:
        issues.append({
            'severity': 'WARNING',
            'message': 'No VPC configuration found in the plan'
        })
    else:
        # Check for private subnets
        subnet_resources = [r for r in resources if r.get('type') == 'aws_subnet']
        private_subnets = [s for s in subnet_resources if not s.get('values', {}).get('map_public_ip_on_launch', False)]
        
        if not private_subnets:
            issues.append({
                'severity': 'HIGH',
                'message': 'No private subnets defined in the architecture'
            })

    results['networking'] = {
        'passed': len(issues) == 0,
        'issues': issues
    }

def validate_security(plan_data, results):
    """Validate security components in the architecture"""
    issues = []
    
    # Check for security groups
    resources = plan_data.get('planned_values', {}).get('root_module', {}).get('resources', [])
    sg_resources = [r for r in resources if r.get('type') == 'aws_security_group']
    
    # Look for overly permissive security groups
    for sg in sg_resources:
        sg_values = sg.get('values', {})
        ingress_rules = sg_values.get('ingress', [])
        
        for rule in ingress_rules:
            if rule.get('cidr_blocks') and '0.0.0.0/0' in rule.get('cidr_blocks'):
                if rule.get('to_port') == 22:
                    issues.append({
                        'severity': 'CRITICAL',
                        'message': f"Security group {sg_values.get('name', 'unknown')} allows SSH access from the internet"
                    })
                else:
                    issues.append({
                        'severity': 'HIGH',
                        'message': f"Security group {sg_values.get('name', 'unknown')} allows access from the internet on port {rule.get('to_port')}"
                    })

    results['security'] = {
        'passed': len(issues) == 0,
        'issues': issues
    }

def validate_high_availability(plan_data, results):
    """Validate high availability aspects of the architecture"""
    issues = []
    
    # Check for resources across multiple AZs
    resources = plan_data.get('planned_values', {}).get('root_module', {}).get('resources', [])
    subnet_resources = [r for r in resources if r.get('type') == 'aws_subnet']
    
    # Group subnets by AZ
    az_distribution = {}
    for subnet in subnet_resources:
        az = subnet.get('values', {}).get('availability_zone')
        if az:
            az_distribution[az] = az_distribution.get(az, 0) + 1
    
    if len(az_distribution) < 2:
        issues.append({
            'severity': 'HIGH',
            'message': f"Architecture uses only {len(az_distribution)} Availability Zones. At least 2 are recommended for high availability."
        })

    results['high_availability'] = {
        'passed': len(issues) == 0,
        'issues': issues
    }

def validate_architecture(plan_data):
    """Main validation function"""
    results = {
        'overall_passed': True,
        'components': {}
    }
    
    # Perform component validations
    validate_networking(plan_data, results['components'])
    validate_security(plan_data, results['components'])
    validate_high_availability(plan_data, results['components'])
    
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
    
    # Create report directory if it doesn't exist
    Path(args.report_path).mkdir(parents=True, exist_ok=True)
    
    # Load and validate plan
    plan_data = load_plan(args.plan_file)
    if not plan_data:
        sys.exit(1)
    
    # Run validation
    logger.info("Starting architecture validation...")
    results = validate_architecture(plan_data)
    
    # Write results
    output_file = os.path.join(args.report_path, 'architecture_validation.json')
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)
    
    logger.info(f"Validation complete. Results written to {output_file}")
    
    # Exit with error if there are critical issues
    if results.get('has_critical_issues'):
        logger.error("Validation found critical issues that must be addressed!")
        sys.exit(1)
    
    if not results['overall_passed']:
        logger.warning("Validation found issues that should be reviewed")
        # Exit with 0 as warnings shouldn't fail the pipeline
        
    logger.info("Architecture validation successful")

if __name__ == "__main__":
    main()