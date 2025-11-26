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

# IAM role and policies would be defined here

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

# Similar resource blocks would be defined for:
# - aws_codebuild_project.dr_failover
# - aws_codebuild_project.dr_validation
# - aws_codebuild_project.dr_failback
# - aws_codebuild_project.dr_report

output "pipeline_id" {
  description = "ID of the DR test pipeline"
  value       = aws_codepipeline.dr_test_pipeline.id
}