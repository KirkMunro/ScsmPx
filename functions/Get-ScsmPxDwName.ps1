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
# SIG # Begin signature block
# MIIOgQYJKoZIhvcNAQcCoIIOcjCCDm4CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUojlw+/v3L0XXFh/aXBY0gi6t
# c7aggguAMIIFbjCCBFagAwIBAgIQClOp2Sk+GSooC3cNldGQvDANBgkqhkiG9w0B
# AQUFADCBtDELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8w
# HQYDVQQLExZWZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTswOQYDVQQLEzJUZXJtcyBv
# ZiB1c2UgYXQgaHR0cHM6Ly93d3cudmVyaXNpZ24uY29tL3JwYSAoYykxMDEuMCwG
# A1UEAxMlVmVyaVNpZ24gQ2xhc3MgMyBDb2RlIFNpZ25pbmcgMjAxMCBDQTAeFw0x
# MzA0MDgwMDAwMDBaFw0xNDA1MDgyMzU5NTlaMIGxMQswCQYDVQQGEwJDQTEPMA0G
# A1UECBMGUXVlYmVjMREwDwYDVQQHEwhHYXRpbmVhdTEeMBwGA1UEChQVUHJvdmFu
# Y2UgVGVjaG5vbG9naWVzMT4wPAYDVQQLEzVEaWdpdGFsIElEIENsYXNzIDMgLSBN
# aWNyb3NvZnQgU29mdHdhcmUgVmFsaWRhdGlvbiB2MjEeMBwGA1UEAxQVUHJvdmFu
# Y2UgVGVjaG5vbG9naWVzMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
# tOGLedLj/J3sKhtLW8+zCRxkMKxupX+C66p52LyvoxyWPppF4zkdVUKLknrXmJls
# 7KkojRWoDEhcQMztwkWbdcT9BT0IF47MiVnBFDqJID5fmubxaxYZoaYXu0M7YjuZ
# Dkd6wa+3Fg0IYL+8lkrS4OMpjUqyW2zTtJHM7JdhVf+aWdaRHSsxAzjtV+V8fTms
# 95W95Xaz5M5/i8K9+mE5FPo0zx6Fz8h8uJQWCv6nDW7j00xNQXh/q8BDcfZ5BFGu
# nTz3Aygz3xFC6P4Oz9uSCwKVqBiZnXHn7Hnm7Lugo7TucWCk75NMpVsV16Kpybxc
# Ns+WPLVIwFtBON55n+9wKQIDAQABo4IBezCCAXcwCQYDVR0TBAIwADAOBgNVHQ8B
# Af8EBAMCB4AwQAYDVR0fBDkwNzA1oDOgMYYvaHR0cDovL2NzYzMtMjAxMC1jcmwu
# dmVyaXNpZ24uY29tL0NTQzMtMjAxMC5jcmwwRAYDVR0gBD0wOzA5BgtghkgBhvhF
# AQcXAzAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy52ZXJpc2lnbi5jb20vcnBh
# MBMGA1UdJQQMMAoGCCsGAQUFBwMDMHEGCCsGAQUFBwEBBGUwYzAkBggrBgEFBQcw
# AYYYaHR0cDovL29jc3AudmVyaXNpZ24uY29tMDsGCCsGAQUFBzAChi9odHRwOi8v
# Y3NjMy0yMDEwLWFpYS52ZXJpc2lnbi5jb20vQ1NDMy0yMDEwLmNlcjAfBgNVHSME
# GDAWgBTPmanqeyb0S8mOj9fwBSbv49KnnTARBglghkgBhvhCAQEEBAMCBBAwFgYK
# KwYBBAGCNwIBGwQIMAYBAQABAf8wDQYJKoZIhvcNAQEFBQADggEBAErjEg19jH7P
# nPdp5lRPUIYWxxkV4J+196Fj0OC1QYAbwI66rwYf3MWbj46/I0WTxMoOodXLLz9g
# 2QI1YtaMjkgzUslrhm/iFuiKAhc+94dRpSycs/NeqzqA9mIQUQlyfngmWXqEcXRu
# 459cP86u+BSVltSw6p0+pF6LmaTyhEF7pbdAn3oN4v6tAyjG36vaguuhtQ6rA8/3
# nTkUYq2fmn4VvqNJIQLjTQ2Te15vaXNH69IrTK7IX81DqFQob1NcTwlK8qrac9lE
# SVpXHJFbQn+FX37HP/VvhTH0bsMOmoWrYy1nk9XzXq4VmmOmGw/DgG4I+gxvpJr6
# K2WA1+m6EpIwggYKMIIE8qADAgECAhBSAOWqJVb8GobtlsnUSzPHMA0GCSqGSIb3
# DQEBBQUAMIHKMQswCQYDVQQGEwJVUzEXMBUGA1UEChMOVmVyaVNpZ24sIEluYy4x
# HzAdBgNVBAsTFlZlcmlTaWduIFRydXN0IE5ldHdvcmsxOjA4BgNVBAsTMShjKSAy
# MDA2IFZlcmlTaWduLCBJbmMuIC0gRm9yIGF1dGhvcml6ZWQgdXNlIG9ubHkxRTBD
# BgNVBAMTPFZlcmlTaWduIENsYXNzIDMgUHVibGljIFByaW1hcnkgQ2VydGlmaWNh
# dGlvbiBBdXRob3JpdHkgLSBHNTAeFw0xMDAyMDgwMDAwMDBaFw0yMDAyMDcyMzU5
# NTlaMIG0MQswCQYDVQQGEwJVUzEXMBUGA1UEChMOVmVyaVNpZ24sIEluYy4xHzAd
# BgNVBAsTFlZlcmlTaWduIFRydXN0IE5ldHdvcmsxOzA5BgNVBAsTMlRlcm1zIG9m
# IHVzZSBhdCBodHRwczovL3d3dy52ZXJpc2lnbi5jb20vcnBhIChjKTEwMS4wLAYD
# VQQDEyVWZXJpU2lnbiBDbGFzcyAzIENvZGUgU2lnbmluZyAyMDEwIENBMIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA9SNLXqXXirsy6dRX9+/kxyZ+rRmY
# /qidfZT2NmsQ13WBMH8EaH/LK3UezR0IjN9plKc3o5x7gOCZ4e43TV/OOxTuhtTQ
# 9Sc1vCULOKeMY50Xowilq7D7zWpigkzVIdob2fHjhDuKKk+FW5ABT8mndhB/JwN8
# vq5+fcHd+QW8G0icaefApDw8QQA+35blxeSUcdZVAccAJkpAPLWhJqkMp22AjpAl
# e8+/PxzrL5b65Yd3xrVWsno7VDBTG99iNP8e0fRakyiF5UwXTn5b/aSTmX/fze+k
# de/vFfZH5/gZctguNBqmtKdMfr27Tww9V/Ew1qY2jtaAdtcZLqXNfjQtiQIDAQAB
# o4IB/jCCAfowEgYDVR0TAQH/BAgwBgEB/wIBADBwBgNVHSAEaTBnMGUGC2CGSAGG
# +EUBBxcDMFYwKAYIKwYBBQUHAgEWHGh0dHBzOi8vd3d3LnZlcmlzaWduLmNvbS9j
# cHMwKgYIKwYBBQUHAgIwHhocaHR0cHM6Ly93d3cudmVyaXNpZ24uY29tL3JwYTAO
# BgNVHQ8BAf8EBAMCAQYwbQYIKwYBBQUHAQwEYTBfoV2gWzBZMFcwVRYJaW1hZ2Uv
# Z2lmMCEwHzAHBgUrDgMCGgQUj+XTGoasjY5rw8+AatRIGCx7GS4wJRYjaHR0cDov
# L2xvZ28udmVyaXNpZ24uY29tL3ZzbG9nby5naWYwNAYDVR0fBC0wKzApoCegJYYj
# aHR0cDovL2NybC52ZXJpc2lnbi5jb20vcGNhMy1nNS5jcmwwNAYIKwYBBQUHAQEE
# KDAmMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC52ZXJpc2lnbi5jb20wHQYDVR0l
# BBYwFAYIKwYBBQUHAwIGCCsGAQUFBwMDMCgGA1UdEQQhMB+kHTAbMRkwFwYDVQQD
# ExBWZXJpU2lnbk1QS0ktMi04MB0GA1UdDgQWBBTPmanqeyb0S8mOj9fwBSbv49Kn
# nTAfBgNVHSMEGDAWgBR/02Wnwt3su/AwCfNDOfoCrzMxMzANBgkqhkiG9w0BAQUF
# AAOCAQEAViLmNKTEYctIuQGtVqhkD9mMkcS7zAzlrXqgIn/fRzhKLWzRf3EafOxw
# qbHwT+QPDFP6FV7+dJhJJIWBJhyRFEewTGOMu6E01MZF6A2FJnMD0KmMZG3ccZLm
# RQVgFVlROfxYFGv+1KTteWsIDEFy5zciBgm+I+k/RJoe6WGdzLGQXPw90o2sQj1l
# NtS0PUAoj5sQzyMmzEsgy5AfXYxMNMo82OU31m+lIL006ybZrg3nxZr3obQhkTNv
# huhYuyV8dA5Y/nUbYz/OMXybjxuWnsVTdoRbnK2R+qztk7pdyCFTwoJTY68SDVCH
# ERs9VFKWiiycPZIaCJoFLseTpUiR0zGCAmswggJnAgEBMIHJMIG0MQswCQYDVQQG
# EwJVUzEXMBUGA1UEChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsTFlZlcmlTaWdu
# IFRydXN0IE5ldHdvcmsxOzA5BgNVBAsTMlRlcm1zIG9mIHVzZSBhdCBodHRwczov
# L3d3dy52ZXJpc2lnbi5jb20vcnBhIChjKTEwMS4wLAYDVQQDEyVWZXJpU2lnbiBD
# bGFzcyAzIENvZGUgU2lnbmluZyAyMDEwIENBAhAKU6nZKT4ZKigLdw2V0ZC8MAkG
# BSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJ
# AzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMG
# CSqGSIb3DQEJBDEWBBR4tEVeXjQINpvyzbSauFg+KRY24jANBgkqhkiG9w0BAQEF
# AASCAQBMUxornMucOS3okVlRLFMqzjP4Iaxceo2njxru49kHe/XDhm8n50M8s7D6
# 6ioR5qTFeQvP/fFxWnzwGm0gXxGNSli/NG9+rfzocd5UBwXj0s9XTG2Ab5hpDa06
# omKbJGTTF0F97roqSg5iJ6NuccP5brk3+k6YdvEtGj6M87486RLznha242X++4Q+
# boj24DlvCJO8lp2XwTRrbHJGl7YuLRAvIaS98+4YYjf/azFjurxC7DKn1SoZs3k8
# /ufuBOBevxcppCQefP5lRW6ZB0gqb+Uyi/P838/DfbJbJHcAYbtsd1ToJ2qN14TQ
# H8RGja0+H/sFKcSqWkXRn7I7fa6C
# SIG # End signature block
