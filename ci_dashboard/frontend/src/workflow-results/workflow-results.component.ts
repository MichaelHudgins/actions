// Copyright 2025 Google LLC

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

//     https://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import { Component } from '@angular/core';
import { Injectable } from '@angular/core';
import * as workflowRunsData from '../../public/workflow_runs.json';
import { CommonModule } from '@angular/common';

// Import Angular Material components
import { MatCardModule } from '@angular/material/card';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';

//Import our own modules and data
import { StatusInfo, WorkflowData } from './workflow-data';
import { WorkflowEntryComponent } from './workflow-entry/workflow-entry.component';

@Injectable({
  providedIn: 'root'
})
@Component({
  selector: 'app-workflow-results',
  imports: [
    CommonModule,
    MatCardModule,
    MatProgressSpinnerModule,
    WorkflowEntryComponent,
  ],
  templateUrl: './workflow-results.component.html',
  styleUrl: './workflow-results.component.scss'
})
export class WorkflowResultsComponent {
  // Load the data at 

  // Key workflows are the ones that should show at the top due to being mointored by build cops
  // These workflows show expanded by default 
  keyWorkflowNames: string[] = [
    'CI',
    'CI - Cloud TPU (nightly)',
    'CoreQL', 'CI - Address Sanitizer (nightly)',
    'CI - Wheel Tests (Continuous)',
    'CI - Wheel Tests (Nightly/Release)',
    'CI - Bazel CPU tests (RBE)',
    'CI - Bazel CUDA tests (RBE)',
  ];
  keyWorkFlowJobs: WorkflowData[] = [];
  otherWorkFlowData: WorkflowData[] = [];
  loading: boolean = true;
  error: any = null;
  displayedColumns: string[] = ['runNumber', 'status', 'conclusion', 'createdAt', 'jobs']; // Add column names

  ngOnInit(): void {
    console.log("Attempting to load json data");
    try {
      // Convert the JSON data into an array of Workflow objects
      Object.entries(workflowRunsData).map(([key, value]) => {
        const workData = value as WorkflowData
        if (workData.runs != null) {
          let wd = value as WorkflowData; // Type assertion to Workflow
          wd.statusInfo = this.statusInfoForWorkflow(wd);
          if (this.keyWorkflowNames.includes(value.workflow_name)) {
            this.keyWorkFlowJobs.push(wd);
          } else {
            this.otherWorkFlowData.push(wd);
          }
        }
      });

      this.loading = false;
      console.log("Data is loaded")
    } catch (err) {
      this.error = err;
      this.loading = false;
    }
  }

  // There are enough cases in which we should skip a workflow that its easier here than html
  shouldShowWorkflow(workData: WorkflowData): boolean {
    if (workData.runs == null) {
      return false
    }
    if (workData.runs.length == 0) {
      return false
    }
    if (workData.runs[0].jobs == null) {
      return false
    }

    // A workflow commited to main that is malformed can create a run record with no jobs
    if (Object.keys(workData.runs[0].jobs).length == 0) {
      return false
    }

    return true
  }

  // Translate the github statuses to how we want to display them
  statusIconForJob(status: string, conclusion: string): string {

    if (status == "completed" && conclusion == "success") {
      return "check_circle"
    }
    if (status == "completed" && conclusion == "failure") {
      return "cancel"
    }
    if (status == "completed" && conclusion == "cancelled") {
      return "block"
    }
    if (status == "completed" && conclusion == "skipped") {
      return "skip_next"
    }
    if (status == "in_progress" || status == "running") {
      return "run_circle"
    }
    if (status == "queued" || status == "pending") {
      return "pending"
    }
    return "unknown_med"
  }

  // Used for css and alt-text
  statusForJob(status: string, conclusion: string): string {

    if (status == "completed" && conclusion == "success") {
      return "success"
    }
    if (status == "completed" && conclusion == "failure") {
      return "failure"
    }
    if (status == "completed" && conclusion == "cancelled") {
      return "cancelled"
    }
    if (status == "completed" && conclusion == "skipped") {
      return "skipped"
    }
    if (status == "in_progress") {
      return "running"
    }
    if (status == "queued" || status == "pending") {
      return "pending"
    }
    return "unknown"
  }

