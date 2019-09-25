using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$zoneName = $env:DNSZone
$zoneRgName = $env:DNSZoneRgName

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."
Write-Host $Request

# Interact with query parameters or the body of the request.
$name = $Request.Query.Name
if (-not $name) {
    $name = $Request.Body.Name
}

# Interact with query parameters or the body of the request.
$address = $Request.Query.Address
if (-not $address) {
    $address = $Request.Body.Address
}

if ($name -And $address) {
    
    #Connect-AzAccount -Identity
    $RecordSet = Get-AzDnsRecordSet `
        -ResourceGroupName $zoneRgName `
        -ZoneName $zoneName `
        -Name $name `
        -RecordType A `
        -ErrorAction SilentlyContinue

    if (!$RecordSet) {
        $Records = @()
        $Records += New-AzDnsRecordConfig -IPv4Address $address
        $RecordSet = New-AzDnsRecordSet `
            -ResourceGroupName $zoneRgName `
            -ZoneName $zoneName `
            -Name $name `
            -RecordType A `
            -Ttl 5 `
            -DnsRecords $Records
        Write-Host "Create new record for $name - $address"
    }
    else {
        $skip = $False
        foreach ($rec in $RecordSet.Records) {
            if ($rec.Ipv4Address -contains $address) {
                $skip = $True
                Write-Host "Skip"
                break
            }
        }

        if (!$skip) {
            $RecordSet.Records = @()
            Add-AzDnsRecordConfig -RecordSet $RecordSet -Ipv4Address $address
            Set-AzDnsRecordSet -RecordSet $RecordSet
        }
        else {
            Write-Host "Skipped as IP Address didn't change"
        }
    }

    $status = [HttpStatusCode]::OK
    $body = $RecordSet
}
else {
    $status = [HttpStatusCode]::BadRequest
    $body = "Please pass a name and an address on the query string or in the request body."
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = $status
        Body       = $body
    })
