# Save as Open-Ports-Test.ps1 and run in Admin PowerShell
# This script opens TCP listeners on user-specified ports for testing

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

# Start listeners
$listeners = @()
foreach ($p in $ports) {
    try {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $p)
        $listener.Start()  # <-- will fail if port is in use or invalid
        $listeners += $listener
        Write-Host "Listening on port $p"

        # Accept connections asynchronously
        Start-Job -ScriptBlock {
            param($l, $port)
            while ($true) {
                try {
                    $client = $l.AcceptTcpClient()   # Blocking until connection
                    $remote = $client.Client.RemoteEndPoint.ToString()
                    Write-Output "Connection on port $port from $remote"
                    $client.Close()
                } catch {
                    break
                }
            }
        } -ArgumentList $listener, $p | Out-Null
    }
    catch {
        Write-Warning "Failed to listen on port $p — $($_.Exception.Message)"
    }
}

if ($listeners.Count -gt 0) {
    Write-Host "✅ Started listeners on: $($ports -join ', '). Press Ctrl+C to stop."
} else {
    Write-Warning "⚠️  No listeners started. Check permissions or port conflicts."
}

# Keep script alive
while ($true) { Start-Sleep -Seconds 3600 }
