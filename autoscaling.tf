resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-"
  description   = "Launch template using the tested JNIT golden AMI"
  image_id      = data.aws_ami.golden.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_runtime.name
  }

  vpc_security_group_ids = [
    aws_security_group.web.id
  ]

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  credit_specification {
    cpu_credits = "standard"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = 8
      volume_type           = "gp3"
    }
  }

  user_data = base64encode(join("\n", [
    "#!/bin/bash",
    "set -euxo pipefail",
    "/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json",
    "systemctl restart nginx",
    ""
  ]))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "${var.project_name}-web"
      Role        = "web-server"
      GoldenAMI   = data.aws_ami.golden.id
      Environment = var.environment
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name        = "${var.project_name}-web-volume"
      Environment = var.environment
    }
  }

  update_default_version = true

  tags = {
    Name = "${var.project_name}-launch-template"
  }
}

resource "aws_autoscaling_group" "web" {
  name                      = "${var.project_name}-asg"
  min_size                  = var.minimum_capacity
  desired_capacity          = var.desired_capacity
  max_size                  = var.maximum_capacity
  vpc_zone_identifier       = values(aws_subnet.private)[*].id
  target_group_arns         = [aws_lb_target_group.web.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_instance_warmup   = 180
  wait_for_capacity_timeout = "15m"

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  termination_policies = [
    "OldestLaunchTemplate",
    "Default"
  ]

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingCapacity",
    "GroupPendingInstances",
    "GroupStandbyCapacity",
    "GroupStandbyInstances",
    "GroupTerminatingCapacity",
    "GroupTerminatingInstances",
    "GroupTotalCapacity",
    "GroupTotalInstances"
  ]

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 180
    }

    triggers = ["tag"]
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-web"
    propagate_at_launch = true
  }

  tag {
    key                 = "Application"
    value               = "JNIT-HA-Web-Platform"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.ec2_cloudwatch,
    aws_iam_role_policy_attachment.ec2_ssm,
    aws_cloudwatch_log_group.nginx_access,
    aws_cloudwatch_log_group.nginx_error,
    aws_route.private_outbound
  ]
}

resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.project_name}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value     = 50
    disable_scale_in = false
  }
}