# AWS Native CI/CD Project - Usage Guide

This guide provides detailed instructions on how to use and operate the AWS Native CI/CD Project. For project overview and architecture information, please refer to the README.md.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Working with CodeCommit Repositories](#working-with-codecommit-repositories)
- [Managing Pipelines](#managing-pipelines)
- [Environment Management](#environment-management)
- [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
- [Common Operations](#common-operations)
- [Disaster Recovery Procedures](#disaster-recovery-procedures)

## Prerequisites

Before you begin, ensure you have the following:

- AWS CLI installed and configured with appropriate permissions
- Terraform ≥ 1.0.0
- Git client installed
- Docker installed (for local testing)
- kubectl command-line tool
- AWS IAM permissions for:
  - CodeCommit, CodeBuild, CodePipeline, CodeDeploy
  - S3, ECR, EKS
  - KMS, IAM, CloudWatch

## Initial Setup

### 1. Clone the Project Repository

```bash
git clone <project-repository-url>
cd AWS_CICD_Project
```

### 2. Initialize and Apply Terraform Configuration

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

This will create all necessary AWS resources including:
- CodeCommit repositories
- CodeBuild projects
- CodePipeline pipelines
- S3 buckets for artifacts
- KMS keys for encryption
- IAM roles

### 3. Configure Local Git for CodeCommit

After Terraform creates the CodeCommit repositories, configure your Git credentials:

```bash
aws codecommit create-credential-helper
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true
```

## Working with CodeCommit Repositories

### Repository Structure

This project uses three separate CodeCommit repositories:

1. **infrastructure-repo**: Contains Terraform code for VPC and networking
2. **eks-repo**: Contains Terraform code for EKS cluster
3. **application-repo**: Contains application code and Kubernetes manifests

### Cloning Repositories

```bash
# Get the clone URLs from the Terraform outputs
terraform output codecommit_clone_urls

# Clone each repository
git clone <infrastructure-repo-url>
git clone <eks-repo-url>
git clone <application-repo-url>
```

### Pushing Code to Repositories

For the initial setup, you'll need to populate each repository:

```bash
# Infrastructure repository
cd infrastructure-repo
cp -r ../modules .
cp ../main.tf ../variables.tf ../outputs.tf .
git add .
git commit -m "Initial infrastructure code"
git push

# EKS repository
cd ../eks-repo
cp -r ../modules/eks .
git add .
git commit -m "Initial EKS code"
git push

# Application repository
cd ../application-repo
cp -r ../app .
git add .
git commit -m "Initial application code"
git push
```

## Managing Pipelines

### Pipeline Execution Order

The pipelines must be executed in the following order:

1. Infrastructure Pipeline
2. EKS Pipeline
3. Application Pipeline

### Triggering Pipelines Manually

Pipelines are configured to trigger automatically on repository changes. However, you can also trigger them manually:

```bash
# Start a pipeline execution
aws codepipeline start-pipeline-execution --name <pipeline-name>

# Example:
aws codepipeline start-pipeline-execution --name infrastructure-pipeline-dev
```

### Approving Production Deployments

Production deployments require manual approval:

1. Navigate to the AWS CodePipeline console
2. Find the pipeline with a pending approval action
3. Click the "Review" button
4. Enter comments and click "Approve" or "Reject"

## Environment Management

### Available Environments

The project supports three environments:

- **dev**: Development environment for testing
- **prod**: Production environment for live workloads
- **dr**: Disaster recovery environment (in a different AWS region)

### Deploying to Specific Environments

```bash
# You can specify the environment via Terraform variables
terraform apply -var="environment=dev"
terraform apply -var="environment=prod"
terraform apply -var="environment=dr"
```

### Accessing EKS Clusters

```bash
# Configure kubectl to access the EKS cluster
aws eks update-kubeconfig --name <cluster-name> --region <region>

# Example:
aws eks update-kubeconfig --name cicd-eks-dev --region eu-west-1
```

## Monitoring and Troubleshooting

### Viewing Pipeline Execution Status

```bash
# Get pipeline execution status
aws codepipeline get-pipeline-state --name <pipeline-name>
```

### Accessing Build Logs

```bash
# Get the build ID first
aws codebuild list-builds-for-project --project-name <project-name>

# Then get the build logs
aws codebuild get-build-log --id <build-id>
```

### Common CloudWatch Log Groups

- `/aws/codebuild/<build-project-name>`
- `/aws/codedeploy/<deploy-group-name>`
- `/aws/eks/<cluster-name>/cluster`

## Common Operations

### Adding a New Service

1. Create Kubernetes manifests in the `app/kubernetes/` directory
2. Update the `buildspec/application.yml` to include the new service
3. Commit and push the changes to the application repository

### Updating Infrastructure

1. Make changes to the Terraform code in the infrastructure repository
2. Commit and push the changes
3. The infrastructure pipeline will automatically trigger

### Scaling Worker Nodes

1. Edit the EKS module configuration to adjust node counts
2. Commit and push the changes to the EKS repository
3. The EKS pipeline will automatically trigger

## Disaster Recovery Procedures

### Testing Failover

1. Run the DR pipeline to ensure the DR environment is up-to-date
2. Update Route 53 failover records to point to the DR environment:
   ```bash
   aws route53 change-resource-record-sets --hosted-zone-id <zone-id> --change-batch file://failover.json
   ```

### Performing Failback

1. Verify that the primary region is operational again
2. Update Route 53 records to point back to the primary environment
3. Sync any data that may have changed in the DR environment back to primary

### Regular DR Testing

Schedule regular DR testing by:
1. Running the DR pipeline
2. Verifying all components are working in the DR environment
3. Performing a test failover (in a maintenance window)
4. Documenting the results