# Define script arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("GET", "POST", "PUT", "DELETE")]
    [string]
    $Method,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Uri,

    [Parameter(Mandatory = $false)]
    [int]
    [ValidateRange(1, 9)]
    $MaxRetries = 3,

    [Parameter(Mandatory = $false)]
    [timespan]
    [ValidateRange("00:00:01", "00:05:00")]
    $RetryDelay = "00:00:30",

    [Parameter(Mandatory = $false)]
    [timespan]
    [ValidateRange("00:00:01", "00:30:00")]
    $MaxRetryDelay = "00:15:00",

    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
    [string[]]
    $Remaining
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

function Get-ExponentialBackoffSeconds {
    param (
        [int]$Attempt,
        [int]$BaseDelaySeconds,
        [int]$MaxDelaySeconds
    )
    $calculated = [int]($BaseDelaySeconds * [Math]::Pow(2, ($Attempt - 1)))
    return [int][Math]::Min($calculated, $MaxDelaySeconds)
}

# get an API token
Write-Host "Getting Synapse API Token"
$token = Get-AzAccessToken -ResourceUrl "https://dev.azuresynapse.net" -AsSecureString
$authHeader = @{
    'Content-Type'  = 'application/json'
    'Authorization' = 'Bearer ' + ($token.Token | ConvertFrom-SecureString -AsPlainText)
}

for($iteration = 0; ++$iteration -le $MaxRetries; ) {
    Write-Host "Invoking request to $($Method) $($Uri). Attempt $($iteration) of $($MaxRetries)."
    # call IWR in background - we need the raw response
    $response = Invoke-WebRequest -Method $Method -Uri $Uri -Headers $authHeader -SkipHttpErrorCheck
    Write-Debug "HTTP Response status code: $($response.StatusCode)"

    if ($response.StatusCode -lt 400 -and $response.StatusCode -ge 200) {
        Write-Debug "Successful response. StatusCode: $($response.StatusCode), Response: $($response)"
        return $response.Content | ConvertFrom-Json
    }
    if($response.StatusCode -eq 400) {
        Write-Debug "BadRequest response status code. Response: $($response)"
        try {
            $decodedResponse = $response.Content | ConvertFrom-Json
            if ($decodedResponse.message -eq "Resource cannot be updated during provisioning") {
                Write-Host "Detected provisioning state. This occurs as a transient error - applying retry."
            }
            else {
                throw "Failed to process server response. (not a well-known message in http/400 response). content: $($response.Content)"
            }
        } catch {
            throw "Failed to process server response (unexpected payload on http/400). content: $($response.Content)", $_
        }
        $waitSeconds = Get-ExponentialBackoffSeconds -Attempt $iteration -BaseDelaySeconds ([int]$RetryDelay.TotalSeconds) -MaxDelaySeconds ([int]$MaxRetryDelay.TotalSeconds)
        Write-Host "Delaying for $($waitSeconds)s before retrying."
        Start-Sleep -Seconds $waitSeconds
        continue
    }
    if($response.StatusCode -eq 403) {
        Write-Debug "Forbidden response status code. Response: $($response)"
        try {
            # check for the response code inside the payload
            # this is a known issue that temorary connection issues can occur (on new?) endpoints that are not yet "DNS integrated" and as a result the private endpoint is not utilized
            $decodedResponse = $response.Content | ConvertFrom-Json
            switch ($decodedResponse.Code) {
                "PublicNetworkAccessDenied" {
                    Write-Host "Detected PublicNetworkAccessDenied. This occurs as a transient error - applying retry. Retrying in $($RetryDelay)."
                }
                default {
                    throw "Failed to process server response. (not a well-known code in http/403 response). content: $($response.Content)"
                }
            }
        } catch {
            throw "Failed to process server response (unexpected payload on http/403). content: $($response.Content)", $_
        }
        $waitSeconds = Get-ExponentialBackoffSeconds -Attempt $iteration -BaseDelaySeconds ([int]$RetryDelay.TotalSeconds) -MaxDelaySeconds ([int]$MaxRetryDelay.TotalSeconds)
        Write-Host "Delaying for $($waitSeconds)s before retrying."
        Start-Sleep -Seconds $waitSeconds
        continue
    }
    if($response.StatusCode -eq 429) {
        if($response.Headers["Retry-After"]){
            $waitSeconds = [int]$response.Headers["Retry-After"]
        }
        else {
            # Should never be triggered as Microsoft says there will ALWAYS be a Retry-After header in a 429 error,
            # but this is here just in case the header is missing
            $waitSeconds = Get-ExponentialBackoffSeconds -Attempt $iteration -BaseDelaySeconds ([int]$RetryDelay.TotalSeconds) -MaxDelaySeconds ([int]$MaxRetryDelay.TotalSeconds)
        }
        Write-Host "Received 429 response, waiting for $($waitSeconds)s before retrying."
        Start-Sleep -Seconds $waitSeconds
        continue
    }
    if($response.StatusCode -eq 500) {
        Write-Debug "InternalServerError response status code. Response: $($response)"
        # Sometimes a transient InternalServerError is thrown during trigger start/stop which is fixed with retry
        $waitSeconds = Get-ExponentialBackoffSeconds -Attempt $iteration -BaseDelaySeconds ([int]$RetryDelay.TotalSeconds) -MaxDelaySeconds ([int]$MaxRetryDelay.TotalSeconds)
        Write-Host "Received 500 response, waiting for $($waitSeconds)s before retrying."
        Start-Sleep -Seconds $waitSeconds
        continue
    }

    # We retry only under certain conditions - not by default
    Write-Warning "HTTP request has returned a non-successful status code. StatusCode: $($response.StatusCode), Content: $($response.Content)"
    break
}

throw "Failed to perform http request within given amount of retries. Uri: $($Uri), Method: $($Method)"
