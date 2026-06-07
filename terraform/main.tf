data "aws_caller_identity" "current" {}

# Use the default VPC rather than building our own.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Latest Amazon Linux 2023 AMI.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Partition key matches the id written in src/db.js.
resource "aws_dynamodb_table" "submissions" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# Instance role so the app can write to the table without stored keys.
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.project_name}-app"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "app_dynamodb" {
  statement {
    sid       = "WriteSubmissions"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.submissions.arn]
  }
}

resource "aws_iam_role_policy" "app_dynamodb" {
  name   = "${var.project_name}-dynamodb-write"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_dynamodb.json
}

# Lets us connect via SSM if SSH ever isn't an option.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.project_name}-app"
  role = aws_iam_role.app.name
}

resource "aws_security_group" "app" {
  name        = "${var.project_name}-app"
  description = "WBP3 web app: app port and SSH ingress"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "App HTTP"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = [var.app_ingress_cidr]
  }

  ingress {
    description = "SSH for CD deploys"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_ingress_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-app"
  }
}

# user_data installs Node and the service; the app code arrives via the pipeline.
resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.app.name
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    aws_region     = var.aws_region
    dynamodb_table = var.dynamodb_table_name
    app_port       = var.app_port
  })

  # Replace the instance if user_data changes.
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required" # enforce IMDSv2
  }

  tags = {
    Name = "${var.project_name}-app"
  }
}
