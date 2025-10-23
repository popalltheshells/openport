# Save as Open-Ports-Test.ps1 and run in Admin PowerShell

# Prompt user for port input
$portInput = Read-Host "Enter port(s) to open (e.g. 80-85 or 80,85)"

# Parse input
$ports = @()
if ($portInput -match '^\d+-\d+$') {
    # Range format (e.g. 80-85)
    $split = $portInput -split '-'
    $startPort = [int]$split[0]
    $endPort   = [int]$split[1]
    $ports = $startPort..$endPort
}
elseif ($portInput -match '^\d+(,\d+)+$') {
    # Comma-separated format (e.g. 80,85,8080)
    $ports = $portInput -split ',' | ForEach-Object { [int]$_ }
}
elseif ($portInput -match '^\d+$') {
    # Single port (e.g. 80)
    $ports = @([int]$portInput)
}
else {
    Write-Error "Invalid format. Use range (e.g. 80-85) or list (e.g. 80,85,8080)."
    exit
}

# Start listeners
$listeners = @()
foreach ($p in $ports) {
    try {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $p)
        $listener.Start()
        $listeners += $listener
        Write-Host "Listening on port $p"

        # Accept connections in background
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
        Write-Warning "Failed to listen on port $p : $_"
    }
}

Write-Host "Started listeners on port(s): $($ports -join ', '). Press Ctrl+C to stop."
while ($true) { Start-Sleep -Seconds 3600 }
# (Press Ctrl+C to exit; listeners stop when PowerShell exits.)
