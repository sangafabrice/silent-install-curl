$CURL_FOR_WINDOWS_PAGE = 'https://curl.se/windows/'
$CURL_EXECUTABLE_NAME = 'curl.exe'
$CURL_CERTIFICATE_NAME = 'curl-ca-bundle.crt'
$CURL_EXE_CURRENT_DIRECTORY = "$Env:SystemRoot\System32\"
$CURL_EXE_ALT_DIRECTORY = "$Env:LocalAppData\Microsoft\WindowsApps"
$CURL_CERT_CURRENT_DIRECTORY = "$Env:USERPROFILE\Documents\cURL-CA-CERT\"
$CURL_EXE_CURRENT_PATH = "$CURL_EXE_CURRENT_DIRECTORY$CURL_EXECUTABLE_NAME"
$NT_ACCOUNT_ADMINISTRATORS = [System.Security.Principal.NTAccount] "BUILTIN\Administrators"
$ACCESS_RULE = [System.Security.AccessControl.FileSystemAccessRule]::new('BUILTIN\Administrators','FullControl','Allow')

$Curl = (Invoke-WebRequest -Uri $CURL_FOR_WINDOWS_PAGE).Links.Href |
    Where-Object {$_ -like "dl-*/curl-*-win64-mingw.zip"} |
    Select-Object -Property @{
        Name = 'Filename';
        Expression = {
            $Temp = $_ -replace '.*/'
            $Temp -replace '-win64-mingw'
        }
    },@{
        Name = 'Link';
        Expression = {"$CURL_FOR_WINDOWS_PAGE$_"}
    } -Unique |
    ForEach-Object {
        Start-BitsTransfer -Source $_.Link -Destination $_.Filename
        $Unzipped = $_.Filename -replace '\.zip'
        Expand-Archive -Path $_.Filename -DestinationPath $Unzipped
        [PSCustomObject] @{
            ExecutablePath = (Get-ChildItem -Path $Unzipped -Recurse -Filter $CURL_EXECUTABLE_NAME -File).FullName;
            CertificatePath = (Get-ChildItem -Path $Unzipped -Recurse -Filter $CURL_CERTIFICATE_NAME -File).FullName
        }
    }

if (Test-Path -Path $CURL_EXE_CURRENT_PATH) {
    Get-Acl -Path $CURL_EXE_CURRENT_PATH |
    ForEach-Object {
        Copy-Item -Path $CURL_EXE_CURRENT_PATH -Destination . -Force
        $_ | Export-Csv -Path 'curl-acl.csv' -IncludeTypeInformation
        Set-Acl -Path $Curl.ExecutablePath -AclObject $_
        $_.SetOwner($NT_ACCOUNT_ADMINISTRATORS)
        $_.SetAccessRule($ACCESS_RULE)
        Set-Acl -Path $CURL_EXE_CURRENT_PATH -AclObject $_
        Copy-Item -Path $Curl.ExecutablePath -Destination $CURL_EXE_CURRENT_DIRECTORY -Force
    }
} else {
    Copy-Item -Path $Curl.ExecutablePath -Destination $CURL_EXE_ALT_DIRECTORY -Force
}

New-Item -ItemType 'Directory' -Path $CURL_CERT_CURRENT_DIRECTORY 2> $null
Copy-Item -Path $Curl.CertificatePath -Destination $CURL_CERT_CURRENT_DIRECTORY -Force
[System.Environment]::SetEnvironmentVariable('CURL_CA_BUNDLE', $CURL_CERT_CURRENT_DIRECTORY, 'Machine')