#!/usr/bin/env python3
"""
Results analysis script for pre-deployment validation.
Analyzes validation reports and determines if deployment should proceed.
"""
import os
import sys
import json
import argparse
import logging
from pathlib import Path
import glob

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger('results-analyzer')

def parse_args():
    parser = argparse.ArgumentParser(description='Analyze validation results')
    parser.add_argument('--report-dir', required=True, help='Directory containing validation reports')
    parser.add_argument('--fail-on-critical', default="true", help='Whether to fail on critical issues (true/false)')
    parser.add_argument('--output-file', default='validation_summary.json', help='Output file for summary')
    return parser.parse_args()

def load_report(filename):
    """Load a JSON report file"""
    try:
        with open(filename, 'r') as f:
            return json.load(f)
    except Exception as e:
        logger.error(f"Failed to load report {filename}: {e}")
        return None

def analyze_architecture_validation(report_file, summary):
    """Analyze architecture validation report"""
    report = load_report(report_file)
    if not report:
        summary['reports']['architecture_validation'] = {
            'status': 'ERROR',
            'message': 'Failed to load architecture validation report'
        }
        return
    
    # Extract issues
    issues = []
    components = report.get('components', {})
    for component_name, component_data in components.items():
        component_issues = component_data.get('issues', [])
        for issue in component_issues:
            issues.append({
                'component': component_name,
                'severity': issue.get('severity', 'UNKNOWN'),
                'message': issue.get('message', 'Unknown issue')
            })
    
    # Determine overall status
    status = 'PASSED'
    if not report.get('overall_passed', True):
        status = 'WARNING'
    if report.get('has_critical_issues', False):
        status = 'FAILED'
    
    # Add to summary
    summary['reports']['architecture_validation'] = {
        'status': status,
        'issues_count': len(issues),
        'issues': issues,
        'has_critical': report.get('has_critical_issues', False)
    }
    
    # Update overall status
    if status == 'FAILED':
        summary['overall_status'] = 'FAILED'
    elif status == 'WARNING' and summary['overall_status'] == 'PASSED':
        summary['overall_status'] = 'WARNING'

def analyze_well_architected(report_file, summary):
    """Analyze Well-Architected Framework review report"""
    report = load_report(report_file)
    if not report:
        summary['reports']['well_architected'] = {
            'status': 'ERROR',
            'message': 'Failed to load Well-Architected Framework review report'
        }
        return
    
    # Extract issues that require review
    issues = []
    pillars = report.get('pillars', [])
    for pillar in pillars:
        pillar_name = pillar.get('pillar', 'Unknown')
        pillar_issues = pillar.get('issues', [])
        for issue in pillar_issues:
            if issue.get('status') == 'REVIEW_REQUIRED':
                issues.append({
                    'pillar': pillar_name,
                    'severity': issue.get('severity', 'UNKNOWN'),
                    'message': issue.get('message', 'Unknown issue')
                })
    
    # Determine status
    status = 'PASSED'
    if report.get('overall_status') == 'REVIEW_REQUIRED':
        status = 'WARNING'
    
    # Check for high severity issues
    has_high_severity = any(issue.get('severity') in ['HIGH', 'CRITICAL'] for issue in issues)
    
    # Add to summary
    summary['reports']['well_architected'] = {
        'status': status,
        'issues_count': len(issues),
        'issues': issues,
        'has_critical': has_high_severity
    }
    
    # Update overall status (Well-Architected issues don't fail the build)
    if status == 'WARNING' and summary['overall_status'] == 'PASSED':
        summary['overall_status'] = 'WARNING'

