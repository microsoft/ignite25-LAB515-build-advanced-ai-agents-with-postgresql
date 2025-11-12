# Define log file path
$logDir = 'C:\Lab\Logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir ("lab-log_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))

# Simple helper function for logging
function Write-Log {
  param([string]$Message)
  $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  "$timestamp $Message" | Out-File -FilePath $logFile -Append -Encoding UTF8
}

Write-Log "==== Script start ===="

# ================== Inputs (Skillable tokens) ==================
$clientId       = "@lab.CloudSubscription.AppId"
$clientSecret   = "@lab.CloudSubscription.AppSecret"
$tenantId       = "@lab.CloudSubscription.TenantId"
$subscriptionId = "@lab.CloudSubscription.Id"
$rgName         = "@lab.CloudResourceGroup(ResourceGroup1).Name"

Write-Log "ClientId: $clientId"
Write-Log "ClientSecret: $clientSecret"
Write-Log "TenantId: $tenantId"
Write-Log "SubscriptionId: $subscriptionId"
Write-Log "ResourceGroup: $rgName"

# Your Bicep file
$bicepPath      = "C:\Lab\infra2\deploy.bicep"
# Where to write compiled JSON
$templateJson   = [System.IO.Path]::ChangeExtension($bicepPath, ".json")

# Optional parameters to your template (example: restore=false)
$tplParams      = @{ restore = $false }

# ================== Fast, deterministic environment ==================
$ErrorActionPreference = 'Stop'
$env:AZURE_CONFIG_DIR = "C:\Temp\.azure"
New-Item -ItemType Directory -Force $env:AZURE_CONFIG_DIR | Out-Null
netsh winhttp reset proxy | Out-Null
Remove-Item Env:HTTPS_PROXY, Env:HTTP_PROXY, Env:ALL_PROXY, Env:NO_PROXY -ErrorAction SilentlyContinue
$env:NO_PROXY="*"
[System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ================== Get ARM token via OAuth2 client credentials ==================
$ct = 'application/x-www-form-urlencoded'
$tokMgmt = Invoke-RestMethod -Method POST `
  -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
  -ContentType $ct -Body @{
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = 'https://management.azure.com/.default'
    grant_type    = 'client_credentials'
  }

$armHeaders = @{
  Authorization = "Bearer $($tokMgmt.access_token)"
  "Content-Type" = "application/json"
}

# ================== Purge deleted OpenAI accounts ==================
Write-Log "Checking for deleted OpenAI accounts to purge"

try {
  # List all deleted Cognitive Services accounts in the subscription
  $listDeletedUri = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.CognitiveServices/deletedAccounts`?api-version=2023-05-01"
  
  Write-Log "Querying deleted accounts: $listDeletedUri"
  
  $deletedAccountsResponse = Invoke-RestMethod -Method GET -Uri $listDeletedUri -Headers $armHeaders
  
  Write-Log "API Response: $($deletedAccountsResponse | ConvertTo-Json -Depth 5)"
  
  # Filter for OpenAI accounts only
  $openAIAccounts = @()
  if ($deletedAccountsResponse.value) {
    $openAIAccounts = @($deletedAccountsResponse.value | Where-Object { 
      $_.kind -eq 'OpenAI'
    })
  }
  
  Write-Log "Filtered OpenAI accounts count: $($openAIAccounts.Count)"
  
  if ($openAIAccounts -and $openAIAccounts.Count -gt 0) {
    Write-Log "Found $($openAIAccounts.Count) deleted OpenAI account(s) to purge"
    
    foreach ($account in $openAIAccounts) {
      # Extract account name and location from the resource ID or properties
      $accountName = if ($account.name) { $account.name } else { ($account.id -split '/')[-1] }
      $location = if ($account.location) { $account.location } else { $account.properties.location }
      
      Write-Log "Purging deleted OpenAI account: $accountName in location: $location"
      
      # Purge the deleted account using the correct URI format
      $purgeUri = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.CognitiveServices/locations/$location/resourceGroups/$rgName/deletedAccounts/$accountName`?api-version=2023-05-01"
      
      Write-Log "Purge URI: $purgeUri"
      
      try {
        Invoke-RestMethod -Method DELETE -Uri $purgeUri -Headers $armHeaders | Out-Null
        Write-Log "Successfully purged: $accountName"
      } catch {
        # Try alternative URI format without resource group
        $altPurgeUri = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.CognitiveServices/locations/$location/deletedAccounts/$accountName`?api-version=2023-05-01"
        Write-Log "Trying alternative purge URI: $altPurgeUri"
        
        try {
          Invoke-RestMethod -Method DELETE -Uri $altPurgeUri -Headers $armHeaders | Out-Null
          Write-Log "Successfully purged using alternative URI: $accountName"
        } catch {
          Write-Log "Warning: Could not purge $accountName - $($_.Exception.Message)"
        }
      }
    }
    
    # Wait for purge operations to complete
    Write-Log "Waiting 15 seconds for purge operations to complete..."
    Start-Sleep -Seconds 15
  } else {
    Write-Log "No deleted OpenAI accounts found to purge"
  }
} catch {
  # Log the full error for diagnostics
  Write-Log "Warning: Error checking for deleted accounts - $($_.Exception.Message)"
  if ($_.Exception.Response) {
    try {
      $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
      $responseBody = $reader.ReadToEnd()
      Write-Log "Error response body: $responseBody"
    } catch {
      Write-Log "Could not read error response"
    }
  }
}

