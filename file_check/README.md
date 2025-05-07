Basic reuseable script to filter if a job should run based on changes

Usage of this action makes the following assumptions and prerequsites for safe usage

* The base ubutnu actions image is being used to run it
* The repo using this action does not run GH actions on untrusted PRs without prior approval
* Contents and pull_requests:read should be the only permissions given to this workflow
* This only operates on pull_request events 
