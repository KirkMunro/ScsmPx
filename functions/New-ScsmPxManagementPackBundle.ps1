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
function New-ScsmPxManagementPackBundle {
    [CmdletBinding(DefaultParameterSetName='Default')]
    [OutputType([System.IO.File])]
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [Parameter(Position=1, Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (-not (Test-Path -LiteralPath $_)) {
                throw "File not found ('$_'). Please verify that the file exists and then try again."
            }
            $true
        })]
        [Alias('PSPath')]
        [System.String[]]
        $InputObject,

        [Parameter(ParameterSetName='Default')]
        [Parameter(Mandatory=$true, ParameterSetName='AsUser')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $ComputerName,

        [Parameter(Mandatory=$true, ParameterSetName='AsUser')]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )
    begin {
        try {
            #region Prepare for splatting of remoting parameters if required.

            $remotingParameters = @{}
            foreach ($remotingParameterName in 'ComputerName','Credential') {
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey($remotingParameterName)) {
                    $remotingParameters[$remotingParameterName] = $PSCmdlet.MyInvocation.BoundParameters.$remotingParameterName
                }
            }

            #endregion

            #region Look up the SCSM installation directory.

            $installDirectory = Get-ScsmPxInstallDirectory @remotingParameters

            #endregion

            #region Load the Microsoft.EnterpriseManagement.Packaging.dll assembly.

            $sdkBinariesDirectory = Join-Path -Path $installDirectory -ChildPath 'SDK Binaries'
            $packagingDll = Join-Path -Path $sdkBinariesDirectory -ChildPath Microsoft.EnterpriseManagement.Packaging.dll
            Add-Type -LiteralPath $packagingDll -ErrorAction Stop

            #endregion

            #region Define an array to store all MP files that will be included in the bundle.

            $mpFiles = @()

            #endregion
        } catch {
            throw
        }
    }
    process {
        try {
            #region Add any input files into our collection of MPs that will be bundled together.

            $mpFiles += $InputObject

            #endregion
        } catch {
            throw
        }
    }
    end {
        try {
            #region Define an array to hold whatever files we open while creating the bundle.

            $openFileStreams = @()

            #endregion

            #region Look up the Enterprise Management Group.

            $emg = Get-ScsmPxEnterpriseManagementGroup @remotingParameters

            #endregion

            #region Create a new Management Pack Bundle.

            $bundle = [Microsoft.EnterpriseManagement.Packaging.ManagementPackBundleFactory]::CreateBundle()

            #endregion

            #region Add all resources and the Management Pack(s) containing them to our bundle.

            foreach ($mpFile in $mpFiles) {
                try {
                    #region Set our current location to the location of the MP file.

                    Split-Path -Path $mpFile -Parent | Set-Location

                    #endregion
                    
                    #region Create the MP object in memory.

                    $mp = New-Object -TypeName Microsoft.EnterpriseManagement.Configuration.ManagementPack -ArgumentList $mpFile,$emg

                    #endregion
                    
                    #region Get the resources in that MP.

                    $resources = @()
                    $resourcesMethod = [Microsoft.EnterpriseManagement.Configuration.ManagementPack].GetMethod('GetResources')
                    $resourcesGenericMethod = $resourcesMethod.MakeGenericMethod([Microsoft.EnterpriseManagement.Configuration.ManagementPackResource])
                    foreach ($resource in $resourcesGenericMethod.Invoke($mp,$null)) {
                        #region Get the full path to the resource.

                        $resourcePath = Resolve-Path -LiteralPath $resource.FileName -ErrorAction Stop | Select-Object -ExpandProperty Path

                        #endregion

                        #region Create a custom resource object for the resource.

                        $resources += [pscustomobject]@{
                              PSTypeName = 'ManagementPackResource'
                                    Name = $resource.Name
                                    File = Get-Item -LiteralPath $resourcePath -ErrorAction Stop
                        }

                        #endregion
                    }

                    #endregion

                    #region Now add the management pack and the resourcs to the bundle.

                    $bundle.AddManagementPack($mp)
                    foreach ($resource in $resources) {
                        #region Open a stream to read the contents of the resource file.
                            
                        $openFileStreams += $stream = New-Object -TypeName System.IO.FileStream -ArgumentList $resource.File.FullName,([System.IO.FileMode]::Open),([System.IO.FileAccess]::Read)

                        #endregion

                        #region Now add the stream to the bundle.
                            
                        $bundle.AddResourceStream($mp,$resource.Name,$stream,[Microsoft.EnterpriseManagement.Packaging.ManagementPackBundleStreamSignature]::Empty)

                        #endregion
                    }

                    #endregion

                } finally {
                    #region Return our location to the previous location.

                    Pop-Location

                    #endregion
                }
            }

            #endregion

            #region Write the bundle to disk in the location that was provided.

            $bundleDirectory = Split-Path -Path $Path -Parent
            if (-not $bundleDirectory) {
                $bundleDirectory = $PWD
            }
            $bundleDirectory = Resolve-Path -LiteralPath $bundleDirectory | Select-Object -ExpandProperty Path
            $bundleName = Split-Path -Path $Path -Leaf
            if ($bundleName -match '\.mpb$') {
                $bundleName = $bundleName -replace '\.mpb$'
            }
            $bundleWriter = [Microsoft.EnterpriseManagement.Packaging.ManagementPackBundleFactory]::CreateBundleWriter($bundleDirectory)
            $bundlePath = $bundleWriter.Write($bundle,$bundleName)

            #endregion

            #region Return the bundle file that was created.

            Get-Item -LiteralPath $bundlePath

            #endregion
        } catch {
            throw
        } finally {
            #region Close the streams to the resource files we opened and dispose of them.

            foreach ($stream in $openFileStreams) {
                $stream.Close()
                $stream.Dispose()
            }

            #endregion
        }
    } 
} 

Export-ModuleMember -Function New-ScsmPxManagementPackBundle