# ================== Compile Bicep -> JSON (no auth required) ==================
function Compile-Bicep {
  param([string] $BicepPath, [string] $OutJson)

  Write-Log "Compiling Bicep file: $BicepPath"
  
  if (Get-Command bicep -ErrorAction SilentlyContinue) {
    Write-Log "Using standalone bicep CLI"
    $bicepOutput = & bicep build $BicepPath --outfile $OutJson 2>&1
    if ($LASTEXITCODE -ne 0) {
      Write-Log "Bicep compilation failed: $bicepOutput"
      throw "Bicep compilation failed: $bicepOutput"
    }
    Write-Log "Bicep compilation successful"
    return
  }

  if (Get-Command az -ErrorAction SilentlyContinue) {
    Write-Log "Using az bicep CLI"
    
    # Set environment variables to control az behavior
    $env:AZURE_BICEP_USE_BINARY_FROM_PATH = "false"
    $env:AZURE_CORE_ONLY_SHOW_ERRORS = "true"
    
    # Create temp directory if it doesn't exist
    if (-not (Test-Path "C:\Temp")) {
      New-Item -ItemType Directory -Path "C:\Temp" -Force | Out-Null
    }
    
    # Use Start-Process to capture output without stderr interfering
    $azProcess = Start-Process -FilePath "az" `
      -ArgumentList "bicep","build","--file",$BicepPath,"--outfile",$OutJson,"--only-show-errors" `
      -NoNewWindow -PassThru -Wait `
      -RedirectStandardOutput "C:\Temp\bicep_stdout.txt" `
      -RedirectStandardError "C:\Temp\bicep_stderr.txt"
    
    $exitCode = $azProcess.ExitCode
    
    # Read output files
    $stdOutContent = if (Test-Path "C:\Temp\bicep_stdout.txt") { Get-Content "C:\Temp\bicep_stdout.txt" -Raw } else { "" }
    $stdErrContent = if (Test-Path "C:\Temp\bicep_stderr.txt") { Get-Content "C:\Temp\bicep_stderr.txt" -Raw } else { "" }
    
    # Log any output for diagnostics (but don't fail on warnings)
    if ($stdOutContent -and $stdOutContent.Trim()) {
      Write-Log "Bicep stdout: $stdOutContent"
    }
    if ($stdErrContent -and $stdErrContent.Trim()) {
      Write-Log "Bicep stderr: $stdErrContent"
    }
    
    # Cleanup temp files
    Remove-Item "C:\Temp\bicep_stdout.txt" -ErrorAction SilentlyContinue
    Remove-Item "C:\Temp\bicep_stderr.txt" -ErrorAction SilentlyContinue
    
    # Check if compilation actually succeeded by verifying output file exists
    if (Test-Path $OutJson) {
      Write-Log "Az bicep compilation successful (output file created)"
      return
    }
    
    # If output file doesn't exist and we have an error, fail
    if ($exitCode -ne 0) {
      Write-Log "Az bicep compilation failed with exit code: $exitCode"
      throw "Az bicep compilation failed with exit code: $exitCode"
    }
    
    # Edge case: exit code 0 but no output file
    throw "Az bicep compilation did not produce output file: $OutJson"
  }

  throw "Neither 'bicep' nor 'az bicep' is available. Install the Bicep CLI or Azure CLI."
}

