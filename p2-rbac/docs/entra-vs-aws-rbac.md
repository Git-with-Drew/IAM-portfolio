# Entra Directory Roles vs AWS IAM Policies

RBAC exists in layers. [Project 1](../../p1-lifecycle/README.md) used **Microsoft Entra directory roles** to control who can administer *identities*. This project used **AWS IAM policies** to control who can touch *cloud resources*. They solve the same problem at different layers, with different mechanics.

| Dimension | Entra directory roles (Project 1) | AWS IAM policies (Project 2) |
|---|---|---|
| **What it controls** | Administration of the directory: users, groups, passwords, role assignments | Actions on cloud resources: S3 objects, EC2 views, bucket settings |
| **How access is defined** | Assign a **built-in role** (a fixed bundle of permissions) to a user | **Write a policy** (actions + resources + optional conditions) and attach it to a group |
| **Example from the labs** | `adm-maya.patel`: Helpdesk Administrator and User Administrator | `aws-finance-analyst`: `pol-finance-data-rw` and `pol-sales-data-ro` |
| **Granularity** | Coarse: pick from the role list | Fine: a single action on a single bucket ARN |
| **Default with no assignment** | Standard user abilities | No permissions at all (implicit deny) |
| **Who holds it** | A user account directly (the lab assigned roles to users, not groups) | A group; users inherit by membership |
| **Where to review it** | User or role **Assigned roles** page | Group **Permissions** tab, Policy Simulator, Access Advisor |
| **Risk if over-granted** | Tenant takeover (a Privileged Role Administrator can grant any other role) | Data exposure or destruction scoped by the policy's resources |

## What the two labs showed

- **Over-granting is easier with roles than with policies.** In Project 1, a title change led to four directory roles on a daily account, including Privileged Role Administrator. Choosing from a list of coarse roles made it easy to grant too much. In AWS, writing a policy forces you to name the actions and resources, which makes over-grant visible in the JSON.
- **The same fix applies in both.** Separate admin accounts (`adm-` in Entra) and group-based assignment (AWS groups) limit blast radius and make access reviewable.
- **Default posture differs.** AWS starts from zero and you add; Entra starts from "standard user" and you add admin power. Both support least privilege, but only AWS lets you scope the grant to a single resource.
- **Admin is not data.** The same separation-of-duties idea shows up in both: IT Admin in AWS manages buckets but cannot read their contents; Entra's Helpdesk Administrator resets passwords for non-administrators but is not a Global Administrator.

## Where they meet
In production the two layers connect through **federation**: the identity provider's groups (Entra) are mapped to cloud roles (AWS). That is the subject of Project 3, and the reason this lab names its AWS groups for roles (`aws-<role>`) rather than reusing the Entra department groups.
