# Powershell script to install the Elastic Beats collectors on Windows systems
# Call like this:
# mkdir C:\scripts
# Start-BitsTransfer -Source https://raw.githubusercontent.com/patrickmslatteryvt/beats/master/install_beats.ps1 -Destination "C:\scripts"
# cd C:\scripts
# PowerShell.exe -ExecutionPolicy UnRestricted -File .\install_beats.ps1 [-version 1.2.1] [-forwarder forwarder.internal.domain.com]

param (
   [string]$forwarder = "forwarder.internal.domain.com",
   [string]$version = "1.2.1"
)

$filebeat_yml = "C:\Program Files\Elastic\filebeat\filebeat.yml"
$winlogbeat_yml = "C:\Program Files\Elastic\winlogbeat\winlogbeat.yml"
$topbeat_yml = "C:\Program Files\Elastic\topbeat\topbeat.yml"

# Function to unzip files (Is built-in in PS v5)
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Expand-Archive { param([string]$zipfile, [string]$outpath) [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath) }

# Create an install directory
New-Item -path "C:\Program Files\" -name "Elastic" -type directory

# Install and enable Filebeat
Start-BitsTransfer -Source https://download.elastic.co/beats/filebeat/filebeat-$version-windows.zip -Destination "C:\Program Files\Elastic"
Expand-Archive "C:\Program Files\Elastic\filebeat-$version-windows.zip" "C:\Program Files\Elastic"
Remove-Item "C:\Program Files\Elastic\filebeat-$version-windows.zip"
Rename-Item -path "C:\Program Files\Elastic\filebeat-$version-windows" -newName "filebeat"
Rename-Item -path $filebeat_yml -newName "filebeat.yml.original"
Set-Content -Value 'filebeat:' -Path $filebeat_yml
Add-Content -Value '  prospectors:' -Path $filebeat_yml
Add-Content -Value '    -' -Path $filebeat_yml
Add-Content -Value '      paths:' -Path $filebeat_yml
# Put the correct paths to the logs here
Add-Content -Value '        - L:\*\*.log' -Path $filebeat_yml
Add-Content -Value '        - L:\*\*\*.log' -Path $filebeat_yml
Add-Content -Value '      input_type: log' -Path $filebeat_yml
Add-Content -Value '  registry_file: "C:/ProgramData/filebeat/registry"' -Path $filebeat_yml
Add-Content -Value 'output:' -Path $filebeat_yml
Add-Content -Value '  elasticsearch:' -Path $filebeat_yml
# Not working...
# Add-Content -Value '    hosts: ["' $forwarder ':9200"]' -Path $filebeat_yml
# Quick and dirty workaround:
Add-Content -Value '    hosts: ["localhost:9200"]' -Path $filebeat_yml
Add-Content -Value 'shipper:' -Path $filebeat_yml
Add-Content -Value 'logging:' -Path $filebeat_yml
Add-Content -Value '  files:' -Path $filebeat_yml
Add-Content -Value '    rotateeverybytes: 10485760 # = 10MB' -Path $filebeat_yml
Rename-Item -path $filebeat_yml -newName "filebeat.yml.temp"
$oldfile = "C:\Program Files\Elastic\filebeat\filebeat.yml.temp"
$newfile = $filebeat_yml
$text = (Get-Content -Path $oldfile -ReadCount 0) -join "`n"
# Insert the correct FQDN to the RELK forwarder here
$text -replace 'localhost', $forwarder | Set-Content -Path $newfile
Remove-Item "C:\Program Files\Elastic\filebeat\filebeat.yml.temp"
cd "C:\Program Files\Elastic\filebeat"
PowerShell.exe -ExecutionPolicy UnRestricted -File .\install-service-filebeat.ps1
Set-Service filebeat -startuptype automatic
Start-Service -name filebeat

# Install and enable Winlogbeat
Start-BitsTransfer -Source https://download.elastic.co/beats/winlogbeat/winlogbeat-$version-windows.zip -Destination "C:\Program Files\Elastic"
Expand-Archive "C:\Program Files\Elastic\winlogbeat-$version-windows.zip" "C:\Program Files\Elastic"
Remove-Item "C:\Program Files\Elastic\winlogbeat-$version-windows.zip"
Rename-Item -path "C:\Program Files\Elastic\winlogbeat-$version-windows" -newName "winlogbeat"
Rename-Item -path "C:\Program Files\Elastic\winlogbeat\winlogbeat.yml" -newName "winlogbeat.yml.original"
$oldfile = "C:\Program Files\Elastic\winlogbeat\winlogbeat.yml.original"
$newfile = "C:\Program Files\Elastic\winlogbeat\winlogbeat.yml"
$text = (Get-Content -Path $oldfile -ReadCount 0) -join "`n"
# Put the correct FQDN to the RELK forwarder here
$text -replace 'localhost:9200', 'relkfwdofg.internal.mywebgrocer.com:9200' | Set-Content -Path $newfile
$text -replace 'localhost:9200', "$(Get-Date):9200" | Set-Content -Path $newfile
cd "C:\Program Files\Elastic\winlogbeat"
PowerShell.exe -ExecutionPolicy UnRestricted -File .\install-service-winlogbeat.ps1
Set-Service winlogbeat -startuptype automatic
Start-Service -name winlogbeat

# Install but disable topbeat
Start-BitsTransfer -Source https://download.elastic.co/beats/topbeat/topbeat-$version-windows.zip -Destination "C:\Program Files\Elastic"
Expand-Archive "C:\Program Files\Elastic\topbeat-$version-windows.zip" "C:\Program Files\Elastic"
Remove-Item "C:\Program Files\Elastic\topbeat-$version-windows.zip"
Rename-Item -path "C:\Program Files\Elastic\topbeat-$version-windows" -newName "topbeat"
### Need to write out the YAML file here
cd "C:\Program Files\Elastic\topbeat"
PowerShell.exe -ExecutionPolicy UnRestricted -File .\install-service-topbeat.ps1
Set-Service topbeat -startuptype disabled
Stop-Service -name topbeat
