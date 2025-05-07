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


# Script to check if provided file patterns match any files
# changed in the current GitHub Pull Request.

# It is not reccomended to use this script outside of repos managed by ML Infra
# See the readme.md for assumptions for security and usage 

# Required environment variables these should normally be supplied by the actions environement:
#   GITHUB_REPOSITORY: The owner and repository name (e.g., "owner/repo").
#   GITHUB_PULL_REQUEST_NUMBER: The number of the pull request.
#   GITHUB_TOKEN: (Optional but recommended) A GitHub token for authentication.

# Check for required commands
if ! command -v curl &> /dev/null; then
    echo "Error: curl command not found. Curl is required in the base image for this action."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq command not found. jq is required in the base image for this action."
    exit 1
fi

# Check for required GitHub environment variables
if [ -z "$GITHUB_REPOSITORY" ]; then
  echo "Error: GITHUB_REPOSITORY environment variable is not set."
  echo "Please set it to your repository (e.g., 'owner/repo')."
  exit 1
fi

if [ -z "$GITHUB_PULL_REQUEST_NUMBER" ]; then
  echo "Error: GITHUB_PULL_REQUEST_NUMBER environment variable is not set."
  echo "Please set it to the pull request number."
  exit 1
fi

# GITHUB_TOKEN is optional but recommended for private repos or to avoid rate limits
if [ -z "$GITHUB_TOKEN" ]; then
  echo "Warning: GITHUB_TOKEN environment variable is not set."
  echo "API requests will be unauthenticated and may be rate-limited or fail for private repositories."
  # Script will proceed without a token if not set.
fi


echo "Patterns to match against $FILE_PATTERNS"

# Construct GitHub API URL
OWNER_REPO="$GITHUB_REPOSITORY"
PR_NUMBER="$GITHUB_PULL_REQUEST_NUMBER"
API_URL="https://api.github.com/repos/${OWNER_REPO}/pulls/${PR_NUMBER}/files"

echo "Fetching changed files for PR #$PR_NUMBER in repository $OWNER_REPO..."

# Prepare curl command arguments
curl_args=("-s" "-L") # -s for silent, -L to follow redirects
curl_args+=("-H" "Accept: application/vnd.github.v3+json")

if [ -n "$GITHUB_TOKEN" ]; then
  curl_args+=("-H" "Authorization: Bearer $GITHUB_TOKEN")
fi

# Append URL to arguments
curl_args+=("$API_URL")

# Fetch changed files from GitHub API
# -w "%{http_code}" appends the HTTP status code to the output
# Store curl output (body + http_code) in a variable
raw_curl_output=$(curl "${curl_args[@]}" -w "\n%{http_code}")
curl_exit_status=$?

if [ $curl_exit_status -ne 0 ]; then
    echo "Error: curl command failed with exit status $curl_exit_status."
    exit 1
fi

# Extract HTTP status code (last line of raw_curl_output)
http_code=$(echo "$raw_curl_output" | tail -n1)
# Extract JSON body (everything except the last line)
json_body=$(echo "$raw_curl_output" | sed '$d')

if [ "$http_code" -ne 200 ]; then
    echo "Error: GitHub API request failed with HTTP status $http_code."
    echo "Response body: $json_body"
    exit 1
fi

python3 -m pip freeze

# Parse the JSON response to get a list of filenames
# Use set -o pipefail to ensure errors in the pipeline are caught
# jq -r '.[]?.filename // empty' extracts filenames, handles nulls gracefully, and outputs raw strings.
# If the PR has no files, .[] will be empty, and jq will produce no output and exit 0.
set -o pipefail
CHANGED_FILES_LIST=$(echo "$json_body" | jq -r '.[]?.filename // empty')
jq_exit_status=$?
set +o pipefail # Important to reset pipefail

if [ $jq_exit_status -ne 0 ]; then
    echo "Error: jq failed to parse GitHub API response. Exit status: $jq_exit_status"
    echo "JSON Body was: $json_body"
    exit 1
fi

if [ -z "$CHANGED_FILES_LIST" ]; then
  echo "No files found changed in PR #$PR_NUMBER or an issue occurred retrieving them."
fi

echo "Files modified by PR: $CHANGED_FILES_LIST"

echo "----------------------------------------------------"
echo "Processing patterns against changed files in PR #$PR_NUMBER:"
echo "----------------------------------------------------"

# Iterate over each pattern provided as a command-line argument
# "$@" expands to all positional parameters as separate words.
at_least_one_match_found=false

for pattern in "$@"; do
  echo "Checking pattern $pattern"
  found_match_for_current_pattern=false # Reset flag for each new pattern

  # Read the list of changed files line by line (from the string variable)
  # IFS= prevents leading/trailing whitespace from being trimmed from lines.
  # -r prevents backslash escapes from being interpreted.
  # The `|| [ -n "$filepath" ]` ensures that the last line is processed
  # even if it doesn't end with a newline character.
  # <<< "$CHANGED_FILES_LIST" is a "here string", feeding the variable's content to the loop.
  while IFS= read -r filepath || [ -n "$filepath" ]; do
    # Skip empty lines that might result from jq processing if any filename was problematic
    # (though `// empty` should prevent this for .filename)
    if [ -z "$filepath" ]; then
      continue
    fi

    # Perform glob pattern matching.
    # In bash's [[ ... ]] construct, if the right-hand side of == or !=
    # is an unquoted string, it's treated as a pattern (glob).
    if [[ "$filepath" == $pattern ]]; then
      found_match_for_current_pattern=true
      at_least_one_match_found=true
      echo "Changed file $filepath matches pattern $pattern"
    fi
  done <<< "$CHANGED_FILES_LIST" # Feed the list of changed files to the while loop

  # Report the result for the current pattern
  if [ "$found_match_for_current_pattern" = true ]; then
    echo "Pattern '$pattern': Found a matching file in the PR."
  else
    echo "Pattern '$pattern': No matching file found in the PR."
  fi
done

# Echo final status out
echo "Pattern was matched: $at_least_one_match_found"

if [ -n "$GITHUB_ENV" ]; then
    # Store to the github env that at least one match was found
    echo "patten_matched=$at_least_one_match_found" >> $GITHUB_ENV
fi

# Exit with success code
exit 0
