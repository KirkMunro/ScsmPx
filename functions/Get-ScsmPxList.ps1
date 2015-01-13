<#############################################################################
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
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Export-ModuleMember -Function Get-ScsmPxList