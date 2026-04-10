# MCD On-Prem Agent - Existing Cluster Example

This example deploys the Monte Carlo on-prem agent on an existing GKE cluster.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.9
- An existing GKE cluster with kubectl access
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) configured with appropriate credentials

## Usage

Update `main.tf` with your existing cluster name, project ID, and region, then:

```bash
terraform init
terraform apply
```
