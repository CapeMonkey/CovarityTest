Param(
    [Parameter(Mandatory=$true,Position=1)] [string]$configFileName,
    [switch]$Teardown
    )

#$ErrorActionPreference = "Stop"
$logToConsole = $true

Import-Module WebAdministration

# Recursive helper method to create directories. Will also make correctly
# defined subdirectories
#   $dirDef is XML with a Name parameter
#   $currPath is the path for this directory to be created in
function Make-DirsFromXML([System.Xml.XmlElement]$dirDef, $currPath) {
    [String]$makePath = $currPath + "\" + $dirDef.name
    mkdir $makePath
    foreach ($subdirDef in $dirDef.folder) {
        Make-DirsFromXML -dirDef $subdirDef -currPath $makePath
    }
}

# Load configuration file

$configFile = Get-Content $configFileName

$config = @{}

foreach ($line in $configFile) {
    if ($line.Trim() -ne "") {
        $keypair = @()
        $keypair = $line.Split("=")
        if ($keypair.count -eq 2) {
            $config.Add($keypair[0].Trim(), $keypair[1].Trim())
        }
    }
}

# Determine where to log

$logFile =""

if ($config.ContainsKey("Log") -and $config["Log"] -ne "") {
    $logFile = $config["Log"]
    $logToConsole = $false
}

# Set up variables
$missingVars = @()

$directory = $config["NewWebsiteBaseDirectoryFullPath"]
if (! ($config.ContainsKey("NewWebsiteBaseDirectoryFullPath"))) {
    $missingVars += "NewWebsiteBaseDirectoryFullPath"
}

$directoryDefnFile = $config["DirectoryDefinitionXMLFile"]
if (! ($config.ContainsKey("DirectoryDefinitionXMLFile"))) {
    $missingVars += "DirectoryDefinitionXMLFile"
}

$appPoolName = $config["NewApplicationPoolName"]
if (! ($config.ContainsKey("NewApplicationPoolName"))) {
    $missingVars += "NewApplicationPoolName"
}

$websiteName = $config["NewWebsiteName"]
if (! ($config.ContainsKey("NewWebsiteName"))) {
    $missingVars += "NewWebsiteName"
}

$websiteLogDir = $config["NewWebsiteLogDirectoryFullPath"]
if (! ($config.ContainsKey("NewWebsiteLogDirectoryFullPath"))) {
    $missingVars += "NewWebsiteLogDirectoryFullPath"
}

if($missingVars.length -ne 0) {
    $tim = (Get-Date).toString()
    $msg = "$tim Aborting, missing variables in $configFileName for"
    foreach($var in $missingVars) {
        $msg += "`n $var"
    } 
    if ($logToConsole) {
        Write-Host $msg
    } else {
        $msg | Add-Content $logfile
    }
    return
}

# Teardown Website if desired

if ($Teardown) {

    # Remove website

    if (!(Test-Path "IIS:\sites\$websiteName")) {
        $tim = (Get-Date).toString()
        $msg = "$tim Aborting, cannot remove website $websiteName, it does not exist"
        if ($logToConsole) {
            Write-Host $msg
        } else {
            $msg | Add-Content $logfile
        }    
        return
    }

    Remove-Website -Name $websiteName
    $tim = (Get-Date).toString()
    $msg = "$tim Removed website $websiteName"
    if ($logToConsole) {
        Write-Host $msg
    } else {
        $msg | Add-Content $logfile
    }

    # Remove Application pool

    if (!(Test-Path "IIS:\AppPools\$appPoolName")) {
        $tim = (Get-Date).toString()
        $msg = "$tim Cannot remove AppPool $appPoolName, it does not exist"
        if ($logToConsole) {
            Write-Host $msg
        } else {
            $msg | Add-Content $logfile
        }    
        return
    }


    # Verify that the app pool is empty before removing

    $sites = Get-Website
    $safeRemove = $true

    foreach ($site in $sites) {
        if ($site.ApplicationPool -eq $appPoolName) {
            $safeRemove = $false
            break
        }
    }

    if ($safeRemove) {
        Remove-WebAppPool -Name $appPoolName
        $tim = (Get-Date).toString()
        $msg = "$tim Removed AppPool $appPoolName"
        if ($logToConsole) {
            Write-Host $msg
        } else {
            $msg | Add-Content $logfile
        }
    } else {
        $tim = (Get-Date).toString()
        $msg = "$tim Did not remove AppPool $appPoolName because other applications are using it"
        if ($logToConsole) {
            Write-Host $msg
        } else {
            $msg | Add-Content $logfile
        }        
    }

    return
}

# Verify that App Pool and Website don't exist

if (Test-Path "IIS:\AppPools\$appPoolName") {
    $tim = (Get-Date).toString()
    $msg = "$tim Aborting, $appPoolName already exists"
    if ($logToConsole) {
        Write-Host $msg
    } else {
        $msg | Add-Content $logfile
    }    
    return
}

if (Test-Path "IIS:\sites\$websiteName") {
    $tim = (Get-Date).toString()
    $msg = "$tim Aborting, $websiteName already exists"
    if ($logToConsole) {
        Write-Host $msg
    } else {
        $msg | Add-Content $logfile
    }    
    return
}

# Setup Directories

[xml]$dirXml = Get-Content $directoryDefnFile
[System.Xml.XmlElement] $root = $dirXml.get_DocumentElement()

if (!(Test-Path $directory)) {
    mkdir $directory
} elseif (Test-Path $directory -PathType Leaf) {
    $tim = (Get-Date).toString()
    $msg = "$tim Aborting, $directory already exists and is not a directory"
    if ($logToConsole) {
        Write-Host $msg
    } else {
        $msg | Add-Content $logfile
    }    
    return    
}

foreach ($subdirDef in $root.folder) {
    Make-DirsFromXML -dirDef $subdirDef -currPath $directory
}

# Create new AppPool
#   PipelineMode: Integrated
#   RuntimeVersion: 4.0

New-WebAppPool -Name $appPoolName
$appPool = Get-Item "IIS:\AppPools\$appPoolName"
$appPool.managedPipeLineMode = "Integrated"
$appPool.managedRuntimeVersion = "v4.0"
$appPool | Set-Item

$tim = (Get-Date).toString()
$msg = "$tim Created AppPool $realAppPool"
if ($logToConsole) {
    Write-Host $msg
} else {
    $msg | Add-Content $logfile
}

# Create and Configure new Website

New-WebSite -Name $websiteName -PhysicalPath $directory -ApplicationPool $appPoolName
$website = Get-Item "IIS:\sites\$websiteName"
$realDir = $website.PhysicalPath
$realAppPool = $website.ApplicationPool

$tim = (Get-Date).toString()
$msg = "$tim Created website $websiteName, content in $realDir, in AppPool $realAppPool"
if ($logToConsole) {
    Write-Host $msg
} else {
    $msg | Add-Content $logfile
}

$website = Get-Item "IIS:\sites\$websiteName"

try {
    if ((Test-Path $websiteLogDir) -eq 0) {
        mkdir $websiteLogDir
    }
} catch {
    $tim = (Get-Date).toString()
    $msg = "$tim Could not create $websiteLogDir. Please use an existing directory or create in an existing directory"
    if ($logToConsole) {
        Write-Warning $msg
    } else {
        "WARNING: $msg" | Add-Content $logfile
    }
}
$website.LogFile.directory = $websiteLogDir
$website | Set-Item

$tim = (Get-Date).toString()
$msg = "$tim Configured website $websiteName"
if ($logToConsole) {
    Write-Host $msg
} else {
    $msg | Add-Content $logfile
}