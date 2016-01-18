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
function Reset-ScsmPxCommandCache {
    [CmdletBinding()]
    param()
    try {
        if ($PSVersionTable.PSVersion -ge [System.Version]'3.0') {
            Get-Module -ListAvailable -Name ScsmPx -Refresh > $null
        } else {
            Write-Warning 'Reset-ScsmPxCommandCache is only necessary in PowerShell version 3.0 and later.'
        }
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Export-ModuleMember -Function Reset-ScsmPxCommandCache