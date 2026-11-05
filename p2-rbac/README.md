# Project 2: RBAC Design and Implementation (AWS IAM + Terraform)

A role-based access control model for a fictional company, deployed as code with **Terraform** , verified with the **IAM Policy Simulator** and console sign-in: five job roles, three data buckets, seven custom least-privilege policies, and ten allow/deny tests that all matched the design.

**What this demonstrates:** role design with written justifications, separation of duties, custom least-privilege policies (not broad managed ones), infrastructure as code, and a matrix-driven testing of both allows and denials.

## Design

Roles come from the fictional departments used in [Project 1](../p1-lifecycle/README.md). Access is granted to **groups that represent roles**, never to individual users.

| Role (AWS group) | sales-data | hr-data | finance-data | EC2 view | Bucket config view |
|---|---|---|---|---|---|
| Sales Rep (`aws-sales-rep`) | Read/Write | none | none | none | none |
| HR Specialist (`aws-hr-specialist`) | none | Read/Write | none | none | none |
| Finance Analyst (`aws-finance-analyst`) | **Read** | none | Read/Write | none | none |
| IT Helpdesk (`aws-it-helpdesk`) | none | none | none | Read | none |
| IT Admin (`aws-it-admin`) | none | none | none | Read | Read |

- **Separation of duties:** IT Admin can see infrastructure and bucket configuration but cannot read HR or finance data. Only Finance writes finance data.
- **One documented exception:** Finance Analyst has read-only access to sales data for revenue reporting.
- **Deliberate omission:** `s3:DeleteObject` is not granted to anyone.
- **Naming:** AWS groups use `aws-<role>`, policies use `pol-<resource>-<level>`, so they stay distinct from the `grp-` department groups in Entra.

Full justifications and trade-offs: [`docs/design-rationale.md`](docs/design-rationale.md). Comparison with Entra directory roles: [`docs/entra-vs-aws-rbac.md`](docs/entra-vs-aws-rbac.md).

## Implementation (Terraform)

Everything is defined in [`Deploy/`](Deploy/), region `us-east-1`. Counted from `main.tf`, it defines all resources:

| Resource | Count | Notes |
|---|---|---|
| S3 buckets | 3 | All four public-access protections on; one dummy `test.txt` each |
| IAM groups | 5 | Created without permissions first, then policies attached |
| IAM users | 5 | `sales1`, `hr1`, `fin1`, `helpdesk1`, `itadmin1`; console login with password reset required at first sign-in; no access keys |
| Customer-managed policies | 7 | JSON copies in [`docs/policies/`](docs/policies/) |
| Group-policy attachments | 12 | `pol-console-nav` on every group, plus the role-specific policies |

The attachment matrix as built:

| Group | Policies |
|---|---|
| `aws-sales-rep` | `pol-console-nav`, `pol-sales-data-rw` |
| `aws-hr-specialist` | `pol-console-nav`, `pol-hr-data-rw` |
| `aws-finance-analyst` | `pol-console-nav`, `pol-sales-data-ro`, `pol-finance-data-rw` |
| `aws-it-helpdesk` | `pol-console-nav`, `pol-ec2-readonly` |
| `aws-it-admin` | `pol-console-nav`, `pol-ec2-readonly`, `pol-s3-config-read` |

**To deploy:** copy `Deploy/example.tfvars` to `terraform.tfvars` with a unique lowercase `name_prefix`, then run `terraform init`, `terraform plan`, `terraform apply`. **To tear down:** `terraform destroy`.

Policies in `docs/policies/` use a `BUCKET_NAME` placeholder in place of the real bucket names.

## Results

Ten core tests were run in the IAM Policy Simulator against the matrix. Workbook: [`docs/test-results.xlsx`](docs/test-results.xlsx).

| ID | User | Action | Expected | Actual | Evidence |
|---|---|---|---|---|---|
| C01 | sales1 | Get object, sales-data | Allow | Allow | [screenshot](evidence/03-simulator/C01-C03-sales1-sales-data.png) |
| C02 | sales1 | Get object, hr-data | Deny | Deny | [screenshot](evidence/03-simulator/C02-sales1-get-hr-data-deny.png) |
| C03 | sales1 | Delete object, sales-data | Deny | Deny | [screenshot](evidence/03-simulator/C01-C03-sales1-sales-data.png) |
| C04 | hr1 | Put object, hr-data | Allow | Allow | [screenshot](evidence/03-simulator/C04-hr1-put-hr-data-allow.png) |
| C05 | fin1 | Get object, sales-data | Allow | Allow | [screenshot](evidence/03-simulator/C05-fin1-get-sales-data-allow.png) |
| C06 | fin1 | Put object, sales-data | Deny | Deny | [screenshot](evidence/03-simulator/C06-fin1-put-sales-data-deny.png) |
| C07 | helpdesk1 | `ec2:DescribeInstances` | Allow | Allow | [screenshot](evidence/03-simulator/C07-helpdesk1-describe-ec2-allow.png) |
| C08 | helpdesk1 | Get object, finance-data | Deny | Deny | [screenshot](evidence/03-simulator/C08-helpdesk1-get-finance-data-deny.png) |
| C09 | itadmin1 | `s3:GetBucketPolicy`, finance-data | Allow | Allow | [screenshot](evidence/03-simulator/C09-itadmin1-get-finance-bucket-policy-allow.png) |
| C10 | itadmin1 | Get object, hr-data | Deny | Deny | [screenshot](evidence/03-simulator/C10-itadmin1-get-hr-data-deny.png) |

