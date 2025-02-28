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

import { ComponentFixture, TestBed } from '@angular/core/testing';

import { WorkflowResultsComponent } from './workflow-results.component';

describe('WorkflowResultsComponent', () => {
  let component: WorkflowResultsComponent;
  let fixture: ComponentFixture<WorkflowResultsComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [WorkflowResultsComponent]
    })
    .compileComponents();

    fixture = TestBed.createComponent(WorkflowResultsComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
    expect(component).toBeTruthy();
  });

  it('should load workflows data', () => {
    expect(component.workflows.length).toBeGreaterThan(0);
    component.workflows.forEach((workflow) => {
      expect(workflow.workflow_id).toBeDefined();
      expect(workflow.workflow_name).toBeDefined();
      expect(workflow.last_updated_at).toBeDefined();
      if (workflow.runs) {
      workflow.runs.forEach((run) => {
        expect(run.id).toBeDefined();
        expect(run.name).toBeDefined();
        expect(run.node_id).toBeDefined();
        expect(run.head_commit.message).toBeDefined();
      });
    }
    })
  });

  it('should show loading screen before load data', () => {
        expect(component.loading).toBeTrue();
    });
  it('should show error screen', () => {
      component.error= "Some error";
      expect(component.error).toEqual(jasmine.any(String));
    });
});
