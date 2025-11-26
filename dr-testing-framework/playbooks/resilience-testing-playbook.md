# AWS Resilience Testing Playbook

## Overview

This playbook provides structured procedures for testing the resilience of AWS infrastructure components. The goal is to validate that systems can withstand failures and recover within defined RTO/RPO objectives.

## Test Categories

### 1. Infrastructure Resilience Tests

#### 1.1. EC2 Instance Failure Testing

**Objective**: Verify auto-recovery or auto-scaling mechanisms respond correctly to instance failures.

**Procedure**:
1. Document baseline metrics (instance count, response times)
2. Execute FIS experiment using `scripts/fis/ec2-termination.json`
3. Measure time to recovery
4. Validate system continues to function during recovery
5. Document findings in test report template

**Success Criteria**:
- Auto-scaling group launches replacement instances within 3 minutes
- Application remains available with < 30 seconds of disruption
- No data loss occurs

#### 1.2. Availability Zone Failure Simulation

**Objective**: Verify multi-AZ resilience capabilities.

**Procedure**:
1. Document services running in each AZ
2. Execute FIS experiment using `scripts/fis/az-outage.json`
3. Measure failover time for each service
4. Validate cross-AZ communication during failure
5. Document findings

**Success Criteria**:
- All critical services remain available
- Failover mechanisms activate within defined timeframes
- No data loss occurs

### 2. Database Resilience Tests

#### 2.1. RDS Failover Testing

**Objective**: Verify RDS failover mechanisms work as expected.

**Procedure**:
1. Document database performance baseline
2. Initiate RDS failover (manual or via FIS)
3. Measure failover time
4. Validate application behavior during failover
5. Document findings

**Success Criteria**:
- RDS failover completes within 2 minutes
- Application handles connection disruption gracefully
- No data loss or corruption occurs

#### 2.2. DynamoDB Throttling Response

**Objective**: Verify application resilience to DynamoDB throttling.

**Procedure**:
1. Document baseline performance
2. Execute throttling test using `scripts/fis/dynamodb-throttle.json`
3. Monitor application behavior and error rates
4. Validate retry mechanisms and error handling
5. Document findings

**Success Criteria**:
- Application implements backoff/retry mechanisms
- Error rates remain below threshold
- User experience degradation is minimized

### 3. Network Resilience Tests

#### 3.1. Network Latency Testing

**Objective**: Verify application performance under increased network latency.

**Procedure**:
1. Document baseline network performance
2. Execute FIS experiment using `scripts/fis/network-latency.json` 
3. Measure application response times
4. Validate timeout settings and retry mechanisms
5. Document findings

**Success Criteria**:
- Application timeout settings are appropriate
- Retry mechanisms function correctly
- User experience degradation is within acceptable limits

## Execution Guidelines

1. Always run tests in a controlled environment first
2. Schedule production tests during maintenance windows
3. Ensure monitoring is in place before running tests
4. Have rollback procedures ready for each test
5. Document all findings, even if tests pass

## Reporting

Complete the resilience test report template in `test-reports/templates/resilience-test-report.md` for each test execution.