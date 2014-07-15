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
        throw
    }
}

Export-ModuleMember -Function Get-ScsmPxInstallDirectory