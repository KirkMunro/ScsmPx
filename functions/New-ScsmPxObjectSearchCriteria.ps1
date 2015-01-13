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
function New-ScsmPxObjectSearchCriteria {
    [CmdletBinding()]
    [OutputType([Microsoft.EnterpriseManagement.Common.EnterpriseManagementObjectCriteria])]
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('SearchString')]
        [System.String]
        $Filter,

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

        #region Replace any property names that are not using the correct case-sensitivity.

        $properties = @{}
        foreach ($item in @($Class) + @($Class.GetBaseTypes())) {
            foreach ($property in $item.GetProperties()) {
                if (-not $properties.ContainsKey($property.Name)) {
                    $properties[$property.Name] = $property
                }
            }
        }
        $stringBuilder = [System.Text.StringBuilder]$Filter
        foreach ($token in [System.Management.Automation.PSParser]::Tokenize($Filter,([REF]$null))) {
            if ($token.Type -ne [System.Management.Automation.PSTokenType]::Command) {
                continue
            }
            if ($properties.ContainsKey($token.Content)) {
                $stringBuilder = $stringBuilder.Replace($token.Content, $properties[$token.Content].Name, $token.Start, $token.Length)
            }
        }
        $Filter = [string]$stringBuilder

        #endregion

        #region Transform the search string using the operator and wildcard maps.

        $Filter = $Filter -replace '"',''''
        foreach ($operator in $operatorMap.Keys) {
            $Filter = $Filter -replace "([^0-9a-z]*)$([System.Text.RegularExpressions.Regex]::Escape($operator))([^0-9a-z]*)","`$1$($operatorMap.$operator)`$2"
        }
        foreach ($wildcard in $wildcardMap.Keys) {
            # First replace the unescaped wildcard characters
            $Filter = $Filter -replace "(?<!``)$([System.Text.RegularExpressions.Regex]::Escape($wildcard))",$wildcardMap.$wildcard
            # Now remove the escape characters from the wildcards that are escaped
            $Filter = $Filter -replace "``$([System.Text.RegularExpressions.Regex]::Escape($wildcard))",$wildcard
        }

        #endregion

        #region Create and return the new search criteria object, applying the appropriate XML escape characters and replacing PowerShell operators where necessary.

        New-Object -TypeName Microsoft.EnterpriseManagement.Common.EnterpriseManagementObjectCriteria -ArgumentList @(
            $Filter
            $Class
        )

        #endregion
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Export-ModuleMember -Function New-ScsmPxObjectSearchCriteria