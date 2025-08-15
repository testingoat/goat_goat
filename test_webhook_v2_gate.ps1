# Test webhook v2 gating and dry-run functionality
$webhookApiKey = "dev-webhook-api-key-2024-secure-odoo-integration"
$baseUrl = "https://oaynfzqjielnsipttzbs.supabase.co/functions/v1"

# Test 1: v1 payload should be rejected
Write-Host "Test 1: v1 payload rejection (FORCE_V2_WEBHOOKS=true)"
$headers = @{
    'x-api-key' = $webhookApiKey
    'Content-Type' = 'application/json'
}
$v1Payload = @{
    product_data = @{
        name = "Test Product v1"
        seller_id = "test-seller"
        seller_uid = "test-uuid"
    }
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Method Post -Uri "$baseUrl/product-sync-webhook" -Headers $headers -Body $v1Payload -ErrorAction Stop
    Write-Host "UNEXPECTED: v1 payload was accepted: $($response | ConvertTo-Json)"
} catch {
    if ($_.Exception.Response.StatusCode -eq 400) {
        Write-Host "EXPECTED: v1 payload rejected with 400"
        Write-Host "   Error: $($_.ErrorDetails.Message)"
    } else {
        Write-Host "UNEXPECTED STATUS: $($_.Exception.Response.StatusCode)"
        Write-Host "   Error: $($_.ErrorDetails.Message)"
    }
}

# Test 2: v2 payload with dry-run should show state:'pending'
Write-Host "`nTest 2: v2 payload dry-run (should show state:'pending')"
$v2Payload = @{
    payload_version = "v2"
    product_data = @{
        name = "Test Product v2"
        seller_id = "test-seller"
        seller_uid = "test-uuid"
        list_price = 100
        meat_type = "chicken"
        description = "Test description"
        default_code = "TEST_001"
    }
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Method Post -Uri "$baseUrl/product-sync-webhook?dryRun=true" -Headers $headers -Body $v2Payload -ErrorAction Stop
    Write-Host "v2 dry-run successful: $($response | ConvertTo-Json)"
    if ($response.dryRun -eq $true) {
        Write-Host "Dry-run flag confirmed"
    }
} catch {
    Write-Host "v2 dry-run failed: $($_.Exception.Message)"
    Write-Host "   Error: $($_.ErrorDetails.Message)"
}

# Test 3: Check feature flag was upserted
Write-Host "`nTest 3: Verify feature flag upserted"
$serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9heW5menFqaWVsbnNpcHR0emJzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0OTkwNTc0NSwiZXhwIjoyMDY1NDgxNzQ1fQ.cauifa8jXJt4rCA53sTNRjsJttvktdl8ZjesHegrW4k"
$flagHeaders = @{
    'apikey' = $serviceRoleKey
    'Authorization' = "Bearer $serviceRoleKey"
    'Content-Type' = 'application/json'
}

try {
    $flagResponse = Invoke-RestMethod -Method Get -Uri "https://oaynfzqjielnsipttzbs.supabase.co/rest/v1/feature_flags?feature_name=eq.auto_sync_status_on_open" -Headers $flagHeaders -ErrorAction Stop
    if ($flagResponse.Count -gt 0 -and $flagResponse[0].enabled -eq $true) {
        Write-Host "Feature flag 'auto_sync_status_on_open' is enabled"
    } else {
        Write-Host "Feature flag not found or not enabled"
    }
} catch {
    Write-Host "Feature flag check failed: $($_.Exception.Message)"
}

Write-Host "`nTest Summary Complete"
