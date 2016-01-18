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

function Get-ScsmPxInstallDirectory {
    [CmdletBinding(DefaultParameterSetName='Default')]
    [OutputType([System.String])]
    param(
        [Parameter(ParameterSetName='Default')]
        [Parameter(Mandatory=$true, ParameterSetName='AsUser')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $ComputerName,

        [Parameter(Mandatory=$true, ParameterSetName='AsUser')]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )
    try {
        #region Define the script block that does the work.

        # Be careful if you modify this script block! It must support PowerShell version 2!
        $powerShellv2ScriptBlock = {
            #region Identify the SCSM Setup Registry Path.

            $scsmSetupKeyPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\System Center\2010\Service Manager\Setup'

            #endregion

            #region Verify SCSM is installed.

            if ((-not (Test-Path -LiteralPath $scsmSetupKeyPath)) -or
                (-not ($scsmInstallDirectoryProperty = Get-ItemProperty -LiteralPath $scsmSetupKeyPath -Name InstallDirectory -ErrorAction SilentlyContinue)) -or
                (-not (Test-Path -LiteralPath $scsmInstallDirectoryProperty.InstallDirectory))) {
                throw "Service Manager does not appear to be properly installed on ${env:COMPUTERNAME}."
            }

            #endregion

            #region Return the SCSM install directory to the caller.

            $scsmInstallDirectoryProperty.InstallDirectory -replace '\\{2,}','\' -replace '[\\/]+$'

            #endregion
        }

        #endregion

        if (($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('ComputerName')) -and
            (-not (Test-LocalComputer -ComputerName $ComputerName))) {
            #region If a remote computer name was provided, use PowerShell remoting to invoke the script block on the remote system.

            $passThruParameters = @{
                ComputerName = $ComputerName
                 ScriptBlock = $powerShellv2ScriptBlock
            }
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Credential') -and ($Credential -ne [System.Management.Automation.PSCredential]::Empty)) {
                $passThruParameters['Credential'] = $Credential
            }
            Invoke-Command @passThruParameters

            #endregion
        } else {
            #region Invoke the script block locally.

            & $powerShellv2ScriptBlock

            #endregion
        }
       
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Export-ModuleMember -Function Get-ScsmPxInstallDirectory