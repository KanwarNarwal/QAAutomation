# Peel CAS

$appName = "PeelCAS_Test"

If (-Not (Test-Path ($PSScriptRoot + '\Record_Id.log'))){
    Write-Host "Creating log file..." -ForegroundColor Green 
    Write-Host ""
    New-Item -ItemType file -Path ($PSScriptRoot + '\Record_Id.log')
}

$headers = @{
    'content-type' = 'application/json';
    Authorization = "Basic OTA4N2NkZDYtODNlOC00NDRlLWE5OTktMDVhZmFmNGVmMGYyOjlhNTkwMzEyLTNlZGEtNGI2MC04M2VjLWUyMGVhZTBiODRlZg==";
    accept = '*/*'
    
}

function Get-AppInfo {
    try {
    $response = Invoke-RestMethod -Method GET -Uri 'https://developer.snap.soti.net/api/v2/apps' -Headers $headers
    Return $response | where {$_.name -eq $appName}
    }
catch {
    write-Host "Unable to get App Information."
    }
}

$appInfo = Get-AppInfo
$appVersionId = $appInfo.publishedVersions[0].id
$appId = $appInfo[0].id


function Get-Records {
    param(
    [String]$appVersionId,
    [String]$appId,
    [int]$offset,
    [int]$limit
    )
    
    try {
        Invoke-RestMethod -Method GET -Uri ('https://developer.snap.soti.net/api/v2/apps/' + $appId + '/appversions/' + 
            $appVersionId + '/forms/Form1/entries?offset=' + $offset + '&limit=' + $limit) -Headers $headers
    }
    catch{
        Write-Error -Message "Cannot get anymore records." -ErrorAction Stop
    }

}

function Get-URL {
    param(
        [String]$assetId,
        [String]$id
        )
    
    $body = ('{"assetIds": [' + '"' + $assetId + '"' +'],"ttl": 0 }')

    try { 
        $assetInfo = Invoke-RestMethod -Method POST -Uri ('https://developer.snap.soti.net/api/v2/assetsInfo') -Headers $headers -Body $body
    }
    catch {
      Write-Host "An error occurred: Unable to get Asset Info"
      Write-Host $_
    }

    if(-Not (Test-Path -Path ($PSScriptRoot + "\" + $id))){ # If directory does not exist, create one
        New-Item -Path $PSScriptRoot -Name $id -ItemType "directory"
    }

    $destination = ($PSScriptRoot + "\" + $id + "\" + $assetId + ".jpg")
    Invoke-WebRequest $assetInfo.fileUrl -OutFile $destination
    
}

[String[]]$ids = Get-Content ($PSScriptRoot + '\Record_Id.log') | where { $_ -ne ''}

For ($j=0;$j -lt $ids.Length; $j++){
    
    $offset = 0
    $limit = 5

    DO {
    $records = Get-Records -appVersionId $appVersionId -appId $appId -offset $offset -limit $limit

    $obj = $records.result | where { $_.fieldId5.value[0].text -eq $ids[$j] } # Find the obj with specified ID

    $offset = $offset + $limit
    
    }
    while(-Not $obj) # run while it does not find the ID specified

    For ($i=0; $i -lt $obj.fieldId6.value.Length; $i++) { # For every assetId found in the obj record
        Get-URL -assetId $obj.fieldId6.value[$i].assetId -id $ids[$j] # Download the image associated to it
        }

}

