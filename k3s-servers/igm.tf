resource "random_string" "token" {
  length  = 32
  special = false
}

data "template_file" "k3s-server-startup-script" {
  template = file("${path.module}/templates/server.sh")
  vars = {
    token                  = random_string.token.result
    internal_lb_ip_address = google_compute_address.k3s-api-server-internal.address
    external_lb_ip_address = google_compute_address.k3s-api-server-external.address
    db_host                = var.db_host
    db_name                = var.db_name
    db_user                = var.db_user
    db_password            = var.db_password
  }
}

resource "google_compute_instance_template" "k3s-server" {
  name_prefix  = "k3s-server-"
  machine_type = var.machine_type

  tags = ["k3s", "k3s-server"]

  metadata_startup_script = data.template_file.k3s-server-startup-script.rendered

  can_ip_forward = true

  metadata = {
    block-project-ssh-keys = "FALSE"
    enable-oslogin         = "FALSE"
    ssh-keys               = "aledbf_gmail_com:${file("/home/aledbf/.ssh/id_rsa.pub")}"
  }

  disk {
    source_image = "gitpod-k3s-20210607-01"
    auto_delete  = true
    boot         = true
    disk_size_gb = 50
  }

  network_interface {
    network    = var.network
    subnetwork = google_compute_subnetwork.k3s-servers.id
    access_config {
    }
  }

  shielded_instance_config {
    enable_secure_boot = false
  }

  # gcloud projects add-iam-policy-binding gitpod-k3s --member='serviceAccount:k3s-server@gitpod-k3s.iam.gserviceaccount.com' --role='roles/editor'
  service_account {
    email = var.service_account
    scopes = [
      # Compute Engine (rw)
      "https://www.googleapis.com/auth/compute",
      # Storage (ro)
      "https://www.googleapis.com/auth/devstorage.read_only",
      # Service Control (enabled)
      "https://www.googleapis.com/auth/servicecontrol",
      # Service Management (rw)
      "https://www.googleapis.com/auth/service.management",
      # Stackdriver Logging (wo)
      "https://www.googleapis.com/auth/logging.write",
      # Stackdriver Monitoring (full)
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "k3s-servers" {
  name = "k3s-servers"

  base_instance_name = "k3s-server"
  region             = var.region

  version {
    instance_template = google_compute_instance_template.k3s-server.id
  }

  target_size = var.target_size

  named_port {
    name = "k3s"
    port = 6443
  }

  depends_on = [google_compute_router_nat.nat]
}
