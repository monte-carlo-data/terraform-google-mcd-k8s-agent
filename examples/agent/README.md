# MCD On-Prem Agent - Full Deployment Example

This example deploys the Monte Carlo on-prem agent on a new GKE cluster with all infrastructure provisioned automatically.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.9
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) configured with appropriate credentials
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

## Usage

1. Copy `credentials.tfvars.example` to `credentials.tfvars` and fill in your Monte Carlo credentials.

2. Apply:
   ```bash
   terraform init
   terraform apply -var-file=credentials.tfvars
   ```

## After Deployment

Configure kubectl:
```bash
gcloud container clusters get-credentials $(terraform output -raw cluster_name) --region us-central1 --project my-gcp-project
```
