provider "google" {
  project = "my-gcp-project"
  region  = "us-central1"
}

variable "mcd_id" {
  description = "Monte Carlo agent ID."
  type        = string
  sensitive   = true
}

variable "mcd_token" {
  description = "Monte Carlo agent token."
  type        = string
  sensitive   = true
}

module "mcd_on_prem_agent" {
  source = "../../"

  project_id          = "my-gcp-project"
  location            = "us-central1"
  backend_service_url = "https://your-instance.getmontecarlo.com"

  token_credentials = {
    mcd_id    = var.mcd_id
    mcd_token = var.mcd_token
  }

  helm = {
    chart_version = "0.0.2"
  }
}

output "cluster_endpoint" {
  value = module.mcd_on_prem_agent.cluster_endpoint
}

output "cluster_name" {
  value = module.mcd_on_prem_agent.cluster_name
}

output "storage_bucket_name" {
  value = module.mcd_on_prem_agent.storage_bucket_name
}

output "service_account_email" {
  value = module.mcd_on_prem_agent.service_account_email
}
