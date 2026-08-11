data "aws_iam_policy_document" "image_builder_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "image_builder" {
  name               = "${var.project_name}-image-builder-role"
  assume_role_policy = data.aws_iam_policy_document.image_builder_trust.json

  tags = {
    Name = "${var.project_name}-image-builder-role"
  }
}

resource "aws_iam_role_policy_attachment" "image_builder" {
  role       = aws_iam_role.image_builder.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/EC2InstanceProfileForImageBuilder"
}

resource "aws_iam_role_policy_attachment" "image_builder_ssm" {
  role       = aws_iam_role.image_builder.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "image_builder_artifact_access" {
  statement {
    sid    = "ReadWebsiteArtifact"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]

    resources = [
      aws_s3_object.website.arn
    ]
  }

  statement {
    sid    = "WriteImageBuilderLogs"
    effect = "Allow"

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.artifacts.arn}/image-builder-logs/*"
    ]
  }

  statement {
    sid    = "ListArtifactBucket"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]

    resources = [
      aws_s3_bucket.artifacts.arn
    ]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["releases/*"]
    }
  }
}

resource "aws_iam_role_policy" "image_builder_artifact_access" {
  name   = "${var.project_name}-artifact-access"
  role   = aws_iam_role.image_builder.id
  policy = data.aws_iam_policy_document.image_builder_artifact_access.json
}

resource "aws_iam_instance_profile" "image_builder" {
  name = "${var.project_name}-image-builder-profile"
  role = aws_iam_role.image_builder.name
}