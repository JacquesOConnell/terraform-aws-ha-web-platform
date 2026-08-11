resource "aws_security_group" "image_builder" {
  name        = "${var.project_name}-image-builder-sg"
  description = "Outbound-only access for temporary Image Builder instances"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Download packages, retrieve artifacts and reach AWS APIs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-image-builder-sg"
  }
}

resource "aws_imagebuilder_image_recipe" "golden" {
  name         = "${var.project_name}-golden-ami"
  version      = "1.0.1"
  parent_image = "ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"

  component {
    component_arn = aws_imagebuilder_component.web_server.arn
  }

  block_device_mapping {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = 8
      volume_type           = "gp3"
    }
  }

  systems_manager_agent {
    uninstall_after_build = false
  }

  tags = {
    Name = "${var.project_name}-golden-ami-recipe"
  }
}

resource "aws_imagebuilder_infrastructure_configuration" "golden" {
  name                          = "${var.project_name}-infrastructure"
  instance_profile_name         = aws_iam_instance_profile.image_builder.name
  instance_types                = ["t3.micro"]
  subnet_id                     = aws_subnet.public["az1"].id
  security_group_ids            = [aws_security_group.image_builder.id]
  terminate_instance_on_failure = true

  instance_metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  logging {
    s3_logs {
      s3_bucket_name = aws_s3_bucket.artifacts.id
      s3_key_prefix  = "image-builder-logs"
    }
  }

  resource_tags = {
    Purpose     = "Temporary golden AMI build"
    Application = "JNIT-HA-Web-Platform"
    Environment = var.environment
    ManagedBy   = "EC2-Image-Builder"
  }

  tags = {
    Name = "${var.project_name}-image-builder-infrastructure"
  }
}

resource "aws_imagebuilder_distribution_configuration" "golden" {
  name = "${var.project_name}-distribution"

  distribution {
    region = var.aws_region

    ami_distribution_configuration {
      name        = "${var.project_name}-{{ imagebuilder:buildDate }}"
      description = "Tested JNIT Nginx and CloudWatch Agent golden AMI"

      ami_tags = {
        Name        = "${var.project_name}-golden-ami"
        BaseImage   = "Amazon-Linux-2023"
        WebServer   = "Nginx"
        Monitoring  = "CloudWatch-Agent"
        Immutable   = "true"
        Environment = var.environment
      }
    }
  }

  tags = {
    Name = "${var.project_name}-distribution"
  }
}

resource "aws_imagebuilder_image_pipeline" "golden" {
  name                             = "${var.project_name}-pipeline"
  description                      = "Build and test the JNIT golden web-server AMI"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.golden.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.golden.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.golden.arn
  enhanced_image_metadata_enabled  = true
  status                           = "ENABLED"

  image_tests_configuration {
    image_tests_enabled = true
    timeout_minutes     = 60
  }

  lifecycle {
    replace_triggered_by = [
      aws_imagebuilder_image_recipe.golden
    ]
  }

  tags = {
    Name = "${var.project_name}-golden-ami-pipeline"
  }
}