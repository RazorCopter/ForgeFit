$PortainerURL = "https://docker.ghome.it"
$Username     = "admin"
$Password     = "gianvitobleve"

# 1. Login
$authBody = @{ Username = $Username; Password = $Password } | ConvertTo-Json
$authResponse = Invoke-RestMethod -Uri "$PortainerURL/api/auth" -Method Post -Body $authBody -ContentType "application/json"
$jwt = $authResponse.jwt
$headers = @{ "Authorization" = "Bearer $jwt" }

# 2. Get Containers
$containers = Invoke-RestMethod -Uri "$PortainerURL/api/endpoints/2/docker/containers/json" -Method Get -Headers $headers
$backendContainer = $containers | Where-Object { $_.Names -contains "/fitforge-backend-1" -or $_.Names -contains "/fitforge-api-1" -or $_.Names -match "backend" }

if ($backendContainer) {
    $containerId = $backendContainer[0].Id
    Write-Host "Found backend container: $containerId"
    # 3. Get Logs
    $logUrl = "$PortainerURL/api/endpoints/2/docker/containers/$containerId/logs?stdout=1&stderr=1&timestamps=0&tail=100"
    $logs = Invoke-RestMethod -Uri $logUrl -Method Get -Headers $headers
    Write-Host "--- LOGS ---"
    Write-Host $logs
} else {
    Write-Host "Backend container not found"
}
