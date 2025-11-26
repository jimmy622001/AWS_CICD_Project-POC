# Required providers for this module
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
      configuration_aliases = [ aws.primary, aws.dr ]
    }
  }
}

variable "project_name" {
  description = "Name of the project being tested"
  type        = string
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
}

variable "dr_region" {
  description = "Disaster Recovery AWS region"
  type        = string
}

variable "failover_components" {
  description = "Components to be included in failover testing"
  type        = list(string)
}

resource "aws_codepipeline" "dr_test_pipeline" {
  name     = "${var.project_name}-dr-test-pipeline"
  role_arn = aws_iam_role.dr_pipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.dr_artifacts.bucket
    type     = "S3"
  }

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
        BranchName     = "dr-test"
      }
    }
  }

  stage {
    name = "TestSetup"

    action {
      name            = "PrepareTestEnv"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output"]
      output_artifacts = ["setup_output"]

      configuration = {
        ProjectName = aws_codebuild_project.dr_test_setup.name
      }
    }
  }

  stage {
    name = "PerformFailover"

    action {
      name            = "ExecuteFailover"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["setup_output"]
      output_artifacts = ["failover_output"]

      configuration = {
        ProjectName = aws_codebuild_project.dr_failover.name
      }
    }
  }

  stage {
    name = "ValidateFailover"

    action {
      name            = "FailoverValidation"
      category        = "Test"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["failover_output"]
      output_artifacts = ["validation_output"]

      configuration = {
        ProjectName = aws_codebuild_project.dr_validation.name
      }
    }
  }

  stage {
    name = "PerformFailback"

    action {
      name            = "ExecuteFailback"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["validation_output"]
      output_artifacts = ["failback_output"]

      configuration = {
        ProjectName = aws_codebuild_project.dr_failback.name
      }
    }
  }

  stage {
    name = "Report"

    action {
      name            = "GenerateReport"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["failback_output"]

      configuration = {
        ProjectName = aws_codebuild_project.dr_report.name
      }
    }
  }
}

resource "aws_s3_bucket" "dr_artifacts" {
  bucket = "${var.project_name}-dr-test-artifacts"
  acl    = "private"
}

# IAM roles and policies
resource "aws_iam_role" "dr_pipeline_role" {
  name = "${var.project_name}-dr-pipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role" "dr_codebuild_role" {
  name = "${var.project_name}-dr-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_codebuild_project" "dr_test_setup" {
  name          = "${var.project_name}-dr-test-setup"
  description   = "Setup DR test environment for ${var.project_name}"
  build_timeout = "60"
  service_role  = aws_iam_role.dr_codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "PROJECT_NAME"
      value = var.project_name
    }

    environment_variable {
      name  = "PRIMARY_REGION"
      value = var.primary_region
    }

    environment_variable {
      name  = "DR_REGION"
      value = var.dr_region
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = <<EOF
version: 0.2
phases:
  install:
    runtime-versions:
      python: 3.9
  pre_build:
    commands:
      - echo Installing dependencies...
      - pip install boto3 pytest
  build:
    commands:
      - echo Setting up DR test environment...
      - python ./dr-testing-framework/scripts/setup_dr_test.py
  post_build:
    commands:
      - echo DR test environment setup complete
artifacts:
  files:
    - test-config.json
EOF
  }
}

# Other CodeBuild projects
resource "aws_codebuild_project" "dr_failover" {
  name          = "${var.project_name}-dr-failover"
  description   = "Execute failover for ${var.project_name}"
  build_timeout = "60"
  service_role  = aws_iam_role.dr_codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "PRIMARY_REGION"
      value = var.primary_region
    }

    environment_variable {
      name  = "DR_REGION"
      value = var.dr_region
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = <<EOF
version: 0.2
phases:
  install:
    runtime-versions:
      python: 3.9
  pre_build:
    commands:
      - echo Installing dependencies...
      - pip install boto3 awscli
  build:
    commands:
      - echo Executing failover script...
      - sh ./dr-testing-framework/scripts/failover_test.sh
  post_build:
    commands:
      - echo Failover execution complete
artifacts:
  files:
    - failover-results.json
EOF
  }
}

resource "aws_codebuild_project" "dr_validation" {
  name          = "${var.project_name}-dr-validation"
  description   = "Validate failover for ${var.project_name}"
  build_timeout = "60"
  service_role  = aws_iam_role.dr_codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "PRIMARY_REGION"
      value = var.primary_region
    }

    environment_variable {
      name  = "DR_REGION"
      value = var.dr_region
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = <<EOF
version: 0.2
phases:
  install:
    runtime-versions:
      python: 3.9
  pre_build:
    commands:
      - echo Installing dependencies...
      - pip install boto3 pytest
  build:
    commands:
      - echo Validating failover...
      - sh ./dr-testing-framework/scripts/data_validation.sh
  post_build:
    commands:
      - echo Validation complete
artifacts:
  files:
    - validation-results.json
EOF
  }
}

resource "aws_codebuild_project" "dr_failback" {
  name          = "${var.project_name}-dr-failback"
  description   = "Execute failback for ${var.project_name}"
  build_timeout = "60"
  service_role  = aws_iam_role.dr_codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "PRIMARY_REGION"
      value = var.primary_region
    }

    environment_variable {
      name  = "DR_REGION"
      value = var.dr_region
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = <<EOF
version: 0.2
phases:
  install:
    runtime-versions:
      python: 3.9
  pre_build:
    commands:
      - echo Installing dependencies...
      - pip install boto3 awscli
  build:
    commands:
      - echo Executing failback...
      - sh ./dr-testing-framework/scripts/failover_test.sh --failback
  post_build:
    commands:
      - echo Failback execution complete
artifacts:
  files:
    - failback-results.json
EOF
  }
}

resource "aws_codebuild_project" "dr_report" {
  name          = "${var.project_name}-dr-report"
  description   = "Generate report for DR test of ${var.project_name}"
  build_timeout = "60"
  service_role  = aws_iam_role.dr_codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "PROJECT_NAME"
      value = var.project_name
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = <<EOF
version: 0.2
phases:
  install:
    runtime-versions:
      python: 3.9
  pre_build:
    commands:
      - echo Installing dependencies...
      - pip install boto3 markdown
  build:
    commands:
      - echo Generating DR test report...
      - python ./dr-testing-framework/scripts/generate_report.py
  post_build:
    commands:
      - echo Report generation complete
artifacts:
  files:
    - dr-test-report.md
    - dr-test-report.html
EOF
  }
}

output "pipeline_id" {
  description = "ID of the DR test pipeline"
  value       = aws_codepipeline.dr_test_pipeline.id
}