# Save as Open-Ports-Test-UDP.ps1 and run in Admin PowerShell
# This script opens UDP listeners on user-specified ports for testing

# Prompt user for port input
$portInput = Read-Host "Enter port(s) to open (e.g. 80-85 or 80,85)"

# Parse input into an integer array
$ports = @()

if ($portInput -match '^\d+-\d+$') {
    # Range format (e.g. 80-85)
    $split = $portInput -split '-'
    $startPort = [int]$split[0]
    $endPort   = [int]$split[1]

    if ($endPort -lt $startPort) {
        Write-Error "End port must be greater than or equal to start port."
        exit
    }

    $ports = $startPort..$endPort
}
elseif ($portInput -match '^\d+(,\d+)*$') {
    # Comma-separated format (e.g. 80,85,8080)
    $ports = $portInput -split ',' | ForEach-Object { [int]$_ }
}
elseif ($portInput -match '^\d+$') {
    # Single port
    $ports = @([int]$portInput)
}
else {
    Write-Error "Invalid format. Use range (80-85) or list (80,85,8080)."
    exit
}

# Remove duplicates and invalid ports
$ports = $ports | Where-Object { $_ -gt 0 -and $_ -lt 65536 } | Sort-Object -Unique
if (-not $ports) {
    Write-Error "No valid ports to open."
    exit
}

# Start UDP listeners (each listener runs in its own background job)
$listeners = @()
foreach ($p in $ports) {
    try {
        # Quick bind test on main thread to check port availability
        $testClient = $null
        try {
            $testClient = [System.Net.Sockets.UdpClient]::new($p)
            $testClient.Close()
        } catch {
            throw $_
        }

        # Start a background job that creates a UdpClient bound to the port and receives packets
        Start-Job -ScriptBlock {
            param($port)
            try {
                $udp = [System.Net.Sockets.UdpClient]::new($port)
            } catch {
                Write-Output "Failed to bind UDP on port $port inside job: $($_.Exception.Message)"
                return
            }

            Write-Output "Listening (UDP) on port $port"
            while ($true) {
                try {
                    $remoteEP = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any,0)
                    $bytes = $udp.Receive([ref]$remoteEP)   # Blocking until a datagram arrives
                    $remote = $remoteEP.ToString()
                    $len = 0
                    if ($bytes -ne $null) { $len = $bytes.Length }
                    Write-Output "UDP packet on port $port from $remote - $len bytes"
                } catch {
                    # If Receive fails (e.g., socket closed), exit the loop
                    break
                }
            }
            try { $udp.Close() } catch {}
        } -ArgumentList $p | Out-Null

        Write-Host "Listening on UDP port $p"
        $listeners += $p
    }
    catch {
        Write-Warning "Failed to listen on port $p — $($_.Exception.Message)"
    }
}

if ($listeners.Count -gt 0) {
    Write-Host "✅ Started UDP listeners on: $($listeners -join ', '). Press Ctrl+C to stop."
} else {
    Write-Warning "⚠️  No UDP listeners started. Check permissions or port conflicts."
}

# Keep script alive
while ($true) { Start-Sleep -Seconds 3600 }
