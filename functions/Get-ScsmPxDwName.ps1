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

# .ExternalHelp ScsmPx-help.xml
function Get-ScsmPxDwName {
    [CmdletBinding(DefaultParameterSetName='FromManagementGroupConnection')]
    [OutputType([System.String])]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='FromComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ComputerName,

        [Parameter(ParameterSetName='FromComputerName')]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter(ParameterSetName='FromManagementGroupConnection')]
        [ValidateNotNull()]
        [Microsoft.SystemCenter.Core.Connection.Connection]
        $SCSession
    )
    try {
        #region Identify SCSM Registry paths.

        $scsmSetupKeyPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\System Center\2010\Service Manager\Setup'
        $scsmSdkServiceKeyPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\System Center\2010\Common\SDK Service'

        #endregion

        if ((Test-Path -LiteralPath $scsmSetupKeyPath) -and
            (($scsmSetupProperties = Get-ItemProperty -LiteralPath $scsmSetupKeyPath -ErrorAction SilentlyContinue)) -and
            (Get-Member -InputObject $scsmSetupProperties -Name ServerVersion -ErrorAction SilentlyContinue) -and
            $scsmSetupProperties.ServerVersion -and
            (Test-Path -LiteralPath $scsmSdkServiceKeyPath) -and
            ($scsmSdkServiceProperties = Get-ItemProperty -LiteralPath $scsmSdkServiceKeyPath -ErrorAction SilentlyContinue) -and
            (Get-Member -InputObject $scsmSdkServiceProperties -Name 'SDK Service Type' -ErrorAction SilentlyContinue) -and
            ($scsmSdkServiceProperties.'SDK Service Type' -eq 2)) {
            #region If we're on a SCSM DW Server, return its name.

            $env:COMPUTERNAME

            #endregion
        } else {
            #region Prepare for splatting of remoting parameters if required.

            $remotingParameters = @{}
            foreach ($remotingParameterName in 'ComputerName','Credential','SCSession') {
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey($remotingParameterName)) {
                    $remotingParameters[$remotingParameterName] = $PSCmdlet.MyInvocation.BoundParameters.$remotingParameterName
                }
            }

            #endregion

            #region Get the enterprise management group object to look up the DW name.

            if (-not ($emg = Get-ScsmPxEnterpriseManagementGroup @remotingParameters)) {
                throw "Failed to create an Enterprise Management Group object for $(if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('ComputerName')) {$ComputerName} else {'localhost'})."
            }

            #endregion

            #region Verify that we can identify the SCSM DW.

            if ((-not $emg.DataWarehouse) -or
                (-not ($dwConfiguration = $emg.DataWarehouse.GetDataWarehouseConfiguration()))) {
                throw "Unable to retrieve the Data Warehouse configuration for $(if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('ComputerName')) {$ComputerName} else {'localhost'})."
            }

            #endregion

            #region Return the data warehouse name to the caller.

            $dwConfiguration.Server

            #endregion
        }

        #endregion
    } catch {
        throw
    }
}

Export-ModuleMember -Function Get-ScsmPxDwName