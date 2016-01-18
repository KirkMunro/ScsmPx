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

# .ExternalHelp ScsmPx-help.xml
function Get-ScsmPxEnterpriseManagementGroup {
    [CmdletBinding(DefaultParameterSetName='Empty')]
    [OutputType([Microsoft.EnterpriseManagement.EnterpriseManagementGroup])]
    param(
        [Parameter(Position=0, Mandatory=$true, ParameterSetName='FromComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $ComputerName,

        [Parameter(Position=0, Mandatory=$true, ParameterSetName='FromInstanceId')]
        [ValidateNotNullOrEmpty()]
        [System.Guid[]]
        $Id,

        [Parameter(Position=0, Mandatory=$true, ParameterSetName='FromManagementGroupName')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $ManagementGroupName,

        [Parameter(Position=0, Mandatory=$true, ParameterSetName='FromManagementGroupConnection')]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.Core.Connection.Connection[]]
        $SCSession,

        [Parameter(ParameterSetName='FromComputerName')]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )
    try {
        #region Identify the management group connection to use.

        switch ($PSCmdlet.ParameterSetName) {
            'Empty' {
                $managementGroupConnectionSettings = @(Get-SCManagementGroupConnection | Where-Object {$_.IsActive} | Select-Object -ExpandProperty Settings)
                break
            }
            'FromComputerName' {
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Credential')) {
                    $managementGroupConnectionSettings = @()
                    foreach ($item in $ComputerName) {
                        $managementGroupConnectionSettingsEntry = New-Object -TypeName Microsoft.EnterpriseManagement.EnterpriseManagementConnectionSettings -ArgumentList $item
                        $managementGroupConnectionSettingsEntry.Domain = $Credential.GetNetworkCredential().Domain
                        $managementGroupConnectionSettingsEntry.UserName = $Credential.GetNetworkCredential().UserName
                        $managementGroupConnectionSettingsEntry.Password = $Credential.Password
                        $managementGroupConnectionSettings += $managementGroupConnectionSettingsEntry
                    }
                } else {
                    $managementGroupConnectionSettings = @(Get-SCManagementGroupConnection @PSBoundParameters | Select-Object -ExpandProperty Settings)
                }
                break
            }
            'FromManagementGroupConnection' {
                $managementGroupConnectionSettings = @($SCSession | Select-Object -ExpandProperty Settings)
                break
            }
            default {
                $managementGroupConnectionSettings = @(Get-SCManagementGroupConnection @PSBoundParameters | Select-Object -ExpandProperty Settings)
                break
            }
        }
        if ($managementGroupConnectionSettings.Count -eq 0) {
            throw 'You must connect to a management group using New-SCManagementGroupConnection or provide connection details using another parameter set before you can retrieve an Enterprise Management Group object.'
        }

        #endregion

        #region Retrieve the Enterprise Management Group object for the chosen connection(s).

        foreach ($item in $managementGroupConnectionSettings) {
            New-Object -TypeName Microsoft.EnterpriseManagement.EnterpriseManagementGroup -ArgumentList $item -ErrorAction Stop
        }

        #endregion
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Export-ModuleMember -Function Get-ScsmPxEnterpriseManagementGroup