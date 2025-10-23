# Save as Open-UDP-Ports-Test.ps1 and run in Admin PowerShell
# This script opens UDP listeners on user-specified ports for testing

# Prompt user for port input
$portInput = Read-Host "Enter port(s) to open (e.g. 53-60 or 53,69,161)"

# Parse input into an integer array
$ports = @()

if ($portInput -match '^\d+-\d+$') {
    # Range format (e.g. 53-60)
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
    # Comma-separated format (e.g. 53,69,161)
    $ports = $portInput -split ',' | ForEach-Object { [int]$_ }
}
elseif ($portInput -match '^\d+$') {
    # Single port
    $ports = @([int]$portInput)
}
else {
    Write-Error "Invalid format. Use range (53-60) or list (53,69,161)."
    exit
}

# Remove duplicates and invalid ports
$ports = $ports | Where-Object { $_ -gt 0 -and $_ -lt 65536 } | Sort-Object -Unique
if (-not $ports) {
    Write-Error "No valid ports to open."
    exit
}

# Start UDP listeners
$listeners = @()
foreach ($p in $ports) {
    try {
        $udpClient = New-Object System.Net.Sockets.UdpClient($p)
        $listeners += $udpClient
        Write-Host "Listening on UDP port $p"

        # Start async receiver in background
        Start-Job -ScriptBlock {
            param($port)

            $udpClient = New-Object System.Net.Sockets.UdpClient($port)
            $remoteEP = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)

            while ($true) {
                try {
                    $received = $udpClient.Receive([ref]$remoteEP)
                    $message = [System.Text.Encoding]::ASCII.GetString($received)
                    Write-Host "📨 Received on UDP port $port from $($remoteEP.Address): $message"
                } catch {
                    break
                }
            }

            $udpClient.Close()
        } -ArgumentList $p | Out-Null

    } catch {
        Write-Warning "❌ Failed to listen on UDP port $p — $($_.Exception.Message)"
    }
}

if ($listeners.Count -gt 0) {
    Write-Host "✅ UDP Listeners started on: $($ports -join ', '). Press Ctrl+C to stop."
} else {
    Write-Warning "⚠️ No UDP listeners started. Check permissions or port conflicts."
}

# Keep script alive
while ($true) { Start-Sleep -Seconds 3600 }
