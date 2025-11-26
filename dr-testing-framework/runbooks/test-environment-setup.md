# Test Environment Setup Runbook

## Overview

This runbook provides step-by-step instructions for setting up AWS test environments for disaster recovery testing.

## Prerequisites

- AWS CLI installed and configured
- Appropriate IAM permissions
- Terraform (if using infrastructure as code)
- InSpec installed for compliance testing
- Access to required AWS accounts

## Environment Setup Procedure

### 1. AWS CLI Configuration

```bash
# Install AWS CLI if needed
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS CLI with test credentials
aws configure --profile dr-test-profile
```

### 2. Test Environment Parameters

1. Review and modify the environment configuration in `config/test-environments.json`
2. Ensure the configuration includes:
   - VPC settings
   - Subnet configurations
   - Security groups
   - Required AWS services

### 3. Infrastructure Deployment

#### Using Terraform

```bash
cd terraform/test-env

# Initialize Terraform
terraform init

# Create a plan
terraform plan -var-file=../../config/test-environments.json -out=tfplan

# Apply the plan
terraform apply tfplan
```

#### Using AWS CloudFormation

```bash
aws cloudformation deploy \
  --template-file templates/test-environment.yaml \
  --stack-name dr-test-environment \
  --parameter-overrides $(cat config/test-environments.json) \
  --capabilities CAPABILITY_IAM
```

### 4. Validation Steps

1. Run infrastructure validation tests:

```bash
cd inspec
inspec exec profiles/dev -t aws://region --reporter cli json:output.json
```

2. Verify that all required services are running:

```bash
# Check EC2 instances
aws ec2 describe-instances --filters "Name=tag:Environment,Values=dr-test" --query "Reservations[*].Instances[*].[InstanceId,State.Name]" --output table

# Check RDS instances
aws rds describe-db-instances --query "DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus]" --output table
```

3. Validate network connectivity:

```bash
# Test VPC connectivity
aws ec2 describe-vpc-peering-connections --filters "Name=tag:Environment,Values=dr-test" --query "VpcPeeringConnections[*].[VpcPeeringConnectionId,Status.Code]" --output table
```

### 5. Monitoring Setup

1. Deploy CloudWatch dashboards:

```bash
python scripts/monitoring/create-test-dashboard.py --env dr-test
```

2. Set up test-specific alarms:

```bash
bash scripts/monitoring/alert-setup.sh --env dr-test
```

### 6. Test Data Setup

1. Deploy test data to appropriate services:

```bash
# Example for RDS
aws rds-data execute-statement --resource-arn [DB_CLUSTER_ARN] --secret-arn [SECRET_ARN] --database [DB_NAME] --sql "$(cat data/test-data.sql)"

# Example for DynamoDB
python scripts/data/load-dynamodb-test-data.py --table [TABLE_NAME]
```

2. Validate test data:

```bash
# Example for RDS
aws rds-data execute-statement --resource-arn [DB_CLUSTER_ARN] --secret-arn [SECRET_ARN] --database [DB_NAME] --sql "SELECT COUNT(*) FROM test_table"
```

## Cleanup Procedure

When testing is complete, clean up the test environment:

### Using Terraform

```bash
cd terraform/test-env
terraform destroy -var-file=../../config/test-environments.json
```

### Using AWS CloudFormation

```bash
aws cloudformation delete-stack --stack-name dr-test-environment
```

### Manual Cleanup Checklist

- [ ] Terminate EC2 instances
- [ ] Delete RDS instances
- [ ] Remove S3 buckets
- [ ] Delete CloudWatch dashboards
- [ ] Remove CloudWatch alarms
- [ ] Delete IAM roles created for testing

## Troubleshooting

### Common Issues

1. **Insufficient Permissions**: Ensure the IAM role/user has all required permissions
2. **Resource Limits**: Check if you've hit AWS service limits
3. **Network Configuration**: Validate VPC and subnet settings
4. **Failed Dependencies**: Ensure all referenced resources exist

### Support Contacts

- AWS Account Team: [Contact Information]
- DevOps Team: [Contact Information]
- DR Test Coordinator: [Contact Information]