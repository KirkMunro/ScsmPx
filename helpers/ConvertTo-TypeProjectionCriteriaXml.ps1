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

function ConvertTo-TypeProjectionCriteriaXml {
    [CmdletBinding()]
    [OutputType([System.String])]
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNull()]
        [Microsoft.EnterpriseManagement.Configuration.ManagementPackTypeProjection]
        $TypeProjection,

        [Parameter(Position=1, Mandatory=$true)]
        [ValidateNotNull()]
        [Microsoft.EnterpriseManagement.Configuration.ManagementPack]
        $ViewMp,

        [Parameter(Position=2, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Filter
    )
    try {
        #region Parse the filter using the v1 parser, injecting $_ where appropriate.

        # We use the PowerShell v1 parser for the initial tokenizing because it handles strings with spaces
        # properly (this saves us from having to do that work). We ignore any errors it finds and simply
        # identify where we want to inject "$_." into the filter.
        $parseErrors = $null
        if ($tokens = [System.Management.Automation.PSParser]::Tokenize($Filter, ([REF]$parseErrors))) {
            # Once we have the tokens, we reverse the collection so that we can process it from back to front
            # more easily
            $tokens = @($tokens[($tokens.Count - 1)..0])
        }
        # Now walk through the reverse token array, and inject '$_.' before any non-string, non-numeric token
        # that does not start with '-' and that contains at least one alphabetic character.
        foreach ($token in $tokens) {
            if ((@('String','Number','Variable') -contains $token.Type) -or
                ($token.Content -match '^-') -or
                ($token.Content -notmatch '[a-z]')) {
                continue
            }
            $Filter = $Filter.Insert($token.Start, '$_.')
        }

        #endregion

        #region Parse the modified filter using the AST parser so that we can break out subexpressions.

        # throw on error if the AST itself does not parse or if it contains anything other than the types of tokens we expect
        # that means no variables (or can we evaluate them at the time of parsing?)
        # Walk the tree and generate the criteria by going through the binary and unary expressions
        # separate by -and's and -or's, then get the criteria and convert it to t.p. criteria
        $tokens = $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($Filter, ([REF]$tokens), ([REF]$parseErrors))
        if ($parseErrors) {
            # TODO: Throw an invalid parameter exception here on the Filter parameter.
        }
        foreach ($expression in $ast.FindAll({$args[0] -is [System.Management.Automation.Language.BinaryExpressionAst] -or $args[0] -is [System.Management.Automation.Language.UnaryExpressionAst]},$false)) {
            if ($expression -is [System.Management.Automation.Language.BinaryExpressionAst]) {
                $member = $null
                foreach ($side in 'Left','Right') {
                    if ($expression.$side -is [System.Management.Automation.Language.MemberExpressionAst]) {
                        $member = $expression.$side.Member.Value
                    }
                }
            } else {
            }
        }

        #endregion

        # Add validator that there are no -ands or -ors to this
        # Check "commands" for "." and split on them, identifying properties in the type projection and their types and then get the EMO criteria for those types
        # Convert the EMO criteria to type projection criteria and add the object type (strip off the GUID from the EMO criteria)
        # Inject the path for the object into the result so that the property can be found for the comparison

        #region Initialize the output stream.

        $outputMemoryStream = New-Object -TypeName System.IO.MemoryStream
        $outputStreamReader = New-Object -TypeName System.IO.StreamReader -ArgumentList $outputMemoryStream

        #endregion

        #region Load the xslt document.

        $xslTransform = New-Object -TypeName System.Xml.Xsl.XslCompiledTransform
        $xslTransform.Load("${PSModuleRoot}\xslt\emoCriteriaToProjectionCriteria.xslt")

        #endregion

        #region Transform the xml using the xslt document.

        $inputMemoryStream = New-Object -TypeName System.IO.MemoryStream -ArgumentList (,[System.Text.Encoding]::UTF8.GetBytes($EmoCriteria.CriteriaXml))
        $inputXPathDocument = New-Object -TypeName System.Xml.XPath.XPathDocument -ArgumentList $inputMemoryStream
        $xslTransform.Transform($inputXPathDocument, $null, $outputMemoryStream)

        #endregion

        #region Identify the management pack reference string.

        $class = $EmoCriteria.ManagementPackClass
        $classMp = $class.GetManagementPack()
        $classMpReference = New-Object -TypeName Microsoft.EnterpriseManagement.Configuration.ManagementPackReference -ArgumentList $classMp
        if ($ViewMp.References.ContainsValue($classMpReference)) {
            $propertyQualifier = "$($ViewMp.References.GetAlias($classMpReference))!$($class.Name)"
        } else {
            $propertyQualifier = "$($classMp.Name)!$($class.Name)"
        }
        
        #endregion

        #region Return the XML (with the qualifier injected) to the caller.

        $outputMemoryStream.Position = 0
        ($outputStreamReader.ReadToEnd() -as [System.String]) -f $propertyQualifier

        #endregion
    } catch {
        throw
    } finally {
        #region Close the output stream reader.

        if ($outputStreamReader) {
            $outputStreamReader.Close()
        }

        #endregion
    }
}