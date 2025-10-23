# udp-listener.ps1
# connect using nc -u IP_ADDRESS PORT
# Simple UDP listener: prompts for port, prints incoming UDP messages with sender IP:port.
# Usage: .\udp-listener.ps1

# Ask user which port to listen on
[int]$port = 0
while ($port -lt 1 -or $port -gt 65535) {
    $input = Read-Host "Enter UDP listener port (1-65535)"
    if (![int]::TryParse($input, [ref]$port)) { $port = 0 }
}

# Create UdpClient and bind to all interfaces on the requested port
$udp = New-Object System.Net.Sockets.UdpClient($port)

Write-Host ""
Write-Host "Listening for UDP on port $port (all interfaces). Press Ctrl+C to stop." -ForegroundColor Cyan
Write-Host "If nothing appears, make sure firewall allows inbound UDP $port and that the other host can reach this machine."
Write-Host ""

try {
    while ($true) {
        $remoteEP = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        # This call blocks until a UDP packet arrives
        $bytes = $udp.Receive([ref]$remoteEP)
        if ($bytes -and $bytes.Length -gt 0) {
            try {
                $text = [System.Text.Encoding]::UTF8.GetString($bytes)
            } catch {
                # fallback to hex if not UTF8
                $text = ($bytes | ForEach-Object { $_.ToString("x2") }) -join ' '
            }
            $time = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Write-Host "[$time] <$($remoteEP.Address):$($remoteEP.Port)> $text"
        } else {
            Write-Host "Received empty packet from $($remoteEP.Address):$($remoteEP.Port)"
        }
    }
} finally {
    $udp.Close()
    Write-Host "Listener stopped."
}
