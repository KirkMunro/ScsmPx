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
function Get-ScsmPxListItem {
    [CmdletBinding(DefaultParameterSetName='FromManagementGroupConnection')]
    [OutputType('Microsoft.EnterpriseManagement.Configuration.ManagementPackEnumeration#Extended')]
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='FromListObject')]
        [ValidateNotNull()]
        [Microsoft.EnterpriseManagement.Configuration.ManagementPackEnumeration[]]
        $List,

        [Parameter(Position=0, ParameterSetName='FromManagementGroupConnection')]
        [Parameter(Position=0, ParameterSetName='FromManagementPack')]
        [Parameter(Position=0, ParameterSetName='FromComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $ListName = '*',

        [Parameter(Position=1)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Name = '*',

        [Parameter(Position=2)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $DisplayName = '*',

        [Parameter(ParameterSetName='FromManagementGroupConnection')]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.Core.Connection.Connection[]]
        $SCSession,

        [Parameter(Mandatory=$true, ParameterSetName='FromManagementPack')]
        [ValidateNotNullOrEmpty()]
        [Microsoft.EnterpriseManagement.Configuration.ManagementPack[]]
        $ManagementPack,

        [Parameter(Mandatory=$true, ParameterSetName='FromComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $ComputerName,

        [Parameter(ParameterSetName='FromComputerName')]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )
    begin {
        try {
            #region Define a helper script block that is used to recursively walk an enumeration.

            $processEnumeration = {
                [CmdletBinding()]
                [OutputType('Microsoft.EnterpriseManagement.Configuration.ManagementPackEnumeration#Extended')]
                param(
                    [Parameter(Position=0, Mandatory=$true)]
                    [ValidateNotNull()]
                    [Microsoft.EnterpriseManagement.EnterpriseManagementGroup]
                    $EnterpriseManagementGroup,

                    [Parameter(Position=1, Mandatory=$true)]
                    [ValidateNotNull()]
                    [Microsoft.EnterpriseManagement.Configuration.ManagementPackEnumeration]
                    $List,

                    [Parameter(Position=2, Mandatory=$true)]
                    [ValidateNotNull()]
                    [Microsoft.EnterpriseManagement.Configuration.ManagementPackEnumeration]
                    $Enumeration,

                    [Parameter(Position=3)]
                    [ValidateNotNullOrEmpty()]
                    [System.String[]]
                    $Name = '*',

                    [Parameter(Position=4)]
                    [ValidateNotNullOrEmpty()]
                    [System.String[]]
                    $DisplayName = '*',

                    [Parameter(Position=5)]
                    [ValidateNotNullOrEmpty()]
                    [System.String]
                    $ParentDisplayPath
                )
                #region Process the first level of child enumeration values.

                foreach ($childEnumeration in $EnterpriseManagementGroup.EntityTypes.GetChildEnumerations($Enumeration.Id,'OneLevel')) {
                    #region Add a display path property to the enumerated value.

                    $displayPathToken = if ($childEnumeration.DisplayName) {
                        $childEnumeration.DisplayName
                    } else {
                        $childEnumeration.Name
                    }

                    $displayPath = if ($Enumeration.Parent) {
                        "${ParentDisplayPath}\${displayPathToken}"
                    } else {
                        $displayPathToken
                    }
                    Add-Member -Force -InputObject $childEnumeration -Name List -MemberType NoteProperty -Value $List
                    Add-Member -Force -InputObject $childEnumeration -Name DisplayPath -MemberType NoteProperty -Value $displayPath

                    #endregion

                    #region Return the numeration if it passes the filters.

                    $returnEnumeration = $false
                    $childEnumerationSimplifiedName = $childEnumeration.Name -replace "^$([System.Text.RegularExpressions.Regex]::Escape($List.Name))\."
                    foreach ($item in $Name) {
                        if ($childEnumerationSimplifiedName -like $item) {
                            $returnEnumeration = $true
                            break
                        }
                    }
                    if ($returnEnumeration) {
                        $returnEnumeration = $false
                        foreach ($item in $DisplayName) {
                            if ($childEnumeration.DisplayName -like $item) {
                                $returnEnumeration = $true
                                break
                            }
                        }
                    }
                    if ($returnEnumeration) {
                        $childEnumeration
                    }

                    #endregion

                    #region Now process children of the child enumeration (if there are any).

                    & $processEnumeration -EnterpriseManagementGroup $EnterpriseManagementGroup -List $List -Enumeration $childEnumeration -Name $Name -DisplayName $DisplayName -ParentDisplayPath $displayPath

                    #endregion
                }

                #endregion
            }

            #endregion
        } catch {
            throw
        }
    }
    process {
        try {
            switch ($PSCmdlet.ParameterSetName) {
                'FromListObject' {
                    #region Retrieve the items in each list that match the filters that were passed in.

                    foreach ($item in $List) {
                        & $processEnumeration -EnterpriseManagementGroup $item.GetManagementPack().Store -List $item -Enumeration $item -Name $Name -DisplayName $DisplayName
                    }
                    break

                    #endregion
                }

                default {
                    #region Identify the parameters that we will pass through to look up the list(s).

                    $passThruParameters = @{
                        Name = $ListName
                    }
                    foreach ($parameterName in @('SCConnection','ManagementPack','ComputerName','Credential')) {
                        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey($parameterName)) {
                            $passThruParameters[$parameterName] = $PSCmdlet.MyInvocation.BoundParameters.$parameterName
                        }
                    }

                    #endregion

                    #region Now process any lists that meet our search criteria, and recurse into Get-ScsmPxListItem.

                    foreach ($list in Get-ScsmPxList @passThruParameters) {
                        Get-ScsmPxListItem -List $list -Name $Name -DisplayName $DisplayName
                    }
                    break

                    #endregion
                }
            }
        } catch {
            throw
        }
    }
}

Export-ModuleMember -Function Get-ScsmPxListItem