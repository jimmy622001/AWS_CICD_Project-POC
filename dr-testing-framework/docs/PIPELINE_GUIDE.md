# DR Testing Pipeline Guide

This document provides detailed instructions for setting up and using the DR testing pipeline in the AWS_CICD_Project.

## Pipeline Architecture

The DR testing pipeline is designed to automate the process of validating disaster recovery capabilities. The pipeline architecture consists of:

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

1. **Using the Terraform Module**

   ```hcl
   module "dr_test_pipeline" {
     source = "./dr-testing-framework/modules/dr_test_pipeline"
     
     project_name        = "aws-cicd-project"
     source_repo         = "github-repo-name"
     source_branch       = "dr-test-integration"
     primary_region      = "us-west-2"
     dr_region           = "us-east-1"
     notification_email  = "team@example.com"
     
     # Optional parameters
     test_types          = ["backup-recovery", "failover", "fis"]
     schedule_expression = "rate(7 days)"  # For scheduled execution
   }
   ```

2. **Apply the Configuration**

   ```bash
   terraform init
   terraform apply
   ```

3. **Verify Pipeline Creation**

   Go to the AWS Console > CodePipeline to verify the pipeline has been created successfully.

## Running the Pipeline

### Manual Execution

1. **From AWS Console**:
   - Navigate to AWS Console > CodePipeline
   - Select your DR test pipeline
   - Click "Release Change" to start the pipeline manually

2. **From AWS CLI**:
   ```bash
   aws codepipeline start-pipeline-execution --name dr-test-pipeline
   ```

3. **Using the Provided Script**:
   ```bash
   ./scripts/trigger_dr_pipeline.sh
   ```

### Scheduled Execution

The pipeline can be configured to run automatically on a schedule:

1. Configure the schedule expression in your Terraform configuration:
   ```hcl
   module "dr_test_pipeline" {
     # Other parameters...
     schedule_expression = "cron(0 4 ? * SUN *)"  # Run at 4:00 AM UTC every Sunday
   }
   ```

2. Apply the configuration to update the schedule.

### Triggering Based on Changes

The pipeline can also be triggered when changes are pushed to the repository:

1. Configure the pipeline to watch the repository branch:
   ```hcl
   module "dr_test_pipeline" {
     # Other parameters...
     source_repo   = "my-repo"
     source_branch = "dr-test-integration"
     trigger_on_changes = true
   }
   ```

2. Push changes to the specified branch to trigger the pipeline.

## Pipeline Stages in Detail

### 1. Source Stage

Pulls the latest code from the repository.

### 2. Setup Stage

- Prepares the test environment
- Validates configurations
- Sets up test parameters

### 3. Test Stage

Executes the DR tests:
- Infrastructure validation
- Backup and recovery testing
- Fault injection scenarios
- Failover testing

### 4. Analysis Stage

- Analyzes test results
- Validates against defined thresholds
- Measures recovery times and data loss

### 5. Report Stage

- Generates test reports
- Creates visualizations of test results
- Sends notifications about test outcomes

### 6. Cleanup Stage

- Restores the environment to its original state
- Removes any temporary test resources
- Archives test results

## Pipeline Outputs

The pipeline produces the following outputs:

1. **Test Result Summary**: Overall pass/fail status and metrics
2. **Detailed Reports**: Logs and detailed results for each test
3. **Compliance Reports**: Security and configuration compliance status
4. **Performance Metrics**: RTO/RPO measurements and performance data

## Monitoring Pipeline Execution

You can monitor the pipeline execution through:

1. **AWS Console**:
   - Navigate to CodePipeline > Your Pipeline > View Execution History

2. **CloudWatch**:
   - Check CloudWatch Logs for detailed execution logs
   - Set up CloudWatch Alarms for pipeline failures

3. **Email Notifications**:
   - Configure SNS topics in the pipeline module for email alerts

## Troubleshooting Pipeline Issues

Common pipeline issues and solutions:

1. **Pipeline Fails in Setup Stage**:
   - Check IAM permissions
   - Verify configuration files are valid
   - Ensure AWS resources are accessible

2. **Test Stage Failures**:
   - Check the specific test logs in CodeBuild
   - Verify the DR infrastructure is properly provisioned
   - Check network connectivity between regions

3. **Pipeline Timeouts**:
   - Increase timeout settings in the buildspec files
   - Break down tests into smaller batches

## Customizing the Pipeline

To customize the pipeline for your specific needs:

1. **Modify Buildspec Files**:
   - Edit buildspec files in `buildspec/` directory
   - Add or remove test stages as needed

2. **Add Custom Tests**:
   - Add custom test scripts to the `scripts/custom/` directory
   - Reference them in the buildspec files

3. **Update Notifications**:
   - Configure additional SNS topics in the pipeline module
   - Set up custom notification targets

4. **Change Test Parameters**:
   - Update test parameters in `config/test-parameters.json`
   - Adjust thresholds for test success/failure

## Best Practices

1. **Regular Execution**: Schedule the pipeline to run regularly (weekly or monthly)
2. **Pre-Release Testing**: Run the pipeline before major releases
3. **Incremental Testing**: Start with basic tests and gradually add more complex scenarios
4. **Isolated Environment**: Use an isolated account for testing when possible
5. **Comprehensive Reporting**: Review and archive test reports for compliance