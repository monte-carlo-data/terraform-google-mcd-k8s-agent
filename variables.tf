# --- GCP Project Configuration ---

variable "project_id" {
  description = "The GCP project ID to deploy the agent into."
  type        = string
}

variable "location" {
  description = "The GCP location (region) to deploy the agent into."
  type        = string
}

variable "backend_service_url" {
  description = "The Monte Carlo backend service URL. Obtain this from Monte Carlo support."
  type        = string
}

# --- Cluster Configuration ---

variable "cluster" {
  description = "GKE cluster configuration."
  type = object({
    create                = optional(bool, true)
    name                  = optional(string, null)
    existing_cluster_name = optional(string, null)
    release_channel       = optional(string, "REGULAR")
    enable_autopilot      = optional(bool, false)
    deletion_protection   = optional(bool, true)
    machine_type          = optional(string, "e2-standard-2")
    node_count            = optional(number, 2)
  })
  default = {}

  validation {
    condition     = contains(["UNSPECIFIED", "RAPID", "REGULAR", "STABLE"], var.cluster.release_channel)
    error_message = "Invalid release channel. Must be one of: UNSPECIFIED, RAPID, REGULAR, STABLE."
  }
}

# --- Networking ---

variable "networking" {
  description = "VPC network configuration."
  type = object({
    create_network         = optional(bool, true)
    subnet_ip_cidr_range   = optional(string, "10.0.0.0/24")
    existing_network_id    = optional(string, null)
    existing_subnetwork_id = optional(string, null)
  })
  default = {}
}

# --- Storage ---

variable "storage" {
  description = "GCS storage configuration."
  type = object({
    create_bucket        = optional(bool, true)
    existing_bucket_name = optional(string, null)
  })
  default = {}
}

# --- Secrets ---

variable "token_secret" {
  description = "Token secret store configuration."
  type = object({
    create = optional(bool, true)
    name   = optional(string, "mcd-agent-token")
  })
  default = {}
}

variable "token_credentials" {
  description = "MCD agent token credentials. Required when token_secret.create is true."
  type = object({
    mcd_id    = optional(string, null)
    mcd_token = optional(string, null)
  })
  sensitive = true
  default   = {}

  validation {
    condition     = !var.token_secret.create || (var.token_credentials.mcd_id != null && var.token_credentials.mcd_token != null)
    error_message = "Both mcd_id and mcd_token are required in token_credentials when token_secret.create is true."
  }
}

variable "integration_secrets" {
  description = "Integration secrets to sync from the cloud secret store."
  type = list(object({
    secret_key     = string
    remote_ref_key = string
  }))
  default = []
}

# --- Agent Configuration ---

variable "agent" {
  description = "Agent container configuration."
  type = object({
    namespace     = optional(string, "mcd-agent")
    image         = optional(string, "montecarlodata/agent:latest-generic")
    pull_policy   = optional(string, "Always")
    replica_count = optional(number, 2)
  })
  default = {}
}

# --- Helm Deployment ---

variable "helm" {
  description = "Helm deployment configuration."
  type = object({
    deploy_agent                      = optional(bool, true)
    install_external_secrets_operator = optional(bool, true)
    chart_repository                  = optional(string, "oci://registry-1.docker.io/montecarlodata")
    chart_name                        = optional(string, "generic-agent-helm")
    # Find the latest version at https://hub.docker.com/r/montecarlodata/generic-agent-helm/tags
    chart_version             = string
    enabled_logs_collector    = optional(bool, true)
    enabled_metrics_collector = optional(bool, true)
  })
}

variable "custom_values" {
  description = "Custom Helm values to merge with module-generated values. Accepts any map matching the chart's values.yaml schema."
  type        = any
  default     = {}
}

variable "custom_default_tags" {
  description = "Custom labels to apply to all resources. Merged with default Monte Carlo agent labels."
  type        = map(string)
  default     = {}
}
