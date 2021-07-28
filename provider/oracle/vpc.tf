resource "oci_core_vcn" "main" {
  dns_label      = "main"
  cidr_block     = var.vpc_cidr
  compartment_id = var.tenancy_ocid
  display_name   = "main"
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "main"
}

resource "oci_core_nat_gateway" "private_subnet" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "private_subnet"

}

resource "oci_core_subnet" "kube-hosts" {
  cidr_block        = var.vpc_cidr
  compartment_id    = var.tenancy_ocid
  vcn_id            = oci_core_vcn.main.id
  display_name      = "kube-hosts-${time_static.id.unix}"
  dns_label         = "public"
  security_list_ids = [oci_core_security_list.allow-all.id]
}

resource "oci_core_default_route_table" "main" {
  manage_default_resource_id = oci_core_vcn.main.default_route_table_id

  route_rules {
    network_entity_id = oci_core_internet_gateway.main.id

    description = "internet gateway"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_route_table" "private_subnet" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.main.id

  display_name = "private_subnet_natgw"

  route_rules {
    network_entity_id = oci_core_nat_gateway.private_subnet.id

    description = "k8s private to public internal"
    destination = "0.0.0.0/0"

  }

}

resource "oci_core_default_security_list" "default" {
  manage_default_resource_id = oci_core_vcn.main.default_security_list_id

  # TODO: check protocol is "all"
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "6"
  }

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "17"
  }

  ingress_security_rules {
    protocol    = "17"
    source      = var.vpc_cidr
    description = "Kubernetes VXLAN"

    udp_options {
      max = 8472
      min = 8472
    }
  }

  ingress_security_rules {
    protocol    = "17"
    source      = "0.0.0.0/0"
    description = "NAT Port"

    udp_options {
      max = 4500
      min = 4500
    }
  }

  ingress_security_rules {
    protocol    = "17"
    source      = "0.0.0.0/0"
    description = "IKE Port"

    udp_options {
      max = 500
      min = 500
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "Metrics Port"

    tcp_options {
      max = 8080
      min = 8080
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "SSH"

    tcp_options {
      max = 22
      min = 22
    }
  }


  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "Kubernetes API"

    tcp_options {
      max = 6443
      min = 6443
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "HTTPS"

    tcp_options {
      max = 443
      min = 443
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "HTTP"

    tcp_options {
      max = 80
      min = 80
    }
  }


  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "Kubernetes Metrics"

    tcp_options {
      max = 10250
      min = 10250
    }
  }
}


resource "oci_core_security_list" "allow-all" {
  vcn_id         = oci_core_vcn.main.id
  compartment_id = var.tenancy_ocid

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "SSH"

    tcp_options {
      max = 22
      min = 22
    }
  }

  ingress_security_rules {
    protocol = "all"
    source   = "0.0.0.0/0"
  }

}

/*
resource "oci_core_subnet" "private_subnet" {
  cidr_block     = var.private_subnet
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "private_subnet"
  route_table_id = oci_core_route_table.private_subnet.id
  dns_label      = "private"
}
*/

/*
resource "oci_core_default_security_list" "default" {
  manage_default_resource_id = oci_core_vcn.main.default_security_list_id
  # vcn_id         = oci_core_vcn.main.id

  # TODO: check protocol is "all"
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    protocol    = "1"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
  }

  ingress_security_rules {
    protocol    = "17"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
  }

}
*/

/*
resource "oci_bastion_bastion" "main" {
  bastion_type     = "STANDARD"
  compartment_id   = var.compartment_id
  target_subnet_id = oci_core_subnet.private_subnet.id

  name                         = var.project_name
  client_cidr_block_allow_list = var.whitelist_subnets
}

resource "random_password" "sqlpassword" {
  length = 24
}

resource "oci_core_instance" "externaldb" {
  availability_domain = element(local.server_ad_names, (var.freetier_server_ad_list - 1))
  compartment_id      = var.compartment_id
  shape               = "VM.Standard.E2.1.Micro"

  display_name = "externaldb"

  create_vnic_details {
    subnet_id        = oci_core_subnet.private_subnet.id
    display_name     = "primary"
    assign_public_ip = false
    hostname_label   = "externaldb"
  }

  source_details {
    source_id   = data.oci_core_images.amd64.images.0.id
    source_type = "image"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = data.template_cloudinit_config.externaldb.rendered
  }

  lifecycle {
    ignore_changes = [
      source_details
    ]
  }
}
*/