# Design Rationale: RBAC for a Fictional Company

## 1. Principles
- **Least privilege:** each role gets only the actions and resources its job needs.
- **Roles, not people:** permissions attach to groups that represent job roles; users inherit them by membership.
- **Default deny:** AWS denies anything not explicitly allowed, so the design is a list of allows.
- **Separation of duties:** no role can both administer a system and read the sensitive data inside it.

## 2. Role-permission matrix with justifications

| Role | Resource | Level | Justification |
|---|---|---|---|
| Sales Rep | sales-data | Read/Write | Creates and updates their own team's records |
| Sales Rep | hr-data, finance-data | None | No job need; HR and finance data are sensitive |
| HR Specialist | hr-data | Read/Write | Owns HR records |
| HR Specialist | sales-data, finance-data | None | No job need |
| Finance Analyst | finance-data | Read/Write | Owns financial records |
| Finance Analyst | sales-data | **Read** | Needs revenue figures for reporting; read-only so Finance cannot alter sales records (documented exception) |
| Finance Analyst | hr-data | None | Payroll detail is not part of this role |
| IT Helpdesk | EC2 | Read | Needs to see instances to troubleshoot, but cannot change them |
| IT Helpdesk | all buckets | None | Support does not need business data |
| IT Admin | EC2 | Read | Infrastructure visibility |
| IT Admin | Bucket config | Read | Can inspect bucket policy, tags, and location to manage infrastructure |
| IT Admin | all bucket contents | None | Separation of duties: administering storage does not require reading its data |

**Separation-of-duties rules**
1. IT Admin manages infrastructure but cannot read HR or finance data.
2. Only Finance writes finance data; no IT role has object access.

## 3. Trade-offs and decisions

| Decision | Alternative | Why I chose this |
|---|---|---|
| Five roles | More, finer roles | Fewer roles are easier to review. Add a role only when several people need the same exception |
| Custom, per-bucket policies | AWS managed `AmazonS3ReadOnlyAccess` | The managed policy covers every bucket, which breaks least privilege. Cost: I maintain the policies |
| No `s3:DeleteObject` | Grant delete to data owners | Accidental or malicious deletion is high-impact; add only on a stated need |
| `pol-console-nav` (`s3:ListAllMyBuckets` on `*`) on all groups | No list permission | Needed for the console bucket list. It reveals bucket names, which I accepted knowingly; without it users need direct URLs |
| Allow-only, no explicit Deny | Explicit Deny guardrails | Simple and testable. Explicit denies are reserved for guardrails, since they override every allow |
| IAM users | IAM Identity Center with federation | Simple for a lab. Production maps IdP groups to roles, so nobody holds a standing IAM user |
| Terraform | Console clicks | Repeatable, reviewable in code, and one command tears it down. Cost: state holds generated passwords, so it stays out of the repo |
| Finance read on sales-data | Strict "own department only" | A real business need; documented so it does not become silent access creep |

## 4. Role-explosion analysis

**The problem:** every exception tends to become a new role. Suppose each of four departments had three sub-teams with slightly different access, plus a read-only variant for cross-department reporting. That is 4 x 3 = 12 sub-team roles, plus up to 12 read variants, so about 24 roles to design, test, and review. Each new bucket multiplies the policy count again.

**How this design limits it:**
- Five roles cover five job functions; the one cross-department need is a single attached policy (`pol-sales-data-ro`), not a new role.
- Policies are built from reusable pieces (one per resource and level), so a role is a combination, not a new document.
- Adding a role requires a stated need and a justification row in the matrix.

**What I would do at larger scale:** use attribute-based access control for the long tail. Tag people and resources with attributes such as department, and write fewer policies that compare them, instead of one policy per team-and-bucket pair. This was **not implemented** in this lab; it is the recommended next step if the role count grew, and it requires checking which attribute conditions each AWS service supports.

## 5. What the testing shows
Ten core tests (five allow, five deny) matched expectations on the first run; every denial was an implicit deny. See the README for the table and evidence, and for what remains untested (real sign-in tests, a full role-by-bucket grid).

## 6. Known gaps
Listed with production fixes in the README: simulator-only testing, IAM users instead of federation, no MFA, no guardrails, no access reviews, static roles.
