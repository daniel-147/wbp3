variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Prefix used to name and tag resources."
  type        = string
  default     = "wbp3"
}

variable "dynamodb_table_name" {
  description = "DynamoDB table that stores form submissions. Must match DYNAMODB_TABLE in the app."
  type        = string
  default     = "wbp3-submissions"
}

variable "instance_type" {
  description = "EC2 instance type. t3.micro / t2.micro are free-tier eligible."
  type        = string
  default     = "t3.micro"
}

variable "app_port" {
  description = "Port the Express app listens on."
  type        = number
  default     = 3000
}

variable "key_pair_name" {
  description = "Name of an existing EC2 key pair for SSH access (used by the CD pipeline). Leave empty to launch without a key pair."
  type        = string
  default     = ""
}

variable "ssh_ingress_cidr" {
  description = "CIDR allowed to reach SSH (port 22). Defaults open because the CD pipeline deploys over SSH from GitHub-hosted runners (whose IPs vary); access is protected by the EC2 key pair. Restrict to your own IP only if you are not deploying via the pipeline."
  type        = string
  default     = "0.0.0.0/0"
}

variable "app_ingress_cidr" {
  description = "CIDR allowed to reach the app port. 0.0.0.0/0 makes the demo publicly reachable."
  type        = string
  default     = "0.0.0.0/0"
}
