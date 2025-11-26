# DR Testing Framework for AWS_CICD_Project

This framework provides comprehensive Disaster Recovery (DR) testing capabilities for the AWS_CICD_Project infrastructure.

## Quick Start

**New to this project?** Check our [Getting Started Guide](./docs/GETTING_STARTED.md) for beginners.

For detailed instructions on running DR tests, please refer to the [DR Testing Guide](./docs/DR_TESTING_GUIDE.md).

## Overview

The DR testing framework includes:

- **Automated Testing Pipeline**: Run DR tests as part of your CI/CD process
- **Multiple Test Types**: Infrastructure validation, backup/recovery, fault injection, and failover testing
- **Compliance Validation**: Security and configuration compliance testing
- **Reporting**: Comprehensive test reports and metrics

## Key Components

- **Scripts**: Test automation scripts in the `scripts/` directory
- **Configuration**: Environment and test configurations in `config/`
- **InSpec Profiles**: Compliance testing profiles in `inspec/`
- **Modules**: Terraform modules for test infrastructure in `modules/`
- **Documentation**: Comprehensive guides in `docs/`

## Running Tests

Basic commands to run DR tests:

```bash
# Run all DR tests
./scripts/run_dr_tests.sh

# Run specific test types
./scripts/run_dr_tests.sh --type backup-recovery
./scripts/run_dr_tests.sh --type failover
./scripts/run_dr_tests.sh --type fis

# Run quick tests only
./scripts/run_dr_tests.sh --quick
```

## Test Results

Test results are stored in the `results/` directory, with a summary report and detailed logs for each test run.

## Integration

This DR testing framework is integrated with the AWS_CICD_Project and can be run:
- Manually for ad-hoc testing
- Scheduled for regular validation
- As part of deployment pipelines to verify DR capabilities before releases

## Further Documentation

- [DR Testing Guide](./docs/DR_TESTING_GUIDE.md) - Detailed instructions for running tests
- [Pipeline Guide](./docs/PIPELINE_GUIDE.md) - How to set up and use the DR testing pipeline
- [Configuration Guide](./docs/CONFIGURATION.md) - How to configure tests for your environment