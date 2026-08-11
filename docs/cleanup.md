# Cleanup procedure

This environment contains resources that accrue hourly or usage-based charges. Destroy it promptly after testing.

## 1. Remove temporary traffic DNS

Remove the `aws` CNAME that points to CloudFront. Keep the ACM validation CNAME until Terraform has destroyed the certificate and distribution.

## 2. Record the generated AMI and snapshot

The Image Builder pipeline is managed by Terraform, but the AMI produced by a manually started build is not.

```powershell
$goldenAmi = terraform output -raw golden_ami_id

$snapshotId = aws ec2 describe-images `
  --image-ids $goldenAmi `
  --query "Images[0].BlockDeviceMappings[?Ebs!=null].Ebs.SnapshotId | [0]" `
  --output text
```

Retain both identifiers for post-destroy cleanup.

## 3. Destroy Terraform resources

```powershell
aws sts get-caller-identity
terraform plan -destroy -out=destroy.tfplan
terraform show -no-color destroy.tfplan | Select-String -Pattern "Plan:"
terraform apply destroy.tfplan
terraform state list
```

The completed lab destroyed 65 Terraform-managed resources. An empty `terraform state list` confirms Terraform no longer manages infrastructure.

## 4. Delete build products

Only after the Terraform-managed Image Builder pipeline is gone:

```powershell
aws ec2 deregister-image `
  --image-id $goldenAmi `
  --delete-associated-snapshots

aws imagebuilder delete-image `
  --image-build-version-arn <IMAGE_BUILD_VERSION_ARN>
```

Image Builder's `delete-image` operation does not delete the produced EC2 AMI, which is why both cleanup steps are required.

## 5. Verify and remove validation DNS

Verify that the project AMI, snapshot, ASG, load balancer, NAT Gateway, CloudFront distribution, certificate, S3 artifact bucket, log groups and alarms no longer exist. Then remove the ACM validation CNAME from the DNS provider.

Never use broad filters or wildcard deletion for cleanup. Resolve and delete only the exact project identifiers captured during deployment.
