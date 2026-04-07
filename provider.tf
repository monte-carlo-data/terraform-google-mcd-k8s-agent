provider "google" {
  project = var.project_id
  region  = var.location
  default_labels = merge(var.custom_default_tags, {
    "mcd-agent-service-name"    = lower(local.mcd_agent_service_name)
    "mcd-agent-deployment-type" = lower(local.mcd_agent_deployment_type)
  })
}

provider "helm" {
  kubernetes = {
    host                   = local.cluster_endpoint
    cluster_ca_certificate = local.cluster_ca_certificate
    token                  = data.google_client_config.default.access_token
  }
}

provider "kubernetes" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = local.cluster_ca_certificate
  token                  = data.google_client_config.default.access_token
}
