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
function Add-ScsmPxTroubleTicketComment {
    [CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName='AddUserComment')]
    [OutputType([Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance])]
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            $classHierarchy = @($_.EnterpriseManagementObject.GetClasses())
            $classHierarchy += $classHierarchy[0].GetBaseTypes()
            $classNameHierarchy = $classHierarchy | Select-Object -ExpandProperty Name
            if ($classNameHierarchy -notcontains 'System.WorkItem.TroubleTicket') {
                throw "Cannot bind parameter 'InputObject'. ""$($_.DisplayName)"" is not of type ""System.WorkItem.TroubleTicket"". Error: ""Invalid type provided in InputObject parameter""."
            }
            $true
        })]
        [Alias('EnterpriseManagementInstance')]
        [Microsoft.EnterpriseManagement.Core.Cmdlets.Instances.EnterpriseManagementInstance[]]
        $InputObject,

        [Parameter(Position=1, Mandatory=$true, ParameterSetName='AddUserComment')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $UserComment,

        [Parameter(Position=1, Mandatory=$true, ParameterSetName='AddAnalystComment')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $AnalystComment,

        [Parameter(Position=1, Mandatory=$true, ParameterSetName='AddAuditComment')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $AuditComment,

        [Parameter(ParameterSetName='AddAnalystComment')]
        [System.Management.Automation.SwitchParameter]
        $Private,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $PassThru
    )
    begin {
        try {
            #region Define an entity cache to store relationships, classes and instances that should only be looked up once.

            $entityCache = @{}

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    process {
        try {
            foreach ($item in $InputObject) {
                #region Get the Enterprise Management Group (EMG) for the trouble ticket.

                $emg = $item.EnterpriseManagementObject.ManagementGroup

                #endregion

                #region If we have not created a cache entry for this EMG yet, create one.

                if ($entityCache.Keys -notcontains $emg.Id) {
                    $entityCache[$emg.Id] = @{}
                }

                #endregion

                #region Identify the comment value and the associated class and relationship properties that are required.

                switch ($PSCmdlet.ParameterSetName) {
                    'AddUserComment' {
                        $comment = $UserComment
                        $commentClassName = 'System.WorkItem.TroubleTicket.UserCommentLog'
                        $commentClassId = 'a3d4e16f-5e8a-18ba-9198-d9815194c986'
                        $commentRelationshipName = 'System.WorkItem.TroubleTicketHasUserComment'
                        $commentRelationshipId = 'ce423786-16dd-da9c-fb7b-21ab5189e12b'
                        break
                    }
                    'AddAnalystComment' {
                        $comment = $AnalystComment
                        $commentClassName = 'System.WorkItem.TroubleTicket.AnalystCommentLog'
                        $commentClassId = 'f14b70f4-878c-c0e1-b5c1-06ca22d05d40'
                        $commentRelationshipName = 'System.WorkItem.TroubleTicketHasAnalystComment'
                        $commentRelationshipId = '835a64cd-7d41-10eb-e5e4-365ea2efc2ea'
                        break
                    }
                    'AddAuditComment' {
                        $comment = $AuditComment
                        $commentClassName = 'System.WorkItem.TroubleTicket.AuditCommentLog'
                        $commentClassId = 'c06a4eb0-d21e-1838-0995-ee817b3aac4a'
                        $commentRelationshipName = 'System.WorkItem.TroubleTicketHasAuditComment'
                        $commentRelationshipId = '5ad35f7b-8ef4-6c4f-ec6d-7a49b0d8f7d7'
                        break
                    }
                }

                #endregion

                #region If the class or relationship are not cached yet, add them to the cache.

                if ($entityCache[$emg.Id] -notcontains $commentClassName) {
                    $entityCache[$emg.Id][$commentClassName] = $emg.EntityTypes.GetClass($commentClassId)
                }
                if ($entityCache[$emg.Id] -notcontains $commentRelationshipName) {
                    $entityCache[$emg.Id][$commentRelationshipName] = $emg.EntityTypes.GetRelationshipClass($commentRelationshipId)
                }

                #endregion

                #region Create a new comment (but don't commit it yet!).

                $commentClass = $entityCache[$emg.Id][$commentClassName]
                $commentEmo = New-Object -TypeName Microsoft.EnterpriseManagement.Common.CreatableEnterpriseManagementObject -ArgumentList $emg,$commentClass
                $commentEmo[$commentClass, 'Id'].Value = [System.Guid]::NewGuid().ToString()
                $commentEmo[$null, 'Comment'].Value = $comment
                $commentEmo[$null, 'EnteredBy'].Value = $emg.GetUserName()
                $commentEmo[$null, 'EnteredDate'].Value = [System.DateTime]::UtcNow
                if ($PSCmdlet.ParameterSetName -eq 'AddAnalystComment') {
                    # Analyst comments can be public or private, so we need to set an additional property on them
                    $commentEmo[$null, 'IsPrivate'].Value = $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Private') -and $Private
                }

                #endregion

                #region Create the relationship between the trouble ticket and the comment.

                $commentRelationship = $entityCache[$emg.Id][$commentRelationshipName]
                $commentRelationshipEmro = New-Object -TypeName Microsoft.EnterpriseManagement.Common.CreatableEnterpriseManagementRelationshipObject -ArgumentList $emg,$commentRelationship
                $commentRelationshipEmro.SetSource($item)
                $commentRelationshipEmro.SetTarget($commentEmo)
                $commentRelationshipEmro.Commit()

                #endregion

                #region Now commit the comment.

                # This is committed at the very end because it is part of a membership
                # relationship (meaning that the object itself cannot exist without it
                # being a member of something). If you were to commit this first and then
                # try to create the relationship, the assignment of the target would fail
                # because the object must be part of a relationship at the time that it
                # is committed to the CMDB.

                $commentEmo.Commit()

                #endregion

                #region If the caller requested it, return the trouble ticket to them.

                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('PassThru') -and $PassThru) {
                    $item
                }

                #endregion
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

Export-ModuleMember -Function Add-ScsmPxTroubleTicketComment