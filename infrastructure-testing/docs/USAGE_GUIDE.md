# Infrastructure Testing Framework - Usage Guide

This guide provides detailed instructions on how to use the Infrastructure Testing Framework across different environments, with specific configuration guidance and operational procedures.

## Table of Contents

- [Overview](#overview)
- [Deployment Instructions](#deployment-instructions)
  - [Prerequisite Setup](#prerequisite-setup)
  - [Deployment to Dev Environment](#deployment-to-dev-environment)
  - [Deployment to Test Environment](#deployment-to-test-environment)
  - [Deployment to Production Environment](#deployment-to-production-environment)
- [Configuration Guide](#configuration-guide)
  - [Essential Configuration Parameters](#essential-configuration-parameters)
  - [Environment-Specific Settings](#environment-specific-settings)
  - [Testing Frequency Recommendations](#testing-frequency-recommendations)
- [Operating the Framework](#operating-the-framework)
  - [Manual Test Execution](#manual-test-execution)
  - [Accessing Test Reports](#accessing-test-reports)
  - [Monitoring Test Results](#monitoring-test-results)
  - [Acting on Test Findings](#acting-on-test-findings)
- [Integration with CI/CD Pipelines](#integration-with-cicd-pipelines)
- [Troubleshooting](#troubleshooting)
- [Extending the Framework](#extending-the-framework)
- [Best Practices](#best-practices)
- [Reference](#reference)

## Overview

The Infrastructure Testing Framework provides comprehensive testing capabilities for AWS infrastructure:

- **Security Testing**: AWS Inspector, Security Hub, and GuardDuty integration
- **Functionality Testing**: CloudWatch Synthetics Canaries for API validation
- **Architecture Validation**: AWS Trusted Advisor and Well-Architected Framework checks
- **Observability**: X-Ray integration for performance monitoring
- **Reporting**: Consolidated reports with findings and actionable recommendations

## Deployment Instructions

### Prerequisite Setup

1. **AWS Account Setup**:
   - Ensure your AWS CLI is configured with the appropriate credentials
   - Verify you have permissions to create Lambda functions, CloudWatch resources, IAM roles, etc.

2. **Terraform Installation**:
   - Install Terraform v0.14+ (latest version recommended)
   - Verify installation: `terraform --version`

3. **Required Tools**:
   - AWS CLI v2+
   - Python 3.8+ (for local development)
   - Zip utility (for packaging Lambda functions)

### Deployment to Dev Environment

1. **Prepare Configuration**:
   ```bash
   cd infrastructure-testing
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit Configuration File**:
   Update `terraform.tfvars` with your dev environment values:
   - Set `environment = "dev"`
   - Update `vpc_id` with your dev VPC ID
   - Configure `api_endpoints` with your dev API URLs
   - Set `notification_email` to your team's email address

3. **Deploy Using the Script**:
   ```bash
   ./scripts/deploy_to_dev.sh
   ```
   
   The script will:
   - Package all Lambda functions
   - Initialize Terraform
   - Create a deployment plan
   - Deploy resources after your confirmation

4. **Verify Deployment**:
   - Check the AWS Console to confirm resources were created
   - Review the CloudWatch Dashboards
   - Wait for the initial test report via email (or trigger a test manually)

### Deployment to Test Environment

1. **Create Environment-Specific Configuration**:
   ```bash
   cp terraform.tfvars test.tfvars
   ```

2. **Edit Test Environment Configuration**:
   Update `test.tfvars` with your test environment values:
   - Set `environment = "test"`
   - Update `vpc_id` with your test VPC ID
   - Configure `api_endpoints` with your test API URLs
   - Adjust testing schedules as needed

3. **Deploy to Test Environment**:
   ```bash
   terraform init
   terraform workspace new test
   terraform plan -var-file=test.tfvars -out=testplan
   terraform apply testplan
   ```

4. **Validate Test Environment Deployment**:
   - Verify resources in AWS Console
   - Check CloudWatch dashboards for the test environment
   - Run a manual test to confirm functionality

### Deployment to Production Environment

1. **Create Production Configuration**:
   ```bash
   cp terraform.tfvars prod.tfvars
   ```

2. **Edit Production Environment Configuration**:
   Update `prod.tfvars` with your production values:
   - Set `environment = "prod"`
   - Update `vpc_id` with your production VPC ID
   - Configure `api_endpoints` with your production API URLs
   - Adjust testing schedules (typically less frequent than dev/test)
   - Consider enabling additional security checks

3. **Deploy to Production Environment**:
   ```bash
   terraform init
   terraform workspace new prod
   terraform plan -var-file=prod.tfvars -out=prodplan
   
   # Review the plan carefully before proceeding
   terraform apply prodplan
   ```

4. **Production Deployment Verification**:
   - Verify all resources in AWS Console
   - Confirm notification emails are working
   - Review initial test results
   - Validate dashboard accessibility

## Configuration Guide

### Essential Configuration Parameters

| Parameter | Description | Example Value |
|-----------|-------------|---------------|
| project_name | Your project identifier | "customer-portal" |
| environment | Deployment environment | "dev", "test", "prod" |
| region | AWS region | "us-east-1" |
| account_id | AWS account ID | "123456789012" |
| vpc_id | VPC to test | "vpc-0123456789abcdef0" |
| notification_email | Email for reports | "team@example.com" |
| api_endpoints | APIs to test | See example below |

**API Endpoints Configuration Example**:
```hcl
api_endpoints = [
  {
    name = "health-check"
    url = "https://api.example.com/health"
    method = "GET"
    expected_status_code = 200
  },
  {
    name = "users-api"
    url = "https://api.example.com/users"
    method = "GET"
    expected_status_code = 200
  }
]
```

### Environment-Specific Settings

**Development Environment**:
- More frequent testing (e.g., daily for some tests)
- Higher X-Ray sampling rate (0.1-0.2)
- All security checks enabled for early detection

**Test Environment**:
- Moderate testing frequency
- Medium X-Ray sampling rate (0.05-0.1)
- Focus on functionality testing for integration validation

**Production Environment**:
- Less frequent testing (weekly/monthly)
- Lower X-Ray sampling rate (0.01-0.05)
- More comprehensive but carefully scheduled security tests
- Enhanced notifications for critical issues

### Testing Frequency Recommendations

| Component | Dev | Test | Prod |
|-----------|-----|------|------|
| API Canaries | Every 5 min | Every 15 min | Every 30 min |
| Security Inspector | Daily | Weekly | Weekly |
| Trusted Advisor | Daily | Weekly | Weekly |
| Well-Architected | Weekly | Monthly | Monthly |
| Comprehensive Reports | Daily | Weekly | Weekly |

## Operating the Framework

### Manual Test Execution

**Running a Complete Test Suite**:
```bash
# Replace with your actual function name
aws lambda invoke \
  --function-name ${project_name}-${env}-test-orchestrator \
  --payload '{"runType": "full"}' \
  output.json
```

**Running Specific Tests**:
```bash
# For security tests only
aws lambda invoke \
  --function-name ${project_name}-${env}-test-orchestrator \
  --payload '{"runType": "security"}' \
  output.json

# For functionality tests only
aws lambda invoke \
  --function-name ${project_name}-${env}-test-orchestrator \
  --payload '{"runType": "functionality"}' \
  output.json
```

### Accessing Test Reports

1. **Via S3 Bucket**:
   ```bash
   # List available reports
   aws s3 ls s3://${project_name}-${env}-test-reports/
   
   # Download latest report
   aws s3 cp s3://${project_name}-${env}-test-reports/latest/summary.pdf ./latest-report.pdf
   ```

2. **Via Email**:
   - Reports are automatically sent to the configured notification email
   - Check your email after scheduled test runs or manual triggers

3. **Via CloudWatch**:
   - Navigate to CloudWatch Logs
   - Find the log group for the report generator Lambda function
   - Review the execution logs for report details

### Monitoring Test Results

1. **CloudWatch Dashboards**:
   - Navigate to CloudWatch > Dashboards in the AWS Console
   - Select one of the framework dashboards:
     - `${project_name}-${env}-functionality-dashboard`
     - `${project_name}-${env}-security-dashboard`
     - `${project_name}-${env}-architecture-dashboard`

2. **Security Hub**:
   - For security findings, check AWS Security Hub
   - Filter by severity to prioritize critical issues

3. **Trusted Advisor**:
   - View architecture recommendations in AWS Trusted Advisor console
   - Findings are also consolidated in the framework reports

### Acting on Test Findings

1. **Prioritize Issues**:
   - Security: Critical > High > Medium > Low
   - Functionality: Failed APIs > Performance Degradation
   - Architecture: Cost Optimization > Performance > Security > Reliability

2. **Remediation Workflow**:
   - Review detailed findings in the comprehensive report
   - Assign issues to appropriate team members
   - Document remediation steps taken
   - Verify fixes by re-running specific tests

3. **Continuous Improvement**:
   - Use monthly trend reports to track improvements
   - Adjust testing parameters based on findings
   - Expand test coverage for problematic areas

## Integration with CI/CD Pipelines

### AWS CodePipeline Integration

Add infrastructure testing to your CI/CD pipeline:

1. **Add Test Stage**:
   ```json
   {
     "name": "InfrastructureTesting",
     "actions": [
       {
         "name": "RunTests",
         "actionTypeId": {
           "category": "Invoke",
           "owner": "AWS",
           "provider": "Lambda",
           "version": "1"
         },
         "configuration": {
           "FunctionName": "${project_name}-${env}-test-orchestrator",
           "UserParameters": "{\"runType\": \"functionality\"}"
         }
       }
     ]
   }
   ```

2. **Add Approval Gate** (for production):
   ```json
   {
     "name": "ApproveDeployment",
     "actions": [
       {
         "name": "ManualApproval",
         "actionTypeId": {
           "category": "Approval",
           "owner": "AWS",
           "provider": "Manual",
           "version": "1"
         },
         "configuration": {
           "CustomData": "Review the infrastructure test report before proceeding"
         }
       }
     ]
   }
   ```

### GitHub Actions Integration

For GitHub-based workflows:

```yaml
jobs:
  infrastructure-testing:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Run Infrastructure Tests
        run: |
          aws lambda invoke \
            --function-name ${PROJECT_NAME}-${ENV}-test-orchestrator \
            --payload '{"runType": "full"}' \
            output.json
          
      - name: Check Test Results
        run: |
          RESULT=$(cat output.json | jq -r '.status')
          if [ "$RESULT" != "success" ]; then
            echo "Infrastructure tests failed"
            exit 1
          fi
```

## Troubleshooting

### Common Issues

1. **Lambda Function Timeouts**:
   - Check CloudWatch Logs for the specific Lambda function
   - Increase timeout settings if necessary
   - Consider breaking larger tests into smaller components

2. **Missing Permissions**:
   - Review CloudTrail for Access Denied errors
   - Check IAM roles and policies
   - Update policy documents as needed

3. **Test Report Generation Failures**:
   - Check S3 bucket permissions
   - Verify Lambda execution role has S3 write access
   - Check for any Lambda errors in CloudWatch Logs

4. **Email Notifications Not Received**:
   - Verify email address is verified in SES
   - Check SES sending limits and quota
   - Review SES delivery status in CloudWatch Logs

### Diagnostic Tools

1. **Checking Lambda Function Status**:
   ```bash
   aws lambda get-function --function-name ${project_name}-${env}-test-orchestrator
   ```

2. **Viewing Recent Execution Logs**:
   ```bash
   aws logs get-log-events \
     --log-group-name /aws/lambda/${project_name}-${env}-test-orchestrator \
     --log-stream-name $(aws logs describe-log-streams \
       --log-group-name /aws/lambda/${project_name}-${env}-test-orchestrator \
       --order-by LastEventTime \
       --descending \
       --max-items 1 \
       --query 'logStreams[0].logStreamName' \
       --output text)
   ```

3. **Testing Synthetic Canaries**:
   ```bash
   aws synthetics describe-canaries \
     --names ${project_name}-${env}-api-canary
   ```

## Extending the Framework

### Adding New API Endpoints

1. Update your `terraform.tfvars` file with new endpoints:
   ```hcl
   api_endpoints = [
     # Existing endpoints...
     {
       name = "new-endpoint"
       url = "https://api.example.com/new-feature"
       method = "POST"
       expected_status_code = 201
     }
   ]
   ```

2. Reapply the Terraform configuration:
   ```bash
   terraform apply
   ```

### Adding Custom Security Tests

1. Create a new Lambda function in the security module directory
2. Update the security module's `main.tf` file
3. Add appropriate IAM permissions
4. Integrate with the orchestrator Lambda

### Creating Custom Reports

1. Modify the report generator Lambda function:
   - Add new sections
   - Customize formatting
   - Include additional metrics

2. Update the report notifier Lambda for new distribution options

## Best Practices

1. **Environment-Specific Approaches**:
   - **Dev**: Frequent testing, immediate alerts, focus on early detection
   - **Test**: Balance between test frequency and resource usage
   - **Prod**: Careful scheduling, focus on minimal impact, comprehensive reporting

2. **Security Testing Best Practices**:
   - Enable all security services in dev for early detection
   - Schedule intensive security scans during off-hours in production
   - Implement immediate notifications for critical findings

3. **API Testing Best Practices**:
   - Include both simple health checks and complex business logic tests
   - Monitor performance trends over time
   - Test with realistic data patterns

4. **Reporting Best Practices**:
   - Consolidate findings into actionable recommendations
   - Include trend analysis in periodic reports
   - Categorize issues by severity and impact

5. **Resource Management**:
   - Optimize Lambda memory allocations based on usage patterns
   - Consider costs when setting X-Ray sampling rates
   - Monitor resource usage and adjust as needed

## Reference

### AWS Services Used

- **AWS Lambda**: Core testing functions and orchestration
- **CloudWatch Synthetics**: API testing with canaries
- **AWS Inspector**: Vulnerability assessment
- **Security Hub**: Security best practice checks
- **GuardDuty**: Threat detection
- **Trusted Advisor**: Cost and performance optimization
- **AWS X-Ray**: Performance tracing
- **CloudWatch**: Metrics, logs, and dashboards
- **Amazon S3**: Report storage
- **Amazon SES**: Email notifications

### Useful AWS CLI Commands

```bash
# List test resources
aws cloudformation list-stack-resources --stack-name ${project_name}-${env}-test-infrastructure

# List synthetic canaries
aws synthetics describe-canaries

# View GuardDuty findings
aws guardduty list-findings --detector-id ${detector_id}

# List Security Hub findings
aws securityhub get-findings

# View Trusted Advisor check results
aws support describe-trusted-advisor-checks --language en
```

### Related Documentation

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS Security Best Practices](https://aws.amazon.com/security/security-resources/)
- [CloudWatch Synthetics Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Synthetics_Canaries.html)
- [AWS X-Ray Documentation](https://docs.aws.amazon.com/xray/latest/devguide/aws-xray.html)