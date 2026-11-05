# Joiner / Mover / Leaver Runbook

**Version:** 1.0 | **Owner:** IAM | **System:** Microsoft Entra ID (lab tenant) | **Source of truth:** `hr-source.csv` (stands in for the HR system)

## 1. Purpose
Give each person the access their role needs from day one, change it when the role changes, and remove it when they leave, with evidence at every step. The goal is least privilege across the whole identity lifecycle.

## 2. Scope
- **In scope:** employees and contractors with an Entra account; department security groups (`grp-sales`, `grp-hr`, `grp-it`, `grp-finance`), `grp-contractors`; directory roles.
- **Out of scope (lab):** app-level local accounts, shared/service accounts, mailbox and device handling, physical access.

## 3. Roles

| Role | Responsibility |
|---|---|
| **HR** | Creates and updates the hire/change/termination record; the only source of truth for the trigger |
| **Hiring/People Manager** | Confirms role and access needs; approves movers and any request-based access; owns the department group |
| **IAM** | Executes account and group changes; verifies; records evidence |
| **IT (Service Desk)** | Hands over credentials/devices securely; supports first login; handles equipment return |

## 4. Triggers

| Event | Trigger | Path |
|---|---|---|
| New hire | HR record created | Joiner |
| Department, title, or manager change | HR record updated | Mover |
| Resignation / end of employment | HR termination notice | Leaver (standard) |
| Dismissal, security incident, or contractor ended early | HR/Security notice flagged urgent | Leaver (urgent) |
| Contractor `EndDate` within 30 days | Scheduled review | Extend or Leaver |

## 5. Procedures

### Joiner
1. HR submits the record with department, title, manager, start date, employment type, and (contractors) end date.
2. IAM validates the data (no duplicates; username follows `first.last` with a collision rule; manager exists).
3. Create the account (initial unique password, forced change at first sign-in, usage location set).
4. Add the user to the **department group**; contractors also join `grp-contractors`. Set Manager.
5. Anything beyond birthright access goes through a manager-approved request.
6. Verify: sign in once from a private window, confirm the password change prompt, confirm group membership.
7. Notify the manager and IT; deliver credentials through a separate channel; log evidence.

### Mover
1. HR submits the change with an effective date.
2. IAM classifies it: **title only** (log, no access change), **same-department privilege change**, or **cross-department**.
3. Manager approves the new access in writing (ticket). Directory roles require a justification and a separate admin account.
4. IAM snapshots current groups and roles (**"before"**).
5. **Remove old access first, then add new access.**
6. Snapshot again (**"after"**) and verify the user no longer holds old-role access.
7. Record in the Mover Log (user, from, to, removed, added, approver, date).
- *Exception:* an overlap period for handover is allowed only with a ticketed end date, 30 days maximum.

### Leaver, standard
1. HR sends notice with the last working day.
2. On the **last working day (end of day)**, in this order: reset the password to a random value, **Revoke sessions**, then set **Account enabled = No**. (Entra will not reset the password of a disabled account, so the reset must come first.)
3. Remove all group memberships and directory roles; record what was removed.
4. Manager confirms data and ownership handoff; IT collects equipment.
5. Keep the account **disabled for 30 days**, then delete. Deleted users remain recoverable for 30 days in Entra.

### Leaver, urgent
1. Notice arrives from HR or Security, flagged urgent.
2. **Immediately, in one continuous sequence:** reset password, Revoke sessions, Account enabled = No. Do not pause between steps; disabling is last only because a disabled account cannot have its password reset.
3. Then remove groups/roles, and review recent sign-in and audit activity for anything unusual.
4. Notify the manager and Security; continue with the standard retention steps.

## 6. SLAs (lab targets; adjust to organization policy)

| Process | Target |
|---|---|
| Joiner | Account ready by the start date, with HR notice received at least 3 business days before |
| Mover | Old access removed on the effective date, or within 2 business days of notice |
| Leaver, standard | Disabled by end of the last working day |
| Leaver, urgent | Within 1 hour of notice (aim for 15 minutes) |
| Contractor expiry | Disabled on `EndDate`; renewal decided 30 days before |
| Retention | Disabled 30 days, then deleted |

## 7. Evidence collected
Attach to each case (file names in `/evidence`): bulk-create result and user list (Joiner); group membership screenshots; before/after snapshots and the completed Mover Log; sign-in-blocked and sessions-revoked screenshots, plus removed-groups list (Leaver); deleted-users page; approval ticket or email for any exception; date and time of each action.

