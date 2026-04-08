locals {
  mcd_agent_service_name    = "REMOTE_AGENT"
  mcd_agent_deployment_type = "TERRAFORM"

  cluster_name           = var.cluster.name != null ? var.cluster.name : "mcd-agent-${random_id.mcd_agent_id.hex}"
  effective_cluster_name = var.cluster.create ? google_container_cluster.mcd_agent[0].name : var.cluster.existing_cluster_name
  namespace              = var.agent.namespace
  service_account_name   = "mcd-agent-service-account"

  mcd_agent_store_name        = "mcd-agent-store-${random_id.mcd_agent_id.hex}"
  mcd_agent_store_data_prefix = "mcd/"
  effective_bucket_name       = var.storage.create_bucket ? google_storage_bucket.mcd_agent_store[0].name : var.storage.existing_bucket_name

  cluster_endpoint       = "https://${var.cluster.create ? google_container_cluster.mcd_agent[0].endpoint : data.google_container_cluster.existing[0].endpoint}"
  cluster_ca_certificate = base64decode(var.cluster.create ? google_container_cluster.mcd_agent[0].master_auth[0].cluster_ca_certificate : data.google_container_cluster.existing[0].master_auth[0].cluster_ca_certificate)
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "google_client_config" "default" {}

data "google_container_cluster" "existing" {
  count    = var.cluster.create ? 0 : 1
  name     = var.cluster.existing_cluster_name
  location = var.location
  project  = var.project_id
}

# -----------------------------------------------------------------------------
# Random ID
# -----------------------------------------------------------------------------

resource "random_id" "mcd_agent_id" {
  byte_length = 4
}

# -----------------------------------------------------------------------------
# API Enablement
# -----------------------------------------------------------------------------

resource "google_project_service" "container_api" {
  service            = "container.googleapis.com"
  project            = var.project_id
  disable_on_destroy = false
}

resource "google_project_service" "secretmanager_api" {
  service            = "secretmanager.googleapis.com"
  project            = var.project_id
  disable_on_destroy = false
}

# -----------------------------------------------------------------------------
# VPC Network (conditional)
# -----------------------------------------------------------------------------

resource "google_compute_network" "mcd_agent_network" {
  count                   = var.networking.create_network ? 1 : 0
  name                    = "mcd-agent-network-${random_id.mcd_agent_id.hex}"
  auto_create_subnetworks = false
  project                 = var.project_id
}

resource "google_compute_subnetwork" "mcd_agent_subnetwork" {
  count         = var.networking.create_network ? 1 : 0
  name          = "mcd-agent-subnet-${random_id.mcd_agent_id.hex}"
  ip_cidr_range = var.networking.subnet_ip_cidr_range
  region        = var.location
  network       = google_compute_network.mcd_agent_network[0].id
  project       = var.project_id
}

# -----------------------------------------------------------------------------
# GKE Cluster (conditional)
# -----------------------------------------------------------------------------

resource "google_container_cluster" "mcd_agent" {
  count    = var.cluster.create ? 1 : 0
  name     = local.cluster_name
  location = var.location
  project  = var.project_id

  enable_autopilot = var.cluster.enable_autopilot ? true : null

  # Standard mode: remove default node pool and manage separately
  remove_default_node_pool = var.cluster.enable_autopilot ? null : true
  initial_node_count       = var.cluster.enable_autopilot ? null : 1

  network    = var.networking.create_network ? google_compute_network.mcd_agent_network[0].id : var.networking.existing_network_id
  subnetwork = var.networking.create_network ? google_compute_subnetwork.mcd_agent_subnetwork[0].id : var.networking.existing_subnetwork_id

  release_channel {
    channel = var.cluster.release_channel
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  deletion_protection = false

  depends_on = [google_project_service.container_api]
}

resource "google_container_node_pool" "mcd_agent_nodes" {
  count      = var.cluster.create && !var.cluster.enable_autopilot ? 1 : 0
  name       = "mcd-agent-node-pool"
  location   = var.location
  cluster    = google_container_cluster.mcd_agent[0].name
  node_count = var.cluster.node_count
  project    = var.project_id

  node_config {
    machine_type = var.cluster.machine_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

# -----------------------------------------------------------------------------
# GCS Storage (conditional)
# -----------------------------------------------------------------------------

resource "google_storage_bucket" "mcd_agent_store" {
  count                       = var.storage.create_bucket ? 1 : 0
  name                        = local.mcd_agent_store_name
  location                    = var.location
  project                     = var.project_id
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  lifecycle_rule {
    condition {
      age            = 90
      matches_prefix = [local.mcd_agent_store_data_prefix]
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age            = 2
      matches_prefix = ["${local.mcd_agent_store_data_prefix}tmp"]
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age            = 1
      matches_prefix = ["${local.mcd_agent_store_data_prefix}responses"]
    }
    action {
      type = "Delete"
    }
  }
}

# -----------------------------------------------------------------------------
# Service Account + IAM
# -----------------------------------------------------------------------------

resource "google_service_account" "mcd_agent_sa" {
  account_id   = "mcd-agent-sa-${random_id.mcd_agent_id.hex}"
  display_name = "MCD Agent Service Account"
  project      = var.project_id
}

resource "google_storage_bucket_iam_member" "mcd_agent_storage_admin" {
  count  = var.storage.create_bucket ? 1 : 0
  bucket = google_storage_bucket.mcd_agent_store[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.mcd_agent_sa.email}"
}

resource "google_storage_bucket_iam_member" "mcd_agent_bucket_viewer" {
  count  = var.storage.create_bucket ? 1 : 0
  bucket = google_storage_bucket.mcd_agent_store[0].name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.mcd_agent_sa.email}"
}

resource "google_project_iam_member" "mcd_agent_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.mcd_agent_sa.email}"
}

resource "google_service_account_iam_member" "mcd_agent_workload_identity" {
  service_account_id = google_service_account.mcd_agent_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.agent.namespace}/${local.service_account_name}]"
}

