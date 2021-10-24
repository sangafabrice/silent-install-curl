$CURL_FOR_WINDOWS_PAGE = 'https://curl.se/windows/'
$CURL_EXECUTABLE_NAME = 'curl.exe'
$CURL_CERTIFICATE_NAME = 'curl-ca-bundle.crt'
$NT_ACCOUNT_ADMINISTRATORS = [System.Security.Principal.NTAccount] "BUILTIN\Administrators"
$ACCESS_RULE = [System.Security.AccessControl.FileSystemAccessRule]::new('BUILTIN\Administrators','FullControl','Allow')
$CURL_DEFAULT_PATH = "$Env:SystemRoot\System32\curl.exe"
$CURL_ALT_PATH = "$Env:LocalAppData\Microsoft\WindowsApps\curl.exe"
$CURL_CERT_DEFAULT_DIRECTORY = "$Env:USERPROFILE\Documents\cURL-CA-CERT\"

function Get-CurlDownloadInfo {
    try {
        (Invoke-WebRequest -Uri $CURL_FOR_WINDOWS_PAGE -ErrorAction Stop).Links.Href |
        Where-Object {$_ -like "dl-*/curl-*-win64-mingw.zip"} |
        Select-Object -Property @{
            Name = 'Version';
            Expression = {if ($_ -match '(?<Version>\d+\.\d+\.\d+(_\d+)?)') {$Matches.Version}}
        },@{
            Name = 'Link';
            Expression = {"$CURL_FOR_WINDOWS_PAGE$_"}
        } -Unique
    }
    catch {}
}

function Compare-CurlDownloadInfo ($Version) {
    !(Test-Path -Path "$Version")
}

function Save-Curl ($LocalName, $Link) {
    try {
        Start-BitsTransfer -Source $Link -Destination "$LocalName.zip" -ErrorAction Stop
        Expand-Archive -Path "$LocalName.zip" -DestinationPath $LocalName
        $GetSetup = {
            param ($SetupFile)
            (Get-ChildItem -Path $LocalName -Recurse -Filter $SetupFile -File).FullName
        }
        [PSCustomObject] @{
            ExePath = & $GetSetup $CURL_EXECUTABLE_NAME;
            CrtPath = & $GetSetup $CURL_CERTIFICATE_NAME
        }
    }
    catch {}
}

function Update-Curl ($SetupPath) {
    if (Test-Path -Path $CURL_DEFAULT_PATH) {
        Get-Acl -Path $CURL_DEFAULT_PATH |
        ForEach-Object {
            Copy-Item -Path $CURL_DEFAULT_PATH -Destination '.\curl-old.exe' -Force
            Set-Acl -Path $SetupPath -AclObject $_
            $_.SetOwner($NT_ACCOUNT_ADMINISTRATORS)
            $_.SetAccessRule($ACCESS_RULE)
            Set-Acl -Path $CURL_DEFAULT_PATH -AclObject $_
            Copy-Item -Path $SetupPath -Destination $CURL_DEFAULT_PATH -Force
        }
    } else {
        Copy-Item -Path $SetupPath -Destination $CURL_ALT_PATH -Force
    }
}

function Update-CurlCertificate ($CertPath) {
    New-Item -ItemType 'Directory' -Path $CURL_CERT_DEFAULT_DIRECTORY 2> $null
    Copy-Item -Path $CertPath -Destination $CURL_CERT_DEFAULT_DIRECTORY -Force
    [System.Environment]::SetEnvironmentVariable('CURL_CA_BUNDLE', $CURL_CERT_DEFAULT_DIRECTORY, 'Machine')
}