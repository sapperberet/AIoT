$ErrorActionPreference = 'Stop'

function Invoke-WithRetry {
  param(
    [scriptblock]$Action,
    [string]$Label,
    [int]$Retries = 4,
    [int]$DelaySec = 2
  )
  for($i=1; $i -le $Retries; $i++) {
    try {
      return & $Action
    } catch {
      Write-Output ("$Label TRY_$i FAIL " + $_.Exception.Message)
      if($i -eq $Retries) { throw }
      Start-Sleep -Seconds $DelaySec
    }
  }
}

$base = 'http://192.168.1.2:5678/run/scenarios'
$ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$name = "E2E Scenario $ts"

$health = Invoke-WithRetry -Label 'HEALTH' -Action { Invoke-WebRequest -Method Get -Uri 'http://192.168.1.2:5678/healthz' -TimeoutSec 20 }
Write-Output ("HEALTH_STATUS " + $health.StatusCode)

$before = Invoke-WithRetry -Label 'GET_BEFORE' -Action { (Invoke-WebRequest -Method Get -Uri "$base/get" -TimeoutSec 25).Content | ConvertFrom-Json }
Write-Output ("GET_BEFORE_COUNT " + @($before).Count)

$createBody = @{ 
  name = $name
  trigger = @{ type='sensor'; sensor='gas'; condition='greater_than'; value=450 }
  actions = @(
    @{ device='buzzer'; action='on' },
    @{ delay=1; unit='seconds' },
    @{ device='fan'; action='out' }
  )
} | ConvertTo-Json -Depth 12

$createdId = $null
$create = Invoke-WithRetry -Label 'CREATE' -Action { Invoke-WebRequest -Method Post -Uri "$base/create" -ContentType 'application/json' -Body $createBody -TimeoutSec 30 }
Write-Output ("CREATE_STATUS " + $create.StatusCode)
Write-Output ("CREATE_RAW " + $create.Content)
if($create.Content) {
  try {
    $createdId = ($create.Content | ConvertFrom-Json).id
  } catch {}
}

Start-Sleep -Seconds 1
$afterCreate = Invoke-WithRetry -Label 'GET_AFTER_CREATE' -Action { (Invoke-WebRequest -Method Get -Uri "$base/get" -TimeoutSec 25).Content | ConvertFrom-Json }
$found = @($afterCreate | Where-Object { $_.name -eq $name })
Write-Output ("GET_AFTER_CREATE_COUNT " + @($afterCreate).Count)
Write-Output ("FOUND_AFTER_CREATE " + $found.Count)
if(-not $createdId -and $found.Count -gt 0) { $createdId = $found[0].id }
if($createdId) { Write-Output ("CREATED_ID " + $createdId) }

if($createdId) {
  $updateBody = @{ 
    name = $name
    trigger = @{ type='sensor'; sensor='gas'; condition='greater_than'; value=500 }
    actions = @(
      @{ device='buzzer'; action='on' },
      @{ device='fan'; action='off' }
    )
  } | ConvertTo-Json -Depth 12

  $update = Invoke-WithRetry -Label 'UPDATE' -Action { Invoke-WebRequest -Method Post -Uri "$base/update?id=$createdId" -ContentType 'application/json' -Body $updateBody -TimeoutSec 30 }
  Write-Output ("UPDATE_STATUS " + $update.StatusCode)
  Write-Output ("UPDATE_RAW " + $update.Content)

  $t0 = Invoke-WithRetry -Label 'TOGGLE_FALSE' -Action { Invoke-WebRequest -Method Post -Uri "$base/toggle?id=$createdId" -ContentType 'application/json' -Body '{"active":false}' -TimeoutSec 25 }
  Write-Output ("TOGGLE_FALSE_STATUS " + $t0.StatusCode)
  Write-Output ("TOGGLE_FALSE_RAW " + $t0.Content)

  $t1 = Invoke-WithRetry -Label 'TOGGLE_TRUE' -Action { Invoke-WebRequest -Method Post -Uri "$base/toggle?id=$createdId" -ContentType 'application/json' -Body '{"active":true}' -TimeoutSec 25 }
  Write-Output ("TOGGLE_TRUE_STATUS " + $t1.StatusCode)
  Write-Output ("TOGGLE_TRUE_RAW " + $t1.Content)

  $del = Invoke-WithRetry -Label 'DELETE' -Action { Invoke-WebRequest -Method Delete -Uri "$base/delete?id=$createdId" -TimeoutSec 25 }
  Write-Output ("DELETE_STATUS " + $del.StatusCode)
  Write-Output ("DELETE_RAW " + $del.Content)
}

Start-Sleep -Milliseconds 700
$afterDelete = Invoke-WithRetry -Label 'GET_FINAL' -Action { (Invoke-WebRequest -Method Get -Uri "$base/get" -TimeoutSec 25).Content | ConvertFrom-Json }
$left = @($afterDelete | Where-Object { $_.name -eq $name }).Count
Write-Output ("GET_FINAL_COUNT " + @($afterDelete).Count)
Write-Output ("LEFTOVER_BY_NAME " + $left)
