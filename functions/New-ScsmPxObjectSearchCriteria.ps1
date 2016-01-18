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

        #region Replace any property names that are not using the correct case-sensitivity, and any values that are variables.

        $properties = @{}
        foreach ($item in @($Class) + @($Class.GetBaseTypes())) {
            foreach ($property in $item.GetProperties()) {
                if (-not $properties.Contains($property.Name)) {
                    $properties[$property.Name] = $property
                }
            }
        }
        # Determine how far up the stack we want to look for variables when evaluating the filter parameter.
        $scope = 0
        foreach ($callStackEntry in Get-PSCallStack) {
            if (($callStackEntry.InvocationInfo.MyCommand.Parameters -ne $null) -and
                $callStackEntry.InvocationInfo.MyCommand.Parameters.ContainsKey('Filter')) {
                $scope++
                continue
            }
            break
        }
        # Replace variables with values
        $stringBuilder = [System.Text.StringBuilder]$Filter
        $tokenOffset = 0
        foreach ($token in [System.Management.Automation.PSParser]::Tokenize($Filter,([REF]$null))) {
            # Skip tokens until we find a "command" (property to filter on)
            if ($token.Type -ne [System.Management.Automation.PSTokenType]::Command) {
                continue
            }

            # Verify that the property exists on the object we are searching
            if (-not $properties.Contains($token.Content)) {
                throw "Invalid filter. Property '$($token.Content)' does not exist on management pack class '$($Class.Name)'."
            }

            # Workaround to the $foreach iterator bug
            while ($foreach.Current -ne $token) {
                if (-not $foreach.MoveNext()) {
                    break
                }
            }

            # Ensure the property name is using the correct case
            if ($properties.Contains($token.Content)) {
                $replacementValue = $properties[$token.Content].Name;
                $stringBuilder = $stringBuilder.Replace($token.Content, $replacementValue, $token.Start + $tokenOffset, $token.Length)
                # We need to update the offset so that multiple replacements in sequence work just fine
                $tokenOffset += $replacementValue.Length - $token.Content.Length
            }
            # If the next token is an operator, and the following one is a variable, replace the variable with its string equivalent
            $foreach.MoveNext() > $null
            if (($foreach.Current.Type -ne [System.Management.Automation.PSTokenType]::CommandParameter) -or
                -not $operatorMap.Contains(($operator = $foreach.Current.Content))) {
                continue
            }
            $foreach.MoveNext() > $null
            if ($foreach.Current.Type -eq [System.Management.Automation.PSTokenType]::Variable) {
                $variableToken = $foreach.Current
                # If the operator is -eq or -ne and the variable is $null, leave it for replacement later as this is a special case
                if ((@('-eq','-ne') -contains $operator) -and
                    ($variableToken.Content -eq 'null')) {
                    continue
                }
                # Otherwise, replace the variable with its string equivalent
                $replacementValue = "'$((Get-Variable -Name $variableToken.Content -Scope $scope -ValueOnly) -as $properties[$token.Content].SystemType)'"
                $stringBuilder = $stringBuilder.Replace("`$$($variableToken.Content)", $replacementValue, $variableToken.Start + $tokenOffset, $variableToken.Length)
                # We need to update the offset so that multiple replacements in sequence work just fine; the -1 at
                # the end ensures that we account for the $ preceding the variable token.
                $tokenOffset += $replacementValue.Length - $variableToken.Content.Length - 1
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