---
name: security
description: This skill should be used when the user asks to "improve security posture", "validate untrusted input", "protect sensitive data", or "apply platform security controls".
---

# Security Best Practices

## Overview

Core requirements for user data privacy and application integrity.

## Scope Boundaries

- Use this skill for baseline threat modeling and secure-by-default controls.
- Use `../keychain-security/SKILL.md` for credential persistence implementation.
- Use `../networking/SKILL.md` for transport and API client hardening.

## 1. Secret Management

- **No Hardcoding**: Never commit API keys, tokens, or passwords.
- **Secure Storage**: Use Keychain and approved configuration boundaries.
- **Least Exposure**: Avoid logging or displaying sensitive values.

## 2. Data Validation

- **Input Sanitization**: Validate external input at module boundaries.
- **Type Safety**: Use strongly typed models and explicit validation rules.
- **Fail Closed**: Reject invalid data explicitly instead of permissive fallback.

## 3. Platform Security

- **Biometrics**: Use `LocalAuthentication` where sensitive actions require user presence.
- **Transport Security**: Keep ATS enabled and enforce HTTPS.
- **Permissions**: Request minimum required capabilities with clear rationale.
