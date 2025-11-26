# DR Testing Framework Configuration Guide

This guide explains how to configure the DR testing framework for the AWS_CICD_Project.

## Configuration Overview

The DR testing framework uses several configuration files to customize tests for your specific AWS environment. These configurations control:

1. Test environments (primary and DR)
2. AWS regions and availability zones
3. Test parameters and thresholds
4. Services to test
5. Pipeline settings

## Configuration Files

### 1. Test Environments Configuration

Located at `config/test-environments.json`:

```json
{
  "environments": {
    "primary": {
      "name": "Production",
      "region": "us-west-2",
      "vpc_cidr": "10.0.0.0/16",
      "subnets": [
        "10.0.1.0/24",
        "10.0.2.0/24"
      ],
      "instances": [
        {
          "type": "web",
          "count": 2,
          "size": "t3.medium"
        },
        {
          "type": "db",
          "count": 1,
          "size": "m5.large"
        }
      ]
    },
    "dr": {
      "name": "DR Environment",
      "region": "us-east-1",
      "vpc_cidr": "10.1.0.0/16",
      "subnets": [
        "10.1.1.0/24",
        "10.1.2.0/24"
      ],
      "instances": [
        {
          "type": "web",
          "count": 2,
          "size": "t3.medium"
        },
        {
          "type": "db",
          "count": 1,
          "size": "m5.large"
        }
      ]
    }
  }
}
```

**How to customize**:
- Update the `region` values to match your primary and DR regions
- Set the correct `vpc_cidr` and `subnets` for your environments
- Update `instances` to match your application's requirements

### 2. AWS Regions Configuration

Located at `config/aws-regions.json`:

```json
{
  "regions": {
    "us-west-2": {
      "name": "US West (Oregon)",
      "availability_zones": ["us-west-2a", "us-west-2b", "us-west-2c"],
      "services": ["ec2", "rds", "s3", "lambda", "dynamodb"]
    },
    "us-east-1": {
      "name": "US East (N. Virginia)",
      "availability_zones": ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d"],
      "services": ["ec2", "rds", "s3", "lambda", "dynamodb"]
    }
  }
}
```

**How to customize**:
- Add or remove regions based on your deployment architecture
- Ensure all services you're using are listed under `services`
- Verify the availability zones you're using are correct

### 3. Test Parameters Configuration

Located at `config/test-parameters.json`:

```json
{
  "test_timeout_minutes": 30,
  "rto_threshold_minutes": 15,
  "rpo_threshold_minutes": 60,
  "services_to_test": ["ec2", "rds", "s3"],
  "test_data_size_mb": 100,
  "backup_retention_days": 7,
  "alerts_enabled": true,
  "notification_email": "team@example.com",
  "fis_experiments": ["cpu-stress", "network-latency"],
  "failover_validation_checks": ["dns", "connectivity", "data_integrity"]
}
```

**How to customize**:
- Set `rto_threshold_minutes` and `rpo_threshold_minutes` to your organization's DR requirements
- Update `services_to_test` to include only services you use
- Set `notification_email` to your team's email address
- Select which `fis_experiments` you want to run

## Project-Specific Configuration

### The `project-specific-dr-test.tf` File

This file connects the DR testing framework to your AWS_CICD_Project infrastructure:

```hcl
module "dr_testing" {
  source = "./dr-testing-framework/modules/dr_test_pipeline"

  # Project identification
  project_name = "aws-cicd-project"
  environment  = "production"
  
  # Regions
  primary_region = "us-west-2"
  dr_region      = "us-east-1"
  
  # Infrastructure details
  vpc_id_primary = "vpc-12345abcde"
  vpc_id_dr      = "vpc-67890fghij"
  
  # Database configuration
  database_identifier = "prod-database"
  database_snapshot_arn = "arn:aws:rds:us-west-2:123456789012:snapshot:prod-snapshot"
  
  # S3 configuration
  s3_bucket_primary = "my-app-data-primary"
  s3_bucket_dr      = "my-app-data-dr"
  
  # Pipeline settings
  notification_email = "team@example.com"
  schedule_expression = "rate(7 days)"
}
```

**How to customize**:
1. Update `project_name` and `environment` to match your project
2. Set the correct `primary_region` and `dr_region`
3. Update infrastructure IDs to match your actual resources
4. Configure database and S3 settings specific to your application
5. Set notification and scheduling preferences

## How to Apply Configuration Changes

After modifying configuration files:

1. Commit your changes to the `dr-test-integration` branch:

   ```bash
   git add config/
   git add project-specific-dr-test.tf
   git commit -m "Update DR test configuration for AWS_CICD_Project"
   ```

2. Apply the Terraform changes:

   ```bash
   terraform init
   terraform apply
   ```

3. Validate your configuration:

   ```bash
   ./scripts/validate_config.sh
   ```

## Advanced Configuration

### Custom Test Scripts

To add custom test scripts:

1. Create your script in `scripts/custom/`:

   ```bash
   #!/bin/bash
   # Custom test for application-specific validation
   
   echo "Running custom validation..."
   # Your test logic here
   
   exit $EXIT_CODE  # 0 for success, non-zero for failure
   ```

2. Make it executable:

   ```bash
   chmod +x scripts/custom/my_custom_test.sh
   ```

3. Reference it in `scripts/run_dr_tests.sh`:

   ```bash
   # Add to the tests array
   tests+=("custom/my_custom_test.sh")
   ```

### Custom InSpec Profiles

To add custom compliance checks:

1. Create a new profile in `inspec/profiles/custom/`:

   ```bash
   mkdir -p inspec/profiles/custom/controls
   ```

2. Add your control file in `inspec/profiles/custom/controls/`:

   ```ruby
   # File: my_custom_checks.rb
   
   control 'custom-1' do
     impact 1.0
     title 'Verify application configuration'
     desc 'Ensures that the application is configured correctly in DR environment'
     
     describe file('/etc/myapp/config.json') do
       it { should exist }
       its('content') { should match /failover_enabled.*true/ }
     end
   end
   ```

3. Reference it in `inspec/profiles/custom/inspec.yml`:

   ```yaml
   name: custom
   title: Custom Application Checks
   version: 1.0.0
   depends:
     - name: aws
       url: https://github.com/mitre/aws-foundation-cis-baseline/archive/master.tar.gz
   ```

## Configuration Validation

To validate your configuration before running tests:

```bash
# Validate all configuration files
./scripts/validate_config.sh

# Validate specific configuration
./scripts/validate_config.sh --type test-environments
./scripts/validate_config.sh --type test-parameters
```

The validation script checks for:
- JSON/YAML syntax errors
- Missing required fields
- Logical inconsistencies
- Resource accessibility

## Troubleshooting Configuration Issues

Common configuration issues and solutions:

1. **Invalid JSON format**:
   - Use a JSON validator to check syntax
   - Ensure all quotes and brackets are properly closed

2. **Resource Not Found Errors**:
   - Verify that resource IDs are correct
   - Check IAM permissions for accessing resources

3. **Region Compatibility Issues**:
   - Verify that services are available in both regions
   - Check for region-specific features that may not be available