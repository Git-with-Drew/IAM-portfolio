# Project 4: Cloud IAM Policy Design (AWS + Amphi)

An over-permissive AWS policy (`s3:*` on `*`) measured, rewritten to least privilege, and checked with Act Security's open-source **Amphi** tools alongside AWS's own validator and simulator. The scenario is deployed as code with Terraform.

**What this demonstrates:** quantifying wildcard risk, writing least-privilege policies with prefix and transport conditions, trust policies that require MFA, a permission boundary, an SCP-style guardrail, and cross-checking each design with independent evaluators.

## Scenario (fictional)

| Item | Definition |
|---|---|
| Bucket `<prefix>-p4-data` | `reports/`, `logs/`, `secret/` prefixes, one small file each |
| `p4-app-role` | May read `reports/*` and write `logs/*`. Nothing else |
| `dev1` (IAM user) | May assume the lab roles only with MFA |
| `p4-boundary-demo` | A deliberately broad role (`s3:*` on `*`) capped by a permission boundary |

Infrastructure is in [`Deploy/`](Deploy/); policy JSON (with `BUCKET` and `ACCOUNT_ID` placeholders) is in [`policies/`](policies/).

## Amphi tools used

| Tool | Used for | Evidence |
|---|---|---|
| IAM Expand | Counting what wildcards grant; proving the exact grants of the final policy | [`evidence/`](evidence/) text files |
| IAM Shrink | Compressing the expanded baseline back to `s3:*` | [`policies/shrunk.json`](policies/shrunk.json) |
| IAM Convert | Turning policy JSON into Terraform | [`docs/iam-convert-output/`](docs/iam-convert-output/) |
| IAM Simulate (browser) | Testing requests against the policies and explaining the result | [app role](evidence/amphi-simulate-app-role-policy.png), [boundary](evidence/amphi-simulate-boundary-policy.png) |
| IAM Collect and IAM Lens | Cross-checking decisions against collected account data | Results recorded in the test table only; raw outputs not saved |
| IAM Truth | Reading the SCP-style region guardrail ([`policies/scp-region-guardrail.json`](policies/scp-region-guardrail.json)) | [Screenshot](evidence/iam-truth-region-guardrail.png) |

IAM data version used: `@actsecurity/iam-data` 0.22.202611091, last updated Nov 8, 2026 ([screenshot](evidence/iam-expand-data-version.png)). AWS adds actions often, so counts change over time.

## Results

### Before and after
Workbook: [`docs/before-after.xlsx`](docs/before-after.xlsx).

| Pattern | Actions granted |
|---|---|
| `s3:*` (baseline) | **180** |
| `s3:Get*` | 63 |
| `s3:GetO*` | 16 |
| `s3:List*` | 18 |
| `s3:Get*` with `--invert` | 22,404 (covers all AWS services, not just S3) |

| Measure | Before | After |
|---|---|---|
| Actions granted | 180 | **3** (`s3:ListBucket`, `s3:GetObject`, `s3:PutObject`) |
| Resources | `*` | One bucket, plus `reports/*` and `logs/*` |
| Conditions | None | 2 (`s3:prefix`, `aws:SecureTransport`) |
| Explicit denies | 0 | 1 (non-TLS) |

**The baseline is not a read policy.** 69 of its 180 actions (38.3%) fall in sensitive categories, found by keyword search over the expanded list ([search 1](evidence/baseline-sensitive-search1.txt), [search 2](evidence/baseline-sensitive-search2.txt)). They include `s3:PutBucketPolicy` and `s3:PutBucketPublicAccessBlock` (expose data), `s3:DeleteBucket` and `s3:DeleteObjectVersion` (destroy data), and `s3:BypassGovernanceRetention`, `s3:PutBucketVersioning` and `s3:PutBucketLogging` (remove protections and visibility). The least-privilege policy has none. The 69 is a keyword-based estimate, not a formal classification.

### Validation and size
- **AWS Access Analyzer** policy validation of the least-privilege policy returned no findings ([output](evidence/validate-app-role-policy.json)).
- **Exact grants:** the three Allow statements expand to exactly three actions ([output](evidence/app-role-allowed-actions.txt)). The Deny statement is excluded from this count because a Deny grants nothing.
- **Shrink:** the expanded baseline (180 listed actions, 5,405 characters excluding whitespace) shrinks to `s3:*` (116 characters), a 97.9% reduction with identical meaning ([expanded](policies/baseline-expanded.json), [shrunk](policies/shrunk.json)).