  toggleJobDetails(runData: any): void {
    runData.showJobDetails = !runData.showJobDetails;
  }

  titlesForWorkFlow(workData: WorkflowData): Array<string> {
    let names = Array<string>()
    names.push("Overall")
    if (workData.runs?.length == 0) {
      return names
    }
    const firstRun = workData.runs![0]
    const keys = Object.keys(firstRun.jobs).sort()
    names.push(...keys)
    return names
  }

  makeEmptyStatus(): StatusInfo {
    const jobStatus: StatusInfo = {
      name: "",
      url: "",
      status: "",
      icon: "",
      date: "",
      isTitle: false,
      isEmpty: true,
    }
    return jobStatus
  }

  // Flatten into how we structure columns
  statusInfoForWorkflow(workflowData: WorkflowData): Array<StatusInfo> {
    let statusInfo = Array<StatusInfo>()
    const numberPerRow = 11

    // Grab the names
    let names = Array<string>()

    // Populate the header which is the job level data, while we do that we will also figure out the names for the next rows
    const summary: StatusInfo = {
      name: "Overall",
      url: "", // TODO: we can gather this
      status: "",
      icon: "",
      date: "",
      isTitle: true,
      isEmpty: false,
    }
    statusInfo.push(summary)

    // We reuse this multiple times so pull it out now
    const firstRun = workflowData.runs![0]

    // Note: The api gatherer will omit any result that does not have at least a single run
    for (let i = 0; i < 10; i++) {
      // If there are not enough runs we will need to pad out
      if (workflowData.runs!.length <= i) {
        statusInfo.push(this.makeEmptyStatus())
        continue
      }
      const runData = workflowData.runs![i]
      if (runData == undefined) {
        console.log("Why did this happen")
      }
      // Lets figure out the naming order we expect for all subsequent rows
      if (i == 0) {
        names = Object.keys(runData.jobs).sort()
      }
      const jobStatus: StatusInfo = {
        name: runData.run.name,
        url: runData.run.html_url,
        date: runData.run.updated_at,
        status: this.statusForJob(runData.run.status, runData.run.conclusion),
        icon: this.statusIconForJob(runData.run.status, runData.run.conclusion),
        isTitle: false,
        isEmpty: false,
      }
      statusInfo.push(jobStatus)
    }

    // Now for each job name we will iterate
    names.forEach(name => {
      // Grab row 0 data by looking at the run from the first run
      const job = firstRun.jobs[name]
      const jobStatus: StatusInfo = {
        name: job.name,
        url: job.html_url,
        date: job.completed_at,
        status: "",
        icon: "",
        isTitle: true,
        isEmpty: false,
      }
      statusInfo.push(jobStatus)


      // Now iterate all 10 results
      for (let i = 0; i < 10; i++) {
        // If there are not enough runs we will need to pad out
        if (workflowData.runs!.length <= i) {
          statusInfo.push(this.makeEmptyStatus())
          continue
        }
        const runData = workflowData.runs![i]
        if (runData.run == undefined) {
          console.log("Why did this happen")
        }
        // If we pulled no job data that is typically from a renaming, we omit it here. 
        const jobData = runData.jobs[name]
        if (jobData == undefined) {
          statusInfo.push(this.makeEmptyStatus())
          continue
        }

        const jobStatus: StatusInfo = {
          name: "",
          date: jobData.created_at,
          url: jobData.html_url,
          status: this.statusForJob(jobData.status, jobData.conclusion),
          icon: this.statusIconForJob(jobData.status, jobData.conclusion),
          isTitle: false,
          isEmpty: false,
        }
        statusInfo.push(jobStatus)
      }

    });



    console.log("Attempting to calculate status infos for workflow %s", workflowData.workflow_name)
    return statusInfo
  }
}

