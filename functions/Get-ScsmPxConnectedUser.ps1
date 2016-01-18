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
function Get-ScsmPxConnectedUser {
    [CmdletBinding(DefaultParameterSetName='FromManagementGroupConnection')]
    [OutputType('ScsmPx.ConnectedUser')]
    param(
        [Parameter(ParameterSetName='FromManagementGroupConnection')]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.Core.Connection.Connection[]]
        $SCSession,

        [Parameter(Mandatory=$true, ParameterSetName='FromComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $ComputerName,

        [Parameter(ParameterSetName='FromComputerName')]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )
    try {
        #region Get the Enterprise Management Group.

        $emg = Get-ScsmPxEnterpriseManagementGroup @PSBoundParameters

        #endregion

        #region Return a record for each user that is connected indicating how many times they are connected.

        foreach ($entry in $emg.GetConnectedUserNames() | Group-Object) {
            $domain,$userName = $entry.Group[0] -split '\\'
            try {
                $user = Get-ScsmPxUserOrGroup -Name "${domain}.${userName}" @PSBoundParameters
            } catch {
                $user = $entry.Group
            }
            $connectedUserRecord = New-Object -TypeName PSCustomObject
            Add-Member -InputObject $connectedUserRecord -MemberType NoteProperty -Name User -Value $user
            Add-Member -InputObject $connectedUserRecord -MemberType NoteProperty -Name ConnectionCount -Value $entry.Count
            $connectedUserRecord.PSTypeNames.Insert(0, 'ScsmPx.ConnectedUser')
            $connectedUserRecord 
        }

        #endregion
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Export-ModuleMember -Function Get-ScsmPxConnectedUser