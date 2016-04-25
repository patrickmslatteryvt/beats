# beats
Some Elastic Beats install and config files

### install_beats.ps1
Powershell script to install the Elastic Beats collectors on Windows systems<br>
Tested on Windows 2008 R2 and 2012 R2<br>
Use like this:<br>
``` powershell
Import-Module BitsTransfer
mkdir C:\scripts
Start-BitsTransfer -Source https://raw.githubusercontent.com/patrickmslatteryvt/beats/master/install_beats.ps1 -Destination "C:\scripts"
cd C:\scripts
PowerShell.exe -ExecutionPolicy UnRestricted -File .\install_beats.ps1 [-version 1.2.1] [-filebeat_forwarder forwarder.internal.domain.com:9200] [-winlogbeat_forwarder forwarder.internal.domain.com:9100] [-topbeat_forwarder forwarder.internal.domain.com:7177]
```
Where the args in the brackets are optional
