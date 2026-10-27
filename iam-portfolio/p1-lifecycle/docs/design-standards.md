# P1 Design Standards: Naming and Birthright Access

## 1. Source of truth
`users.csv` plays the role of the HR system. Columns: FirstName, LastName, Department, JobTitle, Manager, StartDate, EmploymentType, EndDate. I added **EndDate** (blank for employees) because contractors must have an expiry; it feeds the Leaver task.

Heads of department have a blank Manager (they report to an executive outside this dataset).

## 2. Naming standard

| Object | Standard | Example |
|---|---|---|
| Username (UPN prefix) | `firstname.lastname`, lowercase, letters only | `priya.nair@<tenant>.onmicrosoft.com` |
| Display name | `First Last` | Priya Nair |
| Contractor display name | `First Last (Contractor)` | Hannah Brooks (Contractor) |
| Duplicate names | append a number to the username | `john.smith2` |
| Special characters | strip accents/apostrophes/spaces (O'Brien → `obrien`, Müller → `muller`) | |
| Department groups | `grp-<department>` | `grp-finance` |
| Contractor group | `grp-contractors` | |
| Future admin accounts (PAM) | `adm-firstname.lastname`, separate from the daily account | `adm-ethan.walker` |

**Why this matters:**
- Predictable names make provisioning scripts, searches, and audits reliable.
- Lowercase and plain characters avoid sign-in and integration failures in apps that handle case or accents badly.
- Marking contractors in both the display name and `EmploymentType` makes them easy to spot in reviews and directory searches.
- Separating admin from daily accounts limits the damage from a phished daily account.

**Trade-off:** firstname.lastname is readable but reveals employee names and breaks on duplicates and name changes (marriage, legal change). Opaque IDs (e.g., `u104233`) avoid both but are painful for humans. Most organizations choose readable plus a collision rule, and keep a separate immutable internal ID (employee ID).

## 3. Birthright access (lab version)

Birthright access is what a person gets automatically because of their role. Anything beyond this is **request-based** and needs approval. This lab has no real apps, so these are conceptual; Project 2 (RBAC) maps them to real S3 buckets.

| Group | Members | Birthright access (conceptual) | NOT included (request + approval) |
|---|---|---|---|
| `grp-sales` | Sales team | CRM app, Sales shared drive | Finance reports, HR records |
| `grp-hr` | HR team | HRIS app, HR shared drive (sensitive) | Payroll approval, IT admin tools |
| `grp-it` | IT team | Ticketing system, IT shared drive, monitoring (read) | Production admin rights (use a separate admin account) |
| `grp-finance` | Finance team | ERP/Finance app, Finance shared drive | Payroll approval for AP staff (separation of duties) |
| `grp-contractors` | All contractors | Collaboration tools only (email, chat), reviewed regularly | Any internal data stores |

**Decision on contractors:** contractors are members of `grp-contractors` **and** their department group.
- *Why:* they need job-relevant access to do the work, and `grp-contractors` gives you one place to apply stricter rules, track expiry, and run focused access reviews.
- *Trade-off:* the department group may grant more than a short-term contractor needs. A tighter alternative is contractors-only access plus per-resource requests, which is safer but slower and creates more tickets. In production, add an expiry on membership.

**Optional:** a baseline `grp-all-staff` for universal access (intranet, chat). It's not needed for the lab.

## 4. Planned test scenarios

| Scenario | User | Change |
|---|---|---|
| Mover: cross-department | Diego Torres | Sales Representative → Financial Analyst (Finance) |
| Mover: privilege increase | Maya Patel | IT Helpdesk Analyst → Systems Administrator (same dept; requires justification and admin account) |
| Mover: title only | Priya Nair | Account Executive → Senior Account Executive (no access change) |
| Leaver: standard | Tyler Nguyen | Resignation, last day scheduled |
| Leaver: urgent | Hannah Brooks | Contractor ended immediately (block, revoke, reset) |
| Expiry check | Lena Fischer | Contractor end date 2026-12-31, check "who is expiring soon" |

## 5. Trade-off
- "My CSV stands in for an HR source of truth, and I added an end date so contractor expiry is tracked."
- "I chose readable usernames with a collision rule, knowing the trade-off versus opaque IDs."
- "I separated birthright from request-based access, so default access stays minimal."
- "Contractors get both groups for usability. In production I'd add membership expiry or tighter scoping."
