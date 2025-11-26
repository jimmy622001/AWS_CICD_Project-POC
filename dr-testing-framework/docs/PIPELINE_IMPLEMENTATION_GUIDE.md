# DR Testing Pipeline Implementation Guide

This guide provides detailed instructions for implementing, configuring, and customizing the DR testing pipeline for your AWS projects.

## Table of Contents
- [Pipeline Architecture](#pipeline-architecture)
- [Setting Up the Pipeline](#setting-up-the-pipeline)
- [Running the Pipeline](#running-the-pipeline)
- [Pipeline Stages in Detail](#pipeline-stages-in-detail)
- [Pipeline Outputs](#pipeline-outputs)
- [Advanced Configuration](#advanced-configuration)
- [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
- [Best Practices](#best-practices)

## Pipeline Architecture

The DR testing pipeline automates the process of validating disaster recovery capabilities with the following architecture:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│  Source Stage   │────▶│  Setup Stage    │────▶│  Test Stage     │
│                 │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
┌─────────────────┐     ┌─────────────────┐             ▼
│                 │     │                 │     ┌─────────────────┐
│  Cleanup Stage  │◀────│  Report Stage   │◀────│  Analysis Stage │
│                 │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Setting Up the Pipeline

### Prerequisites

- AWS Account with permissions to create CodePipeline, CodeBuild resources
- Source code repository (GitHub, CodeCommit, etc.)
- IAM roles with appropriate permissions for DR testing

### Pipeline Creation

#### Using the Terraform Module

```hcl
module "dr_test_pipeline" {
  source = "./dr-testing-framework/modules/dr_test_pipeline"
  
  project_name        = "aws-cicd-project"
  source_repo         = "github-repo-name"
  source_branch       = "dr-test"
  primary_region      = "us-west-2"
  dr_region           = "us-east-1"
  notification_email  = "team@example.com"
  
  # Optional parameters
  test_types          = ["backup-recovery", "failover", "fis"]
  schedule_expression = "rate(7 days)"  # For scheduled execution
}
```

#### Apply the Configuration

```bash
terraform init
terraform apply
```

#### Verify Pipeline Creation

Go to the AWS Console > CodePipeline to verify the pipeline has been created successfully.

## Running the Pipeline

### Manual Execution

#### From AWS Console
- Navigate to AWS Console > CodePipeline
- Select your DR test pipeline
- Click "Release Change" to start the pipeline manually

#### From AWS CLI
```bash
aws codepipeline start-pipeline-execution --name dr-test-pipeline
```

#### Using the Provided Script
```bash
./scripts/trigger_dr_pipeline.sh
```

### Scheduled Execution

Configure the pipeline to run automatically on a schedule:

```hcl
module "dr_test_pipeline" {
  # Other parameters...
  schedule_expression = "cron(0 4 ? * SUN *)"  # Run at 4:00 AM UTC every Sunday
}
```

### Triggering Based on Changes

Configure the pipeline to trigger when changes are pushed to a specific branch:

```hcl
module "dr_test_pipeline" {
  # Other parameters...
  source_repo   = "my-repo"
  source_branch = "dr-test"
  trigger_on_changes = true
}
```

## Pipeline Stages in Detail

### 1. Source Stage

The source stage pulls the latest code from your repository:

```terraform
stage {
  name = "Source"

  action {
    name             = "Source"
    category         = "Source"
    owner            = "AWS"
    provider         = "CodeCommit"
    version          = "1"
    output_artifacts = ["source_output"]

    configuration = {
      RepositoryName = "${var.project_name}"
      BranchName     = "dr-test"  # Branch that triggers the pipeline
    }
  }
}
```

### 2. Setup Stage

The setup stage:
- Prepares the test environment
- Validates configurations
- Sets up test parameters

### 3. Test Stage

The test stage executes the DR tests:
- Infrastructure validation
- Backup and recovery testing
- Fault injection scenarios
- Failover testing

### 4. Analysis Stage

The analysis stage:
- Analyzes test results
- Validates against defined thresholds
- Measures recovery times and data loss

### 5. Report Stage

The report stage:
- Generates test reports
- Creates visualizations of test results
- Sends notifications about test outcomes

### 6. Cleanup Stage

The cleanup stage:
- Restores the environment to its original state
- Removes any temporary test resources
- Archives test results

## Pipeline Outputs

The pipeline produces the following outputs:

1. **Test Result Summary**: Overall pass/fail status and metrics
2. **Detailed Reports**: Logs and detailed results for each test
3. **Compliance Reports**: Security and configuration compliance status
4. **Performance Metrics**: RTO/RPO measurements and performance data

## Advanced Configuration

### Test Types Configuration

You can configure which types of tests to run in the pipeline:

```hcl
module "dr_test_pipeline" {
  # Other parameters...
  test_types = [
    "infrastructure",  # Infrastructure validation
    "backup-recovery", # Backup and recovery tests
    "failover",        # Failover testing
    "fis"              # Fault injection scenarios
  ]
}
```

### Test Parameters Configuration

Edit the `config/test-parameters.json` file to customize test behaviors:

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

3. Reference it in your buildspec file:
   ```yaml
   version: 0.2
   
   phases:
     build:
       commands:
         - ./scripts/run_dr_tests.sh
         - ./scripts/custom/my_custom_test.sh
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

### Modifying Buildspec Files

To customize the pipeline behavior, edit the buildspec files in the `buildspec/` directory:

```yaml
# Example: buildspec/test_stage.yml
version: 0.2

phases:
  install:
    runtime-versions:
      python: 3.9
  pre_build:
    commands:
      - echo "Setting up test environment..."
      - ./scripts/setup_test_env.sh
  build:
    commands:
      - echo "Running DR tests..."
      - ./scripts/run_dr_tests.sh --type $TEST_TYPE
  post_build:
    commands:
      - echo "Analyzing test results..."
      - ./scripts/analyze_results.sh

artifacts:
  files:
    - results/**/*
    - reports/**/*
```

## Monitoring and Troubleshooting

### Monitoring Pipeline Execution

#### AWS Console
- Navigate to CodePipeline > Your Pipeline > View Execution History

#### CloudWatch
- Check CloudWatch Logs for detailed execution logs
- Set up CloudWatch Alarms for pipeline failures

#### Email Notifications
- Configure SNS topics in the pipeline module for email alerts:
  ```hcl
  module "dr_test_pipeline" {
    # Other parameters...
    notification_email = "team@example.com"
    alert_on_failure = true
  }
  ```

### Troubleshooting Common Issues

#### Pipeline Fails in Setup Stage
- Check IAM permissions
- Verify configuration files are valid
- Ensure AWS resources are accessible

#### Test Stage Failures
- Check the specific test logs in CodeBuild
- Verify the DR infrastructure is properly provisioned
- Check network connectivity between regions

#### Pipeline Timeouts
- Increase timeout settings in the buildspec files:
  ```yaml
  phases:
    build:
      commands:
        - timeout 60m ./scripts/run_dr_tests.sh  # Increase timeout to 60 minutes
  ```
- Break down tests into smaller batches

#### Debugging Test Scripts
- Add debug output to test scripts:
  ```bash
  # Add to your test scripts
  set -x  # Enable debug output
  ```
- Check CloudWatch Logs for test execution details

## Best Practices

1. **Regular Execution**: Schedule the pipeline to run regularly (weekly or monthly)
2. **Pre-Release Testing**: Run the pipeline before major releases
3. **Incremental Testing**: Start with basic tests and gradually add more complex scenarios
4. **Isolated Environment**: Use an isolated account for testing when possible
5. **Comprehensive Reporting**: Review and archive test reports for compliance
6. **Automate Remediation**: Where possible, automate fixes for common issues
7. **Version Control**: Keep your test configurations in version control
8. **Documentation**: Document test scenarios and expected results
9. **Continuous Improvement**: Regularly update tests based on lessons learned
10. **Cross-Region Testing**: Ensure your DR tests cover all regions used by your application