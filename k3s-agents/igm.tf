data "template_file" "k3s-agent-startup-script" {
  template = file("${path.module}/templates/agent.sh")
  vars = {
    token          = var.token
    server_address = var.server_address
  }
}

resource "google_compute_instance_template" "k3s-agent" {
  name_prefix  = "k3s-agent-${var.name}-"
  machine_type = var.machine_type

  tags = ["k3s", "k3s-agent"]

  metadata_startup_script = data.template_file.k3s-agent-startup-script.rendered

  can_ip_forward = true

  metadata = {
    block-project-ssh-keys     = "FALSE"
    enable-oslogin             = "FALSE"
    enable-guest-attributes    = "TRUE"
    google-compute-enable-pcid = "TRUE"
    disable-legacy-endpoints   = "TRUE"
    ssh-keys                   = "aledbf_gmail_com:${file("/home/aledbf/.ssh/id_rsa.pub")}"
    cluster-name               = "kubernetes"

  }

  disk {
    source_image = "gitpod-k3s-20210607-01"
    auto_delete  = true
    boot         = true
    disk_size_gb = 50
  }

  network_interface {
    network    = var.network
    subnetwork = google_compute_subnetwork.k3s-agents.self_link
    access_config {
    }
  }

  shielded_instance_config {
    enable_secure_boot = false
  }

  service_account {
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
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "k3s-agents" {
  name = "k3s-agents-${var.name}"

  base_instance_name = "k3s-agent-${var.name}"
  region             = var.region

  version {
    instance_template = google_compute_instance_template.k3s-agent.id
  }

  target_size = var.target_size

  update_policy {
    type                         = "PROACTIVE"
    instance_redistribution_type = "PROACTIVE"
    minimal_action               = "REPLACE"
    max_surge_fixed              = 3
  }
}
