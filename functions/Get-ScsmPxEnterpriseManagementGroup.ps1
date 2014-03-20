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
            New-Object -TypeName Microsoft.EnterpriseManagement.EnterpriseManagementGroup -ArgumentList $item
        }

        #endregion
    } catch {
        throw
    }
}

Export-ModuleMember -Function Get-ScsmPxEnterpriseManagementGroup