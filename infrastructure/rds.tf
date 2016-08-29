resource "aws_db_instance" "concourse" {
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "9.5.2"
  instance_class         = "db.t2.micro"
  storage_type           = "gp2"
  name                   = "concourse"
  username               = "concourse"
  password               = "concourse-ci"
  db_subnet_group_name   = "${aws_db_subnet_group.concourse.id}"
  vpc_security_group_ids = ["${aws_security_group.pgsql.id}"]
}

resource "aws_db_subnet_group" "concourse" {
  name        = "concourse-subnet-group"
  description = "Main concourse subnet group"
  subnet_ids  = ["${aws_subnet.concourse_a.id}", "${aws_subnet.concourse_b.id}"]
}

resource "aws_security_group" "pgsql" {
  name        = "allow pgsql access"
  description = "allow inbound access to postgresql"

  vpc_id = "${aws_vpc.default.id}"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["${aws_vpc.default.cidr_block}"]
  }

  tags {
    Name = "Allow access to pgsql on port 5432"
  }
}
