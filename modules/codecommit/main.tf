# CodeCommit module implementation

provider "aws" {
  region = var.region
}

# CodeCommit repositories
resource "aws_codecommit_repository" "infra_repository" {
  repository_name = "${var.project}-${var.environment}-infrastructure"
  description     = "Infrastructure code for ${var.project} ${var.environment} environment"
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project}-${var.environment}-infra-repo"
    }
  )
}

resource "aws_codecommit_repository" "eks_repository" {
  repository_name = "${var.project}-${var.environment}-eks"
  description     = "EKS configuration for ${var.project} ${var.environment} environment"
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project}-${var.environment}-eks-repo"
    }
  )
}

resource "aws_codecommit_repository" "app_repository" {
  repository_name = "${var.project}-${var.environment}-application"
  description     = "Application code for ${var.project} ${var.environment} environment"
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project}-${var.environment}-app-repo"
    }
  )
}

# IAM trigger role for notifications
resource "aws_iam_role" "codecommit_trigger_role" {
  name = "${var.project}-${var.environment}-codecommit-trigger-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codecommit.amazonaws.com"
        }
      },
    ]
  })
  
  tags = var.tags
}

# IAM policy for the trigger role
resource "aws_iam_role_policy" "codecommit_trigger_policy" {
  name = "${var.project}-${var.environment}-codecommit-trigger-policy"
  role = aws_iam_role.codecommit_trigger_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sns:Publish",
        ]
        Effect   = "Allow"
        Resource = "*"  # You might want to restrict this to specific SNS topics
      },
    ]
  })
}