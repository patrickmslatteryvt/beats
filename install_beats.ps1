# Powershell script to install the Elastic Beats collectors on Windows systems
# Tested on Windows 2008 R2 and 2012 R2
# Use like this:
# mkdir C:\scripts
# Start-BitsTransfer -Source https://raw.githubusercontent.com/patrickmslatteryvt/beats/master/install_beats.ps1 -Destination "C:\scripts"
# cd C:\scripts
# PowerShell.exe -ExecutionPolicy UnRestricted -File .\install_beats.ps1 [-version 1.2.1] [-filebeat_forwarder forwarder.internal.domain.com:9200] [-winlogbeat_forwarder forwarder.internal.domain.com:9100] [-topbeat_forwarder forwarder.internal.domain.com:7177]
# Args in brackets [] are optional

# Default parameters to use in the case that the user did not pass in any args on the CLI
param (
   [string]$filebeat_forwarder = "forwarder.internal.domain.com:9200",
   [string]$winlogbeat_forwarder = "forwarder.internal.domain.com:9100",
   [string]$topbeat_forwarder = "forwarder.internal.domain.com:7177",
   [string]$version = "1.2.1"
)

# Import BitsTransfer
Import-Module BitsTransfer

# Set some default values
$install_dir = "C:\Program Files\Elastic"
$filebeat_yml = "$install_dir\filebeat\filebeat.yml"
$winlogbeat_yml = "$install_dir\winlogbeat\winlogbeat.yml"
$topbeat_yml = "$install_dir\topbeat\topbeat.yml"
$url_base = "https://download.elastic.co/beats"

# Function to unzip files (Is built-in in PS v5)
# Add-Type -AssemblyName System.IO.Compression.FileSystem
# Function Expand-Archive { param([string]$zipfile, [string]$outpath) [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath) }

# different function for zip expansion http://www.howtogeek.com/tips/how-to-extract-zip-files-using-powershell/
# the 0x14 flag silently overwrites
function Expand-ZIPFile($file, $destination)
{
  $shell = new-object -com shell.application
  $zip = $shell.NameSpace($file)
  foreach($item in $zip.items())
  {
    $shell.Namespace($destination).copyhere($item, 0x14)
  }
}

# Function using Here strings to cleanly write out the new Filebeat Yaml config file
Function CreateFilebeatYmlFile {@"
filebeat:
  prospectors:
    -
      paths:
# Watch all the IIS log files on the L: drive
        - L:\*\*.log
        - L:\*\*\*.log
      input_type: log
      document_type: IIS
      exclude_lines: ['^#']
      exclude_files: ['^L:\\Octopus\\.*','^L:\\smtp\\.*']
  registry_file: "C:/ProgramData/filebeat/registry"
output:
  logstash:
    hosts: ["$filebeat_forwarder"]
shipper:
logging:
  level: info
  files:
    rotateeverybytes: 10485760 # = 10MB
"@ | Set-Content $filebeat_yml -encoding UTF8}

# Cleanly write out the new Topbeat Yaml config file
Function CreateTopbeatYmlFile {@"
input:
  # In seconds, defines how often to read server statistics
  period: 10
  # Regular expression to match the processes that are monitored
  # By default, all the processes are monitored
  procs: [".*"]
  # Statistics to collect (all enabled by default)
  stats:
    system: true
    proc: true
    filesystem: true
output:
  logstash:
    hosts: ["$topbeat_forwarder"]
    max-retries: 0
logging:
  level: info
  # enable file rotation with default configuration
  to_files: true
  # do not log to syslog
  to_syslog: false
  files:
    keepfiles: 7
"@ | Set-Content $topbeat_yml -encoding UTF8}

# Create an install directory
New-Item -path "C:\Program Files\" -name "Elastic" -type directory

################################################################################

# Install and enable Filebeat
$service = "filebeat"
Start-BitsTransfer -Source $url_base/$service/$service-$version-windows.zip -Destination $install_dir
# Expand-Archive "$install_dir\$service-$version-windows.zip" $install_dir
Expand-ZIPFile "$install_dir\$service-$version-windows.zip" $install_dir
Remove-Item "$install_dir\$service-$version-windows.zip"
Rename-Item -path "$install_dir\$service-$version-windows" -newName $service
Rename-Item -path $filebeat_yml -newName "$service.yml.original"
# Create a new very minimal config file
CreateFilebeatYmlFile
# Create the service using the provided install script
cd "$install_dir\$service"
PowerShell.exe -ExecutionPolicy UnRestricted -File .\install-service-$service.ps1
# Set service start parameters and start the service
Set-Service $service -startuptype automatic
Start-Service -name $service

################################################################################

# Install and enable Winlogbeat
$service = "winlogbeat"
Start-BitsTransfer -Source $url_base/$service/$service-$version-windows.zip -Destination $install_dir
# Expand-Archive "$install_dir\$service-$version-windows.zip" $install_dir
Expand-ZIPFile "$install_dir\$service-$version-windows.zip" $install_dir
Remove-Item "$install_dir\$service-$version-windows.zip"
Rename-Item -path "$install_dir\$service-$version-windows" -newName $service
Rename-Item -path $winlogbeat_yml -newName "$service.yml.original"

# Search and replace the forwarder value
$oldfile = "$install_dir\winlogbeat\winlogbeat.yml.original"
$newfile = "$install_dir\winlogbeat\winlogbeat.yml"
$text = (Get-Content -Path $oldfile -ReadCount 0) -join "`n"
$text -replace 'localhost:9200', $winlogbeat_forwarder | Set-Content -Path $newfile

cd "$install_dir\$service"
PowerShell.exe -ExecutionPolicy UnRestricted -File .\install-service-$service.ps1
Set-Service $service -startuptype automatic
Start-Service -name $service

################################################################################

# Install but disable topbeat
$service = "topbeat"
Start-BitsTransfer -Source $url_base/$service/$service-$version-windows.zip -Destination $install_dir
# Expand-Archive "$install_dir\$service-$version-windows.zip" $install_dir
Expand-ZIPFile "$install_dir\$service-$version-windows.zip" $install_dir
Remove-Item "$install_dir\$service-$version-windows.zip"
Rename-Item -path "$install_dir\$service-$version-windows" -newName $service
Rename-Item -path $topbeat_yml -newName "$service.yml.original"
CreateTopbeatYmlFile
cd "$install_dir\$service"
PowerShell.exe -ExecutionPolicy UnRestricted -File .\install-service-$service.ps1
Set-Service $service -startuptype Disabled
# Start-Service -name $service
