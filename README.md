# Monte Carlo Agent - GCP GKE Module

This module deploys the [Monte Carlo](https://www.montecarlodata.com/) containerized agent on GCP using GKE (Google Kubernetes Engine).

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.9
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) with [authentication](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/getting_started)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) for cluster access
- A Monte Carlo account with agent credentials (key/token pair **or** OAuth client credentials)

## Provider Configuration

This module does **not** configure the `google` provider — the calling root module must do so. At minimum, set the target project and region:

```hcl
provider "google" {
  project = "my-gcp-project"
  region  = "us-central1"
}
```

The module applies Monte Carlo agent labels to resources directly via the `custom_default_tags` variable — there is no need to set `default_labels` on the provider.

> **Note:** The `helm` and `kubernetes` providers are configured inside the module because they depend on the cluster's kubeconfig, which is only available after the cluster is created. See the [Terraform provider documentation](https://developer.hashicorp.com/terraform/language/modules/develop/providers) for details on this pattern.

## Usage

> **Finding your `backend_service_url`:** Navigate to the [Account Information](https://getmontecarlo.com/account-info#agent-service) page in Monte Carlo. Under the **Agent Service** section, copy the **Public endpoint**. Use this value for the `backend_service_url` variable in the examples below.

> **Finding the latest `chart_version`:** Check the available versions on [Docker Hub](https://hub.docker.com/r/montecarlodata/generic-agent-helm/tags).

All examples below require the `google` provider configured as described in [Provider Configuration](#provider-configuration).

For more complete configurations, see the [`examples`](./examples/) directory.

### Authentication

The module supports two authentication methods. Use **one** of them -- not both.

#### Option A -- Key/token authentication

**Provide credentials (recommended):** The module creates and populates the secret in GCP Secret Manager.

```hcl
token_credentials = {
  mcd_id    = var.mcd_id
  mcd_token = var.mcd_token
}
```

To keep credentials out of your Terraform files, copy `credentials.tfvars.example` to `credentials.tfvars`, fill in your values, and apply with:

```bash
terraform apply -var-file=credentials.tfvars
```

**Use a pre-existing secret:** Point the module to an existing secret in GCP Secret Manager by name. The secret value must be a JSON object with the following format:

```json
{
  "mcd_id": "YOUR_MCD_ID",
  "mcd_token": "YOUR_MCD_TOKEN"
}
```

```hcl
token_secret = {
  create = false
  name   = "my-existing-secret-name"
}
```

#### Option B -- OAuth 2.0 Client Credentials

**Provide OAuth credentials:** The module creates a secret in GCP Secret Manager and configures the Helm chart to use OAuth (`oauthSecret`) instead of key/token (`tokenSecret`).

```hcl
oauth_credentials = {
  client_id     = var.oauth_client_id
  client_secret = var.oauth_client_secret
}
```

**Use a pre-existing OAuth secret:** Point the module to an existing secret in GCP Secret Manager. The secret value must be a JSON object with the following format:

```json
{
  "client_id": "YOUR_CLIENT_ID",
  "client_secret": "YOUR_CLIENT_SECRET"
}
```

```hcl
oauth_secret = {
  create = false
  name   = "my-existing-oauth-secret"
}
```

### Full deployment (new cluster)

```hcl
provider "google" {
  project = "my-gcp-project"
  region  = "us-central1"
}

module "mcd_agent" {
  source = "monte-carlo-data/mcd-agent-k8s/google"

  project_id          = "my-gcp-project"
  location            = "us-central1"
  backend_service_url = "<backend_service_url>"

  token_credentials = {
    mcd_id    = var.mcd_id
    mcd_token = var.mcd_token
  }

  helm = {
    chart_version = "0.0.2"
  }
}
```

### Existing VPC

```hcl
module "mcd_agent" {
  source = "monte-carlo-data/mcd-agent-k8s/google"

  project_id          = "my-gcp-project"
  location            = "us-central1"
  backend_service_url = "<backend_service_url>"

  helm = {
    chart_version = "0.0.2"
  }

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
  backend_service_url = "<backend_service_url>"

  helm = {
    chart_version = "0.0.2"
  }

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
  backend_service_url = "<backend_service_url>"

  helm = {
    chart_version = "0.0.2"
    deploy_agent  = false
  }
}

output "helm_values" {
  value     = module.mcd_agent.helm_values
  sensitive = true
}
```

### Scaling

Set replicas, per-replica concurrency, and pod resources through the `agent` variable:

```hcl
  agent = {
    replica_count           = 3
    ops_runner_thread_count = 36
    resources = {
      requests = { cpu = "500m", memory = "512Mi" }
      limits   = { cpu = "2", memory = "2Gi" }
    }
  }
```

`ops_runner_thread_count` is the number of operations a single replica processes concurrently (chart default is 18). Raising it is often cheaper than adding replicas, but set `resources` alongside it so the pods have headroom.

To autoscale instead of holding a fixed replica count, supply `agent.autoscaling`:

```hcl
  agent = {
    ops_runner_thread_count = 36
    resources               = { requests = { cpu = "500m", memory = "512Mi" } }

    autoscaling = {
      min_replicas                      = 2
      max_replicas                      = 6
      target_cpu_utilization_percentage = 70
    }
  }
```

Supplying the object enables autoscaling; set `enabled = false` to keep the settings without activating the HorizontalPodAutoscaler. When enabled, `replica_count` is ignored, `resources.requests` is required (the HPA uses requests as its utilization baseline, and the module validates this), and `metrics-server` must be installed in the cluster — standard on EKS, AKS, and GKE.

Set these through the `agent` variable rather than `custom_values`. `custom_values` replaces whole sections rather than merging into them, so a `container` map passed there drops the module's backend URL and data store settings.

## After Deployment

Configure kubectl access:
```bash
gcloud container clusters get-credentials <cluster_name> --region <location> --project <project_id>
```

## Troubleshooting

### Checking agent logs

Verify the agent pod is running and check its logs:

```bash
kubectl get pods -n mcd-agent
kubectl logs -n mcd-agent -l app=mcd-agent --tail=30
```

### Reachability test

Run the reachability test to confirm the agent can communicate with the Monte Carlo platform:

```bash
kubectl exec -n mcd-agent deploy/mcd-agent-deployment -- \
  curl -s -X POST localhost:8080/api/v1/test/reachability
```

### Rotating the agent token

1. Update the secret in GCP Secret Manager:
   ```bash
   echo -n '{"mcd_id":"NEW_MCD_ID","mcd_token":"NEW_MCD_TOKEN"}' | \
     gcloud secrets versions add mcd-agent-token --data-file=-
   ```

2. Force sync the Kubernetes secret from ESO:
   ```bash
   kubectl annotate externalsecret -n mcd-agent --all \
     force-sync=$(date +%s) --overwrite
   ```

3. Restart the agent services:
   ```bash
   kubectl rollout restart deployment mcd-agent-deployment -n mcd-agent
   kubectl rollout restart daemonset logs-collector metrics-collector -n mcd-agent
   ```

### Rotating OAuth credentials

1. Update the secret in GCP Secret Manager:
   ```bash
   echo -n '{"client_id":"NEW_CLIENT_ID","client_secret":"NEW_CLIENT_SECRET"}' | \
     gcloud secrets versions add mcd-agent-oauth --data-file=-
   ```

2. Force sync the Kubernetes secret from ESO:
   ```bash
   kubectl annotate externalsecret -n mcd-agent --all \
     force-sync=$(date +%s) --overwrite
   ```

3. Restart the agent services:
   ```bash
   kubectl rollout restart deployment mcd-agent-deployment -n mcd-agent
   kubectl rollout restart daemonset logs-collector metrics-collector -n mcd-agent
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
| oauth_secret_name | Name of the Secret Manager secret for OAuth credentials |

## Releases and Development

This module follows [standard module structure](https://www.terraform.io/docs/modules/index.html). Run `terraform fmt` before committing.

CircleCI runs `make sanity-check` on every PR.

To release a new version, create and push a new tag: `git tag v0.0.1 && git push origin v0.0.1`

## License

See [LICENSE](LICENSE).

## Security

See [SECURITY](SECURITY.md).
