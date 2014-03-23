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
function New-ScsmPxObjectSearchCriteria {
    [CmdletBinding()]
    [OutputType([Microsoft.EnterpriseManagement.Common.EnterpriseManagementObjectCriteria])]
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $SearchString,

        [Parameter(Position=1, Mandatory=$true)]
        [ValidateNotNull()]
        [Microsoft.EnterpriseManagement.Configuration.ManagementPackClass]
        $Class
    )
    try {
        #region Define the PowerShell to SQL operator and wildcard maps.

        # See: http://msdn.microsoft.com/en-us/library/bb437603.aspx

        # [ordered] does not work in PowerShell 2, so we need to explicitly
        # use the OrderedDictionary class instead.
        $operatorMap = New-Object -TypeName System.Collections.Specialized.OrderedDictionary
        $operatorMap['-eq $null'] = 'IS NULL'
        $operatorMap['-ne $null'] = 'IS NOT NULL'
        $operatorMap[      '-eq'] = '='
        $operatorMap[      '-ne'] = '!='
        $operatorMap[      '-gt'] = '>'
        $operatorMap[      '-lt'] = '<'
        $operatorMap[      '-ge'] = '>='
        $operatorMap[      '-le'] = '<='
        $operatorMap[    '-like'] = 'LIKE'
        $operatorMap[   '-match'] = 'MATCHES'
        $operatorMap[      '-in'] = 'IN'
        $operatorMap[     '-and'] = 'AND'
        $operatorMap[      '-or'] = 'OR'
        $operatorMap[     '-not'] = 'NOT'

        $wildcardMap = @{
            '?' = '_'
            '*' = '%'
        }

        #endregion

        #region Transform the search string using the operator and wildcard maps.

        $SearchString = $SearchString -replace '"',''''
        foreach ($operator in $operatorMap.Keys) {
            $SearchString = $SearchString -replace "([^0-9a-z]*)$([System.Text.RegularExpressions.Regex]::Escape($operator))([^0-9a-z]*)","`$1$($operatorMap.$operator)`$2"
        }
        foreach ($wildcard in $wildcardMap.Keys) {
            # First replace the unescaped wildcard characters
            $SearchString = $SearchString -replace "(?<!``)$([System.Text.RegularExpressions.Regex]::Escape($wildcard))",$wildcardMap.$wildcard
            # Now remove the escape characters from the wildcards that are escaped
            $SearchString = $SearchString -replace "``$([System.Text.RegularExpressions.Regex]::Escape($wildcard))",$wildcard
        }

        #endregion

        #region Create and return the new search criteria object, applying the appropriate XML escape characters and replacing PowerShell operators where necessary.

        New-Object -TypeName Microsoft.EnterpriseManagement.Common.EnterpriseManagementObjectCriteria -ArgumentList @(
            $SearchString
            $Class
        )

        #endregion
    } catch {
        throw
    }
}

Export-ModuleMember -Function New-ScsmPxObjectSearchCriteria