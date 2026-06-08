# WBP3 — CI/CD Pipeline & Infrastructure as Code

A small Express web application that collects personal details and stores them
in AWS DynamoDB, used to demonstrate an automated CI/CD pipeline (GitHub
Actions) and Infrastructure as Code (Terraform on AWS).

This repository covers the project deliverables: the web application, the
pipeline that builds/tests/deploys it, and the IaC that provisions its
infrastructure.

## Architecture

```
  push to main ─► test ─► terraform plan ─► terraform apply ─► deploy ─► EC2 (systemd)
                                            (approval gate)      (SSH)        │
                                                                             ▼
                                                                         DynamoDB
```

- **App** — Express, Node 20. Writes submissions to DynamoDB via an IAM
  instance role (no credentials in code).
- **CI/CD** — [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml): a single
  ordered pipeline. Tests run on every push/PR; on a push to `main` it then runs
  `terraform plan`, `terraform apply` (behind an approval gate), and finally
  deploys the app over SSH to the instance the apply just ensured exists. The
  deploy reads the EC2 host from the Terraform output, so there's no host to
  configure by hand.
- **IaC** — [terraform/](terraform/): DynamoDB table, EC2 instance, Elastic IP,
  IAM instance role, security group. Remote state in S3. AWS auth via GitHub OIDC.
- **Manual infra workflow** — [.github/workflows/terraform.yml](.github/workflows/terraform.yml):
  on-demand `plan` / `apply` / `destroy` (apply and destroy behind the same gate).

## Project layout

```
src/                 Express app (app.js), DynamoDB layer (db.js), entrypoint (server.js)
public/              Static front-end (form + styles)
test/                Jest + supertest unit tests (DynamoDB is mocked)
scripts/             ec2-setup.sh — manual instance provisioning
terraform/           Main IaC (EC2, DynamoDB, IAM, security group); S3 backend
terraform/bootstrap/ One-time setup: S3 state bucket, lock table, GitHub OIDC role
.github/workflows/   ci-cd.yml (test+infra+deploy pipeline), terraform.yml (manual infra)
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
- Add **repository** Actions variables (Settings → Secrets and variables →
  Actions → Variables):
  - `AWS_ROLE_ARN` = the `github_actions_role_arn` output
  - `AWS_REGION` = e.g. `eu-west-2`
- Create two GitHub **environments**:
  - `infrastructure` — used by `plan` and the deploy job; no protection rules.
  - `infrastructure-apply` — used by `apply` and `destroy`; add yourself as a
    **required reviewer** to create the approval gate. (Required reviewers only
    work on public repos, or private repos on a paid plan.)
- Add the **secret** `EC2_SSH_PRIVATE_KEY` (the private key matching your EC2 key
  pair) to the `infrastructure` environment.

### 3. Provision

Locally:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # set key_pair_name
terraform init
terraform apply
```

After the first apply, the CI/CD pipeline takes over: every push to `main`
re-runs plan/apply (gated) and redeploys. You can also apply manually via the
**Terraform (manual)** workflow → Run workflow → `apply`.

### Teardown

Run the **Terraform (manual)** workflow → `destroy` (behind the approval gate),
or `terraform destroy` locally. This satisfies the "provision and destroy
infrastructure" success criterion.

## App deployment (CI/CD)

On a push to `main`, the pipeline tests, applies the infrastructure, then deploys
the app over SSH: it uploads the code, runs `npm ci --omit=dev`, restarts the
`wbp3` systemd service, and smoke-tests `/health`.

The deploy job needs no host configuration — it reads the instance's Elastic IP
straight from the `terraform apply` output, and the login user is always
`ec2-user`. The only secret it needs is **`EC2_SSH_PRIVATE_KEY`** (set on the
`infrastructure` environment), the private key matching your EC2 key pair.

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
