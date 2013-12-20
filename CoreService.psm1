#Requires -version 2.0

$ErrorActionPreference = "Stop";

<#
**************************************************
* Private members
**************************************************
#>

Function Get-CoreServiceBinding
{
	$settings = Get-Settings
	$type = $settings.ConnectionType;
	
	$quotas = New-Object System.Xml.XmlDictionaryReaderQuotas;
	$quotas.MaxStringContentLength = 10485760;
	$quotas.MaxArrayLength = 10485760;
	$quotas.MaxBytesPerRead = 10485760;

	switch($type)
	{
		"LDAP" 
		{ 
			$binding = New-Object System.ServiceModel.WSHttpBinding;
			$binding.Security.Mode = "Message";
			$binding.Security.Transport.ClientCredentialType = "Basic";
		}
		"LDAP-SSL"
		{
			$binding = New-Object System.ServiceModel.WSHttpBinding;
			$binding.Security.Mode = "Transport";
			$binding.Security.Transport.ClientCredentialType = "Basic";
		}
		"netTcp" 
		{ 
			$binding = New-Object System.ServiceModel.NetTcpBinding; 
			$binding.transactionFlow = $true;
			$binding.transactionProtocol = "OleTransactions";
			$binding.Security.Mode = "Transport";
			$binding.Security.Transport.ClientCredentialType = "Windows";
		}
		"SSL"
		{
			$binding = New-Object System.ServiceModel.WSHttpBinding;
			$binding.Security.Mode = "Transport";
			$binding.Security.Transport.ClientCredentialType = "Windows";
		}
		default 
		{ 
			$binding = New-Object System.ServiceModel.WSHttpBinding; 
			$binding.Security.Mode = "Message";
			$binding.Security.Transport.ClientCredentialType = "Windows";
		}
	}
	
	$binding.MaxReceivedMessageSize = 10485760;
	$binding.ReaderQuotas = $quotas;
	return $binding;
}

Function Add-Property($object, $name, $value)
{
	Add-Member -InputObject $object -membertype NoteProperty -name $key -value $value;
}

Function New-ObjectWithProperties([Hashtable]$properties)
{
	$result = New-Object -TypeName System.Object;
	foreach($key in $properties.Keys)
	{
		Add-Property $result $key $properties[$key];
	}
	return $result;
}

