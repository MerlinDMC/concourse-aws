variable "basic_auth_username" {
  default = "concourse"
}

variable "basic_auth_password" {
  default = "ci"
}

data "template_file" "cloud_config_web" {
  template = "${file("${path.module}/cloud-config-web.tpl.yml")}"

  vars {
    postgresql_host = "${aws_db_instance.concourse.address}"
    postgresql_port = "${aws_db_instance.concourse.port}"
    postgresql_name = "${aws_db_instance.concourse.name}"

    postgresql_username = "concourse"
    postgresql_password = "concourse-ci"

    concourse_download_url = "${var.concourse_download_url}"
    concourse_bind_ip      = "0.0.0.0"
    concourse_bind_port    = "8080"
    concourse_external_url = "http://${var.concourse_external_url}"

    basic_auth_username = "${var.basic_auth_username}"
    basic_auth_password = "${var.basic_auth_password}"

    session_signing_key_content        = "${base64encode(tls_private_key.session_signing_key.private_key_pem)}"
    tsa_host_key_content               = "${base64encode(tls_private_key.host_key.private_key_pem)}"
    tsa_authorized_worker_keys_content = "${base64encode(tls_private_key.worker_key.public_key_openssh)}"
  }
}

resource "tls_private_key" "session_signing_key" {
  algorithm = "RSA"
  rsa_bits  = "1024"
}

resource "tls_private_key" "host_key" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_private_key" "worker_key" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "aws_security_group" "atc" {
  name        = "allow ATC access"
  description = "allow inbound access to ATC and ATS"

  vpc_id = "${aws_vpc.default.id}"

  ingress {
    from_port   = 2222
    to_port     = 2222
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "Allow ATC access"
  }
}

resource "aws_instance" "atc" {
  ami                         = "${data.aws_ami.coreos_stable.image_id}"
  instance_type               = "t2.micro"
  associate_public_ip_address = true

  subnet_id = "${aws_subnet.concourse_a.id}"

  key_name = "${var.aws_key_name}"

  vpc_security_group_ids = ["${aws_security_group.ssh.id}", "${aws_security_group.outbound.id}", "${aws_security_group.atc.id}", "${aws_security_group.internal.id}"]

  user_data = "${data.template_file.cloud_config_web.rendered}"

  tags {
    Name = "ATC"
  }
}

output "atc_dns_name" {
  value = "${aws_elb.atc.dns_name}"
}

resource "aws_elb" "atc" {
  name = "${var.vpc_name}-atc-elb"

  listener {
    instance_port     = 8080
    instance_protocol = "TCP"
    lb_port           = 80
    lb_protocol       = "TCP"
  }

  listener {
    instance_port     = 2222
    instance_protocol = "TCP"
    lb_port           = 2222
    lb_protocol       = "TCP"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:8080"
    interval            = 30
  }

  instances       = ["${aws_instance.atc.id}"]
  subnets         = ["${aws_subnet.concourse_a.id}", "${aws_subnet.concourse_b.id}"]
  security_groups = ["${aws_security_group.atc.id}", "${aws_security_group.internal.id}"]
}

resource "aws_elb" "tsa" {
  name = "${var.vpc_name}-tsa-elb"

  listener {
    instance_port     = 2222
    instance_protocol = "TCP"
    lb_port           = 2222
    lb_protocol       = "TCP"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:2222"
    interval            = 30
  }

  internal        = true
  instances       = ["${aws_instance.atc.id}"]
  subnets         = ["${aws_subnet.concourse_a.id}", "${aws_subnet.concourse_b.id}"]
  security_groups = ["${aws_security_group.internal.id}"]
}
