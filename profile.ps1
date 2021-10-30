Set-Location -Path ($MyInvocation.MyCommand.Path -replace '\\[^\\]+$')
Import-Module .\CurlUpdater.psm1
Update-Curl -Save H:\Software\cURL