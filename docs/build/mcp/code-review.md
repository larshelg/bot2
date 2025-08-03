---
description: Code review checklist and standards
globs:
  - '**/*.ts'
  - '**/*.js'
  - '**/*.tsx'
  - '**/*.jsx'
---
# Code Review Checklist

## Pre-Review Requirements

Before reviewing any code, ensure:

- [ ] All tests pass in CI/CD pipeline
- [ ] Code follows our style guide and linting rules
- [ ] PR description clearly explains changes and reasoning
- [ ] Branch is up to date with main/master

## Code Quality Checks

### TypeScript/JavaScript

- [ ] **Type Safety**: All variables and functions have proper type annotations
- [ ] **Error Handling**: Proper try-catch blocks and error propagation
- [ ] **Async/Await**: Consistent use of async/await over promises
- [ ] **Null Checks**: Proper handling of null/undefined values
- [ ] **Performance**: No unnecessary re-renders or inefficient loops

### API Endpoints

- [ ] **Authentication**: Proper JWT validation and user authorization
- [ ] **Input Validation**: All inputs validated using Joi/Zod schemas
- [ ] **Rate Limiting**: Applied to public endpoints
- [ ] **Error Responses**: Follow standard error format
- [ ] **Logging**: Appropriate logging for debugging and monitoring

### Security

- [ ] **Sensitive Data**: No secrets in code (use environment variables)
- [ ] **CORS**: Proper CORS configuration
- [ ] **Headers**: Security headers (HSTS, CSP, etc.)
- [ ] **Dependencies**: No vulnerable dependencies (check npm audit)

## Red Flags (Immediate Rejection)

- ❌ **Hardcoded Secrets**: API keys, passwords, or tokens in code
- ❌ **SQL Injection**: Raw SQL queries with string concatenation
- ❌ **No Error Handling**: Functions that can fail without error handling
- ❌ **Breaking Changes**: API changes without proper versioning
