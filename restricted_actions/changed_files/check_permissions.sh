#!/bin/bash

# Script to check if a GitHub token has only 'contents:read' permission
# based on the X-OAuth-Scopes header returned by the GitHub API.

# This script aims to provide an answer based on the explicit scopes reported
# in the 'X-OAuth-Scopes' HTTP header.

# Expected scope we are checking for
EXPECTED_SCOPE="contents:read"

# Make a request to a simple GitHub API endpoint.
# Using /zen as it's lightweight and should return auth-related headers
# Capture stderr to check curl command output for errors, but don't print it directly unless necessary
API_RESPONSE_HEADERS=$(curl -s -I -H "Authorization: token $GITHUB_TOKEN" https://api.github.com 2>&1)
CURL_EXIT_CODE=$?

echo "$API_RESPONSE_HEADERS"

# Check if curl command itself failed (e.g., network issue, DNS resolution)
if [ $CURL_EXIT_CODE -ne 0 ]; then
  echo "Error: curl command failed. Could not connect to GitHub API. (curl exit code: $CURL_EXIT_CODE)" >&2
  # Avoid printing API_RESPONSE_HEADERS here as it might contain sensitive curl error details or the token.
  exit 2 # Connection/curl error
fi

# Extract HTTP status code from the response headers
HTTP_STATUS_LINE=$(echo "$API_RESPONSE_HEADERS" | grep -i "^HTTP/")
HTTP_STATUS=$(echo "$HTTP_STATUS_LINE" | awk '{print $2}')

# Validate HTTP status
if [ -z "$HTTP_STATUS" ]; then
    echo "Error: Could not retrieve HTTP status from GitHub API response." >&2
    exit 3 # API communication error
fi

# If token is invalid or expired, GitHub returns 401 Unauthorized (shouldn't happen in an action)
if [ "$HTTP_STATUS" == "401" ]; then
  echo "Error: GitHub API returned status $HTTP_STATUS. Token is likely invalid, expired, or revoked." >&2
  exit 4 # Authentication error
fi

# Other non-200 statuses for /zen might indicate other issues (e.g. GitHub rate limiting, server errors)
# Though /zen itself is generally robust.
if [ "$HTTP_STATUS" != "200" ]; then
    echo "Error: GitHub API returned non-200 status $HTTP_STATUS for /zen endpoint." >&2
    # echo "Debug: API Response Headers:" >&2
    # echo "$API_RESPONSE_HEADERS" >&2
    exit 5 # Unexpected API status
fi

# Extract the X-OAuth-Scopes header (case-insensitive search for the header name)
OAUTH_SCOPES_LINE=$(echo "$API_RESPONSE_HEADERS" | grep -i "^X-OAuth-Scopes:")

# Check if the X-OAuth-Scopes header was found
if [ -z "$OAUTH_SCOPES_LINE" ]; then
  # This can happen if the token is not a type that uses OAuth scopes,
  # or if the token has no scopes assigned in a way that populates this header.
  if echo "$API_RESPONSE_HEADERS" | grep -qi "WWW-Authenticate:"; then
      echo "Error: Token authentication may have failed or was not processed as an OAuth token by GitHub." >&2
      echo "The X-OAuth-Scopes header was missing, and a WWW-Authenticate header was present." >&2
  else
      echo "Error: No X-OAuth-Scopes header found in the API response." >&2
      echo "The token might be of an unsupported type for this check, or it genuinely has no OAuth scopes reported." >&2
  fi
  exit 6 # Missing scopes header
fi

# Extract the value part of the scopes header.
# sed: remove "X-OAuth-Scopes: " (case-insensitive) and leading spaces from value.
# tr: remove potential carriage returns.
# xargs: trim leading/trailing whitespace from the final string.
ACTUAL_SCOPES_STRING=$(echo "$OAUTH_SCOPES_LINE" | sed -E 's/^[Xx]-[Oo][Aa]uth-[Ss]copes:[[:space:]]*//i' | tr -d '\r' | xargs)

# No permissions is a valid case
if [ -z "$ACTUAL_SCOPES_STRING" ] || [ "$ACTUAL_SCOPES_STRING" == "(no scope)" ]; then
  echo "Token does not have any permissions"
  exit 0 
fi

# Parse the potentially comma-separated scopes into an array.
# Each scope in the array will be trimmed of leading/trailing whitespace.
IFS=',' read -r -a SCOPES_ARRAY <<< "$ACTUAL_SCOPES_STRING"
declare -a CLEANED_SCOPES
NUM_EFFECTIVE_SCOPES=0

for scope_item in "${SCOPES_ARRAY[@]}"; do
  # Trim whitespace from individual scope_item using xargs
  trimmed_item=$(echo "$scope_item" | xargs)
  if [ -n "$trimmed_item" ]; then # Ensure it's not an empty string after trim (e.g. due to "scope1, , scope2")
    CLEANED_SCOPES+=("$trimmed_item")
    ((NUM_EFFECTIVE_SCOPES++))
  fi
done

# Now, check if the token has *exactly one* scope, and if that scope is the expected one.
if [ "$NUM_EFFECTIVE_SCOPES" -eq 1 ] && [ "${CLEANED_SCOPES[0]}" == "$EXPECTED_SCOPE" ]; then
  echo "Token has only '$EXPECTED_SCOPE' permission."
  exit 0 # Success
else
  echo "Token does not have only '$EXPECTED_SCOPE' permission." >&2
  echo "Detected scopes: $ACTUAL_SCOPES_STRING" >&2
  # Optional: Print parsed scopes for debugging
  echo "Parsed effective scopes ($NUM_EFFECTIVE_SCOPES):" >&2
  for s_debug in "${CLEANED_SCOPES[@]}"; do echo "- '$s_debug'" >&2; done
  exit 1 # Negative result (does not have the permission)
fi