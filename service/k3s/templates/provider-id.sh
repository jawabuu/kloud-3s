#!/bin/sh
# Compile a list of cloud-provider-id's to be used by k3s


%{~if provider == "hcloud" ~}
echo "hcloud://$(curl -s http://169.254.169.254/hetzner/v1/metadata/instance-id)"
%{~endif~}

%{~if provider == "azure" ~}
echo "azure://$(curl -s -H Metadata:true http://169.254.169.254/metadata/instance/compute/resourceId?api-version=2021-05-01\&format=text)"
%{~endif~}

%{~if provider == "digitalocean" ~}
echo "digitalocean://$(curl -s http://169.254.169.254/metadata/v1/id)"
%{~endif~}

%{~if provider == "aws" ~}
echo "aws:///$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)/$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
%{~endif~}

%{~if provider == "oracle" ~}
echo "$(curl -s -H 'Authorization: Bearer Oracle' -L http://169.254.169.254/opc/v2/instance/id)"
%{~endif~}

%{~if provider == "upcloud" ~}
echo "upcloud://$(curl -s http://169.254.169.254/metadata/v1/instance-id)"
%{~endif~}

%{~if provider == "linode" ~}
echo "linode://$(hostname -s)"
%{~endif~}

%{~if provider == "vultr" ~}
echo "k3s://$(hostname -s)"
%{~endif~}

%{~if provider == "scaleway" ~}
echo "k3s://$(hostname -s)"
%{~endif~}

%{~if provider == "ovh" ~}
echo "k3s://$(hostname -s)"
%{~endif~}

%{~if provider == "alicloud" ~}
echo "k3s://$(hostname -s)"
%{~endif~}

%{~if provider == "google" ~}
echo "k3s://$(hostname -s)"
%{~endif~}

%{~if provider == "huaweicloud" ~}
echo "k3s://$(hostname -s)"
%{~endif~}

%{~if provider == "" ~}
echo "k3s://$(hostname -s)"
%{~endif~}

