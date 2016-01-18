<#############################################################################
The ScsmPx module facilitates automation with Microsoft System Center Service
Manager by auto-loading the native modules that are included as part of that
product and enabling automatic discovery of the commands that are contained
within the native modules. It also includes dozens of complementary commands
that are not available out of the box to allow you to do much more with your
PowerShell automation efforts using the platform.

Copyright 2016 Provance Technologies.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
#############################################################################>

try {
    #region Initialize the module.

    Invoke-Snippet -Name Module.Initialize

    #endregion

    #region Initialize the SCSM environment.

    # This must be done before we try to import the function files, because it will make sure that
    # the appropriate .NET binaries are loaded in the current session first
    . $PSModuleRoot\scripts\Initialize-NativeScsmEnvironment.ps1

    #endregion

    #region Import helper (private) function definitions.

    Invoke-Snippet -Name ScriptFile.Import -Parameters @{
        Path = Join-Path -Path $PSModuleRoot -ChildPath helpers
    }

    #endregion

    #region Import public function definitions.

    Invoke-Snippet -Name ScriptFile.Import -Parameters @{
        Path = Join-Path -Path $PSModuleRoot -ChildPath functions
    }

    #endregion

    #region Fix the Get-SCSMCommand command.

    # This is necessary to work around a bug in PowerShell's Get-Command cmdlet. When you invoke
    # the Get-Command cmdlet from within a script module, and request that it return the commands in
    # that module, it will not return any commands that belong to nested modules that are loaded by
    # the script module. The workaround is to explicitly include the nested module names in the list
    # of modules from which you want to return commands. In addition, we add the data warehouse
    # module to this so that we get all commands loaded by both of these modules.
    if (Test-Path -LiteralPath function:Get-SCSMCommand) {
        Set-Item function:Get-SCSMCommand -Value (
            # This script block _must_ be defined within the System.Center.Service.Manager module if
            # we want the command to still belong to that module and if we want the command to also
            # unload when that module is unloaded.
            & (Get-Module -Name System.Center.Service.Manager) {
                {Get-Command -Module System.Center.Service.Manager,Microsoft.EnterpriseManagement.Core.Cmdlets,Microsoft.EnterpriseManagement.ServiceManager.Cmdlets,Microsoft.EnterpriseManagement.Warehouse.Cmdlets}
            }
        )
    }

    #endregion

    #region Add a custom ToString method to the ManagementPackEnumeration type.

    Update-TypeData -TypeName Microsoft.EnterpriseManagement.Configuration.ManagementPackEnumeration -MemberName ToString -MemberType ScriptMethod -Value {$this.DisplayName} -Force

    #endregion

    #region Add a Name parameter to the Workflow type.

    Update-TypeData -TypeName Microsoft.EnterpriseManagement.ServiceManager.Sdk.Workflows.Workflow -MemberName Name -MemberType ScriptProperty -Value {$this.WorkflowSubscription.Name} -Force

    #endregion

    #region Define proxy functions for classes and views.

    # These views will be exposed through the View parameter of a Get-ScsmPx* command.
    $viewMap = @{
        'System.WorkItem.Incident' = @{
                         Active = 'System.WorkItem.Incident.Active.View'
                      ActiveDcm = 'System.WorkItem.Incident.DCM.View'
                    ActiveEmail = 'System.WorkItem.Incident.Email.View'
                 ActiveExtended = 'System.WorkItem.Incident.ActiveExtended.View'
                   ActiveParent = 'System.WorkItem.Incident.Parent.View'
                   ActivePortal = 'System.WorkItem.Incident.Portal.View'
                     ActiveScom = 'System.WorkItem.Incident.SCOM.View'
                    ActiveTier1 = 'System.WorkItem.Incident.Queue.Tier1.View'
                    ActiveTier2 = 'System.WorkItem.Incident.Queue.Tier2.View'
                    ActiveTier3 = 'System.WorkItem.Incident.Queue.Tier3.View'
                            All = 'System.WorkItem.Incident.AllIncidents.View'
                   AssignedToMe = 'System.WorkItem.Incident.AssignedToMe.View'
            AssignedToMeSlaInfo = 'System.WorkItem.Incident.AssignedToMeSLAInfo.View'
                      Escalated = 'System.WorkItem.Incident.Escalated.View'
                        OverDue = 'System.WorkItem.Incident.OverDue.View'
                        Pending = 'System.WorkItem.Incident.Pending.View'
                    SlaBreached = 'System.WorkItem.Incident.SLABreached.View'
                     SlaWarning = 'System.WorkItem.Incident.SLAWarning.View'
                     Unassigned = 'System.WorkItem.Incident.Active.Unassigned.View'
                UnassignedTier1 = 'System.WorkItem.Incident.Queue.Tier1.Unassigned.View'
                UnassignedTier2 = 'System.WorkItem.Incident.Queue.Tier2.Unassigned.View'
                UnassignedTier3 = 'System.WorkItem.Incident.Queue.Tier3.Unassigned.View'
        }
        'System.Build' = @{
            All = 'AllBuildCIsView'
        }
        'Microsoft.Windows.Computer' = @{
                                    All = 'AllComputersView'
            AllWithActiveChangeRequests = 'AllComputersViewWithActiveChangeRequests'
                 AllWithActiveIncidents = 'AllComputersViewWithActiveIncidents'
        }
        'System.Environment' = @{
            All = 'AllEnvironmentCIsView'
        }
        'Microsoft.AD.Printer' = @{
            All = 'AllPrintersView'
        }
        'System.SoftwareItem' = @{
                                    All = 'AllSoftwaresView'
            AllWithActiveChangeRequests = 'AllSoftwaresViewWithActiveChangeRequests'
                 AllWithActiveIncidents = 'AllSoftwaresViewWithActiveIncidents'
        }
        'System.SoftwareUpdate' = @{
                                    All = 'AllSoftwareUpdatesView'
            AllWithActiveChangeRequests = 'AllSoftwareUpdatesWithActiveChangeRequestsView'
                 AllWithActiveIncidents = 'AllSoftwareUpdatesWithActiveIncidentsView'
        }
        'System.WorkItem.ChangeRequest' = @{
                     All = 'ChangeManagement.Views.AllChangeRequests'
            AssignedToMe = 'ChangeManagement.Views.ChangeRequestsAssignedToMe'
               Cancelled = 'ChangeManagement.Views.ChangeRequestsCancelled'
                  Closed = 'ChangeManagement.Views.ChangeRequestsClosed'
               Completed = 'ChangeManagement.Views.ChangeRequestsCompleted'
                  Failed = 'ChangeManagement.Views.ChangeRequestsFailed'
                InReview = 'ChangeManagement.Views.ChangeRequestsInReview'
              InProgress = 'ChangeManagement.Views.ChangeRequestsManualActivityInProgress'
                  OnHold = 'ChangeManagement.Views.ChangeRequestsOnHold'
                Rejected = 'ChangeManagement.Views.ChangeRequestsRejected'
        }
        'System.WorkItem.ReleaseRecord' = @{
                     All = 'ReleaseManagement.Views.AllReleaseRecords'
                   Child = 'ReleaseManagement.Views.ChildReleaseRecords'
            AssignedToMe = 'ReleaseManagement.Views.ReleaseRecordsAssignedToMe'
               Cancelled = 'ReleaseManagement.Views.ReleaseRecordsCanceled'
                  Closed = 'ReleaseManagement.Views.ReleaseRecordsClosed'
               Completed = 'ReleaseManagement.Views.ReleaseRecordsCompleted'
               InEditing = 'ReleaseManagement.Views.ReleaseRecordsEditing'
                  Failed = 'ReleaseManagement.Views.ReleaseRecordsFailed'
              InProgress = 'ReleaseManagement.Views.ReleaseRecordsInProgress'
                  OnHold = 'ReleaseManagement.Views.ReleaseRecordsOnHold'
        }
        'System.Domain.User' = @{
            All = 'ServiceManager.ConfigurationManagement.Library.View.User'
        }
        'System.WorkItem.Problem' = @{
            ActiveKnownError = 'ServiceManager.ProblemManagement.Configuration.View.ActiveKnownErrors'
                      Active = 'ServiceManager.ProblemManagement.Configuration.View.ActiveProblem'
                AssignedToMe = 'ServiceManager.ProblemManagement.Configuration.View.AssignedToMe'
                      Closed = 'ServiceManager.ProblemManagement.Configuration.View.Closed'
               NeedingReview = 'ServiceManager.ProblemManagement.Configuration.View.NeedingReview'
                    Resolved = 'ServiceManager.ProblemManagement.Configuration.View.Resolved'
        }
        'System.RequestOffering' = @{
                    All = 'ServiceManager.RequestOffering.Library.View.AllOfferings'
                  Draft = 'ServiceManager.RequestOffering.Library.View.AllDraftOfferings'
              Published = 'ServiceManager.RequestOffering.Library.View.AllPublishedOfferings'
             Standalone = 'ServiceManager.RequestOffering.Library.View.AllStandaloneOfferings'
        }
        'Microsoft.SystemCenter.Orchestrator.RunbookItem' = @{
            All = 'ServiceManager.Runbook.Configuration.View'
        }
        'System.ServiceOffering' = @{
                  All = 'ServiceManager.ServiceOffering.Library.View.AllOfferings'
                Draft = 'ServiceManager.ServiceOffering.Library.View.AllDraftOfferings'
            Published = 'ServiceManager.ServiceOffering.Library.View.AllPublishedOfferings'
        }
        'System.WorkItem.ServiceRequest' = @{
                            Open = 'ServiceManager.ServiceRequest.Library.View.AllOpen'
                    AssignedToMe = 'ServiceManager.ServiceRequest.Library.View.AssignedToMe'
                       Cancelled = 'ServiceManager.ServiceRequest.Library.View.Canceled'
                          Closed = 'ServiceManager.ServiceRequest.Library.View.Closed'
                       Completed = 'ServiceManager.ServiceRequest.Library.View.Completed'
                          Failed = 'ServiceManager.ServiceRequest.Library.View.Failed'
            ServiceLevelBreached = 'ServiceManager.ServiceRequest.Library.View.SLABreached'
             ServiceLevelWarning = 'ServiceManager.ServiceRequest.Library.View.SLAWarning'
        }
        'System.Knowledge.Article' = @{
                  All = 'KnowledgeView'
             Archived = 'ArchivedKnowledgeArticle'
                Draft = 'DraftKnowledgeArticle'
            Published = 'PublishedKnowledgeArticle'
        }
        'Microsoft.SystemCenter.Orchestrator.RunbookAutomationActivity' = @{
                              All = 'ServiceManager.RunbookActivity.Configuration.View.RunbookAutomationActivities.All'
                       InProgress = 'ServiceManager.RunbookActivity.Configuration.View.RunbookAutomationActivitiesActive'
            AssignedToMeOrMyGroup = 'ServiceManager.RunbookActivity.Configuration.View.RunbookAutomationActivitiesAssignedToMe'
                        Cancelled = 'ServiceManager.RunbookActivity.Configuration.View.RunbookAutomationActivitiesCancelled'
                        Completed = 'ServiceManager.RunbookActivity.Configuration.View.RunbookAutomationActivitiesCompleted'
                           Failed = 'ServiceManager.RunbookActivity.Configuration.View.RunbookAutomationActivitiesFailed'
                       Unassigned = 'ServiceManager.RunbookActivity.Configuration.View.RunbookAutomationActivitiesUnassigned'
        }
        'System.WorkItem.Activity.DependentActivity' = @{
                              All = 'ActivityManagement.Views.AllDependentActivities'
                       InProgress = 'ActivityManagement.Views.DependentActivitiesActive'
            AssignedToMeOrMyGroup = 'ActivityManagement.Views.DependentActivitiesAssignedToMe'
                        Cancelled = 'ActivityManagement.Views.DependentActivitiesCancelled'
                        Completed = 'ActivityManagement.Views.DependentActivitiesCompleted'
                           Failed = 'ActivityManagement.Views.DependentActivitiesFailed'
                       Unassigned = 'ActivityManagement.Views.DependentActivitiesUnassigned'
        }
        'System.WorkItem.Activity.ManualActivity' = @{
                     All = 'ActivityManagement.Views.AllManualActivities'
              InProgress = 'ActivityManagement.Views.ManualActivitiesActive'
            AssignedToMe = 'ActivityManagement.Views.ManualActivitiesAssignedToMe'
               Cancelled = 'ActivityManagement.Views.ManualActivitiesCancelled'
               Completed = 'ActivityManagement.Views.ManualActivitiesCompleted'
                  Failed = 'ActivityManagement.Views.ManualActivitiesFailed'
              Unassigned = 'ActivityManagement.Views.ManualActivitiesUnassigned'
        }
        'System.WorkItem.Activity.ParallelActivity' = @{
                              All = 'ActivityManagement.Views.AllParallelActivities'
                       InProgress = 'ActivityManagement.Views.ParallelActivitiesActive'
            AssignedToMeOrMyGroup = 'ActivityManagement.Views.ParallelActivitiesAssignedToMe'
                        Cancelled = 'ActivityManagement.Views.ParallelActivitiesCancelled'
                        Completed = 'ActivityManagement.Views.ParallelActivitiesCompleted'
                           Failed = 'ActivityManagement.Views.ParallelActivitiesFailed'
                       Unassigned = 'ActivityManagement.Views.ParallelActivitiesUnassigned'
        }
        'System.WorkItem.Activity.ReviewActivity' = @{
                     All = 'ActivityManagement.Views.AllReviewActivities'
              InProgress = 'ActivityManagement.Views.ReviewActivitiesActive'
                Approved = 'ActivityManagement.Views.ReviewActivitiesApproved'
            AssignedToMe = 'ActivityManagement.Views.ReviewActivitiesAssignedToMe'
               Cancelled = 'ActivityManagement.Views.ReviewActivitiesCancelled'
                Rejected = 'ActivityManagement.Views.ReviewActivitiesRejected'
        }
        'System.WorkItem.Activity.SequentialActivity' = @{
                              All = 'ActivityManagement.Views.AllSequentialActivities'
                       InProgress = 'ActivityManagement.Views.SequentialActivitiesActive'
            AssignedToMeOrMyGroup = 'ActivityManagement.Views.SequentialActivitiesAssignedToMe'
                        Cancelled = 'ActivityManagement.Views.SequentialActivitiesCancelled'
                        Completed = 'ActivityManagement.Views.SequentialActivitiesCompleted'
                           Failed = 'ActivityManagement.Views.SequentialActivitiesFailed'
                       Unassigned = 'ActivityManagement.Views.SequentialActivitiesUnassigned'
        }
    }

    # Only config items get the Restore capability
    $nounMap = @{
                   AdGroup = @{ Verbs = 'Get','Set','Rename','Remove','Restore'; Class = 'Microsoft.AD.Group'                                           ; ConfigItem = $true  }
                 AdPrinter = @{ Verbs = 'Get','Set','Rename','Remove','Restore'; Class = 'Microsoft.AD.Printer'                                         ; ConfigItem = $true  }
                    AdUser = @{ Verbs = 'Get','Set','Rename','Remove','Restore'; Class = 'Microsoft.AD.User'                                            ; ConfigItem = $true  }
                     Build = @{ Verbs = 'Get','Set','Rename','Remove','Restore'; Class = 'System.Build'                                                 ; ConfigItem = $true  }
           BusinessService = @{ Verbs = 'Get','Set','Rename','Remove','Restore'; Class = 'Microsoft.SystemCenter.BusinessService'                       ; ConfigItem = $true  }
             ChangeRequest = @{ Verbs = 'Get','Set','Rename','Remove'          ; Class = 'System.WorkItem.ChangeRequest'                                ; ConfigItem = $false }
                ConfigItem = @{ Verbs = 'Get','Set','Rename','Remove','Restore'; Class = 'System.ConfigItem'                                            ; ConfigItem = $true  }
                    DwCube = @{ Verbs = 'Get','Set','Rename','Remove'          ; Class = 'Microsoft.SystemCenter.Warehouse.SystemCenterCube'            ; ConfigItem = $false }
              DwDataSource = @{ Verbs = 'Get','Set','Rename','Remove'          ; Class = 'Microsoft.SystemCenter.DataWarehouse.DataSource'              ; ConfigItem = $false }
               Environment = @{ Verbs = 'Get','Set','Rename','Remove','Restore'; Class = 'System.Environment'                                           ; ConfigItem = $true  }
            FileAttachment = @{ Verbs = 'Get','Set','Rename','Remove'          ; Class = 'System.FileAttachment'                                        ; ConfigItem = $false }
                  Incident = @{ Verbs = 'Get','Set','Rename','Remove'          ; Class = 'System.WorkItem.Incident'                                     ; ConfigItem = $false }
          KnowledgeArticle = @{ Verbs = 'Get','Set','Rename','Remove','Restore'; Class = 'System.Knowledge.Article'                                     ; ConfigItem = $true  }
          ManagementServer = @{ Verbs = 'Get','Set','Rename','Remove','Restore'; Class = 'Microsoft.SystemCenter.ManagementServer'                      ; ConfigItem = $true  }
                   Problem = @{ Verbs = 'Get','Set','Rename','Remove'          ; Class = 'System.WorkItem.Problem'                                      ; ConfigItem = $false }
             ReleaseRecord = @{ Verbs = 'Get','Set','Rename','Remove'          ; Class = 'System.WorkItem.ReleaseRecord'                                ; ConfigItem = $false }
           RequestOffering = @{ Verbs = 'Get','Set','Rename','Remove'          ; Class = 'System.RequestOffering'                                       ; ConfigItem = $false }
                   Runbook = @{ Verbs = 'Get','Set','Rename','Remove'          ; Class = 'Microsoft.SystemCenter.Orchestrator.RunbookItem'              ; ConfigItem = $false }
           ServiceOffering = @{ Verbs = 'Get','Set','Rename','Remove'          ; Class = 'System.ServiceOffering'                                       ; ConfigItem = $false }
            ServiceRequest = @{ Verbs = 'Get','Set','Rename','Remove','Restore'; Class = 'System.WorkItem.ServiceRequest'                               ; ConfigItem = $true  }
              SoftwareItem = @{ Verbs = 'Get','Set','Rename','Remove','Restore'; Class = 'System.SoftwareItem'                                          ; ConfigItem = $true  }
            SoftwareUpdate = @{ Verbs = 'Get','Set','Rename','Remove','Restore'; Class = 'System.SoftwareUpdate'                                        ; ConfigItem = $true  }
               UserOrGroup = @{ Verbs = 'Get','Set','Rename','Remove','Restore'; Class = 'System.Domain.User'                                           ; ConfigItem = $true  }
           WindowsComputer = @{ Verbs = 'Get','Set','Rename','Remove','Restore'; Class = 'Microsoft.Windows.Computer'                                   ; ConfigItem = $true  }
         DependentActivity = @{ Verbs = 'Get','Set','Rename','Remove'          ; Class = 'System.WorkItem.Activity.DependentActivity'                   ; ConfigItem = $false }
            ManualActivity = @{ Verbs = 'Get','Set','Rename','Remove'          ; Class = 'System.WorkItem.Activity.ManualActivity'                      ; ConfigItem = $false }
          ParallelActivity = @{ Verbs = 'Get','Set','Rename','Remove'          ; Class = 'System.WorkItem.Activity.ParallelActivity'                    ; ConfigItem = $false }
            ReviewActivity = @{ Verbs = 'Get','Set','Rename','Remove'          ; Class = 'System.WorkItem.Activity.ReviewActivity'                      ; ConfigItem = $false }
        SequentialActivity = @{ Verbs = 'Get','Set','Rename','Remove'          ; Class = 'System.WorkItem.Activity.SequentialActivity'                  ; ConfigItem = $false }
           RunbookActivity = @{ Verbs = 'Get','Set','Rename','Remove'          ; Class = 'Microsoft.SystemCenter.Orchestrator.RunbookAutomationActivity'; ConfigItem = $false }
    }

    foreach ($noun in $nounMap.Keys) {
        foreach ($verb in $nounMap.$noun.Verbs) {
            $newProxyFunctionDefinitionParameters = @{
                      Verb = $verb
                      Noun = $noun
                NounPrefix = 'ScsmPx'
                 ClassName = $nounMap.$noun.Class
            }
            if ($nounMap.$noun.ConfigItem) {
                $newProxyFunctionDefinitionParameters['ConfigItem'] = $true
            }
            if ($viewMap.ContainsKey($nounMap.$noun.Class)) {
                $newProxyFunctionDefinitionParameters['Views'] = $viewMap[$nounMap.$noun.Class]
            }
            . (New-ScsmPxProxyFunctionDefinition @newProxyFunctionDefinitionParameters)
        }
    }

    #endregion
} catch {
    throw
}