### SCP-style region guardrail
The guardrail denies every action outside `us-east-1` except six global services. In IAM Truth, `s3:GetObject` shows **Not Denied** in `us-east-1` and **Denied** in another region (the tool's stand-in for any other region), as designed ([screenshot](evidence/iam-truth-region-guardrail.png)). IAM Truth assumes `FullAWSAccess` is attached, so it shows only what this policy denies. The guardrail was analyzed, not attached to any organization.

### Test table
Workbook: [`docs/test-results.xlsx`](docs/test-results.xlsx). Twelve cases were run against the AWS simulator, Amphi IAM Lens, and a real attempt. **All agree with the expected result across all three.** Evidence for each case is linked in the workbook: six AWS simulator results ([`evidence/aws-simulator/`](evidence/aws-simulator/)), four console sign-ins ([`evidence/console-signin/`](evidence/console-signin/)), the two Amphi Simulate screenshots, and a redacted CloudTrail extract ([`evidence/cloudtrail-events-redacted.json`](evidence/cloudtrail-events-redacted.json)).

| Case | Expected | AWS simulator | IAM Lens | Real |
|---|---|---|---|---|
| app-role: get `reports/q3.txt` | Allow | Allow | Allow | Allow |
| app-role: put `logs/x` | Allow | Allow | Allow | Allow |
| app-role: put `reports/x` | Deny | Implicit deny | Implicit deny | Denied |
| app-role: get `secret/hr.txt` | Deny | Implicit deny | Implicit deny | Denied |
| app-role: list with prefix `reports/` | Allow | Allow | Allow | Allow |
| app-role: list with no prefix | Deny | Implicit deny | Implicit deny | Denied |
| app-role: delete any object | Deny | Implicit deny | Implicit deny | Denied |
| app-role: get over non-TLS | Deny | Explicit deny | Explicit deny | N/A (S3 console uses HTTPS) |
| dev1: assume role without MFA | Deny | Implicit deny | Implicit deny | Denied |
| dev1: assume role with MFA | Allow | Allow | Allow | Allow |
| boundary role: put `secret/x` | Deny (boundary) | Implicit deny | Implicit deny | Denied |
| boundary role: get `reports/q3.txt` | Allow | Allow | Allow | Allow |

## Findings and lessons learned

1. **Wildcards hide their size.** `s3:GetO*` looks like one action and is 16. `s3:*` is 180, and more than a third of those can expose, destroy, or unprotect data. Counting made the risk concrete instead of a feeling.
2. **`NotAction` in an Allow is a trap.** The inverse of `s3:Get*` is 22,404 actions across all services, so "everything except reads" is far larger than it sounds.
3. **A Deny can look like a big grant if you count carelessly.** The least-privilege file's `s3:*` Deny expands to every S3 action, so grants were counted from an Allow-only copy.
4. **MFA enforcement is visible in CloudTrail.** After dev1's MFA device was removed, several attempts to switch into the lab roles failed, and after a new device was enrolled the switches into both roles succeeded with MFA ([extract](evidence/cloudtrail-events-redacted.json)). CloudTrail records these sign-in failures as `SwitchRole: Failure` with no error code.
5. **Other doors stayed closed.** As `dev1`, creating a bucket was denied. From the app role, the AWS assistant and CloudShell calls were denied too, since the role grants only the three S3 actions.



## Known gaps and production fixes

| Gap | Production fix |
|---|---|
| The region guardrail was analyzed, not attached to any organization | Attach through AWS Organizations after testing, with a longer global-services exemption list |
| One account, IAM users, local state | Federated access, remote encrypted state |
| Keyword-based sensitivity estimate | Use a maintained classification of IAM actions by access level |
| No unused-access analysis (paid AWS feature) | Enable it in a production account |

## Repository layout
```
p4-cloud-iam/
├── README.md
├── Deploy/      main.tf, variables.tf, outputs.tf, example.tfvars
├── policies/    baseline, app-role, allow-only, boundary, trust, region guardrail, expanded and shrunk
├── docs/        before-after.xlsx, test-results.xlsx, iam-convert-output/
└── evidence/    Amphi and AWS outputs, screenshots
```

## Data handling
The environment is fictional. Policies use `BUCKET` and `ACCOUNT_ID` placeholders. Terraform state, real `.tfvars`, and Amphi's `iam-data/` collection (which describes a whole AWS account) are git-ignored. Screenshots had the AWS account ID redacted. The CloudTrail file is an extract with any sensitive data redacted. 
