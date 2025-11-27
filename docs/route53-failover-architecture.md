# Route 53 Failover Architecture for Disaster Recovery

This document describes the Route 53 failover architecture implemented for disaster recovery in this project.

## Architecture Overview

The system uses AWS Route 53 DNS failover to automatically route traffic between the primary region (us-east-1) and the disaster recovery region (us-west-2) in case of an outage.

```
                                   ┌──────────────────────┐
                                   │                      │
                                   │  AWS Route 53        │
                                   │  - Health Checks     │
                                   │  - Failover Records  │
                                   │                      │
                                   └──────────┬───────────┘
                                              │
                       ┌─────────────────────┬┴────────────────────────┐
                       │                     │                         │
         ┌─────────────▼───────────┐         │         ┌──────────────▼────────────┐
         │                         │         │         │                           │
         │  Primary Region         │         │         │  DR Region                │
         │  (us-east-1)           │◄────────┘         │  (us-west-2)              │
         │                         │         ▲         │                           │
         │  - Active Services      │         │         │  - Standby Services       │
         │  - Monitored by Health  │         │         │  - Replicated Data        │
         │    Check                │         │         │  - Ready for Failover     │
         │                         │         │         │                           │
         └─────────────────────────┘         │         └───────────────────────────┘
                       ▲                     │                         ▲
                       │                     │                         │
                       └─────────────────────┴─────────────────────────┘
                                  Traffic Flows to Active Region
```

## How It Works

1. **Health Checks**: 
   - Route 53 continuously monitors the health of the primary region using HTTP/HTTPS health checks
   - Health checks are configured to test a specific endpoint (e.g., `/health`) at regular intervals

2. **Failover DNS Records**:
   - Primary record (Type: A) with failover routing policy set to PRIMARY
   - DR record (Type: A) with failover routing policy set to SECONDARY

3. **Normal Operation**:
   - DNS queries resolve to the primary region endpoint
   - All traffic flows to services in the primary region

4. **During an Outage**:
   - Health checks detect failure in the primary region
   - Route 53 automatically updates DNS to resolve to the DR region endpoint
   - Traffic is redirected to the DR region until the primary region recovers

5. **Recovery**:
   - Once health checks pass for the primary region, Route 53 automatically fails back
   - Traffic resumes flowing to the primary region

## Implementation Details

The Route 53 failover configuration is deployed as part of the production infrastructure using the `modules/route53-failover` module. Both the primary and DR infrastructures are deployed simultaneously when applying the production environment.

### Key Components

- **Health Checks**: Configured to check HTTPS endpoints at 30-second intervals
- **Hosted Zone**: Contains the DNS records for the application domain
- **DNS Records**: Configured with failover routing policies pointing to the appropriate endpoints

## Testing the Failover

To test the failover mechanism:

1. Use the DR testing framework provided in this repository
2. Simulate a failure in the primary region by:
   - Temporarily disabling the health check endpoint
   - Introducing network disruption to the primary region
   - Running the failover test script in the `dr-testing-framework` directory

## Monitoring

Monitor the health and status of your failover configuration through:

1. AWS CloudWatch metrics for Route 53 health checks
2. Route 53 health check status dashboard
3. DNS resolution testing to verify proper failover behavior

## Additional Resources

- [AWS Route 53 Health Checks and DNS Failover Documentation](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover.html)
- [AWS Disaster Recovery Architectures](https://aws.amazon.com/blogs/architecture/disaster-recovery-dr-architecture-on-aws-part-i-strategies-for-recovery-in-the-cloud/)