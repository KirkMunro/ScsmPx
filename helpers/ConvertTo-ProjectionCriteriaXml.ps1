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

function ConvertTo-ProjectionCriteriaXml {
    [CmdletBinding()]
    [OutputType([System.String])]
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNull()]
        [Microsoft.EnterpriseManagement.Configuration.ManagementPack]
        $ViewMp,

        [Parameter(Position=1, Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNull()]
        [Microsoft.EnterpriseManagement.Common.EnterpriseManagementObjectCriteria]
        $EmoCriteria
    )
    try {
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