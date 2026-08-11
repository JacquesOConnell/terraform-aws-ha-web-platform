data "aws_iam_policy_document" "ec2_runtime_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ec2_runtime" {
  name               = "${var.project_name}-ec2-runtime-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_runtime_trust.json

  tags = {
    Name = "${var.project_name}-ec2-runtime-role"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch" {
  role       = aws_iam_role.ec2_runtime.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_runtime.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_runtime" {
  name = "${var.project_name}-ec2-runtime-profile"
  role = aws_iam_role.ec2_runtime.name
}