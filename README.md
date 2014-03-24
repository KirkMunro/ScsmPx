## System Center Service Manager PowerShell Extensions

### Overview

The ScsmPx module facilitates automation with Microsoft System Center Service
Manager by auto-loading the native modules that are included as part of that
product and enabling automatic discovery of the commands that are contained
within the native modules. It also includes dozens of complementary commands
that are not available out of the box to allow you to do much more with your
PowerShell automation efforts using the platform.

Copyright (c) 2014 Provance Technologies.

### License

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

### ScsmPx, the native SCSM cmdlets, and SMLets

The ScsmPx module was designed to address some of the challenges presented
by other Microsoft Windows PowerShell modules that were intended to
facilitate automation tasks with Microsoft System Center Service Manager.

Starting with the 2012 release, Microsoft System Center Service Manager has
included two Microsoft Windows PowerShell modules in its installation
package. These modules are installed automatically on every management
server and every management console. There are 116 cmdlets included in these
two modules to provide automation support to Microsoft System Center Service
Manager 2012 and later. Unfortunately, these modules are not installed
according to Microsoft Windows PowerShell best practices, and as a result
they are not easily loaded or used outside of the Microsoft Windows
PowerShell session that is opened through the management console. This makes
automation of the Microsoft System Center Service Manager platform much more
difficult than it should be. Discovery and loading issues aside, there are
also some design issues that make working with the commands in the native
modules more difficult than it should be. Add to that some gaps in the
coverage provided by the native modules and you end up with a lackluster
user experience.

Prior to the Microsoft System Center Service Manager 2012 release, several
Microsoft employees and some members of the community collaborated on an
open-source project called SMLets. SMLets is a Microsoft Windows PowerShell
module hosted on CodePlex that defines 97 cmdlets to provide automation
support to Microsoft System Center Service Manager 2010 and later. While the
SMLets module has been a very useful resource for Microsoft System Center
Service Manager 2010, with the 2012 release its usefulness has diminished
rapidly for a number of reasons.

First, and most importantly, the SMLets module is not compatible with the
native modules that ship with Microsoft System Center Service Manager 2012.
It may appear compatible, but only if you load it after the native modules
have been loaded. In this scenario, it is swallowing an error and hiding the
incompatibility from the end user. If you load SMLets first, the native
System.Center.Service.Manager module will not load at all due to the
incompatibility.

Second, since Microsoft now includes native modules out of the box, it is
likely that any future investment in automation capabilities for Microsoft
System Center Service Manager will be made there. The SMLets module has
not been updated since March 2012 (almost 2 years at the time of this
writing).

Finally, there are many commands that are duplicated between the SMLets and
the native cmdlets that ship with Microsoft System Center Service Manager.
These duplications are unnecessary, and between duplicated cmdlets with
different parameters, incompatibility issues, error masking, and a lack of
an update it seems that SMLets are best left to automation tasks with the
downlevel Microsoft System Center Service Manager 2010 release.

ScsmPx is a module that tries to bring together the best of both of these
solutions while addressing the biggest issues that each one has created. For
the native Microsoft System Center Service Manager modules, ScsmPx makes the
cmdlets they contain discoverable which enables auto-loading support for
those modules so that they can be used from any Microsoft Windows PowerShell
host more easily. For the SMLets incompatibility and overlap issues, the
ScsmPx module provides 119 additional commands (open-source functions that
are written in Microsoft Windows PowerShell script) to attempt to close the
functionality gap so that SMLets are not required anymore. By offering a
complementary solution instead of a conflicting one, ScsmPx gives you a
single module to start from when working out automation solutions for
Microsoft System Center Service Manager 2012 and later releases.

Note that while ScsmPx adds many valuable commands today, it does not yet
cover all of the capabilities provided by the SMLets module. Over time
more commands will be added to provide this additional coverage.

### How to load the module

To load the ScsmPx module into PowerShell, invoke the following command:

```powershell
Import-Module -Name ScsmPx
```

This command is not necessary if you are running Microsoft Windows
PowerShell 3.0 or later and if module auto-loading is enabled (default).
The presence of this module also enables auto-loading of the native modules
that ship with Microsoft System Center Service Manager 2012 and later.

### ScsmPx Commands

There are 148 commands available in the ScsmPx module today, and 116 cmdlets
in the native modules, offering a total of 264 commands to make Microsoft
System Center Service Manager automation easier. To see a list of all of the
commands that are available in the ScsmPx and native modules, invoke the
following commands:

```powershell
Get-SCSMCommand
Get-ScsmPxCommand
```

The first command will return a list of commands that are included in the
native modules that ship with Microsoft System Center Service Manager. The
second command will return a list of commands that are included in the
ScsmPx module. Note that all ScsmPx module commands start with the ScsmPx
noun prefix.

###  Managing Microsoft System Center Service Manager with ScsmPx

To see a list of all incidents that you have in your environment, invoke
the following command:

```powershell
Get-ScsmPxIncident
```

This data represents individual instances of the System.WorkItem.Incident
class, and it does not identify any of the objects that are related to those
instances. Commands invoked like this allow for very efficient management of
Microsoft System Center Service Manager object data. If you want to work
with more complex data that includes multiple related instances combined
into a single view, you can request a specific view of that data instead by
using the -View parameter. For example, to see a more user friendly view of
the incidents in your environment you could invoke the following command
instead:

```powershell
Get-ScsmPxIncident -View All
```

This data provides the same information that you see when you access the
corresponding "All Incidents" view in the management console. Note that you
cannot apply filters when you are looking up data using a view. In those
cases, the filters that are defined as part of the view are used.

To see what you can do with that data once you have it, have a look at the
other ScsmPxIncident commands by invoking the following command:

```powershell
Get-Command -Noun ScsmPxIncident
```

This identifies that there are other commands that work with incidents. To
use these commands to modify incidents, you can leverage the pipeline. For
example, to automatically resolve any incidents that have been closed for
more than 7 days, you could use the Set-ScsmPxIncident command in the
following script:

```powershell
# Look up the Resolved incident status enumeration
$resolved = Get-ScsmPxListItem -ListName IncidentStatusEnum -Name Resolved
# Look up the Closed incident status enumeration
$closed = Get-ScsmPxListItem -ListName IncidentStatusEnum -Name Closed
# Identify our search filters (closed incidents at least 7 days old)
$filters = @(
"(Status -eq '$($closed.Id)')"
"(LastModified -lt '$((Get-Date).AddDays(-7))')"
)
# Now get any matching incidents and change their status to resolved
Get-ScsmPxIncident -Filter ($filters -join ' -and ') |
  Set-ScsmPxIncident -Property @{Status = $resolved}
```

That demonstrates one simple example to a common problem that these commands
can help resolve with little effort. Between PowerShell scripts, PowerShell
workflows, Microsoft System Center Service Manager workflows, Microsoft
System Center Orchestrator workflows, and now the new Service Management
Automation (SMA) feature of Microsoft System Center Orchestrator, there are
plenty of opportunities to use PowerShell commands to automate Microsoft
System Center Service Manager. Experiment with the other commands in the
ScsmPx module and see what solutions you can come up with.
