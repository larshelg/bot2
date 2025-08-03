---
description: Deployment procedures and configurations
globs:
  - '**/deploy/**'
  - '**/*.yml'
  - '**/*.yaml'
---
# Deployment Guide

## Environments

### Development
- Local development environment
- Hot reloading enabled
- Debug logging active

### Staging
- Production-like environment for testing
- Integration with external services
- Performance monitoring

### Production
- Live user environment
- High availability setup
- Comprehensive monitoring and alerting

## Deployment Process

### Prerequisites
- Docker installed
- Kubernetes cluster access
- Environment variables configured

### Steps

1. **Build**: Create Docker images
2. **Test**: Run automated test suite
3. **Deploy**: Apply Kubernetes manifests
4. **Verify**: Health checks and smoke tests

## Configuration

All configuration is managed through environment variables:

```bash
DATABASE_URL=postgresql://...
JWT_SECRET=...
REDIS_URL=redis://...
API_PORT=3000
```

## Monitoring

- Health check endpoints at `/health`
- Metrics collection with Prometheus
- Log aggregation with ELK stack
- Alerting via PagerDuty
