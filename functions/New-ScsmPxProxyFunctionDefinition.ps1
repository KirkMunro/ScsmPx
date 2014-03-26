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
        [Parameter()]
        [ValidateNotNullOrEmpty()]
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
                `$PSCmdlet.ThrowTerminatingError(`$errorRecord)
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
            throw
        }
    }
    process {
        try {
            #region Process the element that was just received from the previous stage in the pipeline.

            `$steppablePipeline.Process(`$_)

            #endregion
        } catch {
            throw
        }
    }
    end {
        try {
            #region Close the pipeline.

            `$steppablePipeline.End()

            #endregion
        } catch {
            throw
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
                                        $PSPassThruParameters.Filter = "(ObjectStatus -eq '$($statusValues.$item)) -and $($PSPassThruParameters.Filter)"
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
                `$PSCmdlet.ThrowTerminatingError(`$errorRecord)
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
            throw
        }
    }
    process {
        try {
            #region Process the element that was just received from the previous stage in the pipeline.

            `$steppablePipeline.Process(`$_)

            #endregion
        } catch {
            throw
        }
    }
    end {
        try {
            #region Close the pipeline.

            `$steppablePipeline.End()

            #endregion
        } catch {
            throw
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
                                $PSPassThruParameters.Filter = "(ObjectStatus -eq '$($statusValues.$item)) -and $($PSPassThruParameters.Filter)"
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
                `$PSCmdlet.ThrowTerminatingError(`$errorRecord)
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
            throw
        }
    }
    process {
        try {
            #region Process the element that was just received from the previous stage in the pipeline.

            `$steppablePipeline.Process(`$_)

            #endregion
        } catch {
            throw
        }
    }
    end {
        try {
            #region Close the pipeline.

            `$steppablePipeline.End()

            #endregion
        } catch {
            throw
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
            if (`$_.PSTypeNames -notcontains '${ClassName}') {
                throw "Cannot bind parameter 'InputObject'. Cannot convert ""`$(`$_.DisplayName)"" to type ""${ClassName}"". Error: ""Invalid cast from '`$(`$_.PSTypeNames[0])' to '${ClassName}'""."
            }
            `$true
        })]
        [Alias('EnterpriseManagementInstance')]
        [Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance[]]
        `$InputObject,

        [Parameter(Position=1, Mandatory=`$true, ValueFromPipelineByPropertyName=`$true)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable]
        `$PropertyValues,

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
                `$PSCmdlet.ThrowTerminatingError(`$errorRecord)
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
            throw
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
            throw
        }
    }
    end {
        try {
            #region Close the pipeline.

            `$steppablePipeline.End()

            #endregion
        } catch {
            throw
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
            if (`$_.PSTypeNames -notcontains '${ClassName}') {
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
                `$PSCmdlet.ThrowTerminatingError(`$errorRecord)
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
            throw
        }
    }
    process {
        try {
            #region Process the element that was just received from the previous stage in the pipeline.

            `$steppablePipeline.Process(`$InputObject)

            #endregion
        } catch {
            throw
        }
    }
    end {
        try {
            #region Close the pipeline.

            `$steppablePipeline.End()

            #endregion
        } catch {
            throw
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
            if (`$_.PSTypeNames -notcontains '${ClassName}') {
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
                `$PSCmdlet.ThrowTerminatingError(`$errorRecord)
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
            throw
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
            throw
        }
    }
    end {
        try {
            #region Close the pipeline.

            `$steppablePipeline.End()

            #endregion
        } catch {
            throw
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
            if (`$_.PSTypeNames -notcontains '${ClassName}') {
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
                `$PSCmdlet.ThrowTerminatingError(`$errorRecord)
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
            throw
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
            throw
        }
    }
    end {
        try {
            #region Close the pipeline.

            `$steppablePipeline.End()

            #endregion
        } catch {
            throw
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
                [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'NotSupportedException',([System.Management.Automation.ErrorCategory]::InvalidOperation),'New-ScsmPxProxyFunctionDefinition'
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }
        }
    } catch {
        throw
    }
}

Export-ModuleMember -Function New-ScsmPxProxyFunctionDefinition
# SIG # Begin signature block
# MIIZKQYJKoZIhvcNAQcCoIIZGjCCGRYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUMkWFjRvIHmzDMH/SpASLjEjV
# WvmgghQZMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggVuMIIEVqADAgECAhAKU6nZKT4ZKigLdw2V0ZC8MA0GCSqGSIb3DQEBBQUAMIG0
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsT
# FlZlcmlTaWduIFRydXN0IE5ldHdvcmsxOzA5BgNVBAsTMlRlcm1zIG9mIHVzZSBh
# dCBodHRwczovL3d3dy52ZXJpc2lnbi5jb20vcnBhIChjKTEwMS4wLAYDVQQDEyVW
# ZXJpU2lnbiBDbGFzcyAzIENvZGUgU2lnbmluZyAyMDEwIENBMB4XDTEzMDQwODAw
# MDAwMFoXDTE0MDUwODIzNTk1OVowgbExCzAJBgNVBAYTAkNBMQ8wDQYDVQQIEwZR
# dWViZWMxETAPBgNVBAcTCEdhdGluZWF1MR4wHAYDVQQKFBVQcm92YW5jZSBUZWNo
# bm9sb2dpZXMxPjA8BgNVBAsTNURpZ2l0YWwgSUQgQ2xhc3MgMyAtIE1pY3Jvc29m
# dCBTb2Z0d2FyZSBWYWxpZGF0aW9uIHYyMR4wHAYDVQQDFBVQcm92YW5jZSBUZWNo
# bm9sb2dpZXMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC04Yt50uP8
# newqG0tbz7MJHGQwrG6lf4LrqnnYvK+jHJY+mkXjOR1VQouSeteYmWzsqSiNFagM
# SFxAzO3CRZt1xP0FPQgXjsyJWcEUOokgPl+a5vFrFhmhphe7QztiO5kOR3rBr7cW
# DQhgv7yWStLg4ymNSrJbbNO0kczsl2FV/5pZ1pEdKzEDOO1X5Xx9Oaz3lb3ldrPk
# zn+Lwr36YTkU+jTPHoXPyHy4lBYK/qcNbuPTTE1BeH+rwENx9nkEUa6dPPcDKDPf
# EULo/g7P25ILApWoGJmdcefseebsu6CjtO5xYKTvk0ylWxXXoqnJvFw2z5Y8tUjA
# W0E43nmf73ApAgMBAAGjggF7MIIBdzAJBgNVHRMEAjAAMA4GA1UdDwEB/wQEAwIH
# gDBABgNVHR8EOTA3MDWgM6Axhi9odHRwOi8vY3NjMy0yMDEwLWNybC52ZXJpc2ln
# bi5jb20vQ1NDMy0yMDEwLmNybDBEBgNVHSAEPTA7MDkGC2CGSAGG+EUBBxcDMCow
# KAYIKwYBBQUHAgEWHGh0dHBzOi8vd3d3LnZlcmlzaWduLmNvbS9ycGEwEwYDVR0l
# BAwwCgYIKwYBBQUHAwMwcQYIKwYBBQUHAQEEZTBjMCQGCCsGAQUFBzABhhhodHRw
# Oi8vb2NzcC52ZXJpc2lnbi5jb20wOwYIKwYBBQUHMAKGL2h0dHA6Ly9jc2MzLTIw
# MTAtYWlhLnZlcmlzaWduLmNvbS9DU0MzLTIwMTAuY2VyMB8GA1UdIwQYMBaAFM+Z
# qep7JvRLyY6P1/AFJu/j0qedMBEGCWCGSAGG+EIBAQQEAwIEEDAWBgorBgEEAYI3
# AgEbBAgwBgEBAAEB/zANBgkqhkiG9w0BAQUFAAOCAQEASuMSDX2Mfs+c92nmVE9Q
# hhbHGRXgn7X3oWPQ4LVBgBvAjrqvBh/cxZuPjr8jRZPEyg6h1csvP2DZAjVi1oyO
# SDNSyWuGb+IW6IoCFz73h1GlLJyz816rOoD2YhBRCXJ+eCZZeoRxdG7jn1w/zq74
# FJWW1LDqnT6kXouZpPKEQXult0Cfeg3i/q0DKMbfq9qC66G1DqsDz/edORRirZ+a
# fhW+o0khAuNNDZN7Xm9pc0fr0itMrshfzUOoVChvU1xPCUryqtpz2URJWlcckVtC
# f4Vffsc/9W+FMfRuww6ahatjLWeT1fNerhWaY6YbD8OAbgj6DG+kmvorZYDX6boS
# kjCCBgowggTyoAMCAQICEFIA5aolVvwahu2WydRLM8cwDQYJKoZIhvcNAQEFBQAw
# gcoxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5WZXJpU2lnbiwgSW5jLjEfMB0GA1UE
# CxMWVmVyaVNpZ24gVHJ1c3QgTmV0d29yazE6MDgGA1UECxMxKGMpIDIwMDYgVmVy
# aVNpZ24sIEluYy4gLSBGb3IgYXV0aG9yaXplZCB1c2Ugb25seTFFMEMGA1UEAxM8
# VmVyaVNpZ24gQ2xhc3MgMyBQdWJsaWMgUHJpbWFyeSBDZXJ0aWZpY2F0aW9uIEF1
# dGhvcml0eSAtIEc1MB4XDTEwMDIwODAwMDAwMFoXDTIwMDIwNzIzNTk1OVowgbQx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5WZXJpU2lnbiwgSW5jLjEfMB0GA1UECxMW
# VmVyaVNpZ24gVHJ1c3QgTmV0d29yazE7MDkGA1UECxMyVGVybXMgb2YgdXNlIGF0
# IGh0dHBzOi8vd3d3LnZlcmlzaWduLmNvbS9ycGEgKGMpMTAxLjAsBgNVBAMTJVZl
# cmlTaWduIENsYXNzIDMgQ29kZSBTaWduaW5nIDIwMTAgQ0EwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQD1I0tepdeKuzLp1Ff37+THJn6tGZj+qJ19lPY2
# axDXdYEwfwRof8srdR7NHQiM32mUpzejnHuA4Jnh7jdNX847FO6G1ND1JzW8JQs4
# p4xjnRejCKWrsPvNamKCTNUh2hvZ8eOEO4oqT4VbkAFPyad2EH8nA3y+rn59wd35
# BbwbSJxp58CkPDxBAD7fluXF5JRx1lUBxwAmSkA8taEmqQynbYCOkCV7z78/HOsv
# lvrlh3fGtVayejtUMFMb32I0/x7R9FqTKIXlTBdOflv9pJOZf9/N76R17+8V9kfn
# +Bly2C40Gqa0p0x+vbtPDD1X8TDWpjaO1oB21xkupc1+NC2JAgMBAAGjggH+MIIB
# +jASBgNVHRMBAf8ECDAGAQH/AgEAMHAGA1UdIARpMGcwZQYLYIZIAYb4RQEHFwMw
# VjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cudmVyaXNpZ24uY29tL2NwczAqBggr
# BgEFBQcCAjAeGhxodHRwczovL3d3dy52ZXJpc2lnbi5jb20vcnBhMA4GA1UdDwEB
# /wQEAwIBBjBtBggrBgEFBQcBDARhMF+hXaBbMFkwVzBVFglpbWFnZS9naWYwITAf
# MAcGBSsOAwIaBBSP5dMahqyNjmvDz4Bq1EgYLHsZLjAlFiNodHRwOi8vbG9nby52
# ZXJpc2lnbi5jb20vdnNsb2dvLmdpZjA0BgNVHR8ELTArMCmgJ6AlhiNodHRwOi8v
# Y3JsLnZlcmlzaWduLmNvbS9wY2EzLWc1LmNybDA0BggrBgEFBQcBAQQoMCYwJAYI
# KwYBBQUHMAGGGGh0dHA6Ly9vY3NwLnZlcmlzaWduLmNvbTAdBgNVHSUEFjAUBggr
# BgEFBQcDAgYIKwYBBQUHAwMwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFZlcmlT
# aWduTVBLSS0yLTgwHQYDVR0OBBYEFM+Zqep7JvRLyY6P1/AFJu/j0qedMB8GA1Ud
# IwQYMBaAFH/TZafC3ey78DAJ80M5+gKvMzEzMA0GCSqGSIb3DQEBBQUAA4IBAQBW
# IuY0pMRhy0i5Aa1WqGQP2YyRxLvMDOWteqAif99HOEotbNF/cRp87HCpsfBP5A8M
# U/oVXv50mEkkhYEmHJEUR7BMY4y7oTTUxkXoDYUmcwPQqYxkbdxxkuZFBWAVWVE5
# /FgUa/7UpO15awgMQXLnNyIGCb4j6T9Emh7pYZ3MsZBc/D3SjaxCPWU21LQ9QCiP
# mxDPIybMSyDLkB9djEw0yjzY5TfWb6UgvTTrJtmuDefFmvehtCGRM2+G6Fi7JXx0
# Dlj+dRtjP84xfJuPG5aexVN2hFucrZH6rO2Tul3IIVPCglNjrxINUIcRGz1UUpaK
# LJw9khoImgUux5OlSJHTMYIEejCCBHYCAQEwgckwgbQxCzAJBgNVBAYTAlVTMRcw
# FQYDVQQKEw5WZXJpU2lnbiwgSW5jLjEfMB0GA1UECxMWVmVyaVNpZ24gVHJ1c3Qg
# TmV0d29yazE7MDkGA1UECxMyVGVybXMgb2YgdXNlIGF0IGh0dHBzOi8vd3d3LnZl
# cmlzaWduLmNvbS9ycGEgKGMpMTAxLjAsBgNVBAMTJVZlcmlTaWduIENsYXNzIDMg
# Q29kZSBTaWduaW5nIDIwMTAgQ0ECEApTqdkpPhkqKAt3DZXRkLwwCQYFKw4DAhoF
# AKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisG
# AQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcN
# AQkEMRYEFGK6wHc5bd4DABPd9XGtuaeK5ZnkMA0GCSqGSIb3DQEBAQUABIIBAEO7
# XRgwb0Oa84wTkIF2paK6wKGu4M5NV9sW9i7aQUEqPl0DcX9iRI2X+/avH8WHEygp
# 2sKwX0Snkq1bT07yYugAYMcslIKOfAvSaNIWG1t00y8H3iH40aszxIl5GZSC8SGD
# Rohmaa1eoPKGhCvd/JFSBv9Gm943ExR44bSRdbANN9TpTqCPg7gBIT0NuRagIks/
# 0++WVAl90OppORBEBlMPUqfp1AsgDN07BaESHmLMG4HwvzDpvMvt7dB9U3FnY829
# zAyhZzgdQJ7Z0tIdHbWfBK1tPCIxedHsildPoUuQyjbunTwdHL77PnMZ7ZBH0v1c
# u4ZFHA5KrXBvZUdEn3uhggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBe
# MQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAu
# BgNVBAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQ
# Ds/0OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqG
# SIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTQwMzI2MjEzMzM3WjAjBgkqhkiG9w0B
# CQQxFgQUcAL+KLEtAMk3QMug5/lBdUMBZrkwDQYJKoZIhvcNAQEBBQAEggEAV0Me
# qpZ+qBo8HreAs78TgTIPRkIbRWOIGMPi6hafbzw7fz+cEBCHI6my8WbtrxzAgWgP
# F71I6obBKjWkBc18eAcHoX6K0q9vLe9iLpfhDLIXfTXHxEdz/6GWoUFnxcDFwJ0V
# wVuVtMg4RcI9hls5cgkuRQgbC8DQzdEg9iXmlcWcBykj5uHtNcSRoRJqsNcQBqY2
# lszH18ZruAFKGtc2iwobEqy1xhCapP6pnckKTSICVYvJalF1EyVrOIzPfEi2ARem
# Jl05KMIcg8r9CGk8cVlUHBimKMDeXILMMkOeCurn39jVXeH1vrTvcSZcLCBs5cQd
# 0H/NJxSEv4EGqTutcQ==
# SIG # End signature block
