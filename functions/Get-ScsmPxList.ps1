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
function Get-ScsmPxList {
    [CmdletBinding(DefaultParameterSetName='FromManagementGroupConnection')]
    [OutputType('Microsoft.EnterpriseManagement.Configuration.ManagementPackEnumeration')]
    param(
        [Parameter(Position=0)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Name = '*',

        [Parameter(ParameterSetName='FromManagementGroupConnection')]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.Core.Connection.Connection[]]
        $SCSession,

        [Parameter(Mandatory=$true, ParameterSetName='FromManagementPack')]
        [ValidateNotNullOrEmpty()]
        [Microsoft.EnterpriseManagement.Configuration.ManagementPack[]]
        $ManagementPack,

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
        #region Look up the Enterprise Management Group.

        switch ($PSCmdlet.ParameterSetName) {
            'FromManagementPack' {
                $emgCollection = @()
                foreach ($mp in $ManagementPack) {
                    if ($emgCollection -notcontains $mp.Store) {
                        $emgCollection += $mp.Store
                    }
                }
                break
            }
            'FromManagementGroupConnection' {
                $passThruParameters = @{}
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('SCSession')) {
                    $passThruParameters['SCSession'] = $SCSession
                }
                $emgCollection = @(Get-ScsmPxEnterpriseManagementGroup @passThruParameters)
                break
            }
            'FromComputerName' {
                $passThruParameters = @{
                    ComputerName = $ComputerName
                }
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Credential')) {
                    $passThruParameters['Credential'] = $Credential
                }
                $emgCollection = @(Get-ScsmPxEnterpriseManagementGroup @passThruParameters)
                break
            }
        }

        #endregion

        #region Find any top-level enumerations with a name that matches our input parameter and return them.

        foreach ($emg in $emgCollection) {
            $enumerations = $emg.EntityTypes.GetTopLevelEnumerations()
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('ManagementPack')) {
                $enumerations = @($enumerations | Where-Object {$ManagementPack -contains $_.GetManagementPack()})
            }
            foreach ($item in $Name) {
                foreach ($enumeration in $enumerations) {
                    if ($item -match '[\?\*]') {
                        if ($enumeration.Name -like $item) {
                            $enumeration
                        }
                    } elseif ($enumeration.Name -eq $item) {
                        $enumeration
                        break
                    }
                }
            }
        }

        #endregion
    } catch {
        throw
    }
}

Export-ModuleMember -Function Get-ScsmPxList