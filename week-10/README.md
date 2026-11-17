# Week 10 — CI/CD & DevOps Practices: GitHub Actions to AWS via OIDC

## Overview
This directory contains the GitHub Actions CI/CD workflow (`deploy.yml`) that automates building the `propertylite` Docker image, pushing it to Amazon ECR (`property-api`), and deploying updates to Amazon ECS (`training-cluster` / `property-api-service`) in `us-west-1` using OpenID Connect (OIDC) authentication.

---

## Why OIDC is Safer Than Storing AWS Access Keys as GitHub Secrets

Using OpenID Connect (OIDC) to authenticate GitHub Actions with AWS is significantly more secure than storing static AWS IAM user credentials (`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`) in GitHub Secrets for several key reasons:

### 1. Eliminates Long-Lived Static Credentials
* **Static Keys Risk:** Traditional IAM access keys remain valid indefinitely until manually rotated or revoked. If leaked through a misconfigured workflow, compromised third-party action, or accidental log exposure, an attacker gains persistent access to your AWS environment.
* **OIDC Advantage:** No long-lived AWS credentials are ever stored in GitHub. AWS trusts GitHub's OIDC identity provider (`https://token.actions.githubusercontent.com`) directly to verify workflow identity.

### 2. Short-Lived, Auto-Expiring Tokens
* When the workflow runs, GitHub generates a cryptographically signed JSON Web Token (JWT) with the `sts.amazonaws.com` audience.
* AWS STS (`sts:AssumeRoleWithWebIdentity`) exchanges this JWT for temporary credentials tied to `github-actions-deploy-role`. These credentials automatically expire shortly after the job finishes (typically within 1 hour), drastically shrinking the window of opportunity if a token were ever intercepted.

### 3. Granular Access Control via IAM Trust Policies
* Static keys grant the same permissions regardless of where or how they are used.
* With OIDC, the IAM role's trust policy enforces strict conditions on the JWT claims. For this project, `github-actions-deploy-role` is scoped exclusively to `repo:363843342/aws-cloud-engineer-journey:*`, ensuring that no other GitHub user, external repository, or unauthorized workflow can assume the deployment role.

### 4. Zero Secret Rotation & Reduced Operational Overhead
* Security best practices require rotating static access keys every 90 days, which creates ongoing maintenance overhead and risks deployment outages if secrets go out of sync.
* OIDC removes static secrets entirely from the CI/CD pipeline, eliminating manual key rotation while improving auditability in AWS CloudTrail (where every session is logged with the exact repository and workflow run context).