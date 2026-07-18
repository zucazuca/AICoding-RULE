# APPROVAL_RECORD

## Identity

- Task-ID: {{TASK_ID}}
- Plan-Revision: {{PLAN_REVISION}}
- Plan-Identifier: {{PLAN_IDENTIFIER}}
- Plan-Hash: {{PLAN_HASH}}
- Base-Commit: {{FULL_BASE_COMMIT}}
- Candidate-Commit: {{FULL_CANDIDATE_COMMIT}}
- Role: approver

## Scope

- Allowed-Files: {{ALLOWED_FILES}}
- Forbidden-Files: {{FORBIDDEN_FILES}}

## Acceptance-Matrix

{{FROZEN_ACCEPTANCE_MATRIX_AND_FINAL_DISPOSITION}}

## Environment

{{REVIEW_TEST_PUSH_AND_RELEASE_ENVIRONMENTS}}

## Residual-Risks

{{NONE_OR_ACCEPTED_UNACCEPTED_RISKS}}

## Decisions

- Code-Review-Decision: {{APPROVE_TEST_R1_R2_REPLAN_REJECT_SCOPE}}
- Test-Decision: {{PASS_CONDITIONAL_PASS_FAIL_TEST_BLOCKED_SPEC_GAP}}
- Push-Decision: {{APPROVE_PUSH_DENY_PENDING_NOT_APPLICABLE}}
- Release-Decision: {{APPROVE_RELEASE_DENY_PENDING_NOT_APPLICABLE}}
- Owner-Decision: {{APPROVED_DENIED_PENDING_NOT_REQUIRED}}

## Evidence

- Plan-Evidence: {{LINK_OR_COMMAND_OUTPUT}}
- Diff-Evidence: {{BASE_TO_CANDIDATE_DIFF}}
- Test-Evidence: {{INDEPENDENT_TEST_REPORT_REFERENCE}}
- Risk-Acceptance: {{NONE_OR_ACCEPTED_RESIDUAL_RISKS}}
- Owner-Evidence: {{NONE_OR_HUMAN_DECISION_REFERENCE}}

## Audit

- Timestamp: {{ISO_8601_WITH_TIMEZONE}}
- Approver: {{ROLE_OR_ID}}
- Target-Branch: {{BRANCH}}
- Target-Environment: {{ENVIRONMENT_OR_NONE}}
- Pushed-State: {{NOT_PUSHED_OR_PUSHED_EVIDENCE}}
- Released-State: {{NOT_RELEASED_OR_RELEASED_EVIDENCE}}

## State

~~~text
{{STATE}} {{FULL_CANDIDATE_COMMIT}}
~~~
