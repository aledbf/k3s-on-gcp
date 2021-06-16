resource "google_compute_subnetwork" "k3s-servers" {
  name          = "k3s-servers"
  network       = var.network
  region        = var.region
  ip_cidr_range = var.cidr_range

  private_ip_google_access = true
}

resource "google_compute_address" "k3s-api-server-internal" {
  name         = "k3s-api-server-internal"
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
  region       = var.region
  subnetwork   = google_compute_subnetwork.k3s-servers.id
}

resource "google_compute_address" "k3s-api-server-external" {
  name   = "k3s-api-server-external"
  region = var.region
}

resource "google_compute_firewall" "k3s-api-authorized-networks" {
  name          = "k3s-api-authorized-networks"
  network       = var.network
  source_ranges = split(",", var.authorized_networks)
  allow {
    protocol = "tcp"
    ports    = [6443]
  }
  target_tags = ["k3s-server"]
  direction   = "INGRESS"
}
