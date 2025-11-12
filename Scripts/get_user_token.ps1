# ================== Inputs (Skillable tokens) ==================
$clientId             = "@lab.CloudSubscription.AppId"
$clientSecret         = "@lab.CloudSubscription.AppSecret"
$tenantId             = "@lab.CloudSubscription.TenantId"
$subscriptionId       = "@lab.CloudSubscription.Id"
$resourceGroupName    = "@lab.CloudResourceGroup(ResourceGroup1).Name"
$aadUserPrincipalName = "@lab.CloudPortalCredential(User1).Username"
$aadUserPassword      = "@lab.CloudPortalCredential(User1).Password"

Write-Output "Starting Device Code Flow for PostgreSQL authentication..."
Write-Output ""

# Initiate device code flow
# Note: Using a well-known public client ID for Azure CLI which has permissions for ossrdbms
$publicClientId = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"  # Azure CLI public client
$deviceCodeUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/devicecode"
$deviceCodeBody = @{
    client_id = $publicClientId
    scope     = 'https://ossrdbms-aad.database.windows.net/.default offline_access'
}

Write-Output "Note: Using Azure CLI public client for authentication"
Write-Output ""

$deviceCodeResponse = Invoke-RestMethod -Method POST -Uri $deviceCodeUrl -Body $deviceCodeBody -ContentType 'application/x-www-form-urlencoded'

Write-Output "=================================================="
Write-Output $deviceCodeResponse.message
Write-Output "=================================================="
Write-Output ""
Write-Output "Waiting for authentication..."

# Poll for token
$tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
$interval = if ($deviceCodeResponse.interval) { $deviceCodeResponse.interval } else { 5 }
$deviceCode = $deviceCodeResponse.device_code
$expiresIn = $deviceCodeResponse.expires_in

$tokenBody = @{
    client_id   = $publicClientId
    grant_type  = 'urn:ietf:params:oauth:grant-type:device_code'
    device_code = $deviceCode
}

$startTime = Get-Date
$tokenAcquired = $false

while (-not $tokenAcquired -and ((Get-Date) - $startTime).TotalSeconds -lt $expiresIn) {
    Start-Sleep -Seconds $interval
    
    try {
        $tokenResponse = Invoke-RestMethod -Method POST -Uri $tokenUrl -Body $tokenBody -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
        $tokenAcquired = $true
        
        Write-Output ""
        Write-Output "Authentication successful!"
        Write-Output ""
        Write-Output "PostgreSQL Access Token:"
        Write-Output $tokenResponse.access_token
        Write-Output ""
        Write-Output "Token expires in: $($tokenResponse.expires_in) seconds"
        Write-Output ""
        Write-Output "Copy this token and use it as AZURE_PG_PASSWORD in your .env file"
        Write-Output ""
        Write-Output "Username for .env: User1-56409352@LODSPRODMCA.onmicrosoft.com"
        
    } catch {
        # Try to get the error details from the response
        $errorDetail = $null
        $errorMessage = $_.Exception.Message
        
        if ($_.Exception.Response) {
            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $errorText = $reader.ReadToEnd()
                $reader.Close()
                
                if ($errorText) {
                    $errorDetail = $errorText | ConvertFrom-Json
                }
            } catch {
                # Ignore parse errors
            }
        }
        
        if ($errorDetail -and $errorDetail.error) {
            if ($errorDetail.error -eq 'authorization_pending') {
                # Still waiting for user to authenticate - this is normal
                Write-Host "." -NoNewline
                continue
            } elseif ($errorDetail.error -eq 'slow_down') {
                # Server asking us to slow down
                $interval += 5
                continue
            } else {
                # Real error
                Write-Output ""
                Write-Output "Authentication Error: $($errorDetail.error)"
                Write-Output "Description: $($errorDetail.error_description)"
                exit 1
            }
        } else {
            # Unknown error, but don't exit - might be transient
            Write-Host "?" -NoNewline
        }
    }
}

if (-not $tokenAcquired) {
    Write-Output ""
    Write-Output "Authentication timed out. Please try again."
    exit 1
}