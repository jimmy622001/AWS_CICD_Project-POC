# Scheduled Failover Testing Framework

This document describes the automated scheduled failover testing framework implemented in this project.

## Overview

The system includes an automated testing mechanism that verifies the disaster recovery (DR) failover capability on a regular schedule. The tests run during off-peak hours to minimize any potential impact on users.

```
┌───────────────────────┐          ┌───────────────────────┐          ┌────────────────────────┐
│                       │          │                       │          │                        │
│  CloudWatch           │          │  Lambda               │          │  Route 53              │
│  Scheduled Event      ├─────────►│  Failover Test        ├─────────►│  Temporary DNS Change  │
│  (Monthly - Saturday  │          │  Function             │          │  (Failover & Failback) │
│   after midnight)     │          │                       │          │                        │
└───────────────────────┘          └─────────┬─────────────┘          └────────────────────────┘
                                             │                                      │
                                             │                                      │
                                             ▼                                      ▼
                                   ┌────────────────────┐               ┌─────────────────────┐
                                   │                    │               │                     │
                                   │  Test Results &    │               │  Health Checks      │
                                   │  Detailed Logs     │               │  Verify Application │
                                   │                    │               │  Accessibility      │
                                   └─────────┬──────────┘               └─────────────────────┘
                                             │
                                             │
                                             ▼
                                   ┌────────────────────┐
                                   │                    │
                                   │  SNS Notification  │
                                   │  (Email Reports)   │
                                   │                    │
                                   └────────────────────┘
```

## Scheduled Testing Process

The automated failover test performs the following steps:

1. **Pre-Test Validation**
   - Verifies that both primary and DR environments are ready for testing
   - Checks the health of both environments before proceeding

2. **Controlled Failover**
   - Updates Route 53 DNS records to direct traffic to the DR region
   - Waits for DNS propagation (60 seconds)

3. **DR Validation**
   - Verifies that the application is accessible from the DR region
   - Confirms that the failover was successful

4. **Controlled Failback**
   - Restores Route 53 DNS records to direct traffic back to the primary region
   - Waits for DNS propagation (60 seconds)

5. **Post-Test Validation**
   - Verifies that the application is accessible from the primary region
   - Confirms that the failback was successful

6. **Notification**
   - Sends detailed test results via email notification
   - Provides a comprehensive report of all test steps and their outcomes

## Schedule

The failover test runs automatically on the first Saturday of each month at 2:00 AM. This schedule was chosen to minimize potential impact on users during the test.

## Notification System

Test results are sent via Amazon SNS to the specified email addresses. These notifications include:

- Overall test status (Success/Failure)
- Detailed step-by-step results
- Timing information for each step
- Any errors or issues encountered
- Recommendations for addressing failures (if applicable)

## Monitoring and Alerts

The system includes CloudWatch alarms that trigger if:

- The Lambda function encounters errors
- The test fails to complete successfully
- The failback process encounters issues

These alarms ensure that any problems with the DR failover mechanism are promptly identified and addressed.

## Manual Testing

In addition to the scheduled tests, you can manually trigger a failover test at any time by invoking the Lambda function directly from the AWS console or using the AWS CLI:

```bash
aws lambda invoke --function-name scheduled-failover-test-prod output.json
```

## Customizing the Test

The failover test can be customized by modifying the following parameters in the Terraform configuration:

- **Schedule**: Change the CloudWatch Events rule schedule expression
- **Notification Recipients**: Update the list of email addresses that receive test results
- **Health Check Path**: Modify the endpoint path used for health validation
- **Wait Times**: Adjust the DNS propagation wait times

## Troubleshooting

If a scheduled test fails, check the following:

1. **CloudWatch Logs**: Review the detailed Lambda function logs
2. **Health Check Status**: Verify the health of both primary and DR endpoints
3. **Route 53 Configuration**: Ensure the Route 53 records are correctly configured
4. **Network Connectivity**: Confirm that the Lambda function can access both endpoints

## Additional Resources

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html)
- [Amazon CloudWatch Events](https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/WhatIsCloudWatchEvents.html)
- [Amazon SNS Documentation](https://docs.aws.amazon.com/sns/latest/dg/welcome.html)