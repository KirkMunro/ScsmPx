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
function Set-ScsmPxObject {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance])]
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('EnterpriseManagementInstance')]
        [Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance[]]
        $InputObject,

        [Parameter(Position=1, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('PropertyValues')]
        [System.Collections.Hashtable]
        $Property,

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

            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Update-SCClassInstance', [System.Management.Automation.CommandTypes]::Cmdlet)

            #endregion

            #region If the command was not found, throw an appropriate command not found exception.

            if (-not $wrappedCmd) {
                [System.String]$message = $PSCmdlet.GetResourceString('DiscoveryExceptions','CommandNotFoundException')
                [System.Management.Automation.CommandNotFoundException]$exception = New-Object -TypeName System.Management.Automation.CommandNotFoundException -ArgumentList ($message -f 'Update-SCClassInstance')
                $exception.CommandName = 'Update-SCClassInstance'
                [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'DiscoveryExceptions',([System.Management.Automation.ErrorCategory]::ObjectNotFound),'Update-SCClassInstance'
                throw $errorRecord
            }

            #endregion

            #region Replace any InputObject bound parameters with an Instance bound parameter.

            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('InputObject')) {
                $PSCmdlet.MyInvocation.BoundParameters['Instance'] = $PSCmdlet.MyInvocation.BoundParameters['InputObject']
                $PSCmdlet.MyInvocation.BoundParameters.Remove('InputObject') > $null
            }

            #endregion

            #region Remove the Property parameter from the passthru parameter list and define ShouldProcess helper arguments.

            $PSCmdlet.MyInvocation.BoundParameters.Remove('Property') > $null
            $propertyKeys = @($Property.Keys)
            if ($propertyKeys.Count -gt 1) {
                $propertyValuesAsString = """$($propertyKeys[0..($propertyKeys.Count - 2)] -join '", "')"" and ""$($propertyKeys[-1])"""
                $ShouldProcessArguments = @{
                    Description = "Setting properties ${propertyValuesAsString} on ""{0}""."
                    Warning = "Set properties ${propertyValuesAsString} on ""{0}"""
                }
            } else {
                $propertyValuesAsString = """$($propertyKeys[0])"""
                $ShouldProcessArguments = @{
                    Description = "Setting property ${propertyValuesAsString} on ""{0}""."
                    Warning = "Set property ${propertyValuesAsString} on ""{0}"""
                }
            }

            #endregion

            #region Remove the PassThru parameter.

            # This is necessary to work around a bug in how Update-SCClassInstance passes through objects
            # (it re-adds all of the PS Properties to the object passed in).

            if ($PassThru = ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('PassThru') -and $PassThru)) {
                $PSCmdlet.MyInvocation.BoundParameters.Remove('PassThru') > $null
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
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    process {
        try {
            foreach ($item in $InputObject) {
                #region Assign the properties to the element that was just received from the previous stage in the pipeline.

                if ($PSCmdlet.ShouldProcess(($ShouldProcessArguments.Description -f $item.DisplayName), 'Confirm', ($ShouldProcessArguments.Warning -f $item.DisplayName))) {
                    foreach ($propertyName in $Property.Keys) {
                        $item.$propertyName = $Property.$propertyName
                    }
                }

                #endregion.

                #region Process the element that was just received from the previous stage in the pipeline.

                $steppablePipeline.Process($item)

                #endregion

                #region If the object was to be passed through, pass it though.
            
                if ($PassThru) {
                    $item
                }

                #endregion
            }
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

Export-ModuleMember -Function Set-ScsmPxObject