---
name: networking
description: This skill should be used when the user asks to "build API client", "model request/response", "configure URLSession", or "improve network resiliency/security".
---

# Networking Standards

## Role

Use this skill as the canonical owner for transport, request modeling, and network resiliency guidance in Prisma.

- Own URLSession usage patterns, request/response contracts, retries, and offline/error handling expectations.
- Keep networking guidance separate from credential persistence and broad security policy.
- Delegate secrets and security-baseline decisions to the relevant specialist owners.

## When to Use

Use this skill when the user asks to build an API client, model request/response data, configure URLSession, or improve network resiliency/security.

## Overview

Best practices for reliable, secure network communication in this project.

## Scope Boundaries

- Use this skill for transport configuration, request/response modeling, retries, and resiliency.
- Use `../security/SKILL.md` for cross-cutting security posture and threat model decisions.
- Use `../keychain-security/SKILL.md` when API credentials must be persisted locally.

## 1. Implementation

- **URLSession**: Use `URLSession` as the default networking engine.
- **Timeouts**: Configure realistic per-endpoint timeouts.
- **Typed Models**: Use `Codable` request/response models.

## 2. Reliability & Resiliency

- **Retry Logic**: Retry only transient failures with bounded policy.
- **Validation**: Validate status codes and headers before decoding.
- **Offline Handling**: Model offline/timeout states explicitly for the UI layer.

## 3. Security

- **HTTPS**: Require HTTPS and keep ATS constraints active.
- **Pinning**: Use certificate pinning only when policy requires it.
- **Secrets**: Never hardcode credentials.

## Related Skills

- `../security/SKILL.md`
- `../keychain-security/SKILL.md`

## References

- `../security/SKILL.md`
- `../keychain-security/SKILL.md`
