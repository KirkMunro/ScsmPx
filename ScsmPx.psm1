<#############################################################################
The ScsmPx module facilitates automation with Microsoft System Center Service
Manager by auto-loading the native modules that are included as part of that
product and enabling automatic discovery of the commands that are contained
within the native modules. It also includes dozens of complementary commands
that are not available out of the box to allow you to do much more with your
PowerShell automation efforts using the platform.

Copyright (c) 2014 Provance Technologies.

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License in the
license folder that is included in the ScsmPx module. If not, see
<https://www.gnu.org/licenses/gpl.html>.
#############################################################################>

Set-StrictMode -Version Latest
Export-ModuleMember
$PSModuleRoot = $PSScriptRoot

#region If PowerShell erroneously created an Initialize-Scsmx module, remove it.

# This is a workaround to a bug in PowerShell 3.0 and later.
if (Get-Module -Name Initialize-ScsmPxModule) {
    Remove-Module -Name Initialize-ScsmPxModule
}

#endregion

#region If the ScriptToProcess script raised an exception, throw it from here.

if ($initializeScsmPxModuleException = Get-Variable -Scope Global -Name InitializeScsmPxModuleException -ValueOnly -ErrorAction SilentlyContinue) {
    Remove-Variable -Scope Global -Name InitializeScsmPxModuleException
    throw $initializeScsmPxModuleException
}

#endregion

#region Import helper (private) function definitions.

# There are no helper (private) functions for now.

#endregion

#region Import public function definitions.

. $PSScriptRoot\functions\Get-ScsmPxCommand.ps1
. $PSScriptRoot\functions\Get-ScsmPxConnectedUser.ps1
. $PSScriptRoot\functions\Get-ScsmPxDwName.ps1
. $PSScriptRoot\functions\Get-ScsmPxEnterpriseManagementGroup.ps1
. $PSScriptRoot\functions\Get-ScsmPxList.ps1
. $PSScriptRoot\functions\Get-ScsmPxListItem.ps1
. $PSScriptRoot\functions\Get-ScsmPxObject.ps1
. $PSScriptRoot\functions\Get-ScsmPxPrimaryManagementServer.ps1
. $PSScriptRoot\functions\Get-ScsmPxRelatedObject.ps1
. $PSScriptRoot\functions\Get-ScsmPxViewData.ps1
. $PSScriptRoot\functions\New-ScsmPxObject.ps1
. $PSScriptRoot\functions\New-ScsmPxObjectSearchCriteria.ps1
. $PSScriptRoot\functions\New-ScsmPxProxyFunctionDefinition.ps1
. $PSScriptRoot\functions\Remove-ScsmPxObject.ps1
. $PSScriptRoot\functions\Rename-ScsmPxObject.ps1
. $PSScriptRoot\functions\Reset-ScsmPxCommandCache.ps1
. $PSScriptRoot\functions\Restore-ScsmPxObject.ps1
. $PSScriptRoot\functions\Set-ScsmPxObject.ps1

#endregion

#region Add a custom ToString method to the ManagementPackEnumeration type.