**10 of 10 matched on the first run: five allows and five denials.** Every denial in the screenshots reads "Implicit deny due to no statement(s) matching", which shows the design relies on AWS's default deny rather than explicit Deny statements.

**Real console sign-in test.** One case was also run for real, by signing in to the AWS console as the test user:

| ID | User | Action | Expected | Actual | Evidence |
|---|---|---|---|---|---|
| R01 | fin1 | Open the HR bucket in the S3 console and list its objects | Deny | Deny: "Insufficient permissions to list objects", naming the missing `s3:ListBucket` action | [screenshot](evidence/04-console-signin/R01-fin1-console-list-hr-data-denied.png) |

The error names `s3:ListBucket`, the exact action that `fin1`'s policies do not grant on the HR bucket, which matches the design and the simulator. The account ID and the bucket-name prefix are redacted in the screenshot.

Supporting evidence for the build: [groups before policies](evidence/01-foundation/groups-before-policies.png) ("Not defined"), [users](evidence/01-foundation/users.png), [groups after policies](evidence/02-policies/groups-permissions-defined.png) ("Defined"), and one permissions page per group in [`evidence/02-policies/`](evidence/02-policies/). Each shows the attached policies matching the matrix. The console totals (6 groups, 8 users) include entries beyond the five lab groups and users, which the screenshots crop out.

## Findings and lessons learned

1. **The design, the code, and the console agree.** The matrix, the Terraform attachment map, the console permissions pages, and the simulator results all say the same thing. That traceability is the point of defining access as code.
2. **Default deny does the work.** With no explicit Deny statements, every ungranted action was refused. The trade-off is that a later over-broad policy attached to a group would silently grant access, so guardrails (explicit denies, permission boundaries) are the next layer.
3. **Passing first time proves only what was tested.** Ten cases cover each role's key allow and deny, but not every role against every bucket. A full grid of role, bucket, and action combinations would be the next test to write.
4. **Infrastructure as code made the lab disposable.** The whole environment can be rebuilt or destroyed with one command. The cost is that Terraform state holds the generated initial passwords, so state is excluded from the repo and would need encrypted remote storage in production.

## Known gaps and production fixes

| Gap | Production fix |
|---|---|
|  **Limited real sign-in testing.** One console test is evidenced (R01, `fin1` denied listing the HR bucket); the other nine core tests are simulator-only. The simulator checks identity-based policies, not the whole sign-in path. | Sign in as each remaining user and capture the outcomes; add automated checks |
| **IAM users instead of federation.** People should not have standing IAM users. | Federate from the IdP (Entra/Okta) into IAM Identity Center and map IdP groups to roles (see Project 3) |
| **No MFA on the test users.** Didn't eneble MFA as this is a test disposable env. | Enforce MFA , for example with a policy condition on `aws:MultiFactorAuthPresent` |
| **No guardrails.** No explicit Deny statements or permission boundaries. | Add boundaries for any role that can create roles or users, and explicit denies for sensitive actions |
| **No access reviews.** Group membership is static and unreviewed. | Periodic recertification (Project 1 covers the process side) |
| **Static roles.** Fine at five roles; role explosion at scale. | Attribute-based conditions on tags for the long tail (analysis in the rationale) |
| **Local Terraform state.** | Remote, encrypted state with locking |

## Repository layout
```
p2-rbac/
├── README.md
├── .gitignore
├── Deploy/      main.tf, variables.tf, outputs.tf, example.tfvars, test.txt
├── docs/        design-rationale.md, entra-vs-aws-rbac.md, test-results.xlsx,
│                policy-attachment-matrix.png, policies/*.json
└── evidence/    01-foundation/, 02-policies/, 03-simulator/, 04-console-signin/
```

## Data handling
The environment is fictional. Terraform state, the real `terraform.tfvars`, and generated console passwords are excluded from the repository. Screenshots have the AWS account ID and the bucket-name prefix redacted, and contain no credentials.

## Next steps
Project 3 (SSO and federation) connects an identity provider to a cloud application, which is the missing link between the department groups in Project 1 and the roles in this project.
