variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_key_path" {}
variable "aws_key_name" {}

variable "aws_region" { default = "eu-west-1" }

variable "vpc_network" { default = "10.29" }
variable "vpc_name" { default = "concourse-ci" }

variable "concourse_download_url" { default = "https://github.com/concourse/concourse/releases/download/v1.6.0/concourse_linux_amd64" }
variable "concourse_external_url" { default = "http://localhost" }

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}

resource "aws_vpc" "default" {
  cidr_block           = "${var.vpc_network}.0.0/16"
  enable_dns_hostnames = "true"
  tags {
    Name = "${var.vpc_name}"
  }
}

resource "aws_subnet" "concourse_a" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.vpc_network}.65.0/24"
  availability_zone = "${var.aws_region}a"
  tags {
    Name = "${var.vpc_name}-concourse-a"
  }
}

resource "aws_subnet" "concourse_b" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.vpc_network}.66.0/24"
  availability_zone = "${var.aws_region}b"
  tags {
    Name = "${var.vpc_name}-concourse-b"
  }
}

resource "aws_route_table_association" "concourse_a" {
  subnet_id      = "${aws_subnet.concourse_a.id}"
  route_table_id = "${aws_route_table.external.id}"
}

resource "aws_route_table_association" "concourse_b" {
  subnet_id      = "${aws_subnet.concourse_b.id}"
  route_table_id = "${aws_route_table.external.id}"
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

resource "aws_route_table" "external" {
  vpc_id = "${aws_vpc.default.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.default.id}"
  }
  tags {
    Name = "${var.vpc_name}-external"
  }
}

resource "aws_security_group" "internal" {
  name = "allow ALL internal traffic"
  description = "allow all internal traffic"

  vpc_id = "${aws_vpc.default.id}"

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["${aws_vpc.default.cidr_block}"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["${aws_vpc.default.cidr_block}"]
  }

  tags {
    Name = "Allow ALL internal traffic"
  }
}

resource "aws_security_group" "outbound" {
  name = "allow outbound access"
  description = "allow all outbound traffic"

  vpc_id = "${aws_vpc.default.id}"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "Allow ALL outbound traffic"
  }
}

resource "aws_security_group" "ssh" {
  name = "allow SSH access"
  description = "allow inbound access to SSHd"

  vpc_id = "${aws_vpc.default.id}"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "Allow SSH access"
  }
}
