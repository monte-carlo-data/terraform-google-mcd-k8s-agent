output "cluster_name" {
  description = "GKE cluster name."
  value       = local.effective_cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for GKE control plane."
  value       = var.cluster.create ? "https://${google_container_cluster.mcd_agent[0].endpoint}" : null
}

output "project_id" {
  description = "GCP project ID."
  value       = var.project_id
}

output "location" {
  description = "GCP region."
  value       = var.location
}

output "storage_bucket_name" {
  description = "GCS bucket name for agent storage."
  value       = local.effective_bucket_name
}

output "service_account_email" {
  description = "Service account email for the agent."
  value       = google_service_account.mcd_agent_sa.email
}

output "namespace" {
  description = "Kubernetes namespace for the agent."
  value       = local.namespace
}

output "helm_values" {
  description = "Helm values used for agent deployment. Use these for manual Helm deployment when deploy_agent is false."
  value       = local.helm_values_yaml
  sensitive   = false
}

output "oauth_secret_name" {
  description = "Name of the Secret Manager secret for OAuth credentials."
  value       = local.use_oauth ? var.oauth_secret.name : null
}
