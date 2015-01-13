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
        $PSCmdlet.ThrowTerminatingError($_)
    }
}