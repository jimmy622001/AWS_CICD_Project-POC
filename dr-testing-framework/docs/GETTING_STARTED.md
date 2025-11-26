# Getting Started with DR Testing Framework

This guide provides simple step-by-step instructions for beginners to set up and run DR tests for the AWS_CICD_Project.

## Prerequisites

Before you start, make sure you have:

1. **AWS Account Access**: Valid credentials with appropriate permissions
2. **Git**: Installed and configured on your machine
3. **Terraform**: Version 1.0.0+ installed (run `terraform --version` to check)
4. **PowerShell**: For Windows users (already included in Windows 10+)

## Step-by-Step Setup Guide

### Step 1: Clone the Repository

```bash
git clone https://github.com/your-organization/AWS_CICD_Project.git
cd AWS_CICD_Project
```

### Step 2: Switch to the DR Test Branch

```bash
git checkout dr-test-integration
```

### Step 3: Navigate to the DR Testing Framework

```bash
cd dr-testing-framework
```

### Step 4: Configure Your Environment

You have two options to configure the DR testing environment:

#### Option A: Edit JSON Configuration Files

1. Open and edit the JSON files in the `config` directory:
   ```
   config/test-environments.json
   config/aws-regions.json
   config/test-parameters.json
   ```

2. Update values to match your AWS environment:
   - Set correct AWS regions in `aws-regions.json`
   - Configure VPC and subnet settings in `test-environments.json`
   - Adjust test parameters in `test-parameters.json`

#### Option B: Edit Terraform Variables Directly

1. Open and edit the `terraform.tfvars` file:
   ```
   notepad terraform.tfvars
   # or any text editor of your choice
   ```

2. Update values to match your environment requirements

### Step 5: Initialize Terraform

Run the following command to initialize Terraform:

```bash
terraform init
```

### Step 6: Run the Automated Setup Script

Execute the provided batch file to set up your environment:

```bash
run-terraform.bat
```

This will:
- Convert your JSON configuration to Terraform variables (if using JSON)
- Initialize Terraform (if not already done)
- Create a plan for your DR testing infrastructure

### Step 7: Review the Plan

Carefully review the Terraform plan output to ensure it will create the resources you expect.

### Step 8: Apply the Configuration

If the plan looks good, apply it to create your DR testing environment:

```bash
terraform apply
```

When prompted, type `yes` to confirm.

### Step 9: Run DR Tests

Execute the DR test script:

```bash
./scripts/run_dr_tests.sh
```

For specific test types only:
```bash
./scripts/run_dr_tests.sh --type failover
./scripts/run_dr_tests.sh --type backup-recovery
```

### Step 10: View Test Results

1. Navigate to the results directory:
   ```bash
   cd results/latest
   ```

2. Open the summary report:
   ```bash
   cat summary.txt
   ```

3. Explore detailed logs in the `details` directory

### Step 11: Clean Up Resources (When Finished)

When you're done testing, clean up the resources:

```bash
terraform destroy
```

When prompted, type `yes` to confirm.

## Troubleshooting Common Issues

### Issue: "The term 'run-terraform.bat' is not recognized"

**Solution:** Make sure you're in the correct directory:
```bash
cd dr-testing-framework
dir  # Verify run-terraform.bat is in this directory
```

### Issue: AWS Authentication Errors

**Solution:** Configure your AWS credentials:
```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, default region, and output format
```

### Issue: Terraform Initialization Fails

**Solution:** Clear the Terraform cache and try again:
```bash
rm -rf .terraform
terraform init
```

### Issue: DR Tests Fail

**Solution:** Check the logs for specific error messages:
```bash
cat results/latest/details/error.log
```

## Additional Help

If you encounter any issues not covered in this guide:

1. Refer to the more detailed documentation:
   - [DR Testing Guide](./DR_TESTING_GUIDE.md)
   - [Configuration Guide](./CONFIGURATION.md)
   - [Pipeline Guide](./PIPELINE_GUIDE.md)

2. Contact the project maintainers for support