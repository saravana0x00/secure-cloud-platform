from unittest.mock import MagicMock

from botocore.exceptions import ClientError

import s3_remediate as tool


def client_error(code):
    return ClientError({"Error": {"Code": code, "Message": "test"}}, "TestOperation")


def fake_s3(public_block=None, encryption_rules=None, versioning="Enabled"):
    """Build a stand-in S3 client. None means the setting is missing."""
    s3 = MagicMock()
    if public_block is None:
        s3.get_public_access_block.side_effect = client_error("NoSuchPublicAccessBlockConfiguration")
    else:
        s3.get_public_access_block.return_value = {"PublicAccessBlockConfiguration": public_block}
    s3.get_bucket_encryption.return_value = {
        "ServerSideEncryptionConfiguration": {"Rules": encryption_rules or []}
    }
    s3.get_bucket_versioning.return_value = {"Status": versioning}
    return s3


ALL_BLOCKED = dict(tool.PUBLIC_ACCESS_BLOCK)
SSE_RULE = [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]


def test_public_access_missing_is_a_finding():
    assert tool.public_access_is_blocked(fake_s3(public_block=None), "b") is False


def test_public_access_partly_blocked_is_a_finding():
    partial = dict(ALL_BLOCKED, BlockPublicPolicy=False)
    assert tool.public_access_is_blocked(fake_s3(public_block=partial), "b") is False


def test_public_access_fully_blocked_passes():
    assert tool.public_access_is_blocked(fake_s3(public_block=ALL_BLOCKED), "b") is True


def test_encryption_with_no_rules_is_a_finding():
    assert tool.has_default_encryption(fake_s3(encryption_rules=[]), "b") is False


def test_encryption_not_found_error_is_a_finding():
    s3 = fake_s3()
    s3.get_bucket_encryption.side_effect = client_error("ServerSideEncryptionConfigurationNotFoundError")
    assert tool.has_default_encryption(s3, "b") is False


def test_encryption_with_a_rule_passes():
    assert tool.has_default_encryption(fake_s3(encryption_rules=SSE_RULE), "b") is True


def test_report_mode_counts_problems_and_changes_nothing():
    s3 = fake_s3(public_block=None, encryption_rules=[])
    assert tool.check_bucket(s3, "b", apply_fixes=False) == 2
    s3.put_public_access_block.assert_not_called()
    s3.put_bucket_encryption.assert_not_called()


def test_fix_mode_applies_both_fixes():
    s3 = fake_s3(public_block=None, encryption_rules=[])
    assert tool.check_bucket(s3, "b", apply_fixes=True) == 2
    s3.put_public_access_block.assert_called_once()
    s3.put_bucket_encryption.assert_called_once()


def test_clean_bucket_is_left_alone():
    s3 = fake_s3(public_block=ALL_BLOCKED, encryption_rules=SSE_RULE)
    assert tool.check_bucket(s3, "b", apply_fixes=True) == 0
    s3.put_public_access_block.assert_not_called()
    s3.put_bucket_encryption.assert_not_called()