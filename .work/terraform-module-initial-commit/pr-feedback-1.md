---
skill: handle-pr-feedback
phase: complete
pr: 1
url: https://github.com/monte-carlo-data/terraform-google-mcd-k8s-agent/pull/1
branch: mrostan/terraform-module-initial-commit
base: main
---

# PR Feedback: #1 — Add GCP GKE agent Terraform module

> Terraform module for deploying Monte Carlo agent on GCP GKE with conditional resource creation.
> Processed: 2026-04-10

## Work Items

### Human Feedback

#### H1. [BLOCKER] Project-level Secret Manager access is too broad
- **Reviewer:** @97nitt
- **File:** main.tf:L195-L199
- **Comment:** `roles/secretmanager.secretAccessor` is granted at the project level, allowing the agent SA to read every secret. The AWS module scopes secret access to specific ARNs. Suggests using `google_secret_manager_secret_iam_member` on specific secrets instead.
- **Thread:** (no replies)
- **Description:** Replace `google_project_iam_member` for secret access with `google_secret_manager_secret_iam_member` bindings on the specific token secret and each integration secret.
- **Validity:** confirmed
- **Status:** fixed — replaced `google_project_iam_member` with `google_secret_manager_secret_iam_member` scoped to the token secret and each integration secret individually

#### H2. [BLOCKER] Missing storage IAM for existing buckets
- **Reviewer:** @97nitt
- **File:** main.tf:L181-L193
- **Comment:** Both `google_storage_bucket_iam_member` resources use `count = var.storage.create_bucket ? 1 : 0`. When users bring their own bucket, the SA gets no storage permissions. Should always create the binding using the effective bucket name.
- **Thread:** (no replies)
- **Description:** Remove the conditional count (or change condition) and reference the effective bucket name so IAM bindings are created whether the bucket is new or existing.
- **Validity:** confirmed
- **Status:** fixed — removed `count`, both bindings now use `local.effective_bucket_name`

#### H3. [ISSUE] `coalesce` may error at runtime
- **Reviewer:** @97nitt
- **File:** main.tf:L226-L229
- **Comment:** `coalesce(null, "")` raises an error since both are "empty". Suggests using explicit ternary like the AWS module: `var.token_credentials.mcd_id != null ? var.token_credentials.mcd_id : ""`.
- **Thread:** (no replies)
- **Description:** Replace `coalesce` with explicit ternary for mcd_id and mcd_token in the secret version data.
- **Validity:** confirmed
- **Status:** fixed — replaced `coalesce` with explicit ternary matching AWS pattern

#### H4. [ISSUE] `deletion_protection` is hardcoded to `false`
- **Reviewer:** @97nitt
- **File:** main.tf:L102
- **Comment:** For a customer-facing module, a careless `terraform destroy` could wipe a production cluster. Suggests adding a `deletion_protection` field to the `cluster` variable defaulting to `true`.
- **Thread:** (no replies)
- **Description:** Add `deletion_protection` optional field to cluster variable (default `true`) and wire it to the resource.
- **Validity:** confirmed
- **Status:** fixed — added `deletion_protection` to cluster variable defaulting to `true`

#### H5. [ISSUE] Terraform version mismatch in example READMEs
- **Reviewer:** @97nitt
- **File:** examples/agent/README.md:L7, examples/existing_cluster/README.md:L7
- **Comment:** Says `>= 1.3` but `versions.tf` requires `>= 1.9`.
- **Thread:** (no replies)
- **Description:** Update example READMEs to say `>= 1.9` matching versions.tf.
- **Validity:** confirmed
- **Status:** fixed — updated both example READMEs to `>= 1.9`, also removed stale post-deploy token instructions from agent example

#### H6. [ISSUE] `serviceAccount.name` not explicitly set in Helm values
- **Reviewer:** @97nitt
- **File:** main.tf:L305-L309
- **Comment:** Workload identity binding references `local.service_account_name` but Helm values only set the annotation, not the name. If chart's default SA name differs, workload identity binding will silently fail.
- **Thread:** (no replies)
- **Description:** Add `name = local.service_account_name` to the serviceAccount block in helm values.
- **Validity:** confirmed
- **Status:** fixed — explicitly set `name = local.service_account_name` in serviceAccount helm values

#### H7. [SUGGESTION] Inconsistent `cluster_endpoint` format
- **Reviewer:** @97nitt
- **File:** outputs.tf:L6-L9
- **Comment:** `local.cluster_endpoint` prepends `https://` but the output exposes raw endpoint (just IP/hostname). AWS module returns full URL. Suggests aligning.
- **Thread:** (no replies)
- **Description:** Prepend `https://` to the cluster_endpoint output to match the local and the AWS module pattern.
- **Validity:** confirmed
- **Status:** fixed — output now includes `https://` prefix

#### H8. [SUGGESTION] Verify Terraform Registry source path
- **Reviewer:** @97nitt
- **File:** README.md (multiple places)
- **Comment:** Repo is `terraform-google-mcd-k8s-agent` which maps to `monte-carlo-data/mcd-k8s-agent/google` by Registry convention, but README uses `monte-carlo-data/mcd-agent-k8s/google` (reversed). Need to verify correct slug.
- **Thread:** (no replies)
- **Description:** Verify and correct the Terraform Registry source path in README examples.
- **Validity:** not an issue
- **Status:** no change needed — AWS repo (`terraform-aws-mcd-k8s-agent`) uses `monte-carlo-data/mcd-agent-k8s/aws`, so `mcd-agent-k8s` is the intentional Registry slug across all platforms
