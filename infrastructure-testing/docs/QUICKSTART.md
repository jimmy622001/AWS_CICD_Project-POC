# Infrastructure Testing Framework - Quick Start Guide

This guide will help you quickly set up and start using the Infrastructure Testing Framework for your AWS environments.

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI installed and configured
- Terraform v0.14+ installed
- Basic understanding of AWS services (Lambda, CloudWatch, S3)

## 5-Minute Setup

Follow these steps to quickly deploy the framework to your development environment:

### Step 1: Clone and Configure

```bash
# Navigate to the infrastructure testing directory
cd infrastructure-testing

# Copy the example configuration
cp terraform.tfvars.example terraform.tfvars
```

### Step 2: Edit Configuration

Edit `terraform.tfvars` with your specific values:

```hcl
project_name      = "your-project-name"
environment       = "dev"
region            = "us-east-1"  # Change to your preferred region
account_id        = "123456789012"  # Your AWS Account ID
vpc_id            = "vpc-0123456789abcdef0"  # Your VPC ID
notification_email = "your-email@example.com"

# Add at least one API endpoint to test
api_endpoints = [
  {
    name = "health-check"
    url = "https://your-api.example.com/health"
    method = "GET"
    expected_status_code = 200
  }
]
```

### Step 3: Deploy the Framework

```bash
# Run the deployment script
./scripts/deploy_to_dev.sh
```

The script will:
1. Create Lambda function packages
2. Initialize Terraform
3. Plan the deployment
4. Apply the configuration after your confirmation

### Step 4: Verify Deployment

After deployment completes, you should see outputs including:

- S3 bucket URL for test reports
- CloudWatch dashboard URLs
- Lambda function names

## First Test Run

To trigger your first test run manually:

```bash
# Replace with your actual project name from the configuration
aws lambda invoke \
  --function-name your-project-name-dev-test-orchestrator \
  --payload '{"runType": "full"}' \
  output.json

# Check the output
cat output.json
```

## Accessing Your First Results

### View Test Reports

```bash
# List available reports
aws s3 ls s3://your-project-name-dev-test-reports/

# Download the latest summary report
aws s3 cp s3://your-project-name-dev-test-reports/latest/summary.pdf ./latest-report.pdf
```

### Check CloudWatch Dashboards

1. Open the AWS Console
2. Navigate to CloudWatch > Dashboards
3. Look for dashboards with names like:
   - `your-project-name-dev-security-dashboard`
   - `your-project-name-dev-functionality-dashboard`
   - `your-project-name-dev-architecture-dashboard`

## Common Tasks

### Running Specific Tests

```bash
# Security tests only
aws lambda invoke \
  --function-name your-project-name-dev-test-orchestrator \
  --payload '{"runType": "security"}' \
  output.json

# Functionality tests only
aws lambda invoke \
  --function-name your-project-name-dev-test-orchestrator \
  --payload '{"runType": "functionality"}' \
  output.json

# Architecture validation only
aws lambda invoke \
  --function-name your-project-name-dev-test-orchestrator \
  --payload '{"runType": "architecture"}' \
  output.json
```

### Generating a Custom Report

```bash
aws lambda invoke \
  --function-name your-project-name-dev-report-generator \
  --payload '{"reportType": "custom", "startDate": "2023-01-01", "endDate": "2023-01-31"}' \
  report_output.json
```

### Adding a New API Endpoint to Test

Edit your `terraform.tfvars` file:

```hcl
api_endpoints = [
  # Existing endpoints...
  {
    name = "new-endpoint"
    url = "https://api.example.com/new"
    method = "GET"
    expected_status_code = 200
  }
]
```

Then reapply the Terraform configuration:

```bash
terraform apply
```

## Next Steps

After completing the quick start, consider these next steps:

1. **Explore Documentation**:
   - Read the [Usage Guide](USAGE_GUIDE.md) for detailed usage instructions
   - Check the [Environment Strategy](ENVIRONMENT_STRATEGY.md) for multi-environment setup
   - Review [CI/CD Integration](CICD_INTEGRATION.md) for pipeline integration

2. **Expand Your Testing**:
   - Add more API endpoints to test
   - Configure Security Hub standards
   - Set up X-Ray tracing for your applications

3. **Customize Reporting**:
   - Adjust notification settings
   - Create custom report templates
   - Set up regular report delivery

4. **Deploy to Additional Environments**:
   - Create test.tfvars and prod.tfvars for other environments
   - Adjust testing frequencies for each environment
   - Configure environment-specific notification recipients

## Troubleshooting

### Common Issues

1. **Lambda Packaging Errors**:
   ```bash
   # Manually create Lambda ZIP files
   cd modules/security_testing/lambda
   zip -r process_inspector_findings.zip process_inspector_findings.py
   # Repeat for other Lambda functions
   ```

2. **Permission Issues**:
   - Check that your AWS user/role has the necessary permissions
   - Review CloudTrail for Access Denied errors

3. **Email Notifications Not Arriving**:
   - Verify your email is confirmed in Amazon SES
   - Check SES sending limits and restrictions

4. **Test Failures**:
   - Check CloudWatch Logs for specific error details:
   ```bash
   aws logs get-log-events \
     --log-group-name /aws/lambda/your-project-name-dev-test-orchestrator \
     --log-stream-name $(aws logs describe-log-streams \
       --log-group-name /aws/lambda/your-project-name-dev-test-orchestrator \
       --order-by LastEventTime \
       --descending \
       --max-items 1 \
       --query 'logStreams[0].logStreamName' \
       --output text)
   ```

## Quick Reference

### Key Commands

| Task | Command |
|------|---------|
| Deploy to dev | `./scripts/deploy_to_dev.sh` |
| Run all tests | `aws lambda invoke --function-name ${project}-${env}-test-orchestrator --payload '{"runType": "full"}' output.json` |
| Generate report | `aws lambda invoke --function-name ${project}-${env}-report-generator --payload '{"reportType": "default"}' report.json` |
| Download report | `aws s3 cp s3://${project}-${env}-test-reports/latest/summary.pdf ./report.pdf` |
| Check test logs | `aws logs get-log-events --log-group-name /aws/lambda/${project}-${env}-test-orchestrator` |

### Key Resources

| Resource | Description |
|----------|-------------|
| `${project}-${env}-test-orchestrator` | Main Lambda function for triggering tests |
| `${project}-${env}-report-generator` | Lambda function for generating reports |
| `${project}-${env}-test-reports` | S3 bucket containing test reports |
| `${project}-${env}-security-dashboard` | CloudWatch dashboard for security findings |
| `${project}-${env}-functionality-dashboard` | CloudWatch dashboard for API test results |