﻿<#############################################################################
The ScsmPx module facilitates automation with Microsoft System Center Service
Manager by auto-loading the native modules that are included as part of that
product and enabling automatic discovery of the commands that are contained
within the native modules. It also includes dozens of complementary commands
that are not available out of the box to allow you to do much more with your
PowerShell automation efforts using the platform.

Copyright 2015 Provance Technologies.

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

@{
      ModuleToProcess = 'ScsmPx.psm1'

        ModuleVersion = '1.0.12.54'

                 GUID = '2fb132d0-0eea-434f-9619-e8c134e12c57'

               Author = 'Kirk Munro'

          CompanyName = 'Provance Technologies'

            Copyright = 'Copyright 2015 Provance Technologies'

          Description = 'The ScsmPx module facilitates automation with Microsoft System Center Service Manager by auto-loading the native modules that are included as part of that product and enabling automatic discovery of the commands that are contained within the native modules. It also includes dozens of complementary commands that are not available out of the box to allow you to do much more with your PowerShell automation efforts using the platform.'

    PowerShellVersion = '3.0'

        NestedModules = @(
                        'SnippetPx'
                        )

    FunctionsToExport = @(
                        'Add-ScsmPxFileAttachment'
                        'Add-ScsmPxTroubleTicketComment'
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
                        'Get-ScsmPxFileAttachment'
                        'Get-ScsmPxIncident'
                        'Get-ScsmPxInstallDirectory'
                        'Get-ScsmPxList'
                        'Get-ScsmPxListItem'
                        'Get-ScsmPxKnowledgeArticle'
                        'Get-ScsmPxManagementServer'
                        'Get-ScsmPxManualActivity'
                        'Get-ScsmPxObject'
                        'Get-ScsmPxObjectHistory'
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
                        'New-ScsmPxManagementPackBundle'
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
                        'Remove-ScsmPxFileAttachment'
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
                        'Rename-ScsmPxFileAttachment'
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
                        'Set-ScsmPxFileAttachment'
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
                        'LICENSE'
                        'NOTICE'
                        'ScsmPx.psd1'
                        'ScsmPx.psm1'
                        'functions\Add-ScsmPxFileAttachment.ps1'
                        'functions\Add-ScsmPxTroubleTicketComment.ps1'
                        'functions\Get-ScsmPxCommand.ps1'
                        'functions\Get-ScsmPxConnectedUser.ps1'
                        'functions\Get-ScsmPxDwName.ps1'
                        'functions\Get-ScsmPxEnterpriseManagementGroup.ps1'
                        'functions\Get-ScsmPxInstallDirectory.ps1'
                        'functions\Get-ScsmPxList.ps1'
                        'functions\Get-ScsmPxListItem.ps1'
                        'functions\Get-ScsmPxObject.ps1'
                        'functions\Get-ScsmPxObjectHistory.ps1'
                        'functions\Get-ScsmPxPrimaryManagementServer.ps1'
                        'functions\Get-ScsmPxRelatedObject.ps1'
                        'functions\Get-ScsmPxViewData.ps1'
                        'functions\New-ScsmPxManagementPackBundle.ps1'
                        'functions\New-ScsmPxObject.ps1'
                        'functions\New-ScsmPxObjectSearchCriteria.ps1'
                        'functions\New-ScsmPxProxyFunctionDefinition.ps1'
                        'functions\Remove-ScsmPxObject.ps1'
                        'functions\Rename-ScsmPxObject.ps1'
                        'functions\Reset-ScsmPxCommandCache.ps1'
                        'functions\Restore-ScsmPxObject.ps1'
                        'functions\Set-ScsmPxObject.ps1'
                        'helpers\ConvertTo-TypeProjectionCriteriaXml.ps1'
                        'helpers\Initialize-NativeScsmEnvironment.ps1'
                        'helpers\Join-CriteriaXml.ps1'
                        'xslt\emoCriteriaToProjectionCriteria.xslt'
                        )


          PrivateData = @{
                            PSData = @{
                                Tags = 'system center service manager scsm smlets'
                                LicenseUri = 'http://apache.org/licenses/LICENSE-2.0.txt'
                                ProjectUri = 'http://kirkmunro.github.io/ScsmPx'
                                IconUri = ''
                                ReleaseNotes = ''
                            }
                        }
}