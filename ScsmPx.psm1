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
# SIG # Begin signature block
# MIIZKQYJKoZIhvcNAQcCoIIZGjCCGRYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUztvWvsITUpi7a5uCBf0AXwh2
# 0zagghQZMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggVuMIIEVqADAgECAhBaCt8RSzACYI8wikJ38dScMA0GCSqGSIb3DQEBBQUAMIG0
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsT
# FlZlcmlTaWduIFRydXN0IE5ldHdvcmsxOzA5BgNVBAsTMlRlcm1zIG9mIHVzZSBh
# dCBodHRwczovL3d3dy52ZXJpc2lnbi5jb20vcnBhIChjKTEwMS4wLAYDVQQDEyVW
# ZXJpU2lnbiBDbGFzcyAzIENvZGUgU2lnbmluZyAyMDEwIENBMB4XDTE0MDUwNzAw
# MDAwMFoXDTE2MDYwNTIzNTk1OVowgbExCzAJBgNVBAYTAkNBMQ8wDQYDVQQIEwZR
# dWViZWMxETAPBgNVBAcTCEdhdGluZWF1MR4wHAYDVQQKFBVQcm92YW5jZSBUZWNo
# bm9sb2dpZXMxPjA8BgNVBAsTNURpZ2l0YWwgSUQgQ2xhc3MgMyAtIE1pY3Jvc29m
# dCBTb2Z0d2FyZSBWYWxpZGF0aW9uIHYyMR4wHAYDVQQDFBVQcm92YW5jZSBUZWNo
# bm9sb2dpZXMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDLiRcW2j5o
# eaNIUBUtmxBdBtkjTfBphgAJQVr7j1OPpBYAlpgUdBQ7nA5XYgPsmrRWYr7KaytF
# vigAvn6smkYz41DE2mFpYakhpo5/vW+ppgXdIDuNy/WCjHQadrpXNn41hVWxoig+
# pXYVe5UsxAH9S2B+r1x1qiTiPtVuLQGgNAwJaRTGI98oYGQZAwEetKywofwcq5em
# KB2V+4+Caac+X2tizlqQ6Wntzkcti02OmeWxUb3jwCjkgUmIlOOb43AiC4vfBys+
# mcniWCYMgGPsDjeThmDKTSChQJIcf/EmqUSkfSV7QVACcJVIRuDgwxQpdaCDBJ5c
# LTjePE1yiR+hAgMBAAGjggF7MIIBdzAJBgNVHRMEAjAAMA4GA1UdDwEB/wQEAwIH
# gDBABgNVHR8EOTA3MDWgM6Axhi9odHRwOi8vY3NjMy0yMDEwLWNybC52ZXJpc2ln
# bi5jb20vQ1NDMy0yMDEwLmNybDBEBgNVHSAEPTA7MDkGC2CGSAGG+EUBBxcDMCow
# KAYIKwYBBQUHAgEWHGh0dHBzOi8vd3d3LnZlcmlzaWduLmNvbS9ycGEwEwYDVR0l
# BAwwCgYIKwYBBQUHAwMwcQYIKwYBBQUHAQEEZTBjMCQGCCsGAQUFBzABhhhodHRw
# Oi8vb2NzcC52ZXJpc2lnbi5jb20wOwYIKwYBBQUHMAKGL2h0dHA6Ly9jc2MzLTIw
# MTAtYWlhLnZlcmlzaWduLmNvbS9DU0MzLTIwMTAuY2VyMB8GA1UdIwQYMBaAFM+Z
# qep7JvRLyY6P1/AFJu/j0qedMBEGCWCGSAGG+EIBAQQEAwIEEDAWBgorBgEEAYI3
# AgEbBAgwBgEBAAEB/zANBgkqhkiG9w0BAQUFAAOCAQEAthqiVI8NgoeOb07LiC6e
# GpOKoY/ClKrwbPcgvj8jkr7JgLR1n2PmfF1K1z8mW3GnWeBNsilBPfLMIHWtYasP
# pN08eIDcAyvr7QKKQPW5AY3HmCADofNCAqcgAC2YxJ5pstYwRDKkBcrV211s+jmE
# W+2ij0XivPvXokVcfaiSG6ovftQu58yEJZ3knMS3BIC/tPSVFt2GSalDTHCLtCBP
# TJ2XrZKnBvmCnFoifPrD3DSMT10FeZp6gHlDtpOD1oODu4fquFjmGyrhjgnrzu4N
# atHfFbVW4if/662W3Cso3C4zo502fMWgz+mHBbbNF0yeuwUG6NJUG/rQdbCqw2QD
# ijCCBgowggTyoAMCAQICEFIA5aolVvwahu2WydRLM8cwDQYJKoZIhvcNAQEFBQAw
# gcoxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5WZXJpU2lnbiwgSW5jLjEfMB0GA1UE
# CxMWVmVyaVNpZ24gVHJ1c3QgTmV0d29yazE6MDgGA1UECxMxKGMpIDIwMDYgVmVy
# aVNpZ24sIEluYy4gLSBGb3IgYXV0aG9yaXplZCB1c2Ugb25seTFFMEMGA1UEAxM8
# VmVyaVNpZ24gQ2xhc3MgMyBQdWJsaWMgUHJpbWFyeSBDZXJ0aWZpY2F0aW9uIEF1
# dGhvcml0eSAtIEc1MB4XDTEwMDIwODAwMDAwMFoXDTIwMDIwNzIzNTk1OVowgbQx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5WZXJpU2lnbiwgSW5jLjEfMB0GA1UECxMW
# VmVyaVNpZ24gVHJ1c3QgTmV0d29yazE7MDkGA1UECxMyVGVybXMgb2YgdXNlIGF0
# IGh0dHBzOi8vd3d3LnZlcmlzaWduLmNvbS9ycGEgKGMpMTAxLjAsBgNVBAMTJVZl
# cmlTaWduIENsYXNzIDMgQ29kZSBTaWduaW5nIDIwMTAgQ0EwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQD1I0tepdeKuzLp1Ff37+THJn6tGZj+qJ19lPY2
# axDXdYEwfwRof8srdR7NHQiM32mUpzejnHuA4Jnh7jdNX847FO6G1ND1JzW8JQs4
# p4xjnRejCKWrsPvNamKCTNUh2hvZ8eOEO4oqT4VbkAFPyad2EH8nA3y+rn59wd35
# BbwbSJxp58CkPDxBAD7fluXF5JRx1lUBxwAmSkA8taEmqQynbYCOkCV7z78/HOsv
# lvrlh3fGtVayejtUMFMb32I0/x7R9FqTKIXlTBdOflv9pJOZf9/N76R17+8V9kfn
# +Bly2C40Gqa0p0x+vbtPDD1X8TDWpjaO1oB21xkupc1+NC2JAgMBAAGjggH+MIIB
# +jASBgNVHRMBAf8ECDAGAQH/AgEAMHAGA1UdIARpMGcwZQYLYIZIAYb4RQEHFwMw
# VjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cudmVyaXNpZ24uY29tL2NwczAqBggr
# BgEFBQcCAjAeGhxodHRwczovL3d3dy52ZXJpc2lnbi5jb20vcnBhMA4GA1UdDwEB
# /wQEAwIBBjBtBggrBgEFBQcBDARhMF+hXaBbMFkwVzBVFglpbWFnZS9naWYwITAf
# MAcGBSsOAwIaBBSP5dMahqyNjmvDz4Bq1EgYLHsZLjAlFiNodHRwOi8vbG9nby52
# ZXJpc2lnbi5jb20vdnNsb2dvLmdpZjA0BgNVHR8ELTArMCmgJ6AlhiNodHRwOi8v
# Y3JsLnZlcmlzaWduLmNvbS9wY2EzLWc1LmNybDA0BggrBgEFBQcBAQQoMCYwJAYI
# KwYBBQUHMAGGGGh0dHA6Ly9vY3NwLnZlcmlzaWduLmNvbTAdBgNVHSUEFjAUBggr
# BgEFBQcDAgYIKwYBBQUHAwMwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFZlcmlT
# aWduTVBLSS0yLTgwHQYDVR0OBBYEFM+Zqep7JvRLyY6P1/AFJu/j0qedMB8GA1Ud
# IwQYMBaAFH/TZafC3ey78DAJ80M5+gKvMzEzMA0GCSqGSIb3DQEBBQUAA4IBAQBW
# IuY0pMRhy0i5Aa1WqGQP2YyRxLvMDOWteqAif99HOEotbNF/cRp87HCpsfBP5A8M
# U/oVXv50mEkkhYEmHJEUR7BMY4y7oTTUxkXoDYUmcwPQqYxkbdxxkuZFBWAVWVE5
# /FgUa/7UpO15awgMQXLnNyIGCb4j6T9Emh7pYZ3MsZBc/D3SjaxCPWU21LQ9QCiP
# mxDPIybMSyDLkB9djEw0yjzY5TfWb6UgvTTrJtmuDefFmvehtCGRM2+G6Fi7JXx0
# Dlj+dRtjP84xfJuPG5aexVN2hFucrZH6rO2Tul3IIVPCglNjrxINUIcRGz1UUpaK
# LJw9khoImgUux5OlSJHTMYIEejCCBHYCAQEwgckwgbQxCzAJBgNVBAYTAlVTMRcw
# FQYDVQQKEw5WZXJpU2lnbiwgSW5jLjEfMB0GA1UECxMWVmVyaVNpZ24gVHJ1c3Qg
# TmV0d29yazE7MDkGA1UECxMyVGVybXMgb2YgdXNlIGF0IGh0dHBzOi8vd3d3LnZl
# cmlzaWduLmNvbS9ycGEgKGMpMTAxLjAsBgNVBAMTJVZlcmlTaWduIENsYXNzIDMg
# Q29kZSBTaWduaW5nIDIwMTAgQ0ECEFoK3xFLMAJgjzCKQnfx1JwwCQYFKw4DAhoF
# AKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisG
# AQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcN
# AQkEMRYEFJS+2b+5tVzzlpwYKVXScTIhcff8MA0GCSqGSIb3DQEBAQUABIIBAGqt
# p7ZDjaGMagSXF5NnLe5rlsysfuEAaPjBaWdzIc2yrdnQaKCHm4Kamh7/aWeKc913
# Gmm6Wn8AH0i0BmGns8mhUHh000b7fZAy/+cP6yua35bNJSN50aCJlWnYV7EgXHEZ
# OyFsgbJhM3oVkr92OiyL22WYjaYeMvAT62DNprelKHY4dHornBk+UfGfUbtdo8oD
# f39iN5bn4/5mbFpACGomt9AZcs7NtuZ8okRangG7HAgIc8GjOB3oYaDyAqGP3k7K
# Qf7mlBZvi+ujo4xqwGg20GPuKi2fj8BmRZe2VrqwqM4ZnISi6m/gWnWaF3sGMKRQ
# mulHwkZs92CUKhaB38ehggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBe
# MQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAu
# BgNVBAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQ
# Ds/0OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqG
# SIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTYwMTIwMjExOTI4WjAjBgkqhkiG9w0B
# CQQxFgQU0UDvAqXr0iLSJXZS6BzyzQtoCZEwDQYJKoZIhvcNAQEBBQAEggEAQ3QO
# E0PAZE/B9ZOySYiEZrnC0y8KE8aBDxFWgdc93DzM87F+K97l9m52d026hhlOtxKt
# 3L4yuQiqozsscVs3aREbH9JGGtSdbOj38QSrr4j7oqjWWZIK+WJitF1NxRkR+AzM
# rdB6mzcPeHdPWBf45K/B02xUJ6Dl+Bb9lbYU5n6/NDmg0Mn3+8rV/v0cfi7Kxac6
# eKJGuS14ZSpGyAqejLJneRoG55QjqbK8foPPXFaDL8hOkNdhHnVQ8nCSQrN/EXNk
# 6pYQH8lnFMPtKSAl3QxV36fpZx/pxCsSvLE8E6pHgLHHlcG6+WgqWwFyK3VTDX0y
# 1AUdUpWiUlGWmZSmBA==
# SIG # End signature block
