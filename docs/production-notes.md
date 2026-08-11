# Design decisions and production improvements

## Decisions used in the lab

- **Two private web subnets:** application instances have no public IP addresses and accept traffic only from the ALB.
- **Two public ALB subnets:** the load balancer remains available across two Availability Zones.
- **One NAT Gateway:** deliberately reduces the cost of a temporary development deployment.
- **Golden AMI:** application assets and operational agents are tested before instances enter service.
- **No SSH:** Systems Manager provides administration and inventory without an inbound management port.
- **Restricted origin:** CloudFront's managed origin prefix list and a secret header prevent ordinary direct ALB requests.
- **Seven-day logs:** enough for lab verification while limiting retained CloudWatch data.
- **No database:** the deployed application is static and has no genuine persistence requirement.

## Changes for a long-running production service

1. Place one NAT Gateway in each Availability Zone and give each private subnet an AZ-local route.
2. Encrypt CloudFront-to-origin traffic using an ALB certificate, or evaluate a private CloudFront VPC origin.
3. Add AWS WAF managed rules, rate controls and tested exception handling.
4. Store Terraform state in an encrypted remote backend with locking, restricted access and recovery controls.
5. Build AMIs through CI/CD, scan them, promote immutable versions between environments and add lifecycle policies.
6. Add Route 53 health-aware DNS where appropriate and automate DNS validation records.
7. Define business-driven SLOs, alarm destinations, escalation paths, dashboards and longer log retention.
8. Add access-log analysis, CloudTrail integration, Security Hub/Inspector coverage and continuous configuration checks.
9. Run controlled load, failover and recovery tests and record measurable RTO/RPO targets.
10. Use separate development, staging and production accounts with organisation-level guardrails.