def analyze_dr_validation(report_file, summary):
    """Analyze DR architecture validation report"""
    report = load_report(report_file)
    if not report:
        # DR validation might not be present for all environments
        return
    
    # Extract issues
    issues = []
    components = report.get('components', {})
    for component_name, component_data in components.items():
        component_issues = component_data.get('issues', [])
        for issue in component_issues:
            issues.append({
                'component': component_name,
                'severity': issue.get('severity', 'UNKNOWN'),
                'message': issue.get('message', 'Unknown issue')
            })
    
    # Determine overall status
    status = 'PASSED'
    if not report.get('overall_passed', True):
        status = 'WARNING'
    if report.get('has_critical_issues', False):
        status = 'FAILED'
    
    # Add to summary
    summary['reports']['dr_validation'] = {
        'status': status,
        'issues_count': len(issues),
        'issues': issues,
        'has_critical': report.get('has_critical_issues', False)
    }
    
    # Update overall status
    if status == 'FAILED':
        summary['overall_status'] = 'FAILED'
    elif status == 'WARNING' and summary['overall_status'] == 'PASSED':
        summary['overall_status'] = 'WARNING'

def analyze_security_scan(report_file, summary):
    """Analyze security scanning report"""
    report = load_report(report_file)
    if not report:
        summary['reports']['security_scan'] = {
            'status': 'ERROR',
            'message': 'Failed to load security scan report'
        }
        return
    
    # For Checkov reports
    if isinstance(report, dict) and 'results' in report:
        failed_checks = report.get('results', {}).get('failed_checks', [])
        passed_checks = report.get('results', {}).get('passed_checks', [])
        
        # Extract issues from failed checks
        issues = []
        for check in failed_checks:
            issues.append({
                'severity': check.get('severity', 'UNKNOWN'),
                'message': check.get('check_name', 'Unknown issue'),
                'resource': check.get('resource', 'Unknown')
            })
        
        # Determine if there are any critical issues
        has_critical = any(issue['severity'] in ['CRITICAL', 'HIGH'] for issue in issues)
        
        # Determine overall status
        status = 'PASSED'
        if issues:
            status = 'WARNING'
        if has_critical:
            status = 'FAILED'
        
        # Add to summary
        summary['reports']['security_scan'] = {
            'status': status,
            'issues_count': len(issues),
            'passed_count': len(passed_checks),
            'issues': issues,
            'has_critical': has_critical
        }
        
        # Update overall status
        if status == 'FAILED':
            summary['overall_status'] = 'FAILED'
        elif status == 'WARNING' and summary['overall_status'] == 'PASSED':
            summary['overall_status'] = 'WARNING'

def main():
    args = parse_args()
    fail_on_critical = args.fail_on_critical.lower() == 'true'
    
    # Initialize summary
    summary = {
        'overall_status': 'PASSED',
        'reports': {}
    }
    
    # Find and analyze all reports
    report_dir = Path(args.report_dir)
    
    # Architecture validation
    architecture_report = report_dir / 'architecture_validation.json'
    if architecture_report.exists():
        analyze_architecture_validation(architecture_report, summary)
    
    # Well-Architected Framework review
    well_architected_report = report_dir / 'well_architected_review.json'
    if well_architected_report.exists():
        analyze_well_architected(well_architected_report, summary)
    
    # DR architecture validation
    dr_report = report_dir / 'dr_architecture_validation.json'
    if dr_report.exists():
        analyze_dr_validation(dr_report, summary)
    
    # Security scanning
    security_report = report_dir / 'security_scan.json'
    if security_report.exists():
        analyze_security_scan(security_report, summary)
    
    # Write summary report
    output_file = report_dir / args.output_file
    with open(output_file, 'w') as f:
        json.dump(summary, f, indent=2)
    
    logger.info(f"Analysis complete. Summary written to {output_file}")
    
    # Determine exit status
    if summary['overall_status'] == 'FAILED' and fail_on_critical:
        logger.error("Validation failed with critical issues that must be addressed!")
        sys.exit(1)
    
    if summary['overall_status'] == 'WARNING':
        logger.warning("Validation found issues that should be reviewed")
    
    logger.info("Validation analysis completed successfully")

if __name__ == "__main__":
    main()