$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot

# 1) Redis (mock con protocolo real) en segundo plano
Start-Process -FilePath "bin\redismock.exe" -RedirectStandardError "redis_mock.err" -NoNewWindow
Start-Sleep -Seconds 4

# 2) Leer el puerto real que asigno miniredis
$addr = (Get-Content redis_mock.err | Where-Object { $_ -match 'REDIS_ADDR=' } | Select-Object -Last 1) -replace '.*REDIS_ADDR=',''
$port = $addr.Split(':')[-1]
$env:REDIS_URL = "redis://localhost:$port"
Write-Host "Redis en puerto $port  ->  REDIS_URL=$env:REDIS_URL"

# 3) Backend apuntando a ese Redis
Start-Process -FilePath "bin\backendgo_test.exe" -RedirectStandardOutput "backend_test.log" -RedirectStandardError "backend_test.err" -NoNewWindow
Start-Sleep -Seconds 5

Write-Host "=== backend log (debe responder y haber conectado Redis) ==="
Get-Content backend_test.log
Pop-Location
