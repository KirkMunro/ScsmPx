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
function Get-ScsmPxViewData {
    [CmdletBinding(DefaultParameterSetName='FromViewNameAndManagementGroupConnection')]
    [OutputType('Microsoft.EnterpriseManagement.ServiceManager.ViewRecord')]
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='FromViewObject')]
        [ValidateNotNullOrEmpty()]
        [Microsoft.EnterpriseManagement.Configuration.ManagementPackView[]]
        $View,

        [Parameter(Position=0, ParameterSetName='FromViewNameAndManagementGroupConnection')]
        [Parameter(Position=0, ParameterSetName='FromViewNameAndComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $ViewName = '*',

        [Parameter(Position=0, Mandatory=$true, ParameterSetName='FromViewDisplayNameAndManagementGroupConnection')]
        [Parameter(Position=0, Mandatory=$true, ParameterSetName='FromViewDisplayNameAndComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $ViewDisplayName = '*',

#        [Parameter()]
#        [ValidateNotNullOrEmpty()]
#        [System.String[]]
#        $Filter,

        [Parameter(ParameterSetName='FromViewNameAndManagementGroupConnection')]
        [Parameter(ParameterSetName='FromViewDisplayNameAndManagementGroupConnection')]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.Core.Connection.Connection[]]
        $SCSession,

        [Parameter(Mandatory=$true, ParameterSetName='FromViewNameAndComputerName')]
        [Parameter(Mandatory=$true, ParameterSetName='FromViewDisplayNameAndComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $ComputerName,

        [Parameter(ParameterSetName='FromViewNameAndComputerName')]
        [Parameter(ParameterSetName='FromViewDisplayNameAndComputerName')]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )
    begin {
        try {
            #region Define a helper function that converts enterprise management objects into their PSObject equivalent.

            function Convert-EmoToPsEmi {
                [CmdletBinding()]
                [OutputType([System.Management.Automation.PSObject])]
                param(
                    [Parameter(Position=0, Mandatory=$true)]
                    [ValidateNotNull()]
                    [Microsoft.EnterpriseManagement.Common.EnterpriseManagementObject[]]
                    $EnterpriseManagementObject
                )
                try {
                    foreach ($item in $EnterpriseManagementObject) {
                        $rawEmi = [Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance]$item
                        $rawEmi.ToPSObject()
                    }
                } catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }

            #endregion

            #region Define a helper function that will be used to return objects to the caller.

            function New-ScsmPxViewDataRecord {
                [CmdletBinding()]
                [OutputType('Microsoft.EnterpriseManagement.ServiceManager.ViewRecord')]
                param(
                    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
                    [ValidateNotNull()]
                    [Microsoft.EnterpriseManagement.Common.EnterpriseManagementObject]
                    $EnterpriseManagementObject,

                    [Parameter(Position=1)]
                    [System.Collections.Specialized.OrderedDictionary]
                    $RelatedEnterpriseManagementObjectMap = (New-Object -TypeName System.Collections.Specialized.OrderedDictionary)
                )
                process {
                    try {
                        $psoPropertyValues = New-Object -TypeName System.Collections.Specialized.OrderedDictionary
                        $psoPropertyValues['EnterpriseManagementInstance'] = Convert-EmoToPsEmi -EnterpriseManagementObject $EnterpriseManagementObject
                        foreach ($key in $RelatedEnterpriseManagementObjectMap.Keys | Sort-Object) {
                            $psoPropertyValues[$key] = Convert-EmoToPsEmi -EnterpriseManagementObject $RelatedEnterpriseManagementObjectMap[$key]
                        }
                        foreach ($item in $emoPropertiesInDdps) {
                            if ($psoPropertyValues.Keys -notcontains $item) {
                                $psoPropertyValues[$item] = $EnterpriseManagementObject.$item
                            }
                        }
                        foreach ($emoProperty in $EnterpriseManagementObject.GetProperties()) {
                            if ($psoPropertyValues.Keys -contains $emoProperty.Name) {
                                continue
                            }
                            $psoPropertyValues[$emoProperty.Name] = $psoPropertyValues['EnterpriseManagementInstance'].$($emoProperty.Name)
                        }
                        foreach ($propertyDisplayName in $defaultDisplayPropertyMap.Keys) {
                            if ($psoPropertyValues.Keys -contains $propertyDisplayName) {
                                continue
                            }
                            $propertyName = $defaultDisplayPropertyMap[$propertyDisplayName]
                            if ($propertyName -match '[\\/\.]') {
                                $propertyNameParts = $propertyName -split '[\\/\.]'
                                $propertyValues = @()
                                if ($psoPropertyValues.Keys -contains $propertyNameParts[0]) {
                                    foreach ($propertyValue in $psoPropertyValues[$propertyNameParts[0]]) {
                                        foreach ($subPropertyName in $propertyNameParts[1..$($propertyNameParts.Count - 1)]) {
                                            if (-not $propertyValue) {
                                                break
                                            }
                                            if (Get-Member -InputObject $propertyValue -Name $subPropertyName -ErrorAction SilentlyContinue) {
                                                $propertyValue = $propertyValue.$subPropertyName
                                            } elseif ($psoPropertyValues.Keys -contains $subPropertyName) {
                                                $propertyValue = $psoPropertyValues.$subPropertyName
                                            } else {
                                                $propertyValue = $null
                                            }
                                        }
                                        if ($propertyValue) {
                                            $propertyValues += $propertyValue
                                        }
                                    }
                                    if ($propertyValues.Count -eq 1) {
                                        $psoPropertyValues[$propertyDisplayName] = $propertyValues[0]
                                    } elseif ($propertyValues.Count -gt 1) {
                                        $psoPropertyValues[$propertyDisplayName] = $propertyValues
                                    } else {
                                        $psoPropertyValues[$propertyDisplayName] = $null
                                    }
                                } else {
                                    $psoPropertyValues[$propertyDisplayName] = $psoPropertyValues[$propertyNameParts[0]] = $null
                                }
                            } else {
                                if ($psoPropertyValues.Keys -notcontains $propertyName) {
                                    $psoPropertyValues[$propertyName] = $null
                                }
                                $psoPropertyValues[$propertyDisplayName] = $psoPropertyValues[$propertyName]
                            }
                        }
                        $viewRecord = New-Object -TypeName PSCustomObject -Property $psoPropertyValues
                        $viewRecord.PSTypeNames.Insert(0, $baseTypeName)
                        $viewRecord.PSTypeNames.Insert(0, $extendedTypeName)
                        $viewRecord
                    } catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
                }
            }

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    process {
        try {
            #region Identify the specific views that the caller wants to retrieve data for.

            if ($PSCmdlet.ParameterSetName -eq 'FromViewObject') {
                foreach ($item in $View) {
                    #region Skip over any views that are used as templates.

                    if ($item.Configuration -match '{\d+}') {
                        continue
                    }

                    #endregion

                    #region Get the management pack that contains the view for later use.

                    $viewMp = $item.GetManagementPack()

                    #endregion

                    #region Convert the view XML string to an XML object.

                    $viewXml =  [xml]('<?xml version="1.0" encoding="utf-8" ?><View>' + $item.Configuration + '</View>')

                    #endregion

                    #region If the view doesn't have a data or itemssource section, raise an error.

                    if (-not $viewXml.SelectSingleNode('/View/Data/ItemsSource')) {
                        Write-Error "View $($item.Name) does not have either of the recognized list support classes referenced within its items source definition and therefore its data cannot be retrieved by this command."
                        continue
                    }

                    #endregion

                    #region Get a reference to any query parameters in the view.

                    if ((($elementList = @($viewXml.View.Data.ItemsSource.GetElementsByTagName('AdvancedListSupportClass'))).Count -eq 1) -and
                        (($elementList = @($elementList[0].GetElementsByTagName('AdvancedListSupportClass.Parameters'))).Count -eq 1) -and
                        (($elementList = @($elementList[0].GetElementsByTagName('QueryParameter'))).Count -gt 0)) {
                        $qp = $elementList
                    } elseif ((($elementList = @($viewXml.View.Data.ItemsSource.GetElementsByTagName('ListSupportClass'))).Count -eq 1) -and
                                (($elementList = @($elementList[0].GetElementsByTagName('ListSupportClass.Parameters'))).Count -eq 1) -and
                                (($elementList = @($elementList[0].GetElementsByTagName('QueryParameter'))).Count -gt 0)) {
                        $qp = $elementList
                    } else {
                        Write-Error "View $($item.Name) does not have either of the recognized list support classes referenced within its items source definition and therefore its data cannot be retrieved by this command."
                        continue
                    }

                    #endregion

                    #region Identify the base type and the extended type name for the view record objects that will be returned.

                    $baseTypeName = 'Microsoft.EnterpriseManagement.ServiceManager.ViewRecord'
                    $extendedTypeName = "${baseTypeName}#$($item.Name)"

                    #endregion

                    #region Identify the default display properties and property mappings for the objects that will be returned and update the ETS type accordingly.

                    $emoPropertiesInDdps = @()
                    $defaultDisplayPropertyMap = New-Object -TypeName System.Collections.Specialized.OrderedDictionary
                    if ($viewXml.View.Presentation.Columns) {
                        foreach ($column in $viewXml.View.Presentation.Columns.ColumnCollection.Column) {
                            if ((Get-Member -InputObject $column -Name DisplayMemberBinding) -or
                                (Get-Member -InputObject $column -Name 'Column.DisplayMemberBinding') -or
                                (Get-Member -InputObject $column -Name 'Column.CellTemplate')) {
                                if ((Get-Member -InputObject $column -Name IsVisible) -and
                                    ($column.IsVisible -eq 'false')) {
                                    continue
                                }
                                $propertyName = $column.Property
                                if ($propertyName -match '\$ReturnValueAsBigInt\$') {
                                    $propertyName = $propertyName -replace '\$ReturnValueAsBigInt\$'
                                } elseif ($propertyName -match '^\$[^\$]+\$$') {
                                    $propertyName = $propertyName -replace '^\$|\$$'
                                    $emoPropertiesInDdps += $propertyName
                                } elseif ($propertyName -match '[\./\\]DisplayName') {
                                    $propertyName = $propertyName -replace '[\./\\]DisplayName'
                                }
                                $propertyDisplayName = $propertyName
                                try {
                                    if (($mpElementId = $viewXml.View.Presentation.ViewStrings.SelectSingleNode("//ViewString[@ID='$($column.DisplayName)']")) -and
                                        ($mpElement = $viewMp.ProcessElementReference($mpElementId.'#text')) -and
                                        ($stringResource = $viewMp.GetStringResource($mpElement.Name))) {
                                        $propertyDisplayName = $stringResource.DisplayName
                                    }
                                } catch {
                                }
                                $defaultDisplayPropertyMap[$propertyDisplayName] = $propertyName
                            }
                        }
                        if ($defaultDisplayPropertyMap.Count) {
                            if ($PSVersionTable.PSVersion -ge '3.0') {
                                Update-TypeData -TypeName $extendedTypeName -DefaultDisplayPropertySet ([string[]]$defaultDisplayPropertyMap.Keys) -Force
                            } else {
                                # The PS team broke the capability for setting DefaultDisplayPropertySet in PowerShell 2.0.
                                # To address this issue, we use the $Host.Runspace.RunspaceConfiguration "TypeTable"
                                # internal property to get the type table for the current runspace, and then use the
                                # hidden "members" field on the TypeTable object to access (and modify) the members table
                                # (this is not read only, so we can rip and replace the DefaultDisplayPropertySet value
                                # this way). If this does not work for one reason or another we'll simply continue
                                # execution, since failing to adhere to the default display property set is not a
                                # showstopper.
                                try {
                                    $runspaceConfiguration = $Host.Runspace.RunspaceConfiguration
                                    if (($typeTableProperty = $runspaceConfiguration.GetType().GetProperty('TypeTable',[System.Reflection.BindingFlags]'NonPublic,Instance')) -and
                                        ($typeTable = $typeTableProperty.GetValue($runspaceConfiguration,$null)) -and
                                        ($membersField = $typeTable.GetType().GetField('members',[System.Reflection.BindingFlags]'NonPublic,Instance')) -and
                                        ($members = $membersField.GetValue($typeTable))) {
                                        if ((-not $members.ContainsKey($extendedTypeName)) -and
                                            ($psMemberInfoInternalCollectionType = [System.Management.Automation.PSObject].Assembly.GetType('System.Management.Automation.PSMemberInfoInternalCollection`1',$true,$true)) -and
                                            ($psMemberInfoGenericCollection = $psMemberInfoInternalCollectionType.MakeGenericType([System.Management.Automation.PSMemberInfo])) -and
                                            ($genericCollectionConstructor = $psMemberInfoGenericCollection.GetConstructor('NonPublic,Instance',$null,@(),@()))) {
                                            $genericCollection = $genericCollectionConstructor.Invoke(@())
                                            $defaultDisplayPropertySet = New-Object -TypeName System.Management.Automation.PSPropertySet -ArgumentList (‘DefaultDisplayPropertySet’,[string[]]$defaultDisplayPropertyMap.Keys)
                                            $psMemberSet = New-Object -TypeName System.Management.Automation.PSMemberSet -ArgumentList ('PSStandardMembers',[System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet))
                                            $genericCollection.Add($psMemberSet)
                                            $members.Add($extendedTypeName,$genericCollection)
                                        } else {
                                            $defaultDisplayPropertySet = New-Object -TypeName System.Management.Automation.PSPropertySet -ArgumentList (‘DefaultDisplayPropertySet’,[string[]]$defaultDisplayPropertyMap.Keys)
                                            $psMemberSet = New-Object -TypeName System.Management.Automation.PSMemberSet -ArgumentList ('PSStandardMembers',[System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet))
                                            $members[$extendedTypeName].Remove('PSStandardMembers')
                                            $members[$extendedTypeName].Add($psMemberSet)
                                        }
                                    }
                                } catch {
                                }
                            }
                        }
                    }

                    #endregion

                    #region Identify the query parameter names and values in an ordered dictionary.

                    $queryParameters = New-Object -TypeName System.Collections.Specialized.OrderedDictionary
                    foreach ($entry in $qp) {
                        $queryParameters[$entry.Parameter] = $entry.Value
                    }

                    #endregion

                    #region Replace MPElement values in the query criteria with their equivalent GUID.

                    if (($node = $viewXml.SelectSingleNode('/View/Data/Criteria')) -and
                        (($elementList = $node.GetElementsByTagName('Value')).Count -ge 1)) {
                        foreach ($element in $elementList) {
                            if (($element.'#text' -match '^\$MPElement') -and
                                ($elementReference = $viewMp.ProcessElementReference($element.'#text'))) {
                                $element.'#text' = $elementReference.Id.ToString()
                            }
                        }
                    }

                    #endregion

                    if ($queryParameters.Keys -notmatch '^TypeProjection') {
                        #region Identify the management pack class for the view.

                        if ($queryParameters.Keys -contains 'ManagementPackClassId') {
                            $elementReference = $viewMp.ProcessElementReference($queryParameters['ManagementPackClassId'])
                            $class = $viewMp.Store.EntityTypes.GetClass($elementReference.Id)
                        } elseif ($item.Target -is [Microsoft.EnterpriseManagement.Configuration.ManagementPackElementReference`1[Microsoft.EnterpriseManagement.Configuration.ManagementPackClass]]) {
                            $class = $viewMp.Store.EntityTypes.GetClass([System.Guid]$item.Target.Id)
                        } else {
                            Write-Error "View $($item.Name) does not have a Management Pack class id and therefore is not supported by this command at this time."
                            continue
                        }

                        #endregion

                        #region Use search criteria if any is present or if a filter is applied.

                        $criteriaXml = $null
                        if (($node = $viewXml.SelectSingleNode('/View/Data/Criteria')) -and
                            (($elementList = $node.GetElementsByTagName('Criteria')).Count -gt 1)) {
                            $criteriaXml = $elementList[1].OuterXml
#                            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Filter')) {
#                                foreach ($filterItem in $Filter) {
#                                    $additionalCriteria = New-ScsmPxObjectSearchCriteria -Class $class -Filter $filterItem
#                                    $criteriaXml = (Join-CriteriaXml -CriteriaXml $criteriaXml -AdditionalCriteriaXml $additionalCriteria.Criteria).OuterXml
#                                }
#                            }
#                        } elseif ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Filter')) {
#                            foreach ($filterItem in $Filter) {
#                                if (-not $criteriaXml) {
#                                    $criteriaXml = (New-ScsmPxObjectSearchCriteria -Class $class -Filter $filterItem).Criteria
#                                } else {
#                                    $additionalCriteria = New-ScsmPxObjectSearchCriteria -Class $class -Filter $filterItem
#                                    $criteriaXml = (Join-CriteriaXml -CriteriaXml $criteriaXml -AdditionalCriteriaXml $additionalCriteria.Criteria).OuterXml
#                                }
#                            }
                        }

                        #endregion

                        #region Look up the view data using the view criteria or class.

                        if ($criteriaXml) {
                            $objectReaderSourceType = [Microsoft.EnterpriseManagement.Common.EnterpriseManagementObjectCriteria]
                            [Microsoft.EnterpriseManagement.Common.EnterpriseManagementObjectCriteria]$objectReaderSource = New-Object -TypeName Microsoft.EnterpriseManagement.Common.EnterpriseManagementObjectCriteria -ArgumentList $criteriaXml,$class,$viewMp,$viewMp.Store
                        } else {
                            $objectReaderSourceType = [Microsoft.EnterpriseManagement.Configuration.ManagementPackClass]
                            $objectReaderSource = $class
                        }
                        [Type[]]$methodType = ($objectReaderSourceType,[Microsoft.EnterpriseManagement.Common.ObjectQueryOptions])
                        $getObjectReaderMethod = $viewMp.Store.EntityObjects.GetType().GetMethod("GetObjectReader", $methodType)
                        $getObjectReaderGenericMethod = $getObjectReaderMethod.MakeGenericMethod([Microsoft.EnterpriseManagement.Common.EnterpriseManagementObject])
                        $reader = $getObjectReaderGenericMethod.Invoke($viewMp.Store.EntityObjects, ($objectReaderSource, [Microsoft.EnterpriseManagement.Common.ObjectQueryOptions]::Default))
                        for ($i = 0; $i -lt $reader.Count; $i++) {
                            New-ScsmPxViewDataRecord -EnterpriseManagementObject $reader.GetData($i)
                        }

                        #endregion
                    } else {
                        #region Look up the type projection object using the query parameters.

                        foreach ($queryParameterName in $queryParameters.Keys) {
                            if ($queryParameterName -eq 'TypeProjectionName') {
                                [Microsoft.EnterpriseManagement.Configuration.ManagementPackTypeProjection]$typeProjection = $viewMp.Store.EntityTypes.GetTypeProjections("Name='$($queryParameters[$queryParameterName])'") | Select-Object -First 1
                                break
                            } elseif ($queryParameterName -eq 'TypeProjectionId') {
                                $elementReference = $viewMp.ProcessElementReference($queryParameters[$queryParameterName])
                                [Microsoft.EnterpriseManagement.Configuration.ManagementPackTypeProjection]$typeProjection = $viewMp.Store.EntityTypes.GetTypeProjection($elementReference.Id)
                                break
                            }
                        }

                        #endregion

                        #region Create a projected type alias map.

                        $projectedTypeAliasMap = New-Object -TypeName System.Collections.Specialized.OrderedDictionary
                        foreach ($projectedTypeRecord in $typeProjection.GetEnumerator()) {
                            $projectedTypeAliasMap[$projectedTypeRecord.Key] = $typeProjection.Item($projectedTypeRecord.Key)[0].Alias
                        }

                        #endregion

                        #region Identify that we want all objects back from the view.

                        [Microsoft.EnterpriseManagement.Common.ObjectQueryOptions]$options = New-Object -TypeName Microsoft.EnterpriseManagement.Common.ObjectQueryOptions -ArgumentList ([Microsoft.EnterpriseManagement.Common.ObjectPropertyRetrievalBehavior]::All)

                        #endregion

                        #region Use search criteria if any is present or if a filter is applied.

                        $projectionCriteriaXml = $null
                        if (($node = $viewXml.SelectSingleNode('/View/Data/Criteria')) -and
                            (($elementList = $node.GetElementsByTagName('Criteria')).Count -gt 1)) {
                            $projectionCriteriaXml = $elementList[1].OuterXml
#                            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Filter')) {
#                                foreach ($filterItem in $Filter) {
#                                    $additionalProjectionCriteriaXml = ConvertTo-TypeProjectionCriteriaXml -TypeProjection $typeProjection -ViewMp $viewMp -Filter $filterItem
#                                    $projectionCriteriaXml = (Join-CriteriaXml -CriteriaXml $projectionCriteriaXml -AdditionalCriteriaXml $additionalProjectionCriteriaXml).OuterXml
#                                }
#                            }
#                        } elseif ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Filter')) {
#                            foreach ($filterItem in $Filter) {
#                                if (-not $projectionCriteriaXml) {
#                                    $projectionCriteriaXml = ConvertTo-TypeProjectionCriteriaXml -TypeProjection $typeProjection -ViewMp $viewMp -Filter $filterItem
#                                } else {
#                                    $additionalProjectionCriteriaXml = ConvertTo-TypeProjectionCriteriaXml -TypeProjection $typeProjection -ViewMp $viewMp -Filter $filterItem
#                                    $projectionCriteriaXml = (Join-CriteriaXml -CriteriaXml $projectionCriteriaXml -AdditionalCriteriaXml $additionalProjectionCriteriaXml).OuterXml
#                                }
#                            }
                        }

                        #endregion

                        if ($projectionCriteriaXml) {
                            #region If we have search criteria, use it with the type projection to create the object projection criteria.
                        
                            [Microsoft.EnterpriseManagement.Common.ObjectProjectionCriteria]$opc = New-Object -TypeName Microsoft.EnterpriseManagement.Common.ObjectProjectionCriteria -ArgumentList $projectionCriteriaXml,$typeProjection,$viewMp,$viewMp.Store

                            #endregion
                        } else {
                            #region Otherwise create the object projection criteria using the type projection by itself.

                            [Microsoft.EnterpriseManagement.Common.ObjectProjectionCriteria]$opc = New-Object -TypeName Microsoft.EnterpriseManagement.Common.ObjectProjectionCriteria -ArgumentList $typeProjection

                            #endregion
                        }

                        #region Pull the objects back from the server using the criteria and options we created.

                        [Type[]]$methodType = ([Microsoft.EnterpriseManagement.Common.ObjectProjectionCriteria],[Microsoft.EnterpriseManagement.Common.ObjectQueryOptions])
                        $getObjectProjectionReaderMethod = $viewMp.Store.EntityObjects.GetType().GetMethod("GetObjectProjectionReader", $methodType)
                        $getObjectProjectionReaderGenericMethod = $getObjectProjectionReaderMethod.MakeGenericMethod([Microsoft.EnterpriseManagement.Common.EnterpriseManagementObject])
                        $reader = $getObjectProjectionReaderGenericMethod.Invoke($viewMp.Store.EntityObjects, ($opc, $options))

                        #endregion

                        for ($i = 0; $i -lt $reader.Count; $i++) {
                            #region Get an object projection for the current object.

                            [Microsoft.EnterpriseManagement.Common.EnterpriseManagementObjectProjection]$projection = $reader.GetData($i)

                            #endregion

                            #region Add the projection EnterpriseManagementObjects to our object map.

                            $relatedEmoObjectMap = New-Object -TypeName System.Collections.Specialized.OrderedDictionary
                            foreach ($relatedObjectKey in @($projection) | Select-Object -ExpandProperty Key) {
                                $relatedEmoObjectMap[$projectedTypeAliasMap[$relatedObjectKey]] = $projection.Item($relatedObjectKey) | Select-Object -ExpandProperty Object
                            }

                            #endregion

                            #region Return the view record for the object received from the projection.

                            New-ScsmPxViewDataRecord -EnterpriseManagementObject $projection.Object -RelatedEnterpriseManagementObjectMap $relatedEmoObjectMap

                            #endregion
                        }
                    }
                }
            } else {
                #region Identify the parameters that will be used to find the view.

                switch ($PSCmdlet.ParameterSetName) {
                    'FromViewNameAndManagementGroupConnection' {
                        $passThruParameters = @{
                            Name = $ViewName
                        }
                        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('SCSession')) {
                            $passThruParameters['SCSession'] = $SCSession
                        }
                        break
                    }

                    'FromViewDisplayNameAndManagementGroupConnection' {
                        $passThruParameters = @{
                            DisplayName = $ViewDisplayName
                        }
                        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('SCSession')) {
                            $passThruParameters['SCSession'] = $SCSession
                        }
                        break
                    }

                    'FromViewNameAndComputerName' {
                        $passThruParameters = @{
                                    Name = $ViewName
                            ComputerName = $ComputerName
                        }
                        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Credential')) {
                            $passThruParameters['Credential'] = $Credential
                        }
                        break
                    }

                    'FromViewDisplayNameAndComputerName' {
                        $passThruParameters = @{
                             DisplayName = $ViewDisplayName
                            ComputerName = $ComputerName
                        }
                        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Credential')) {
                            $passThruParameters['Credential'] = $Credential
                        }
                        break
                    }
                }

                #endregion

                #region Now look up the appropriate views and get their view data.

                try {
                    if ($views = Get-SCSMView @passThruParameters) {
                        $passThruParameters = @{
                            View = $views
                        }
#                        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Filter')) {
#                            $passThruParameters['Filter'] = $PSCmdlet.MyInvocation.BoundParameters['Filter']
#                        }
                        Get-ScsmPxViewData @passThruParameters
                    }
                } catch [Microsoft.EnterpriseManagement.Common.ObjectNotFoundException] {
                    # Object not found exceptions should not be exposed to PowerShell. As a workaround,
                    # we can safely ignore these types of exceptions.
                    continue
                }

                #endregion
            }

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

Export-ModuleMember -Function Get-ScsmPxViewData
# SIG # Begin signature block
# MIIZKQYJKoZIhvcNAQcCoIIZGjCCGRYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUcfqdH8Md2I3ir8oqysZKU7nn
# b1OgghQZMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
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
# AQkEMRYEFPjW5drZp0HjieeXkSeomyXw7gCFMA0GCSqGSIb3DQEBAQUABIIBAH+w
# oSHM1EJEmh/A2hZ7tFhOvRLQghr7WwNdxp7DmC39bWZ/YSQ46eolXs0dTUvz3wvJ
# dJeU+FJ1X29WSPNC/hfJoPeg5dj0EkjlLo060YEi4mMHvNVOc5XwII0peaNwcpS5
# FLm5k594YiqC8HlMFRiRpg3bJCr/NcYPFdpz9SIWA898RUFm1heM1vARE1Vso1TR
# oUdPJxjzKdlOOOde/k4PPGMryOegFY4eAA0EOSTtEYgwxRBJJ/sxIBtnmKYTK134
# /nBBCE2/G36msG8AKOKMfgSgdVRg+zUcyodUM+zAp1WV0HeAFF0961hnwhs0ceSN
# zm9FkMFaX2ELCl+fJDuhggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBe
# MQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAu
# BgNVBAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQ
# Ds/0OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqG
# SIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTYwMTIwMjExOTI5WjAjBgkqhkiG9w0B
# CQQxFgQUrZWc653r3hMhH8JugEc927lZXlAwDQYJKoZIhvcNAQEBBQAEggEAGZ/a
# 0z4MyP5QcJVkmhoJnmY6nqlVmKuErYcZr1kapqpfHXjTm6jcuEeGJRmw5pJyPDQ8
# Ulae/2Mn8PcXK4Wj5/98yjrw+6wFetyAYFvMKG4Fu03D4/Hap1GygpITbWDOIm9y
# eoSfV1KYI0YIoiu07PXiPM3fIttqUPe/7KdOQxcCys0C/vRQ+f7+6qrGbS3ujsUx
# s+s1E4l8/VU8wGiiFbhDIERtbkMs3dZIH8y5rSLnID2B7TfKyF1gPhk0DIOAyJO1
# LdKF+rFZ2lktKBYmRs2zLuSo0utDwePbo6CEUUxwMaFJldu50kraJk3NVfcSQEEn
# pSN0XYmf18wIkrdlTA==
# SIG # End signature block
