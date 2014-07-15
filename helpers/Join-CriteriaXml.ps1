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

function Join-CriteriaXml {
    [CmdletBinding()]
    [OutputType([System.Xml.XmlDocument])]
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNull()]
        [ValidateScript({
            if ($_.DocumentElement.xmlns -ne 'http://Microsoft.EnterpriseManagement.Core.Criteria/') {
                throw 'CriteriaXml must contain an XML document from the namespace "http://Microsoft.EnterpriseManagement.Core.Criteria".'
            }
            $true
        })]
        [System.Xml.XmlDocument]
        $CriteriaXml,
        
        [Parameter(Position=1, Mandatory=$true)]
        [ValidateNotNull()]
        [ValidateScript({
            if ($_.DocumentElement.xmlns -ne 'http://Microsoft.EnterpriseManagement.Core.Criteria/') {
                throw 'AdditionalCriteriaXml must contain an XML document from the namespace "http://Microsoft.EnterpriseManagement.Core.Criteria".'
            }
            $true
        })]
        [System.Xml.XmlDocument]
        $AdditionalCriteriaXml
    )
    try {
        #region Join the reference XML entries from both of the documents.

        $referenceXmlEntries = @()
        foreach ($xmlDocument in $CriteriaXml,$AdditionalCriteriaXml) {
            foreach ($reference in $xmlDocument.GetElementsByTagName('Reference')) {
                if ($referenceXmlEntries -notcontains $reference.OuterXml) {
                    $referenceXmlEntries += $reference.OuterXml
                }
            }
        }
        $referenceXml = $referenceXmlEntries -join "`r`n"

        #endregion

        #region Join the expressions from both of the documents.

        $expressionXmlEntries = @()
        foreach ($xmlDocument in $CriteriaXml,$AdditionalCriteriaXml) {
            $expressionRoot = $xmlDocument.DocumentElement.CreateNavigator().SelectChildren('Expression',$xmlDocument.DocumentElement.xmlns) | Select-Object -First 1
            if (-not $expressionRoot) {
                continue
            }
            if ($andElement = $expressionRoot.SelectChildren('And',$xmlDocument.DocumentElement.xmlns) | Select-Object -First 1) {
                $expressions = $andElement.SelectChildren('Expression',$xmlDocument.DocumentElement.xmlns)
            } else {
                $expressions = $expressionRoot
            }
            foreach ($expression in $expressions) {
                if ($expressionXmlEntries -notcontains $expression.OuterXml) {
                    $expressionXmlEntries += $expression.OuterXml
                }
            }
        }
        $expressionXml = $expressionXmlEntries -join "`r`n"


        #endregion

        #region Now return the combined XML.

        [xml]@"
<Criteria xmlns='http://Microsoft.EnterpriseManagement.Core.Criteria/'>
${referenceXml}
<Expression>
  <And>
    ${expressionXml}
  </And>
</Expression>
</Criteria>
"@

        #endregion
    } catch {
        throw
    }
}