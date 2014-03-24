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

function Initialize-ScsmPxModule {
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
            [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'IncompatibilityException',([System.Management.Automation.ErrorCategory]::InvalidOperation),'Initialize-ScsmPxModule'
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
            [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'FileNotFoundException',([System.Management.Automation.ErrorCategory]::ObjectNotFound),'Initialize-ScsmPxModule'
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
    Initialize-ScsmPxModule

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
    $global:InitializeScsmPxModuleException = $_

    #endregion
} finally {
    #region Remove the Initialize-ScsmPxModule function from the session.

    # This is only used on import, and we don't want leave any crumbs behind so we need to remove it
    # from the global scope if it is still there.
    if (Test-Path -LiteralPath function:Initialize-ScsmPxModule) {
        Remove-Item -LiteralPath function:Initialize-ScsmPxModule
    }

    #endregion
}
# SIG # Begin signature block
# MIIZKQYJKoZIhvcNAQcCoIIZGjCCGRYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUfs3meZi45wKezTvEcW380K1v
# hIygghQZMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggVuMIIEVqADAgECAhAKU6nZKT4ZKigLdw2V0ZC8MA0GCSqGSIb3DQEBBQUAMIG0
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsT
# FlZlcmlTaWduIFRydXN0IE5ldHdvcmsxOzA5BgNVBAsTMlRlcm1zIG9mIHVzZSBh
# dCBodHRwczovL3d3dy52ZXJpc2lnbi5jb20vcnBhIChjKTEwMS4wLAYDVQQDEyVW
# ZXJpU2lnbiBDbGFzcyAzIENvZGUgU2lnbmluZyAyMDEwIENBMB4XDTEzMDQwODAw
# MDAwMFoXDTE0MDUwODIzNTk1OVowgbExCzAJBgNVBAYTAkNBMQ8wDQYDVQQIEwZR
# dWViZWMxETAPBgNVBAcTCEdhdGluZWF1MR4wHAYDVQQKFBVQcm92YW5jZSBUZWNo
# bm9sb2dpZXMxPjA8BgNVBAsTNURpZ2l0YWwgSUQgQ2xhc3MgMyAtIE1pY3Jvc29m
# dCBTb2Z0d2FyZSBWYWxpZGF0aW9uIHYyMR4wHAYDVQQDFBVQcm92YW5jZSBUZWNo
# bm9sb2dpZXMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC04Yt50uP8
# newqG0tbz7MJHGQwrG6lf4LrqnnYvK+jHJY+mkXjOR1VQouSeteYmWzsqSiNFagM
# SFxAzO3CRZt1xP0FPQgXjsyJWcEUOokgPl+a5vFrFhmhphe7QztiO5kOR3rBr7cW
# DQhgv7yWStLg4ymNSrJbbNO0kczsl2FV/5pZ1pEdKzEDOO1X5Xx9Oaz3lb3ldrPk
# zn+Lwr36YTkU+jTPHoXPyHy4lBYK/qcNbuPTTE1BeH+rwENx9nkEUa6dPPcDKDPf
# EULo/g7P25ILApWoGJmdcefseebsu6CjtO5xYKTvk0ylWxXXoqnJvFw2z5Y8tUjA
# W0E43nmf73ApAgMBAAGjggF7MIIBdzAJBgNVHRMEAjAAMA4GA1UdDwEB/wQEAwIH
# gDBABgNVHR8EOTA3MDWgM6Axhi9odHRwOi8vY3NjMy0yMDEwLWNybC52ZXJpc2ln
# bi5jb20vQ1NDMy0yMDEwLmNybDBEBgNVHSAEPTA7MDkGC2CGSAGG+EUBBxcDMCow
# KAYIKwYBBQUHAgEWHGh0dHBzOi8vd3d3LnZlcmlzaWduLmNvbS9ycGEwEwYDVR0l
# BAwwCgYIKwYBBQUHAwMwcQYIKwYBBQUHAQEEZTBjMCQGCCsGAQUFBzABhhhodHRw
# Oi8vb2NzcC52ZXJpc2lnbi5jb20wOwYIKwYBBQUHMAKGL2h0dHA6Ly9jc2MzLTIw
# MTAtYWlhLnZlcmlzaWduLmNvbS9DU0MzLTIwMTAuY2VyMB8GA1UdIwQYMBaAFM+Z
# qep7JvRLyY6P1/AFJu/j0qedMBEGCWCGSAGG+EIBAQQEAwIEEDAWBgorBgEEAYI3
# AgEbBAgwBgEBAAEB/zANBgkqhkiG9w0BAQUFAAOCAQEASuMSDX2Mfs+c92nmVE9Q
# hhbHGRXgn7X3oWPQ4LVBgBvAjrqvBh/cxZuPjr8jRZPEyg6h1csvP2DZAjVi1oyO
# SDNSyWuGb+IW6IoCFz73h1GlLJyz816rOoD2YhBRCXJ+eCZZeoRxdG7jn1w/zq74
# FJWW1LDqnT6kXouZpPKEQXult0Cfeg3i/q0DKMbfq9qC66G1DqsDz/edORRirZ+a
# fhW+o0khAuNNDZN7Xm9pc0fr0itMrshfzUOoVChvU1xPCUryqtpz2URJWlcckVtC
# f4Vffsc/9W+FMfRuww6ahatjLWeT1fNerhWaY6YbD8OAbgj6DG+kmvorZYDX6boS
# kjCCBgowggTyoAMCAQICEFIA5aolVvwahu2WydRLM8cwDQYJKoZIhvcNAQEFBQAw
# gcoxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5WZXJpU2lnbiwgSW5jLjEfMB0GA1UE
# CxMWVmVyaVNpZ24gVHJ1c3QgTmV0d29yazE6MDgGA1UECxMxKGMpIDIwMDYgVmVy
# aVNpZ24sIEluYy4gLSBGb3IgYXV0aG9yaXplZCB1c2Ugb25seTFFMEMGA1UEAxM8
# VmVyaVNpZ24gQ2xhc3MgMyBQdWJsaWMgUHJpbWFyeSBDZXJ0aWZpY2F0aW9uIEF1
# dGhvcml0eSAtIEc1MB4XDTEwMDIwODAwMDAwMFoXDTIwMDIwNzIzNTk1OVowgbQx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5WZXJpU2lnbiwgSW5jLjEfMB0GA1UECxMW
# VmVyaVNpZ24gVHJ1c3QgTmV0d29yazE7MDkGA1UECxMyVGVybXMgb2YgdXNlIGF0
# IGh0dHBzOi8vd3d3LnZlcmlzaWduLmNvbS9ycGEgKGMpMTAxLjAsBgNVBAMTJVZl
# cmlTaWduIENsYXNzIDMgQ29kZSBTaWduaW5nIDIwMTAgQ0EwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQD1I0tepdeKuzLp1Ff37+THJn6tGZj+qJ19lPY2
# axDXdYEwfwRof8srdR7NHQiM32mUpzejnHuA4Jnh7jdNX847FO6G1ND1JzW8JQs4
# p4xjnRejCKWrsPvNamKCTNUh2hvZ8eOEO4oqT4VbkAFPyad2EH8nA3y+rn59wd35
# BbwbSJxp58CkPDxBAD7fluXF5JRx1lUBxwAmSkA8taEmqQynbYCOkCV7z78/HOsv
# lvrlh3fGtVayejtUMFMb32I0/x7R9FqTKIXlTBdOflv9pJOZf9/N76R17+8V9kfn
# +Bly2C40Gqa0p0x+vbtPDD1X8TDWpjaO1oB21xkupc1+NC2JAgMBAAGjggH+MIIB
# +jASBgNVHRMBAf8ECDAGAQH/AgEAMHAGA1UdIARpMGcwZQYLYIZIAYb4RQEHFwMw
# VjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cudmVyaXNpZ24uY29tL2NwczAqBggr
# BgEFBQcCAjAeGhxodHRwczovL3d3dy52ZXJpc2lnbi5jb20vcnBhMA4GA1UdDwEB
# /wQEAwIBBjBtBggrBgEFBQcBDARhMF+hXaBbMFkwVzBVFglpbWFnZS9naWYwITAf
# MAcGBSsOAwIaBBSP5dMahqyNjmvDz4Bq1EgYLHsZLjAlFiNodHRwOi8vbG9nby52
# ZXJpc2lnbi5jb20vdnNsb2dvLmdpZjA0BgNVHR8ELTArMCmgJ6AlhiNodHRwOi8v
# Y3JsLnZlcmlzaWduLmNvbS9wY2EzLWc1LmNybDA0BggrBgEFBQcBAQQoMCYwJAYI
# KwYBBQUHMAGGGGh0dHA6Ly9vY3NwLnZlcmlzaWduLmNvbTAdBgNVHSUEFjAUBggr
# BgEFBQcDAgYIKwYBBQUHAwMwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFZlcmlT
# aWduTVBLSS0yLTgwHQYDVR0OBBYEFM+Zqep7JvRLyY6P1/AFJu/j0qedMB8GA1Ud
# IwQYMBaAFH/TZafC3ey78DAJ80M5+gKvMzEzMA0GCSqGSIb3DQEBBQUAA4IBAQBW
# IuY0pMRhy0i5Aa1WqGQP2YyRxLvMDOWteqAif99HOEotbNF/cRp87HCpsfBP5A8M
# U/oVXv50mEkkhYEmHJEUR7BMY4y7oTTUxkXoDYUmcwPQqYxkbdxxkuZFBWAVWVE5
# /FgUa/7UpO15awgMQXLnNyIGCb4j6T9Emh7pYZ3MsZBc/D3SjaxCPWU21LQ9QCiP
# mxDPIybMSyDLkB9djEw0yjzY5TfWb6UgvTTrJtmuDefFmvehtCGRM2+G6Fi7JXx0
# Dlj+dRtjP84xfJuPG5aexVN2hFucrZH6rO2Tul3IIVPCglNjrxINUIcRGz1UUpaK
# LJw9khoImgUux5OlSJHTMYIEejCCBHYCAQEwgckwgbQxCzAJBgNVBAYTAlVTMRcw
# FQYDVQQKEw5WZXJpU2lnbiwgSW5jLjEfMB0GA1UECxMWVmVyaVNpZ24gVHJ1c3Qg
# TmV0d29yazE7MDkGA1UECxMyVGVybXMgb2YgdXNlIGF0IGh0dHBzOi8vd3d3LnZl
# cmlzaWduLmNvbS9ycGEgKGMpMTAxLjAsBgNVBAMTJVZlcmlTaWduIENsYXNzIDMg
# Q29kZSBTaWduaW5nIDIwMTAgQ0ECEApTqdkpPhkqKAt3DZXRkLwwCQYFKw4DAhoF
# AKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisG
# AQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcN
# AQkEMRYEFKNBgzmm0zk0+MapHAvGzhn4OiRZMA0GCSqGSIb3DQEBAQUABIIBAHPr
# HgmIut3kDrOikXNnA+KCgO+QTzaiTnk3g4a/6qD3jWyyWJvyrTd6SvR39EEeTkqR
# Tx/vQZjerf0yCSRhkh6ZNMDfy5EaPL8v2KChrS5vRxI3daWKyhb6/flbhzt8yuMC
# dVQqPmNUdKsKL7Bnh66I9gmvHEqI2r4iUPJ0fXZjp5rgxfp9VlLcfR0lE0g8Fyzh
# Sa3n1+9JHZuP/9mNDGCqnw+Huck0mLHIbrPaUzIQLevQQuCFS4Jr7Mvip8AwZTmP
# V+93uWJnxIhNo+N4tfD0VRaeFhml4N6Y3FY8X2bIArGVePje2d0n5ZbxN08iaJ8j
# qaiqMWdtxSPRiYr1Vg6hggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBe
# MQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAu
# BgNVBAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQ
# Ds/0OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqG
# SIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTQwMzI0MjAwNTEwWjAjBgkqhkiG9w0B
# CQQxFgQUjcSEoqdmRWFG1GOXOhEfIWb/wNQwDQYJKoZIhvcNAQEBBQAEggEAY+/5
# Y0t+ymwYBHraIPurnqRuTTrromz4HdKNLelF5DN3H8P2e+y/1TKkzcO0RPe+g2bB
# aJ1dAPT3me4DKDnM/IfWCo43GQaIqGnkhu1NjZirNJasy4zMhFtAeQIz7xbHFVS6
# 1bN8hV6HmIJLIHprHbb5U6MlJcK+kvz7lNYSnPxiPTaB1nQIEkmGditsArPVccnE
# ol0+dmR/aTGrp2Ku2Dg2BEHgaABhAjeq0LyOOqDJwHLJ39+usc1j5ZQfUsxZw3f/
# nNdKeh3Odczp0+9o5G7nUpgRmpgn7UwMzKUpG2azjltI2JPq/9dg0m6knzt8QhIJ
# c2O52LFZ4mny5jZuKg==
# SIG # End signature block
