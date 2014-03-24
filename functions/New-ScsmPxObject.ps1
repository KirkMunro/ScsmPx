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
function New-ScsmPxObject {
    [CmdletBinding(DefaultParameterSetName='FromClassObjectAndManagementGroupConnection',SupportsShouldProcess=$true)]
    [OutputType([Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance])]
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='FromClassObjectAndManagementGroupConnection')]
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='FromClassObjectAndComputerName')]
        [ValidateNotNullOrEmpty()]
        [Microsoft.EnterpriseManagement.Configuration.ManagementPackClass]
        $Class,

        [Parameter(Position=0, Mandatory=$true, ParameterSetName='FromClassNameAndManagementGroupConnection')]
        [Parameter(Position=0, Mandatory=$true, ParameterSetName='FromClassNameAndComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ClassName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable]
        $Property,

        [Parameter(ParameterSetName='FromClassObjectAndManagementGroupConnection')]
        [Parameter(ParameterSetName='FromClassNameAndManagementGroupConnection')]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.Core.Connection.Connection[]]
        $SCSession,

        [Parameter(Mandatory=$true, ParameterSetName='FromClassObjectAndComputerName')]
        [Parameter(Mandatory=$true, ParameterSetName='FromClassNameAndComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $ComputerName,

        [Parameter(ParameterSetName='FromClassObjectAndComputerName')]
        [Parameter(ParameterSetName='FromClassNameAndComputerName')]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $PassThru
    )
    begin {
        try {
            #region Ensure that objects are sent through the pipeline one at a time.

            $outBuffer = $null
            if ($PSCmdlet.MyInvocation.BoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer)) {
                $PSCmdlet.MyInvocation.BoundParameters['OutBuffer'] = 1
            }

            #endregion

            #region Add empty credential support, regardless of the function being proxied.

            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Credential') -and ($Credential -eq [System.Management.Automation.PSCredential]::Empty)) {
                $PSCmdlet.MyInvocation.BoundParameters.Remove('Credential') > $null
            }

            #endregion

            #region Look up the command being proxied.

            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('New-SCClassInstance', [System.Management.Automation.CommandTypes]::Cmdlet)

            #endregion

            #region If the command was not found, throw an appropriate command not found exception.

            if (-not $wrappedCmd) {
                [System.String]$message = $PSCmdlet.GetResourceString('DiscoveryExceptions','CommandNotFoundException')
                [System.Management.Automation.CommandNotFoundException]$exception = New-Object -TypeName System.Management.Automation.CommandNotFoundException -ArgumentList ($message -f 'New-SCClassInstance')
                $exception.CommandName = 'New-SCClassInstance'
                [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'DiscoveryExceptions',([System.Management.Automation.ErrorCategory]::ObjectNotFound),'New-SCClassInstance'
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }

            #endregion

            #region Identify the class that will be used in the query.

            switch -regex ($PSCmdlet.ParameterSetName) {
                '^FromClassObject' {
                    # Nothing to do in this case
                    break
                }
                '^FromClassName' {
                    # This parameter set allows for easy lookup using a class name. It facilitates working
                    # with SCSM data when you don't need to actually access the class object itself.
                    $remotingParameters = @{}
                    foreach ($remotingParameterName in @('SCSession','ComputerName','Credential')) {
                        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey($remotingParameterName)) {
                            $remotingParameters[$remotingParameterName] = $PSCmdlet.MyInvocation.BoundParameters.$remotingParameterName
                        }
                    }
                    $PSCmdlet.MyInvocation.BoundParameters['Class'] = $Class = Get-SCClass -Name $ClassName @remotingParameters
                    $PSCmdlet.MyInvocation.BoundParameters.Remove('ClassName') > $null
                    break
                }
                default {
                    throw 'This should never happen.'
                }
            }

            #endregion

            #region Create the proxy command script block.

            $scriptCmd = {& $wrappedCmd @PSBoundParameters}

            #endregion

            #region Use the script block to create the steppable pipeline, then invoke its begin block.

            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)

            #endregion
        } catch {
            throw
        }
    }
    process {
        try {
            #region Process the element that was just received from the previous stage in the pipeline.

            $steppablePipeline.Process($_)

            #endregion
        } catch {
            throw
        }
    }
    end {
        try {
            #region Close the pipeline.

            $steppablePipeline.End()

            #endregion
        } catch {
            throw
        }
    }
}

Export-ModuleMember -Function New-ScsmPxObject