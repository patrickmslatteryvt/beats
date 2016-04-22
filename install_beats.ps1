# Powershell script to install the Elastic Beats collectors on Windows systems
# Tested on Windows 2008 R2 and 2012 R2
# Use like this:
# mkdir C:\scripts
# Start-BitsTransfer -Source https://raw.githubusercontent.com/patrickmslatteryvt/beats/master/install_beats.ps1 -Destination "C:\scripts"
# cd C:\scripts
# PowerShell.exe -ExecutionPolicy UnRestricted -File .\install_beats.ps1 [-version 1.2.1] [-forwarder forwarder.internal.domain.com:9200]

# Default parameters to use in the case that the user did not pass in any args on the CLI
param (
   [string]$forwarder = "forwarder.internal.domain.com:9200",
   [string]$version = "1.2.1"
)

# Set some default values
$install_dir = "C:\Program Files\Elastic"
$filebeat_yml = "$install_dir\filebeat\filebeat.yml"
$winlogbeat_yml = "$install_dir\winlogbeat\winlogbeat.yml"
$topbeat_yml = "$install_dir\topbeat\topbeat.yml"
$url_base = "https://download.elastic.co/beats"

# Function to unzip files (Is built-in in PS v5)
Add-Type -AssemblyName System.IO.Compression.FileSystem
Function Expand-Archive { param([string]$zipfile, [string]$outpath) [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath) }

# Function using Here strings to cleanly write out the new Filebeat Yaml config file
Function CreateFilebeatYmlFile {@"
filebeat:
  prospectors:
    -
      paths:
        - L:\*\*.log
        - L:\*\*\*.log
      input_type: log
  registry_file: "C:/ProgramData/filebeat/registry"
output:
  elasticsearch:
    hosts: ["$forwarder"]
shipper:
logging:
  files:
    rotateeverybytes: 10485760 # = 10MB
"@ | Set-Content $filebeat_yml -encoding UTF8}

# Create an install directory
New-Item -path "C:\Program Files\" -name "Elastic" -type directory

################################################################################

# Install and enable Filebeat
Start-BitsTransfer -Source $url_base/filebeat/filebeat-$version-windows.zip -Destination $install_dir
Expand-Archive "$install_dir\filebeat-$version-windows.zip" $install_dir
Remove-Item "$install_dir\filebeat-$version-windows.zip"
Rename-Item -path "$install_dir\filebeat-$version-windows" -newName "filebeat"
Rename-Item -path $filebeat_yml -newName "filebeat.yml.original"
# Create a new very minimal config file
CreateFilebeatYmlFile
# Create the service using the provided install script
cd "$install_dir\filebeat"
PowerShell.exe -ExecutionPolicy UnRestricted -File .\install-service-filebeat.ps1
# Set service start parameters and start the service
Set-Service filebeat -startuptype automatic
Start-Service -name filebeat

################################################################################

# Install and enable Winlogbeat
Start-BitsTransfer -Source $url_base/winlogbeat/winlogbeat-$version-windows.zip -Destination $install_dir
Expand-Archive "$install_dir\winlogbeat-$version-windows.zip" $install_dir
Remove-Item "$install_dir\winlogbeat-$version-windows.zip"
Rename-Item -path "$install_dir\winlogbeat-$version-windows" -newName "winlogbeat"
Rename-Item -path "$install_dir\winlogbeat\winlogbeat.yml" -newName "winlogbeat.yml.original"
# Search and replace the forwarder value
$oldfile = "$install_dir\winlogbeat\winlogbeat.yml.original"
$newfile = "$install_dir\winlogbeat\winlogbeat.yml"
$text = (Get-Content -Path $oldfile -ReadCount 0) -join "`n"
$text -replace 'localhost', $forwarder | Set-Content -Path $newfile
cd "$install_dir\winlogbeat"
PowerShell.exe -ExecutionPolicy UnRestricted -File .\install-service-winlogbeat.ps1
Set-Service winlogbeat -startuptype automatic
Start-Service -name winlogbeat

################################################################################

# Install but disable topbeat
Start-BitsTransfer -Source $url_base/topbeat/topbeat-$version-windows.zip -Destination $install_dir
Expand-Archive "$install_dir\topbeat-$version-windows.zip" $install_dir
Remove-Item "$install_dir\topbeat-$version-windows.zip"
Rename-Item -path "$install_dir\topbeat-$version-windows" -newName "topbeat"
### Need to write out the YAML file here
cd "$install_dir\topbeat"
PowerShell.exe -ExecutionPolicy UnRestricted -File .\install-service-topbeat.ps1
Set-Service topbeat -startuptype disabled
Stop-Service -name topbeat
