# DR Testing Guide for AWS_CICD_Project

This guide provides detailed instructions on how to run the Disaster Recovery (DR) testing pipeline for the AWS_CICD_Project.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Testing Overview](#testing-overview)
- [Pipeline Structure](#pipeline-structure)
- [Running the DR Test Pipeline](#running-the-dr-test-pipeline)
  - [Option 1: Manual Execution](#option-1-manual-execution)
  - [Option 2: Scheduled Execution](#option-2-scheduled-execution)
  - [Option 3: Integration with Deployment Pipeline](#option-3-integration-with-deployment-pipeline)
- [Test Types](#test-types)
- [Understanding Test Results](#understanding-test-results)
- [Troubleshooting](#troubleshooting)
- [Customizing Tests](#customizing-tests)

## Prerequisites

Before running DR tests, ensure you have:

1. **AWS Access**: Appropriate IAM permissions for both primary and DR regions
2. **Terraform Installed**: Version 1.0.0 or higher
3. **AWS CLI Configured**: With access to required accounts
4. **InSpec Installed**: For compliance validation tests
5. **GitHub Access**: To the `dr-test-integration` branch

## Testing Overview

The DR testing framework validates the resilience of your infrastructure by simulating various failure scenarios and verifying that recovery mechanisms work as expected. Tests include:

- **Infrastructure Validation**: Verifies that DR infrastructure matches primary
- **Backup and Recovery**: Tests backup retrieval and restoration
- **Fault Injection**: Simulates failures using AWS Fault Injection Service (FIS)
- **Failover Testing**: Validates failover from primary to DR region
- **Compliance Checks**: Ensures DR environment meets security requirements

## Pipeline Structure

The DR test pipeline consists of the following stages:

1. **Setup**: Prepares the test environment and configurations
2. **Pre-test Validation**: Verifies infrastructure compliance before testing
3. **Test Execution**: Runs the selected DR tests
4. **Results Analysis**: Analyzes and reports on test outcomes
5. **Cleanup**: Returns the environment to its original state

## Running the DR Test Pipeline

### Option 1: Manual Execution

To manually run the DR test pipeline:

1. Checkout the `dr-test-integration` branch:
   ```bash
   git checkout dr-test-integration
   ```

2. Navigate to the DR testing framework directory:
   ```bash
   cd dr-testing-framework
   ```

3. Initialize Terraform:
   ```bash
   terraform init
   ```

4. Apply the configuration to set up the testing environment:
   ```bash
   terraform apply -var-file=config/test-parameters.json
   ```

5. Run the DR test script:
   ```bash
   ./scripts/run_dr_tests.sh
   ```

6. Review the test results in the `results` directory:
   ```bash
   cat results/latest/summary.txt
   ```

### Option 2: Scheduled Execution

To set up scheduled DR testing:

1. Configure the schedule in the AWS_CICD_Project pipeline:
   ```hcl
   # In your project-specific-dr-test.tf file
   module "scheduled_dr_tests" {
     source = "./dr-testing-framework/modules/scheduled_tests"
     
     schedule_expression = "cron(0 2 ? * MON *)"  # Every Monday at 2:00 AM UTC
     notification_email  = "team@example.com"
     test_types          = ["infrastructure", "backup", "failover"]
   }
   ```

2. Apply the configuration:
   ```bash
   terraform apply
   ```

3. Tests will automatically run according to the schedule.

### Option 3: Integration with Deployment Pipeline

To run DR tests as part of your deployment pipeline:

1. Add the DR testing stage to your buildspec file:
   ```yaml
   # In your main buildspec.yml
   phases:
     # Other phases...
     post_build:
       commands:
         - cd dr-testing-framework
         - ./scripts/run_dr_tests.sh --quick
   
   artifacts:
     files:
       - dr-testing-framework/results/latest/**/*
   ```

2. Configure the pipeline to report DR test results.

## Test Types

You can run specific types of tests using the `--type` parameter with the `run_dr_tests.sh` script:

```bash
# Run only backup and recovery tests
./scripts/run_dr_tests.sh --type backup-recovery

# Run only failover tests
./scripts/run_dr_tests.sh --type failover

# Run only infrastructure validation tests
./scripts/run_dr_tests.sh --type infrastructure

# Run FIS experiment tests
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

Common issues and solutions:

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

To customize tests for your specific environment:

1. Edit test parameters in `config/test-parameters.json`:
   ```json
   {
     "test_timeout_minutes": 30,
     "services_to_test": ["ec2", "rds", "s3"],
     "failover_validation_checks": ["dns", "connectivity", "data_integrity"]
   }
   ```

2. Create custom test scripts in the `scripts` directory:
   ```bash
   # Example: Create a custom database validation test
   touch scripts/custom/validate_database.sh
   chmod +x scripts/custom/validate_database.sh
   ```

3. Add custom InSpec controls in `inspec/profiles/custom/controls/`.

4. Reference your custom tests in `run_dr_tests.sh`.