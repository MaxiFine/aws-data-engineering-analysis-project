# GitHub Actions CI/CD Setup

This guide explains how to set up automated deployment using GitHub Actions.

## Architecture

The workflow automatically deploys your Sudoku app when you push changes to the `main` branch:
- Detects changes to HTML/CSS/JS or Terraform files
- Runs Terraform to update infrastructure
- Invalidates CloudFront cache for immediate updates
- Uses OIDC for secure AWS authentication (no long-lived credentials)

## Setup Instructions

### 1. Create IAM OIDC Identity Provider

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 2. Create IAM Role for GitHub Actions

Create `github-actions-role.json`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:*"
        }
      }
    }
  ]
}
```

Create the role:
```bash
aws iam create-role \
  --role-name GitHubActionsDeployRole \
  --assume-role-policy-document file://github-actions-role.json
```

### 3. Attach IAM Policies

```bash
aws iam attach-role-policy \
  --role-name GitHubActionsDeployRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

aws iam attach-role-policy \
  --role-name GitHubActionsDeployRole \
  --policy-arn arn:aws:iam::aws:policy/CloudFrontFullAccess
```

Or create a custom policy with minimal permissions:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "cloudfront:*",
        "acm:ListCertificates",
        "acm:DescribeCertificate"
      ],
      "Resource": "*"
    }
  ]
}
```

### 4. Configure Terraform Backend (Optional but Recommended)

Add to `terraform/main.tf`:
```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "sudoku-app/terraform.tfstate"
    region = "us-east-1"
  }
}
```

Create the S3 bucket:
```bash
aws s3 mb s3://your-terraform-state-bucket
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled
```

### 5. Add GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add the following secret:
- **Name:** `AWS_ROLE_ARN`
- **Value:** `arn:aws:iam::YOUR_ACCOUNT_ID:role/GitHubActionsDeployRole`

### 6. Commit terraform.tfvars

Since the workflow needs your configuration, commit `terraform.tfvars`:
```bash
git add terraform/terraform.tfvars
git commit -m "Add Terraform configuration"
git push
```

**Security Note:** Never commit sensitive values. Use GitHub secrets for sensitive data.

## Usage

### Automatic Deployment
Push changes to `main` branch:
```bash
git add .
git commit -m "Update Sudoku app"
git push origin main
```

### Manual Deployment
Go to Actions tab → Deploy Sudoku App → Run workflow

## Workflow Triggers

The workflow runs when:
- Changes pushed to `main` branch affecting:
  - `index.html`
  - `style.css`
  - `index.js`
  - `terraform/**`
- Manually triggered via GitHub UI

## Monitoring

View deployment status:
1. Go to your repository on GitHub
2. Click "Actions" tab
3. Select the latest workflow run
4. View logs and deployment URL

## Troubleshooting

**Authentication failed:**
- Verify IAM role ARN in GitHub secrets
- Check trust policy allows your repository
- Ensure OIDC provider is created

**Terraform state locked:**
- Use S3 backend with DynamoDB for state locking
- Or wait for previous deployment to complete

**CloudFront invalidation failed:**
- Ensure IAM role has CloudFront permissions
- Check distribution ID output exists

## Advanced: Multi-Environment Setup

For staging/production environments, create separate workflows:

`.github/workflows/deploy-staging.yml`:
```yaml
on:
  push:
    branches:
      - develop

env:
  TF_VAR_bucket_name: sudoku-app-staging
```

`.github/workflows/deploy-production.yml`:
```yaml
on:
  push:
    branches:
      - main

env:
  TF_VAR_bucket_name: sudoku-app-production
```
