# Who is running this (used to build the key policy)
data "aws_caller_identity" "current" {}

# Encryption key we control (not the default AWS-managed one)
resource "aws_kms_key" "data" {
  description             = "Key for encrypting data at rest"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AccountAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })
}

# The bucket
resource "aws_s3_bucket" "secure_data" {
  #checkov:skip=CKV2_AWS_62:Event notifications are not needed for this demo bucket
  #checkov:skip=CKV_AWS_144:Cross-region replication doubles cost and is not needed for a demo
  bucket = "secure-data-demo-bucket"
}

# Block every form of public access
resource "aws_s3_bucket_public_access_block" "secure_data" {
  bucket                  = aws_s3_bucket.secure_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encrypt everything stored in the bucket with our key
resource "aws_s3_bucket_server_side_encryption_configuration" "secure_data" {
  bucket = aws_s3_bucket.secure_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.data.arn
    }
  }
}

# Keep old versions so accidental deletes or overwrites can be recovered
resource "aws_s3_bucket_versioning" "secure_data" {
  bucket = aws_s3_bucket.secure_data.id

  versioning_configuration {
    status = "Enabled"
  }
}
# Separate bucket that receives access logs
resource "aws_s3_bucket" "access_logs" {
  #checkov:skip=CKV2_AWS_62:Event notifications are not needed for a log bucket
  #checkov:skip=CKV_AWS_144:Replication is not needed for demo logs
  bucket = "secure-data-demo-access-logs"
}

# Block all public access on the log bucket as well
resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encrypt the logs with the same key
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.data.arn
    }
  }
}

# Send the main bucket's access logs to the log bucket
resource "aws_s3_bucket_logging" "secure_data" {
  bucket        = aws_s3_bucket.secure_data.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "secure-data/"
}

# Expire old versions of objects in the main bucket
resource "aws_s3_bucket_lifecycle_configuration" "secure_data" {
  bucket = aws_s3_bucket.secure_data.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Delete access logs after one year
resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Keep previous versions of log files so tampering can be recovered from
resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}