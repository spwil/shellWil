# Script de compilación para unir los módulos de ShellSW.bat
$targetFile = Join-Path $PSScriptRoot "ShellSW.bat"
$wrapperFile = Join-Path $PSScriptRoot "wrapper_template.bat"
$srcFolder = Join-Path $PSScriptRoot "src"

Write-Host "Iniciando ensamblado de ShellSW.bat..." -ForegroundColor Cyan

# 1. Leer el archivo wrapper
if (-not (Test-Path $wrapperFile)) {
    Write-Error "Error: No se encontró $wrapperFile"
    exit 1
}
$content = [System.IO.File]::ReadAllText($wrapperFile, [System.Text.Encoding]::UTF8)

# 2. Definir el orden de los módulos
$modules = @(
    "helpers.ps1",
    "subMenu20.ps1",
    "subMenu21.ps1",
    "subMenu22.ps1",
    "subMenu23.ps1",
    "subMenu24.ps1",
    "subMenu25.ps1",
    "subMenu26.ps1",
    "subMenu27.ps1",
    "subMenu28.ps1",
    "menuPrincipal.ps1"
)

# 3. Concatenar cada módulo
foreach ($module in $modules) {
    $modulePath = Join-Path $srcFolder $module
    if (Test-Path $modulePath) {
        Write-Host " > Agregando: $module" -ForegroundColor Gray
        $moduleContent = [System.IO.File]::ReadAllText($modulePath, [System.Text.Encoding]::UTF8)
        
        # Asegurar separación por nueva línea
        if (-not $content.EndsWith("`r`n") -and -not $content.EndsWith("`n")) {
            $content += "`r`n"
        }
        $content += $moduleContent
    }
    else {
        Write-Error "Error: No se encontró el módulo $modulePath"
        exit 1
    }
}

# 4. Agregar la llamada de ejecución final para el menú
if (-not $content.EndsWith("`r`n") -and -not $content.EndsWith("`n")) {
    $content += "`r`n"
}
$content += "`r`n# Ejecutar el MENU PRINCIPAL`r`nmenuPrincipal`r`n"

# 5. Escribir el archivo compilado en formato UTF-8 sin BOM (evita error '´╗┐' en CMD)
# Resolvemos la ruta de destino absoluta
$absoluteTarget = [System.IO.Path]::GetFullPath($targetFile)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($absoluteTarget, $content, $utf8NoBom)

Write-Host "Compilacion EXITOSA. Archivo generado: $targetFile`n" -ForegroundColor Green
