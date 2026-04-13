# NOTE: The google provider is intentionally NOT configured here. Reusable modules
# should not include provider configuration blocks — the calling root module must
# configure the google provider. See README for required provider settings.
#
# The helm and kubernetes providers ARE configured here because they depend on the
# cluster's kubeconfig, which is only available after the cluster is created. This
# is a known compromise for modules that deploy Kubernetes resources.
# See: https://developer.hashicorp.com/terraform/language/modules/develop/providers

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
