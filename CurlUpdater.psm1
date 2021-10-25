$CURL_FOR_WINDOWS_PAGE = 'https://curl.se/windows/'
$CURL_EXECUTABLE_NAME = 'curl.exe'
$CURL_CERTIFICATE_NAME = 'curl-ca-bundle.crt'
$LIBCURL_DLL_NAME = 'Libcurl-x64.dll'
$LIBCURL_DEF_NAME = 'Libcurl-x64.def'
$NT_ACCOUNT_ADMINISTRATORS = [System.Security.Principal.NTAccount] "BUILTIN\Administrators"
$NT_ACCOUNT_TRUSTEDINSTALLER = [System.Security.Principal.NTAccount] "NT SERVICE\TrustedInstaller"
$ACCESS_RULE = [System.Security.AccessControl.FileSystemAccessRule]::new('BUILTIN\Administrators','FullControl','Allow')
$RESTRICTED_ACCESS_RULE = [System.Security.AccessControl.FileSystemAccessRule]::new('BUILTIN\Administrators','ReadAndExecute','Allow')
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
        Expand-Archive -Path "$LocalName.zip" -DestinationPath $LocalName -ErrorAction Stop -Force
        Remove-Item -Path "$LocalName.zip" -Force
        $GetSetup = {
            param ($SetupFile)
            (Get-ChildItem -Path $LocalName -Recurse -Filter $SetupFile -File).FullName
        }
        [PSCustomObject] @{
            ExePath = & $GetSetup $CURL_EXECUTABLE_NAME;
            CrtPath = & $GetSetup $CURL_CERTIFICATE_NAME;
            LibPath = ((& $GetSetup $LIBCURL_DLL_NAME),(& $GetSetup $LIBCURL_DEF_NAME))
        }
    }
    catch {}
}

function Update-CurlExecutable ($SetupPath) {
    if (Test-Path -Path $CURL_DEFAULT_PATH) {
        Get-Acl -Path $CURL_DEFAULT_PATH |
        ForEach-Object {
            Copy-Item -Path $CURL_DEFAULT_PATH -Destination '.\curl-old.exe' -Force
            $_.SetOwner($NT_ACCOUNT_ADMINISTRATORS)
            $_.SetAccessRule($ACCESS_RULE)
            Set-Acl -Path $CURL_DEFAULT_PATH -AclObject $_
            try {
                Copy-Item -Path $SetupPath -Destination $CURL_DEFAULT_PATH -ErrorAction Stop -Force
                $_.SetOwner($NT_ACCOUNT_TRUSTEDINSTALLER)
                $_.SetAccessRule($RESTRICTED_ACCESS_RULE)
                Set-Acl -Path $CURL_DEFAULT_PATH -AclObject $_
            }
            catch {}
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

function Update-Libcurl ($LibPath) {
    Compress-Archive -Path $LibPath -DestinationPath '.\libcurl.zip' -CompressionLevel Optimal -Force
}

function Update-Curl {
    Get-CurlDownloadInfo |
    ForEach-Object {
        if (Compare-CurlDownloadInfo -Version $_.Version) {
            $LocalName = "curl-$($_.Version)"
            Save-Curl -LocalName $LocalName -Link $_.Link |
            ForEach-Object {
                Update-CurlExecutable -SetupPath $_.ExePath
                Update-CurlCertificate -CertPath $_.CrtPath
                Update-Libcurl -LibPath $_.LibPath
            }
            New-Item -Path $_.Version -ItemType File | Out-Null
            Remove-Item -Path $LocalName -Force -Recurse
        }
    }
}

Export-ModuleMember -Function 'Update-Curl'