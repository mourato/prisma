import Danger
import Foundation

// MARK: - Dangerfile for MeetingAssistant

// Automated PR review checks using Danger-Swift

let danger = Danger()

// Utility to check if a file is a Swift source file (excluding generated mocks)
let swiftFiles = (danger.git.modifiedFiles + danger.git.createdFiles).filter {
    $0.hasSuffix(".swift") && !$0.contains("GeneratedMocks.swift")
}

// 1. Check for PR size
let additions = danger.github?.pr.additions ?? 0
if additions > 500 {
    warn("This PR is quite large (\(additions) additions). Consider splitting it into smaller PRs for easier review.")
}

// 2. Check for test coverage
let hasTestChanges = (danger.git.modifiedFiles + danger.git.createdFiles).contains(where: { $0.contains("Tests") })
if !swiftFiles.isEmpty, !hasTestChanges {
    warn("This PR modifies Swift files but doesn't include any test changes. Consider adding tests for new functionality.")
}

// 3. Documentation for public APIs
for file in swiftFiles {
    let content = danger.utils.readFile(file)
    if content.contains("public "), !content.contains("///") {
        warn("Public types or methods in `\(file)` should be documented with DocC comments (///).")
    }
}

// 4. Check for force unwraps (excluding Tests and Mocks)
for file in swiftFiles {
    guard !file.contains("Tests") else { continue }
    let content = danger.utils.readFile(file)
    // Basic regex for force unwrap (e.g., value!, but not !=, !{, etc)
    if content.range(of: #"[a-zA-Z0-9)]!"#, options: .regularExpression) != nil {
        warn("Force unwrapping detected in `\(file)`. Consider using optional binding or guard statements instead.")
    }
}

// 5. Check for TODO/FIXME comments
for file in swiftFiles {
    let content = danger.utils.readFile(file)
    if content.localizedCaseInsensitiveContains("TODO:") || content.localizedCaseInsensitiveContains("FIXME:") {
        warn("`\(file)` contains TODO/FIXME comments. Consider addressing these before merging.")
    }
}

// 6. Check for print statements in production code
for file in swiftFiles {
    guard !file.contains("Tests") else { continue }
    let content = danger.utils.readFile(file)
    if content.contains("print(") || content.contains("debugPrint(") {
        warn("Print statements detected in `\(file)`. Consider using proper logging with `Logger` or `OSLog` instead.")
    }
}

// 7. Encourage PR descriptions (GitHub only)
if let body = danger.github?.pr.body, body.count < 10 {
    warn("Please provide a detailed PR description explaining the changes and their purpose.")
}

// 8. Check for proper commit messages
for commit in danger.git.commits {
    if commit.message.count < 10 {
        warn("Commit message '\(commit.message.trimmingCharacters(in: .whitespacesAndNewlines))' is too short. Consider providing more context.")
    }
}

// Success message
message("🎉 Thanks for the PR! All automated checks have been processed.")
