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
            [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'ItemNotFoundException',([System.Management.Automation.ErrorCategory]::ObjectNotFound),$healthService
            throw $errorRecord
        }

        #endregion

        #region Return the computer that hosts the health service application.

        $computer = Get-ScsmPxRelatedObject -Target $healthService -RelationshipClassName Microsoft.Windows.ComputerHostsLocalApplication @remotingParameters
        if (-not $computer -or $computer.GetType().IsArray) {
            [System.String]$message = 'Failed to find the computer that hosts the health service application.'
            [System.Management.Automation.ItemNotFoundException]$exception = New-Object -TypeName System.Management.Automation.ItemNotFoundException -ArgumentList $message
            [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'ItemNotFoundException',([System.Management.Automation.ErrorCategory]::ObjectNotFound),$computer
            throw $errorRecord
        }

        #endregion
        
        #region Then return the computer that hosts the health service (the primary management server) to the caller.

        $computer

        #endregion
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Export-ModuleMember -Function Get-ScsmPxPrimaryManagementServer