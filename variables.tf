variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, prod, dr)"
  type        = string
  validation {
    condition     = contains(["dev", "prod", "dr"], var.environment)
    error_message = "Environment must be one of: dev, prod, dr"
  }
}

variable "repositories" {
  description = "Map of CodeCommit repositories to create"
  type = map(object({
    description     = string
    default_branch  = string
  }))
  default = {
    infrastructure = {
      description    = "Infrastructure as Code repository"
      default_branch = "main"
    },
    eks = {
      description    = "EKS configuration repository"
      default_branch = "main"
    },
    application = {
      description    = "Application code repository"
      default_branch = "main"
    }
  }
}

variable "build_projects" {
  description = "Map of CodeBuild projects to create"
  type = map(object({
    repository_name       = string
    buildspec            = string
    environment_type     = string
    compute_type         = string
    image                = string
    privileged_mode      = bool
    environment_variables = map(object({
      value = string
      type  = string
    }))
  }))
  default = {
    infrastructure-build = {
      repository_name      = "infrastructure"
      buildspec           = "buildspec/infrastructure.yml"
      environment_type    = "LINUX_CONTAINER"
      compute_type        = "BUILD_GENERAL1_SMALL"
      image               = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
      privileged_mode     = false
      environment_variables = {
        TERRAFORM_VERSION = {
          value = "1.5.0"
          type  = "PLAINTEXT"
        }
      }
    },
    eks-build = {
      repository_name      = "eks"
      buildspec           = "buildspec/eks.yml"
      environment_type    = "LINUX_CONTAINER"
      compute_type        = "BUILD_GENERAL1_SMALL"
      image               = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
      privileged_mode     = false
      environment_variables = {
        TERRAFORM_VERSION = {
          value = "1.5.0"
          type  = "PLAINTEXT"
        },
        KUBECTL_VERSION = {
          value = "1.26.0"
          type  = "PLAINTEXT"
        }
      }
    },
    application-build = {
      repository_name      = "application"
      buildspec           = "buildspec/application.yml"
      environment_type    = "LINUX_CONTAINER"
      compute_type        = "BUILD_GENERAL1_SMALL"
      image               = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
      privileged_mode     = true  # For Docker operations
      environment_variables = {
        ECR_REPOSITORY = {
          value = "application-repo"
          type  = "PLAINTEXT"
        }
      }
    }
  }
}

variable "deployment_apps" {
  description = "Map of CodeDeploy applications to create"
  type = map(object({
    compute_platform = string
    deployment_groups = map(object({
      deployment_config_name = string
      ec2_tag_filters = list(object({
        key   = string
        value = string
        type  = string
      }))
      auto_rollback_enabled = bool
      auto_rollback_events  = list(string)
    }))
  }))
  default = {
    application = {
      compute_platform = "ECS"
      deployment_groups = {
        application-dg = {
          deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
          ec2_tag_filters        = []
          auto_rollback_enabled  = true
          auto_rollback_events   = ["DEPLOYMENT_FAILURE"]
        }
      }
    }
  }
}

