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