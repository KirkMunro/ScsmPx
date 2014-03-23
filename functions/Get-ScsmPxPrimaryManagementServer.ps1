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
function Get-ScsmPxPrimaryManagementServer {
    [CmdletBinding(DefaultParameterSetName='FromManagementGroupConnection')]
    [OutputType('Microsoft.SystemCenter.RootManagementServer')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='FromComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ComputerName,

        [Parameter(ParameterSetName='FromComputerName')]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter(ParameterSetName='FromManagementGroupConnection')]
        [ValidateNotNull()]
        [Microsoft.SystemCenter.Core.Connection.Connection]
        $SCSession
    )
    try {
        #region Prepare for splatting of remoting parameters if required.

        $remotingParameters = @{}
        foreach ($remotingParameterName in 'ComputerName','Credential','SCSession') {
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey($remotingParameterName)) {
                $remotingParameters[$remotingParameterName] = $PSCmdlet.MyInvocation.BoundParameters.$remotingParameterName
            }
        }

        #endregion

        #region Get the relationships we need so that we can use them later.

        $chlaRelationship = Get-SCRelationship -Name Microsoft.Windows.ComputerHostsLocalApplication @remotingParameters
        $hsmeRelationship = Get-SCRelationship -Name Microsoft.SystemCenter.HealthServiceManagesEntity @remotingParameters

        #endregion

        #region Get a list of the computers that are running SCSM Management Servers.

        $windowsComputers = @()
        foreach ($scsmManagementServer in Get-ScsmPxManagementServer @remotingParameters) {
            if ($windowsComputer = $scsmManagementServer.GetRelatedObjectsWhereTarget($chlaRelationship.Id)) {
                $windowsComputers += $windowsComputer.EnterpriseManagementObject
            }
        }

        #endregion

        #region Identify which of the SCSM Management Servers has an associated Health Service (this is the workflow server).

        # This logic was derived from details on the following SCSM blog post (search for "a little bit of magic"):
        # http://blogs.technet.com/b/servicemanager/archive/2009/08/21/targeting-workflows-in-service-manager.aspx

        :outer foreach ($hs in Get-ScsmPxObject -ClassName Microsoft.SystemCenter.HealthService @remotingParameters) {
            $relatedTargets = @($hs.GetRelatedObjectsWhereSource($hsmeRelationship.Id) | Select-Object -ExpandProperty EnterpriseManagementObject)
            foreach ($windowsComputer in $windowsComputers) {
                if ($relatedTargets -contains $windowsComputer) {
                    $windowsComputerInstance = $windowsComputer -as [Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance]
                    $windowsComputerInstance.ToPSObject()
                    break outer
                }
            }
        }

        #endregion
    } catch {
        throw
    }
}

Export-ModuleMember -Function Get-ScsmPxPrimaryManagementServer