Function Get-DefaultSettings
{
	return New-ObjectWithProperties @{
		"AssemblyPath" = Join-Path $PSScriptRoot 'Tridion.ContentManager.CoreService.Client.2011sp1.dll';
		"ClassName" = "Tridion.ContentManager.CoreService.Client.SessionAwareCoreServiceClient";
		"EndpointUrl" = "http://localhost/webservices/CoreService2011.svc/wsHttp";
		"HostName" = "localhost";
		"UserName" = ([Environment]::UserDomainName + "\" + [Environment]::UserName);
		"Version" = "2011-SP1";
		"ConnectionType" = "Default"
	};
}

Function Get-Settings
{
	if ($script:Settings -eq $null)
	{
		$script:Settings = Load-Settings;
	}
	
	return $script:Settings;
}

Function Load-Settings
{
	$settingsFile = Join-Path $PSScriptRoot 'CoreServiceSettings.xml';
	if (Test-Path $settingsFile)
	{
		try
		{
			return Import-Clixml $settingsFile;
		}
		catch
		{
			Write-Host -ForegroundColor Red "Failed to load your existing settings. Using the default settings. "; 
			return Get-DefaultSettings;
		}
	}
	return Get-DefaultSettings;
}

Function Save-Settings($settings)
{
	if ($settings -ne $null)
	{
		$settingsFile = Join-Path $PSScriptRoot 'CoreServiceSettings.xml';
		
		try
		{
			Export-Clixml -Path $settingsFile -InputObject $settings;
			$script:Settings = $settings;
		}
		catch
		{
			Write-Host -ForegroundColor Red "Failed to save your settings for next time.";
			Write-Host -ForegroundColor Red "Perhaps you don't have modify permissions in '$PSScriptRoot'?";
		}
	}
}

<#
**************************************************
* Public members
**************************************************
#>

Function Get-TridionCoreServiceSettings
{
    <#
    .Synopsis
    Gets the settings used to connect to the Core Service.

    .Link
    Get the latest version of this script from the following URL:
    https://code.google.com/p/tridion-powershell-modules/
	#>
    [CmdletBinding()]
    Param()
	
	Process { return Get-Settings; }
}

Function Set-TridionCoreServiceSettings
{
    <#
    .Synopsis
    Changes the settings used to connect to the Core Service.

    .Link
    Get the latest version of this script from the following URL:
    https://code.google.com/p/tridion-powershell-modules/

    .Example
    Set-TridionCoreServiceSettings -hostName "machine.domain" -version "2013-SP1" -connectionType netTcp
	
	Makes the module connect to a Core Service hosted on "machine.domain", using netTcp bindings and the 2013 SP1 version of the service.
	
    #>
    [CmdletBinding()]
    Param
    (
        [Parameter()]
        [string]$hostName,
		
		[ValidateSet('', '2011-SP1', '2013', '2013-SP1')]
		[string]$version,
		
		[Parameter()]
		[string]$userName,
		
		[ValidateSet('', 'Default', 'SSL', 'LDAP', 'LDAP-SSL', 'netTcp')]
		[Parameter()]
		[string]$connectionType,
		
		[Parameter()]
		[switch]$persist
    )

    Process
    {
		$hostNameSpecified = (![string]::IsNullOrEmpty($hostName));
		$userNameSpecified = (![string]::IsNullOrEmpty($userName));
		$versionSpecified = (![string]::IsNullOrEmpty($version));
		$connectionTypeSpecified = (![string]::IsNullOrEmpty($connectionType));
		
		$settings = Get-Settings;
		if ($connectionTypeSpecified) { $settings.ConnectionType = $connectionType; }
		if ($hostNameSpecified) { $settings.HostName = $hostName; }
		if ($userNameSpecified) { $settings.UserName = $userName; }
		if ($versionSpecified) { $settings.Version = $version; }

		if ($versionSpecified -or $hostNameSpecified -or $connectionTypeSpecified)
		{
			$netTcp =  ($settings.connectionType -eq "netTcp");
			$protocol = "http://";
			$port = "";
			
			switch($settings.connectionType)
			{
				"SSL" 		{ $protocol = "https://"; }
				"LDAP-SSL" 	{ $protocol = "https://"; }
				"netTcp"	{ $protocol = "net.tcp://"; $port = ":2660"; }
			}
			
			switch($settings.Version)
			{
				"2011-SP1" 
				{ 
					$settings.AssemblyPath = Join-Path $PSScriptRoot 'Tridion.ContentManager.CoreService.Client.2011sp1.dll';
					$relativeUrl = if ($netTcp) { "/CoreService/2011/netTcp" } else { "/webservices/CoreService2011.svc/wsHttp" };
					$settings.EndpointUrl = (@($protocol, $settings.HostName, $port, $relativeUrl) -join "");
				}
				"2013" 
				{
					$settings.AssemblyPath = Join-Path $PSScriptRoot 'Tridion.ContentManager.CoreService.Client.2013.dll';
					$relativeUrl = if ($netTcp) { "/CoreService/2012/netTcp" } else { "/webservices/CoreService2012.svc/wsHttp" };
					$settings.EndpointUrl = (@($protocol, $settings.HostName, $port, $relativeUrl) -join "");
				}
				"2013-SP1" 
				{ 
					$settings.AssemblyPath = Join-Path $PSScriptRoot 'Tridion.ContentManager.CoreService.Client.2013sp1.dll';
					$relativeUrl = if ($netTcp) { "/CoreService/2013/netTcp" } else { "/webservices/CoreService2013.svc/wsHttp" };
					$settings.EndpointUrl = (@($protocol, $settings.HostName, $port, $relativeUrl) -join "");
				}
			}
		}
		
		if ($persist)
		{
			Save-Settings $settings;
		}
    }
}

Function Get-TridionCoreServiceClient
{
    <#
    .Synopsis
    Gets a client capable of accessing the Tridion Core Service.

    .Description
    Gets a session-aware Core Service client. The Core Service version, binding, and host machine can be modified using Set-TridionCoreServiceSettings.

    .Notes
    Make sure you call the Close method when you are done with the client (i.e. in a finally block).

    .Inputs
    None.

    .Outputs
    Returns a client of type [Tridion.ContentManager.CoreService.Client.SessionAwareCoreServiceClient].

    .Link
    Get the latest version of this script from the following URL:
    https://code.google.com/p/tridion-powershell-modules/

    .Example
    $client = Get-TridionCoreServiceClient;
    if ($client -ne $null)
    {
        try
        {
            $client.GetCurrentUser();
        }
        finally
        {
            $client.Close() | Out-Null;
        }
    }

    #>
    [CmdletBinding()]
    Param()

    Begin
    {
        # Load required .NET assemblies
        Add-Type -AssemblyName System.ServiceModel

        # Load information about the Core Service client available on this system
        $serviceInfo = Get-Settings
        
        Write-Verbose ("Connecting to the Core Service at {0}..." -f $serviceInfo.HostName);
        
        # Load the Core Service Client
        $endpoint = New-Object System.ServiceModel.EndpointAddress -ArgumentList $serviceInfo.EndpointUrl
        $binding = Get-CoreServiceBinding;
        [Reflection.Assembly]::LoadFrom($serviceInfo.AssemblyPath) | Out-Null;            
    }
    
    Process
    {
        try
        {
            $proxy = New-Object $serviceInfo.ClassName -ArgumentList $binding, $endpoint;

            Write-Verbose ("Connecting as {0}" -f $serviceInfo.UserName);
            $proxy.Impersonate($serviceInfo.UserName) | Out-Null;
            
            return $proxy;
        }
        catch [System.Exception]
        {
            Write-Error $_;
            return $null;
        }
    }
}

function Get-TridionPublications
{
    <#
    .Synopsis
    Gets a list of Publications present in Tridion Content Manager.

    .Description
    Gets a list of PublicationData objects containing information about all Publications present in Tridion Content Manager.

    .Notes
    Example of properties available: Id, Title, Key, PublicationPath, PublicationUrl, MultimediaUrl, etc.
    
    For a full list, consult the Content Manager Core Service API Reference Guide documentation 
    (Tridion.ContentManager.Data.CommunicationManagement.PublicationData object)

    .Inputs
    None.

    .Outputs
    Returns a list of objects of type [Tridion.ContentManager.CoreService.Client.PublicationData].

    .Link
    Get the latest version of this script from the following URL:
    https://code.google.com/p/tridion-powershell-modules/

    .Example
    Get-TridionPublications

    .Example
    Get-TridionPublications | Select-Object Title, Id, Key
    
    #>
    [CmdletBinding()]
	Param()
	
    Process
    {
        $client = Get-TridionCoreServiceClient;
        if ($client -ne $null)
        {
            try
            {
                Write-Host "Loading list of Publications...";
                $filter = New-Object Tridion.ContentManager.CoreService.Client.PublicationsFilterData;
                $client.GetSystemWideList($filter);
            }
            finally
            {
                $client.Close() | Out-Null;
            }
        }
    }
}


Function Get-TridionItem
{
    <#
    .Synopsis
    Reads the item with the given ID.

    .Notes
    Example of properties available: Id, Title, etc.
    
    For a full list, consult the Content Manager Core Service API Reference Guide documentation 
    (Tridion.ContentManager.Data.CommunicationManagement.IdentifiableObject object)

    .Inputs
    None.

    .Outputs
    Returns a list of objects of type [Tridion.ContentManager.CoreService.Client.IdentifiableObject].

    .Link
    Get the latest version of this script from the following URL:
    https://code.google.com/p/tridion-powershell-modules/

    .Example
    Get-TridionItem "tcm:2-44"
	Reads a Component.

    .Example
    Get-TridionItem "tcm:2-55-8"
	Reads a Schema.

    .Example
    Get-TridionItem "tcm:2-44" | Select-Object Id, Title
	Reads a Component and outputs just the ID and Title of it.
    
    #>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $id
    )

    Process
    {
        try
        {
            $client = Get-TridionCoreServiceClient
            if ($client.IsExistingObject($id))
            {
                $client.Read($id, (New-Object Tridion.ContentManager.CoreService.Client.ReadOptions));
            }
            else
            {
                Write-Host "There is no item with ID '$id'.";
            }
        }
        finally
        {
            $client.Close() | Out-Null;
        }
    }
}


