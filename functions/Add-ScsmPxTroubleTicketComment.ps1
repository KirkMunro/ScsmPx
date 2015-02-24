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
function Add-ScsmPxTroubleTicketComment {
    [CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName='AddUserComment')]
    [OutputType([Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance])]
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            $classHierarchy = @($_.EnterpriseManagementObject.GetClasses())
            $classHierarchy += $classHierarchy[0].GetBaseTypes()
            $classNameHierarchy = $classHierarchy | Select-Object -ExpandProperty Name
            if ($classNameHierarchy -notcontains 'System.WorkItem.TroubleTicket') {
                throw "Cannot bind parameter 'InputObject'. ""$($_.DisplayName)"" is not of type ""System.WorkItem.TroubleTicket"". Error: ""Invalid type provided in InputObject parameter""."
            }
            $true
        })]
        [Alias('EnterpriseManagementInstance')]
        [Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance[]]
        $InputObject,

        [Parameter(Position=1, Mandatory=$true, ParameterSetName='AddUserComment')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $UserComment,

        [Parameter(Position=1, Mandatory=$true, ParameterSetName='AddAnalystComment')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $AnalystComment,

        [Parameter(Position=1, Mandatory=$true, ParameterSetName='AddAuditComment')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $AuditComment,

        [Parameter(ParameterSetName='AddAnalystComment')]
        [System.Management.Automation.SwitchParameter]
        $Private,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $PassThru
    )
    begin {
        try {
            #region Define an entity cache to store relationships, classes and instances that should only be looked up once.

            $entityCache = @{}

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    process {
        try {
            foreach ($item in $InputObject) {
                #region Get the Enterprise Management Group (EMG) for the trouble ticket.

                $emg = $item.EnterpriseManagementObject.ManagementGroup

                #endregion

                #region If we have not created a cache entry for this EMG yet, create one.

                if ($entityCache.Keys -notcontains $emg.Id) {
                    $entityCache[$emg.Id] = @{}
                }

                #endregion

                #region Identify the comment value and the associated class and relationship properties that are required.

                switch ($PSCmdlet.ParameterSetName) {
                    'AddUserComment' {
                        $comment = $UserComment
                        $commentClassName = 'System.WorkItem.TroubleTicket.UserCommentLog'
                        $commentClassId = 'a3d4e16f-5e8a-18ba-9198-d9815194c986'
                        $commentRelationshipName = 'System.WorkItem.TroubleTicketHasUserComment'
                        $commentRelationshipId = 'ce423786-16dd-da9c-fb7b-21ab5189e12b'
                        break
                    }
                    'AddAnalystComment' {
                        $comment = $AnalystComment
                        $commentClassName = 'System.WorkItem.TroubleTicket.AnalystCommentLog'
                        $commentClassId = 'f14b70f4-878c-c0e1-b5c1-06ca22d05d40'
                        $commentRelationshipName = 'System.WorkItem.TroubleTicketHasAnalystComment'
                        $commentRelationshipId = '835a64cd-7d41-10eb-e5e4-365ea2efc2ea'
                        break
                    }
                    'AddAuditComment' {
                        $comment = $AuditComment
                        $commentClassName = 'System.WorkItem.TroubleTicket.AuditCommentLog'
                        $commentClassId = 'c06a4eb0-d21e-1838-0995-ee817b3aac4a'
                        $commentRelationshipName = 'System.WorkItem.TroubleTicketHasAuditComment'
                        $commentRelationshipId = '5ad35f7b-8ef4-6c4f-ec6d-7a49b0d8f7d7'
                        break
                    }
                }

                #endregion

                #region If the class or relationship are not cached yet, add them to the cache.

                if ($entityCache[$emg.Id] -notcontains $commentClassName) {
                    $entityCache[$emg.Id][$commentClassName] = $emg.EntityTypes.GetClass($commentClassId)
                }
                if ($entityCache[$emg.Id] -notcontains $commentRelationshipName) {
                    $entityCache[$emg.Id][$commentRelationshipName] = $emg.EntityTypes.GetRelationshipClass($commentRelationshipId)
                }

                #endregion

                #region Create a new comment (but don't commit it yet!).

                $commentClass = $entityCache[$emg.Id][$commentClassName]
                $commentEmo = New-Object -TypeName Microsoft.EnterpriseManagement.Common.CreatableEnterpriseManagementObject -ArgumentList $emg,$commentClass
                $commentEmo[$commentClass, 'Id'].Value = [System.Guid]::NewGuid().ToString()
                $commentEmo[$null, 'Comment'].Value = $comment
                $commentEmo[$null, 'EnteredBy'].Value = $emg.GetUserName()
                $commentEmo[$null, 'EnteredDate'].Value = [System.DateTime]::UtcNow
                if ($PSCmdlet.ParameterSetName -eq 'AddAnalystComment') {
                    # Analyst comments can be public or private, so we need to set an additional property on them
                    $commentEmo[$null, 'IsPrivate'].Value = $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Private') -and $Private
                }

                #endregion

                #region Create the relationship between the trouble ticket and the comment.

                $commentRelationship = $entityCache[$emg.Id][$commentRelationshipName]
                $commentRelationshipEmro = New-Object -TypeName Microsoft.EnterpriseManagement.Common.CreatableEnterpriseManagementRelationshipObject -ArgumentList $emg,$commentRelationship
                $commentRelationshipEmro.SetSource($item)
                $commentRelationshipEmro.SetTarget($commentEmo)
                $commentRelationshipEmro.Commit()

                #endregion

                #region Now commit the comment.

                # This is committed at the very end because it is part of a membership
                # relationship (meaning that the object itself cannot exist without it
                # being a member of something). If you were to commit this first and then
                # try to create the relationship, the assignment of the target would fail
                # because the object must be part of a relationship at the time that it
                # is committed to the CMDB.

                $commentEmo.Commit()

                #endregion

                #region If the caller requested it, return the trouble ticket to them.

                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('PassThru') -and $PassThru) {
                    $item
                }

                #endregion
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

Export-ModuleMember -Function Add-ScsmPxTroubleTicketComment
# SIG # Begin signature block
# MIIZKQYJKoZIhvcNAQcCoIIZGjCCGRYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQURyCsnbtOmkfUKhfawBZBvD9v
# xc6gghQZMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
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
# ggVuMIIEVqADAgECAhBaCt8RSzACYI8wikJ38dScMA0GCSqGSIb3DQEBBQUAMIG0
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsT
# FlZlcmlTaWduIFRydXN0IE5ldHdvcmsxOzA5BgNVBAsTMlRlcm1zIG9mIHVzZSBh
# dCBodHRwczovL3d3dy52ZXJpc2lnbi5jb20vcnBhIChjKTEwMS4wLAYDVQQDEyVW
# ZXJpU2lnbiBDbGFzcyAzIENvZGUgU2lnbmluZyAyMDEwIENBMB4XDTE0MDUwNzAw
# MDAwMFoXDTE2MDYwNTIzNTk1OVowgbExCzAJBgNVBAYTAkNBMQ8wDQYDVQQIEwZR
# dWViZWMxETAPBgNVBAcTCEdhdGluZWF1MR4wHAYDVQQKFBVQcm92YW5jZSBUZWNo
# bm9sb2dpZXMxPjA8BgNVBAsTNURpZ2l0YWwgSUQgQ2xhc3MgMyAtIE1pY3Jvc29m
# dCBTb2Z0d2FyZSBWYWxpZGF0aW9uIHYyMR4wHAYDVQQDFBVQcm92YW5jZSBUZWNo
# bm9sb2dpZXMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDLiRcW2j5o
# eaNIUBUtmxBdBtkjTfBphgAJQVr7j1OPpBYAlpgUdBQ7nA5XYgPsmrRWYr7KaytF
# vigAvn6smkYz41DE2mFpYakhpo5/vW+ppgXdIDuNy/WCjHQadrpXNn41hVWxoig+
# pXYVe5UsxAH9S2B+r1x1qiTiPtVuLQGgNAwJaRTGI98oYGQZAwEetKywofwcq5em
# KB2V+4+Caac+X2tizlqQ6Wntzkcti02OmeWxUb3jwCjkgUmIlOOb43AiC4vfBys+
# mcniWCYMgGPsDjeThmDKTSChQJIcf/EmqUSkfSV7QVACcJVIRuDgwxQpdaCDBJ5c
# LTjePE1yiR+hAgMBAAGjggF7MIIBdzAJBgNVHRMEAjAAMA4GA1UdDwEB/wQEAwIH
# gDBABgNVHR8EOTA3MDWgM6Axhi9odHRwOi8vY3NjMy0yMDEwLWNybC52ZXJpc2ln
# bi5jb20vQ1NDMy0yMDEwLmNybDBEBgNVHSAEPTA7MDkGC2CGSAGG+EUBBxcDMCow
# KAYIKwYBBQUHAgEWHGh0dHBzOi8vd3d3LnZlcmlzaWduLmNvbS9ycGEwEwYDVR0l
# BAwwCgYIKwYBBQUHAwMwcQYIKwYBBQUHAQEEZTBjMCQGCCsGAQUFBzABhhhodHRw
# Oi8vb2NzcC52ZXJpc2lnbi5jb20wOwYIKwYBBQUHMAKGL2h0dHA6Ly9jc2MzLTIw
# MTAtYWlhLnZlcmlzaWduLmNvbS9DU0MzLTIwMTAuY2VyMB8GA1UdIwQYMBaAFM+Z
# qep7JvRLyY6P1/AFJu/j0qedMBEGCWCGSAGG+EIBAQQEAwIEEDAWBgorBgEEAYI3
# AgEbBAgwBgEBAAEB/zANBgkqhkiG9w0BAQUFAAOCAQEAthqiVI8NgoeOb07LiC6e
# GpOKoY/ClKrwbPcgvj8jkr7JgLR1n2PmfF1K1z8mW3GnWeBNsilBPfLMIHWtYasP
# pN08eIDcAyvr7QKKQPW5AY3HmCADofNCAqcgAC2YxJ5pstYwRDKkBcrV211s+jmE
# W+2ij0XivPvXokVcfaiSG6ovftQu58yEJZ3knMS3BIC/tPSVFt2GSalDTHCLtCBP
# TJ2XrZKnBvmCnFoifPrD3DSMT10FeZp6gHlDtpOD1oODu4fquFjmGyrhjgnrzu4N
# atHfFbVW4if/662W3Cso3C4zo502fMWgz+mHBbbNF0yeuwUG6NJUG/rQdbCqw2QD
# ijCCBgowggTyoAMCAQICEFIA5aolVvwahu2WydRLM8cwDQYJKoZIhvcNAQEFBQAw
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
# Q29kZSBTaWduaW5nIDIwMTAgQ0ECEFoK3xFLMAJgjzCKQnfx1JwwCQYFKw4DAhoF
# AKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisG
# AQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcN
# AQkEMRYEFM0d0p9DJ0fAdsEU3KrH77MuY6KUMA0GCSqGSIb3DQEBAQUABIIBAKna
# 9MLhETp/XvEcOQY3tKhfyqmiC7BvP/FeL7JIkSwhznUjQvJlBzMvDDk/a62ancNY
# bxJ7qeCXZLTM/eGIRcZ7d/0d+Qknn/SfpVhRaMzejh4GhiUMSUYQ/EBXm2ZYYst7
# gKWmEjscPJ5jYAFA/NbnElmfaU5SjsR787s6HmJ0hhQUMAUqMkUhzmfIRGsEy+qY
# eal40mW6Ce7/Qm5230VjdwBWM8gQDPmirWUTKvjg1Lfdx1lHtqfJ0aE237qtb6Og
# C9+tPJ0bFLirE7rzdL1WC2mL0o9YRhyLS32eBgudX8xcdaNJvqWLLuULKDs9deTM
# TwV7Lm8hv3IaK3CgCVOhggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBe
# MQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAu
# BgNVBAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQ
# Ds/0OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqG
# SIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTUwMjI0MTk0NTU0WjAjBgkqhkiG9w0B
# CQQxFgQUMCP3AC3//yiAshe7lvqeDCHchxEwDQYJKoZIhvcNAQEBBQAEggEAAsye
# hrp6co8vgXPm6y3dbg38IF39sENjk0Bb7BtH6pJyYPaIsY0qyjAO85eF1xf1LZGT
# LA64gqV+9B4q1Zwxxf8hcEOZ0vS8HVHqkzftG4mSJS9CJCOebprzYLu/o+WMNEDU
# IHiKmyn9//JHL5xeLIIki8qmD+X717TI0u2dpyg/r/pxBkB9LjDONecGhmUiLSSx
# rj/RR1nIEdf3fs8neNxaIfmlqI2hzlGUsmjkU14ccYS0qaP5DPod0xOehk8iKPES
# LHQD0zRlRqEQJBG7cLLFZtfmcHuGgc0jfHygeYZqVHqmtOgRj05k8FNY63JOjRZX
# Haw/qBftWWOxfH181g==
# SIG # End signature block
