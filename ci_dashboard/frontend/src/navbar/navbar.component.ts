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

import { Component, input } from '@angular/core';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatButtonModule } from '@angular/material/button';
import { CommonModule, DatePipe } from '@angular/common';

import { WorkflowService } from '../workflow-data/workflow.service';
import { Observable } from 'rxjs';
import { WorkflowBundle} from '../workflow-data/workflow-data';

@Component({
  selector: 'app-navbar',
  imports: [
    CommonModule,
    MatToolbarModule,
    MatButtonModule,
    DatePipe,
  ],
  templateUrl: './navbar.component.html',
  styleUrl: './navbar.component.scss'
})
export class NavbarComponent {
  bundle$: Observable<WorkflowBundle>;
  constructor(private workflow_service: WorkflowService) {
    this.bundle$ = workflow_service.getWorklowBundle();
  }
}