variable "pipelines" {
  description = "Map of CodePipeline pipelines to create"
  type = map(object({
    repository_name     = string
    stages             = list(object({
      name = string
      actions = list(object({
        name             = string
        category         = string
        owner            = string
        provider         = string
        version          = string
        input_artifacts  = list(string)
        output_artifacts = list(string)
        configuration    = map(string)
      }))
    }))
  }))
  default = {
    infrastructure-pipeline = {
      repository_name = "infrastructure"
      stages = [
        {
          name = "Source"
          actions = [
            {
              name             = "Source"
              category         = "Source"
              owner            = "AWS"
              provider         = "CodeCommit"
              version          = "1"
              input_artifacts  = []
              output_artifacts = ["source_output"]
              configuration = {
                RepositoryName       = "infrastructure"
                BranchName           = "main"
                PollForSourceChanges = "false"
              }
            }
          ]
        },
        {
          name = "Build"
          actions = [
            {
              name             = "TerraformBuild"
              category         = "Build"
              owner            = "AWS"
              provider         = "CodeBuild"
              version          = "1"
              input_artifacts  = ["source_output"]
              output_artifacts = ["build_output"]
              configuration = {
                ProjectName = "infrastructure-build"
              }
            }
          ]
        },
        {
          name = "Approve"
          actions = [
            {
              name             = "ManualApproval"
              category         = "Approval"
              owner            = "AWS"
              provider         = "Manual"
              version          = "1"
              input_artifacts  = []
              output_artifacts = []
              configuration = {
                CustomData = "Please review the infrastructure changes before deployment"
              }
            }
          ]
        },
        {
          name = "Deploy"
          actions = [
            {
              name             = "TerraformApply"
              category         = "Build"
              owner            = "AWS"
              provider         = "CodeBuild"
              version          = "1"
              input_artifacts  = ["build_output"]
              output_artifacts = []
              configuration = {
                ProjectName = "infrastructure-deploy"
              }
            }
          ]
        }
      ]
    },
    eks-pipeline = {
      repository_name = "eks"
      stages = [
        {
          name = "Source"
          actions = [
            {
              name             = "Source"
              category         = "Source"
              owner            = "AWS"
              provider         = "CodeCommit"
              version          = "1"
              input_artifacts  = []
              output_artifacts = ["source_output"]
              configuration = {
                RepositoryName       = "eks"
                BranchName           = "main"
                PollForSourceChanges = "false"
              }
            }
          ]
        },
        {
          name = "Build"
          actions = [
            {
              name             = "EKSBuild"
              category         = "Build"
              owner            = "AWS"
              provider         = "CodeBuild"
              version          = "1"
              input_artifacts  = ["source_output"]
              output_artifacts = ["build_output"]
              configuration = {
                ProjectName = "eks-build"
              }
            }
          ]
        },
        {
          name = "Approve"
          actions = [
            {
              name             = "ManualApproval"
              category         = "Approval"
              owner            = "AWS"
              provider         = "Manual"
              version          = "1"
              input_artifacts  = []
              output_artifacts = []
              configuration = {
                CustomData = "Please review the EKS changes before deployment"
              }
            }
          ]
        },
        {
          name = "Deploy"
          actions = [
            {
              name             = "EKSApply"
              category         = "Build"
              owner            = "AWS"
              provider         = "CodeBuild"
              version          = "1"
              input_artifacts  = ["build_output"]
              output_artifacts = []
              configuration = {
                ProjectName = "eks-deploy"
              }
            }
          ]
        }
      ]
    },
    application-pipeline = {
      repository_name = "application"
      stages = [
        {
          name = "Source"
          actions = [
            {
              name             = "Source"
              category         = "Source"
              owner            = "AWS"
              provider         = "CodeCommit"
              version          = "1"
              input_artifacts  = []
              output_artifacts = ["source_output"]
              configuration = {
                RepositoryName       = "application"
                BranchName           = "main"
                PollForSourceChanges = "false"
              }
            }
          ]
        },
        {
          name = "Build"
          actions = [
            {
              name             = "BuildAndTest"
              category         = "Build"
              owner            = "AWS"
              provider         = "CodeBuild"
              version          = "1"
              input_artifacts  = ["source_output"]
              output_artifacts = ["build_output"]
              configuration = {
                ProjectName = "application-build"
              }
            }
          ]
        },
        {
          name = "Deploy"
          actions = [
            {
              name             = "DeployToECS"
              category         = "Deploy"
              owner            = "AWS"
              provider         = "CodeDeployToECS"
              version          = "1"
              input_artifacts  = ["build_output"]
              output_artifacts = []
              configuration = {
                ApplicationName                = "application"
                DeploymentGroupName            = "application-dg"
                TaskDefinitionTemplateArtifact = "build_output"
                TaskDefinitionTemplatePath     = "taskdef.json"
                AppSpecTemplateArtifact        = "build_output"
                AppSpecTemplatePath            = "appspec.yml"
              }
            }
          ]
        }
      ]
    }
  }
}