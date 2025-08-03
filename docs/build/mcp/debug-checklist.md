---
description: Debugging procedures and troubleshooting steps
---
# Debug Checklist

## Initial Assessment

- [ ] **Reproduce the Issue**: Can you consistently reproduce the problem?
- [ ] **Error Messages**: Collect all error messages and stack traces
- [ ] **Environment**: Which environment is affected (dev/staging/prod)?
- [ ] **Timing**: When did the issue first appear?

## Common Issues

### API Errors

1. **500 Internal Server Error**
   - Check server logs for detailed error messages
   - Verify database connections
   - Check for unhandled exceptions

2. **401 Unauthorized**
   - Verify JWT token is present and valid
   - Check token expiry
   - Confirm user permissions

3. **404 Not Found**
   - Verify URL path is correct
   - Check if route is properly registered
   - Confirm API version in headers

### Database Issues

1. **Connection Timeout**
   - Check database server status
   - Verify connection string
   - Check connection pool settings

2. **Query Performance**
   - Use EXPLAIN to analyze query execution
   - Check for missing indexes
   - Monitor connection pool usage

### Performance Issues

1. **Slow Response Times**
   - Check database query performance
   - Monitor CPU and memory usage
   - Review caching strategy

2. **Memory Leaks**
   - Monitor memory usage over time
   - Check for unclosed connections
   - Review event listener cleanup

## Debugging Tools

- **Logs**: Always check application and system logs first
- **APM**: Use Application Performance Monitoring tools
- **Database**: Monitor database performance metrics
- **Network**: Check network connectivity and latency
