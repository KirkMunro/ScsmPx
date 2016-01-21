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

# .ExternalHelp ScsmPx-help.xml
function Add-ScsmPxFileAttachment {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance])]
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            $classHierarchy = @($_.EnterpriseManagementObject.GetClasses())
            $classHierarchy += $classHierarchy[0].GetBaseTypes()
            $classNameHierarchy = $classHierarchy | Select-Object -ExpandProperty Name
            if (($classNameHierarchy -notcontains 'System.WorkItem') -and ($classNameHierarchy -notcontains 'System.ConfigItem')) {
                throw "Cannot bind parameter 'InputObject'. ""$($_.DisplayName)"" is not of type ""System.ConfigItem"" nor is it of type ""System.WorkItem"". Error: ""Invalid type provided in InputObject parameter""."
            }
            $true
        })]
        [Alias('EnterpriseManagementInstance')]
        [Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance[]]
        $InputObject,

        [Parameter(Position=1, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Path,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $PassThru
    )
    begin {
        try {
            #region Define an entity cache to store relationships, classes and instances that should only be looked up once.

            $entityCache = @{}

            #endregion

            #region Get a list of the files that will be attached (wildcards are accepted).

            $attachments = @()
            foreach ($attachment in Get-Item -Path $Path) {
                if ($attachment.PSIsContainer) {
                    Write-Warning -Message "Folder '$($attachment.Name)' will be skipped. Only files may be attached to work items or configuration items."
                    continue
                }
                $attachments += $attachment
            }

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    process {
        try {
            foreach ($item in $InputObject) {
                if ($attachments) {
                    #region Get the Enterprise Management Group (EMG) for the work/config item.

                    $emg = $item.EnterpriseManagementObject.ManagementGroup

                    #endregion

                    #region If we haven't cached classes, relationships and instances for this EMG yet, cache them.

                    if ($entityCache.Keys -notcontains $emg.Id) {
                        #region Cache classes and relationships that are well known.

                        $entityCache[$emg.Id] = @{
                                                FileAttachmentClass = $emg.EntityTypes.GetClass('68a35b6d-ca3d-8d90-f93d-248ceff935c0')
                                                      WorkItemClass = $emg.EntityTypes.GetClass('f59821e2-0364-ed2c-19e3-752efbb1ece9')
                                                    ConfigItemClass = $emg.EntityTypes.GetClass('62f0be9f-ecea-e73c-f00d-3dd78a7422fc')
                                        IncidentGeneralSettingClass = $emg.EntityTypes.GetClass('613c9f3e-9b94-1fef-4088-16c33bfd0be1')
                                                          UserClass = $emg.EntityTypes.GetClass('943d298f-d79a-7a29-a335-8833e582d252')
                              WorkItemHasFileAttachmentRelationship = $emg.EntityTypes.GetRelationshipClass('aa8c26dc-3a12-5f88-d9c7-753e5a8a55b4')
                            ConfigItemHasFileAttachmentRelationship = $emg.EntityTypes.GetRelationshipClass('095ebf2a-ee83-b956-7176-ab09eded6784')
                              FileAttachmentAddedByUserRelationship = $emg.EntityTypes.GetRelationshipClass('ffd71f9e-7346-d12b-85d6-7c39f507b7bb')
                        }

                        #endregion

                        #region Cache the System.WorkItem.Incident.GeneralSetting instance.

                        [Type[]]$methodType = ([Microsoft.EnterpriseManagement.Configuration.ManagementPackClass],[Microsoft.EnterpriseManagement.Common.ObjectQueryOptions])
                        $getObjectReaderMethod = $emg.EntityObjects.GetType().GetMethod("GetObjectReader", $methodType)
                        $getObjectReaderGenericMethod = $getObjectReaderMethod.MakeGenericMethod([Microsoft.EnterpriseManagement.Common.EnterpriseManagementObject])
                        $reader = $getObjectReaderGenericMethod.Invoke($emg.EntityObjects, ($entityCache[$emg.Id].IncidentGeneralSettingClass, [Microsoft.EnterpriseManagement.Common.ObjectQueryOptions]::Default))
                        for ($i = 0; $i -lt $reader.Count; $i++) {
                            if ($rawEmi = $reader.GetData($i) -as [Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance]) {
                                $entityCache[$emg.Id]['IncidentGeneralSettingInstance'] = $rawEmi.ToPSObject()
                                break
                            }
                        }

                        #endregion

                        #region Cache the current System.User instance.

                        $currentUserName = $emg.GetUserName()
                        $criteriaXml = @"
<Criteria xmlns="http://Microsoft.EnterpriseManagement.Core.Criteria/">
  <Reference Id="System.Library"
             Version="7.0.5000.0"
             PublicKeyToken="31bf3856ad364e35"
             Alias="System" />
  <Expression>
    <Or>
      <Expression>
        <SimpleExpression>
          <ValueExpressionLeft>
            <Property>`$Target/Property[Type='System!System.User']/DisplayName$</Property>
          </ValueExpressionLeft>
          <Operator>Equal</Operator>
          <ValueExpressionRight>
            <Value>${currentUserName}</Value>
          </ValueExpressionRight>
        </SimpleExpression>
      </Expression>
      <Expression>
        <SimpleExpression>
          <ValueExpressionLeft>
            <Property>`$Target/Property[Type='System!System.User']/DisplayName$</Property>
          </ValueExpressionLeft>
          <Operator>Equal</Operator>
          <ValueExpressionRight>
            <Value>$($currentUserName -replace '\\','.')</Value>
          </ValueExpressionRight>
        </SimpleExpression>
      </Expression>
    </Or>
  </Expression>
</Criteria>
"@
                        [Microsoft.EnterpriseManagement.Common.EnterpriseManagementObjectCriteria]$emoCriteria = New-Object -TypeName Microsoft.EnterpriseManagement.Common.EnterpriseManagementObjectCriteria -ArgumentList $criteriaXml,$entityCache[$emg.Id].UserClass,$emg
                        [Type[]]$methodType = ([Microsoft.EnterpriseManagement.Common.EnterpriseManagementObjectCriteria],[Microsoft.EnterpriseManagement.Common.ObjectQueryOptions])
                        $getObjectReaderMethod = $emg.EntityObjects.GetType().GetMethod("GetObjectReader", $methodType)
                        $getObjectReaderGenericMethod = $getObjectReaderMethod.MakeGenericMethod([Microsoft.EnterpriseManagement.Common.EnterpriseManagementObject])
                        $reader = $getObjectReaderGenericMethod.Invoke($emg.EntityObjects, ($emoCriteria, [Microsoft.EnterpriseManagement.Common.ObjectQueryOptions]::Default))
                        for ($i = 0; $i -lt $reader.Count; $i++) {
                            if ($rawEmi = $reader.GetData($i) -as [Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance]) {
                                $entityCache[$emg.Id]['CurrentUserInstance'] = $rawEmi.ToPSObject()
                                break
                            }
                        }

                        #endregion

                        #region Write a warning if the current user was not found.

                        if (-not ($entityCache[$emg.Id].ContainsKey('CurrentUserInstance'))) {
                            Write-Warning "Failed to find a System.User object with a display name that matches '${currentUserName}'. As a result, attachments will not be associated with that user."
                        }

                        #endregion
                    }

                    #endregion

                    #region Determine which max size and count we should adhere to (different for config items and work items).

                    if ($item.EnterpriseManagementObject.IsInstanceOf($entityCache[$emg.Id].WorkItemClass)) {
                        $maxSize = $entityCache[$emg.Id].IncidentGeneralSettingInstance.MaxAttachmentSize * 1KB
                        $maxCount = $entityCache[$emg.Id].IncidentGeneralSettingInstance.MaxAttachments
                    } elseif ($item.EnterpriseManagementObject.IsInstanceOf($entityCache[$emg.Id].ConfigItemClass)) {
                        $maxSize = 10240KB
                        $maxCount = $null
                    }

                    #endregion

                    foreach ($attachment in $attachments) {
                        try {
                            #region Initialize the memory stream and file stream to null.

                            $memoryStream = $fileStream = $null

                            #endregion

                            #region If the attachment size exceeds the maximum attachment size, output an error and continue.

                            if ($maxCount -and
                                ($item.GetRelatedObjectsWhereSource($entityCache[$emg.Id].WorkItemHasFileAttachmentRelationship).Count -ge $maxCount)) {
                                Write-Error -Message "Attachment '$($attachment.Name)' cannot be added to work item '$($item.DisplayName)' because it already has the maximum number of attachments ($maxCount)."
                                break
                            } elseif ($attachment.Length -gt $maxSize) {
                                $errorMessage = 'Attachment ''{0}'' is too large to be added to ''{1}''. The maximum attachment size is {2}KB. This attachment will be skipped.' -f $attachment.Name,$item.DisplayName,($maxSize / 1KB)
                                Write-Error -Message $errorMessage
                                continue
                            }

                            #endregion

                            #region Open a memory stream for the attachment.

                            $memoryStream = New-Object -TypeName System.IO.MemoryStream
                            $fileStream = [System.IO.File]::OpenRead($attachment.FullName)
                            $memoryStream.SetLength($fileStream.Length)
                            $fileStream.Read($memoryStream.GetBuffer(), 0, $fileStream.Length) > $null
                            $memoryStream.Position = 0

                            #endregion

                            #region Define the attachment instance properties.

                            $attachmentProperties = @{
                                         Id = [System.Guid]::NewGuid().ToString()
                                DisplayName = $attachment.Name
                                Description = $attachment.Name
                                  Extension = $attachment.Extension
                                    Content = $memoryStream
                                       Size = $memoryStream.Length
                                  AddedDate = [System.DateTime]::UtcNow
                            }

                            #endregion

                            #region Create the attachment instance (but don't commit it yet, that has to be done later).

                            $fileAttachmentEmo = New-Object -TypeName Microsoft.EnterpriseManagement.Common.CreatableEnterpriseManagementObject -ArgumentList $emg,$entityCache[$emg.Id].FileAttachmentClass
                            foreach ($attachmentPropertyName in $attachmentProperties.Keys) {
                                $fileAttachmentEmo[$entityCache[$emg.Id].FileAttachmentClass,$attachmentPropertyName].Value = $attachmentProperties.$attachmentPropertyName
                            }

                            #endregion

                            #region Determine which relationship we should use based on the input object type.

                            if ($item.EnterpriseManagementObject.IsInstanceOf($entityCache[$emg.Id].WorkItemClass)) {
                                $relationshipName = 'WorkItemHasFileAttachmentRelationship'
                            } elseif ($item.EnterpriseManagementObject.IsInstanceOf($entityCache[$emg.Id].ConfigItemClass)) {
                                $relationshipName = 'ConfigItemHasFileAttachmentRelationship'
                            }

                            #endregion

                            #region Create a relationship between the input object and the file attachment.

                            $itemHasFileAttachmentRi = New-Object -TypeName Microsoft.EnterpriseManagement.Common.CreatableEnterpriseManagementRelationshipObject -ArgumentList $emg,$entityCache[$emg.Id].$relationshipName
                            $itemHasFileAttachmentRi.SetSource($item)
                            $itemHasFileAttachmentRi.SetTarget($fileAttachmentEmo)
                            $itemHasFileAttachmentRi.Commit()

                            #endregion

                            #region Create a relationship between the file attachment and the current user.

                            if ($entityCache[$emg.Id].ContainsKey('CurrentUserInstance')) {
                                $fileAttachmentAddedByUserRi = New-Object -TypeName Microsoft.EnterpriseManagement.Common.CreatableEnterpriseManagementRelationshipObject -ArgumentList $emg,$entityCache[$emg.Id].FileAttachmentAddedByUserRelationship
                                $fileAttachmentAddedByUserRi.SetSource($fileAttachmentEmo)
                                $fileAttachmentAddedByUserRi.SetTarget($entityCache[$emg.Id].CurrentUserInstance)
                                $fileAttachmentAddedByUserRi.Commit()
                            }

                            #endregion

                            #region Now commit the file attachment to the CMDB.

                            $fileAttachmentEmo.Commit()

                            #endregion
                        } finally {
                            #region If we have any open streams, close them.

                            if ($fileStream) {
                                $fileStream.Close()
                            }
                            if ($memoryStream) {
                                $memoryStream.Close()
                            }

                            #endregion
                        }
                    }
                }

                #region Return the work/config item to the caller if they requested it.

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

Export-ModuleMember -Function Add-ScsmPxFileAttachment
# SIG # Begin signature block
# MIIZKQYJKoZIhvcNAQcCoIIZGjCCGRYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU1rObrDQUcDC3dT+zXCTUIItm
# wVSgghQZMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
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
# AQkEMRYEFC3DFesPlSvrBDXUFTQTe/RcNdYhMA0GCSqGSIb3DQEBAQUABIIBAAnl
# skVXChmBFZrdySQEnebqJWR58vN/6ocznONuvF9yzctbisnThhGmHiN+YLLQkivM
# TvW+YTZ6z++ci+2VsfmXw/rXwVEuditndGKnL0n9G0j1ox0pa9cLQZMChVUhPvCJ
# pqlEG7FbVvY0JOwk+WHB8LK7xqfgpbvFej8h8N6NAG1XG6EdDvSxIIvImuSkE/nU
# +Axsx3ZyXmXsbgjynhrtldQqmpUD0bN/5TVmN7RhXZry4Ss63eglxRWyUezvOE0x
# nS0cdy48IWzOLyqIFqAvIwXjngdshn+9e48toirdDyx/W/gJcWh6r0TZOfBDa3pH
# lQxNqf6Uff3A+jVyHd2hggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBe
# MQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAu
# BgNVBAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQ
# Ds/0OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqG
# SIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTYwMTIxMDIyNDExWjAjBgkqhkiG9w0B
# CQQxFgQUhZickcGMDVVehCjPnjrbL9RWrFgwDQYJKoZIhvcNAQEBBQAEggEANtgh
# tmKcysuZnjZmbGE7KNvBpIsWxaTL3LDVGJAxRqfMvXmBQWN3lbuJphVTi66eVYdA
# 4KU4XPJYIo9Ts3KkS/itji9GlarOJs1ZDUoeoON4CWl6k1Q2HMnwHaI+WV+Rut6R
# HwlIt0FI7scDdI/d8RsaDiJm0bTbezWH6EXWSWAg/1tLUnvDxKQMmAZ+3jR/WXRp
# zMKOrJvumizTkdsg+hgD8jJsIApTl+KqhQwPC5S2WlmgWScRNxHhkWfP4xaHqCK8
# ILNqmI5iJHJXxUiYFYjwxhCjNsjDTgJeAlilt/wsGLIi3fV7ZI5TQ/Hkiv1rd32Y
# 3adrCfW1k3pVtJxexA==
# SIG # End signature block
