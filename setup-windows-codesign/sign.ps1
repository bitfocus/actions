# Signs a Windows binary with the Bitfocus code signing key in Google Cloud KMS.
# The setup-windows-codesign action must have run first, and BF_CODESIGN_ACCESS_TOKEN must be set.
#
# Usage: sign.ps1 <file> -Description "<product name>"
param(
	[Parameter(Mandatory = $true, Position = 0)]
	[string]$Path,

	[Parameter(Mandatory = $true)]
	[string]$Description,

	[string]$Url = 'https://bitfocus.io'
)

$ErrorActionPreference = 'Stop'

foreach ($Name in 'BF_CODESIGN_JAVA', 'BF_CODESIGN_JSIGN_JAR', 'BF_CODESIGN_CERT_FILE', 'BF_CODESIGN_KMS_KEYRING', 'BF_CODESIGN_KMS_KEY', 'BF_CODESIGN_ACCESS_TOKEN') {
	if (-not [Environment]::GetEnvironmentVariable($Name)) { throw "$Name variable is not set" }
}
if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "File to sign does not exist: $Path" }

& $env:BF_CODESIGN_JAVA -jar $env:BF_CODESIGN_JSIGN_JAR `
	--storetype GOOGLECLOUD `
	--keystore $env:BF_CODESIGN_KMS_KEYRING `
	--storepass env:BF_CODESIGN_ACCESS_TOKEN `
	--alias $env:BF_CODESIGN_KMS_KEY `
	--certfile $env:BF_CODESIGN_CERT_FILE `
	--alg SHA-256 `
	--tsmode RFC3161 `
	--tsaurl 'http://timestamp.digicert.com,http://timestamp.sectigo.com' `
	--name $Description `
	--url $Url `
	$Path
if ($LASTEXITCODE -ne 0) { throw "jsign failed with exit code $LASTEXITCODE" }

$Signature = Get-AuthenticodeSignature -LiteralPath $Path
if ($Signature.Status -ne 'Valid') {
	throw "Signature of $Path is not valid: $($Signature.Status) $($Signature.StatusMessage)"
}
Write-Host "Signed $Path as $($Signature.SignerCertificate.Subject)"
