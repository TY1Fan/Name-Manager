# Names Manager - Development Constitution

## Overview
This document establishes practical quality standards for the Names Manager application. These are realistic standards for a small web application that balance quality with development velocity.

## Testing Standards

### Basic Testing Requirements
- **Coverage Target**: 60% code coverage (realistic for a small team)
- **Backend**: Test core API endpoints and validation logic
  - Happy path for each endpoint
  - Basic error handling
  - Input validation edge cases
- **Frontend**: Test critical user interactions
  - Form submission
  - Basic error display
- **Manual Testing**: Document test cases for manual verification

### Testing Approach
- **Backend**: Simple pytest setup with basic coverage
- **Frontend**: Manual testing with documented test cases
- **Integration**: Basic smoke tests to verify system works end-to-end

## Security Standards

### Basic Security
- **Input Validation**: Server-side validation for all user inputs
- **SQL Injection**: Continue using SQLAlchemy ORM (already protected)
- **Length Limits**: Current 50-character limit is sufficient
- **XSS Prevention**: Basic HTML escaping (already handled by framework)

### Container Security
- **Current Setup**: Existing Docker setup is adequate for development/demo
- **Secrets**: Move database credentials to environment variables
- **Updates**: Occasional base image updates

## Performance Standards

### Reasonable Performance Targets
- **API Response Time**: < 500ms under normal load (more realistic)
- **Page Load**: < 2 seconds initial load
- **Concurrent Users**: Handle 10-20 concurrent users
- **Database**: Basic query performance monitoring

### Resource Usage
- **Memory**: Monitor but no strict limits for development environment
- **Monitoring**: Basic health check endpoint

## Code Quality Standards

### Python (Backend)
- **Style**: Basic PEP 8 compliance (can use IDE formatting)
- **Documentation**: Comments for complex logic
- **Error Handling**: Basic try/catch with meaningful error messages

### JavaScript (Frontend)
- **Style**: Consistent formatting (manual or basic prettier setup)
- **Error Handling**: Basic error display for users

### Docker
- **Current Setup**: Existing Dockerfiles are sufficient
- **Documentation**: Keep README updated with setup instructions

## Development Workflow

### Simple Workflow
- **Version Control**: Feature branches for significant changes
- **Testing**: Run tests before major commits
- **Code Review**: Optional for small team, recommended for major changes
- **Documentation**: Update README when adding new features

## Quality Gates

### Before Major Changes
- Existing functionality still works
- New code follows basic style guidelines
- Manual testing completed for new features

### Basic Production Readiness
- Application starts successfully with docker-compose
- Core functionality works as expected
- Basic error handling in place

This simplified constitution focuses on practical quality standards that can be achieved and maintained by a small team while still improving code quality and reliability.