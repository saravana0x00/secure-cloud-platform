# NIST SP 800-53 control mapping

This maps the controls in this repository to NIST SP 800-53 Rev. 5 controls. It is an engineering aid for a learning
project, not a formal assessment, and a control is only "satisfied" after review by a qualified assessor.
Everything was tested against LocalStack and a local cluster, not a production system.

Status key: **Automated** = enforced or checked by the pipeline. **Partial** = covered in part, with a stated gap.
**Manual** = relies on a person. **Gap** = not covered yet.

| Control | Name | How this repo addresses it | Evidence | Status |
|---|---|---|---|---|
| CM-2 | Baseline configuration | Terraform defines the cloud baseline as code | `terraform/aws-landing-zone/` | Automated |
| CM-3 | Configuration change control | All changes go through pull requests with required checks | Branch protection, `.github/workflows/` | Partial: no required human reviewer |
| CM-6 | Configuration settings | Checkov and Conftest enforce secure settings on every change | `security-scan.yml`, `policy-as-code/` | Automated |
| CM-7 | Least functionality | Pods must drop all capabilities and run without privilege | `pod-security.rego`, `kubernetes/hardening/` | Automated |
| CM-8 | System component inventory | SBOM generated for every image build | `image-security.yml` | Automated |
| AC-6 | Least privilege | Scoped IAM role for flow logs; non-root containers; narrow network allow rules | `vpc.tf`, `allow-client-to-web.yaml` | Partial: one shared KMS key administered by the account root |
| SC-7 | Boundary protection | Default-deny network policy; empty default security group | `default-deny.yaml`, `vpc.tf` | Partial: demonstrated on a local cluster only |
| SC-12 | Cryptographic key management | Customer-managed KMS key with rotation and explicit policy | `s3.tf` | Partial: not tested on real AWS |
| SC-28 | Protection of information at rest | KMS encryption on buckets and log group | `s3.tf`, `vpc.tf` | Automated |
| AU-2, AU-12 | Event logging and generation | S3 access logs and VPC flow logs | `s3.tf`, `vpc.tf` | Partial: log bucket does not log itself |
| AU-11 | Audit record retention | 365-day retention on logs | `s3.tf`, `vpc.tf` | Automated |
| RA-5 | Vulnerability monitoring and scanning | Trivy scans every image build | `image-security.yml` | Automated |
| SI-2 | Flaw remediation | Build fails on fixable high and critical findings; package patched | `Dockerfile`, `image-security.yml` | Partial: unfixable findings are tracked, not blocked |
| SI-7 | Software and information integrity | Keyless signature by digest, verified in the pipeline | `publish-sign.yml` | Partial: not verified at deploy time |
| SA-11 | Developer testing and evaluation | Unit tests and scanners on every change | `automation-tests.yml` | Automated |
| IA-5 | Authenticator management | Gitleaks scans the history for committed secrets | `secret-scan.yml` | Partial: pattern-based, runs after a push |
| SI-4 | System monitoring | Drift remediation tool detects and fixes S3 drift | `automation/s3_remediate.py` | Partial: on demand only, no alerting |
| SC-5 | Denial-of-service protection | Memory limits required by policy | `pod-security.rego` | Partial: no quotas, CPU limits not enforced |

## Gaps (not covered yet)

| Control | Name | Why it matters here |
|---|---|---|
| CA-7 | Continuous monitoring | No scheduled drift scan, posture reporting or alerting |
| IR-4, IR-5 | Incident handling and monitoring | No incident runbook or post-incident review yet |
| SR-3, SR-4 | Supply chain controls and provenance | Signing exists, but no build provenance attestation and actions are not pinned to commit SHAs |
| AC-2 | Account management | Out of scope for this project, since no real accounts or identities are managed |

## Notes

- Controls were chosen from the ones this repository genuinely touches. Mapping a tool to a control it only loosely relates
  to would make the table look better and be less true.
- FedRAMP baselines include many of these controls, but this table makes no claim about any baseline.
- Row statuses should be updated whenever a control is added or a gap is closed.