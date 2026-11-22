param(
  [string]$Arquivo = (Join-Path $PSScriptRoot '..\.env')
)

# Carrega KEY=VALUE do .env na sessao PowerShell atual. Uso:
#   . .\tool\carregar-env.ps1
# Nao imprime valores. Linhas vazias e chaves sem valor sao ignoradas.

if (-not (Test-Path -LiteralPath $Arquivo)) {
  Write-Warning "Arquivo .env nao encontrado: $Arquivo"
  return
}

$carregadas = 0
foreach ($linha in Get-Content -LiteralPath $Arquivo) {
  $texto = $linha.Trim()
  if ($texto -eq '' -or $texto.StartsWith('#')) { continue }

  $separador = $texto.IndexOf('=')
  if ($separador -lt 1) { continue }

  $nome = $texto.Substring(0, $separador).Trim()
  if ($nome -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { continue }

  $valor = $texto.Substring($separador + 1).Trim()
  if ($valor.Length -ge 2) {
    $primeiro = $valor.Substring(0, 1)
    $ultimo = $valor.Substring($valor.Length - 1, 1)
    if (($primeiro -eq '"' -and $ultimo -eq '"') -or
        ($primeiro -eq "'" -and $ultimo -eq "'")) {
      $valor = $valor.Substring(1, $valor.Length - 2)
    }
  }
  if ($valor -eq '') { continue }

  Set-Item -Path "Env:$nome" -Value $valor
  $carregadas++
}

Write-Host "Variaveis carregadas do .env: $carregadas"
