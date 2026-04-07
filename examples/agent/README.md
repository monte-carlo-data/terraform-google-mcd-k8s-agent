# MCD On-Prem Agent - Full Deployment Example

This example deploys the Monte Carlo on-prem agent on a new GKE cluster with all infrastructure provisioned automatically.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.3
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) configured with appropriate credentials
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

## Usage

```bash
terraform init
terraform apply
```

## After Deployment

1. Update the agent token secret in GCP Secret Manager with your Monte Carlo credentials:
   ```bash
   echo -n '{"mcd_id":"YOUR_MCD_ID","mcd_token":"YOUR_MCD_TOKEN"}' | \
     gcloud secrets versions add mcd-agent-token --data-file=-
   ```

2. Configure kubectl:
   ```bash
   gcloud container clusters get-credentials $(terraform output -raw cluster_name) --region us-central1 --project my-gcp-project
   ```
