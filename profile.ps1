$CURL_FOR_WINDOWS_PAGE = 'https://curl.se/windows/'
$CURL_EXECUTABLE_NAME = 'curl.exe'
$CURL_CERTIFICATE_NAME = 'curl-ca-bundle.crt'

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

$Curl | Format-List