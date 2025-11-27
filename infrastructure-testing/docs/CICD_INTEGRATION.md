# CI/CD Integration Guide for Infrastructure Testing Framework

This guide provides detailed instructions for integrating the Infrastructure Testing Framework with various CI/CD pipelines. The goal is to automate infrastructure testing as part of your deployment processes.

## Table of Contents

- [Overview](#overview)
- [AWS CodePipeline Integration](#aws-codepipeline-integration)
- [GitHub Actions Integration](#github-actions-integration)
- [Jenkins Integration](#jenkins-integration)
- [GitLab CI Integration](#gitlab-ci-integration)
- [Best Practices](#best-practices)
- [Testing Stages](#testing-stages)
- [Reference Implementations](#reference-implementations)

## Overview

Integrating the Infrastructure Testing Framework into your CI/CD pipeline provides several benefits:

1. **Early Detection**: Identify infrastructure issues before they impact production
2. **Automated Validation**: Ensure infrastructure meets security and functionality standards
3. **Consistent Testing**: Apply the same tests across all environments
4. **Deployment Gates**: Use test results to control promotion between environments
5. **Audit Trail**: Maintain records of infrastructure quality over time

### Integration Patterns

There are two primary patterns for integration:

1. **Pre-Deployment Testing**: Run infrastructure tests before deploying application changes
2. **Post-Deployment Validation**: Verify infrastructure after changes are deployed

Both patterns can be used together for comprehensive coverage.

## AWS CodePipeline Integration

AWS CodePipeline is a fully managed CI/CD service that integrates well with the Infrastructure Testing Framework.

### Basic Integration

1. **Add a Lambda Invoke Stage**:

```json
{
  "name": "InfrastructureTesting",
  "actions": [
    {
      "name": "RunTests",
      "actionTypeId": {
        "category": "Invoke",
        "owner": "AWS",
        "provider": "Lambda",
        "version": "1"
      },
      "configuration": {
        "FunctionName": "${project_name}-${env}-test-orchestrator",
        "UserParameters": "{\"runType\": \"full\"}"
      },
      "inputArtifacts": [],
      "outputArtifacts": []
    }
  ]
}
```

2. **Add Test Report Stage**:

```json
{
  "name": "GenerateTestReport",
  "actions": [
    {
      "name": "CreateReport",
      "actionTypeId": {
        "category": "Invoke",
        "owner": "AWS",
        "provider": "Lambda",
        "version": "1"
      },
      "configuration": {
        "FunctionName": "${project_name}-${env}-report-generator",
        "UserParameters": "{\"reportType\": \"deployment\"}"
      },
      "inputArtifacts": [],
      "outputArtifacts": [
        {
          "name": "TestReport"
        }
      ]
    }
  ]
}
```

3. **Add Manual Approval Stage** (for production deployments):

```json
{
  "name": "ApproveDeployment",
  "actions": [
    {
      "name": "ManualApproval",
      "actionTypeId": {
        "category": "Approval",
        "owner": "AWS",
        "provider": "Manual",
        "version": "1"
      },
      "configuration": {
        "CustomData": "Review the infrastructure test report before proceeding",
        "ExternalEntityLink": "https://console.aws.amazon.com/s3/buckets/${project_name}-${env}-test-reports/latest/"
      },
      "inputArtifacts": []
    }
  ]
}
```

### CodeBuild Integration

For more complex testing scenarios, use CodeBuild:

1. **Create a buildspec.yml**:

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      python: 3.9
  pre_build:
    commands:
      - echo "Starting infrastructure tests"
      - aws lambda invoke --function-name ${PROJECT_NAME}-${ENV}-test-orchestrator --payload '{"runType": "security"}' security_output.json
      - aws lambda invoke --function-name ${PROJECT_NAME}-${ENV}-test-orchestrator --payload '{"runType": "functionality"}' functionality_output.json
  build:
    commands:
      - echo "Processing test results"
      - python process_results.py
  post_build:
    commands:
      - echo "Generating test report"
      - aws lambda invoke --function-name ${PROJECT_NAME}-${ENV}-report-generator --payload '{"reportType": "deployment"}' report_output.json

artifacts:
  files:
    - test_report.pdf
    - test_summary.json
  discard-paths: yes
```

2. **Add CodeBuild Project to Pipeline**:

```json
{
  "name": "InfrastructureTests",
  "actions": [
    {
      "name": "RunInfrastructureTests",
      "actionTypeId": {
        "category": "Build",
        "owner": "AWS",
        "provider": "CodeBuild",
        "version": "1"
      },
      "configuration": {
        "ProjectName": "${project_name}-${env}-infra-tests"
      },
      "inputArtifacts": [
        {
          "name": "SourceCode"
        }
      ],
      "outputArtifacts": [
        {
          "name": "TestResults"
        }
      ]
    }
  ]
}
```

## GitHub Actions Integration

GitHub Actions provides a flexible way to integrate infrastructure testing into your GitHub workflows.

### Basic Integration

1. **Create a workflow file** (`.github/workflows/infra-tests.yml`):

```yaml
name: Infrastructure Testing

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

jobs:
  infrastructure-testing:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Run Security Tests
        id: security
        run: |
          aws lambda invoke \
            --function-name ${GITHUB_REPOSITORY_NAME}-${{ github.ref_name }}-test-orchestrator \
            --payload '{"runType": "security"}' \
            security_output.json
          
      - name: Run Functionality Tests
        id: functionality
        run: |
          aws lambda invoke \
            --function-name ${GITHUB_REPOSITORY_NAME}-${{ github.ref_name }}-test-orchestrator \
            --payload '{"runType": "functionality"}' \
            functionality_output.json
            
      - name: Generate Report
        run: |
          aws lambda invoke \
            --function-name ${GITHUB_REPOSITORY_NAME}-${{ github.ref_name }}-report-generator \
            --payload '{"reportType": "github"}' \
            report_output.json
            
      - name: Download Test Report
        run: |
          aws s3 cp s3://${GITHUB_REPOSITORY_NAME}-${{ github.ref_name }}-test-reports/latest/summary.pdf ./test-report.pdf
          
      - name: Upload Test Report as Artifact
        uses: actions/upload-artifact@v2
        with:
          name: test-report
          path: ./test-report.pdf
```

### Environment-Specific Workflows

For multi-environment pipelines:

```yaml
name: Infrastructure Testing Pipeline

on:
  push:
    branches: [ main, develop ]
  workflow_dispatch:

jobs:
  dev-testing:
    runs-on: ubuntu-latest
    environment: dev
    steps:
      # Configure AWS credentials for dev
      - uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.DEV_AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.DEV_AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      # Run tests in dev environment
      - name: Run Dev Environment Tests
        run: |
          aws lambda invoke \
            --function-name ${GITHUB_REPOSITORY_NAME}-dev-test-orchestrator \
            --payload '{"runType": "full"}' \
            dev_output.json
  
  prod-testing:
    needs: dev-testing
    runs-on: ubuntu-latest
    environment: prod
    steps:
      # Configure AWS credentials for prod
      - uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.PROD_AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.PROD_AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      # Run tests in prod environment
      - name: Run Production Environment Tests
        run: |
          aws lambda invoke \
            --function-name ${GITHUB_REPOSITORY_NAME}-prod-test-orchestrator \
            --payload '{"runType": "full"}' \
            prod_output.json
```

## Jenkins Integration

Jenkins provides a robust platform for integrating infrastructure testing into your CI/CD pipeline.

### Jenkinsfile Example

```groovy
pipeline {
    agent any
    
    parameters {
        choice(name: 'ENVIRONMENT', choices: ['dev', 'test', 'prod'], description: 'Select environment')
        choice(name: 'TEST_TYPE', choices: ['full', 'security', 'functionality', 'architecture'], description: 'Select test type')
    }
    
    stages {
        stage('Setup') {
            steps {
                sh 'aws configure set region us-east-1'
            }
        }
        
        stage('Run Infrastructure Tests') {
            steps {
                script {
                    def testPayload = "{\\\"runType\\\": \\\"${params.TEST_TYPE}\\\"}"
                    sh "aws lambda invoke --function-name project-name-${params.ENVIRONMENT}-test-orchestrator --payload '${testPayload}' test_output.json"
                    
                    // Check test results
                    def testOutput = readFile('test_output.json')
                    def testJson = readJSON text: testOutput
                    
                    if (testJson.status != "success") {
                        error "Infrastructure tests failed: ${testJson.message}"
                    }
                }
            }
        }
        
        stage('Generate Report') {
            steps {
                sh "aws lambda invoke --function-name project-name-${params.ENVIRONMENT}-report-generator --payload '{\\\"reportType\\\": \\\"jenkins\\\"}' report_output.json"
                sh "aws s3 cp s3://project-name-${params.ENVIRONMENT}-test-reports/latest/summary.pdf ./infra-test-report.pdf"
                archiveArtifacts artifacts: 'infra-test-report.pdf', fingerprint: true
            }
        }
        
        stage('Deploy if Tests Pass') {
            when {
                expression { return params.ENVIRONMENT != 'prod' }
            }
            steps {
                echo "Proceeding with deployment to ${params.ENVIRONMENT}"
                // Deployment steps here
            }
        }
        
        stage('Request Production Approval') {
            when {
                expression { return params.ENVIRONMENT == 'prod' }
            }
            steps {
                input message: "Deploy to production?", ok: "Deploy"
            }
        }
    }
    
    post {
        always {
            echo "Test results available at: https://s3.console.aws.amazon.com/s3/buckets/project-name-${params.ENVIRONMENT}-test-reports/"
        }
    }
}
```

## GitLab CI Integration

GitLab CI/CD can be configured to run infrastructure tests as part of your pipeline.

### .gitlab-ci.yml Example

```yaml
stages:
  - test
  - report
  - deploy

variables:
  PROJECT_NAME: "my-aws-project"

infrastructure-tests-dev:
  stage: test
  image: amazon/aws-cli:latest
  script:
    - aws lambda invoke --function-name $PROJECT_NAME-dev-test-orchestrator --payload '{"runType": "full"}' output.json
    - cat output.json
    - |
      if grep -q "\"status\":\"failed\"" output.json; then
        echo "Tests failed"
        exit 1
      fi
  environment:
    name: dev
  only:
    - develop

infrastructure-tests-prod:
  stage: test
  image: amazon/aws-cli:latest
  script:
    - aws lambda invoke --function-name $PROJECT_NAME-prod-test-orchestrator --payload '{"runType": "full"}' output.json
    - cat output.json
    - |
      if grep -q "\"status\":\"failed\"" output.json; then
        echo "Tests failed"
        exit 1
      fi
  environment:
    name: prod
  only:
    - main
  when: manual

generate-report:
  stage: report
  image: amazon/aws-cli:latest
  script:
    - aws lambda invoke --function-name $PROJECT_NAME-${CI_ENVIRONMENT_NAME}-report-generator --payload '{"reportType": "gitlab"}' report.json
    - aws s3 cp s3://$PROJECT_NAME-${CI_ENVIRONMENT_NAME}-test-reports/latest/summary.pdf ./report.pdf
  artifacts:
    paths:
      - report.pdf
    expire_in: 1 week
  dependencies:
    - infrastructure-tests-dev
    - infrastructure-tests-prod

deploy:
  stage: deploy
  script:
    - echo "Deploying application..."
  only:
    - main
  when: manual
  environment:
    name: production
  dependencies:
    - generate-report
```

## Best Practices

### 1. Incremental Testing Approach

Implement a progressive testing strategy that runs different test types at different stages:

1. **Pre-commit**: Basic security checks
2. **Pull Request**: Critical functionality tests
3. **Merge to Dev**: Full security and functionality tests
4. **Deploy to Test**: Architecture validation
5. **Deploy to Prod**: Comprehensive testing

### 2. Test Result Handling

- **Fail Fast**: Fail the pipeline immediately on critical security issues
- **Warning Mode**: For non-critical issues, proceed but flag warnings
- **Historical Tracking**: Store test results to track improvements over time

### 3. Environment-Specific Configuration

Configure test severity thresholds based on the environment:

```hcl
# Dev environment - more permissive
failure_thresholds = {
  security_critical = 1,   # Fail on any critical security issues
  security_high = 5,       # Allow up to 5 high security issues
  functionality = 0.9      # 90% of functionality tests must pass
}

# Production environment - strict
failure_thresholds = {
  security_critical = 0,   # No critical security issues allowed
  security_high = 0,       # No high security issues allowed
  functionality = 1.0      # 100% of functionality tests must pass
}
```

### 4. Notification Strategy

Implement targeted notifications based on test results:

- **Critical Issues**: Immediate Slack/Teams notification + email
- **High Issues**: Daily digest email
- **Medium/Low Issues**: Weekly report

## Testing Stages

Integrate different types of tests at different pipeline stages:

### 1. Pre-Deployment Testing

Run before deploying new infrastructure:

```yaml
infrastructure-validation:
  stage: validate
  script:
    - aws lambda invoke --function-name $PROJECT_NAME-$ENV-test-orchestrator --payload '{"runType": "architecture"}' arch_output.json
```

### 2. Security Testing

Focus on security issues:

```yaml
security-scanning:
  stage: security
  script:
    - aws lambda invoke --function-name $PROJECT_NAME-$ENV-test-orchestrator --payload '{"runType": "security"}' security_output.json
```

### 3. Post-Deployment Testing

Verify infrastructure after deployment:

```yaml
infrastructure-verification:
  stage: verify
  script:
    - aws lambda invoke --function-name $PROJECT_NAME-$ENV-test-orchestrator --payload '{"runType": "functionality"}' func_output.json
```

### 4. Scheduled Comprehensive Testing

Regular full testing:

```yaml
full-infrastructure-audit:
  stage: audit
  script:
    - aws lambda invoke --function-name $PROJECT_NAME-$ENV-test-orchestrator --payload '{"runType": "full"}' full_output.json
  only:
    - schedules
```

## Reference Implementations

### AWS CodePipeline with Infrastructure Testing

This example shows a complete CodePipeline implementation with infrastructure testing:

1. **Source Stage**: Pull code from CodeCommit/GitHub
2. **Build Stage**: Build application
3. **Infrastructure Testing Stage**: Test infrastructure
4. **Approval Stage**: Review test results
5. **Deploy Stage**: Deploy application

```bash
# Create the infrastructure testing stage
aws codepipeline create-pipeline --cli-input-json file://pipeline-with-infra-testing.json

# Example trigger command for testing
aws codepipeline start-pipeline-execution --name MyApplicationPipeline
```

### GitHub Actions Workflow with Environment Progression

This workflow shows progression through environments with testing gates:

```yaml
name: Deploy with Infrastructure Testing

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build application
        run: |
          # Build steps
          
  test-dev:
    needs: build
    runs-on: ubuntu-latest
    environment: dev
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.DEV_AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.DEV_AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
          
      - name: Deploy to Dev
        run: |
          # Deploy to dev environment
          
      - name: Test Infrastructure
        run: |
          aws lambda invoke --function-name project-dev-test-orchestrator --payload '{"runType": "full"}' output.json
          
  test-staging:
    needs: test-dev
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.STAGING_AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.STAGING_AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
          
      - name: Deploy to Staging
        run: |
          # Deploy to staging environment
          
      - name: Test Infrastructure
        run: |
          aws lambda invoke --function-name project-staging-test-orchestrator --payload '{"runType": "full"}' output.json
          
  deploy-prod:
    needs: test-staging
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.PROD_AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.PROD_AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
          
      - name: Deploy to Production
        run: |
          # Deploy to production environment
          
      - name: Verify Production Infrastructure
        run: |
          aws lambda invoke --function-name project-prod-test-orchestrator --payload '{"runType": "functionality"}' output.json
```