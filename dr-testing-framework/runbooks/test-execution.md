# DR Test Execution Runbook

## Overview

This runbook provides step-by-step instructions for executing disaster recovery tests in AWS environments. It covers pre-test preparation, test execution, and post-test activities.

## Test Execution Process

### 1. Pre-Test Preparation

#### 1.1. Test Environment Validation

```bash
# Validate test environment is ready
inspec exec profiles/dr/controls/environment_readiness.rb -t aws://region

# Check resource availability
aws cloudwatch get-metric-data --metric-data-queries file://config/resource-metrics.json --start-time $(date -d '1 hour ago' '+%Y-%m-%dT%H:%M:%S') --end-time $(date '+%Y-%m-%dT%H:%M:%S')
```

#### 1.2. Backup Test Data

```bash
# Create backup of test data
bash scripts/data/backup-test-data.sh --environment dr-test --backup-id $(date '+%Y%m%d-%H%M')

# Verify backup completion
aws backup describe-recovery-point --backup-vault-name dr-test-vault --recovery-point-arn [ARN]
```

#### 1.3. Test Notification

1. Notify all stakeholders of upcoming test:
   - Test name and type
   - Start and end times
   - Expected impact
   - Emergency contact information

2. Verify monitoring systems are operational:

```bash
# Check CloudWatch alarms
aws cloudwatch describe-alarms --state-value ALARM

# Verify dashboard access
python scripts/monitoring/verify-dashboard-access.py --dashboard-name dr-test
```

### 2. Test Execution

#### 2.1. Establish Baseline Metrics

```bash
# Capture baseline metrics
python scripts/monitoring/capture-baseline.py --environment dr-test --output-file baseline-$(date '+%Y%m%d').json
```

#### 2.2. Execute Test Scenario

##### Resilience Test Example

```bash
# Run AWS FIS experiment
aws fis start-experiment --experiment-template-id [TEMPLATE_ID] --tags Purpose=DR-Testing

# Monitor experiment progress
aws fis get-experiment --id [EXPERIMENT_ID]
```

##### Security Test Example

```bash
# Execute security test
inspec exec profiles/dr/controls/security.rb -t aws://region --reporter cli json:output.json

# Analyze findings
python scripts/security/analyze-findings.py --input-file output.json
```

##### Performance Test Example

```bash
# Run load test
bash scripts/performance/run-load-test.sh --scenario failover-load --duration 30m

# Monitor performance metrics
python scripts/monitoring/stream-metrics.py --metrics-config config/performance-metrics.json
```

#### 2.3. Test Observation

1. Monitor key metrics during test:

```bash
# Watch critical metrics
aws cloudwatch get-metric-data --metric-data-queries file://config/critical-metrics.json --start-time [TEST_START] --end-time [TEST_END]
```

2. Document observations in real-time:
   - System behavior
   - Unexpected events
   - Performance changes
   - Recovery actions

#### 2.4. Intervention Criteria

Stop the test immediately if:
- Production impact detected
- Security breach occurs
- Data loss detected
- Test exceeds maximum allowed duration

Emergency stop procedure:

```bash
# Stop FIS experiment
aws fis stop-experiment --id [EXPERIMENT_ID]

# Execute emergency rollback
bash scripts/emergency-rollback.sh --environment dr-test
```

### 3. Post-Test Activities

#### 3.1. Data Collection

```bash
# Collect test metrics
python scripts/monitoring/export-test-metrics.py --start-time [TEST_START] --end-time [TEST_END] --output-file test-metrics-$(date '+%Y%m%d').json

# Collect logs
bash scripts/monitoring/collect-logs.sh --start-time [TEST_START] --end-time [TEST_END] --output-dir test-logs-$(date '+%Y%m%d')
```

#### 3.2. Environment Restoration

```bash
# Verify all services returned to normal
inspec exec profiles/dr/controls/service_health.rb -t aws://region

# Restore test data if needed
bash scripts/data/restore-test-data.sh --backup-id [BACKUP_ID] --environment dr-test

# Remove test artifacts
bash scripts/cleanup-test-artifacts.sh --test-id [TEST_ID]
```

#### 3.3. Results Analysis

1. Compare metrics against baseline:

```bash
python scripts/analysis/compare-metrics.py --baseline baseline-$(date '+%Y%m%d').json --test-data test-metrics-$(date '+%Y%m%d').json --output comparison-$(date '+%Y%m%d').json
```

2. Evaluate test against success criteria:

```bash
python scripts/analysis/evaluate-test.py --test-data test-metrics-$(date '+%Y%m%d').json --criteria config/success-criteria.json --output evaluation-$(date '+%Y%m%d').json
```

#### 3.4. Reporting

Complete the appropriate test report template:
- Use `test-reports/templates/resilience-test-report.md` for resilience tests
- Use `test-reports/templates/security-test-report.md` for security tests
- Use `test-reports/templates/performance-test-report.md` for performance tests

Include:
- Test summary
- Success criteria evaluation
- Metrics and screenshots
- Issues encountered
- Recommendations

#### 3.5. Debrief

Schedule test debrief meeting with:
- Test team
- Application owners
- Infrastructure team
- Security team (if relevant)

Focus on:
- Lessons learned
- Process improvements
- Infrastructure improvements
- Follow-up actions

## Appendix

### Test Scenario References

| Test Type | Reference Playbook | Configuration File |
|-----------|-------------------|-------------------|
| EC2 Resilience | playbooks/resilience-testing-playbook.md | config/experiments/ec2-failure.json |
| RDS Failover | playbooks/resilience-testing-playbook.md | config/experiments/rds-failover.json |
| Network Degradation | playbooks/performance-testing-playbook.md | config/experiments/network-latency.json |
| Security Controls | playbooks/security-testing-playbook.md | inspec/profiles/dr/controls/security.rb |

### Success Criteria References

Review success criteria for different test types in:
- `config/success-criteria/resilience.json`
- `config/success-criteria/performance.json`
- `config/success-criteria/security.json`