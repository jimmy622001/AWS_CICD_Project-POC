provider "aws" {
  region = "eu-west-1"  # Use an appropriate region
}

# Test Pipeline specifically for test branches
resource "aws_codepipeline" "test_pipeline" {
  name     = "${var.project}-test-pipeline"
  role_arn = module.codepipeline.codepipeline_role_arn

  artifact_store {
    location = var.artifact_bucket_name
    type     = "S3"
    
    encryption_key {
      id   = var.kms_key_arn
      type = "KMS"
    }
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
        RepositoryName = var.test_repository_name
        BranchName     = var.test_branch_name  # This will be a variable that can be set for testing
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "BuildAndTest"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = var.test_build_project_name
      }
    }
  }

  tags = {
    Name    = "${var.project}-test-pipeline"
    Project = var.project
    Environment = "test"
  }
}

variable "test_repository_name" {
  description = "Name of the test repository"
  type        = string
}

variable "test_branch_name" {
  description = "Name of the test branch"
  type        = string
  default     = "feature/pre-deployment-validation"  # Default to your test branch
}

variable "test_build_project_name" {
  description = "Name of the test build project"
  type        = string
}