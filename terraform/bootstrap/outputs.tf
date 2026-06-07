output "state_bucket_name" {
  description = "S3 bucket name to set as the backend `bucket` in ../versions.tf."
  value       = aws_s3_bucket.state.id
}

output "lock_table_name" {
  description = "DynamoDB table name to set as the backend `dynamodb_table`."
  value       = aws_dynamodb_table.lock.name
}

output "github_actions_role_arn" {
  description = "Set this as the GitHub Actions repository variable AWS_ROLE_ARN."
  value       = aws_iam_role.github_actions.arn
}
