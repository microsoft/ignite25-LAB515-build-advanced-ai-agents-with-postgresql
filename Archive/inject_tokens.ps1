# ================== Inputs (Skillable tokens) ==================
$clientId             = "@lab.CloudSubscription.AppId"
$clientSecret         = "@lab.CloudSubscription.AppSecret"
$tenantId             = "@lab.CloudSubscription.TenantId"
$subscriptionId       = "@lab.CloudSubscription.Id"
$resourceGroupName    = "@lab.CloudResourceGroup(ResourceGroup1).Name"
$aadUserPrincipalName = "@lab.CloudPortalCredential(User1).Username"
$aadUserPassword      = "@lab.CloudPortalCredential(User1).Password"

Write-Output "Injecting Skillable tokens into target scripts..."
Write-Output ""
Write-Output "Token Values (after Skillable replacement):"
Write-Output "  Client ID: $clientId"
Write-Output "  Tenant ID: $tenantId"
Write-Output "  Subscription ID: $subscriptionId"
Write-Output "  Resource Group: $resourceGroupName"
Write-Output "  User Principal Name: $aadUserPrincipalName"
Write-Output ""

# Define the scripts to update
$targetScripts = @(
    "C:\Lab\Scripts\get_env.ps1",
    "C:\Lab\Scripts\get_user_token.ps1",
    "C:\Lab\Scripts\load_age.ps1"
)

# Create the replacement block with actual values
$replacementBlock = @"
# ================== Inputs (Skillable tokens) ==================
`$clientId             = "$clientId"
`$clientSecret         = "$clientSecret"
`$tenantId             = "$tenantId"
`$subscriptionId       = "$subscriptionId"
`$resourceGroupName    = "$resourceGroupName"
`$aadUserPrincipalName = "$aadUserPrincipalName"
`$aadUserPassword      = "$aadUserPassword"
"@

# Process each target script
foreach ($scriptPath in $targetScripts) {
    if (-not (Test-Path $scriptPath)) {
        Write-Warning "Script not found: $scriptPath"
        continue
    }
    
    $scriptName = Split-Path -Leaf $scriptPath
    Write-Output "Processing: $scriptName"
    
    # Read the entire file
    $content = Get-Content -Path $scriptPath -Raw
    
    # Define the pattern to match the token block
    # This matches from the comment line through all the variable assignments
    $pattern = '(?s)(# ================== Inputs \(Skillable tokens\) ==================\r?\n)(\$clientId\s+=\s+[^\r\n]+\r?\n\$clientSecret\s+=\s+[^\r\n]+\r?\n\$tenantId\s+=\s+[^\r\n]+\r?\n\$subscriptionId\s+=\s+[^\r\n]+\r?\n\$resourceGroupName\s+=\s+[^\r\n]+\r?\n\$aadUserPrincipalName\s+=\s+[^\r\n]+\r?\n\$aadUserPassword\s+=\s+[^\r\n]+)'
    
    # Check if the pattern exists in the file
    if ($content -match $pattern) {
        # Replace the matched block with our new values
        $newContent = $content -replace $pattern, $replacementBlock
        
        # Write the updated content back to the file
        $newContent | Out-File -FilePath $scriptPath -Encoding utf8 -NoNewline
        
        Write-Output "  Successfully injected tokens"
    } else {
        Write-Warning "  Could not find token block pattern in file"
    }
    
    Write-Output ""
}

Write-Output "Token injection complete!"
Write-Output ""
Write-Output "Updated scripts:"
foreach ($scriptPath in $targetScripts) {
    if (Test-Path $scriptPath) {
        $scriptName = Split-Path -Leaf $scriptPath
        Write-Output "  - $scriptName"
    }
}
