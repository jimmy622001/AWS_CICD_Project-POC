# DR Testing Integration Guide

This guide provides comprehensive instructions for integrating and using the DR testing framework in your AWS project.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Integration Steps](#integration-steps)
- [Configuration Options](#configuration-options)
- [Running DR Tests](#running-dr-tests)
- [Understanding Test Results](#understanding-test-results)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before integrating the DR testing framework, ensure you have:

1. **AWS Account Access**: Valid credentials with appropriate permissions
2. **Git**: Installed and configured on your machine
3. **Terraform**: Version 1.0.0+ installed (run `terraform --version` to check)
4. **PowerShell**: For Windows users (already included in Windows 10+)

## Quick Start

For those wanting to quickly get started:

1. Clone your project repository and create a DR test branch:
   ```bash
   git checkout -b dr-test
   ```

2. Copy the DR testing framework into your project or include it as a module:
   ```hcl
   # Example project-specific-dr-test.tf
   module "project_dr_test" {
     source = "./dr-testing-framework"

     project_name    = "your-project-name"
     primary_region  = "your-primary-region"
     dr_region       = "your-dr-region"
     # Add other required configuration
   }
   ```

3. Configure your environment in the `config` directory files

4. Initialize and apply the Terraform configuration:
   ```bash
   cd dr-testing-framework
   terraform init
   terraform apply
   ```

5. Run the DR tests:
   ```bash
   ./scripts/run_dr_tests.sh
   ```

6. View the results in the `results/latest` directory

## Integration Steps

### Step 1: Clone the Target Repository

```bash
git clone https://github.com/your-organization/your-project.git
cd your-project
```

### Step 2: Create a DR Test Branch

```bash
git checkout -b dr-test
```

> **Important**: The `dr-test` branch is specifically configured to trigger the DR testing pipeline automatically when changes are pushed to it.

### Step 3: Integrate the DR Testing Framework

Copy the DR testing framework into your project or include it as a module:

```hcl
# Example project-specific-dr-test.tf
module "project_dr_test" {
  source = "./dr-testing-framework"

  project_name    = "your-project-name"
  primary_region  = "your-primary-region"
  dr_region       = "your-dr-region"
  
  # Core settings
  vpc_id_primary = "vpc-12345abcde"
  vpc_id_dr      = "vpc-67890fghij"
  
  # Database configuration (if applicable)
  database_identifier = "prod-database"
  database_snapshot_arn = "arn:aws:rds:eu-west-2:123456789012:snapshot:prod-snapshot"
  
  # S3 configuration (if applicable)
  s3_bucket_primary = "my-app-data-primary"
  s3_bucket_dr      = "my-app-data-dr"
  
  # Pipeline settings
  notification_email = "team@example.com"
  schedule_expression = "rate(7 days)"
}
```

### Step 4: Configure Your Environment

Edit the configuration files in the DR testing framework's `config` directory:

#### Region Configuration
```json
// config/aws-regions.json
{
  "primary": {
    "region": "us-west-2",
    "availability_zones": ["us-west-2a", "us-west-2b"],
    "services": ["ec2", "rds", "s3", "lambda"]
  },
  "dr": {
    "region": "us-east-1",
    "availability_zones": ["us-east-1a", "us-east-1b"],
    "services": ["ec2", "rds", "s3", "lambda"]
  }
}
```

#### Test Environment Configuration
```json
// config/test-environments.json
{
  "primary": {
    "vpc_cidr": "10.0.0.0/16",
    "subnets": ["10.0.1.0/24", "10.0.2.0/24"],
    "instances": [
      {
        "name": "app-server",
        "type": "t3.medium",
        "ami": "ami-12345678"
      }
    ]
  },
  "dr": {
    "vpc_cidr": "10.1.0.0/16",
    "subnets": ["10.1.1.0/24", "10.1.2.0/24"],
    "instances": [
      {
        "name": "app-server-dr",
        "type": "t3.medium",
        "ami": "ami-87654321"
      }
    ]
  }
}
```

#### Test Parameters Configuration
```json
// config/test-parameters.json
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

### Step 5: Initialize and Set Up Your Environment

Navigate to the DR testing framework directory and initialize Terraform:

```bash
cd dr-testing-framework
terraform init
```

Then, run the automated setup script:

```bash
run-terraform.bat
```

This script will:
- Convert your JSON configuration to Terraform variables
- Initialize Terraform
- Create a plan for your DR testing infrastructure

### Step 6: Apply the Configuration

After reviewing the plan, apply it to create your DR testing environment:

```bash
terraform apply
```

When prompted, type `yes` to confirm.

## Configuration Options

### Using Terraform Variables

All configuration options are available as Terraform variables. Here are the key variables:

```hcl
# Core settings
project_name     = "aws-cicd-project"  # Project name
primary_region   = "us-west-2"       # Primary AWS region
dr_region        = "us-east-1"       # DR AWS region

# Network configuration
vpc_cidr_primary = "10.0.0.0/16"     # CIDR for primary VPC
vpc_cidr_dr      = "10.1.0.0/16"     # CIDR for DR VPC
subnets_primary  = ["10.0.1.0/24"]   # Subnets for primary
subnets_dr       = ["10.1.1.0/24"]   # Subnets for DR

# Recovery objectives
rto_threshold_minutes = 15            # Recovery Time Objective
rpo_threshold_minutes = 60            # Recovery Point Objective
```

### Using JSON Configuration Files

If you prefer using JSON configuration files:

1. Edit the JSON files in the `config/` directory
2. Run the conversion script to update Terraform variables:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\convert_json_to_tfvars.ps1
   ```
3. Apply the Terraform changes:
   ```bash
   terraform init
   terraform apply
   ```

## Running DR Tests

### Option 1: Automatic Pipeline Execution

Push changes to the `dr-test` branch to automatically trigger the test pipeline:

```bash
git add .
git commit -m "Update DR test configuration"
git push origin dr-test
```

### Option 2: Manual Test Execution

Execute the test scripts manually:

```bash
# For all tests
./scripts/run_dr_tests.sh

# For specific test types
./scripts/run_dr_tests.sh --type failover
./scripts/run_dr_tests.sh --type backup-recovery
./scripts/run_dr_tests.sh --type infrastructure
./scripts/run_dr_tests.sh --type fis
```

## Understanding Test Results

After running tests, results are stored in the `dr-testing-framework/results` directory:

- `summary.txt`: Overall test results and metrics
- `details/`: Detailed logs for each test
- `compliance/`: InSpec compliance reports
- `metrics/`: Performance metrics during tests

Test results include:

- **Pass/Fail Status**: Overall test status
- **Recovery Time**: Measured RTO (Recovery Time Objective)
- **Data Loss**: Measured RPO (Recovery Point Objective)
- **Compliance Score**: Security compliance percentage

## Troubleshooting

### Common Issues

1. **"The term 'run-terraform.bat' is not recognized"**
   
   **Solution:** Make sure you're in the correct directory:
   ```bash
   cd dr-testing-framework
   dir  # Verify run-terraform.bat is in this directory
   ```

2. **AWS Authentication Errors**
   
   **Solution:** Configure your AWS credentials:
   ```bash
   aws configure
   # Enter your AWS Access Key ID, Secret Access Key, default region, and output format
   ```

3. **Terraform Initialization Fails**
   
   **Solution:** Clear the Terraform cache and try again:
   ```bash
   rm -rf .terraform
   terraform init
   ```

4. **DR Tests Fail**
   
   **Solution:** Check the logs for specific error messages:
   ```bash
   cat results/latest/details/error.log
   ```

### Test-Specific Issues

1. **Failed Infrastructure Validation**:
   - Check that your DR region has the same resources as your primary region
   - Verify that the configuration in `test-environments.json` matches your actual infrastructure

2. **Backup Restoration Failures**:
   - Verify that backups exist and are accessible
   - Check IAM permissions for backup access

3. **Timeout During Tests**:
   - Increase the timeout value in `config/test-parameters.json`
   - Check network connectivity between primary and DR regions

## Customizing Tests

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
   tests+=(\"custom/my_custom_test.sh\")
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