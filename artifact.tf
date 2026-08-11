data "archive_file" "website" {
  type        = "zip"
  source_dir  = "${path.module}/website"
  output_path = "${path.module}/website.zip"
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.project_name}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  force_destroy = true

  tags = {
    Name    = "${var.project_name}-artifacts"
    Purpose = "EC2 Image Builder website source"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "website" {
  bucket       = aws_s3_bucket.artifacts.id
  key          = "releases/website.zip"
  source       = data.archive_file.website.output_path
  source_hash  = data.archive_file.website.output_base64sha256
  content_type = "application/zip"

  depends_on = [
    aws_s3_bucket_public_access_block.artifacts,
    aws_s3_bucket_server_side_encryption_configuration.artifacts,
    aws_s3_bucket_versioning.artifacts
  ]
}