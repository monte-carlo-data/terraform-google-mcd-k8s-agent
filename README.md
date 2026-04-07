# Monte Carlo Agent - GCP GKE Module

This module deploys the [Monte Carlo](https://www.montecarlodata.com/) containerized agent on GCP using GKE (Google Kubernetes Engine).

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.3
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) with [authentication](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/getting_started)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) for cluster access
- A Monte Carlo account with agent credentials (mcd_id and mcd_token)

## Usage

### Full deployment (new cluster)

```hcl
module "mcd_agent" {
  source = "monte-carlo-data/mcd-agent-k8s/google"

  project_id          = "my-gcp-project"
  location            = "us-central1"
  backend_service_url = "https://your-instance.getmontecarlo.com"
}
```

### Existing VPC

```hcl
module "mcd_agent" {
  source = "monte-carlo-data/mcd-agent-k8s/google"

  project_id          = "my-gcp-project"
  location            = "us-central1"
  backend_service_url = "https://your-instance.getmontecarlo.com"

  networking = {
    create_network         = false
    existing_network_id    = "projects/my-gcp-project/global/networks/my-vpc"
    existing_subnetwork_id = "projects/my-gcp-project/regions/us-central1/subnetworks/my-subnet"
  }
}
```

### Existing cluster

```hcl
module "mcd_agent" {
  source = "monte-carlo-data/mcd-agent-k8s/google"

  project_id          = "my-gcp-project"
  location            = "us-central1"
  backend_service_url = "https://your-instance.getmontecarlo.com"

  cluster = {
    create                = false
    existing_cluster_name = "my-cluster"
  }

  networking = {
    create_network = false
  }
}
```

### Infrastructure only (manual Helm deployment)

```hcl
module "mcd_agent" {
  source = "monte-carlo-data/mcd-agent-k8s/google"

  project_id          = "my-gcp-project"
  location            = "us-central1"
  backend_service_url = "https://your-instance.getmontecarlo.com"

  helm = {
    deploy_agent = false
  }
}

output "helm_values" {
  value     = module.mcd_agent.helm_values
  sensitive = true
}
```

## After Deployment

1. Update the agent token in GCP Secret Manager:
   ```bash
   echo -n '{"mcd_id":"YOUR_MCD_ID","mcd_token":"YOUR_MCD_TOKEN"}' | \
     gcloud secrets versions add mcd-agent-token --data-file=-
   ```

2. Configure kubectl access:
   ```bash
   gcloud container clusters get-credentials <cluster_name> --region <location> --project <project_id>
   ```

## Outputs

| Name | Description |
|------|-------------|
| cluster_name | GKE cluster name |
| cluster_endpoint | Endpoint for GKE control plane |
| project_id | GCP project ID |
| location | GCP region |
| storage_bucket_name | GCS bucket name for agent storage |
| service_account_email | Service account email for the agent |
| namespace | Kubernetes namespace for the agent |
| helm_values | Helm values for manual deployment (sensitive) |

## Releases and Development

This module follows [standard module structure](https://www.terraform.io/docs/modules/index.html). Run `terraform fmt` before committing.

CircleCI runs `make sanity-check` on every PR.

To release a new version, create and push a new tag: `git tag v0.0.1 && git push origin v0.0.1`

## License

See [LICENSE](LICENSE).

## Security

See [SECURITY](SECURITY.md).
