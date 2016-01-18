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
function Get-ScsmPxObject {
    [CmdletBinding(DefaultParameterSetName='FromClassObjectAndManagementGroupConnection')]
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
        [System.String[]]
        $DisplayName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Guid[]]
        $Id,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Filter,

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
        $Credential = [System.Management.Automation.PSCredential]::Empty
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

            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Get-SCClassInstance', [System.Management.Automation.CommandTypes]::Cmdlet)

            #endregion

            #region If the command was not found, throw an appropriate command not found exception.

            if (-not $wrappedCmd) {
                [System.String]$message = $PSCmdlet.GetResourceString('DiscoveryExceptions','CommandNotFoundException')
                [System.Management.Automation.CommandNotFoundException]$exception = New-Object -TypeName System.Management.Automation.CommandNotFoundException -ArgumentList ($message -f 'Get-SCClassInstance')
                $exception.CommandName = 'Get-SCClassInstance'
                [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'DiscoveryExceptions',([System.Management.Automation.ErrorCategory]::ObjectNotFound),'Get-SCClassInstance'
                throw $errorRecord
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
                    if (-not ($Class = Get-SCClass -Name $ClassName @remotingParameters)) {
                        [System.String]$message = "Class not found. Class ${ClassName} was not found in Service Manager."
                        [System.Management.Automation.ItemNotFoundException]$exception = New-Object -TypeName System.Management.Automation.ItemNotFound -ArgumentList $message
                        [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'NotFoundExceptions',([System.Management.Automation.ErrorCategory]::ObjectNotFound),$ClassName
                        throw $errorRecord
                    }
                    $PSCmdlet.MyInvocation.BoundParameters['Class'] = $Class
                    $PSCmdlet.MyInvocation.BoundParameters.Remove('ClassName') > $null
                    break
                }
                default {
                    throw 'This should never happen.'
                }
            }

            #endregion

            #region If the Name, Id, or DisplayName parameters were used, add them to the filter.

            foreach ($parameterName in @('Id','DisplayName','Name')) {
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey($parameterName)) {
                    $partialFilters = @()
                    :nextItem foreach ($item in $PSCmdlet.MyInvocation.BoundParameters.$parameterName) {
                        foreach ($wildcardCharacter in @('*','?')) {
                            if ($item -match "(?<!``{1})${wildcardCharacter}") {
                                $partialFilters += "${parameterName} -like ""${item}"""
                                continue nextItem
                            }
                        }
                        $partialFilters += "${parameterName} -eq ""${item}"""
                    }
                    if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Filter')) {
                        if ($PSCmdlet.MyInvocation.BoundParameters.Filter -notmatch '^\(.+\)$') {
                            $PSCmdlet.MyInvocation.BoundParameters.Filter = "($($PSCmdlet.MyInvocation.BoundParameters.Filter))"
                        }
                        $PSCmdlet.MyInvocation.BoundParameters.Filter = "($($partialFilters -join ' -or ')) -and $($PSCmdlet.MyInvocation.BoundParameters.Filter)"
                    } else {
                        $PSCmdlet.MyInvocation.BoundParameters.Filter = $partialFilters -join ' -or '
                    }
                    $PSCmdlet.MyInvocation.BoundParameters.Remove($parameterName) > $null
                }
            }

            #endregion

            #region If we have a filter, adjust the passthrough parameters accordingly.

            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Filter')) {
                $PSCmdlet.MyInvocation.BoundParameters['Criteria'] = New-ScsmPxObjectSearchCriteria -Class $PSCmdlet.MyInvocation.BoundParameters.Class -Filter $PSCmdlet.MyInvocation.BoundParameters.Filter
                $PSCmdlet.MyInvocation.BoundParameters.Remove('Class') > $null
                $PSCmdlet.MyInvocation.BoundParameters.Remove('Filter') > $null
            }

            #endregion

            #region Create the proxy command script block.

            $scriptCmd = {& $wrappedCmd @PSBoundParameters | Add-ClassHierarchyToTypeNameList}

            #endregion

            #region Use the script block to create the steppable pipeline, then invoke its begin block.

            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    process {
        try {
            #region Process the element that was just received from the previous stage in the pipeline.

            $steppablePipeline.Process($_)

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    end {
        try {
            #region Close the pipeline.

            $steppablePipeline.End()

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

Export-ModuleMember -Function Get-ScsmPxObject