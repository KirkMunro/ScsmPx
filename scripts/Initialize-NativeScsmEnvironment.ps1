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

        if (Get-Module -Name SMLets) {
            [System.String]$message = 'You cannot load the native SCSM cmdlets into a session where the SMLets module is loaded. The SMLets module defines a type extension that is not compatible with the native SCSM cmdlets. Unload the SMLets module and then try again.'
            [System.Management.Automation.SessionStateException]$exception = New-Object -TypeName System.Management.Automation.SessionStateException -ArgumentList $message
            [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'IncompatibilityException',([System.Management.Automation.ErrorCategory]::InvalidOperation),'Initialize-NativeScsmEnvironment'
            $PSCmdlet.ThrowTerminatingError($errorRecord)
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
            [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'FileNotFoundException',([System.Management.Automation.ErrorCategory]::ObjectNotFound),'Initialize-NativeScsmEnvironment'
            $PSCmdlet.ThrowTerminatingError($errorRecord)
            throw 
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

        #region Import the modules that are not loaded and set up the Management Group connection.

        if (-not (Get-Module -Name System.Center.Service.Manager)) {
            Import-Module $scsmModuleManifest.FullName
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
                # absorb warn them about the error and allow the user to connect on their own.
                Write-Warning "Unable to connect to the default SCSM Management Server ('${defaultScsmManagementServer}'). Use the New-SCManagementGroupConnection cmdlet to establish a valid connection to an SCSM Management Server that is online."
            }
        }
        if (-not (Get-Module -Name Microsoft.EnterpriseManagement.Warehouse.Cmdlets)) {
            Import-Module $scsmDwModuleManifest.FullName
        }

        #endregion
    } catch {
        throw
    }
}

try {
    #region Call the function to load the SCSM PowerShell modules into the global scope.

    # We can't put this inside the module, even though that might make sense, because we need to make
    # sure that it is invoked in the global scope if we want the modules loaded globally (which we do).
    Initialize-NativeScsmEnvironment

    #endregion

    #region Once the module is loaded, fix the Get-SCSMCommand function definition if it is present.

    # This is necessary to work around a bug in PowerShell's Get-Command cmdlet. When you invoke the
    # Get-Command cmdlet from within a script module, and request that it return the commands in that
    # module, it will not return any commands that belong to nested modules that are loaded by the
    # script module. The workaround is to explicitly include the nested module names in the list of
    # modules from which you want to return commands. In addition, we add the data warehouse module
    # to this so that we get all commands loaded by both of these modules.
    if (Test-Path -LiteralPath function:Get-SCSMCommand) {
        Set-Item function:Get-SCSMCommand -Value (
            # This script block _must_ be defined within the System.Center.Service.Manager module if
            # we want the command to still belong to that module and if we want the command to also
            # unload when that module is unloaded.
            & (Get-Module -Name System.Center.Service.Manager) {
                {Get-Command -Module System.Center.Service.Manager,Microsoft.EnterpriseManagement.Core.Cmdlets,Microsoft.EnterpriseManagement.ServiceManager.Cmdlets,Microsoft.EnterpriseManagement.Warehouse.Cmdlets}
            }
        )
    }

    #endregion
} catch {
    #region If an exception was raised, set a flag so that the module does not load.

    # This is a workaround to a PowerShell bug. If a ScriptToProcess script raises an exception,
    # the coresponding module will load anyway. This should not be the case. To workaround this
    # issue, we'll cache any exception we receive in a global variable and then raise that
    # exception from the module itself.
    $global:InitializeNativeScsmEnvironmentException = $_

    #endregion
} finally {
    #region Remove the Initialize-NativeScsmEnvironment function from the session.

    # This is only used on import, and we don't want leave any crumbs behind so we need to remove it
    # from the global scope if it is still there.
    if (Test-Path -LiteralPath function:Initialize-NativeScsmEnvironment) {
        Remove-Item -LiteralPath function:Initialize-NativeScsmEnvironment
    }

    #endregion
}