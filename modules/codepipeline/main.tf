# CodePipeline module implementation

provider "aws" {
  region = var.region
}

# IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.project}-${var.environment}-codepipeline-role"

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
  
  tags = var.tags
}

# Policy for the CodePipeline role
resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.project}-${var.environment}-codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject",
          "s3:ListBucket",
        ]
        Effect   = "Allow"
        Resource = [
          "${var.artifact_bucket_arn}",
          "${var.artifact_bucket_arn}/*",
        ]
      },
      {
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:UploadArchive",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:CancelUploadArchive",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
        ]
        Effect   = "Allow"
        Resource = var.kms_key_arn
      }
    ]
  })
}

# SNS Topic for manual approvals
resource "aws_sns_topic" "pipeline_approval" {
  name = "${var.project}-${var.environment}-pipeline-approval"
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project}-${var.environment}-pipeline-approval"
    }
  )
}

# Infrastructure Pipeline
resource "aws_codepipeline" "infrastructure_pipeline" {
  name     = "${var.project}-${var.environment}-infrastructure"
  role_arn = aws_iam_role.codepipeline_role.arn

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
        RepositoryName = var.infrastructure_repository_name
        BranchName     = "main"
      }
    }
  }

  stage {
    name = "PreDeploymentValidation"
  
    action {
      name             = "ValidateArchitecture"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["validation_output"]
      version          = "1"
  
      configuration = {
        ProjectName = var.pre_deployment_validation_project_name
      }
    }
  }
  
  stage {
    name = "Build"
  
    action {
      name             = "BuildAndDeploy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
  
      configuration = {
        ProjectName = var.infrastructure_build_project_name
      }
    }
  }

  # Only add manual approval for production and DR environments
  dynamic "stage" {
    for_each = var.environment == "prod" || var.environment == "dr" ? [1] : []
    content {
      name = "Approval"

      action {
        name     = "Approval"
        category = "Approval"
        owner    = "AWS"
        provider = "Manual"
        version  = "1"

        configuration = {
          NotificationArn = aws_sns_topic.pipeline_approval.arn
          CustomData      = "Please review the infrastructure changes before proceeding"
        }
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-${var.environment}-infrastructure-pipeline"
    }
  )
}

# EKS Pipeline
resource "aws_codepipeline" "eks_pipeline" {
  name     = "${var.project}-${var.environment}-eks"
  role_arn = aws_iam_role.codepipeline_role.arn

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
        RepositoryName = var.eks_repository_name
        BranchName     = "main"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "BuildAndDeploy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = var.eks_build_project_name
      }
    }
  }

  # Only add manual approval for production and DR environments
  dynamic "stage" {
    for_each = var.environment == "prod" || var.environment == "dr" ? [1] : []
    content {
      name = "Approval"

      action {
        name     = "Approval"
        category = "Approval"
        owner    = "AWS"
        provider = "Manual"
        version  = "1"

        configuration = {
          NotificationArn = aws_sns_topic.pipeline_approval.arn
          CustomData      = "Please review the EKS changes before proceeding"
        }
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-${var.environment}-eks-pipeline"
    }
  )
}

# Application Pipeline
resource "aws_codepipeline" "app_pipeline" {
  name     = "${var.project}-${var.environment}-application"
  role_arn = aws_iam_role.codepipeline_role.arn

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
        RepositoryName = var.app_repository_name
        BranchName     = "main"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "BuildAndPush"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = var.app_build_project_name
      }
    }
  }

  # Only add manual approval for production and DR environments
  dynamic "stage" {
    for_each = var.environment == "prod" || var.environment == "dr" ? [1] : []
    content {
      name = "Approval"

      action {
        name     = "Approval"
        category = "Approval"
        owner    = "AWS"
        provider = "Manual"
        version  = "1"

        configuration = {
          NotificationArn = aws_sns_topic.pipeline_approval.arn
          CustomData      = "Please review the application changes before proceeding"
        }
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-${var.environment}-application-pipeline"
    }
  )
}