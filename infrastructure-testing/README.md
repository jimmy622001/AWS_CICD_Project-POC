# Infrastructure Testing Framework

A comprehensive framework for testing AWS infrastructure security, functionality, architecture, and performance. This module is designed to work alongside the existing DR testing framework.

## Features

- **Security Testing**: Uses AWS Inspector, Security Hub, and GuardDuty to identify vulnerabilities and security issues.
- **Functionality Testing**: Implements CloudWatch Synthetics Canaries to test API endpoints.
- **Architecture Validation**: Leverages AWS Trusted Advisor and Well-Architected Framework to validate architecture.
- **Observability**: Integrates AWS X-Ray for performance monitoring and tracing.
- **Reporting**: Consolidates findings into comprehensive reports.

## Getting Started

### Prerequisites

- Terraform 0.14+
- AWS CLI configured with appropriate permissions
- S3 bucket for Terraform state (optional)

### Installation

1. Clone this repository
2. Navigate to the `infrastructure-testing` directory
3. Copy `terraform.tfvars.example` to `terraform.tfvars` and update with your configuration
4. Run the following commands:

```bash
terraform init
terraform plan
terraform apply
```

## Usage

### Running Tests in the Dev Environment

The framework is configured to automatically run tests in the dev environment according to the schedule specified in the `testing_schedule` variable. By default, comprehensive tests run weekly on Sunday at midnight.

To manually trigger a test run:

```bash
aws lambda invoke --function-name <project-name>-dev-test-orchestrator out.json
```

### Viewing Reports

Reports are stored in the S3 bucket specified during setup. You can access them via the AWS Console or CLI:

```bash
aws s3 ls s3://<your-bucket>/reports/
```

### CloudWatch Dashboards

The framework creates several CloudWatch dashboards:

1. Functionality Testing Dashboard: Shows API test results
2. X-Ray Dashboard: Shows performance metrics
3. Security Dashboard: Shows security findings

Access these dashboards in the CloudWatch console.

## Module Structure

- **Security Testing**: AWS Inspector, Security Hub, GuardDuty
- **Functionality Testing**: CloudWatch Synthetics Canaries
- **Architecture Validation**: Trusted Advisor checks, Well-Architected reviews
- **Observability**: AWS X-Ray integration
- **Reporting**: Aggregated reports and notifications

## Configuration Options

See `variables.tf` for all configuration options. Key variables include:

- `project_name`: Name of your project
- `environment`: Deployment environment (e.g., dev, test, prod)
- `api_endpoints`: List of API endpoints to test
- `notification_email`: Email for alerts and reports
- Various schedules for different test components

## Extending the Framework

### Adding Custom Tests

1. Create a new Lambda function in the appropriate module
2. Update the module's `main.tf` to include the new function
3. Add necessary IAM permissions
4. Integrate with the test orchestrator

### Adding New Testing Tools

1. Create a new module under the `modules` directory
2. Define inputs and outputs in `variables.tf` and `outputs.tf`
3. Implement the testing logic in `main.tf`
4. Reference the new module in the root `main.tf`

## License

This project is licensed under the MIT License - see the LICENSE file for details.