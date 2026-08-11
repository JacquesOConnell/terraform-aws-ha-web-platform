output "artifact_bucket_name" {
  description = "Private S3 bucket containing the website build artifact"
  value       = aws_s3_bucket.artifacts.id
}

output "website_artifact_key" {
  description = "S3 object used by EC2 Image Builder"
  value       = aws_s3_object.website.key
}

output "vpc_id" {
  description = "VPC used by the highly available web platform"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs used by the ALB"
  value       = values(aws_subnet.public)[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by the Auto Scaling Group"
  value       = values(aws_subnet.private)[*].id
}

output "nat_gateway_id" {
  description = "Development NAT Gateway used for private-instance outbound access"
  value       = aws_nat_gateway.main.id
}

output "image_builder_pipeline_arn" {
  description = "Golden AMI Image Builder pipeline ARN"
  value       = aws_imagebuilder_image_pipeline.golden.arn
}

output "golden_ami_id" {
  description = "Latest tested golden AMI used by the launch template"
  value       = data.aws_ami.golden.id
}


output "alb_dns_name" {
  description = "ALB origin DNS name; direct public requests are intentionally restricted"
  value       = aws_lb.web.dns_name
}

output "target_group_arn" {
  description = "Target group used by the Auto Scaling Group"
  value       = aws_lb_target_group.web.arn
}

output "autoscaling_group_name" {
  description = "Auto Scaling Group managing the private web servers"
  value       = aws_autoscaling_group.web.name
}

output "launch_template_id" {
  description = "Launch template using the tested golden AMI"
  value       = aws_launch_template.web.id
}

output "operations_sns_topic_arn" {
  description = "SNS topic used by operational CloudWatch alarms"
  value       = aws_sns_topic.operations.arn
}

output "cloudfront_certificate_arn" {
  description = "ACM certificate requested in us-east-1 for CloudFront"
  value       = aws_acm_certificate.cloudfront.arn
}

output "certificate_validation_records" {
  description = "DNS CNAME records required to validate the CloudFront certificate"

  value = [
    for validation in aws_acm_certificate.cloudfront.domain_validation_options : {
      domain = validation.domain_name
      name   = validation.resource_record_name
      type   = validation.resource_record_type
      value  = validation.resource_record_value
    }
  ]
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.website.id
}

output "cloudfront_domain_name" {
  description = "CloudFront-generated domain name"
  value       = aws_cloudfront_distribution.website.domain_name
}

output "application_url" {
  description = "Custom HTTPS application URL"
  value       = "https://${var.domain_name}"
}
