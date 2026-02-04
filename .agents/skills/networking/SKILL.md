---
name: networking
description: This skill should be used when building API clients, modeling networking requests/responses, or configuring URLSession security.
---

# Networking Standards

## Overview

Best practices for reliable and secure network communication in the Meeting Assistant project.

## 1. Implementation

- **URLSession**: Use native `URLSession` as the primary networking engine.
- **Timeouts**: Configure realistic timeouts (typically 15-30 seconds).
- **JSON Modeling**: Use `Codable` for request and response structures. Avoid generic dictionaries.

## 2. Reliability & Resiliency

- **Retry Logic**: Implement retry strategies for transient failures (e.g., 5xx status codes or timeouts).
- **Validation**: Always validate HTTP status codes and response headers before processing the body.
- **Reachability**: Handle offline states gracefully and provide UI feedback.

## 3. Security

- **HTTPS**: Enforce HTTPS for all production communication. App Transport Security (ATS) must remain enabled.
- **Certificate Pinning**: Consider pinning certificates for sensitive backend communication if required by security policy.
- **Secrets**: Never hardcode API keys. Use environmental variables or secure local storage.