function Get-TridionUser
{
    <#
    .Synopsis
    Gets information about the a specific Tridion user. Defaults to the current user.

    .Description
    Gets a UserData object containing information about the specified user within Tridion. 
    If called without any parameters, the currently logged on user will be returned.

    .Notes
    Example of properties available: Title, IsEnabled, LanguageId, LocaleId, Privileges (system administrator = 1), etc.
    
    For a full list, consult the Content Manager Core Service API Reference Guide documentation 
    (Tridion.ContentManager.Data.Security.UserData object)

    .Inputs
    None.

    .Outputs
    Returns an object of type [Tridion.ContentManager.CoreService.Client.UserData].

    .Link
    Get the latest version of this script from the following URL:
    https://code.google.com/p/tridion-powershell-modules/

    .Example
    Get-TridionUser | Format-List
    
    Returns a formatted list of properties of the currently logged on user.

    .Example
    Get-TridionUser | Select-Object Title, LanguageId, LocaleId, Privileges
    
    Returns the title, language, locale, and privileges (system administrator) of the currently logged on user.
    
    .Example
    Get-TridionUser "tcm:0-12-65552"
    
    Returns information about user #11 within Tridion (typically the Administrator user created during installation).
    
    #>
    [CmdletBinding()]
    Param
    (
        [Parameter(ValueFromPipeline=$true)]
        [string]$id
    )

    
    Process
    {
        $client = Get-TridionCoreServiceClient;
        if ($client -ne $null)
        {
            try
            {
                if ([string]::IsNullOrEmpty($id))
                {
                    Write-Host "Loading current user...";
                    $client.GetCurrentUser();
                }
                else
                {
                    Write-Host "Loading Tridion user...";
                    if (!$client.IsExistingObject($id))
                    {
                        Write-Host "There is no such user in the system.";
                        return $null;
                    }
                    
                    $readOptions = New-Object Tridion.ContentManager.CoreService.Client.ReadOptions;
                    $readOptions.LoadFlags = [Tridion.ContentManager.CoreService.Client.LoadFlags]::WebdavUrls -bor [Tridion.ContentManager.CoreService.Client.LoadFlags]::Expanded;
                    $client.Read($id, $readOptions);
                }
            }
            finally
            {
                $client.Close() | Out-Null;
            }
        }
    }
}