if ($PSVersionTable.PSVersion -ge '3.0') {
    Update-TypeData -TypeName Microsoft.EnterpriseManagement.Configuration.ManagementPackEnumeration -MemberName ToString -MemberType ScriptMethod -Value {$this.DisplayName} -Force
} else {
    # Update-TypeData requires PowerShell 3.0 or later. To support extensions like this in 2.0 without
    # requiring a ps1xml file, we need to use some internal methods. These methods won't change at
    # this point though, so this should be a safe workaround for PowerShell 2.0. If it were to fail
    # though, we don't want to raise a fuss, so continue loading the module.
    try {
        $runspaceConfiguration = $Host.Runspace.RunspaceConfiguration
        if (($typeTableProperty = $runspaceConfiguration.GetType().GetProperty('TypeTable',[System.Reflection.BindingFlags]'NonPublic,Instance')) -and
            ($typeTable = $typeTableProperty.GetValue($runspaceConfiguration,$null)) -and
            ($membersField = $typeTable.GetType().GetField('members',[System.Reflection.BindingFlags]'NonPublic,Instance')) -and
            ($members = $membersField.GetValue($typeTable))) {
            if ((-not $members.ContainsKey('Microsoft.EnterpriseManagement.Configuration.ManagementPackEnumeration')) -and
                ($psMemberInfoInternalCollectionType = [System.Management.Automation.PSObject].Assembly.GetType('System.Management.Automation.PSMemberInfoInternalCollection`1',$true,$true)) -and
                ($psMemberInfoGenericCollection = $psMemberInfoInternalCollectionType.MakeGenericType([System.Management.Automation.PSMemberInfo])) -and
                ($genericCollectionConstructor = $psMemberInfoGenericCollection.GetConstructor('NonPublic,Instance',$null,@(),@()))) {
                $genericCollection = $genericCollectionConstructor.Invoke(@())
                $scriptMethod = New-Object -TypeName System.Management.Automation.PSScriptMethod -ArgumentList 'ToString',{$this.DisplayName}
                $genericCollection.Add($scriptMethod)
                $members.Add('Microsoft.EnterpriseManagement.Configuration.ManagementPackEnumeration',$genericCollection)
            } else {
                $scriptMethod = New-Object -TypeName System.Management.Automation.PSScriptMethod -ArgumentList 'ToString',{$this.DisplayName}
                $members['Microsoft.EnterpriseManagement.Configuration.ManagementPackEnumeration'].Remove('ToString')
                $members['Microsoft.EnterpriseManagement.Configuration.ManagementPackEnumeration'].Add($scriptMethod)
            }
        }
    } catch {
        Write-Warning -Message 'Updating the ToString method for Management Pack enumerations failed.'
    }
}

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
    foreach ($verb in 'New','Get','Set','Rename','Remove','Restore') {
        if ($nounMap.$noun.Verbs -contains $verb) {
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
}

#endregion
# SIG # Begin signature block
# MIIZKQYJKoZIhvcNAQcCoIIZGjCCGRYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUeGYZFdCBOAcWo3hImAe0EW5J
# 5I+gghQZMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
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
# ggVuMIIEVqADAgECAhAKU6nZKT4ZKigLdw2V0ZC8MA0GCSqGSIb3DQEBBQUAMIG0
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsT
# FlZlcmlTaWduIFRydXN0IE5ldHdvcmsxOzA5BgNVBAsTMlRlcm1zIG9mIHVzZSBh
# dCBodHRwczovL3d3dy52ZXJpc2lnbi5jb20vcnBhIChjKTEwMS4wLAYDVQQDEyVW
# ZXJpU2lnbiBDbGFzcyAzIENvZGUgU2lnbmluZyAyMDEwIENBMB4XDTEzMDQwODAw
# MDAwMFoXDTE0MDUwODIzNTk1OVowgbExCzAJBgNVBAYTAkNBMQ8wDQYDVQQIEwZR
# dWViZWMxETAPBgNVBAcTCEdhdGluZWF1MR4wHAYDVQQKFBVQcm92YW5jZSBUZWNo
# bm9sb2dpZXMxPjA8BgNVBAsTNURpZ2l0YWwgSUQgQ2xhc3MgMyAtIE1pY3Jvc29m
# dCBTb2Z0d2FyZSBWYWxpZGF0aW9uIHYyMR4wHAYDVQQDFBVQcm92YW5jZSBUZWNo
# bm9sb2dpZXMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC04Yt50uP8
# newqG0tbz7MJHGQwrG6lf4LrqnnYvK+jHJY+mkXjOR1VQouSeteYmWzsqSiNFagM
# SFxAzO3CRZt1xP0FPQgXjsyJWcEUOokgPl+a5vFrFhmhphe7QztiO5kOR3rBr7cW
# DQhgv7yWStLg4ymNSrJbbNO0kczsl2FV/5pZ1pEdKzEDOO1X5Xx9Oaz3lb3ldrPk
# zn+Lwr36YTkU+jTPHoXPyHy4lBYK/qcNbuPTTE1BeH+rwENx9nkEUa6dPPcDKDPf
# EULo/g7P25ILApWoGJmdcefseebsu6CjtO5xYKTvk0ylWxXXoqnJvFw2z5Y8tUjA
# W0E43nmf73ApAgMBAAGjggF7MIIBdzAJBgNVHRMEAjAAMA4GA1UdDwEB/wQEAwIH
# gDBABgNVHR8EOTA3MDWgM6Axhi9odHRwOi8vY3NjMy0yMDEwLWNybC52ZXJpc2ln
# bi5jb20vQ1NDMy0yMDEwLmNybDBEBgNVHSAEPTA7MDkGC2CGSAGG+EUBBxcDMCow
# KAYIKwYBBQUHAgEWHGh0dHBzOi8vd3d3LnZlcmlzaWduLmNvbS9ycGEwEwYDVR0l
# BAwwCgYIKwYBBQUHAwMwcQYIKwYBBQUHAQEEZTBjMCQGCCsGAQUFBzABhhhodHRw
# Oi8vb2NzcC52ZXJpc2lnbi5jb20wOwYIKwYBBQUHMAKGL2h0dHA6Ly9jc2MzLTIw
# MTAtYWlhLnZlcmlzaWduLmNvbS9DU0MzLTIwMTAuY2VyMB8GA1UdIwQYMBaAFM+Z
# qep7JvRLyY6P1/AFJu/j0qedMBEGCWCGSAGG+EIBAQQEAwIEEDAWBgorBgEEAYI3
# AgEbBAgwBgEBAAEB/zANBgkqhkiG9w0BAQUFAAOCAQEASuMSDX2Mfs+c92nmVE9Q
# hhbHGRXgn7X3oWPQ4LVBgBvAjrqvBh/cxZuPjr8jRZPEyg6h1csvP2DZAjVi1oyO
# SDNSyWuGb+IW6IoCFz73h1GlLJyz816rOoD2YhBRCXJ+eCZZeoRxdG7jn1w/zq74
# FJWW1LDqnT6kXouZpPKEQXult0Cfeg3i/q0DKMbfq9qC66G1DqsDz/edORRirZ+a
# fhW+o0khAuNNDZN7Xm9pc0fr0itMrshfzUOoVChvU1xPCUryqtpz2URJWlcckVtC
# f4Vffsc/9W+FMfRuww6ahatjLWeT1fNerhWaY6YbD8OAbgj6DG+kmvorZYDX6boS
# kjCCBgowggTyoAMCAQICEFIA5aolVvwahu2WydRLM8cwDQYJKoZIhvcNAQEFBQAw
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
# Q29kZSBTaWduaW5nIDIwMTAgQ0ECEApTqdkpPhkqKAt3DZXRkLwwCQYFKw4DAhoF
# AKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisG
# AQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcN
# AQkEMRYEFB/Spt6zhupHYhfAxF9XVxWhVJq0MA0GCSqGSIb3DQEBAQUABIIBACuZ
# 6VrB5YGuMk6PXSuXy7YL6MppTtXfC9ko6EovICLv7slVzBRIf2Bbpw0BBXoJ9jgZ
# JST3/MRUiOzm0POY8+2Ma5T15ymBjdFqWd9ctA0GgMZ4SIlR/zx1TwFIj0+4HKHz
# r1Q254mW59O4OvXyV35GPp1aWGZ5pln8e7AnetuJVsn8M/Mz+CZ8tpw6LRV+gn8H
# DMFyvZNYNlViiQVGnXpIj+cX+nymUEs/Z/BMtYyNy5aOODOraj4QL81bTFJnDU+O
# LNEjnhsV3p9ZL/d/x/PA2PniMNDzW0Vwe71fBTLeN1vZ+/0X6CHbPW+ftVwI4cVo
# nTT0zh8T7RnULyZiwdOhggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBe
# MQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAu
# BgNVBAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQ
# Ds/0OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqG
# SIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTQwMzI2MjEzMzM2WjAjBgkqhkiG9w0B
# CQQxFgQU0iplfap1C34kzKy7bGhn7IZ4c3QwDQYJKoZIhvcNAQEBBQAEggEAUdQ8
# fZMIp7RSTTqL2El5Kxi2ZJHbiAX5AU1a7ow5r3T8lTN24ooyBsslRSzffFZBKawI
# 32RjBURzCz2ItWq7N40cKWRrs1HyCGnssFTELyS7mdtgpigQbJ3ZXdMbqIBfrXlE
# ZEmJY5GPX61rIaccRIKX9+ZJSKeWgqwPypubaae8xDTUJl7snecR6Ln6M7UnPWmY
# HQA6dYsmCSGPKA0e8ST0eJFxvrvsGqVb5rIcbbasNGy0E+G4QJX9mnKClmVABD6u
# SYF3To1HpG2Lhff8eZARzofLg/quLnbR4RpB1KPjjDQuzL711FxJYqtnPMb9UFQ4
# oZ21F08J/zokGAEKxg==
# SIG # End signature block
