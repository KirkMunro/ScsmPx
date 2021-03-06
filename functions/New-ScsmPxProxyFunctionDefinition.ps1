﻿<#############################################################################
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

function New-ScsmPxProxyFunctionDefinition {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ScriptBlock])]
    param(
        [Parameter(Position=1, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Verb,

        [Parameter(Position=2, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Noun,

        [Parameter(Position=3, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ClassName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $NounPrefix = '',

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $ConfigItem,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable]
        $Views
    )

    try {
        $functionToProxy = "${Verb}-ScsmPxObject"
        $proxyFunctionName = "${Verb}-${NounPrefix}${Noun}"
        switch ($functionToProxy) {
            'New-ScsmPxObject' {
                $ExecutionContext.InvokeCommand.NewScriptBlock(@"
function ${proxyFunctionName} {
    [CmdletBinding(DefaultParameterSetName='FromManagementGroupConnection')]
    [OutputType([Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance])]
    param(
        [Parameter(Position=0, Mandatory=`$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('PropertyValues')]
        [System.Collections.Hashtable]
        `$Property,

        [Parameter(ParameterSetName='FromManagementGroupConnection')]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.Core.Connection.Connection[]]
        `$SCSession,

        [Parameter(Mandatory=`$true, ParameterSetName='FromComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        `$ComputerName,

        [Parameter(ParameterSetName='FromComputerName')]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        `$Credential = [System.Management.Automation.PSCredential]::Empty

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        `$PassThru
    )
    begin {
        try {
            #region Ensure that objects are sent through the pipeline one at a time.

            `$outBuffer = `$null
            if (`$PSCmdlet.MyInvocation.BoundParameters.TryGetValue('OutBuffer', [ref]`$outBuffer)) {
                `$PSCmdlet.MyInvocation.BoundParameters['OutBuffer'] = 1
            }

            #endregion

            #region Add empty credential support, regardless of the function being proxied.

            if (`$PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Credential') -and (`$Credential -eq [System.Management.Automation.PSCredential]::Empty)) {
                `$PSCmdlet.MyInvocation.BoundParameters.Remove('Credential') > `$null
            }

            #endregion

            #region Copy the bound parameters to a PSPassThruParameters parameter hashtable.

            [System.Collections.Hashtable]`$PSPassThruParameters = `$PSCmdlet.MyInvocation.BoundParameters

            #endregion

            #region Add additional required parameters to the PSPassThruParameters hashtable.

            # We must pass through a class object and not the class name because of a bug in
            # the PowerShell 2.0 parameter set recognition logic.
            `$remotingParameters = @{}
            foreach (`$remotingParameterName in @('SCSession','ComputerName','Credential')) {
                if (`$PSPassThruParameters.ContainsKey(`$remotingParameterName)) {
                    `$remotingParameters[`$remotingParameterName] = `$PSPassThruParameters.`$remotingParameterName
                }
            }
            `$PSPassThruParameters['Class'] = Get-SCClass -Name ${ClassName} @remotingParameters

            #endregion

            #region Look up the command being proxied.

            `$wrappedCmd = `$ExecutionContext.InvokeCommand.GetCommand('${functionToProxy}', [System.Management.Automation.CommandTypes]::Function)

            #endregion

            #region If the command was not found, throw an appropriate command not found exception.

            if (-not `$wrappedCmd) {
                [System.String]`$message = `$PSCmdlet.GetResourceString('DiscoveryExceptions','CommandNotFoundException')
                [System.Management.Automation.CommandNotFoundException]`$exception = New-Object -TypeName System.Management.Automation.CommandNotFoundException -ArgumentList (`$message -f '${functionToProxy}')
                `$exception.CommandName = '${functionToProxy}'
                [System.Management.Automation.ErrorRecord]`$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList `$exception,'DiscoveryExceptions',([System.Management.Automation.ErrorCategory]::ObjectNotFound),'${functionToProxy}'
                throw `$errorRecord
            }

            #endregion

            #region Create the proxy command script block.

            `$scriptCmd = {& `$wrappedCmd @PSPassThruParameters}

            #endregion

            #region Use the script block to create the steppable pipeline, then invoke its begin block.

            `$steppablePipeline = `$scriptCmd.GetSteppablePipeline(`$myInvocation.CommandOrigin)
            `$steppablePipeline.Begin(`$PSCmdlet)

            #endregion
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
    process {
        try {
            #region Process the element that was just received from the previous stage in the pipeline.

            `$steppablePipeline.Process(`$_)

            #endregion
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
    end {
        try {
            #region Close the pipeline.

            `$steppablePipeline.End()

            #endregion
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
}

Export-ModuleMember -Function ${proxyFunctionName}
"@)
                break
            }

            'Get-ScsmPxObject' {
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Views')) {
                    $ExecutionContext.InvokeCommand.NewScriptBlock(@"
function ${proxyFunctionName} {
    [CmdletBinding(DefaultParameterSetName='EmoFromManagementGroupConnection')]
    [OutputType([Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance])]
    [OutputType('Microsoft.EnterpriseManagement.ServiceManager.ViewRecord')]
    param(
        [Parameter(ParameterSetName='EmoFromManagementGroupConnection')]
        [Parameter(ParameterSetName='EmoFromComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        `$DisplayName,

        [Parameter(ParameterSetName='EmoFromManagementGroupConnection')]
        [Parameter(ParameterSetName='EmoFromComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        `$Name,

        [Parameter(ParameterSetName='EmoFromManagementGroupConnection')]
        [Parameter(ParameterSetName='EmoFromComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.Guid[]]
        `$Id,
$(if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('ConfigItem') -and $ConfigItem) {
@'

        [Parameter(ParameterSetName='EmoFromManagementGroupConnection')]
        [Parameter(ParameterSetName='EmoFromComputerName')]
        [ValidateSet('Active','Deleted','PendingDelete')]
        [System.String[]]
        $Status = 'Active',


'@
})
        [Parameter(ParameterSetName='EmoFromManagementGroupConnection')]
        [Parameter(ParameterSetName='EmoFromComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        `$Filter,

        [Parameter(Mandatory=`$true,ParameterSetName='ViewFromManagementGroupConnection')]
        [Parameter(Mandatory=`$true,ParameterSetName='ViewFromComputerName')]
        [ValidateNotNull()]
        [ValidateSet('$(@($Views.Keys | Sort-Object) -join ''',''')')]
        [System.String]
        `$View,

        [Parameter(ParameterSetName='EmoFromManagementGroupConnection')]
        [Parameter(ParameterSetName='ViewFromManagementGroupConnection')]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.Core.Connection.Connection[]]
        `$SCSession,

        [Parameter(Mandatory=`$true, ParameterSetName='EmoFromComputerName')]
        [Parameter(Mandatory=`$true, ParameterSetName='ViewFromComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        `$ComputerName,

        [Parameter(ParameterSetName='EmoFromComputerName')]
        [Parameter(ParameterSetName='ViewFromComputerName')]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        `$Credential = [System.Management.Automation.PSCredential]::Empty
    )
    begin {
        try {
            #region Ensure that objects are sent through the pipeline one at a time.

            `$outBuffer = `$null
            if (`$PSCmdlet.MyInvocation.BoundParameters.TryGetValue('OutBuffer', [ref]`$outBuffer)) {
                `$PSCmdlet.MyInvocation.BoundParameters['OutBuffer'] = 1
            }

            #endregion

            #region Add empty credential support, regardless of the function being proxied.

            if (`$PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Credential') -and (`$Credential -eq [System.Management.Automation.PSCredential]::Empty)) {
                `$PSCmdlet.MyInvocation.BoundParameters.Remove('Credential') > `$null
            }

            #endregion

            #region Copy the bound parameters to a PSPassThruParameters parameter hashtable.

            [System.Collections.Hashtable]`$PSPassThruParameters = `$PSCmdlet.MyInvocation.BoundParameters

            #endregion

            switch -regex (`$PSCmdlet.ParameterSetName) {
                '^Emo' {
                    #region Add additional required parameters to the PSPassThruParameters hashtable.

                    # We must pass through a class object and not the class name because of a bug in
                    # the PowerShell 2.0 parameter set recognition logic.
                    `$remotingParameters = @{}
                    foreach (`$remotingParameterName in @('SCSession','ComputerName','Credential')) {
                        if (`$PSPassThruParameters.ContainsKey(`$remotingParameterName)) {
                            `$remotingParameters[`$remotingParameterName] = `$PSPassThruParameters.`$remotingParameterName
                        }
                    }
                    `$PSPassThruParameters['Class'] = Get-SCClass -Name ${ClassName} @remotingParameters

                    #endregion
$(if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('ConfigItem') -and $ConfigItem) {
@'

                    #region Add the status to the filter if we're filtering on status.

                    if ($PSPassThruParameters.ContainsKey('Status')) {
                        $statusValues = @{
                                   Active = 'acdcedb7-100c-8c91-d664-4629a218bd94'
                                  Deleted = 'eec83e3c-0106-d4c0-99ea-93b75fd23020'
                            PendingDelete = '47101e64-237f-12c8-e3f5-ec5a665412fb'
                        }
                        $Status = $Status | Select-Object -Unique
                        if ($Status.Count -lt $statusValues.Count) {
                            foreach ($item in $Status | Select-Object -Unique) {
                                if ($statusValues.Keys -contains $item) {
                                    if ($PSPassThruParameters.ContainsKey('Filter')) {
                                        if ($PSPassThruParameters.Filter -notmatch '^\(.+\)$') {
                                            $PSPassThruParameters.Filter = "($($PSPassThruParameters.Filter))"
                                        }
                                        $PSPassThruParameters.Filter = "(ObjectStatus -eq '$($statusValues.$item)') -and $($PSPassThruParameters.Filter)"
                                    } else {
                                        $PSPassThruParameters.Filter = "ObjectStatus -eq '$($statusValues.$item)'"
                                    }
                                }
                            }
                        }
                        $PSPassThruParameters.Remove('Status') > $null
                    }

                    #endregion


'@
})

                    break
                }

                '^View' {
                    #region Replace the View parameter if we're looking up data using a view.

                    `$viewMap = @{
$(@(foreach ($key in $Views.Keys | Sort-Object) {
    "                        ${key} = '$($Views.$key)'"
}) -join "`r`n")
                    }
                    `$PSPassThruParameters.Remove('View') > `$null
                    `$PSPassThruParameters['ViewName'] = `$viewMap[`$View]

                    #endregion

                    break
                }
            }

            #region Look up the command being proxied.

            switch -regex (`$PSCmdlet.ParameterSetName) {
                '^Emo' {
                    `$functionToProxy = '${functionToProxy}'
                     break
                }
                '^View' {
                    `$functionToProxy = 'Get-ScsmPxViewData'
                     break
                }
            }
            `$wrappedCmd = `$ExecutionContext.InvokeCommand.GetCommand(`$functionToProxy, [System.Management.Automation.CommandTypes]::Function)

            #endregion

            #region If the command was not found, throw an appropriate command not found exception.

            if (-not `$wrappedCmd) {
                [System.String]`$message = `$PSCmdlet.GetResourceString('DiscoveryExceptions','CommandNotFoundException')
                [System.Management.Automation.CommandNotFoundException]`$exception = New-Object -TypeName System.Management.Automation.CommandNotFoundException -ArgumentList (`$message -f `$functionToProxy)
                `$exception.CommandName = `$functionToProxy
                [System.Management.Automation.ErrorRecord]`$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList `$exception,'DiscoveryExceptions',([System.Management.Automation.ErrorCategory]::ObjectNotFound),`$functionToProxy
                throw `$errorRecord
            }

            #endregion

            #region Create the proxy command script block.

            `$scriptCmd = {& `$wrappedCmd @PSPassThruParameters}

            #endregion

            #region Use the script block to create the steppable pipeline, then invoke its begin block.

            `$steppablePipeline = `$scriptCmd.GetSteppablePipeline(`$myInvocation.CommandOrigin)
            `$steppablePipeline.Begin(`$PSCmdlet)

            #endregion
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
    process {
        try {
            #region Process the element that was just received from the previous stage in the pipeline.

            `$steppablePipeline.Process(`$_)

            #endregion
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
    end {
        try {
            #region Close the pipeline.

            `$steppablePipeline.End()

            #endregion
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
}

Export-ModuleMember -Function ${proxyFunctionName}
"@)
                } else {
                    $ExecutionContext.InvokeCommand.NewScriptBlock(@"
function ${proxyFunctionName} {
    [CmdletBinding(DefaultParameterSetName='FromManagementGroupConnection')]
    [OutputType([Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        `$DisplayName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        `$Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Guid[]]
        `$Id,
$(if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('ConfigItem') -and $ConfigItem) {
@'

        [Parameter()]
        [ValidateSet('Active','Deleted','PendingDelete')]
        [System.String[]]
        $Status = 'Active',


'@
})
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        `$Filter,

        [Parameter(ParameterSetName='FromManagementGroupConnection')]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.Core.Connection.Connection[]]
        `$SCSession,

        [Parameter(Mandatory=`$true, ParameterSetName='FromComputerName')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        `$ComputerName,

        [Parameter(ParameterSetName='FromComputerName')]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        `$Credential = [System.Management.Automation.PSCredential]::Empty
    )
    begin {
        try {
            #region Ensure that objects are sent through the pipeline one at a time.

            `$outBuffer = `$null
            if (`$PSCmdlet.MyInvocation.BoundParameters.TryGetValue('OutBuffer', [ref]`$outBuffer)) {
                `$PSCmdlet.MyInvocation.BoundParameters['OutBuffer'] = 1
            }

            #endregion

            #region Add empty credential support, regardless of the function being proxied.

            if (`$PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Credential') -and (`$Credential -eq [System.Management.Automation.PSCredential]::Empty)) {
                `$PSCmdlet.MyInvocation.BoundParameters.Remove('Credential') > `$null
            }

            #endregion

            #region Copy the bound parameters to a PSPassThruParameters parameter hashtable.

            [System.Collections.Hashtable]`$PSPassThruParameters = `$PSCmdlet.MyInvocation.BoundParameters

            #endregion

            #region Add additional required parameters to the PSPassThruParameters hashtable.

            # We must pass through a class object and not the class name because of a bug in
            # the PowerShell 2.0 parameter set recognition logic.
            `$remotingParameters = @{}
            foreach (`$remotingParameterName in @('SCSession','ComputerName','Credential')) {
                if (`$PSPassThruParameters.ContainsKey(`$remotingParameterName)) {
                    `$remotingParameters[`$remotingParameterName] = `$PSPassThruParameters.`$remotingParameterName
                }
            }
            `$PSPassThruParameters['Class'] = Get-SCClass -Name ${ClassName} @remotingParameters

            #endregion
$(if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('ConfigItem') -and $ConfigItem) {
@'

            #region Add the status to the filter if we're filtering on status.

            if ($PSPassThruParameters.ContainsKey('Status')) {
                $statusValues = @{
                           Active = 'acdcedb7-100c-8c91-d664-4629a218bd94'
                          Deleted = 'eec83e3c-0106-d4c0-99ea-93b75fd23020'
                    PendingDelete = '47101e64-237f-12c8-e3f5-ec5a665412fb'
                }
                $Status = $Status | Select-Object -Unique
                if ($Status.Count -lt $statusValues.Count) {
                    foreach ($item in $Status | Select-Object -Unique) {
                        if ($statusValues.Keys -contains $item) {
                            if ($PSPassThruParameters.ContainsKey('Filter')) {
                                if ($PSPassThruParameters.Filter -notmatch '^\(.+\)$') {
                                    $PSPassThruParameters.Filter = "($($PSPassThruParameters.Filter))"
                                }
                                $PSPassThruParameters.Filter = "(ObjectStatus -eq '$($statusValues.$item)') -and $($PSPassThruParameters.Filter)"
                            } else {
                                $PSPassThruParameters.Filter = "ObjectStatus -eq '$($statusValues.$item)'"
                            }
                        }
                    }
                }
                $PSPassThruParameters.Remove('Status') > $null
            }

            #endregion


'@
})
            #region Look up the command being proxied.

            `$wrappedCmd = `$ExecutionContext.InvokeCommand.GetCommand('${functionToProxy}', [System.Management.Automation.CommandTypes]::Function)

            #endregion

            #region If the command was not found, throw an appropriate command not found exception.

            if (-not `$wrappedCmd) {
                [System.String]`$message = `$PSCmdlet.GetResourceString('DiscoveryExceptions','CommandNotFoundException')
                [System.Management.Automation.CommandNotFoundException]`$exception = New-Object -TypeName System.Management.Automation.CommandNotFoundException -ArgumentList (`$message -f '${functionToProxy}')
                `$exception.CommandName = '${functionToProxy}'
                [System.Management.Automation.ErrorRecord]`$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList `$exception,'DiscoveryExceptions',([System.Management.Automation.ErrorCategory]::ObjectNotFound),'${functionToProxy}'
                throw `$errorRecord
            }

            #endregion

            #region Create the proxy command script block.

            `$scriptCmd = {& `$wrappedCmd @PSPassThruParameters}

            #endregion

            #region Use the script block to create the steppable pipeline, then invoke its begin block.

            `$steppablePipeline = `$scriptCmd.GetSteppablePipeline(`$myInvocation.CommandOrigin)
            `$steppablePipeline.Begin(`$PSCmdlet)

            #endregion
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
    process {
        try {
            #region Process the element that was just received from the previous stage in the pipeline.

            `$steppablePipeline.Process(`$_)

            #endregion
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
    end {
        try {
            #region Close the pipeline.

            `$steppablePipeline.End()

            #endregion
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
}

Export-ModuleMember -Function ${proxyFunctionName}
"@)
                }
                break
            }

            'Set-ScsmPxObject' {
                $ExecutionContext.InvokeCommand.NewScriptBlock(@"
function ${proxyFunctionName} {
    <#
    .ForwardHelpTargetName ${functionToProxy}
    .ForwardHelpCategory Function
    #>
    [CmdletBinding(SupportsShouldProcess=`$true)]
    [OutputType([Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance])]
    param(
        [Parameter(Position=0, Mandatory=`$true, ValueFromPipeline=`$true, ValueFromPipelineByPropertyName=`$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (@(`$_.EnterpriseManagementObject.GetClasses() | Select-Object -ExpandProperty Name) -notcontains '${ClassName}') {
                throw "Cannot bind parameter 'InputObject'. Cannot convert ""`$(`$_.DisplayName)"" to type ""${ClassName}"". Error: ""Invalid cast from '`$(`$_.PSTypeNames[0])' to '${ClassName}'""."
            }
            `$true
        })]
        [Alias('EnterpriseManagementInstance')]
        [Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance[]]
        `$InputObject,

        [Parameter(Position=1, Mandatory=`$true, ValueFromPipelineByPropertyName=`$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('PropertyValues')]
        [System.Collections.Hashtable]
        `$Property,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        `$PassThru
    )
    begin {
        try {
            #region Ensure that objects are sent through the pipeline one at a time.

            `$outBuffer = `$null
            if (`$PSCmdlet.MyInvocation.BoundParameters.TryGetValue('OutBuffer', [ref]`$outBuffer)) {
                `$PSCmdlet.MyInvocation.BoundParameters['OutBuffer'] = 1
            }

            #endregion

            #region Add empty credential support, regardless of the function being proxied.

            if (`$PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Credential') -and (`$Credential -eq [System.Management.Automation.PSCredential]::Empty)) {
                `$PSCmdlet.MyInvocation.BoundParameters.Remove('Credential') > `$null
            }

            #endregion

            #region Copy the bound parameters to a PSPassThruParameters parameter hashtable.

            [System.Collections.Hashtable]`$PSPassThruParameters = `$PSCmdlet.MyInvocation.BoundParameters

            #endregion

            #region Look up the command being proxied.

            `$wrappedCmd = `$ExecutionContext.InvokeCommand.GetCommand('${functionToProxy}', [System.Management.Automation.CommandTypes]::Function)

            #endregion

            #region If the command was not found, throw an appropriate command not found exception.

            if (-not `$wrappedCmd) {
                [System.String]`$message = `$PSCmdlet.GetResourceString('DiscoveryExceptions','CommandNotFoundException')
                [System.Management.Automation.CommandNotFoundException]`$exception = New-Object -TypeName System.Management.Automation.CommandNotFoundException -ArgumentList (`$message -f '${functionToProxy}')
                `$exception.CommandName = '${functionToProxy}'
                [System.Management.Automation.ErrorRecord]`$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList `$exception,'DiscoveryExceptions',([System.Management.Automation.ErrorCategory]::ObjectNotFound),'${functionToProxy}'
                throw `$errorRecord
            }

            #endregion

            #region Create the proxy command script block.

            `$scriptCmd = {& `$wrappedCmd @PSPassThruParameters}

            #endregion

            #region Use the script block to create the steppable pipeline, then invoke its begin block.

            `$steppablePipeline = `$scriptCmd.GetSteppablePipeline(`$myInvocation.CommandOrigin)
            `$steppablePipeline.Begin(`$PSCmdlet)

            #endregion
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
    process {
        try {
            foreach (`$item in `$InputObject) {
                #region Process the element that was just received from the previous stage in the pipeline.

                `$steppablePipeline.Process(`$item)

                #endregion
            }
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
    end {
        try {
            #region Close the pipeline.

            `$steppablePipeline.End()

            #endregion
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
}

Export-ModuleMember -Function ${proxyFunctionName}
"@)
                break
            }

            'Rename-ScsmPxObject' {
                $ExecutionContext.InvokeCommand.NewScriptBlock(@"
function ${proxyFunctionName} {
    <#
    .ForwardHelpTargetName ${functionToProxy}
    .ForwardHelpCategory Function
    #>
    [CmdletBinding(SupportsShouldProcess=`$true)]
    [OutputType([Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance])]
    param(
        [Parameter(Position=0, Mandatory=`$true, ValueFromPipeline=`$true, ValueFromPipelineByPropertyName=`$true)]
        [ValidateNotNull()]
        [ValidateScript({
            if (@(`$_.EnterpriseManagementObject.GetClasses() | Select-Object -ExpandProperty Name) -notcontains '${ClassName}') {
                throw "Cannot bind parameter 'InputObject'. Cannot convert ""`$(`$_.DisplayName)"" to type ""${ClassName}"". Error: ""Invalid cast from '`$(`$_.PSTypeNames[0])' to '${ClassName}'""."
            }
            `$true
        })]
        [Alias('EnterpriseManagementInstance')]
        [Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance]
        `$InputObject,

        [Parameter(Position=1, Mandatory=`$true, ValueFromPipelineByPropertyName=`$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        `$NewName,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        `$PassThru
    )
    begin {
        try {
            #region Ensure that objects are sent through the pipeline one at a time.

            `$outBuffer = `$null
            if (`$PSCmdlet.MyInvocation.BoundParameters.TryGetValue('OutBuffer', [ref]`$outBuffer)) {
                `$PSCmdlet.MyInvocation.BoundParameters['OutBuffer'] = 1
            }

            #endregion

            #region Add empty credential support, regardless of the function being proxied.

            if (`$PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Credential') -and (`$Credential -eq [System.Management.Automation.PSCredential]::Empty)) {
                `$PSCmdlet.MyInvocation.BoundParameters.Remove('Credential') > `$null
            }

            #endregion

            #region Copy the bound parameters to a PSPassThruParameters parameter hashtable.

            [System.Collections.Hashtable]`$PSPassThruParameters = `$PSCmdlet.MyInvocation.BoundParameters

            #endregion

            #region Look up the command being proxied.

            `$wrappedCmd = `$ExecutionContext.InvokeCommand.GetCommand('${functionToProxy}', [System.Management.Automation.CommandTypes]::Function)

            #endregion

            #region If the command was not found, throw an appropriate command not found exception.

            if (-not `$wrappedCmd) {
                [System.String]`$message = `$PSCmdlet.GetResourceString('DiscoveryExceptions','CommandNotFoundException')
                [System.Management.Automation.CommandNotFoundException]`$exception = New-Object -TypeName System.Management.Automation.CommandNotFoundException -ArgumentList (`$message -f '${functionToProxy}')
                `$exception.CommandName = '${functionToProxy}'
                [System.Management.Automation.ErrorRecord]`$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList `$exception,'DiscoveryExceptions',([System.Management.Automation.ErrorCategory]::ObjectNotFound),'${functionToProxy}'
                throw `$errorRecord
            }

            #endregion

            #region Create the proxy command script block.

            `$scriptCmd = {& `$wrappedCmd @PSPassThruParameters}

            #endregion

            #region Use the script block to create the steppable pipeline, then invoke its begin block.

            `$steppablePipeline = `$scriptCmd.GetSteppablePipeline(`$myInvocation.CommandOrigin)
            `$steppablePipeline.Begin(`$PSCmdlet)

            #endregion
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
    process {
        try {
            #region Process the element that was just received from the previous stage in the pipeline.

            `$steppablePipeline.Process(`$InputObject)

            #endregion
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
    end {
        try {
            #region Close the pipeline.

            `$steppablePipeline.End()

            #endregion
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
}

Export-ModuleMember -Function ${proxyFunctionName}
"@)
                break
            }

            'Remove-ScsmPxObject' {
                $ExecutionContext.InvokeCommand.NewScriptBlock(@"
function ${proxyFunctionName} {
    <#
    .ForwardHelpTargetName ${functionToProxy}
    .ForwardHelpCategory Function
    #>
    [CmdletBinding(SupportsShouldProcess=`$true)]
    [OutputType([Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance])]
    param(
        [Parameter(Position=0, Mandatory=`$true, ValueFromPipeline=`$true, ValueFromPipelineByPropertyName=`$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (@(`$_.EnterpriseManagementObject.GetClasses() | Select-Object -ExpandProperty Name) -notcontains '${ClassName}') {
                throw "Cannot bind parameter 'InputObject'. Cannot convert ""`$(`$_.DisplayName)"" to type ""${ClassName}"". Error: ""Invalid cast from '`$(`$_.PSTypeNames[0])' to '${ClassName}'""."
            }
            `$true
        })]
        [Alias('EnterpriseManagementInstance')]
        [Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance[]]
        `$InputObject,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        `$Force
    )
    begin {
        try {
            #region Ensure that objects are sent through the pipeline one at a time.

            `$outBuffer = `$null
            if (`$PSCmdlet.MyInvocation.BoundParameters.TryGetValue('OutBuffer', [ref]`$outBuffer)) {
                `$PSCmdlet.MyInvocation.BoundParameters['OutBuffer'] = 1
            }

            #endregion

            #region Add empty credential support, regardless of the function being proxied.

            if (`$PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Credential') -and (`$Credential -eq [System.Management.Automation.PSCredential]::Empty)) {
                `$PSCmdlet.MyInvocation.BoundParameters.Remove('Credential') > `$null
            }

            #endregion

            #region Copy the bound parameters to a PSPassThruParameters parameter hashtable.

            [System.Collections.Hashtable]`$PSPassThruParameters = `$PSCmdlet.MyInvocation.BoundParameters

            #endregion

            #region Look up the command being proxied.

            `$wrappedCmd = `$ExecutionContext.InvokeCommand.GetCommand('${functionToProxy}', [System.Management.Automation.CommandTypes]::Function)

            #endregion

            #region If the command was not found, throw an appropriate command not found exception.

            if (-not `$wrappedCmd) {
                [System.String]`$message = `$PSCmdlet.GetResourceString('DiscoveryExceptions','CommandNotFoundException')
                [System.Management.Automation.CommandNotFoundException]`$exception = New-Object -TypeName System.Management.Automation.CommandNotFoundException -ArgumentList (`$message -f '${functionToProxy}')
                `$exception.CommandName = '${functionToProxy}'
                [System.Management.Automation.ErrorRecord]`$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList `$exception,'DiscoveryExceptions',([System.Management.Automation.ErrorCategory]::ObjectNotFound),'${functionToProxy}'
                throw `$errorRecord
            }

            #endregion

            #region Create the proxy command script block.

            `$scriptCmd = {& `$wrappedCmd @PSPassThruParameters}

            #endregion

            #region Use the script block to create the steppable pipeline, then invoke its begin block.

            `$steppablePipeline = `$scriptCmd.GetSteppablePipeline(`$myInvocation.CommandOrigin)
            `$steppablePipeline.Begin(`$PSCmdlet)

            #endregion
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
    process {
        try {
            foreach (`$item in `$InputObject) {
                #region Process the element that was just received from the previous stage in the pipeline.

                `$steppablePipeline.Process(`$item)

                #endregion
            }
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
    end {
        try {
            #region Close the pipeline.

            `$steppablePipeline.End()

            #endregion
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
}

Export-ModuleMember -Function ${proxyFunctionName}
"@)
                break
            }

            'Restore-ScsmPxObject' {
                $ExecutionContext.InvokeCommand.NewScriptBlock(@"
function ${proxyFunctionName} {
    <#
    .ForwardHelpTargetName ${functionToProxy}
    .ForwardHelpCategory Function
    #>
    [CmdletBinding(SupportsShouldProcess=`$true)]
    [OutputType([Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance])]
    param(
        [Parameter(Position=0, Mandatory=`$true, ValueFromPipeline=`$true, ValueFromPipelineByPropertyName=`$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (@(`$_.EnterpriseManagementObject.GetClasses() | Select-Object -ExpandProperty Name) -notcontains '${ClassName}') {
                throw "Cannot bind parameter 'InputObject'. Cannot convert ""`$(`$_.DisplayName)"" to type ""${ClassName}"". Error: ""Invalid cast from '`$(`$_.PSTypeNames[0])' to '${ClassName}'""."
            }
            `$true
        })]
        [Alias('EnterpriseManagementInstance')]
        [Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance[]]
        `$InputObject,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        `$PassThru
    )
    begin {
        try {
            #region Ensure that objects are sent through the pipeline one at a time.

            `$outBuffer = `$null
            if (`$PSCmdlet.MyInvocation.BoundParameters.TryGetValue('OutBuffer', [ref]`$outBuffer)) {
                `$PSCmdlet.MyInvocation.BoundParameters['OutBuffer'] = 1
            }

            #endregion

            #region Add empty credential support, regardless of the function being proxied.

            if (`$PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Credential') -and (`$Credential -eq [System.Management.Automation.PSCredential]::Empty)) {
                `$PSCmdlet.MyInvocation.BoundParameters.Remove('Credential') > `$null
            }

            #endregion

            #region Copy the bound parameters to a PSPassThruParameters parameter hashtable.

            [System.Collections.Hashtable]`$PSPassThruParameters = `$PSCmdlet.MyInvocation.BoundParameters

            #endregion

            #region Look up the command being proxied.

            `$wrappedCmd = `$ExecutionContext.InvokeCommand.GetCommand('${functionToProxy}', [System.Management.Automation.CommandTypes]::Function)

            #endregion

            #region If the command was not found, throw an appropriate command not found exception.

            if (-not `$wrappedCmd) {
                [System.String]`$message = `$PSCmdlet.GetResourceString('DiscoveryExceptions','CommandNotFoundException')
                [System.Management.Automation.CommandNotFoundException]`$exception = New-Object -TypeName System.Management.Automation.CommandNotFoundException -ArgumentList (`$message -f '${functionToProxy}')
                `$exception.CommandName = '${functionToProxy}'
                [System.Management.Automation.ErrorRecord]`$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList `$exception,'DiscoveryExceptions',([System.Management.Automation.ErrorCategory]::ObjectNotFound),'${functionToProxy}'
                throw `$errorRecord
            }

            #endregion

            #region Create the proxy command script block.

            `$scriptCmd = {& `$wrappedCmd @PSPassThruParameters}

            #endregion

            #region Use the script block to create the steppable pipeline, then invoke its begin block.

            `$steppablePipeline = `$scriptCmd.GetSteppablePipeline(`$myInvocation.CommandOrigin)
            `$steppablePipeline.Begin(`$PSCmdlet)

            #endregion
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
    process {
        try {
            foreach (`$item in `$InputObject) {
                #region Process the element that was just received from the previous stage in the pipeline.

                `$steppablePipeline.Process(`$item)

                #endregion
            }
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
    end {
        try {
            #region Close the pipeline.

            `$steppablePipeline.End()

            #endregion
        } catch {
            `$PSCmdlet.ThrowTerminatingError(`$_)
        }
    }
}

Export-ModuleMember -Function ${proxyFunctionName}
"@)
                break
            }

            default {
                [System.String]$message = "There is no support for proxying ${_} at this time."
                [System.Management.Automation.PSNotSupportedException]$exception = New-Object -TypeName System.Management.Automation.PSNotSupportedException -ArgumentList $message
                [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'NotSupportedException',([System.Management.Automation.ErrorCategory]::InvalidOperation),$_
                throw $errorRecord
            }
        }
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Export-ModuleMember -Function New-ScsmPxProxyFunctionDefinition