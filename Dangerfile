# MARK: - Dangerfile for MeetingAssistant
# Automated PR review checks using Danger-Swift

# Check for PR size
if git.lines_of_code > 500
  warn("This PR is quite large (#{git.lines_of_code} lines). Consider splitting it into smaller PRs for easier review.")
end

# Check for test coverage
if git.modified_files.include?("*.swift") && !git.modified_files.any? { |file| file.include?("Tests") }
  warn("This PR modifies Swift files but doesn't include any test changes. Consider adding tests for new functionality.")
end

# Check for documentation
swift_files_modified = git.modified_files.select { |file| file.end_with?(".swift") }
swift_files_modified.each do |file|
  content = File.read(file)
  if content.include?("public") && !content.include?("///")
    warn("Public types or methods in #{file} should be documented with DocC comments (///).")
  end
end

# Check for force unwraps
swift_files_modified.each do |file|
  content = File.read(file)
  if content.scan(/!\]/).size > 0
    warn("Force unwrapping detected in #{file}. Consider using optional binding or guard statements instead.")
  end
end

# Check for TODO/FIXME comments
swift_files_modified.each do |file|
  content = File.read(file)
  todos = content.scan(/\/\/ (TODO|FIXME|XXX):/i)
  if todos.size > 0
    warn("#{file} contains #{todos.size} TODO/FIXME comment(s). Consider addressing these before merging.")
  end
end

# Check for print statements in production code
swift_files_modified.each do |file|
  next if file.include?("Tests") # Allow prints in tests
  content = File.read(file)
  if content.include?("print(") || content.include?("debugPrint(")
    warn("Print statements detected in #{file}. Consider using proper logging instead.")
  end
end

# Encourage PR descriptions
if github.pr_body.length < 10
  warn("Please provide a detailed PR description explaining the changes and their purpose.")
end

# Check for proper commit messages
git.commits.each do |commit|
  if commit.message.length < 10
    warn("Commit '#{commit.message.strip}' is quite short. Consider providing more context.")
  end
end

# Success message
message("🎉 Thanks for the PR! All automated checks have passed.")