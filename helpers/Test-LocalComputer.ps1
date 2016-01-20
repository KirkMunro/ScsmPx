<#####################################################################
These files contain scripts used to assist in troubleshooting support
issues related to the Provance 2012 IT Asset Management Pack and the
Provance 2012 Data Management Pack. Do not edit or change the contents
of these files directly.

Copyright (c) 2016 Provance Technologies. All rights reserved.
Proprietary and Confidential.

THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY
KIND, WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR
PURPOSE. IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF
USE OR RESULTS IN CONNECTION WITH THE USE OF THIS CODE AND INFORMATION
REMAINS WITH THE USER.
######################################################################>

function Test-LocalComputer {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $ComputerName
    )
    try {
        #region Look up the host entry in DNS.

        $hostEntry = [System.Net.Dns]::GetHostEntry('')

        #endregion

        #region Create a list of local computer identifiers from well-known identifiers and the host entry details.

        $resultIdentifiers = @(
            'localhost'
            '192.168.0.1'
            '127.0.0.1'
            '::1'
            $env:COMPUTERNAME
            $hostEntry.HostName
        ) + $hostEntry.AddressList.IPAddressToString

        #endregion

        #region Return true if all of the computer names are in the list of local computer identifiers; false otherwise.

        $result = $true
        foreach ($item in $ComputerName) {
            if ($resultIdentifiers -notcontains $item) {
                $result = $false
                break
            }
        }
        $result

        #endregion
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}