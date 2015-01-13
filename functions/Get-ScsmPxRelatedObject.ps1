﻿<#############################################################################
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
function Get-ScsmPxRelatedObject {
    [CmdletBinding(DefaultParameterSetName='RelatedToSourceFromManagementGroupConnection')]
    [OutputType('Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance#RelatedObject')]
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='RelatedToSourceFromManagementGroupConnection')]
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='RelatedToSourceFromComputerName')]
        [ValidateNotNullOrEmpty()]
        [Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance[]]
        $Source,

        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='RelatedToTargetFromManagementGroupConnection')]
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='RelatedToTargetFromComputerName')]
        [ValidateNotNullOrEmpty()]
        [Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance[]]
        $Target,

        [Parameter(Position=1)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $RelationshipClassName,

        [Parameter(Mandatory=$true, ParameterSetName='RelatedToSourceFromComputerName')]
        [Parameter(Mandatory=$true, ParameterSetName='RelatedToTargetFromComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ComputerName,

        [Parameter(ParameterSetName='RelatedToSourceFromComputerName')]
        [Parameter(ParameterSetName='RelatedToTargetFromComputerName')]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter(ParameterSetName='RelatedToSourceFromManagementGroupConnection')]
        [Parameter(ParameterSetName='RelatedToTargetFromManagementGroupConnection')]
        [ValidateNotNull()]
        [Microsoft.SystemCenter.Core.Connection.Connection]
        $SCSession
    )
    begin {
        try {
            #region Prepare for splatting of remoting parameters if required.

            $remotingParameters = @{}
            foreach ($remotingParameterName in 'ComputerName','Credential','SCSession') {
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey($remotingParameterName)) {
                    $remotingParameters[$remotingParameterName] = $PSCmdlet.MyInvocation.BoundParameters.$remotingParameterName
                }
            }

            #endregion

            #region Determine the search parameter and related item property name based on the parameter set.

            switch -regex ($PSCmdlet.ParameterSetName) {
                '^RelatedToSource' {
                    $searchParameter = 'Source'
                    $searchMethod = 'GetRelationshipObjectsWhereSource'
                    $relatedItemPropertyName = 'TargetObject'
                    break
                }
                '^RelatedToTarget' {
                    $searchParameter = 'Target'
                    $searchMethod = 'GetRelationshipObjectsWhereTarget'
                    $relatedItemPropertyName = 'SourceObject'
                    break
                }
            }

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    process {
        try {
            foreach ($item in Get-Variable -Name $searchParameter -ValueOnly) {
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('RelationshipClassName')) {
                    #region Get the related items when we have a relationship class name to work with.

                    # You must use this generic method and not the GetRelatedObjectsWhereSource/Target methods
                    # because those methods return more objects that you ask for.
                    $relationship = [Microsoft.EnterpriseManagement.Configuration.ManagementPackRelationship](Get-SCRelationship -Name $RelationshipClassName @remotingParameters)
                    $emg = $relationship.ManagementGroup
                    [Type[]]$getRelationshipObjectsMethodType = @(
                        [System.Guid]
                        [Microsoft.EnterpriseManagement.Configuration.ManagementPackRelationship]
                        [Microsoft.EnterpriseManagement.Configuration.DerivedClassTraversalDepth]
                        [Microsoft.EnterpriseManagement.Common.TraversalDepth]
                        [Microsoft.EnterpriseManagement.Common.ObjectQueryOptions]
                    )
                    $getRelationshipObjectsMethod = $emg.EntityObjects.GetType().GetMethod($searchMethod, $getRelationshipObjectsMethodType)
                    $getRelationshipObjectsGenericMethod = $getRelationshipObjectsMethod.MakeGenericMethod([Microsoft.EnterpriseManagement.Common.EnterpriseManagementObject])
                    $getRelationshipObjectsGenericMethodParameters = @(
                        $item.EnterpriseManagementObject.Id,
                        $relationship,
                        [Microsoft.EnterpriseManagement.Configuration.DerivedClassTraversalDepth]::None,
                        [Microsoft.EnterpriseManagement.Common.TraversalDepth]::OneLevel,
                        [Microsoft.EnterpriseManagement.Common.ObjectQueryOptions]::Default
                    )
                    foreach ($relatedItem in $getRelationshipObjectsGenericMethod.Invoke($emg.EntityObjects, $getRelationshipObjectsGenericMethodParameters)) {
                        $rawEmi = [Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance]$relatedItem.$relatedItemPropertyName
                        $psObject = $rawEmi.ToPSObject()
                        Add-Member -InputObject $psObject -MemberType NoteProperty -Name "RelatedTo${searchParameter}" -Value $item
                        Add-Member -InputObject $psObject -MemberType NoteProperty -Name RelationshipClass -Value $relationship
                        $psObject = $psObject | Add-ClassHierarchyToTypeNameList
                        if ($psObject.PSTypeNames -notcontains 'Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance#RelatedObject') {
                            $insertIndex = $psObject.PSTypeNames.IndexOf('Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance')
                            $psObject.PSTypeNames.Insert($insertIndex, 'Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance#RelatedObject')
                        }
                        $psObject
                    }

                    #endregion
                } else {
                    #region Identify the filter we'll use when looking up the relationship instance.

                    $relationshipInstanceParameters = @{
                        $searchParameter = $item
                    }

                    #endregion

                    foreach ($relationshipInstance in Get-SCRelationshipInstance @relationshipInstanceParameters @remotingParameters) {
                        #region If the relationship is deleted, skip it.

                        if ($relationshipInstance.IsDeleted) {
                            continue
                        }

                        #endregion

                        #region If the related item is null, raise a warning.

                        if (-not $relationshipInstance.$relatedItemPropertyName) {
                            Write-Warning "The item related to $($item.DisplayName) is null."
                            continue
                        }

                        #endregion

                        #region Now return the related item instance.

                        if ($relatedItem = [Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance]$relationshipInstance.$relatedItemPropertyName) {
                            if ($relatedItem.PSTypeNames[0].StartsWith($relatedItem.GetType().FullName)) {
                                $psObject = $relatedItem.ToPSObject()
                            } else {
                                $psObject = $relatedItem
                            }
                            Add-Member -InputObject $psObject -MemberType NoteProperty -Name "RelatedTo${searchParameter}" -Value $item
                            Add-Member -InputObject $psObject -MemberType NoteProperty -Name RelationshipClass -Value ($relationshipInstance.ManagementGroup.EntityTypes.GetRelationshipClass($relationshipInstance.RelationshipId))
                            $psObject = $psObject | Add-ClassHierarchyToTypeNameList
                            if ($psObject.PSTypeNames -notcontains 'Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance#RelatedObject') {
                                $insertIndex = $psObject.PSTypeNames.IndexOf('Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance')
                                $psObject.PSTypeNames.Insert($insertIndex, 'Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance#RelatedObject')
                            }
                            $psObject
                        }

                        #endregion
                    }
                }
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

Export-ModuleMember -Function Get-ScsmPxRelatedObject