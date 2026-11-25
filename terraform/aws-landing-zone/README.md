# AWS Landing Zone (secure baseline)

Terraform module that builds a secure-by-default baseline: an encrypted,
private, logged S3 bucket and a locked-down VPC with traffic logging.
It runs against LocalStack, so it costs nothing and needs no AWS account.

## Controls and the risk each one reduces

| Control | Resource | Risk reduced |
|---|---|---|
| Customer-managed KMS key with rotation and explicit key policy | `aws_kms_key.data` | Uncontrolled key access, stale keys |
| Public access block on every bucket | `aws_s3_bucket_public_access_block` | Accidental data exposure |
| Encryption at rest with our key | `aws_s3_bucket_server_side_encryption_configuration` | Data readable if storage is compromised |
| Versioning | `aws_s3_bucket_versioning` | Accidental or malicious overwrite and delete |
| Access logging to a separate log bucket | `aws_s3_bucket_logging` | No audit trail of who accessed data |
| Lifecycle rules | `aws_s3_bucket_lifecycle_configuration` | Unbounded data retention and cost |
| Empty default security group | `aws_default_security_group` | Implicit trust between resources |
| VPC flow logs to an encrypted log group | `aws_flow_log` | No network visibility for investigations |
| Least-privilege role for flow log delivery | `aws_iam_role_policy.flow_logs` | Over-permissioned service role |

## How to run it

1. Start LocalStack from the repo root: `docker compose up -d`
2. `cd terraform/aws-landing-zone`
3. `terraform init`, then `terraform apply`
4. Scan: `python -m checkov.main -d terraform/aws-landing-zone --compact --quiet`

## Accepted risks (documented in code)

- Cross-region replication (CKV_AWS_144): doubles cost, not needed for a demo.
- S3 event notifications (CKV2_AWS_62): not needed for demo buckets.

## Known limitations

- LocalStack reports the flow log delivery status as `FAILED` ("Access error")
  because the emulator does not really deliver flow logs. The configuration
  itself (role, least-privilege policy, KMS statement for CloudWatch Logs) is
  written for real AWS, but this has not been verified there.
- The log bucket does not log its own access; logging its own access would
  require a third bucket, and the risk is low for a demo.