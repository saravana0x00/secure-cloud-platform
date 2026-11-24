# Encryption key we control (not the default AWS-managed one)
resource "aws_kms_key" "data" {
  description             = "Key for encrypting data at rest"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

# The bucket
resource "aws_s3_bucket" "secure_data" {
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