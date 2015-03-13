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

function Initialize-NativeScsmEnvironment {
    [CmdletBinding()]
    param()
    try {
        #region Return immediately if the SCSM native modules are already loaded.

        if ((Get-Module -Name System.Center.Service.Manager) -and
            (Get-Module -Name Microsoft.EnterpriseManagement.Warehouse.Cmdlets)) {
            return
        }

        #endregion

        #region Raise an error if the SMLets module is loaded (compatibility issues).

        if ($smlets = Get-Module -Name SMLets) {
            [System.String]$message = 'You cannot load the native SCSM cmdlets into a session where the SMLets module is loaded. The SMLets module defines a type extension that is not compatible with the native SCSM cmdlets. Unload the SMLets module and then try again.'
            [System.Management.Automation.SessionStateException]$exception = New-Object -TypeName System.Management.Automation.SessionStateException -ArgumentList $message
            [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'IncompatibilityException',([System.Management.Automation.ErrorCategory]::InvalidOperation),$smlets
            throw $errorRecord
        }

        #endregion

        #region Remove any conflicting SMLets type configuration files from the session.

        # This is necessary because PowerShell doesn't properly clean up after itself when
        # modules are removed from the session. The location of these files changed between
        # PowerShell 2.0 and 3.0, so we need to take extra steps to support 2.0 and later.
        if ($PSVersionTable.PSVersion -ge [System.Version]'3.0') {
            $sessionStateProperty = 'InitialSessionState'
        } else {
            $sessionStateProperty = 'RunspaceConfiguration'
        }
        $typePs1xmlFiles = @($Host.Runspace.${sessionStateProperty}.Types)
        for ($index = 0; $index -lt $typePs1xmlFiles.Count; $index++) {
            if ($typePs1xmlFiles[$index].FileName -match 'SMLets\.Types\.ps1xml$') {
                $Host.Runspace.${sessionStateProperty}.Types.RemoveItem($index)
                Update-TypeData
                break
            }
        }

        #endregion

        #region Define the SCSM Registry key paths that are used to initialize this module.

        $scsmSetupKeyPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\System Center\2010\Service Manager\Setup'
        $scsmUserSettingsKeyPath = 'Registry::HKEY_CURRENT_USER\Software\Microsoft\System Center\2010\Service Manager\Console\User Settings'
        $scsmSdkServiceKeyPath = 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\System Center\2010\Common\SDK Service'

        #endregion

        #region Verify that the SCSM modules are installed on the current machine.

        if ((-not (Test-Path -LiteralPath $scsmSetupKeyPath)) -or
            (-not ($scsmSetupKeyProperties = Get-ItemProperty -LiteralPath $scsmSetupKeyPath -Name InstallDirectory -ErrorAction SilentlyContinue)) -or
            (-not (Test-Path -LiteralPath $scsmSetupKeyProperties.InstallDirectory)) -or
            (-not ($scsmModuleManifest = Get-Item -LiteralPath "$($scsmSetupKeyProperties.InstallDirectory)\PowerShell\System.Center.Service.Manager.psd1" -ErrorAction SilentlyContinue)) -or
            (-not ($scsmDwModuleManifest = Get-Item -LiteralPath "$($scsmSetupKeyProperties.InstallDirectory)\Microsoft.EnterpriseManagement.Warehouse.Cmdlets.psd1" -ErrorAction SilentlyContinue))) {
            [System.String]$message = 'The Service Manager cmdlets do not appear to be properly installed on this system.'
            [System.Management.Automation.ItemNotFoundException]$exception = New-Object -TypeName System.Management.Automation.ItemNotFoundException -ArgumentList $message
            [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'FileNotFoundException',([System.Management.Automation.ErrorCategory]::ObjectNotFound),$scsmSetupKeyPath
            throw $errorRecord
        }

        #endregion

        #region Try to identify the default SCSM Management Server based on the Registry settings.

        if ((Test-Path -LiteralPath $scsmUserSettingsKeyPath) -and
            ($scsmUserSettingsKeyProperties = Get-ItemProperty -LiteralPath $scsmUserSettingsKeyPath -Name SDKServiceMachine -ErrorAction SilentlyContinue)) {
            # This identifies the default SCSM Management Server for the current user
            $defaultScsmManagementServer = $scsmUserSettingsKeyProperties.SDKServiceMachine
        } elseif ((Test-Path -LiteralPath $scsmSdkServiceKeyPath) -and
                  ($scsmSdkServiceKeyProperties = Get-ItemProperty -LiteralPath $scsmSdkServiceKeyPath -Name 'SDK Service Type' -ErrorAction SilentlyContinue) -and
                  ($scsmSdkServiceKeyProperties.'SDK Service Type' -eq 1)) {
            # This identifies the default as the current machine if run on an SCSM Management Server
            $defaultScsmManagementServer = $env:COMPUTERNAME
        } else {
            # If the default SCSM Management server cannot be found, leave it up to the user to
            # create their SCSM connection using New-SCManagementGroupConnection on their own.
            # This is necessary for service accounts which may never have been used to open the
            # SCSM Management console. These accounts can connect and use the SCSM cmdlets fine,
            # so no default management server is required for them to work.
            $defaultScsmManagementServer = $null
        }

        #endregion

        #region Import the modules that are not loaded into the global scope and set up the Management Group connection.

        if (-not (Get-Module -Name System.Center.Service.Manager)) {
            Import-Module -Name $scsmModuleManifest.FullName -Global
        }
        if ($defaultScsmManagementServer) {
            try {
                # Ensure that we can ping the default SCSM Management Server before we try to connect to it.
                if (-not (Test-Connection -ComputerName $defaultScsmManagementServer -Count 2 -ErrorAction SilentlyContinue)) {
                    throw
                }
                New-SCManagementGroupConnection -ComputerName $defaultScsmManagementServer -ErrorAction Stop
            } catch {
                # This will fail if the default management server is offline, in which case we
                # warn them about the error and allow the user to connect on their own.
                Write-Warning "Unable to connect to the default SCSM Management Server ('${defaultScsmManagementServer}'). Use the New-SCManagementGroupConnection cmdlet to establish a valid connection to an SCSM Management Server that is online."
            }
        }
        if (-not (Get-Module -Name Microsoft.EnterpriseManagement.Warehouse.Cmdlets)) {
            Import-Module -Name $scsmDwModuleManifest.FullName -Global
        }

        #endregion
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}