# WBP3 — CI/CD Pipeline & Infrastructure as Code

A small Express web application that collects personal details and stores them
in AWS DynamoDB, used to demonstrate an automated CI/CD pipeline (GitHub
Actions) and Infrastructure as Code (Terraform on AWS).

This repository covers the project deliverables: the web application, the
pipeline that builds/tests/deploys it, and the IaC that provisions its
infrastructure.

## Architecture

```
  Developer push ──► GitHub Actions ──► Jest tests ──► SSH deploy ──► EC2 (systemd)
                                                                        │
                                                                        ▼
                                                                   DynamoDB
  Terraform (manual workflow / local) ──► EC2 · DynamoDB · IAM role · Security group
```

- **App** — Express, Node 20. Writes submissions to DynamoDB via an IAM
  instance role (no credentials in code).
- **CI/CD** — [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml): tests
  on every push/PR to `main`; deploys to EC2 over SSH on a passing push to `main`.
- **IaC** — [terraform/](terraform/): DynamoDB table, EC2 instance, IAM instance
  role, security group. Remote state in S3.
- **Infra workflow** — [.github/workflows/terraform.yml](.github/workflows/terraform.yml):
  manual `plan` / `apply` / `destroy`, authenticating to AWS via GitHub OIDC.

## Project layout

```
src/                 Express app (app.js), DynamoDB layer (db.js), entrypoint (server.js)
public/              Static front-end (form + styles)
test/                Jest + supertest unit tests (DynamoDB is mocked)
scripts/             ec2-setup.sh — manual instance provisioning
terraform/           Main IaC (EC2, DynamoDB, IAM, security group); S3 backend
terraform/bootstrap/ One-time setup: S3 state bucket, lock table, GitHub OIDC role
.github/workflows/   ci-cd.yml (app) and terraform.yml (infra)
```

## Local development

```bash
npm ci
npm test          # run the unit tests
npm run dev       # start with auto-reload on http://localhost:3000
```

The app reads configuration from environment variables — see
[.env.example](.env.example). For local runs against real AWS, set credentials;
on EC2 the instance role supplies them automatically.

## Deploying the infrastructure (Terraform)

State lives in S3, and the GitHub Actions infra workflow assumes an IAM role via
OIDC. Both of those must exist first, so there is a one-time bootstrap step.

### 1. Bootstrap (run once, locally)

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars   # edit: unique bucket name + your repo
terraform init
terraform apply
```

Note the three outputs (`state_bucket_name`, `lock_table_name`,
`github_actions_role_arn`).

### 2. Wire up the main config

- In [terraform/versions.tf](terraform/versions.tf), set the backend `bucket`
  and `dynamodb_table` to the bootstrap outputs.
- In the GitHub repo settings, add **Actions variables**:
  - `AWS_ROLE_ARN` = the `github_actions_role_arn` output
  - `AWS_REGION` = e.g. `eu-west-2`
- Create a GitHub **environment** named `infrastructure` (the workflow and the
  role trust policy both reference it).

### 3. Provision

Locally:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # set key_pair_name
terraform init
terraform apply
```

Or via the **Terraform (Infrastructure)** workflow → Run workflow → `apply`.

`terraform output app_url` / `public_ip` gives the running app's address; use the
public IP as the `EC2_HOST` secret below.

### Teardown

`terraform destroy` (locally) or the infra workflow → `destroy`. This satisfies
the "provision and destroy infrastructure" success criterion.

## App deployment (CI/CD)

Pushes to `main` that pass the tests are deployed to the EC2 instance over SSH.
Add these **Actions secrets** in the GitHub repo:

| Secret | Value |
|---|---|
| `EC2_HOST` | Public IP / DNS of the instance (Terraform `public_ip` output) |
| `EC2_USER` | `ec2-user` |
| `EC2_SSH_PRIVATE_KEY` | Private key matching the instance's key pair |

The deploy job uploads the app, runs `npm ci --omit=dev`, restarts the `wbp3`
systemd service, and smoke-tests `/health`.

## Manual EC2 setup (before Terraform)

If you create the instance by hand first, mirror the Terraform provisioning by
running [scripts/ec2-setup.sh](scripts/ec2-setup.sh) on the instance:

```bash
sudo AWS_REGION=eu-west-2 DYNAMODB_TABLE=wbp3-submissions APP_PORT=3000 bash ec2-setup.sh
```

The instance needs an IAM role granting `dynamodb:PutItem` on the table, a
security group allowing the app port (3000) and SSH (port 22), and a key pair
whose private key you store as `EC2_SSH_PRIVATE_KEY`. Port 22 is left open
because the CD pipeline deploys over SSH from GitHub runners (changing IPs); the
key pair is the protection.
