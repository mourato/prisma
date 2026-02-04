---
name: security
description: This skill should be used when implementing security measures, secret management, data validation, or platform security like biometrics.
---

# Security Best Practices

## Overview

Core requirements for ensuring user data privacy and application integrity.

## 1. Secret Management

- **No Hardcoding**: Never store API keys, tokens, or passwords in the source code.
- **Secure Storage**: Use variables of environment, configuration files (appropriately ignored by Git), or secure servers.
- **Keychain**: Always use the system Keychain for local storage of sensitive credentials.

## 2. Data Validation

- **Input Sanitization**: Validate all user input and data received from external sources (APIs, files).
- **Type Safety**: Leverage the Swift type system to enforce valid data states and prevent injection or corruption.

## 3. Platform Security

- **Biometrics**: Use `LocalAuthentication` for protecting access to sensitive features or data.
- **Transport Security**: Maintain App Transport Security (ATS) settings to require HTTPS for all network communication.
- **Permissions**: Request only the minimum necessary system permissions (e.g., Microphone, Accessibility) and explain the usage to the user.
