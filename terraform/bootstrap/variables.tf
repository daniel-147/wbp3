variable "aws_region" {
  description = "AWS region for the state bucket, lock table and OIDC role."
  type        = string
  default     = "eu-west-2"
}

variable "state_bucket_name" {
  description = "Globally-unique name for the S3 bucket that stores Terraform state."
  type        = string
}

variable "lock_table_name" {
  description = "Name of the DynamoDB table used for Terraform state locking."
  type        = string
  default     = "wbp3-tflock"
}

variable "github_repo" {
  description = "GitHub repository allowed to assume the Actions role, as owner/repo."
  type        = string
}

variable "github_environment" {
  description = "GitHub Actions environment the role is restricted to (matches the Terraform workflow)."
  type        = string
  default     = "infrastructure"
}
