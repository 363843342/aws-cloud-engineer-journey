# Week 8 — Infrastructure as Code with Terraform

## Overview
This project reproduces the VPC architecture originally provisioned manually in Week 5, using **Terraform** and the official AWS VPC module (`terraform-aws-modules/vpc/aws`). 

The goal is to move from imperative cloud configuration to a declarative Infrastructure as Code (IaC) workflow, ensuring reproducibility, drift tracking, and automated lifecycle management.

---

## Terraform Lifecycle Commands

### 1. `terraform init`
* **Purpose:** Initializes the working directory containing Terraform configuration files.
* **What it does:** Downloads and installs the necessary plugins, including the AWS provider and external child modules (such as the VPC module specified in `main.tf`). It also sets up backend configurations required to store and track state.

### 2. `terraform plan`
* **Purpose:** Serves as a dry run and safety pre-check before any infrastructure is modified.
* **What it does:** Compares the local configuration files against the current infrastructure state and computes the delta. It outputs an execution plan highlighting which resources will be **to add (`+`)**, **to change (`~`)**, or **to destroy (`-`)**.
* **Best Practice:** Always read the plan output line-by-line before running `apply` to avoid unintended modifications or resource recreation.

### 3. `terraform apply`
* **Purpose:** Executes the proposed changes outlined in the execution plan.
* **What it does:** Calls the underlying AWS APIs to provision, update, or configure real cloud resources (VPC, subnets, route tables, Internet Gateway, and NAT Gateway). Once approved (by typing `yes`), it records the resulting resource IDs and metadata into the state file.
Apply complete! Resources: 19 added, 0 changed, 0 destroyed.


### 4. `terraform destroy`
* **Purpose:** Safely tears down and deletes all resources managed by the current Terraform configuration.
* **What it does:** References the state file to find all created dependencies in reverse order, requests confirmation, and cleanly deletes them from AWS (preventing lingering compute, IP, or NAT Gateway charges).
Destroy complete! Resources: 19 destroyed.

---

## Why Terraform State Matters

### The Single Source of Truth
Terraform relies on a state file (`terraform.tfstate`) as its internal mapping between declared configuration blocks and real-world AWS resources. Without state:
* Terraform cannot know which physical AWS VPC ID belongs to the module declared in `main.tf`.
* Terraform would have to query the entire cloud provider API on every run to guess what belongs to your project.
* Terraform cannot track resource metadata, dependencies, or plan deterministic destroy operations.

### Understanding and Managing Drift
**State drift** occurs when physical cloud resources are changed or deleted outside of Terraform (e.g., modifying rules or deleting a subnet directly via the AWS Management Console). 

* If cloud reality diverges from `terraform.tfstate`, `terraform plan` may fail with conflicts or attempt to destroy and recreate functioning infrastructure.
* **Rule of thumb:** Once a resource is brought under Terraform control, the AWS Console becomes **read-only** in practice. All future modifications must be made in code and applied through Terraform.
* If drift occurs, tools like `terraform import` (to capture untracked existing resources) or `terraform state rm` (to drop deleted resources from state) are required to reconcile the gap.

### Security Note
The `terraform.tfstate` file can contain sensitive values in plain text (e.g., initial passwords, tokens, private network details). 

**Never commit state files or local plugin directories to source control:**
```gitignore
.terraform/
terraform.tfstate
terraform.tfstate.backup
*.tfvars
```