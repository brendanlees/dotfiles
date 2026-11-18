# Keep the prompt off stdout; only the secret is returned to chezmoi.
$ErrorActionPreference = 'Stop'
[Console]::Error.Write('GitHub download token (public releases, input hidden): ')
$token = $Host.UI.ReadLineAsSecureString()
[Console]::Error.WriteLine()
[Console]::Out.Write([System.Net.NetworkCredential]::new('', $token).Password)