## 8. Exceptions
- **Emergency access:** granted by the manager's verbal approval and documented in writing within 24 hours.
- **Overlap access for movers:** ticketed end date, 30 days maximum.
- **Extended retention or legal hold:** HR/Legal request, documented, reviewed monthly.
- **Missing or late HR notice:** IAM acts on a manager's request and flags the HR process gap.
- Every exception is recorded with requester, approver, reason, and expiry.

---

# 9. Controls Mapping

| Step | Control | Type | Risk it reduces |
|---|---|---|---|
| Validate data before account creation | Data check | Preventive | Duplicate or wrong accounts from bad HR data |
| Forced password change at first sign-in | Credential control | Preventive | Account use by someone who knows the initial password |
| Add user to department group only | Birthright access model | Preventive | Over-provisioning ("copy a coworker's access") |
| Manager approval for extra access | Authorization | Preventive | Unapproved or excessive access |
| Remove old groups **before** adding new | Order of operations | Preventive | Access creep from movers; temporary over-access |
| Before/after snapshot | Evidence | Detective | Unverified or undocumented changes |
| Block sign-in + revoke sessions | Immediate deactivation | Corrective | Ex-employee or terminated user access |
| Reset password at leave (before disabling) | Credential invalidation | Corrective | Use of cached or known credentials |
| Remove groups and roles | Access removal | Corrective | Residual rights if the account is re-enabled by mistake |
| Disable 30 days, then delete | Retention policy | Preventive / Recovery | Data loss and unrecoverable mistakes; long-lived orphans |
| Contractor `EndDate` and 30-day expiry review | Time-bound access | Preventive | Contractor access outliving the engagement |
| Separate admin account for directory roles | Privilege separation | Preventive | One phished daily account giving admin control |
| Mover Log and evidence folder | Audit trail | Detective | Failed audits; inability to prove who approved what |

---

# 10. Metrics

| Metric | How to calculate | Target | Why it matters |
|---|---|---|---|
| **Time-to-provision** | Account-ready time minus HR record time | Ready by start date | Productivity and shadow-IT risk |
| **Time-to-deprovision** | Account-disabled time minus termination notice time | Standard: end of last day; urgent: ≤ 1 hr | Direct measure of ex-employee exposure |
| **Orphaned accounts** | Enabled accounts with no matching active HR record | 0 | Top audit finding; real attack surface |
| **% movers with old access removed** | Movers with old groups removed by effective date ÷ total movers | 100% | Measures access creep control |
| **Contractor expiry compliance** | Contractors disabled on `EndDate` ÷ contractors past end date | 100% | Time-bound access works |
| **Birthright accuracy** | New users whose groups match their department ÷ total joiners | 100% | Quality of the joiner process |
| **Dormant accounts** | Enabled accounts with no sign-in for 90 days | Trend to 0 | Catches leavers the process missed |

*Data sources:* HR records (CSV), Entra user list, audit logs, sign-in logs, Mover Log.

---

# 11. Known Gaps in This Lab and Production Fixes

| # | Gap | Risk | Production fix |
|---|---|---|---|
| 1 | **Manual CSV instead of an HR integration.** Someone has to notice the event and run the change. | Delays, typos, missed leavers, wrong trigger date | HR system (e.g., Workday) as authoritative source feeding Entra through built-in provisioning or SCIM, with automated joiner and leaver workflows and reconciliation reports for mismatches |
| 2 | **Static groups, manual membership.** No dynamic groups on the free tier, so mover removals depend on a human remembering. | Access creep when the "remove old" step is missed | Dynamic groups driven by `department`/`jobTitle` (Entra ID P1), plus scheduled access reviews as a safety net. *Next step:* the project 5 Python script, which automates the same remove-then-add steps |
| 3 | **No app-level accounts or full logs.** Lab apps are conceptual, sign-in history is short, and no SaaS apps hold local accounts. | A "disabled" user may still have working access in apps outside SSO; dormant checks are weak | Put apps behind SSO (project 3) or provision with SCIM so disabling the identity removes app access; ship logs to a SIEM for long-term retention; inventory apps with local accounts and handle them in the leaver checklist |

**Also worth naming:** service and shared accounts have no owner process here, and the lab has no approval workflow tool (approvals are simulated with tickets or email).
