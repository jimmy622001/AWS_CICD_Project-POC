#!/bin/bash
# Script to deploy the Infrastructure Testing Framework to dev environment

# Display banner
echo "=============================================="
echo "Infrastructure Testing Framework Deployment"
echo "=============================================="

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "Error: Terraform is not installed. Please install Terraform and try again."
    exit 1
fi

# Navigate to the infrastructure-testing directory
cd "$(dirname "$0")/.." || exit 1

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "Error: terraform.tfvars not found. Please create it from terraform.tfvars.example."
    echo "Would you like to create it now? (y/n)"
    read -r create_vars
    if [[ "$create_vars" == "y" ]]; then
        cp terraform.tfvars.example terraform.tfvars
        echo "Created terraform.tfvars. Please edit it with your specific values."
        exit 0
    else
        exit 1
    fi
fi

# Create directories for Lambda zip files if they don't exist
echo "Setting up Lambda code directories..."
mkdir -p modules/security_testing/lambda
mkdir -p modules/functionality_testing/lambda
mkdir -p modules/architecture_validation/lambda
mkdir -p modules/observability/lambda
mkdir -p modules/reporting/lambda
mkdir -p lambda

# Create ZIP files for Lambda functions
echo "Creating Lambda function packages..."

# Security testing Lambda functions
cd modules/security_testing/lambda || exit 1
zip -r process_inspector_findings.zip process_inspector_findings.py
cd ../../../

# Functionality testing Lambda functions
cd modules/functionality_testing/lambda || exit 1
zip -r process_canary_results.zip process_canary_results.py
cd ../scripts || exit 1
zip -r api_canary.zip api_canary.js
cd ../../../

# Architecture validation Lambda functions
cd modules/architecture_validation/lambda || exit 1
zip -r trusted_advisor_refresh.zip trusted_advisor_refresh.py
zip -r process_trusted_advisor.zip process_trusted_advisor.py
zip -r well_architected_review.zip well_architected_review.py
cd ../../../

# Observability Lambda functions
cd modules/observability/lambda || exit 1
zip -r xray_insights.zip xray_insights.py
cd ../../../

# Reporting Lambda functions
cd modules/reporting/lambda || exit 1
zip -r report_generator.zip report_generator.py
zip -r report_notifier.zip report_notifier.py
cd ../../../

# Main orchestrator Lambda
cd lambda || exit 1
zip -r test_orchestrator.zip orchestrator.py
cd ../

echo "Starting Terraform deployment..."

# Initialize Terraform
terraform init

# Plan the deployment
echo "Planning deployment..."
terraform plan -out=tfplan

# Ask for confirmation
echo
echo "Ready to deploy to dev environment. Proceed? (y/n)"
read -r proceed
if [[ "$proceed" != "y" ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Apply the plan
echo "Applying deployment..."
terraform apply tfplan

# Show outputs
echo
echo "Deployment complete. Outputs:"
terraform output

echo
echo "=============================================="
echo "Infrastructure Testing Framework is now deployed to dev!"
echo "=============================================="
echo
echo "Next steps:"
echo "1. Check the S3 bucket for test reports"
echo "2. Monitor CloudWatch dashboards for test results"
echo "3. Wait for email notifications or trigger tests manually"
echo