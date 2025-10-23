# Save as Open-Ports-Test.ps1 and run in Admin PowerShell:
param(
  [int]$StartPort = 8000,
  [int]$EndPort   = 8010
)

$listeners = @()
for ($p = $StartPort; $p -le $EndPort; $p++) {
  try {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $p)
    $listener.Start()
    $listeners += $listener
    Write-Host "Listening on port $p"
    # accept in background
    Start-Job -ScriptBlock {
      param($l,$port)
      while ($true) {
        try {
          $client = $l.AcceptTcpClient()   # blocking until connection
          $remote = $client.Client.RemoteEndPoint.ToString()
          Write-Output "Connection on port $port from $remote"
          $client.Close()
        } catch {
          break
        }
      }
    } -ArgumentList $listener, $p | Out-Null
  } catch {
    Write-Warning "Failed to listen on $p : $_"
  }
}
Write-Host "Started listeners on $StartPort..$EndPort. Press Ctrl+C to stop."
while ($true) { Start-Sleep -Seconds 3600 }
# (Press Ctrl+C to exit; job/ listeners stop when PS exits.)
