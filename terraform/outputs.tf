output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.app.id
}

output "public_ip" {
  description = "Elastic IP. Set this as the EC2_HOST GitHub secret for the CD pipeline."
  value       = aws_eip.app.public_ip
}

output "app_url" {
  description = "URL the deployed web app is served at."
  value       = "http://${aws_eip.app.public_ip}:${var.app_port}"
}

output "dynamodb_table_name" {
  description = "Submissions table name (matches the app's DYNAMODB_TABLE)."
  value       = aws_dynamodb_table.submissions.name
}
