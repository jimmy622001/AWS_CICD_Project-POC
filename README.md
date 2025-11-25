# AWS Native CI/CD Project

This project implements a complete CI/CD solution using AWS native services (CodeCommit, CodeBuild, CodeDeploy, and CodePipeline) replacing Jenkins for infrastructure, EKS, and application deployments.

## Project Structure

```
AWS_CICD_Project/
├── app/                           # Application files
│   ├── Dockerfile                 # Docker container definition
│   ├── index.html                 # Sample app HTML
│   ├── app.js                     # Sample app JS
│   ├── styles.css                 # Sample app CSS
│   └── kubernetes/                # Kubernetes manifests
│       └── deployment.yaml        # K8s deployment definition
├── buildspec/                     # CodeBuild specification files
│   ├── infrastructure.yml         # Infrastructure pipeline buildspec
│   ├── eks.yml                    # EKS pipeline buildspec
│   └── application.yml            # Application pipeline buildspec
├── environments/                  # Environment-specific configurations
│   ├── dev/                       # Development environment
│   ├── prod/                      # Production environment
│   └── dr/                        # Disaster Recovery environment
├── modules/                       # Terraform modules
│   ├── codecommit/                # CodeCommit module
│   ├── codebuild/                 # CodeBuild module
│   ├── codedeploy/                # CodeDeploy module
│   ├── codepipeline/              # CodePipeline module
│   ├── eks/                       # EKS module
│   └── vpc/                       # VPC module
├── main.tf                        # Main Terraform configuration
├── variables.tf                   # Project variables
├── outputs.tf                     # Project outputs
└── README.md                      # Project documentation
```

## Project Components

### Infrastructure Components

1. **VPC and Networking**
   - Subnets (Public, Private, DB)
   - NAT Gateway, Internet Gateway
   - Route Tables and Associations

2. **EKS (Elastic Kubernetes Service)**
   - Managed Kubernetes cluster
   - Node groups and IAM roles
   - OIDC provider for service accounts

3. **Application**
   - Simple containerized web application
   - Kubernetes deployment & service manifests
   - Autoscaling configuration

### CI/CD Components

1. **Source Control**
   - AWS CodeCommit repositories for different components

2. **Build System**
   - AWS CodeBuild projects with buildspec files
   - Build environments for infrastructure and application code

3. **Deployment System**
   - AWS CodeDeploy for application deployments
   - Direct Kubernetes deployments via kubectl

4. **Pipeline Orchestration**
   - AWS CodePipeline for workflow orchestration
   - Manual approval steps for production deployments
   - Multi-environment promotion workflow

## Pipeline Types

1. **Infrastructure Pipeline**
   - Deploys VPC and networking components
   - Runs infrequently (only when infrastructure changes)
   - Produces outputs required by EKS pipeline

2. **EKS Pipeline**
   - Deploys Kubernetes cluster and configurations
   - Runs infrequently (only when cluster changes)
   - Produces outputs required by application pipeline

3. **Application Pipeline**
   - Builds and deploys application containers
   - Runs frequently (for application code changes)
   - Supports CI/CD for multiple environments

## Getting Started

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform ≥ 1.0.0
- Docker (for local testing)

### Deployment Steps

1. **Initialize the Project**
   ```
   terraform init
   terraform apply
   ```

2. **Configure AWS CodeCommit**
   - Set up Git credentials for AWS CodeCommit
   - Push code to the repositories

3. **Run the Pipelines**
   - Infrastructure pipeline first
   - EKS pipeline second
   - Application pipeline last

### Environment Promotion

The project supports a typical promotion workflow:
1. Deploy to development (dev)
2. Test and validate
3. Promote to production (prod)
4. Optionally deploy to disaster recovery (dr)

## Security Features

- KMS encryption for artifacts
- IAM roles with least privilege
- Secret management via AWS Secrets Manager
- Network security through VPC design

## Monitoring & Logging

- CloudWatch Logs for pipeline execution
- CloudTrail for API activity
- X-Ray for pipeline tracing (optional)

## Cost Optimization

- Pay-per-use model for CI/CD components
- Resource cleanup through retention policies
- Cost allocation tagging