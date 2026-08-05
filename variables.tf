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
  description = "MCD agent token credentials. Required when token_secret.create is true and oauth_credentials is not set."
  type = object({
    mcd_id    = optional(string, null)
    mcd_token = optional(string, null)
  })
  sensitive = true
  default   = {}
}

variable "oauth_credentials" {
  description = "OAuth client credentials for agent authentication. If provided, the module creates a secret in GCP Secret Manager and configures the Helm chart to use OAuth instead of key/token. Only one of oauth_credentials or token_credentials should be set."
  type = object({
    client_id     = string
    client_secret = string
  })
  default   = null
  sensitive = true
}

variable "oauth_secret" {
  description = "OAuth secret store configuration. Only needed to customize the secret name or to reference a pre-existing secret (create = false). When null and oauth_credentials is set, the module creates a secret with the default name."
  type = object({
    create = optional(bool, true)
    name   = optional(string, "mcd-agent-oauth")
  })
  default = null
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

    # Concurrent operations a single replica processes. Chart default is 18.
    ops_runner_thread_count = optional(number, null)

    # Pod resource requests/limits, e.g.
    #   { requests = { cpu = "500m", memory = "512Mi" }, limits = { cpu = "2" } }
    # At least requests must be set when autoscaling is enabled.
    resources = optional(map(map(string)), null)

    # Horizontal Pod Autoscaler. Supplying this object enables autoscaling
    # unless enabled is explicitly set to false. When enabled, replica_count
    # is ignored and the HPA manages the replica count.
    autoscaling = optional(object({
      enabled                              = optional(bool, true)
      min_replicas                         = optional(number, 2)
      max_replicas                         = optional(number, 5)
      target_cpu_utilization_percentage    = optional(number, 70)
      target_memory_utilization_percentage = optional(number, null)
    }), null)
  })
  default = {}

  validation {
    condition     = var.agent.resources == null || length(setsubtract(keys(var.agent.resources), ["requests", "limits"])) == 0
    error_message = "agent.resources may only contain \"requests\" and \"limits\" keys."
  }

  validation {
    condition     = try(var.agent.autoscaling.enabled, false) == false || try(var.agent.resources["requests"], null) != null
    error_message = "agent.resources.requests must be set when agent.autoscaling is enabled — the HorizontalPodAutoscaler uses requests as its utilization baseline."
  }

  validation {
    condition     = try(var.agent.autoscaling.min_replicas <= var.agent.autoscaling.max_replicas, true)
    error_message = "agent.autoscaling.min_replicas must be less than or equal to agent.autoscaling.max_replicas."
  }
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
    log_shipping              = optional(string, "in-process")
    enabled_metrics_collector = optional(bool, true)
  })

  validation {
    condition     = contains(["in-process", "fluentd", "none"], var.helm.log_shipping)
    error_message = "helm.log_shipping must be one of: in-process, fluentd, none."
  }
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
