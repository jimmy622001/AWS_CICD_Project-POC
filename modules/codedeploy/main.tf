# CodeDeploy module implementation

provider "aws" {
  region = var.region
}

# IAM Role for CodeDeploy
resource "aws_iam_role" "codedeploy_role" {
  name = "${var.project}-${var.environment}-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      },
    ]
  })
  
  tags = var.tags
}

# Attach AWS managed policy for CodeDeploy
resource "aws_iam_role_policy_attachment" "codedeploy_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRoleForECS"
  role       = aws_iam_role.codedeploy_role.name
}

# Create a CodeDeploy application
resource "aws_codedeploy_app" "app" {
  name             = "${var.project}-${var.environment}-app"
  compute_platform = "ECS"
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project}-${var.environment}-app"
    }
  )
}

# Note: For EKS deployments, we're using direct kubectl via CodeBuild
# rather than CodeDeploy since CodeDeploy doesn't natively support EKS.
# This CodeDeploy module is included for completeness but may be more
# relevant for ECS or Lambda deployments.