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
function Remove-ScsmPxObject {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance])]
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('EnterpriseManagementInstance')]
        [Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance[]]
        $InputObject,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Force
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

            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Force') -and $Force) {
                $cmdletName = 'Remove-SCClassInstance'
                $PSCmdlet.MyInvocation.BoundParameters.Remove('Force') > $null
            } else {
                $cmdletName = 'Update-SCClassInstance'
            }
            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand($cmdletName, [System.Management.Automation.CommandTypes]::Cmdlet)

            #endregion

            #region If the command was not found, throw an appropriate command not found exception.

            if (-not $wrappedCmd) {
                [System.String]$message = $PSCmdlet.GetResourceString('DiscoveryExceptions','CommandNotFoundException')
                [System.Management.Automation.CommandNotFoundException]$exception = New-Object -TypeName System.Management.Automation.CommandNotFoundException -ArgumentList ($message -f $cmdletName)
                $exception.CommandName = $cmdletName
                [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'DiscoveryExceptions',([System.Management.Automation.ErrorCategory]::ObjectNotFound),$cmdletName
                throw $errorRecord
            }

            #endregion

            #region Replace any InputObject bound parameters with an Instance bound parameter.

            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('InputObject')) {
                $PSCmdlet.MyInvocation.BoundParameters['Instance'] = $PSCmdlet.MyInvocation.BoundParameters['InputObject']
                $PSCmdlet.MyInvocation.BoundParameters.Remove('InputObject') > $null
            }

            #endregion

            #region Define ShouldProcess helper arguments.

            if ($cmdletName -eq 'Update-SCClassInstance') {
                $ShouldProcessArguments = @{
                    Description = "Setting property ""ObjectStatus"" on ""{0}""."
                    Warning = "Set property ""ObjectStatus"" on ""{0}"""
                }
            } else {
                $ShouldProcessArguments = @{
                    Description = "Removing all relationships associated with ""{0}""."
                    Warning = "Remove all relationships associated with ""{0}"""
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
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    process {
        try {
            foreach ($item in $InputObject) {
                if ($cmdletName -eq 'Update-SCClassInstance') {
                    if (@($item.__EnterpriseManagementObject.GetClasses([Microsoft.EnterpriseManagement.Configuration.BaseClassTraversalDepth]::Recursive) | Select-Object -ExpandProperty Name) -contains 'System.ConfigItem') {
                        if ($PSCmdlet.ShouldProcess(($ShouldProcessArguments.Description -f $item.DisplayName), 'Confirm', ($ShouldProcessArguments.Warning -f $item.DisplayName))) {
                            #region Assign the properties to the element that was just received from the previous stage in the pipeline.

                            $item.ObjectStatus = $item.__EnterpriseManagementObject.ManagementGroup.EntityTypes.GetEnumeration('47101e64-237f-12c8-e3f5-ec5a665412fb')

                            #endregion.
                        }

                        #region Process the element that was just received from the previous stage in the pipeline.

                        $steppablePipeline.Process($item)

                        #endregion
                    } else {
                        #region Raise an error indicating that non-config items may only be removed with the -Force parameter.

                        [System.String]$message = 'The -Force parameter is required to remove non-config items. Please rerun your previous command with the -Force parameter if you want to permanently delete these items.'
                        [System.InvalidOperationException]$exception = New-Object -TypeName System.InvalidOperationException -ArgumentList $message
                        [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'InvalidOperationException',([System.Management.Automation.ErrorCategory]::InvalidOperation),$item
                        throw $errorRecord

                        #endregion
                    }
                } else {
                    #region Remove all relationships that are linked to the Enterprise Management Object before removing the object itself.

                    if ($PSCmdlet.ShouldProcess(($ShouldProcessArguments.Description -f $item.DisplayName), 'Confirm', ($ShouldProcessArguments.Warning -f $item.DisplayName))) {
                        $emg = $item.__EnterpriseManagementObject.ManagementGroup
                        [Type[]]$getRelationshipObjectsMethodType = @(
                            [System.Guid]
                            [Microsoft.EnterpriseManagement.Common.TraversalDepth]
                            [Microsoft.EnterpriseManagement.Common.ObjectQueryOptions]
                        )
                        $getRelationshipObjectsMethod = $emg.EntityObjects.GetType().GetMethod('GetRelationshipObjectsWhereSource', $getRelationshipObjectsMethodType)
                        $getRelationshipObjectsGenericMethod = $getRelationshipObjectsMethod.MakeGenericMethod([Microsoft.EnterpriseManagement.Common.EnterpriseManagementObject])
                        $getRelationshipObjectsGenericMethodParameters = @(
                            $item.__EnterpriseManagementObject.Id,
                            [Microsoft.EnterpriseManagement.Common.TraversalDepth]::OneLevel,
                            [Microsoft.EnterpriseManagement.Common.ObjectQueryOptions]::Default
                        )
                        foreach ($relationshipItem in $getRelationshipObjectsGenericMethod.Invoke($emg.EntityObjects, $getRelationshipObjectsGenericMethodParameters)) {
                            Remove-SCRelationshipInstance -Instance $relationshipItem
                        }
                        [Type[]]$getRelationshipObjectsMethodType = @(
                            [System.Guid]
                            [Microsoft.EnterpriseManagement.Common.ObjectQueryOptions]
                        )
                        $getRelationshipObjectsMethod = $emg.EntityObjects.GetType().GetMethod('GetRelationshipObjectsWhereTarget', $getRelationshipObjectsMethodType)
                        $getRelationshipObjectsGenericMethod = $getRelationshipObjectsMethod.MakeGenericMethod([Microsoft.EnterpriseManagement.Common.EnterpriseManagementObject])
                        $getRelationshipObjectsGenericMethodParameters = @(
                            $item.__EnterpriseManagementObject.Id,
                            [Microsoft.EnterpriseManagement.Common.ObjectQueryOptions]::Default
                        )
                        foreach ($relationshipItem in $getRelationshipObjectsGenericMethod.Invoke($emg.EntityObjects, $getRelationshipObjectsGenericMethodParameters)) {
                            Remove-SCRelationshipInstance -Instance $relationshipItem
                        }
                    }

                    #endregion

                    #region Process the element that was just received from the previous stage in the pipeline.

                    $steppablePipeline.Process($item)

                    #endregion
                }
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

Export-ModuleMember -Function Remove-ScsmPxObject