"""Find S3 buckets that drifted from the secure baseline and fix the safe problems.

Dry run by default: it only reports. Use --fix to apply the automatic fixes.
Talks to LocalStack unless AWS_ENDPOINT_URL is set to something else.
"""
import argparse
import os
import sys

import boto3
from botocore.exceptions import ClientError

ENDPOINT = os.environ.get("AWS_ENDPOINT_URL", "http://localhost:4566")

PUBLIC_ACCESS_BLOCK = {
    "BlockPublicAcls": True,
    "IgnorePublicAcls": True,
    "BlockPublicPolicy": True,
    "RestrictPublicBuckets": True,
}


def make_client():
    return boto3.client(
        "s3",
        endpoint_url=ENDPOINT,
        region_name="us-east-1",
        aws_access_key_id="test",
        aws_secret_access_key="test",
    )


def public_access_is_blocked(s3, bucket):
    try:
        config = s3.get_public_access_block(Bucket=bucket)["PublicAccessBlockConfiguration"]
    except ClientError as err:
        if err.response["Error"]["Code"] == "NoSuchPublicAccessBlockConfiguration":
            return False
        raise
    return all(config.get(key) is True for key in PUBLIC_ACCESS_BLOCK)


def has_default_encryption(s3, bucket):
    try:
        response = s3.get_bucket_encryption(Bucket=bucket)
    except ClientError as err:
        if err.response["Error"]["Code"] == "ServerSideEncryptionConfigurationNotFoundError":
            return False
        raise
    # An empty configuration (no rules) means the bucket is not encrypted by default.
    rules = response.get("ServerSideEncryptionConfiguration", {}).get("Rules", [])
    return len(rules) > 0


def versioning_enabled(s3, bucket):
    return s3.get_bucket_versioning(Bucket=bucket).get("Status") == "Enabled"


def fix_public_access(s3, bucket):
    s3.put_public_access_block(
        Bucket=bucket,
        PublicAccessBlockConfiguration=PUBLIC_ACCESS_BLOCK,
    )


def fix_encryption(s3, bucket):
    s3.put_bucket_encryption(
        Bucket=bucket,
        ServerSideEncryptionConfiguration={
            "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
        },
    )


def check_bucket(s3, bucket, apply_fixes):
    """Return the number of fixable problems found on one bucket."""
    found = 0

    if not public_access_is_blocked(s3, bucket):
        found += 1
        print(f"[FINDING] {bucket}: public access is not fully blocked")
        if apply_fixes:
            fix_public_access(s3, bucket)
            print(f"[FIXED]   {bucket}: public access block applied")

    if not has_default_encryption(s3, bucket):
        found += 1
        print(f"[FINDING] {bucket}: no default encryption")
        if apply_fixes:
            fix_encryption(s3, bucket)
            print(f"[FIXED]   {bucket}: default encryption (SSE-S3) applied")

    if not versioning_enabled(s3, bucket):
        print(f"[REPORT]  {bucket}: versioning is off (needs an owner decision, not auto-fixed)")

    return found


def main():
    parser = argparse.ArgumentParser(description="Detect and fix S3 bucket drift.")
    parser.add_argument(
        "--fix",
        action="store_true",
        help="apply the automatic fixes (default: report only)",
    )
    args = parser.parse_args()

    s3 = make_client()
    buckets = [item["Name"] for item in s3.list_buckets()["Buckets"]]
    print(f"Checking {len(buckets)} bucket(s) at {ENDPOINT}")

    total = sum(check_bucket(s3, name, args.fix) for name in buckets)
    print(f"Done. Fixable problems found: {total}")

    # In report mode a non-zero exit lets a pipeline fail on drift.
    return 1 if total and not args.fix else 0


if __name__ == "__main__":
    sys.exit(main())