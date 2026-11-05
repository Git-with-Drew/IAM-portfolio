# IAM Portfolio

Hands-on Identity and Access management (IAM) labs built with free tools and fictional users. Each project has a runbook or design write-up, evidence from the tenant, and an honest list of what the lab does not cover.

## Projects

| # | Project | What I built | Tools | Status |
|---|---|---|---|---|
| 1 | [User Lifecycle Management](p1-lifecycle/README.md) | Joiner / mover / leaver process for 15 users: bulk provisioning, group-based access, urgent and standard offboarding, runbook, controls mapping, metrics | Microsoft Entra ID Free | Complete (follow-ups listed in its README) |
| 2 | RBAC Design and Implementation | Role-permission matrix implemented as cloud groups and policies, with access tests | AWS IAM, Entra roles | Planned |
| 3 | SSO and Federation | Working SAML and OIDC sign-in with annotated flows | Okta, samltest.id | Planned |
| 4 | Cloud IAM Policy Design | Least-privilege policies, conditions, and policy simulation | AWS IAM | Planned |
| 5 | IAM Automation | Python scripts for provisioning, deprovisioning, and access reports | Python, Okta API | Planned |


## How the projects connect
- Project 2 maps the department groups from Project 1 to real resources.
- Project 5 automates the joiner, mover, and leaver steps I first did by hand in Project 1, using the same HR source file as input.

## How each project folder is laid out
```
pN-name/
├── README.md    goal, results, findings, known gaps
├── docs/        runbook, design decisions, diagrams
├── data/        fictional source data and sanitized samples
└── evidence/    redacted screenshots and records
```

## Conventions
- **Fictional data only.** Every user, department, and contractor is invented.
- **No secrets in the repo.** Real upload files, API tokens, and keys are git-ignored. Samples use placeholders.
- **Redacted evidence.** Screenshots have any sensitive information redacted.
- **Honest write-ups.** Each README lists where my execution differed from my own plan and what remains unproven.

## Environment
Free tiers only: Microsoft Entra ID Free, AWS Free Tier, Okta developer account, Python 3. Free-plan limits are noted in each project where they shaped a decision.
