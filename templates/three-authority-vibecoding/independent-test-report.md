# INDEPENDENT_TEST_REPORT

## Identity

- Task-ID: {{TASK_ID}}
- Plan-Revision: {{PLAN_REVISION}}
- Plan-Identifier: {{PLAN_IDENTIFIER}}
- Plan-Hash: {{PLAN_HASH}}
- Base-Commit: {{FULL_BASE_COMMIT}}
- Candidate-Commit: {{FULL_CANDIDATE_COMMIT}}
- Actual-HEAD: {{FULL_ACTUAL_HEAD}}
- Role: tester

## Scope

- Allowed-Files: NONE
- Forbidden-Files: {{ALL_CONTROLLED_SOURCE_AND_PROJECT_FORBIDDEN_FILES}}

## Acceptance-Matrix

{{FROZEN_ACCEPTANCE_MATRIX_WITH_RESULT_PER_ITEM}}

## Environment

{{OS_RUNTIME_SERVICES_DEPENDENCIES}}

## Test-Data

{{ACCOUNTS_ROLES_TENANTS_FIXTURES_AND_CLEANUP}}

## Results

- Automated-Tests: {{COMMANDS_RESULTS_EXIT_CODES}}
- Regression: {{SCENARIOS_RESULTS}}
- Browser-Acceptance: {{PATH_ROLE_STEPS_EXPECTED_ACTUAL_CONSOLE_NETWORK_EVIDENCE}}
- Permission-Tests: {{AUTHORIZED_UNAUTHORIZED_RESULTS}}
- Isolation-Tests: {{CROSS_USER_TENANT_MERCHANT_RESULTS}}
- Contract-Tests: {{REQUEST_RESPONSE_DATA_RESULTS}}

## Failures

| ID | Severity | Preconditions | Reproduction | Expected | Actual | Evidence | Impact | Blocks-Push | Blocks-Release |
|---|---|---|---|---|---|---|---|---|---|
| {{FAILURE_ID_OR_NONE}} | {{SEVERITY}} | {{PRECONDITION}} | {{STEPS}} | {{EXPECTED}} | {{ACTUAL}} | {{EVIDENCE}} | {{IMPACT}} | {{YES_NO}} | {{YES_NO}} |

## Gaps And Risks

- Unexecuted-Items: {{NONE_OR_ITEMS_AND_REASONS}}
- Environment-Blocks: {{NONE_OR_BLOCKS_AND_UNBLOCK_CONDITIONS}}
- Residual-Risks: {{NONE_OR_RISKS}}

## Final-git-status

~~~text
git status --short
{{OUTPUT_OR_EMPTY}}
~~~

## Conclusion

- Decision: {{PASS_CONDITIONAL_PASS_FAIL_TEST_BLOCKED_SPEC_GAP}}
- Candidate-Binding: {{FULL_CANDIDATE_COMMIT_OR_NONE}}
- Alternative-Evidence: {{NONE_OR_EVIDENCE}}
- Retest-Conditions: {{NONE_OR_CONDITIONS}}

~~~text
{{DECISION}} {{FULL_CANDIDATE_COMMIT_OR_NONE}} {{OPTIONAL_REASON_CODE}}
~~~
