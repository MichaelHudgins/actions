#!/bin/bash
# Copyright 2025 Google LLC

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     https://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script is a simple check to see if a set of globs matches the files
# in a GitHub PR.  For this to work checkout must fetch-depth to 2. 


# Check if git is installed
if ! command -v git &> /dev/null
then
    echo "git is not installed. Please install git and try again."
    exit 1
fi

# Function to get the changed files between the current and previous commit
get_changed_files() {
  # Use git diff to find files changed between HEAD and HEAD~1
  local changed_files=$(git diff --name-only HEAD~1 HEAD)

  # Handle the case where there are no previous commits.
  if [[ -z "$changed_files" ]]; then
    echo "No previous commit found. Exiting."
    exit 0
  fi
  echo "$changed_files"
}

# Function to filter files by globs
filter_files_by_globs() {
  local files="$1" # Input: list of files, separated by newlines
  local globs=($GLOB_PATTERNS) # Input: list of glob patterns from env. variable

  local matched_files=()
  local match_count=0

  # Check if GLOB_PATTERNS is set
  if [[ -z "$GLOB_PATTERNS" ]]; then
    echo "Error: No GLOB_PATTERNS supplied, you must supply at least one patter if using this script"
    exit 1
  fi

  echo "Matching against globs:"
  for glob in "${globs[@]}"; do
    echo "  $glob"
  done

  # Loop through each file.
  while IFS= read -r file; do
    # Useful for debugging to just print all of these
    echo "File $file was changed"

    # Loop through each glob pattern.
    for glob in "${globs[@]}"; do
      # Use bash's pattern matching.
      if [[ "$file" == "$glob" ]]; then
        matched_files+=("$file")
        ((match_count++))
        # No need to check other globs if one matches.
        break
      fi
    done
  done <<< "$files" # Feed the list of files to the while loop.

  # Output the matched files.
  if [[ ${#matched_files[@]} -gt 0 ]]; then
    echo "Matched files:"
    for matched_file in "${matched_files[@]}"; do
      echo "  $matched_file"
    done
  else
    echo "No files matched the provided globs."
  fi

  # Output the number of matched files
  echo "Total matching files: $match_count"

  # Output to GITHUB_OUTPUT if defined
  if [[ -n "$GITHUB_OUTPUT" && $match_count -gt 0 ]]; then
    # Join the matched files with commas for output
    local output_value=$(IFS=,; echo "${matched_files[*]}")
    echo "files=$output_value" >> "$GITHUB_OUTPUT"
  fi
}

# Main script logic
changed_files=$(get_changed_files)

# Check if any files were changed
if [[ -z "$changed_files" ]]; then
    echo "No files changed between the last two commits."
    exit 0
fi

# Filter the changed files by the provided globs and display the results.
filter_files_by_globs "$changed_files"
