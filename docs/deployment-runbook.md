# Deployment runbook

This runbook documents the phased workflow used for the lab. It is intentionally explicit because the runtime configuration selects a tested Image Builder AMI that must exist before the application tier can be planned.

## 1. Authenticate safely

Use short-lived AWS credentials and pin the intended account and region in every new PowerShell terminal:

```powershell
aws login --profile cicd-lab

$env:AWS_PROFILE = "cicd-lab"
$env:AWS_DEFAULT_PROFILE = "cicd-lab"
$env:AWS_REGION = "eu-west-1"
$env:AWS_DEFAULT_REGION = "eu-west-1"
$env:TF_VAR_expected_account_id = "<AWS_ACCOUNT_ID>"

aws sts get-caller-identity
aws configure list
```

Do not proceed until the identity output shows the intended account. Both AWS providers also use `allowed_account_ids` as a Terraform-side guardrail.

## 2. Initialise and validate

```powershell
terraform fmt -recursive
terraform init
terraform validate
```

Commit `.terraform.lock.hcl`; never commit state, plans, credentials or generated archives.

## 3. Publish the website artifact

Bootstrap the private artifact bucket and versioned website object:

```powershell
terraform plan `
  -target=aws_s3_bucket.artifacts `
  -target=aws_s3_bucket_public_access_block.artifacts `
  -target=aws_s3_bucket_server_side_encryption_configuration.artifacts `
  -target=aws_s3_bucket_versioning.artifacts `
  -target=aws_s3_object.website `
  -out=artifact.tfplan

terraform apply artifact.tfplan
```

Verify the archive:

```powershell
$artifactBucket = terraform output -raw artifact_bucket_name
$artifactKey = terraform output -raw website_artifact_key

aws s3api head-object `
  --bucket $artifactBucket `
  --key $artifactKey `
  --query "{Size:ContentLength,Encryption:ServerSideEncryption,ContentType:ContentType,VersionId:VersionId}" `
  --output table
```

## 4. Build the golden AMI

Apply the Image Builder IAM, network, component and pipeline resources in controlled stages. Review every saved plan before applying it.

Start the manual build:

```powershell
$pipelineArn = terraform output -raw image_builder_pipeline_arn

$imageBuildArn = aws imagebuilder start-image-pipeline-execution `
  --image-pipeline-arn $pipelineArn `
  --query "imageBuildVersionArn" `
  --output text

aws imagebuilder get-image `
  --image-build-version-arn $imageBuildArn `
  --query "image.{Name:name,Version:version,State:state.status,Reason:state.reason}" `
  --output table
```

Wait for `AVAILABLE`. If the state is `FAILED`, use the S3 AWSTOE logs configured under `image-builder-logs/` rather than rebuilding blindly.

Confirm the published AMI:

```powershell
aws ec2 describe-images `
  --owners self `
  --filters "Name=tag:Name,Values=jnit-ha-web-platform-golden-ami" "Name=state,Values=available" `
  --query "Images[].{AMI:ImageId,Created:CreationDate,Name:Name}" `
  --output table
```

## 5. Deploy the runtime platform

Once the AMI exists, create a complete fresh plan:

```powershell
terraform plan -out=runtime.tfplan
terraform show -no-color runtime.tfplan | Select-String -Pattern "Plan:"
terraform apply runtime.tfplan
```

The runtime deployment creates the restricted ALB, launch template, ASG, operational identity, CloudWatch resources, alarms and certificate request.

## 6. Validate the certificate and deploy CloudFront

The certificate for CloudFront must be requested in `us-east-1`. Add the ACM-provided validation CNAME at the authoritative DNS provider, wait for `ISSUED`, and verify the exact SAN:

```powershell
$certificateArn = terraform output -raw cloudfront_certificate_arn

aws acm describe-certificate `
  --certificate-arn $certificateArn `
  --region us-east-1 `
  --query "Certificate.{Status:Status,Domain:DomainName,SANs:SubjectAlternativeNames}" `
  --output json
```

The custom alias and the viewer certificate must be configured together. A CloudFront default certificate cannot validate a custom domain.

Create and apply a fresh plan after certificate issuance. Then wait for deployment:

```powershell
$distributionId = terraform output -raw cloudfront_distribution_id
aws cloudfront wait distribution-deployed --id $distributionId
terraform output -raw cloudfront_domain_name
```

Create the traffic CNAME at the DNS provider so `aws.jnit.co.za` points to the generated CloudFront domain.

## 7. Verify and test resilience

Follow [verification.md](verification.md), capture evidence, and deliberately terminate one ASG instance using:

```powershell
aws autoscaling terminate-instance-in-auto-scaling-group `
  --instance-id <PROJECT_INSTANCE_ID> `
  --no-should-decrement-desired-capacity
```

Confirm that desired capacity stays at two, a replacement instance launches, Systems Manager reports it online and both ALB targets return to healthy.

## 8. Destroy the lab

Follow [cleanup.md](cleanup.md) on the same day to stop NAT Gateway, ALB, EC2, EBS, IPv4 and CloudWatch charges.
