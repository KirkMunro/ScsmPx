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

            # This will throw an exception if it fails, so we can count on $emg being set if it succeeds.
            $emg = Get-ScsmPxEnterpriseManagementGroup @remotingParameters

            #endregion

            #region Verify that we can identify the SCSM DW.

            if ((-not $emg.DataWarehouse) -or
                (-not ($dwConfiguration = $emg.DataWarehouse.GetDataWarehouseConfiguration()))) {
                [System.String]$message = "Unable to retrieve the Data Warehouse configuration for $(if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('ComputerName')) {$ComputerName} else {'localhost'})."
                [System.Management.Automation.ItemNotFoundException]$exception = New-Object -TypeName System.Management.Automation.ItemNotFoundException -ArgumentList $message
                [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,$exception.GetType().Name,([System.Management.Automation.ErrorCategory]::ObjectNotFound),$emg
                throw $errorRecord
            }

            #endregion

            #region Return the data warehouse name to the caller.

            $dwConfiguration.Server

            #endregion
        }

        #endregion
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Export-ModuleMember -Function Get-ScsmPxDwName