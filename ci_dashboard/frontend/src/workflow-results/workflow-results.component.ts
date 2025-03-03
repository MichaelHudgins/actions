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
import { CommonModule } from '@angular/common';

// Import Angular Material components
import { MatCardModule } from '@angular/material/card';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { WorkflowEntryComponent } from '../workflow-entry/workflow-entry.component';

import { WorkflowService } from '../workflow-data/workflow.service';
import { Observable } from 'rxjs';
import { WorkflowBundle, WorkflowData } from '../workflow-data/workflow-data';

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

  bundle$: Observable<WorkflowBundle>;

  constructor(private workflow_service: WorkflowService) {
    this.bundle$ = workflow_service.getWorklowBundle();
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
}
