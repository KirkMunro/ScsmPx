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
    [OutputType('Microsoft.SystemCenter.ManagedComputerServer')]
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

        # The logic below was derived from details on the following SCSM team blog post (search for "a little bit of magic"):
        # http://blogs.technet.com/b/servicemanager/archive/2009/08/21/targeting-workflows-in-service-manager.aspx

        #region Look up the WWF target singleton instance.

        $wwfTarget = Get-ScsmPxObject -ClassName Microsoft.SystemCenter.WorkflowFoundation.WorkflowTarget @remotingParameters

        #endregion

        #region Identify the health service instance that manages the WWF target.

        $healthService = Get-ScsmPxRelatedObject -Target $wwfTarget -RelationshipClassName Microsoft.SystemCenter.HealthServiceManagesEntity @remotingParameters
        if (-not $healthService -or $healthService.GetType().IsArray) {
            [System.String]$message = 'Failed to find the health service that manages the WWF target.'
            [System.Management.Automation.ItemNotFoundException]$exception = New-Object -TypeName System.Management.Automation.ItemNotFoundException -ArgumentList $message
            [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'ItemNotFoundException',([System.Management.Automation.ErrorCategory]::ObjectNotFound),'Get-ScsmPxPrimaryManagementServer'
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        #endregion

        #region Return the computer that hosts the health service application.

        $computer = Get-ScsmPxRelatedObject -Target $healthService -RelationshipClassName Microsoft.Windows.ComputerHostsLocalApplication @remotingParameters
        if (-not $computer -or $computer.GetType().IsArray) {
            [System.String]$message = 'Failed to find the computer that hosts the health service application.'
            [System.Management.Automation.ItemNotFoundException]$exception = New-Object -TypeName System.Management.Automation.ItemNotFoundException -ArgumentList $message
            [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'ItemNotFoundException',([System.Management.Automation.ErrorCategory]::ObjectNotFound),'Get-ScsmPxPrimaryManagementServer'
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        #endregion
        
        #region Then return the computer that hosts the health service (the primary management server) to the caller.

        $computer

        #endregion
    } catch {
        throw
    }
}

Export-ModuleMember -Function Get-ScsmPxPrimaryManagementServer