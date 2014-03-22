<#############################################################################
The ScsmPx module facilitates automation with System Center Service Manager by
auto-loading the native modules and enabling automatic discovery of the native
module commands. It also includes additional complementary commands that are
not available out of the box.

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

@{
      ModuleToProcess = 'ScsmPx.psm1'
        ModuleVersion = '1.0.4.28'
                 GUID = '2fb132d0-0eea-434f-9619-e8c134e12c57'
               Author = 'Kirk Munro'
          CompanyName = 'Provance Technologies'
            Copyright = '(c) 2014 Provance Technologies'
          Description = 'A module that facilitates automation with System Center Service Manager via auto-loading and automatic discovery of the native modules and definition of additional commands that are not available out of the box.'
    PowerShellVersion = '3.0'
     ScriptsToProcess = @(
                        'scripts\Initialize-ScsmPxModule.ps1'
                        )
    FunctionsToExport = @(
                        'Get-SCSMCommand'
                        'Get-ScsmPxAdGroup'
                        'Get-ScsmPxAdPrinter'
                        'Get-ScsmPxAdUser'
                        'Get-ScsmPxBuild'
                        'Get-ScsmPxBusinessService'
                        'Get-ScsmPxChangeRequest'
                        'Get-ScsmPxCommand'
                        'Get-ScsmPxConfigItem'
                        'Get-ScsmPxConnectedUser'
                        'Get-ScsmPxDependentActivity'
                        'Get-ScsmPxDwCube'
                        'Get-ScsmPxDwDataSource'
                        'Get-ScsmPxDwName'
                        'Get-ScsmPxEnterpriseManagementGroup'
                        'Get-ScsmPxEnvironment'
                        'Get-ScsmPxIncident'
                        'Get-ScsmPxList'
                        'Get-ScsmPxListItem'
                        'Get-ScsmPxKnowledgeArticle'
                        'Get-ScsmPxManagementServer'
                        'Get-ScsmPxManualActivity'
                        'Get-ScsmPxObject'
                        'Get-ScsmPxParallelActivity'
                        'Get-ScsmPxPrimaryManagementServer'
                        'Get-ScsmPxProblem'
                        'Get-ScsmPxRelatedObject'
                        'Get-ScsmPxReleaseRecord'
                        'Get-ScsmPxRequestOffering'
                        'Get-ScsmPxReviewActivity'
                        'Get-ScsmPxRunbook'
                        'Get-ScsmPxRunbookActivity'
                        'Get-ScsmPxSequentialActivity'
                        'Get-ScsmPxServiceOffering'
                        'Get-ScsmPxServiceRequest'
                        'Get-ScsmPxSoftwareItem'
                        'Get-ScsmPxSoftwareUpdate'
                        'Get-ScsmPxUserOrGroup'
                        'Get-ScsmPxViewData'
                        'Get-ScsmPxWindowsComputer'
                        'New-ScsmPxObject'
                        'New-ScsmPxObjectSearchCriteria'
                        'New-ScsmPxProxyFunctionDefinition'
                        'Remove-ScsmPxAdGroup'
                        'Remove-ScsmPxAdPrinter'
                        'Remove-ScsmPxAdUser'
                        'Remove-ScsmPxBuild'
                        'Remove-ScsmPxBusinessService'
                        'Remove-ScsmPxChangeRequest'
                        'Remove-ScsmPxConfigItem'
                        'Remove-ScsmPxDependentActivity'
                        'Remove-ScsmPxDwCube'
                        'Remove-ScsmPxDwDataSource'
                        'Remove-ScsmPxEnvironment'
                        'Remove-ScsmPxIncident'
                        'Remove-ScsmPxKnowledgeArticle'
                        'Remove-ScsmPxManagementServer'
                        'Remove-ScsmPxManualActivity'
                        'Remove-ScsmPxObject'
                        'Remove-ScsmPxParallelActivity'
                        'Remove-ScsmPxProblem'
                        'Remove-ScsmPxReleaseRecord'
                        'Remove-ScsmPxRequestOffering'
                        'Remove-ScsmPxReviewActivity'
                        'Remove-ScsmPxRunbook'
                        'Remove-ScsmPxRunbookActivity'
                        'Remove-ScsmPxSequentialActivity'
                        'Remove-ScsmPxServiceOffering'
                        'Remove-ScsmPxServiceRequest'
                        'Remove-ScsmPxSoftwareItem'
                        'Remove-ScsmPxSoftwareUpdate'
                        'Remove-ScsmPxUserOrGroup'
                        'Remove-ScsmPxWindowsComputer'
                        'Rename-ScsmPxAdGroup'
                        'Rename-ScsmPxAdPrinter'
                        'Rename-ScsmPxAdUser'
                        'Rename-ScsmPxBuild'
                        'Rename-ScsmPxBusinessService'
                        'Rename-ScsmPxChangeRequest'
                        'Rename-ScsmPxConfigItem'
                        'Rename-ScsmPxDependentActivity'
                        'Rename-ScsmPxDwCube'
                        'Rename-ScsmPxDwDataSource'
                        'Rename-ScsmPxEnvironment'
                        'Rename-ScsmPxIncident'
                        'Rename-ScsmPxKnowledgeArticle'
                        'Rename-ScsmPxManagementServer'
                        'Rename-ScsmPxManualActivity'
                        'Rename-ScsmPxObject'
                        'Rename-ScsmPxParallelActivity'
                        'Rename-ScsmPxProblem'
                        'Rename-ScsmPxReleaseRecord'
                        'Rename-ScsmPxRequestOffering'
                        'Rename-ScsmPxReviewActivity'
                        'Rename-ScsmPxRunbook'
                        'Rename-ScsmPxRunbookActivity'
                        'Rename-ScsmPxSequentialActivity'
                        'Rename-ScsmPxServiceOffering'
                        'Rename-ScsmPxServiceRequest'
                        'Rename-ScsmPxSoftwareItem'
                        'Rename-ScsmPxSoftwareUpdate'
                        'Rename-ScsmPxUserOrGroup'
                        'Rename-ScsmPxWindowsComputer'
                        'Reset-ScsmPxCommandCache'
                        'Restore-ScsmPxAdGroup'
                        'Restore-ScsmPxAdPrinter'
                        'Restore-ScsmPxAdUser'
                        'Restore-ScsmPxBuild'
                        'Restore-ScsmPxBusinessService'
                        'Restore-ScsmPxConfigItem'
                        'Restore-ScsmPxEnvironment'
                        'Restore-ScsmPxKnowledgeArticle'
                        'Restore-ScsmPxManagementServer'
                        'Restore-ScsmPxObject'
                        'Restore-ScsmPxServiceRequest'
                        'Restore-ScsmPxSoftwareItem'
                        'Restore-ScsmPxSoftwareUpdate'
                        'Restore-ScsmPxUserOrGroup'
                        'Restore-ScsmPxWindowsComputer'
                        'Set-ScsmPxAdGroup'
                        'Set-ScsmPxAdPrinter'
                        'Set-ScsmPxAdUser'
                        'Set-ScsmPxBuild'
                        'Set-ScsmPxBusinessService'
                        'Set-ScsmPxChangeRequest'
                        'Set-ScsmPxConfigItem'
                        'Set-ScsmPxDependentActivity'
                        'Set-ScsmPxDwCube'
                        'Set-ScsmPxDwDataSource'
                        'Set-ScsmPxEnvironment'
                        'Set-ScsmPxIncident'
                        'Set-ScsmPxKnowledgeArticle'
                        'Set-ScsmPxManagementServer'
                        'Set-ScsmPxManualActivity'
                        'Set-ScsmPxObject'
                        'Set-ScsmPxParallelActivity'
                        'Set-ScsmPxProblem'
                        'Set-ScsmPxReleaseRecord'
                        'Set-ScsmPxRequestOffering'
                        'Set-ScsmPxReviewActivity'
                        'Set-ScsmPxRunbook'
                        'Set-ScsmPxRunbookActivity'
                        'Set-ScsmPxSequentialActivity'
                        'Set-ScsmPxServiceOffering'
                        'Set-ScsmPxServiceRequest'
                        'Set-ScsmPxSoftwareItem'
                        'Set-ScsmPxSoftwareUpdate'
                        'Set-ScsmPxUserOrGroup'
                        'Set-ScsmPxWindowsComputer'
                        )
      CmdletsToExport = @(
                        'Add-SCSMAllowListClass'
                        'Disable-SCDWJob'
                        'Disable-SCDWJobCategory'
                        'Disable-SCDWJobSchedule'
                        'Disable-SCDWSource'
                        'Enable-SCDWJob'
                        'Enable-SCDWJobCategory'
                        'Enable-SCDWJobSchedule'
                        'Enable-SCDWSource'
                        'Export-SCManagementPack'
                        'Get-SCClass'
                        'Get-SCClassInstance'
                        'Get-SCDiscovery'
                        'Get-SCDWEntity'
                        'Get-SCDWJob'
                        'Get-SCDWJobModule'
                        'Get-SCDWJobSchedule'
                        'Get-SCDWRetentionPeriod'
                        'Get-SCDWSource'
                        'Get-SCDWSourceType'
                        'Get-SCDWWatermark'
                        'Get-SCGroup'
                        'Get-SCManagementGroupConnection'
                        'Get-SCManagementPack'
                        'Get-SCObjectTemplate'
                        'Get-SCRelationship'
                        'Get-SCRelationshipInstance'
                        'Get-SCRunAsAccount'
                        'Get-SCSMAllowList'
                        'Get-SCSMAnnouncement'
                        'Get-SCSMChannel'
                        'Get-SCSMConnector'
                        'Get-SCSMDCMWorkflow'
                        'Get-SCSMDeletedItem'
                        'Get-SCSMEmailTemplate'
                        'Get-SCSMEmailTemplateContent'
                        'Get-SCSMPortalCMConfiguration'
                        'Get-SCSMPortalContactConfiguration'
                        'Get-SCSMPortalDeploymentProcess'
                        'Get-SCSMPortalSoftwarePackage'
                        'Get-SCSMQueue'
                        'Get-SCSMSetting'
                        'Get-SCSMSubscription'
                        'Get-SCSMTask'
                        'Get-SCSMUser'
                        'Get-SCSMUserRole'
                        'Get-SCSMView'
                        'Get-SCSMWorkflow'
                        'Get-SCSMWorkflowStatus'
                        'Import-SCManagementPack'
                        'Import-SCSMInstance'
                        'New-SCADConnector'
                        'New-SCClassInstance'
                        'New-SCCMConnector'
                        'New-SCDWSourceType'
                        'New-SCManagementGroupConnection'
                        'New-SCManagementPack'
                        'New-SCManagementPackBundle'
                        'New-SCOMAlertConnector'
                        'New-SCOMConfigurationItemConnector'
                        'New-SCOrchestratorConnector'
                        'New-SCRelationshipInstance'
                        'New-SCRunAsAccount'
                        'New-SCSMAlertRule'
                        'New-SCSMAnnouncement'
                        'New-SCSMDCMWorkflow'
                        'New-SCSMEmailTemplate'
                        'New-SCSMPortalDeploymentProcess'
                        'New-SCSMSubscription'
                        'New-SCSMUserRole'
                        'New-SCSMWorkflow'
                        'New-SCVMMConnector'
                        'Protect-SCManagementPack'
                        'Register-SCDWSource'
                        'Remove-SCClassInstance'
                        'Remove-SCManagementGroupConnection'
                        'Remove-SCManagementPack'
                        'Remove-SCRelationshipInstance'
                        'Remove-SCRunAsAccount'
                        'Remove-SCSMAllowListClass'
                        'Remove-SCSMAnnouncement'
                        'Remove-SCSMConnector'
                        'Remove-SCSMDCMWorkflow'
                        'Remove-SCSMEmailTemplate'
                        'Remove-SCSMPortalDeploymentProcess'
                        'Remove-SCSMSubscription'
                        'Remove-SCSMUserRole'
                        'Remove-SCSMWorkflow'
                        'Reset-SCSMAllowList'
                        'Restore-SCSMDeletedItem'
                        'Set-SCDWJobSchedule'
                        'Set-SCDWRetentionPeriod'
                        'Set-SCDWSource'
                        'Set-SCDWWatermark'
                        'Set-SCManagementGroupConnection'
                        'Set-SCSMChannel'
                        'Set-SCSMPortalCMConfiguration'
                        'Set-SCSMPortalContactConfiguration'
                        'Start-SCDWJob'
                        'Start-SCSMConnector'
                        'Stop-SCDWJob'
                        'Test-SCManagementPack'
                        'Unregister-SCDWManagementPack'
                        'Unregister-SCDWSource'
                        'Update-SCClassInstance'
                        'Update-SCRunAsAccount'
                        'Update-SCSMAnnouncement'
                        'Update-SCSMConnector'
                        'Update-SCSMDCMWorkflow'
                        'Update-SCSMEmailTemplate'
                        'Update-SCSMPortalDeploymentProcess'
                        'Update-SCSMPortalSoftwarePackage'
                        'Update-SCSMSetting'
                        'Update-SCSMSubscription'
                        'Update-SCSMUserRole'
                        'Update-SCSMWorkflow'
                        )
      AliasesToExport = @(
                        'Export-SCSMManagementPack'
                        'Get-SCSMClass'
                        'Get-SCSMClassInstance'
                        'Get-SCSMDiscovery'
                        'Get-SCSMGroup'
                        'Get-SCSMManagementGroupConnection'
                        'Get-SCSMManagementPack'
                        'Get-SCSMObjectTemplate'
                        'Get-SCSMRelationship'
                        'Get-SCSMRelationshipInstance'
                        'Get-SCSMRunAsAccount'
                        'Import-SCSMManagementPack'
                        'New-SCSMADConnector'
                        'New-SCSMClassInstance'
                        'New-SCSMCMConnector'
                        'New-SCSMManagementGroupConnection'
                        'New-SCSMManagementPack'
                        'New-SCSMManagementPackBundle'
                        'New-SCSMOMAlertConnector'
                        'New-SCSMOMConfigurationItemConnector'
                        'New-SCSMRunAsAccount'
                        'Protect-SCSMManagementPack'
                        'Remove-SCSMClassInstance'
                        'Remove-SCSMManagementGroupConnection'
                        'Remove-SCSMManagementPack'
                        'Remove-SCSMRelationshipInstance'
                        'Remove-SCSMRunAsAccount'
                        'Set-SCSMManagementGroupConnection'
                        'Test-SCSMManagementPack'
                        'Update-SCSMClassInstance'
                        'Update-SCSMRunAsAccount'
                        )
             FileList = @(
                        'ScsmPx.psd1'
                        'ScsmPx.psm1'
                        'functions\Get-ScsmPxCommand.ps1'
                        'functions\Get-ScsmPxConnectedUser.ps1'
                        'functions\Get-ScsmPxDwName.ps1'
                        'functions\Get-ScsmPxEnterpriseManagementGroup.ps1'
                        'functions\Get-ScsmPxList.ps1'
                        'functions\Get-ScsmPxListItem.ps1'
                        'functions\Get-ScsmPxObject.ps1'
                        'functions\Get-ScsmPxPrimaryManagementServer.ps1'
                        'functions\Get-ScsmPxRelatedObject.ps1'
                        'functions\Get-ScsmPxViewData.ps1'
                        'functions\New-ScsmPxObject.ps1'
                        'functions\New-ScsmPxObjectSearchCriteria.ps1'
                        'functions\New-ScsmPxProxyFunctionDefinition.ps1'
                        'functions\Remove-ScsmPxObject.ps1'
                        'functions\Rename-ScsmPxObject.ps1'
                        'functions\Reset-ScsmPxCommandCache.ps1'
                        'functions\Restore-ScsmPxObject.ps1'
                        'functions\Set-ScsmPxObject.ps1'
                        'scripts\Initialize-ScsmPxModule.ps1'
                        )
}