try {
  Compile-Bicep -BicepPath $bicepPath -OutJson $templateJson
  
  # Verify the file was created and is valid JSON
  if (-not (Test-Path $templateJson)) {
    throw "Compiled template file not found at: $templateJson"
  }
  
  # Load the compiled template as a PowerShell object (so we can embed it in the request body)
  $templateObject = Get-Content -Raw -Path $templateJson | ConvertFrom-Json
  
  if (-not $templateObject) {
    throw "Failed to parse compiled template JSON"
  }
  
  Write-Log "Template loaded successfully"
} catch {
  Write-Log "Error during Bicep compilation or template loading: $_"
  throw
}

# Convert simple hashtable params into ARM 'parameters' shape: name:{ value: ... }
$armParamObj = @{}
foreach ($k in $tplParams.Keys) { $armParamObj[$k] = @{ value = $tplParams[$k] } }

# ================== Submit deployment via ARM REST ==================
$deploymentName = "lab-" + (Get-Date -Format "yyyyMMdd-HHmmss")
$deployUri = "https://management.azure.com/subscriptions/$subscriptionId/resourcegroups/$rgName/providers/Microsoft.Resources/deployments/$deploymentName`?api-version=2021-04-01"

Write-Log "Deployment URI: $deployUri"

$deployBody = @{
  properties = @{
    mode       = "Incremental"
    template   = $templateObject
    parameters = $armParamObj
  }
} | ConvertTo-Json -Depth 100

Write-Log "Starting deployment: $deploymentName"

try {
  # Start/Upsert deployment (ARM is async; we'll poll below)
  $start = Invoke-RestMethod -Method PUT -Uri $deployUri -Headers $armHeaders -Body $deployBody
  Write-Log "Deployment initiated successfully. Provisioning state: $($start.properties.provisioningState)"
  
  # ================== Poll deployment status ==================
  $maxWaitMinutes = 30
  $pollIntervalSeconds = 15
  $maxPolls = ($maxWaitMinutes * 60) / $pollIntervalSeconds
  $pollCount = 0
  
  Write-Log "Polling deployment status (max wait: $maxWaitMinutes minutes)"
  
  do {
    Start-Sleep -Seconds $pollIntervalSeconds
    $pollCount++
    
    $status = Invoke-RestMethod -Method GET -Uri $deployUri -Headers $armHeaders
    $provisioningState = $status.properties.provisioningState
    
    Write-Log "Poll $pollCount : Provisioning state = $provisioningState"
    
    if ($provisioningState -eq "Succeeded") {
      Write-Log "==== Deployment succeeded ===="
      Write-Log "Outputs: $($status.properties.outputs | ConvertTo-Json -Depth 10)"
      Write-Host "Deployment completed successfully!" -ForegroundColor Green
      break
    }
    
    if ($provisioningState -eq "Failed" -or $provisioningState -eq "Canceled") {
      Write-Log "==== Deployment failed ===="
      Write-Log "Error details: $($status.properties.error | ConvertTo-Json -Depth 10)"
      throw "Deployment failed with state: $provisioningState"
    }
    
    if ($pollCount -ge $maxPolls) {
      Write-Log "==== Deployment timeout ===="
      throw "Deployment timed out after $maxWaitMinutes minutes"
    }
    
  } while ($provisioningState -in @("Running", "Accepted", "Creating", "Updating"))
  
} catch {
  Write-Log "Error during deployment: $_"
  Write-Log "Error details: $($_.Exception.Message)"
  if ($_.Exception.Response) {
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    $responseBody = $reader.ReadToEnd()
    Write-Log "Response body: $responseBody"
  }
  throw
}

Write-Log "==== Script end ===="