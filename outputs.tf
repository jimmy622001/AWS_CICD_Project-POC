output "codecommit_repositories" {
  description = "Map of created CodeCommit repositories"
  value       = module.codecommit_repos.repository_map
}

output "codebuild_projects" {
  description = "Map of created CodeBuild projects"
  value       = module.codebuild_projects.project_map
}

output "codedeploy_applications" {
  description = "Map of created CodeDeploy applications"
  value       = module.codedeploy_apps.app_map
}

output "codepipelines" {
  description = "Map of created CodePipeline pipelines"
  value       = module.ci_cd_pipelines.pipeline_map
}

output "artifact_bucket" {
  description = "S3 bucket for CI/CD artifacts"
  value       = aws_s3_bucket.artifacts_bucket.bucket
}