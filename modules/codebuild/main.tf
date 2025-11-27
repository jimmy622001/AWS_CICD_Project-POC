# CodeBuild module implementation

provider "aws" {
  region = var.region
}

# IAM Role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "${var.project}-${var.environment}-codebuild-role"

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
  
  tags = var.tags
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "${var.project}-${var.environment}-codebuild-policy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
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
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
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

# Extra policy for infrastructure build projects (needs AWS resource creation permissions)
resource "aws_iam_role_policy" "infrastructure_build_policy" {
  name = "${var.project}-${var.environment}-infra-build-policy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:*",
          "iam:*",
          "route53:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "cloudwatch:*",
          "s3:*",
          "sns:*",
          "cloudformation:*",
          "rds:*",
          "sqs:*",
          "eks:*",
          "logs:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Infrastructure CodeBuild Project
resource "aws_codebuild_project" "infrastructure_build" {
  name          = "${var.project}-${var.environment}-infrastructure-build"
  description   = "Build project for ${var.project} ${var.environment} infrastructure"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = "60"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_REGION"
      value = var.region
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }
    
    environment_variable {
      name  = "ARTIFACT_BUCKET"
      value = var.artifact_bucket_name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec/infrastructure.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project}-${var.environment}-infrastructure-build"
      stream_name = "build-log"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-${var.environment}-infrastructure-build"
    }
  )
}

# EKS CodeBuild Project
resource "aws_codebuild_project" "eks_build" {
  name          = "${var.project}-${var.environment}-eks-build"
  description   = "Build project for ${var.project} ${var.environment} EKS"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = "60"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_REGION"
      value = var.region
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }
    
    environment_variable {
      name  = "ARTIFACT_BUCKET"
      value = var.artifact_bucket_name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec/eks.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project}-${var.environment}-eks-build"
      stream_name = "build-log"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-${var.environment}-eks-build"
    }
  )
}

# App CodeBuild Project
resource "aws_codebuild_project" "app_build" {
  name          = "${var.project}-${var.environment}-app-build"
  description   = "Build project for ${var.project} ${var.environment} application"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = "30"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true  # Required for Docker commands

    environment_variable {
      name  = "AWS_REGION"
      value = var.region
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }
    
    environment_variable {
      name  = "ARTIFACT_BUCKET"
      value = var.artifact_bucket_name
    }
    
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.aws_account_id
    }
    
    environment_variable {
      name  = "ECR_REPOSITORY_NAME"
      value = "${var.project}-${var.environment}-app"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec/application.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project}-${var.environment}-app-build"
      stream_name = "build-log"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-${var.environment}-app-build"
    }
  )
}

# Pre-Deployment Validation CodeBuild Project
resource "aws_codebuild_project" "pre_deployment_validation" {
  name          = "${var.project}-${var.environment}-pre-deployment-validation"
  description   = "Pre-deployment validation for ${var.project} ${var.environment} infrastructure"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = "30"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false

    environment_variable {
      name  = "AWS_REGION"
      value = var.region
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }

    environment_variable {
      name  = "ARTIFACT_BUCKET"
      value = var.artifact_bucket_name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec/pre_deployment_validation.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project}-${var.environment}-pre-deployment-validation"
      stream_name = "build-log"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-${var.environment}-pre-deployment-validation"
    }
  )
}

# ECR Repository for application
resource "aws_ecr_repository" "app_repository" {
  name                 = "${var.project}-${var.environment}-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-${var.environment}-app-ecr"
    }
  )
}