# -----------------------------------------------------------------------------
# Secret Manager (conditional)
# -----------------------------------------------------------------------------

resource "google_secret_manager_secret" "mcd_agent_token" {
  count     = var.token_secret.create ? 1 : 0
  secret_id = var.token_secret.name
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager_api]
}

resource "google_secret_manager_secret_version" "mcd_agent_token_version" {
  count  = var.token_secret.create ? 1 : 0
  secret = google_secret_manager_secret.mcd_agent_token[0].id
  secret_data = jsonencode({
    "mcd_id"    = coalesce(var.token_credentials.mcd_id, "")
    "mcd_token" = coalesce(var.token_credentials.mcd_token, "")
  })
}

# -----------------------------------------------------------------------------
# Helm - External Secrets Operator (conditional)
# -----------------------------------------------------------------------------

resource "helm_release" "external_secrets" {
  count            = var.helm.install_external_secrets_operator ? 1 : 0
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true

  depends_on = [google_container_cluster.mcd_agent]
}

# -----------------------------------------------------------------------------
# Helm - Agent (conditional)
# -----------------------------------------------------------------------------

resource "kubernetes_namespace_v1" "mcd_agent" {
  count = var.helm.deploy_agent ? 1 : 0

  metadata {
    name = local.namespace

    labels = {
      "app.kubernetes.io/managed-by" = "Helm"
    }

    annotations = {
      "meta.helm.sh/release-name"      = "mcd-agent"
      "meta.helm.sh/release-namespace" = local.namespace
    }
  }

  depends_on = [google_container_cluster.mcd_agent]
}

resource "helm_release" "mcd_agent" {
  count            = var.helm.deploy_agent ? 1 : 0
  name             = "mcd-agent"
  repository       = var.helm.chart_repository
  chart            = var.helm.chart_name
  version          = var.helm.chart_version
  namespace        = local.namespace
  create_namespace = false

  values = [local.helm_values_yaml]

  depends_on = [
    google_container_cluster.mcd_agent,
    helm_release.external_secrets,
    kubernetes_namespace_v1.mcd_agent
  ]
}

locals {
  base_helm_values = {
    namespace    = local.namespace
    replicaCount = var.agent.replica_count

    image = {
      repository = split(":", var.agent.image)[0]
      pullPolicy = "IfNotPresent"
      tag        = length(split(":", var.agent.image)) > 1 ? split(":", var.agent.image)[1] : "latest-generic"
    }

    container = {
      backendServiceUrl = var.backend_service_url
      storageBucketName = local.effective_bucket_name
      storageType       = "GCS"
    }

    serviceAccount = {
      annotations = {
        "iam.gke.io/gcp-service-account" = google_service_account.mcd_agent_sa.email
      }
    }

    secretStore = {
      provider = {
        gcpsm = {
          projectID = var.project_id
          auth = {
            workloadIdentity = {
              serviceAccountRef = {
                name = local.service_account_name
              }
            }
          }
        }
      }
    }

    tokenSecret = {
      remoteRef = {
        key = var.token_secret.name
      }
    }

    integrationsSecrets = {
      data = [for s in var.integration_secrets : {
        secretKey = s.secret_key
        remoteRef = {
          key = s.remote_ref_key
        }
      }]
    }

    logsCollector    = { enabled = var.helm.enabled_logs_collector }
    metricsCollector = { enabled = var.helm.enabled_metrics_collector }
  }

  helm_values = merge(local.base_helm_values, var.custom_values, {
    logsCollector = merge(
      try(var.custom_values.logsCollector, {}),
      { enabled = var.helm.enabled_logs_collector }
    )
    metricsCollector = merge(
      try(var.custom_values.metricsCollector, {}),
      { enabled = var.helm.enabled_metrics_collector }
    )
  })

  helm_values_yaml = yamlencode(local.helm_values)
}
