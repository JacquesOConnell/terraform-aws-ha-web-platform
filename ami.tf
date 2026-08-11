data "aws_ami" "golden" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-golden-ami"]
  }

  filter {
    name   = "tag:Immutable"
    values = ["true"]
  }

  filter {
    name   = "tag:WebServer"
    values = ["Nginx"]
  }
}