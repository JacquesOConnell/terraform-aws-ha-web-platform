resource "aws_cloudwatch_log_group" "nginx_access" {
  name              = "/jnit/ha-web-platform/nginx/access"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-nginx-access"
  }
}

resource "aws_cloudwatch_log_group" "nginx_error" {
  name              = "/jnit/ha-web-platform/nginx/error"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-nginx-error"
  }
}