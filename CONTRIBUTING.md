# Contributing

Thank you for your interest in contributing to the **PS-Module-O365EndpointService** project.

Contributions of all kinds are welcome, including bug fixes, new features, documentation improvements, test coverage enhancements, and code refactoring.

## Project Goal

The goal of this project is to provide a reusable PowerShell module for retrieving, processing, and consuming Microsoft 365 endpoint information.

Please keep new contributions aligned with this objective.

---

## Prerequisites

The recommended development environment is:

- PowerShell 7.x or later
- Git
- Visual Studio Code
- Pester
- PSScriptAnalyzer

---

## Setting Up Your Development Environment

Clone the repository:

```powershell
git clone https://github.com/samurai-ka/PS-Module-O365EndpointService.git
cd PS-Module-O365EndpointService
```

Install required development dependencies:

```powershell
Install-Module Pester -Scope CurrentUser
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

---

## Branching Strategy

Please do not develop directly on the `main` branch.

Create a dedicated branch for your work:

```powershell
git checkout -b feature/my-new-feature
```

### Branch Naming Convention

| Type | Example |
|--------|---------|
| Feature | feature/add-ipv6-support |
| Bug Fix | bugfix/fix-endpoint-filter |
| Documentation | docs/update-readme |
| Refactoring | refactor/improve-caching |
| Testing | test/add-parser-tests |

---

## Coding Guidelines

### General Principles

- Follow PowerShell best practices.
- Prefer Advanced Functions.
- Use approved PowerShell verbs.
- Validate all parameters where appropriate.
- Implement proper error handling.
- Write maintainable and readable code.
- Avoid hardcoded values whenever possible.
- Never commit secrets, credentials, or sensitive data.

### Formatting

- Use 4 spaces for indentation.
- Save files using UTF-8 encoding.
- Use meaningful variable names.
- Keep functions focused on a single responsibility.

---

## Documentation Requirements

All public functions should include PowerShell help documentation.

At minimum, provide:

- Synopsis
- Description
- Parameters
- Examples

Example:

```powershell
<#
.SYNOPSIS
Returns Microsoft 365 endpoints.

.DESCRIPTION
Retrieves endpoint information from the Microsoft 365 Endpoint Service.

.PARAMETER ServiceArea
Filters endpoints by Microsoft 365 workload.

.EXAMPLE
Get-O365Endpoint -ServiceArea Exchange
#>
```

Whenever functionality changes, update:

- README.md
- Examples
- Function help
- Any related documentation

---

## Testing

Every contribution should be validated before submitting a Pull Request.

Run all tests:

```powershell
Invoke-Pester
```

Run static code analysis:

```powershell
Invoke-ScriptAnalyzer -Path .
```

Contributors are encouraged to add new tests for:

- New functionality
- Bug fixes
- Edge cases
- Regression scenarios

---

## Pull Request Guidelines

Before opening a Pull Request, ensure that:

- [ ] The solution builds successfully
- [ ] Existing tests pass
- [ ] New tests have been added where appropriate
- [ ] PSScriptAnalyzer reports no issues
- [ ] Documentation has been updated
- [ ] No secrets or credentials are included

### Pull Request Description

Please include:

#### Summary

Describe the change.

#### Motivation

Explain why the change is needed.

#### Testing

Describe how the change was tested.

#### Breaking Changes

Clearly indicate any breaking behavior.

---

## Commit Message Convention

This project follows the Conventional Commits specification.

Examples:

```text
feat: add support for IPv6 endpoints
fix: correct endpoint filtering logic
docs: update installation guide
test: add endpoint parser test coverage
refactor: simplify endpoint cache handling
chore: update development dependencies
```

---

## Reporting Bugs

When reporting issues, please provide:

- PowerShell version
- Operating system
- Module version
- Detailed problem description
- Expected behavior
- Actual behavior
- Reproduction steps
- Error messages or logs

The more information provided, the easier it is to investigate and resolve the issue.

---

## Feature Requests

Suggestions for improvements are welcome.

Please describe:

- The problem being solved
- The proposed solution
- Alternative approaches considered
- Expected benefits
- Example usage scenarios

---

## Security

Please do not report security vulnerabilities through public GitHub Issues.

Instead, contact the project maintainers directly and provide sufficient information for investigation.

---

## Code of Conduct

All contributors are expected to foster a welcoming, professional, and respectful environment.

Please:

- Be respectful
- Be constructive
- Be collaborative
- Assume positive intent
- Focus discussions on technical topics

---

## License

By contributing to this repository, you agree that your contributions may be distributed under the same license as the project.

---

## Recognition

Every contribution, whether code, documentation, testing, design, or feedback, helps improve the project and is greatly appreciated.

Thank you for helping make **PS-Module-O365EndpointService** better for everyone.