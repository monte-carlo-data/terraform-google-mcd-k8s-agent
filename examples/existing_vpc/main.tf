module "mcd_on_prem_agent" {
  source = "../../"

  project_id          = "my-gcp-project"
  location            = "us-central1"
  backend_service_url = "https://your-instance.getmontecarlo.com"

  # Create a new GKE cluster in an existing VPC network
  networking = {
    create_network         = false
    existing_network_id    = "projects/my-gcp-project/global/networks/my-vpc"
    existing_subnetwork_id = "projects/my-gcp-project/regions/us-central1/subnetworks/my-subnet"
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
