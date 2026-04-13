# Existing VPC Example

Deploys a new GKE cluster and Monte Carlo agent into an existing VPC network.

You must provide the full self-link or ID of the existing network and subnetwork. The subnetwork should have outbound internet access for pulling container images and reaching the Monte Carlo backend.

## Usage

```bash
terraform init
terraform apply -var="project_id=my-gcp-project" -var="location=us-central1"
```
