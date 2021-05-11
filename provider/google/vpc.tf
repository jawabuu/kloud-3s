resource "google_compute_subnetwork" "kube-vpc" {
  provider      = google-beta
  project       = var.project
  name          = "kube-vpc-${time_static.id.unix}"
  ip_cidr_range = var.vpc_cidr
  region        = var.region
  network       = google_compute_network.kube-hosts.self_link
}

resource "google_compute_network" "kube-hosts" {
  provider                = google-beta
  project                 = var.project
  name                    = "kube-hosts-${time_static.id.unix}"
  auto_create_subnetworks = false
}