function New-TridionGroup
{
    <#
    .Synopsis
    Adds a new Group to Tridion Content Manager.

    .Description
    Adds a new Group to Tridion Content Manager with the given name. 
    Optionally, you may specify a description for the Group. 
	It can also be a member of other Groups and only be available under specific Publications.

    .Notes
     Example of properties available: Id, Title, Scope, GroupMemberships, etc.
    
    For a full list, consult the Content Manager Core Service API Reference Guide documentation 
    (Tridion.ContentManager.Data.Security.GroupData object)

    .Inputs
    [string] name: the user name including the domain.
    [string] description: a description of the Group. Defaults to the $name parameter.

    .Outputs
    Returns an object of type [Tridion.ContentManager.CoreService.Client.GroupData], representing the newly created Group.

    .Link
    Get the latest version of this script from the following URL:
    https://code.google.com/p/tridion-powershell-modules/

    .Example
    New-TridionGroup "Content Editors (NL)"
    
    Creates a new Group with the name "Content Editors (NL)". It is valid for all Publications.
    
    .Example
    New-TridionGroup "Content Editors (NL)" -description "Dutch Content Editors"
    
    Creates a new Group with the name "Content Editors (NL)" and a description of "Dutch Content Editors". 
	It is valid for all Publications.
    
    .Example
    New-TridionGroup "Content Editors (NL)" -description "Dutch Content Editors" | Format-List
    
    Creates a new Group with the name "Content Editors (NL)" and a description of "Dutch Content Editors". 
	It is valid for all Publications.
    Displays all of the properties of the resulting Group as a list.
	
	.Example
	New-TridionGroup -name "Content Editors (NL)" -description "Dutch Content Editors" -scope @("tcm:0-1-1", "tcm:0-2-1") -memberOf @("tcm:0-5-65568", "tcm:0-7-65568");
	
	Creates a new Group with the name "Content Editors (NL)" and a description of "Dutch Content Editors". 
	It is only usable in Publication 1 and 2.
	It is a member of the Author and Editor groups.    
    #>
    [CmdletBinding()]
    Param(
    
            [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
            [string]$name,
            
            [Parameter()]
            [string]$description,
			
			[Parameter()]
			[string[]]$scope,
			
			[Parameter()]
			[string[]]$memberOf
    )

    Process
    {
        $client = Get-TridionCoreServiceClient;
        if ($client -ne $null)
        {
            try
            {
                if ($description –is [ScriptBlock]) 
                { 
                    [string]$groupDescription = $description.invoke() 
                }
                else
                { 
					$groupDescription = if ([string]::IsNullOrEmpty($description)) { $name } else { $description };
                }

                $readOptions = New-Object Tridion.ContentManager.CoreService.Client.ReadOptions;
                $readOptions.LoadFlags = [Tridion.ContentManager.CoreService.Client.LoadFlags]::None;
                
				if ($client.GetDefaultData.OverloadDefinitions[0].IndexOf('string containerId') -gt 0)
				{
					$group = $client.GetDefaultData("Group", $null, $readOptions);
				}
				else
				{
					$group = $client.GetDefaultData("User", $null);
				}
                
                $group.Title = $name;
                $group.Description = $groupDescription;
				
				if (![string]::IsNullOrEmpty($scope))
				{
					foreach($publicationUri in $scope)
					{
						$link = New-Object Tridion.ContentManager.CoreService.Client.LinkWithIsEditableToRepositoryData;
						$link.IdRef = $publicationUri;
						$group.Scope += $link;
					}
				}
				
				if (![string]::IsNullOrEmpty($memberOf))
				{
					foreach($groupUri in $memberOf)
					{
						$groupData = New-Object Tridion.ContentManager.CoreService.Client.GroupMembershipData;
						$groupLink = New-Object Tridion.ContentManager.CoreService.Client.LinkToGroupData;
						$groupLink.IdRef = $groupUri;
						$groupData.Group = $groupLink;
						$group.GroupMemberships += $groupData;
					}
				}
				
                $client.Create($group, $readOptions);
                Write-Host ("Group '{0}' has been created." -f $name);
            }
            finally
            {
                $client.Close() | Out-Null;
            }
        }
    }
}


function New-TridionUser
{
    <#
    .Synopsis
    Adds a new user to Tridion Content Manager.

    .Description
    Adds a new user to Tridion Content Manager with the given user name and description (friendly name). 
    Optionally, the user can be given system administrator rights with the Content Manager.

    .Notes
    Example of properties available: Id, Title, Key, PublicationPath, PublicationUrl, MultimediaUrl, etc.
    
    For a full list, consult the Content Manager Core Service API Reference Guide documentation 
    (Tridion.ContentManager.Data.CommunicationManagement.PublicationData object)

    .Inputs
    [string] userName: the user name including the domain.
    [string] description: the friendly name of the user, typically the full name. Defaults to the $userName parameter.
    [bool] isAdmin: set to true if you wish to give the new user full administrator rights within the Content Manager. Defaults to $false.

    .Outputs
    Returns an object of type [Tridion.ContentManager.CoreService.Client.UserData], representing the newly created user.

    .Link
    Get the latest version of this script from the following URL:
    https://code.google.com/p/tridion-powershell-modules/

    .Example
    New-TridionUser "GLOBAL\user01"
    
    Adds "GLOBAL\user01" to the Content Manager with a description matching the user name and no administrator rights.
    
    .Example
    New-TridionUser "GLOBAL\user01" "User 01"
    
    Adds "GLOBAL\user01" to the Content Manager with a description of "User 01" and no administrator rights.
    
    .Example
    New-TridionUser -username GLOBAL\User01 -isAdmin $true
    
    Adds "GLOBAL\user01" to the Content Manager with a description matching the user name and system administrator rights.

    .Example
    New-TridionUser "GLOBAL\user01" "User 01" $true | Format-List
    
    Adds "GLOBAL\user01" to the Content Manager with a description of "User 01" and system administrator rights.
    Displays all of the properties of the resulting user as a list.
    
    #>
    [CmdletBinding()]
    Param(
    
            [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
            [string]$userName,
            
            [Parameter()]
            [string]$description,
            
            [Parameter()]
            [bool]$isAdmin = $false
    )

    Process
    {
        $client = Get-TridionCoreServiceClient;
        if ($client -ne $null)
        {
            try
            {
                if ($description –is [ScriptBlock]) 
                { 
                    [string]$userDescription = $description.invoke() 
                }
                else
                {
					$userDescription = if ([string]::IsNullOrEmpty($description)) { $userName } else { $description };
                }

                $readOptions = New-Object Tridion.ContentManager.CoreService.Client.ReadOptions;
                $readOptions.LoadFlags = [Tridion.ContentManager.CoreService.Client.LoadFlags]::None;
                
				if ($client.GetDefaultData.OverloadDefinitions[0].IndexOf('string containerId') -gt 0)
				{
					$user = $client.GetDefaultData("User", $null, $readOptions);
				}
				else
				{
					$user = $client.GetDefaultData("User", $null);
				}
                
                $user.Title = $userName;
                $user.Description = $userDescription;

                if ($isAdmin)
                {
                    $user.Privileges = 1;
                }
                else
                {
                    $user.Privileges = 0;
                }
                
                $client.Create($user, $readOptions);
                Write-Host ("User '{0}' has been added." -f $userDescription);
            }
            finally
            {
                $client.Close() | Out-Null;
            }
        }
    }
}


Function Get-TridionUsers
{
    <#
    .Synopsis
    Gets a list of user within Tridion Content Manager.

    .Description
    Gets a list of users within Tridion Content Manager. 

    .Notes
    Example of properties available: Id, Title, IsEnabled, etc.
    
    For a full list, consult the Content Manager Core Service API Reference Guide documentation 
    (Tridion.ContentManager.Data.Security.UserData object)

    .Inputs
    None.

    .Outputs
    Returns a list of objects of type [Tridion.ContentManager.CoreService.Client.UserData].

    .Link
    Get the latest version of this script from the following URL:
    https://code.google.com/p/tridion-powershell-modules/

    .Example
    Get-TridionUsers
    
    Gets a list of all users.
    
    .Example
    Get-TridionUsers | Select-Object Id,Title,IsEnabled
    
    Gets the ID, Title, and enabled status of all users.
    
    .Example
    Get-TridionUsers | Where-Object { $_.IsEnabled -eq $false } | Select-Object Id,Title,IsEnabled | Format-List
    
    Gets the ID, Title, and enabled status of all disabled users in the system.
    Displays all of the properties as a list.
    
    #>
    Process
    {
        $client = Get-TridionCoreServiceClient;
        if ($client -ne $null)
        {
            try
            {
                Write-Host "Getting a list of Tridion users.";
                $filter = New-Object Tridion.ContentManager.CoreService.Client.UsersFilterData;
                $client.GetSystemWideList($filter);
            }
            finally
            {
                $client.Close() | Out-Null;
            }
        }
    }
}


<#
**************************************************
* Export statements
**************************************************
#>
Export-ModuleMember Get-TridionCoreServiceClient
Export-ModuleMember Get-TridionCoreServiceSettings;
Export-ModuleMember Get-TridionItem
Export-ModuleMember Get-TridionPublications
Export-ModuleMember Get-TridionUser
Export-ModuleMember Get-TridionUsers
Export-ModuleMember New-TridionGroup
Export-ModuleMember New-TridionUser
Export-ModuleMember Set-TridionCoreServiceSettings;