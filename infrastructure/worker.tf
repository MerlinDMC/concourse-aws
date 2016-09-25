variable "worker_count" {
  default = "1"
}

data "template_file" "cloud_config_worker" {
  template = "${file("${path.module}/cloud-config-worker.tpl.yml")}"

  vars {
    concourse_download_url = "${var.concourse_download_url}"
    concourse_tsa_host     = "${aws_elb.tsa.dns_name}"

    tsa_public_key_content         = "${base64encode(tls_private_key.host_key.public_key_openssh)}"
    tsa_worker_private_key_content = "${base64encode(tls_private_key.worker_key.private_key_pem)}"
  }
}

resource "aws_instance" "worker" {
  ami                         = "${data.aws_ami.coreos_stable.image_id}"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  count                       = "${var.worker_count}"

  subnet_id = "${aws_subnet.concourse_a.id}"

  key_name = "${var.aws_key_name}"

  vpc_security_group_ids = ["${aws_security_group.outbound.id}", "${aws_security_group.internal.id}"]

  user_data = "${data.template_file.cloud_config_worker.rendered}"

  tags {
    Name = "Worker ${count.index + 1}"
  }
}
