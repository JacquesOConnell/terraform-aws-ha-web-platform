variable "aws_region" {
  description = "AWS region for the web platform"
  type        = string
  default     = "eu-west-1"
}

variable "expected_account_id" {
  description = "AWS account that Terraform is permitted to use"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "expected_account_id must contain exactly 12 digits."
  }
}

variable "project_name" {
  description = "Name used for project resources"
  type        = string
  default     = "jnit-ha-web-platform"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "development"
}

variable "domain_name" {
  description = "Temporary DNS name used by CloudFront"
  type        = string
  default     = "aws.jnit.co.za"
}

variable "instance_type" {
  description = "EC2 instance type used by the Auto Scaling Group"
  type        = string
  default     = "t3.micro"
}

variable "minimum_capacity" {
  description = "Minimum number of web servers"
  type        = number
  default     = 2
}

variable "desired_capacity" {
  description = "Normal number of web servers"
  type        = number
  default     = 2
}

variable "maximum_capacity" {
  description = "Maximum number of web servers"
  type        = number
  default     = 4
}