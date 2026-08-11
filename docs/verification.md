# Verification commands

## Auto Scaling and Availability Zones

```powershell
aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names jnit-ha-web-platform-asg `
  --query "AutoScalingGroups[0].{Minimum:MinSize,Desired:DesiredCapacity,Maximum:MaxSize,Instances:Instances[].{Instance:InstanceId,AZ:AvailabilityZone,Lifecycle:LifecycleState,Health:HealthStatus}}" `
  --output json
```

## ALB target health

```powershell
$targetGroupArn = terraform output -raw target_group_arn

aws elbv2 describe-target-health `
  --target-group-arn $targetGroupArn `
  --query "TargetHealthDescriptions[].{Instance:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason}" `
  --output table
```

## Systems Manager

```powershell
aws ssm describe-instance-information `
  --query "InstanceInformationList[].{Instance:InstanceId,Ping:PingStatus,Platform:PlatformName,Agent:AgentVersion}" `
  --output table
```

## CloudWatch logs and custom metrics

```powershell
aws logs describe-log-streams `
  --log-group-name "/jnit/ha-web-platform/nginx/access" `
  --query "logStreams[].{Instance:logStreamName,LastEvent:lastEventTimestamp}" `
  --output table

aws cloudwatch list-metrics `
  --namespace "JNIT/HAWebPlatform" `
  --query "Metrics[].{Metric:MetricName,Dimensions:Dimensions}" `
  --output json
```

## Alarms

```powershell
aws cloudwatch describe-alarms `
  --alarm-name-prefix "jnit-ha-web-platform-" `
  --query "MetricAlarms[].{Name:AlarmName,State:StateValue,Metric:MetricName,Namespace:Namespace,Threshold:Threshold}" `
  --output table
```

## CloudFront distribution

```powershell
$distributionId = terraform output -raw cloudfront_distribution_id

aws cloudfront get-distribution `
  --id $distributionId `
  --query "Distribution.{Status:Status,Domain:DomainName,Aliases:DistributionConfig.Aliases.Items,Certificate:DistributionConfig.ViewerCertificate.ACMCertificateArn}" `
  --output json
```

Run the request twice. The first request normally reports `Miss from cloudfront`; the next reports `Hit from cloudfront`:

```powershell
curl.exe -I https://aws.jnit.co.za
curl.exe -I https://aws.jnit.co.za
```

Expected controls include HSTS, `X-Content-Type-Options`, `X-Frame-Options`, a referrer policy, `Via` and `X-Cache`.

If the local resolver retained a negative DNS response, resolve the CloudFront domain through a public resolver and temporarily use curl's `--resolve` option while keeping the custom hostname for TLS.
