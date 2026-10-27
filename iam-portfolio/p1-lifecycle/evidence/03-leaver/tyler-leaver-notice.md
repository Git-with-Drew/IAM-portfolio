# Leaver Notice and Execution Record: Tyler Nguyen

**Case type:** Standard leaver (resignation), lab scenario
**Runbook:** [`docs/jml-runbook.md`](../../docs/jml-runbook.md), "Leaver, standard"

## Employee
| Field | Value |
|---|---|
| Name / title | Tyler Nguyen, Payroll Specialist |
| Department | Finance |
| Manager (per `hr-source.csv`) | Rachel Kim |
| Account created | Oct 15, 2026, 3:40 PM (Entra overview) |

## Notice and approval
| Field | Value |
|---|---|
| HR record | `EndDate` set to 2026-10-26 in `hr-source.csv` |
| Notice received from HR | **Not captured in this run** |
| Last working day | 2026-10-26, treated as the last day; notice and last day were compressed into one session for the lab |
| Manager approval | Not recorded; the lab has no ticketing system. In production the manager (Rachel Kim) approves by ticket |

## Access before
From the Entra overview ([screenshot](tyler-overview-before.png)): account enabled, **1 group membership**, 0 assigned roles, 0 licenses. The overview shows only the count; the one membership is `grp-finance` per the design standard.

## Execution (from the audit log)
Date: 10/26/2026, local time as displayed in Entra. Evidence: [audit log](tyler-audit-log.png).

| Time | Audit entry | Runbook step |
|---|---|---|
| 1:05:32 | Reset password; password-profile updates | Reset password |
| 1:05:32 | Update StsRefreshTokensValidFrom, initiated by a Microsoft service | Appears to be a side effect of the reset |
| 1:05:39 | Update StsRefreshTokensValidFrom, initiated by the admin | Revoke sessions |
| 1:05:59 | Disable account | Block sign-in |
| 1:06:30 | Remove member from group | Remove group membership |

Order followed: reset password, revoke sessions, disable, remove groups. This is the corrected order from the runbook, since Entra will not reset the password of a disabled account.

## Result
From the Entra overview ([screenshot](tyler-overview-after.png)): account status **Disabled**, **0 group memberships**, 0 assigned roles, 0 licenses.

## Timing
| Measure | Result |
|---|---|
| First action to account disabled | 27 seconds |
| First action to all access removed | 58 seconds |
| Notice received to account disabled | Not measurable (notice time not captured) |

## Retention
The account is **disabled and retained**, not deleted. Planned deletion: 2026-11-25 (30 days after 2026-10-26). Deletion has not been executed. Recovery behavior was tested separately on Lena Fischer ([deleted users page](deleted-users-retention-window.png), [restore audit log](lena-restore-audit-log.png)).

## Notes
- The tenant domain and administrator email were redacted from the screenshots in this folder.
- The reset-triggered token update at 1:05:32 means the explicit revoke at 1:05:39 may have been redundant for refresh tokens. It is kept in the procedure as a deliberate, evidenced step.
