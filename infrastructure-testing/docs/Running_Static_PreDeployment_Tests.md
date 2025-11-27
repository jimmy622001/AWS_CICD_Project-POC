# Running Static Pre-Deployment Tests

This guide provides detailed instructions for running static pre-deployment validation tests for infrastructure code before any resources are provisioned.

## Overview

Static pre-deployment tests analyze your Infrastructure as Code (IaC) files to identify potential issues related to:

- Architecture design and best practices
- Security vulnerabilities and misconfigurations
- Compliance with industry standards and organizational policies
- Cost optimization opportunities
- Well-Architected Framework alignment

These tests help catch issues early in the development cycle, reducing the need for costly fixes later.

## Prerequisites

Before running static pre-deployment tests, ensure you have:

### Software Requirements

- Python 3.9 or higher
- Terraform 1.0.0 or higher
- AWS CLI configured with appropriate permissions
- Checkov (`pip install checkov`)
- TFLint (`brew install tflint` or download from GitHub)

### Configuration Files

- Valid AWS credentials (for AWS Well-Architected Tool integration)
- `.checkov.yaml` (optional, for customizing Checkov rules)
- `architecture_rules.json` (custom architecture validation rules)

## Running Tests Locally

### 1. Basic Terraform Validation

```bash
# Navigate to your infrastructure code directory
cd path/to/terraform/code

# Initialize Terraform
terraform init

# Validate Terraform syntax
terraform validate

# Create a plan file for deeper analysis
terraform plan -out=tfplan

# Convert to JSON format for analysis
Use `terraform show -json tfplan` to output the plan in JSON format
2. Architecture Validation
# Run the architecture validation script
python infrastructure-testing/modules/architecture_validation/scripts/validate_architecture.py \
  --terraform-path ./environments/dev \
  --rules-path ./infrastructure-testing/modules/architecture_validation/rules/architecture_rules.json \
  --output-path ./validation-reports/architecture-validation.json
3. Security Scanning with Checkov
# Run Checkov against Terraform files
checkov -d ./environments/dev --framework terraform --output json \
  --output-file-path ./validation-reports/security-validation.json

# For specific checks only
checkov -d ./environments/dev --framework terraform --check CKV_AWS_1,CKV_AWS_2
4. AWS Well-Architected Review
# Run Well-Architected review
python infrastructure-testing/modules/architecture_validation/scripts/well_architected_review.py \
  --workload-id your-workload-id \
  --terraform-path ./environments/dev \
  --output-path ./validation-reports/well-architected-review.json
5. Running All Tests Together
We provide a convenience script to run all static validation tests at once:

# Navigate to the project root
cd /path/to/project/root

# Run the combined validation script
./infrastructure-testing/scripts/run_static_validation.sh --environment dev
Running Tests in CI/CD Pipeline
Triggering Tests Manually
To manually trigger the pre-deployment validation pipeline:

Push to the feature/pre-deployment-validation branch:
git checkout feature/pre-deployment-validation
git add .
git commit -m "Run pre-deployment validation"
git push origin feature/pre-deployment-validation
Or use the AWS CLI to start the pipeline:
aws codepipeline start-pipeline-execution --name PreDeploymentValidationPipeline
Understanding Pipeline Results
Accessing Reports:
Pipeline reports are stored in the S3 bucket defined in the pipeline configuration
Reports are also available in the CodeBuild execution details
Interpreting Results:
The pipeline will fail if critical issues are found
Warning-level issues allow the pipeline to continue but are reported
Review the validation-results.json file for a summary of all findings
Test Configuration
Customizing Architecture Validation Rules
Edit the infrastructure-testing/modules/architecture_validation/rules/architecture_rules.json file:

{
  "rules": [
    {
      "id": "VPC-001",
      "name": "VPC CIDR Size",
      "description": "VPC CIDR block should be at least /16",
      "resource_type": "aws_vpc",
      "property": "cidr_block",
      "condition": "regex_match",
      "value": "^\\d+\\.\\d+\\.0\\.0/1[6-9]$|^\\d+\\.\\d+\\.0\\.0/[2-9]$",
      "severity": "HIGH"
    }
  ]
}
Setting Severity Thresholds
Edit the .checkov.yaml file to customize Checkov behavior:

soft-fail: true
check:
  - CKV_AWS*
skip-check:
  - CKV_AWS_123  # Skip specific check
  - CKV_AWS_456
framework:
  - terraform
output:
  - json
Environment-Specific Rules
Create environment-specific rule files:

infrastructure-testing/
├── rules/
│   ├── dev/
│   │   └── rules.json
│   ├── staging/
│   │   └── rules.json
│   └── prod/
│       └── rules.json
Troubleshooting Common Issues
Missing Dependencies
If you encounter errors about missing dependencies:

# Install all required Python dependencies
pip install -r infrastructure-testing/requirements.txt
AWS Authentication Issues
For Well-Architected Tool integration issues:

# Verify AWS credentials
aws sts get-caller-identity

# Set specific profile if needed
export AWS_PROFILE=your-profile-name
Terraform Plan Failures
If terraform plan fails:

# Clean Terraform state and try again
rm -rf .terraform
terraform init
terraform plan
Best Practices
Run Tests Early and Often:
Run static validation before committing code
Use pre-commit hooks to automate validation
Tailor Rules to Your Environment:
Start with stricter rules for production
Customize rules based on your architectural standards
Progressive Validation:
Use different validation thresholds for different environments
More permissive in dev, stricter in production
Continuous Improvement:
Review validation results regularly
Update rules based on lessons learned
Integration with Development Workflow:
Use IDE plugins for real-time validation
Integrate results with code review tools
Examples
Example: Validating a New VPC Configuration
# From project root
cd environments/dev/networking

# Run targeted validation
python ../../../infrastructure-testing/modules/architecture_validation/scripts/validate_architecture.py \
  --terraform-path . \
  --resource-type aws_vpc
Example: Full Pre-Deployment Report
# Generate a comprehensive report
./infrastructure-testing/scripts/generate_validation_report.sh \
  --environment dev \
  --output-format html \
  --output-path ./reports/dev-validation-report.html
Conclusion
Running static pre-deployment tests is a critical step in ensuring your infrastructure meets architectural, security, and compliance standards before deployment. By integrating these tests into your development workflow, you can catch issues early and improve the quality of your infrastructure code.