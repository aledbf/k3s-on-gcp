resource "google_compute_subnetwork" "k3s-agents" {
  name          = "k3s-agents-${var.name}"
  network       = var.network
  region        = var.region
  ip_cidr_range = var.cidr_range

  private_ip_google_access = true
}
