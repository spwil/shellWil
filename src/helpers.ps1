
<#
.SYNOPSIS
    Script de mantenimiento optimizado con correccion de sintaxis.
#>

function psLimpiarRAM {
    Write-Host "`n******* OPTIMIZACION DE RAM *******" -ForegroundColor Cyan
    
    # Definimos el codigo C# como una cadena simple para evitar el error de 'Atributo inesperado'
    $codigoC = "
        using System;
        using System.Runtime.InteropServices;
        public class RamUtil {
            [DllImport(`"psapi.dll`")]
            public static extern bool EmptyWorkingSet(IntPtr hProcess);
        }
    "

    # Cargamos el tipo solo si no existe
    if (-not ([System.Management.Automation.PSTypeName]"RamUtil").Type) {
        Add-Type -TypeDefinition $codigoC -ErrorAction SilentlyContinue
    }

    try {
        $procesos = [System.Diagnostics.Process]::GetProcesses()
        foreach ($p in $procesos) {
            if ($p.Id -gt 4) {
                # Omitimos Idle y System
                try {
                    [RamUtil]::EmptyWorkingSet($p.Handle) | Out-Null
                }
                catch {}
            }
            if ($p) { $p.Dispose() }
        }
        Write-Host "RAM optimizada correctamente." -ForegroundColor Green
    }
    catch {
        Write-Host "Error al optimizar." -ForegroundColor Red
    }
}

function Write-Header {
    param([string]$texto)
    
    $ancho = $texto.Length + 15
    $linea = "=" * $ancho
    Write-Host "`n$linea" -ForegroundColor Yellow
    Write-Host "| $texto |" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "$linea" -ForegroundColor Yellow
}

function menuOpcion {
    param([string]$texto)
    
    $ancho = $texto.Length + 5
    $linea = "=" * $ancho
    Write-Host "`n$linea" -ForegroundColor Yellow
    Write-Host "| $texto |" -ForegroundColor Black -BackgroundColor Yellow
    Write-Host "$linea" -ForegroundColor Yellow
}

#****************************************************** CABECERA ******************************************************************
function cabecera {

    Clear-Host
    $Host.UI.RawUI.WindowTitle = "Bienvenido: $env:COMPUTERNAME\$env:USERNAME ;; Copyright  spWil Derechos Reservados ;; Version 1.8.0"
    $os = Get-WmiObject Win32_OperatingSystem
    $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $fecha = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

    # Datos de ejecucion
    Write-Host " SO: $($os.Caption) ; Version S.O.: $($os.Version)"  -ForegroundColor Cyan
    Write-Host " Usuario: $user  ;  Fecha:   $fecha"  -ForegroundColor Cyan
    Write-Host " Ing. Wilson Yucra - Soft. Administracion y Gestion del Sistema Operativo" -ForegroundColor Cyan
    Write-Host " ------------------------------------------------------------------------"  -ForegroundColor Cyan
}
#************************************************** FIN CABECERA ******************************************************************

function Get-ShellWorkspacePath {
    <#
    .SYNOPSIS
        Resuelve de forma portable y dinamica la ruta raiz de trabajo del proyecto ShellSW/shellWil,
        soportando ejecucion como script suelto, modulo de src/, binario Polyglot .bat o Google Drive.
    #>
    if ($env:SCRIPT_PATH -and (Test-Path $env:SCRIPT_PATH)) {
        return (Split-Path $env:SCRIPT_PATH)
    }
    if ($PSScriptRoot) {
        if (Test-Path (Join-Path $PSScriptRoot "ShellSW.bat")) { return $PSScriptRoot }
        if (Test-Path (Join-Path $PSScriptRoot "build.ps1")) { return $PSScriptRoot }
        $parent = Split-Path $PSScriptRoot -ErrorAction SilentlyContinue
        if ($parent -and ((Test-Path (Join-Path $parent "ShellSW.bat")) -or (Test-Path (Join-Path $parent "build.ps1")))) {
            return $parent
        }
        return $PSScriptRoot
    }
    $loc = (Get-Location).Path
    if (Test-Path (Join-Path $loc "ShellSW.bat")) { return $loc }
    return $loc
}

function Get-ShellLogsPath {
    <#
    .SYNOPSIS
        Devuelve y asegura la existencia de la carpeta portable de logs dentro del proyecto.
        Fallback a %ProgramData%\ShellSW\logs o %TEMP%\ShellSW_Logs si la unidad no permite escritura.
    #>
    $ws = Get-ShellWorkspacePath
    $candidate = Join-Path $ws "logs"
    if (-not (Test-Path $candidate)) {
        try {
            New-Item -ItemType Directory -Path $candidate -Force -ErrorAction SilentlyContinue | Out-Null
        } catch {}
    }
    if (Test-Path $candidate) {
        return $candidate
    }
    
    # Fallback seguro con permisos de escritura
    $altLogs = Join-Path $env:ProgramData "ShellSW\logs"
    if (-not (Test-Path $altLogs)) {
        try { New-Item -ItemType Directory -Path $altLogs -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
    }
    if (Test-Path $altLogs) { return $altLogs }
    
    $tempLogs = Join-Path $env:TEMP "ShellSW_Logs"
    if (-not (Test-Path $tempLogs)) {
        try { New-Item -ItemType Directory -Path $tempLogs -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
    }
    return $tempLogs
}

function Get-PsExecPath {
    <#
    .SYNOPSIS
        Busca y retorna de forma dinamica la ruta absoluta al ejecutable PsExec.exe,
        verificando C:\PSTools, la raiz del proyecto, System32 o el PATH del sistema.
    #>
    $workspace = Get-ShellWorkspacePath
    $candidatePaths = @(
        "C:\PSTools\PsExec.exe",
        "C:\PSTools\psexec.exe",
        "C:\PSTools\PsExec64.exe",
        (Join-Path $workspace "PSTools\PsExec.exe"),
        (Join-Path $workspace "PSTools\psexec.exe"),
        "C:\Windows\System32\PsExec.exe",
        "C:\Windows\System32\psexec.exe"
    )

    foreach ($p in $candidatePaths) {
        if (-not [string]::IsNullOrWhiteSpace($p) -and (Test-Path -LiteralPath $p)) {
            return $p
        }
    }

    $cmd = Get-Command psexec.exe -ErrorAction SilentlyContinue
    if (-not $cmd) {
        $cmd = Get-Command psexec -ErrorAction SilentlyContinue
    }
    if ($cmd) {
        return $cmd.Definition
    }

    return ""
}

function psReconstruirSiDesarrollo {
    $parentDir = if ($env:SCRIPT_PATH) { 
        Split-Path $env:SCRIPT_PATH 
    } elseif ($PSScriptRoot) { 
        if (Test-Path (Join-Path $PSScriptRoot "build.ps1")) { $PSScriptRoot } else { Split-Path $PSScriptRoot }
    } else { 
        (Get-Location).Path 
    }

    if ($parentDir) {
        $buildScript = Join-Path $parentDir "build.ps1"
        if (Test-Path $buildScript) {
            Write-Host "`n[DEV] Entorno de desarrollo detectado." -ForegroundColor Yellow
            Write-Host "[DEV] Ejecutando build.ps1 para actualizar ShellSW.bat..." -ForegroundColor Yellow
            try {
                # Iniciar la reconstrucciÃ³n de forma sÃ­ncrona
                $p = Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$buildScript`"" -NoNewWindow -PassThru -Wait
                if ($p.ExitCode -eq 0) {
                    Write-Host "[DEV] Reconstruccion completa y exitosa." -ForegroundColor Green
                }
                else {
                    Write-Host "[DEV] Error en la reconstruccion (Codigo de salida: $($p.ExitCode))." -ForegroundColor Red
                }
            }
            catch {
                Write-Host "[DEV] Fallo al ejecutar el script de ensamblado: $_" -ForegroundColor Red
            }
        }
    }
}

# ==============================================================================
# FUNCIONES DE GESTION GIT MULTI-PC (OPCIONES 1010 Y 1011)
# ==============================================================================

function Get-GitDevContext {
    <#
    .SYNOPSIS
        Valida si el directorio actual es un entorno de desarrollo con Git configurado,
        normaliza safe.directory y retorna un objeto de contexto de Git.
    #>
    $repoPath = Get-ShellWorkspacePath
    if (-not (Test-Path (Join-Path $repoPath ".git")) -and (Test-Path (Join-Path (Split-Path $repoPath -ErrorAction SilentlyContinue) ".git"))) {
        $repoPath = Split-Path $repoPath
    }

    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCmd -or -not (Test-Path (Join-Path $repoPath ".git"))) {
        return $null
    }

    # Normalizar ruta para safe.directory en Windows
    $repoNormalized = ($repoPath -replace '\\', '/')
    $safeDirs = git config --global --get-all safe.directory 2>$null
    if ($safeDirs -notcontains $repoNormalized -and $safeDirs -notcontains "*") {
        git config --global --add safe.directory "$repoNormalized" 2>$null
    }

    Push-Location $repoPath
    try {
        $remoteUrl = git remote get-url origin 2>$null
        $activeBranch = git branch --show-current 2>$null
        if ([string]::IsNullOrEmpty($activeBranch)) {
            $activeBranch = "main"
        }

        return [PSCustomObject]@{
            RepoPath     = $repoPath
            RemoteUrl    = $remoteUrl
            ActiveBranch = $activeBranch
            IsAuthorized = ($remoteUrl -like "*spwil/shellWil*")
        }
    }
    finally {
        Pop-Location
    }
}

function Clear-GitLockFiles {
    <#
    .SYNOPSIS
        Detecta y ofrece liberar archivos *.lock generados por procesos interrumpidos o sincronizacion de Google Drive.
    #>
    param([string]$repoPath)
    if (-not (Test-Path (Join-Path $repoPath ".git"))) { return $true }

    $lockFiles = Get-ChildItem -Path (Join-Path $repoPath ".git") -Filter "*.lock" -Recurse -ErrorAction SilentlyContinue
    if ($lockFiles -and $lockFiles.Count -gt 0) {
        Write-Host "`n[AVISO] Se detectaron archivos de bloqueo en .git (*.lock):" -ForegroundColor Yellow
        $lockFiles | ForEach-Object { Write-Host "  - $($_.FullName)" -ForegroundColor DarkYellow }
        Write-Host "Esto suele ocurrir si Google Drive esta sincronizando o un proceso previo se interrumpio." -ForegroundColor Yellow
        $eliminar = Read-Host "Â¿Desea liberar los bloqueos automaticamente para continuar? (S/N) [S]"
        if ($eliminar -notmatch "^[nN]$") {
            $lockFiles | ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
            Write-Host "[OK] Archivos de bloqueo eliminados." -ForegroundColor Green
            return $true
        } else {
            Write-Host "[!] Operacion cancelada por archivos de bloqueo." -ForegroundColor Red
            return $false
        }
    }
    return $true
}

function Invoke-GitPublicar1010 {
    <#
    .SYNOPSIS
        Opcion 1010: Auto-compila, crea commit y sube cambios a GitHub.
        Mejora: Si GitHub rechaza la subida por cambios remotos previos, ofrece integrarlos (rebase) y reintentar.
    #>
    param([switch]$SkipHeader)

    if (-not $SkipHeader) {
        menuOpcion "MODO DESARROLLADOR: PUBLICAR EN GITHUB (Opcion 1010)"
    }

    $ctx = Get-GitDevContext
    if (-not $ctx -or -not $ctx.IsAuthorized) {
        Write-Host "`n[INFO] Esta opcion solo esta disponible en el entorno de desarrollo autorizado." -ForegroundColor Yellow
        Write-Host "No se detecto la carpeta local de Git o el repositorio origin correcto." -ForegroundColor Gray
        Write-Host ""
        return
    }

    $repoPath = $ctx.RepoPath
    $activeBranch = $ctx.ActiveBranch

    # 1. Auto-compilacion automatica
    Write-Host "`n[*] Iniciando auto-compilacion del script unificado (build.ps1)..." -ForegroundColor Cyan
    psReconstruirSiDesarrollo

    Push-Location $repoPath
    try {
        # 2. Archivos de bloqueo
        if (-not (Clear-GitLockFiles -repoPath $repoPath)) { return }

        # 3. Asegurar identidad de autor
        $cUser = git config user.name
        $cMail = git config user.email
        if (-not $cUser -or -not $cMail) {
            git config user.name "Wilson Yucra Juan"
            git config user.email "wyucra@gmsantacruz.gov.bo"
        }

        # 4. Mostrar resumen de cambios
        Write-Host "`n[*] Resumen de archivos modificados para subir:" -ForegroundColor Yellow
        $gitStatus = git status -s
        if ([string]::IsNullOrEmpty($gitStatus)) {
            Write-Host "No hay cambios pendientes de confirmacion en el repositorio." -ForegroundColor Green
            return
        }
        Write-Host $gitStatus -ForegroundColor Gray
        Write-Host ""

        # 5. Solicitar descripcion del commit
        $desc = Read-Host "Ingrese la descripcion para el commit (Mensaje de Git)"
        if ([string]::IsNullOrEmpty($desc)) {
            Write-Host "`n[!] Operacion cancelada: El mensaje de commit no puede estar vacio." -ForegroundColor Red
            return
        }

        # 6. Confirmacion de seguridad
        $confirmar = Read-Host "Â¿Proceder con la actualizacion en GitHub? (S/N) [N]"
        if ($confirmar -notmatch "^[sS]$") {
            Write-Host "`n[!] Operacion cancelada por el usuario." -ForegroundColor Yellow
            return
        }

        # 7. Ejecucion de Git Commit
        Write-Host "`n[*] Agregando archivos al area de preparacion (git add -A)..." -ForegroundColor Gray
        git add -A

        Write-Host "[*] Confirmando cambios localmente (git commit)..." -ForegroundColor Gray
        $commitResult = git commit -m "$desc" 2>&1
        Write-Host $commitResult -ForegroundColor Gray

        # 8. Subida a GitHub con deteccion inteligente de rechazo
        Write-Host "[*] Subiendo cambios a GitHub en la rama '$activeBranch' (git push)..." -ForegroundColor Yellow
        $pushResult = git push origin $activeBranch 2>&1
        Write-Host $pushResult -ForegroundColor Gray

        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n[OK] Â¡Repositorio de GitHub actualizado exitosamente en la rama '$activeBranch'!" -ForegroundColor Green
            Write-Host "[TIP] Para continuar en la otra PC, ejecuta la Opcion 1011 al iniciar." -ForegroundColor Cyan
        }
        else {
            # Verificar si el rechazo fue por falta de descarga previa (non-fast-forward / fetch first)
            $esRechazoPrevio = ($pushResult -like "*[rejected]*") -or 
                               ($pushResult -like "*fetch first*") -or 
                               ($pushResult -like "*non-fast-forward*") -or 
                               ($pushResult -like "*contains work that you do*not have locally*")

            if ($esRechazoPrevio) {
                Write-Host "`n[AVISO] GitHub rechazo la subida: La otra PC subio cambios que aun no tienes en este equipo." -ForegroundColor Yellow
                $integrar = Read-Host "Â¿Deseas descargar e integrar los cambios de GitHub (git pull --rebase) y reintentar la subida? (S/N) [S]"
                if ($integrar -notmatch "^[nN]$") {
                    Write-Host "`n[*] Integrando cambios remotos con git pull --rebase origin $activeBranch..." -ForegroundColor Cyan
                    $rebaseResult = git pull --rebase origin $activeBranch 2>&1
                    Write-Host $rebaseResult -ForegroundColor Gray
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "[*] Reintentando subida a GitHub (git push)..." -ForegroundColor Yellow
                        $retryPush = git push origin $activeBranch 2>&1
                        Write-Host $retryPush -ForegroundColor Gray
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "`n[OK] Â¡Cambios integrados y subidos exitosamente a GitHub!" -ForegroundColor Green
                            Write-Host "[TIP] Para continuar en la otra PC, ejecuta la Opcion 1011 al iniciar." -ForegroundColor Cyan
                            psReconstruirSiDesarrollo
                        } else {
                            Write-Host "`n[ERROR] Fallo al subir tras integrar: $retryPush" -ForegroundColor Red
                        }
                    } else {
                        Write-Host "`n[ERROR] Hay conflictos entre los cambios locales y remotos." -ForegroundColor Red
                        Write-Host "Solucion: Resuelva los conflictos o use 'git rebase --abort'." -ForegroundColor Yellow
                    }
                }
            }
            elseif ($pushResult -like "*Authentication failed*" -or $pushResult -like "*Permission to*denied*" -or $pushResult -like "*fatal: could not read Username*") {
                Write-Host "`n[SUGERENCIA DE ACCESO]: No se detectaron credenciales validas de GitHub en este equipo." -ForegroundColor Yellow
                Write-Host " 1. Configure sus credenciales ejecutando:" -ForegroundColor Cyan
                Write-Host "    git config --global credential.helper manager" -ForegroundColor Gray
                Write-Host " 2. Realice un 'git push' manual en PowerShell para iniciar sesion interactiva en el navegador." -ForegroundColor Cyan
            }
            else {
                Write-Host "`n[ERROR] Ocurrio un problema al subir los cambios a GitHub." -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Host "`n[ERROR NO ESPERADO] Error al interactuar con Git: $_" -ForegroundColor Red
    }
    finally {
        Pop-Location
    }
    Write-Host ""
}

function Invoke-GitSincronizar1011 {
    <#
    .SYNOPSIS
        Opcion 1011: Continuar con el proyecto tras una pausa o cambio de PC.
        Descarga cambios (git pull origin <rama>), gestiona cambios locales pendientes,
        resuelve bloqueos, y auto-compila el proyecto con build.ps1.
    #>
    menuOpcion "MODO DESARROLLADOR: CONTINUAR / SINCRONIZAR PROYECTO (Opcion 1011)"

    $ctx = Get-GitDevContext
    if (-not $ctx -or -not $ctx.IsAuthorized) {
        Write-Host "`n[INFO] Esta opcion solo esta disponible en el entorno de desarrollo autorizado." -ForegroundColor Yellow
        Write-Host "No se detecto el repositorio Git local o el origin remoto correcto." -ForegroundColor Gray
        Write-Host ""
        return
    }

    $repoPath = $ctx.RepoPath
    $activeBranch = $ctx.ActiveBranch

    Push-Location $repoPath
    $stashed = $false
    try {
        # 1. Limpieza preventiva de archivos de bloqueo
        if (-not (Clear-GitLockFiles -repoPath $repoPath)) { return }

        # 2. Verificar cambios locales no confirmados
        $gitStatus = git status -s
        if (-not [string]::IsNullOrEmpty($gitStatus)) {
            Write-Host "`n[AVISO] Tienes cambios locales pendientes de guardar:" -ForegroundColor Yellow
            Write-Host $gitStatus -ForegroundColor Gray
            Write-Host "`nÂ¿Como deseas proceder antes de descargar los cambios de GitHub?" -ForegroundColor Cyan
            Write-Host "  1. Guardar y subir cambios locales primero (Opcion 1010) [Recomendado]" -ForegroundColor White
            Write-Host "  2. Guardar temporalmente en STASH, descargar cambios y re-aplicar" -ForegroundColor White
            Write-Host "  3. Descartar cambios locales (Reset) y sobrescribir con lo de GitHub" -ForegroundColor White
            Write-Host "  4. Cancelar y revisar manualmente" -ForegroundColor White

            $opcConflicto = Read-Host "`nSeleccione una opcion (1-4) [1]"
            if ([string]::IsNullOrWhiteSpace($opcConflicto) -or $opcConflicto -eq "1") {
                Write-Host "`n[*] Redirigiendo a Opcion 1010 para guardar cambios locales..." -ForegroundColor Cyan
                Invoke-GitPublicar1010 -SkipHeader
            }
            elseif ($opcConflicto -eq "2") {
                Write-Host "`n[*] Guardando cambios en Git Stash..." -ForegroundColor Cyan
                $fechaStash = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
                $stashRes = git stash push -m "AutoStash_Opcion1011_$fechaStash" 2>&1
                Write-Host $stashRes -ForegroundColor Gray
                $stashed = $true
            }
            elseif ($opcConflicto -eq "3") {
                $confirmReset = Read-Host "Â¿ESTA SEGURO de descartar TODOS los cambios locales no guardados? (S/N) [N]"
                if ($confirmReset -match "^[sS]$") {
                    Write-Host "`n[*] Descartando cambios locales..." -ForegroundColor Yellow
                    git reset --hard HEAD 2>&1 | Write-Host -ForegroundColor Gray
                    git clean -fd 2>&1 | Write-Host -ForegroundColor Gray
                } else {
                    Write-Host "`n[!] Operacion cancelada por el usuario." -ForegroundColor Yellow
                    return
                }
            }
            else {
                Write-Host "`n[!] Operacion cancelada por el usuario." -ForegroundColor Yellow
                return
            }
        }

        # 3. Descargar cambios remotos (git pull origin <rama>)
        Write-Host "`n[*] Descargando ultimos cambios de GitHub: git pull origin $activeBranch..." -ForegroundColor Cyan
        $pullOutput = git pull origin $activeBranch 2>&1
        $pullExitCode = $LASTEXITCODE

        Write-Host $pullOutput -ForegroundColor Gray

        if ($pullExitCode -eq 0) {
            if ($pullOutput -like "*Already up to date*" -or $pullOutput -like "*Ya estÃ¡ actualizado*") {
                Write-Host "`n[OK] El proyecto ya se encuentra al dia con GitHub." -ForegroundColor Green
            } else {
                Write-Host "`n[OK] Â¡Descarga e integracion exitosa desde GitHub!" -ForegroundColor Green
                Write-Host "`n[*] Ultimo(s) commit(s) incorporado(s):" -ForegroundColor Cyan
                git log -2 --oneline 2>$null | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkCyan }
            }

            # Restaurar cambios de stash si se aplico
            if ($stashed) {
                Write-Host "`n[*] Restaurando cambios temporales de Git Stash..." -ForegroundColor Cyan
                $stashPop = git stash pop 2>&1
                Write-Host $stashPop -ForegroundColor Gray
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "[AVISO] Hubo diferencias al re-aplicar Stash. Revise los archivos marcados." -ForegroundColor Yellow
                } else {
                    Write-Host "[OK] Cambios temporales restaurados sin conflicto." -ForegroundColor Green
                }
            }

            # 4. Auto-compilar el proyecto con build.ps1
            Write-Host "`n[*] Reconstruyendo ShellSW.bat con el codigo actualizado..." -ForegroundColor Cyan
            psReconstruirSiDesarrollo

            Write-Host "`n[LISTO] Â¡El proyecto esta listo para continuar el desarrollo!" -ForegroundColor Green

            # 5. Ofrecer reinicio
            $reiniciar = Read-Host "`nÂ¿Desea reiniciar ShellSW ahora para recargar los modulos actualizados? (S/N) [S]"
            if ($reiniciar -notmatch "^[nN]$") {
                $rutaScript = if ($env:SCRIPT_PATH) { $env:SCRIPT_PATH } else { Join-Path $repoPath "ShellSW.bat" }
                if (Test-Path $rutaScript) {
                    Write-Host "`nReiniciando ShellSW..." -ForegroundColor Cyan
                    Start-Process cmd.exe -ArgumentList "/c `"$rutaScript`""
                    exit
                }
            }
        }
        else {
            Write-Host "`n[ERROR] Ocurrio un problema al descargar los cambios de GitHub." -ForegroundColor Red
            if ($pullOutput -like "*conflict*" -or $pullOutput -like "*Merge conflict*") {
                Write-Host "[!] CONFLICTO DETECTADO: Hay archivos con modificaciones incompatibles entre ambas PCs." -ForegroundColor Yellow
                Write-Host "Solucion: Abra los archivos con marcas de conflicto en su editor y elija que cambios conservar." -ForegroundColor White
            }
            elseif ($pullOutput -like "*Authentication failed*" -or $pullOutput -like "*Permission to*denied*") {
                Write-Host "[!] ERROR DE AUTENTICACION: Se requieren credenciales de GitHub." -ForegroundColor Yellow
                Write-Host "Ejecute: git config --global credential.helper manager" -ForegroundColor Cyan
            }
        }
    }
    catch {
        Write-Host "`n[ERROR NO ESPERADO] Error en sincronizacion Git: $_" -ForegroundColor Red
    }
    finally {
        Pop-Location
    }
    Write-Host ""
}

function Test-IsProcessAdmin {
    <#
    .SYNOPSIS
        Verifica si el proceso actual se ejecuta con privilegios elevados de Administrador (Token Elevado / UAC).
    #>
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return [bool]$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function psHabilitarAdministracionRemota {
    param(
        [string]$targetInput,
        [string]$baseIP = "192.168.176.",
        [string]$username = $null,
        [string]$passwordText = $null
    )

    # --- HABILITACIÃ“N REMOTA DE ADMINISTRACIÃ“N ---
    if ([string]::IsNullOrEmpty($targetInput)) {
        $targetInput = Read-Host "Ingrese el ultimo octeto de la IP (192.168.176.XXX) o la IP completa / Nombre de Equipo"
    }
    
    if ($targetInput -eq "") {
        Write-Host "Operacion cancelada." -ForegroundColor Red
        return
    }

    $ipRemota = $targetInput
    if ($targetInput -notmatch "\." -and $targetInput -notmatch "^[a-zA-Z]") {
        $ipRemota = $baseIP + $targetInput
    }

    # 1. ResoluciÃ³n de Hostname
    $computerTarget = $ipRemota
    Write-Host "`n[*] Resolviendo Hostname de $ipRemota para habilitar Kerberos..." -ForegroundColor Yellow
    try {
        $entry = [System.Net.Dns]::GetHostEntry($ipRemota)
        $computerTarget = $entry.HostName.Split('.')[0]
        Write-Host "[+] Hostname resuelto: $computerTarget (Kerberos habilitado)" -ForegroundColor Green
    }
    catch {
        $nbt = nbtstat -a $ipRemota
        $lineaName = $nbt | Where-Object { $_ -match "<\x00>.*UNIQUE" } | Select-Object -First 1
        if ($lineaName -and $lineaName -match "^\s*([A-Za-z0-9\-]+)") {
            $computerTarget = $Matches[1].Trim()
            Write-Host "[+] Hostname resuelto via NetBIOS: $computerTarget" -ForegroundColor Green
        }
        else {
            Write-Host "[-] No se pudo resolver Hostname. Usando IP directamente ($ipRemota)." -ForegroundColor Yellow
        }
    }

    # 2. Verificar conectividad
    Write-Host "`n[*] Verificando enlace con $computerTarget (Ping)..." -ForegroundColor Yellow
    if (-not (Test-Connection -ComputerName $computerTarget -Count 1 -Quiet)) {
        Write-Warning "El equipo $computerTarget no responde a ping. Es posible que este apagado o tenga el firewall activo."
    }

    # 3. ConstrucciÃ³n del Bloque de Comandos de Firewall y Servicios
    $cmds = @(
        'netsh advfirewall firewall set rule group="Windows Management Instrumentation (WMI)" new enable=yes',
        'netsh advfirewall firewall set rule group="Instrumentacion de administracion de Windows (WMI)" new enable=yes',
        'netsh advfirewall firewall set rule group="Windows Remote Management" new enable=yes',
        'netsh advfirewall firewall set rule group="Administracion remota de Windows" new enable=yes',
        'netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=yes',
        'netsh advfirewall firewall set rule group="Compartir archivos e impresoras" new enable=yes',
        'netsh advfirewall firewall set rule group="Remote Administration" new enable=yes',
        'netsh advfirewall firewall set rule group="Administracion remota" new enable=yes',
        'reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f'
    )
    $cmdFirewall = $cmds -join " & "
    $cmdPS = "powershell.exe -NoProfile -Command `"try { Enable-PSRemoting -SkipNetworkProfileCheck -Force } catch {}; try { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force } catch {}`""
    $fullCommand = "cmd.exe /c $cmdFirewall & $cmdPS"

    $exito = $false

    # A. MÃ©todo 1: PsExec (Puerto SMB 445)
    $psexecPath = Get-PsExecPath
    $psexecFound = [bool]$psexecPath

    if ($psexecFound) {
        Write-Host "[*] Intentando habilitacion via PsExec (SMB puerto 445)..." -ForegroundColor Yellow
        if ($username -and $passwordText) {
            $argsList = "\\$computerTarget -u gmsantacruz\$username -p $passwordText -accepteula -s cmd.exe /c $fullCommand"
        } else {
            $argsList = "\\$computerTarget -accepteula -s cmd.exe /c $fullCommand"
        }
        $p = Start-Process -FilePath $psexecPath -ArgumentList $argsList -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
        if ($p -and $p.ExitCode -eq 0) {
            Write-Host "[OK] Habilitacion remota ejecutada exitosamente via PsExec!" -ForegroundColor Green
            $exito = $true
        }
        else {
            $code = if ($p) { $p.ExitCode } else { "N/A" }
            Write-Host "[-] PsExec no pudo completar la accion (Codigo: $code)." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "[-] PsExec.exe no detectado en C:\PSTools ni en el PATH. Omitiendo." -ForegroundColor Gray
    }

    # B. MÃ©todo 2: WinRM / PSRemoting (WS-Man 5985)
    if (-not $exito) {
        Write-Host "[*] Intentando habilitacion via WinRM (PowerShell Remoting)..." -ForegroundColor Yellow
        try {
            $icParams = @{
                ComputerName = $computerTarget
                ScriptBlock = {
                    netsh advfirewall firewall set rule group="Windows Management Instrumentation (WMI)" new enable=yes
                    netsh advfirewall firewall set rule group="Instrumentacion de administracion de Windows (WMI)" new enable=yes
                    netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=yes
                    netsh advfirewall firewall set rule group="Compartir archivos e impresoras" new enable=yes
                    netsh advfirewall firewall set rule group="Remote Administration" new enable=yes
                    netsh advfirewall firewall set rule group="Administracion remota" new enable=yes
                    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f
                }
                ErrorAction = 'Stop'
            }
            if ($username -and $passwordText) {
                $secPassword = ConvertTo-SecureString $passwordText -AsPlainText -Force
                $icParams['Credential'] = New-Object System.Management.Automation.PSCredential("gmsantacruz\$username", $secPassword)
                $icParams['Authentication'] = 'Kerberos'
            }
            Invoke-Command @icParams | Out-Null
            Write-Host "[OK] Habilitacion remota ejecutada exitosamente via WinRM!" -ForegroundColor Green
            $exito = $true
        }
        catch {
            Write-Host "[-] WinRM no esta disponible en ${computerTarget}: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # C. MÃ©todo 3: WMI (WMI 135)
    if (-not $exito) {
        Write-Host "[*] Intentando habilitacion via WMI (Win32_Process)..." -ForegroundColor Yellow
        try {
            $wmiParams = @{
                Class = 'Win32_Process'
                Name = 'Create'
                ComputerName = $computerTarget
                ArgumentList = $fullCommand
                ErrorAction = 'Stop'
            }
            if ($username -and $passwordText) {
                $secPassword = ConvertTo-SecureString $passwordText -AsPlainText -Force
                $wmiParams['Credential'] = New-Object System.Management.Automation.PSCredential("gmsantacruz\$username", $secPassword)
            }
            $result = Invoke-WmiMethod @wmiParams
            if ($result -and $result.ReturnValue -eq 0) {
                Write-Host "[OK] Comando enviado via WMI con exito!" -ForegroundColor Green
                $exito = $true
            }
            else {
                $val = if ($result) { $result.ReturnValue } else { "N/A" }
                Write-Host "[-] WMI retorno codigo de error: $val" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "[-] WMI/RPC no esta disponible en ${computerTarget}: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # 4. Reporte final
    if ($exito) {
        Write-Host "`n================================================" -ForegroundColor White
        Write-Host "   CONFIGURACION DE ADMINISTRACION HABILITADA" -ForegroundColor Green
        Write-Host "================================================" -ForegroundColor White
        Write-Host "El equipo remoto $computerTarget ahora deberia aceptar"
        Write-Host "consultas de red, WMI, ping y PSRemoting."
        Write-Host "================================================" -ForegroundColor White
    }
    else {
        Write-Host "`n================================================" -ForegroundColor White
        Write-Host "       ERROR: NO SE PUDO CONFIGURAR EL EQUIPO" -ForegroundColor Red
        Write-Host "================================================" -ForegroundColor White
        Write-Host "No se pudo conectar por WMI, WinRM ni PsExec."
        Write-Host "Asegurese de:"
        Write-Host "1. Que PsExec este en C:\PSTools\PsExec.exe"
        Write-Host "2. Que su usuario tenga privilegios de Administrador"
        Write-Host "   en el equipo remoto $computerTarget."
        Write-Host "================================================" -ForegroundColor White
    }
}

function psGestionarServiciosUpdateRemoto {
    param(
        [string]$targetInput,
        [string]$accion,
        [string]$baseIP = "192.168.176."
    )

    cabecera
    menuOpcion "ADMINISTRACION REMOTA: $accion DE SERVICIOS WINDOWS UPDATE"

    # --- ENTRADA DE DATOS ---
    if ([string]::IsNullOrEmpty($targetInput)) {
        $targetInput = Read-Host "Ingrese el ultimo octeto de la IP (192.168.176.XXX), IP completa o Nombre de Equipo"
    }
    
    if ($targetInput -eq "") {
        Write-Host "Operacion cancelada." -ForegroundColor Red
        return
    }

    $ipRemota = $targetInput
    if ($targetInput -notmatch "\." -and $targetInput -notmatch "^[a-zA-Z]") {
        $ipRemota = $baseIP + $targetInput
    }

    # 1. ResoluciÃ³n de Hostname
    $computerTarget = $ipRemota
    Write-Host "`n[*] Resolviendo Hostname de $ipRemota para la conexion..." -ForegroundColor Yellow
    try {
        $entry = [System.Net.Dns]::GetHostEntry($ipRemota)
        $computerTarget = $entry.HostName.Split('.')[0]
        Write-Host "[+] Hostname resuelto: $computerTarget" -ForegroundColor Green
    }
    catch {
        $nbt = nbtstat -a $ipRemota
        $lineaName = $nbt | Where-Object { $_ -match "<\x00>.*UNIQUE" } | Select-Object -First 1
        if ($lineaName -and $lineaName -match "^\s*([A-Za-z0-9\-]+)") {
            $computerTarget = $Matches[1].Trim()
            Write-Host "[+] Hostname resuelto via NetBIOS: $computerTarget" -ForegroundColor Green
        }
        else {
            Write-Host "[-] No se pudo resolver Hostname. Usando IP directamente ($ipRemota)." -ForegroundColor Yellow
        }
    }

    # 2. Verificar conectividad
    Write-Host "`n[*] Verificando enlace con $computerTarget (Ping)..." -ForegroundColor Yellow
    if (-not (Test-Connection -ComputerName $computerTarget -Count 1 -Quiet)) {
        Write-Warning "El equipo $computerTarget no responde a ping. Es posible que este apagado o tenga el firewall activo."
    }

    $ip = if ($ipRemota) { $ipRemota } else { $computerTarget }

    # --- ACCION: ESTADO ---
    if ($accion -eq "Estado") {
        $serviciosConsulta = @("wuauserv", "bits", "dosvc", "TrustedInstaller", "cryptsvc")
        $estadoResultados = @()
        $queryExito = $false
        
        # Intentar consultar via WMI
        Write-Host "`n[*] Consultando estado de servicios via WMI (RPC/DCOM)..." -ForegroundColor Yellow
        try {
            foreach ($serv in $serviciosConsulta) {
                $serviceWmi = Get-WmiObject -Class Win32_Service -ComputerName $ip -Filter "Name='$serv'" -ErrorAction Stop
                if ($serviceWmi) {
                    $estadoResultados += [PSCustomObject]@{
                        Servicio   = $serv
                        Nombre     = $serviceWmi.DisplayName
                        TipoInicio = $serviceWmi.StartMode
                        Estado     = $serviceWmi.State
                        Metodo     = "WMI"
                    }
                }
                else {
                    throw "Servicio no encontrado"
                }
            }
            $queryExito = $true
        }
        catch {
            Write-Host "[-] WMI no pudo consultar todos los servicios. Intentando via WinRM..." -ForegroundColor Yellow
            $estadoResultados = @() # limpiar
        }

        # Intentar consultar via WinRM
        if (-not $queryExito) {
            try {
                $remoteResults = Invoke-Command -ComputerName $computerTarget -ScriptBlock {
                    param($servs)
                    Get-Service -Name $servs | ForEach-Object {
                        [PSCustomObject]@{
                            Servicio   = $_.Name
                            Nombre     = $_.DisplayName
                            TipoInicio = $_.StartType.ToString()
                            Estado     = $_.Status.ToString()
                        }
                    }
                } -ArgumentList (, $serviciosConsulta) -ErrorAction Stop
                
                foreach ($res in $remoteResults) {
                    $estadoResultados += [PSCustomObject]@{
                        Servicio   = $res.Servicio
                        Nombre     = $res.Nombre
                        TipoInicio = $res.TipoInicio
                        Estado     = $res.Estado
                        Metodo     = "WinRM"
                    }
                }
                $queryExito = $true
            }
            catch {
                Write-Host "[-] WinRM no disponible para consulta. Intentando via PsExec..." -ForegroundColor Yellow
                $estadoResultados = @() # limpiar
            }
        }

        # Intentar consultar via PsExec
        if (-not $queryExito) {
            # Localizar PsExec
            $psexecPath = Get-PsExecPath
            $psexecFound = [bool]$psexecPath

            if ($psexecFound) {
                try {
                    foreach ($serv in $serviciosConsulta) {
                        $output = & $psexecPath \\$computerTarget -accepteula -h -s cmd.exe /c "sc query $serv & sc qc $serv" 2>$null
                        
                        $state = "Desconocido"
                        $startMode = "Desconocido"
                        
                        foreach ($line in $output) {
                            if ($line -match "STATE\s*:\s*\d+\s+([A-Z_]+)") {
                                $state = $Matches[1]
                            }
                            if ($line -match "START_TYPE\s*:\s*\d+\s+([A-Z_]+)") {
                                $startMode = $Matches[1]
                            }
                        }

                        $estadoResultados += [PSCustomObject]@{
                            Servicio   = $serv
                            Nombre     = $serv # fallback
                            TipoInicio = $startMode
                            Estado     = $state
                            Metodo     = "PsExec (sc)"
                        }
                    }
                    $queryExito = $true
                }
                catch {
                    Write-Host "[-] PsExec fallo al consultar." -ForegroundColor Red
                }
            }
        }

        # Mostrar resultados
        if ($queryExito -and $estadoResultados.Count -gt 0) {
            Write-Host "`n==========================================================================" -ForegroundColor White
            Write-Host "          ESTADO DE SERVICIOS WINDOWS UPDATE EN: $computerTarget" -ForegroundColor Green
            Write-Host "==========================================================================" -ForegroundColor White
            
            # Encabezado de la tabla
            Write-Host ("  {0,-18} {1,-18} {2,-15} {3,-15}" -f "Servicio", "Tipo de Inicio", "Estado Actual", "Metodo")
            Write-Host "  ------------------------------------------------------------------------"
            
            foreach ($res in $estadoResultados) {
                $color = if ($res.Estado -match "RUNNING|Running|RUN") { "Green" } else { "Yellow" }
                
                # Imprimir con colores para el estado
                Write-Host "  " -NoNewline
                Write-Host ("{0,-18}" -f $res.Servicio) -NoNewline
                Write-Host ("{0,-18}" -f $res.TipoInicio) -NoNewline
                Write-Host ("{0,-15}" -f $res.Estado) -ForegroundColor $color -NoNewline
                Write-Host ("{0,-15}" -f $res.Metodo)
            }
            Write-Host "==========================================================================`n" -ForegroundColor White
        }
        else {
            Write-Host "`n========================================================" -ForegroundColor Red
            Write-Host "         ERROR AL CONSULTAR EL ESTADO DE SERVICIOS" -ForegroundColor White -BackgroundColor DarkRed
            Write-Host "========================================================" -ForegroundColor Red
            Write-Host "No se pudo conectar por WMI, WinRM ni PsExec en $computerTarget."
        }
        return
    }

    # --- ACCIONES: HABILITAR / DESHABILITAR ---
    if ($accion -eq "Habilitar") {
        $serviciosConfig = @(
            @{ Name = "wuauserv"; StartMode = "Automatic"; ScStart = "auto"; Action = "Start" },
            @{ Name = "bits"; StartMode = "Manual"; ScStart = "demand"; Action = "Start" },
            @{ Name = "dosvc"; StartMode = "Manual"; ScStart = "demand"; Action = "Start" },
            @{ Name = "TrustedInstaller"; StartMode = "Manual"; ScStart = "demand"; Action = "None" },
            @{ Name = "cryptsvc"; StartMode = "Automatic"; ScStart = "auto"; Action = "Start" }
        )
    }
    else {
        $serviciosConfig = @(
            @{ Name = "wuauserv"; StartMode = "Disabled"; ScStart = "disabled"; Action = "Stop" },
            @{ Name = "bits"; StartMode = "Disabled"; ScStart = "disabled"; Action = "Stop" },
            @{ Name = "dosvc"; StartMode = "Disabled"; ScStart = "disabled"; Action = "Stop" },
            @{ Name = "TrustedInstaller"; StartMode = "Disabled"; ScStart = "disabled"; Action = "Stop" }
        )
    }

    $exito = $false

    # A. MÃ©todo 1: WMI (WMI 135) - Muy compatible sin WinRM
    Write-Host "`n[*] Intentando configurar servicios via WMI (RPC/DCOM)..." -ForegroundColor Yellow
    $wmiExito = $true
    foreach ($sConfig in $serviciosConfig) {
        $serv = $sConfig.Name
        $mode = $sConfig.StartMode
        $act = $sConfig.Action
        
        try {
            $serviceWmi = Get-WmiObject -Class Win32_Service -ComputerName $ip -Filter "Name='$serv'" -ErrorAction Stop
            if ($serviceWmi) {
                # Cambiar StartMode
                $resMode = $serviceWmi.ChangeStartMode($mode).ReturnValue
                # Cambiar Estado
                $resAct = 0
                if ($act -eq "Start") {
                    $resAct = $serviceWmi.StartService().ReturnValue
                }
                elseif ($act -eq "Stop") {
                    $resAct = $serviceWmi.StopService().ReturnValue
                }
                
                # Validar Ã©xito considerando cÃ³digos de retorno especiales en WMI:
                # ChangeStartMode: 0 = Ã‰xito. (Para dosvc a veces falla con 2 [Acceso Denegado] pero se corrige por WinRM/PsExec).
                # StartService: 0 = Ã‰xito, 10 = Ya iniciado (tambiÃ©n Ã©xito para nuestro propÃ³sito).
                # StopService: 0 = Ã‰xito, 5 = Detenido/No acepta control, 6 = No activo (tambiÃ©n Ã©xito).
                $isModeOk = ($resMode -eq 0)
                $isActOk = $false
                
                if ($act -eq "Start") {
                    $isActOk = ($resAct -eq 0 -or $resAct -eq 10)
                }
                elseif ($act -eq "Stop") {
                    $isActOk = ($resAct -eq 0 -or $resAct -eq 5 -or $resAct -eq 6)
                }
                else {
                    $isActOk = $true # AcciÃ³n "None"
                }

                if ($isModeOk -and $isActOk) {
                    Write-Host " -> Servicio ${serv}: Modo=$mode, Accion=$act [OK]" -ForegroundColor Green
                }
                else {
                    $wmiExito = $false
                    # Cambiamos a color amarillo para advertir que requiere fallback, sin asustar al usuario con un error rojo fatal
                    Write-Host " -> Servicio ${serv}: Requiere fallback (ModoRes=$resMode, ActRes=$resAct)." -ForegroundColor Yellow
                }
            }
            else {
                $wmiExito = $false
                Write-Host " -> Servicio ${serv}: No encontrado via WMI." -ForegroundColor Yellow
            }
        }
        catch {
            $wmiExito = $false
            Write-Host " -> Servicio ${serv}: Error de conexion WMI." -ForegroundColor Yellow
        }
    }

    if ($wmiExito) {
        $exito = $true
    }

    # B. MÃ©todo 2: WinRM / PSRemoting (WinRM 5985)
    if (-not $exito) {
        Write-Host "`n[*] WMI no completo todas las configuraciones de forma directa. Intentando via WinRM (PowerShell Remoting)..." -ForegroundColor Yellow
        try {
            Invoke-Command -ComputerName $computerTarget -ScriptBlock {
                param($config)
                foreach ($s in $config) {
                    $name = $s.Name
                    $mode = $s.StartMode
                    $act = $s.Action
                    
                    Set-Service -Name $name -StartupType $mode -ErrorAction SilentlyContinue
                    if ($act -eq "Start") {
                        Start-Service -Name $name -ErrorAction SilentlyContinue
                    }
                    elseif ($act -eq "Stop") {
                        Stop-Service -Name $name -Force -ErrorAction SilentlyContinue
                    }
                }
            } -ArgumentList (, $serviciosConfig) -ErrorAction Stop
            Write-Host "[OK] Servicios configurados exitosamente via WinRM!" -ForegroundColor Green
            $exito = $true
        }
        catch {
            Write-Host "[-] WinRM no esta disponible en ${computerTarget}: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # C. MÃ©todo 3: PsExec (SMB 445)
    if (-not $exito) {
        Write-Host "`n[*] WinRM no disponible. Intentando via PsExec (SMB)..." -ForegroundColor Yellow
        
        $psexecPath = Get-PsExecPath
        $psexecFound = [bool]$psexecPath

        if ($psexecFound) {
            $psExito = $true
            foreach ($sConfig in $serviciosConfig) {
                $serv = $sConfig.Name
                $scMode = $sConfig.ScStart
                $act = $sConfig.Action
                
                # Configurar StartupType
                $argsConfig = "\\$computerTarget -accepteula -s cmd.exe /c sc config $serv start= $scMode"
                $pConfig = Start-Process -FilePath $psexecPath -ArgumentList $argsConfig -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
                
                # Iniciar o detener
                $argsAct = ""
                if ($act -eq "Start") {
                    $argsAct = "\\$computerTarget -accepteula -s cmd.exe /c sc start $serv"
                }
                elseif ($act -eq "Stop") {
                    $argsAct = "\\$computerTarget -accepteula -s cmd.exe /c sc stop $serv"
                }
                
                if ($argsAct -ne "") {
                    Start-Process -FilePath $psexecPath -ArgumentList $argsAct -Wait -NoNewWindow -ErrorAction SilentlyContinue | Out-Null
                }
                
                if ($pConfig -and $pConfig.ExitCode -eq 0) {
                    Write-Host " -> Servicio $serv configurado via PsExec [OK]" -ForegroundColor Green
                }
                else {
                    $psExito = $false
                    $code = if ($pConfig) { $pConfig.ExitCode } else { "N/A" }
                    Write-Host " -> Error al configurar $serv via PsExec (Codigo: $code)." -ForegroundColor Red
                }
            }
            if ($psExito) {
                $exito = $true
            }
        }
        else {
            Write-Host "[-] PsExec.exe no detectado en C:\PSTools ni en el PATH. Omitiendo." -ForegroundColor Gray
        }
    }

    # 4. Reporte final
    if ($exito) {
        Write-Host "`n========================================================" -ForegroundColor Green
        Write-Host "   SERVICIOS WINDOWS UPDATE CONFIGURADOS CON EXITO" -ForegroundColor White -BackgroundColor DarkGreen
        Write-Host "========================================================" -ForegroundColor Green
        Write-Host "La accion de '$accion' se ejecuto correctamente."
    }
    else {
        Write-Host "`n========================================================" -ForegroundColor Red
        Write-Host "        ERROR AL CONFIGURAR LOS SERVICIOS REMOTOS" -ForegroundColor White -BackgroundColor DarkRed
        Write-Host "========================================================" -ForegroundColor Red
        Write-Host "No se pudo conectar por WMI, WinRM ni PsExec en $computerTarget."
    }
}

#**********************************************************************************************************************************
#**********************************************************************************************************************************
# MODULO: CONFIGURACION REGIONAL SIAF-SICE (.REG / SIMBOLOS MONETARIOS Y DECIMALES)
#**********************************************************************************************************************************

function psConfigurarSimbolosSiafSice {
    <#
    .SYNOPSIS
        Configura los simbolos regionales para el funcionamiento correcto de SIAF-SICE (.reg)
        en el equipo local o remoto, permitiendo seleccionar entre la sesion actual o todos los usuarios.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [hashtable]$Destino = $null
    )

    cabecera
    menuOpcion "ADMINISTRACION: CONFIGURACION DE SIMBOLOS REGIONALES SIAF-SICE"

    # 1. Resolver destino si no fue suministrado
    if (-not $Destino) {
        $rawInput = Read-Host "Ingrese la IP completa (ej: 192.168.176.50), los 2 ultimos octetos (ej: 176.50) o Nombre de Equipo"
        if ([string]::IsNullOrWhiteSpace($rawInput)) {
            Write-Host "Operacion cancelada." -ForegroundColor Yellow
            return
        }
        $rawInput = $rawInput.Trim()

        $ipRemota = ""
        $targetMachine = ""

        if ($rawInput -in @('.', 'localhost', '127.0.0.1', $env:COMPUTERNAME)) {
            $Destino = @{ IP = "127.0.0.1"; Hostname = $env:COMPUTERNAME; IsLocal = $true }
        }
        else {
            if ($rawInput -match '^(\d{1,3}\.){3}\d{1,3}$') {
                $ipRemota = $rawInput
            }
            elseif ($rawInput -match '^\d{1,3}\.\d{1,3}$') {
                $ipRemota = "192.168.$rawInput"
            }
            elseif ($rawInput -match '^\d{1,3}$') {
                $ipRemota = "192.168.176.$rawInput"
            }
            else {
                $targetMachine = $rawInput
            }

            if (-not [string]::IsNullOrWhiteSpace($ipRemota)) {
                Write-Host "Resolviendo nombre de equipo para $ipRemota..." -ForegroundColor Cyan
                try {
                    $sys = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ipRemota -ErrorAction Stop
                    $targetMachine = $sys.CSName
                    Write-Host "Nombre de equipo resuelto: $targetMachine" -ForegroundColor Green
                }
                catch {
                    try {
                        $targetMachine = [System.Net.Dns]::GetHostEntry($ipRemota).HostName
                        Write-Host "Nombre de equipo resuelto via DNS: $targetMachine" -ForegroundColor Green
                    }
                    catch {
                        $targetMachine = $ipRemota
                    }
                }
            }
            elseif (-not [string]::IsNullOrWhiteSpace($targetMachine)) {
                try {
                    $ipRemota = ([System.Net.Dns]::GetHostAddresses($targetMachine) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1).IPAddressToString
                } catch {
                    $ipRemota = $targetMachine
                }
            }

            $isLoc = ($ipRemota -in @('127.0.0.1', '::1') -or $targetMachine.ToUpper() -eq $env:COMPUTERNAME.ToUpper())
            $Destino = @{ IP = $ipRemota; Hostname = $targetMachine; IsLocal = $isLoc }
        }
    }

    $targetIP = if ($Destino.IP) { $Destino.IP } else { $Destino.Hostname }
    $targetHost = if ($Destino.Hostname) { $Destino.Hostname } else { $targetIP }
    $isLocal = [bool]$Destino.IsLocal

    # 2. Menu de seleccion de alcance
    Write-Host "`n======================================================================" -ForegroundColor Cyan
    Write-Host "           ALCANCE DE APLICACION PARA SIMBOLOS SIAF-SICE              " -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host " Equipo objetivo: $targetHost ($targetIP)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1. SESION ACTUAL: Aplicar solo al usuario activo con sesion iniciada" -ForegroundColor Green
    Write-Host "  2. TODOS LOS USUARIOS: Aplicar a todos los perfiles de la maquina" -ForegroundColor Yellow
    Write-Host "     (Sesiones activas + perfiles en disco + plantilla Default User)" -ForegroundColor Gray
    Write-Host "  0. Cancelar operacion" -ForegroundColor Red
    Write-Host "======================================================================" -ForegroundColor Cyan
    $alcance = Read-Host "Seleccione una opcion (1/2/0)"

    if ($alcance -notin @('1', '2')) {
        Write-Host "Operacion cancelada por el usuario." -ForegroundColor Yellow
        return
    }

    # Definicion centralizada del diccionario de valores SIAF-SICE para local .NET
    $siafSettings = @{
        International = @{
            "Locale"          = "0000400a"
            "LocaleName"      = "es-BO"
            "s1159"           = "a.m."
            "s2359"           = "p.m."
            "sCountry"        = "MÃ©xico"
            "sCurrency"       = "Bs."
            "sDate"           = "/"
            "sDecimal"        = "."
            "sGrouping"       = "3;0"
            "sLanguage"       = "ESM"
            "sList"           = ","
            "sLongDate"       = "dddd, dd' de 'MMMM' de 'yyyy"
            "sMonDecimalSep"  = "."
            "sMonGrouping"    = "3;0"
            "sMonThousandSep" = ","
            "sNativeDigits"   = "0123456789"
            "sNegativeSign"   = "-"
            "sPositiveSign"   = ""
            "sShortDate"      = "dd/MM/yyyy"
            "sThousand"       = ","
            "sTime"           = ":"
            "sTimeFormat"     = "HH:mm:ss"
            "sShortTime"      = "HH:mm"
            "sYearMonth"      = "MMMM' de 'yyyy"
            "iCalendarType"   = "1"
            "iCountry"        = "52"
            "iCurrDigits"     = "2"
            "iCurrency"       = "2"
            "iDate"           = "1"
            "iDigits"         = "2"
            "NumShape"        = "1"
            "iFirstDayOfWeek" = "6"
            "iFirstWeekOfYear"= "0"
            "iLZero"          = "1"
            "iMeasure"        = "0"
            "iNegCurr"        = "14"
            "iNegNumber"      = "1"
            "iPaperSize"      = "1"
            "iTime"           = "0"
            "iTimePrefix"     = "0"
            "iTLZero"         = "1"
            "HilightText"     = "0 0 0"
        }
        Geo = @{
            "Nation" = "26"
        }
        UserProfile = @{
            "ShowAutoCorrection"                  = 1
            "ShowTextPrediction"                  = 1
            "ShowCasing"                          = 1
            "ShowShiftLock"                       = 1
            "UserLocaleFromLanguageProfileOptOut" = 1
        }
        EsBo = @{
            "400A:0000080A" = 1
        }
    }

    # Helper interno para escribir las claves en un objeto RegistryKey (Local)
    $aplicarEnKey = {
        param([Microsoft.Win32.RegistryKey]$BaseKey, [string]$SubRuta)
        
        $pInt = if ($SubRuta) { "$SubRuta\Control Panel\International" } else { "Control Panel\International" }
        $pGeo = if ($SubRuta) { "$SubRuta\Control Panel\International\Geo" } else { "Control Panel\International\Geo" }
        $pUp  = if ($SubRuta) { "$SubRuta\Control Panel\International\User Profile" } else { "Control Panel\International\User Profile" }
        $pEs  = if ($SubRuta) { "$SubRuta\Control Panel\International\User Profile\es-BO" } else { "Control Panel\International\User Profile\es-BO" }

        # International
        $kInt = $BaseKey.CreateSubKey($pInt)
        if ($kInt) {
            foreach ($item in $siafSettings.International.GetEnumerator()) {
                $kInt.SetValue($item.Key, $item.Value, [Microsoft.Win32.RegistryValueKind]::String)
            }
            $kInt.Close()
        }

        # Geo
        $kGeo = $BaseKey.CreateSubKey($pGeo)
        if ($kGeo) {
            $kGeo.SetValue("Nation", "26", [Microsoft.Win32.RegistryValueKind]::String)
            $kGeo.Close()
        }

        # User Profile
        $kUp = $BaseKey.CreateSubKey($pUp)
        if ($kUp) {
            $kUp.SetValue("Languages", [string[]]@("es-BO"), [Microsoft.Win32.RegistryValueKind]::MultiString)
            foreach ($item in $siafSettings.UserProfile.GetEnumerator()) {
                $kUp.SetValue($item.Key, $item.Value, [Microsoft.Win32.RegistryValueKind]::DWord)
            }
            $kUp.Close()
        }

        # es-BO
        $kEs = $BaseKey.CreateSubKey($pEs)
        if ($kEs) {
            $kEs.SetValue("400A:0000080A", 1, [Microsoft.Win32.RegistryValueKind]::DWord)
            $kEs.Close()
        }
    }

    # Helper generador de comandos reg add para WMI / batch remoto
    $getSiafRegAddCmd = {
        param([string]$KeyRoot) # ej: "HKU\$sidActivo" o "HKLM\ShellSW_DefSiaf"
        return "reg add `"$KeyRoot\Control Panel\International`" /v sDecimal /t REG_SZ /d . /f & " +
            "reg add `"$KeyRoot\Control Panel\International`" /v sThousand /t REG_SZ /d , /f & " +
            "reg add `"$KeyRoot\Control Panel\International`" /v sMonDecimalSep /t REG_SZ /d . /f & " +
            "reg add `"$KeyRoot\Control Panel\International`" /v sMonThousandSep /t REG_SZ /d , /f & " +
            "reg add `"$KeyRoot\Control Panel\International`" /v sCurrency /t REG_SZ /d `"Bs.`" /f & " +
            "reg add `"$KeyRoot\Control Panel\International`" /v sShortDate /t REG_SZ /d `"dd/MM/yyyy`" /f & " +
            "reg add `"$KeyRoot\Control Panel\International`" /v sDate /t REG_SZ /d / /f & " +
            "reg add `"$KeyRoot\Control Panel\International`" /v sTimeFormat /t REG_SZ /d `"HH:mm:ss`" /f & " +
            "reg add `"$KeyRoot\Control Panel\International`" /v Locale /t REG_SZ /d `"0000400a`" /f & " +
            "reg add `"$KeyRoot\Control Panel\International`" /v LocaleName /t REG_SZ /d `"es-BO`" /f & " +
            "reg add `"$KeyRoot\Control Panel\International`" /v GeoID /t REG_SZ /d `"26`" /f & " +
            "reg add `"$KeyRoot\Control Panel\International\Geo`" /v Nation /t REG_SZ /d `"26`" /f & " +
            "reg add `"$KeyRoot\Control Panel\International\User Profile`" /v Languages /t REG_MULTI_SZ /d `"es-BO`" /f & " +
            "reg add `"$KeyRoot\Control Panel\International\User Profile`" /v UserLocaleFromLanguageProfileOptOut /t REG_DWORD /d 1 /f & " +
            "reg add `"$KeyRoot\Control Panel\International\User Profile\es-BO`" /v `"400A:0000080A`" /t REG_DWORD /d 1 /f"
    }

    # Helper para notificar refresco al sistema sin reiniciar
    $notificarRefresco = {
        param([string]$hostTarget, [bool]$esLoc)
        try {
            if ($esLoc) {
                $null = Start-Process -FilePath "rundll32.exe" -ArgumentList "user32.dll,UpdatePerUserSystemParameters 1, True" -NoNewWindow -Wait -ErrorAction SilentlyContinue
            } else {
                $proc = Get-WmiObject -Class Win32_Process -ComputerName $hostTarget -List -ErrorAction SilentlyContinue
                if ($proc) {
                    $null = $proc.Create("rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True")
                }
            }
        } catch {}
    }

    # =========================================================================
    # CASO 1: SESION ACTUAL
    # =========================================================================
    if ($alcance -eq '1') {
        Write-Host "`n[*] Identificando usuario con sesion interactiva en $targetHost..." -ForegroundColor Cyan
        
        $usuarioActivo = $null
        $sidActivo = $null

        if ($isLocal) {
            $usuarioActivo = "$env:USERDOMAIN\$env:USERNAME"
            $sidActivo = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        }
        else {
            try {
                $explorers = Get-WmiObject -Class Win32_Process -ComputerName $targetIP -Filter "Name='explorer.exe'" -ErrorAction Stop
                foreach ($exp in $explorers) {
                    $owner = $exp.GetOwner()
                    $ownerSid = $exp.GetOwnerSid()
                    if ($owner.ReturnValue -eq 0 -and $ownerSid.ReturnValue -eq 0) {
                        $usuarioActivo = "$($owner.Domain)\$($owner.User)"
                        $sidActivo = $ownerSid.Sid
                        break
                    }
                }
            } catch {
                Write-Host "[-] Advertencia al consultar sesion remota via WMI: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        if (-not $usuarioActivo -or -not $sidActivo) {
            Write-Host "[-] No se detecto ninguna sesion activa de usuario con 'explorer.exe' en $targetHost." -ForegroundColor Yellow
            $aplicarTodos = Read-Host "Â¿Desea aplicar los simbolos a TODOS los usuarios en su lugar? (S/N)"
            if ($aplicarTodos -match '^[sSyY]') {
                $alcance = '2'
            } else {
                Write-Host "Operacion finalizada." -ForegroundColor Gray
                return
            }
        }
        else {
            Write-Host "  -> Usuario activo detectado: $usuarioActivo (SID: $sidActivo)" -ForegroundColor Green
            $confirma = Read-Host "Â¿Esta seguro de aplicar la configuracion SIAF-SICE a la sesion de '$usuarioActivo'? (S/N)"
            if ($confirma -notmatch '^[sSyY]') {
                Write-Host "Operacion cancelada." -ForegroundColor Yellow
                return
            }

            Write-Host "`n[*] Aplicando simbolos SIAF-SICE en la colmena del usuario activo..." -ForegroundColor Cyan
            $exitoSesion = $false

            if ($isLocal) {
                # Local: Aplicar via .NET en Users y en CurrentUser directamente
                try {
                    $regUsers = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::Users, [Microsoft.Win32.RegistryView]::Default)
                    & $aplicarEnKey $regUsers $sidActivo
                    $regUsers.Close()
                    $exitoSesion = $true
                    Write-Host "  [OK] Registro actualizado en HKEY_USERS\$sidActivo." -ForegroundColor Green
                } catch {}

                try {
                    $regCu = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::CurrentUser, [Microsoft.Win32.RegistryView]::Default)
                    & $aplicarEnKey $regCu ""
                    $regCu.Close()
                    $exitoSesion = $true
                    Write-Host "  [OK] Registro actualizado directamente en HKCU." -ForegroundColor Green
                } catch {}
            }
            else {
                # Remoto: Inyeccion directa mediante WMI (sin depender del servicio Registro Remoto)
                try {
                    $procWmi = [wmiclass]"\\$targetIP\root\cimv2:Win32_Process"
                    if ($procWmi) {
                        $cmd = "cmd.exe /c " + (& $getSiafRegAddCmd "HKU\$sidActivo")
                        $res = $procWmi.Create($cmd)
                        if ($res.ReturnValue -eq 0) {
                            $exitoSesion = $true
                            Write-Host "  [OK] Inyeccion de claves completada via WMI en HKU\$sidActivo." -ForegroundColor Green
                        } else {
                            Write-Host "  [-] WMI devolvio codigo: $($res.ReturnValue)" -ForegroundColor Yellow
                        }
                    }
                } catch {
                    Write-Host "  [-] Error en ejecucion WMI: $($_.Exception.Message)" -ForegroundColor Red
                }

                # Fallback a PsExec si WMI fallo
                if (-not $exitoSesion) {
                    $psexecPath = Get-PsExecPath
                    if ($psexecPath) {
                        Write-Host "  [*] Ejecutando fallback alternativo via PsExec..." -ForegroundColor Yellow
                        $argP = "\\$targetIP -accepteula -s cmd.exe /c `"" + (& $getSiafRegAddCmd "HKU\$sidActivo") + "`""
                        $p = Start-Process -FilePath $psexecPath -ArgumentList $argP -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
                        if ($p -and $p.ExitCode -eq 0) {
                            $exitoSesion = $true
                            Write-Host "  [OK] Simbolos configurados via PsExec." -ForegroundColor Green
                        }
                    }
                }
            }

            # Notificar refresco de parametros
            & $notificarRefresco $targetHost $isLocal

            if ($exitoSesion) {
                Write-Host "`n========================================================================" -ForegroundColor Green
                Write-Host " [EXITO] CONFIGURACION SIAF-SICE APLICADA A LA SESION ACTUAL" -ForegroundColor White -BackgroundColor DarkGreen
                Write-Host "========================================================================" -ForegroundColor Green
                Write-Host " Usuario configurado: $usuarioActivo" -ForegroundColor Green
                Write-Host " Separador decimal:   . (Punto)" -ForegroundColor Cyan
                Write-Host " Separador de miles:  , (Coma)" -ForegroundColor Cyan
                Write-Host " Moneda y Formato:    Bs. | dd/MM/yyyy | es-BO" -ForegroundColor Cyan
                Write-Host "`n [!] NOTA HELPDESK: Si el usuario tenia SIAF o SICE abierto, solicitele que cierre y vuelva a abrir el programa." -ForegroundColor Yellow
            } else {
                Write-Host "`n[ERROR] No se pudo escribir en el registro del usuario activo." -ForegroundColor Red
            }
            return
        }
    }

    # =========================================================================
    # CASO 2: TODOS LOS USUARIOS (ESTRATEGIA MULTI-USUARIO POR CAPAS)
    # =========================================================================
    if ($alcance -eq '2') {
        Write-Host "`n"
        Write-Host "======================================================================" -ForegroundColor Yellow
        Write-Host "        CONFIRMACION: APLICAR A TODOS LOS USUARIOS EN $targetHost      " -ForegroundColor Yellow
        Write-Host "======================================================================" -ForegroundColor Yellow
        Write-Host " Esta accion aplicara los simbolos de SIAF-SICE a:"
        Write-Host "   1. Todas las sesiones activas cargadas en memoria (HKEY_USERS)"
        Write-Host "   2. Todos los perfiles de usuario desconectados en disco (NTUSER.DAT)"
        Write-Host "   3. La plantilla base (Default User) para cualquier usuario nuevo"
        Write-Host "   4. La cuenta del sistema (.DEFAULT / Pantalla de bienvenida)"
        Write-Host "----------------------------------------------------------------------"
        $confirmaTodos = Read-Host "Â¿Esta seguro de continuar? (S/N)"
        if ($confirmaTodos -notmatch '^[sSyY]') {
            Write-Host "Operacion cancelada por el usuario." -ForegroundColor Yellow
            return
        }

        Write-Host "`n[*] Iniciando aplicacion multi-capa de simbolos SIAF-SICE..." -ForegroundColor Cyan

        $totalSesionesActivas = 0
        $totalPerfilesDisco = 0
        $defaultConfigurado = $false

        # Inicializar handle de WMI para procesos si es remoto
        $procWmi = $null
        if (-not $isLocal) {
            try {
                $procWmi = [wmiclass]"\\$targetIP\root\cimv2:Win32_Process"
            } catch {
                Write-Host "[-] Error al conectar con WMI Win32_Process en ${targetIP}: $($_.Exception.Message)" -ForegroundColor Red
            }
        }

        # --- CAPA 1: SESIONES ACTIVAS EN MEMORIA (HKEY_USERS) ---
        Write-Host "`n[Capa 1/4] Actualizando sesiones cargadas en memoria (HKEY_USERS)..." -ForegroundColor Cyan
        
        if ($isLocal) {
            try {
                $regUsers = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::Users, [Microsoft.Win32.RegistryView]::Default)
                if ($regUsers) {
                    $subKeys = $regUsers.GetSubKeyNames()
                    foreach ($k in $subKeys) {
                        if (($k -match '^S-1-5-21-' -and $k -notmatch '_Classes$') -or $k -eq '.DEFAULT') {
                            try {
                                & $aplicarEnKey $regUsers $k
                                if ($k -ne '.DEFAULT') {
                                    $totalSesionesActivas++
                                    Write-Host "  -> Perfil activo actualizado: $k" -ForegroundColor Green
                                } else {
                                    Write-Host "  -> Cuenta del sistema .DEFAULT actualizada [OK]" -ForegroundColor Green
                                }
                            } catch {}
                        }
                    }
                    $regUsers.Close()
                }

                $regCu = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::CurrentUser, [Microsoft.Win32.RegistryView]::Default)
                & $aplicarEnKey $regCu ""
                $regCu.Close()
                Write-Host "  -> HKCU del administrador local actualizado [OK]" -ForegroundColor Green
            } catch {
                Write-Host "  [!] Advertencia en Capa 1 local: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        else {
            # Remoto: Deteccion de sesiones activas via WMI (sin depender de RemoteRegistry)
            $sidsActivos = @()

            # A. Consultar perfiles cargados en Win32_UserProfile
            try {
                $wmiLoaded = Get-WmiObject -Class Win32_UserProfile -ComputerName $targetIP -ErrorAction SilentlyContinue | 
                    Where-Object { -not $_.Special -and $_.Loaded }
                if ($wmiLoaded) {
                    $sidsActivos += ($wmiLoaded | Select-Object -ExpandProperty SID)
                }
            } catch {}

            # B. Consultar procesos interactivos explorer.exe
            try {
                $explorers = Get-WmiObject -Class Win32_Process -ComputerName $targetIP -Filter "Name='explorer.exe'" -ErrorAction SilentlyContinue
                foreach ($exp in $explorers) {
                    $osid = $exp.GetOwnerSid()
                    if ($osid -and $osid.ReturnValue -eq 0 -and $osid.Sid -match '^S-1-5-21-') {
                        $sidsActivos += $osid.Sid
                    }
                }
            } catch {}

            # C. Agregar .DEFAULT
            $listaSids = ($sidsActivos + '.DEFAULT') | Select-Object -Unique

            if ($procWmi) {
                foreach ($sid in $listaSids) {
                    try {
                        $cmd = "cmd.exe /c " + (& $getSiafRegAddCmd "HKU\$sid")
                        $res = $procWmi.Create($cmd)
                        if ($res.ReturnValue -eq 0) {
                            if ($sid -ne '.DEFAULT') {
                                $totalSesionesActivas++
                                Write-Host "  -> Perfil activo actualizado via WMI: $sid" -ForegroundColor Green
                            } else {
                                Write-Host "  -> Cuenta del sistema .DEFAULT actualizada via WMI [OK]" -ForegroundColor Green
                            }
                        } else {
                            Write-Host "  [-] Aviso al actualizar $sid (Codigo WMI: $($res.ReturnValue))." -ForegroundColor Gray
                        }
                    } catch {
                        Write-Host "  [-] Error al actualizar $sid : $($_.Exception.Message)" -ForegroundColor Gray
                    }
                }
            }
        }

        # --- CAPA 2: PERFILES DESCONECTADOS EN DISCO (C:\Users\*\NTUSER.DAT) ---
        Write-Host "`n[Capa 2/4] Verificando perfiles desconectados en disco..." -ForegroundColor Cyan
        
        $perfilesDisco = @()

        if ($isLocal) {
            try {
                $localProfiles = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue |
                    Where-Object { -not $_.Special -and -not $_.Loaded -and $_.LocalPath -notmatch '(?i)systemprofile|LocalService|NetworkService' }
                if ($localProfiles) {
                    foreach ($lp in $localProfiles) {
                        $pPath = $lp.LocalPath
                        $suf = if ($lp.SID.Length -ge 4) { $lp.SID.Substring($lp.SID.Length - 4) } else { "User" }
                        $hMount = "ShellSW_Siaf_$suf"
                        Write-Host "  -> Procesando perfil local en disco: $pPath" -ForegroundColor Gray
                        $cmdMontar = "cmd.exe /c reg load HKLM\$hMount `"$pPath\NTUSER.DAT`" & " + (& $getSiafRegAddCmd "HKLM\$hMount") + " & reg unload HKLM\$hMount"
                        $null = cmd.exe /c $cmdMontar 2>&1
                        $totalPerfilesDisco++
                        Write-Host "     [OK] Perfil local $pPath actualizado." -ForegroundColor Green
                    }
                }
            } catch {
                Write-Host "  [!] Advertencia en Capa 2 local: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        else {
            # Remoto: Consultar Win32_UserProfile para perfiles donde Loaded == $false
            try {
                $remProfiles = Get-WmiObject -Class Win32_UserProfile -ComputerName $targetIP -ErrorAction SilentlyContinue |
                    Where-Object { -not $_.Special -and -not $_.Loaded -and $_.LocalPath -notmatch '(?i)systemprofile|LocalService|NetworkService' }
                if ($remProfiles) {
                    $perfilesDisco = $remProfiles
                }
            } catch {}

            # Fallback: Si Win32_UserProfile no retorno perfiles, consultar directorios de C:\Users via WMI
            if (-not $perfilesDisco -or $perfilesDisco.Count -eq 0) {
                try {
                    $userDirs = Get-WmiObject -Class Win32_Directory -ComputerName $targetIP -Filter "Drive='C:' and Path='\\\\Users\\\\'" -ErrorAction SilentlyContinue |
                        Where-Object { $_.FileName -notmatch '(?i)^(Public|Default|All Users|Default User)$' }
                    if ($userDirs) {
                        $perfilesDisco = $userDirs | ForEach-Object {
                            [PSCustomObject]@{
                                LocalPath = $_.Name
                                SID       = "TEMP_$($_.FileName)"
                            }
                        }
                    }
                } catch {}
            }

            if ($perfilesDisco -and $procWmi) {
                foreach ($p in $perfilesDisco) {
                    $profPath = $p.LocalPath
                    $sufijo = if ($p.SID.Length -ge 4) { $p.SID.Substring($p.SID.Length - 4) } else { "User" }
                    $hiveMount = "ShellSW_Siaf_$sufijo"

                    Write-Host "  -> Procesando perfil en disco: $profPath" -ForegroundColor Gray
                    $cmdMontar = "cmd.exe /c reg load HKLM\$hiveMount `"$profPath\NTUSER.DAT`" & " + (& $getSiafRegAddCmd "HKLM\$hiveMount") + " & reg unload HKLM\$hiveMount"
                    try {
                        $res = $procWmi.Create($cmdMontar)
                        if ($res.ReturnValue -eq 0) {
                            $totalPerfilesDisco++
                            Write-Host "     [OK] Perfil en disco actualizado: $profPath" -ForegroundColor Green
                        } else {
                            Write-Host "     [-] Aviso: No se pudo montar $profPath (Codigo WMI: $($res.ReturnValue))." -ForegroundColor Gray
                        }
                    } catch {
                        Write-Host "     [-] Error al procesar ${profPath}: $($_.Exception.Message)" -ForegroundColor Gray
                    }
                }
            } else {
                Write-Host "  -> No se detectaron perfiles desconectados adicionales en disco." -ForegroundColor Gray
            }
        }

        # --- CAPA 3: PLANTILLA BASE PARA NUEVOS USUARIOS (DEFAULT USER) ---
        Write-Host "`n[Capa 3/4] Configurando plantilla base (C:\Users\Default\NTUSER.DAT)..." -ForegroundColor Cyan
        try {
            $cmdDef = "cmd.exe /c reg load HKLM\ShellSW_DefSiaf `"C:\Users\Default\NTUSER.DAT`" & " + (& $getSiafRegAddCmd "HKLM\ShellSW_DefSiaf") + " & reg unload HKLM\ShellSW_DefSiaf"

            if ($isLocal) {
                $null = cmd.exe /c $cmdDef 2>&1
                $defaultConfigurado = $true
                Write-Host "  [OK] Default User configurado localmente." -ForegroundColor Green
            } else {
                if ($procWmi) {
                    $res = $procWmi.Create($cmdDef)
                    if ($res.ReturnValue -eq 0) {
                        $defaultConfigurado = $true
                        Write-Host "  [OK] Default User configurado en equipo remoto." -ForegroundColor Green
                    }
                }
            }
        } catch {
            Write-Host "  [!] Advertencia en Capa 3 (Default User): $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # --- CAPA 4: NOTIFICACION DE CAMBIO DE PARAMETROS ---
        Write-Host "`n[Capa 4/4] Enviando seÃ±al de refresco a la interfaz grafica..." -ForegroundColor Cyan
        & $notificarRefresco $targetHost $isLocal
        Write-Host "  [OK] Notificacion de refresco emitida." -ForegroundColor Green

        # Reporte final
        Write-Host "`n========================================================================" -ForegroundColor Green
        Write-Host " [EXITO] CONFIGURACION MULTI-USUARIO SIAF-SICE COMPLETADA" -ForegroundColor White -BackgroundColor DarkGreen
        Write-Host "========================================================================" -ForegroundColor Green
        Write-Host " Equipo objetivo:               $targetHost ($targetIP)" -ForegroundColor Green
        Write-Host " Perfiles activos en memoria:   $totalSesionesActivas" -ForegroundColor Cyan
        Write-Host " Perfiles procesados en disco:  $totalPerfilesDisco" -ForegroundColor Cyan
        Write-Host " Plantilla base (Default User): $(if ($defaultConfigurado) { 'Configurada [OK]' } else { 'No modificada' })" -ForegroundColor Cyan
        Write-Host " Simbolos aplicados:            Punto decimal (.) | Coma de miles (,) | Moneda Bs. | dd/MM/yyyy" -ForegroundColor White
        Write-Host "`n [!] NOTA HELPDESK: Cualquier usuario existente o nuevo que inicie sesion en $targetHost ya tendra SIAF-SICE configurado." -ForegroundColor Yellow
    }
}

# MODULO: INFORMACION DEL USUARIO ACTIVO (LOCAL Y DE DOMINIO)
#**********************************************************************************************************************************

function psMostrarInformacionUsuarioActivo {
    <#
    .SYNOPSIS
        Consulta y muestra en consola la informaciÃ³n del usuario activo (local o de dominio)
        en un equipo remoto o local, respetando el formato visual y paleta de colores estÃ¡ndar.
    .PARAMETER TargetIP
        DirecciÃ³n IP o Nombre de Equipo (Hostname) a consultar.
    .PARAMETER Credential
        Credencial opcional para autenticaciÃ³n en WMI/CIM.
    .PARAMETER TimeoutMs
        Tiempo de espera para comprobaciÃ³n de red previa.
    .PARAMETER ForceRefresh
        Fuerza la consulta ignorando la cachÃ© en memoria de la sesiÃ³n.
    .PARAMETER ReturnObject
        Devuelve el objeto con los datos en lugar de solo imprimirlo.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$TargetIP,
        [Parameter(Mandatory=$false)]
        [pscredential]$Credential = $null,
        [Parameter(Mandatory=$false)]
        [int]$TimeoutMs = 1500,
        [Parameter(Mandatory=$false)]
        [switch]$ForceRefresh,
        [Parameter(Mandatory=$false)]
        [switch]$ReturnObject
    )

    if ([string]::IsNullOrWhiteSpace($TargetIP)) {
        return
    }

    $cleanTarget = $TargetIP.Trim()
    $cacheKey = $cleanTarget.ToUpper()

    # Inicializar almacenamiento de cachÃ© de sesiÃ³n si no existe
    if (-not $global:ActiveUserCache) {
        $global:ActiveUserCache = @{}
    }

    # Verificar si tenemos datos en cachÃ© vÃ¡lidos (vigencia de 45 segundos)
    if (-not $ForceRefresh -and $global:ActiveUserCache.ContainsKey($cacheKey)) {
        $cacheEntry = $global:ActiveUserCache[$cacheKey]
        if ($cacheEntry -and ((Get-Date) - $cacheEntry.Timestamp).TotalSeconds -lt 45) {
            $cached = $cacheEntry.Data
            
            Write-Host "`n============================================================" -ForegroundColor Cyan
            Write-Host "                INFORMACION DEL USUARIO ACTIVO              " -ForegroundColor Cyan
            Write-Host "============================================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host ("{0,-30}" -f "Usuario con Sesion:") -ForegroundColor Cyan -NoNewline
            Write-Host "$($cached.AccountName)" -ForegroundColor Green
            Write-Host ("{0,-30}" -f "Nombre Completo:") -ForegroundColor Cyan -NoNewline
            Write-Host "$($cached.FullName)" -ForegroundColor Yellow
            Write-Host ("{0,-30}" -f "Tipo de Cuenta:") -ForegroundColor Cyan -NoNewline
            if ($cached.IsLocal) {
                Write-Host "$($cached.AccountType)" -ForegroundColor Yellow
            } else {
                Write-Host "$($cached.AccountType)" -ForegroundColor Green
            }
            Write-Host ("{0,-30}" -f "Ruta de Perfil:") -ForegroundColor Cyan -NoNewline
            Write-Host "$($cached.ProfilePath)" -ForegroundColor Yellow
            Write-Host ("{0,-30}" -f "Inicio de Sesion:") -ForegroundColor Cyan -NoNewline
            Write-Host "$($cached.LogonTime)" -ForegroundColor Gray
            Write-Host ("{0,-30}" -f "Estado de Sesion:") -ForegroundColor Cyan -NoNewline
            Write-Host "$($cached.SessionState)" -ForegroundColor Green
            Write-Host ""

            if ($ReturnObject) {
                return [PSCustomObject]$cached
            }
            return
        }
    }

    $isLocalMachine = ($cleanTarget -eq "127.0.0.1") -or 
                      ($cleanTarget -eq "::1") -or 
                      ($cleanTarget -eq ".") -or 
                      ($cleanTarget -eq "localhost") -or 
                      ($cleanTarget.ToUpper() -eq $env:COMPUTERNAME.ToUpper())

    # 1. VerificaciÃ³n rÃ¡pida de conectividad en destinos remotos para evitar cuelgues (timeout 600ms)
    if (-not $isLocalMachine) {
        $pingOk = $false
        try {
            $pingObj = New-Object System.Net.NetworkInformation.Ping
            $reply = $pingObj.Send($cleanTarget, 600)
            if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                $pingOk = $true
            }
        } catch {}

        # Si ping no responde (posible bloqueo ICMP), probar puertos RPC/SMB (135/445)
        if (-not $pingOk) {
            $portOk = $false
            foreach ($port in @(135, 445)) {
                try {
                    $tcp = New-Object System.Net.Sockets.TcpClient
                    $async = $tcp.BeginConnect($cleanTarget, $port, $null, $null)
                    if ($async.AsyncWaitHandle.WaitOne(350, $false) -and $tcp.Connected) {
                        $portOk = $true
                        $tcp.Close()
                        break
                    }
                    $tcp.Close()
                } catch {}
            }

            if (-not $portOk) {
                Write-Host "`n============================================================" -ForegroundColor Cyan
                Write-Host "                INFORMACION DEL USUARIO ACTIVO              " -ForegroundColor Cyan
                Write-Host "============================================================" -ForegroundColor Cyan
                Write-Host ""
                Write-Host ("{0,-30}" -f "Usuario con Sesion:") -ForegroundColor Cyan -NoNewline
                Write-Host "No disponible" -ForegroundColor Gray
                Write-Host ("{0,-30}" -f "Nombre Completo:") -ForegroundColor Cyan -NoNewline
                Write-Host "No disponible" -ForegroundColor Gray
                Write-Host ("{0,-30}" -f "Tipo de Cuenta:") -ForegroundColor Cyan -NoNewline
                Write-Host "No disponible" -ForegroundColor Gray
                Write-Host ("{0,-30}" -f "Ruta de Perfil:") -ForegroundColor Cyan -NoNewline
                Write-Host "No disponible" -ForegroundColor Gray
                Write-Host ("{0,-30}" -f "Inicio de Sesion:") -ForegroundColor Cyan -NoNewline
                Write-Host "No disponible" -ForegroundColor Gray
                Write-Host ("{0,-30}" -f "Estado de Sesion:") -ForegroundColor Cyan -NoNewline
                Write-Host "Equipo no responde (Offline / Firewall)" -ForegroundColor Yellow
                Write-Host ""
                return
            }
        }
    }

    # 2. ResoluciÃ³n de Hostname y Datos de Dominio
    $targetHost = $cleanTarget
    try {
        $entry = [System.Net.Dns]::GetHostEntry($cleanTarget)
        if ($entry -and $entry.HostName) {
            $targetHost = $entry.HostName.Split('.')[0]
        }
    } catch {}

    $sysCS = $null
    try {
        $csParams = @{
            Class = 'Win32_ComputerSystem'
            ComputerName = $cleanTarget
            ErrorAction = 'SilentlyContinue'
        }
        if ($Credential) { $csParams['Credential'] = $Credential }
        $sysCS = Get-WmiObject @csParams
    } catch {}

    $partOfDomain = if ($sysCS) { $sysCS.PartOfDomain } else { $false }
    $domainFQDN = if ($sysCS -and $sysCS.Domain) { $sysCS.Domain } else { "" }

    # 3. DetecciÃ³n del Usuario Activo
    $usuariosActivos = @()

    # MÃ©todo A: Procesos explorer.exe interactivos vÃ­a WMI
    try {
        $procParams = @{
            Class = 'Win32_Process'
            Filter = "Name='explorer.exe'"
            ComputerName = $cleanTarget
            ErrorAction = 'Stop'
        }
        if ($Credential) { $procParams['Credential'] = $Credential }
        $procs = Get-WmiObject @procParams

        if ($procs) {
            foreach ($p in $procs) {
                $owner = $p.GetOwner()
                if ($owner.ReturnValue -eq 0 -and -not [string]::IsNullOrEmpty($owner.User)) {
                    $fechaLogon = "Sesion activa (Hora no disponible)"
                    if ($p.CreationDate) {
                        try {
                            $fechaLogon = [Management.ManagementDateTimeConverter]::ToDateTime($p.CreationDate).ToString("dd/MM/yyyy HH:mm:ss")
                        } catch {}
                    }
                    $usuariosActivos += [PSCustomObject]@{
                        Domain    = $owner.Domain
                        User      = $owner.User
                        LogonTime = $fechaLogon
                    }
                }
            }
        }
    } catch {}

    # MÃ©todo B: Fallback a Win32_ComputerSystem.UserName
    if ($usuariosActivos.Count -eq 0 -and $sysCS -and -not [string]::IsNullOrEmpty($sysCS.UserName)) {
        $parts = $sysCS.UserName.Split('\')
        $dom = if ($parts.Count -gt 1) { $parts[0] } else { "" }
        $usr = if ($parts.Count -gt 1) { $parts[1] } else { $parts[0] }
        $usuariosActivos += [PSCustomObject]@{
            Domain    = $dom
            User      = $usr
            LogonTime = "Sesion activa (Hora no disponible)"
        }
    }

    # MÃ©todo C: Fallback rÃ¡pido mediante quser
    if ($usuariosActivos.Count -eq 0) {
        try {
            $quserOut = quser /server:$cleanTarget 2>$null
            if ($quserOut) {
                foreach ($line in ($quserOut | Select-Object -Skip 1)) {
                    $cleanLine = $line.Trim()
                    if ($cleanLine -match '^\>?\s*([a-zA-Z0-9_\-\.]+)\s+.*?(\d{1,2}/\d{1,2}/\d{4}\s+\d{1,2}:\d{2})') {
                        $usuariosActivos += [PSCustomObject]@{
                            Domain    = if ($domainFQDN) { $domainFQDN } else { "" }
                            User      = $Matches[1]
                            LogonTime = $Matches[2]
                        }
                    } elseif ($cleanLine -match '^\>?\s*([a-zA-Z0-9_\-\.]+)') {
                        $usuariosActivos += [PSCustomObject]@{
                            Domain    = if ($domainFQDN) { $domainFQDN } else { "" }
                            User      = $Matches[1]
                            LogonTime = "Sesion activa (Hora no disponible)"
                        }
                    }
                }
            }
        } catch {}
    }

    # Descartar duplicados manteniendo los Ãºnicos
    $usuariosUnicos = @()
    $seen = @{}
    foreach ($u in $usuariosActivos) {
        $key = "$($u.Domain)\$($u.User)".ToUpper()
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $usuariosUnicos += $u
        }
    }
    $usuariosActivos = $usuariosUnicos

    # 4. Caso: Sin sesiÃ³n interactiva activa
    if ($usuariosActivos.Count -eq 0) {
        Write-Host "`n============================================================" -ForegroundColor Cyan
        Write-Host "                INFORMACION DEL USUARIO ACTIVO              " -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host ("{0,-30}" -f "Usuario con Sesion:") -ForegroundColor Cyan -NoNewline
        Write-Host "Sin sesion activa" -ForegroundColor Yellow
        Write-Host ("{0,-30}" -f "Nombre Completo:") -ForegroundColor Cyan -NoNewline
        Write-Host "Ningun usuario interactivo conectado" -ForegroundColor Yellow
        Write-Host ("{0,-30}" -f "Tipo de Cuenta:") -ForegroundColor Cyan -NoNewline
        Write-Host "No disponible" -ForegroundColor Gray
        Write-Host ("{0,-30}" -f "Ruta de Perfil:") -ForegroundColor Cyan -NoNewline
        Write-Host "No disponible" -ForegroundColor Gray
        Write-Host ("{0,-30}" -f "Inicio de Sesion:") -ForegroundColor Cyan -NoNewline
        Write-Host "No disponible" -ForegroundColor Gray
        Write-Host ("{0,-30}" -f "Estado de Sesion:") -ForegroundColor Cyan -NoNewline
        Write-Host "Sin sesion activa (Conectado a la red)" -ForegroundColor Yellow
        Write-Host ""
        return
    }

    # 5. Obtener perfiles remotos para resolver Ruta de Perfil
    $perfilesRemotos = $null
    try {
        $profParams = @{
            Class = 'Win32_UserProfile'
            ComputerName = $cleanTarget
            ErrorAction = 'SilentlyContinue'
        }
        if ($Credential) { $profParams['Credential'] = $Credential }
        $perfilesRemotos = Get-WmiObject @profParams
    } catch {}

    # 6. Procesar y presentar la informaciÃ³n de cada usuario activo
    $lastResultObj = $null

    foreach ($u in $usuariosActivos) {
        $esLocal = ($u.Domain.ToUpper() -eq $targetHost.ToUpper()) -or 
                   ($u.Domain -eq ".") -or 
                   ([string]::IsNullOrEmpty($u.Domain)) -or 
                   (-not $partOfDomain)

        # ResoluciÃ³n de Nombre Completo
        $nombreCompleto = ""
        if (-not $esLocal) {
            try {
                $searcher = [adsisearcher]"(sAMAccountName=$($u.User))"
                $adUser = $searcher.FindOne()
                if ($adUser -and $adUser.Properties["displayname"]) {
                    $nombreCompleto = $adUser.Properties["displayname"][0].ToString().Trim()
                }
            } catch {}
        }
        if ([string]::IsNullOrWhiteSpace($nombreCompleto)) {
            try {
                $accParams = @{
                    Class = 'Win32_UserAccount'
                    Filter = "Name='$($u.User)' and LocalAccount=True"
                    ComputerName = $cleanTarget
                    ErrorAction = 'SilentlyContinue'
                }
                if ($Credential) { $accParams['Credential'] = $Credential }
                $acc = Get-WmiObject @accParams
                if ($acc -and $acc.FullName) {
                    $nombreCompleto = $acc.FullName.Trim()
                }
            } catch {}
        }
        if ([string]::IsNullOrWhiteSpace($nombreCompleto)) {
            $nombreCompleto = "No especificado / No disponible"
        }

        # ResoluciÃ³n de Tipo de Cuenta
        $tipoCuenta = ""
        if ($esLocal) {
            $tipoCuenta = "Usuario Local (.\$($u.User))"
        } else {
            $nombreDominio = if ($domainFQDN) { $domainFQDN } elseif ($u.Domain) { $u.Domain } else { "Dominio" }
            $tipoCuenta = "Usuario de Dominio ($nombreDominio)"
        }

        # ResoluciÃ³n de Ruta de Perfil
        $rutaPerfil = ""
        if ($perfilesRemotos) {
            $perf = $perfilesRemotos | Where-Object { 
                ($_.LocalPath -like "*\$($u.User)") -or 
                ($_.Loaded -eq $true -and -not $_.Special) 
            } | Select-Object -First 1
            if ($perf -and $perf.LocalPath) {
                $rutaPerfil = $perf.LocalPath
            }
        }
        if ([string]::IsNullOrWhiteSpace($rutaPerfil)) {
            $rutaPerfil = "C:\Users\$($u.User)"
        }

        # Formateo de Cuenta
        $cuentaFormato = if (-not [string]::IsNullOrEmpty($u.Domain)) { "$($u.Domain)\$($u.User)" } else { ".\$($u.User)" }

        # Salida visual fiel a la imagen
        Write-Host "`n============================================================" -ForegroundColor Cyan
        Write-Host "                INFORMACION DEL USUARIO ACTIVO              " -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host ("{0,-30}" -f "Usuario con Sesion:") -ForegroundColor Cyan -NoNewline
        Write-Host "$cuentaFormato" -ForegroundColor Green
        Write-Host ("{0,-30}" -f "Nombre Completo:") -ForegroundColor Cyan -NoNewline
        Write-Host "$nombreCompleto" -ForegroundColor Yellow
        Write-Host ("{0,-30}" -f "Tipo de Cuenta:") -ForegroundColor Cyan -NoNewline
        if ($esLocal) {
            Write-Host "$tipoCuenta" -ForegroundColor Yellow
        } else {
            Write-Host "$tipoCuenta" -ForegroundColor Green
        }
        Write-Host ("{0,-30}" -f "Ruta de Perfil:") -ForegroundColor Cyan -NoNewline
        Write-Host "$rutaPerfil" -ForegroundColor Yellow
        Write-Host ("{0,-30}" -f "Inicio de Sesion:") -ForegroundColor Cyan -NoNewline
        Write-Host "$($u.LogonTime)" -ForegroundColor Gray
        Write-Host ("{0,-30}" -f "Estado de Sesion:") -ForegroundColor Cyan -NoNewline
        Write-Host "Activa (Conectado)" -ForegroundColor Green
        Write-Host ""

        $lastResultObj = [PSCustomObject]@{
            AccountName  = $cuentaFormato
            FullName     = $nombreCompleto
            AccountType  = $tipoCuenta
            ProfilePath  = $rutaPerfil
            LogonTime    = $u.LogonTime
            SessionState = "Activa (Conectado)"
            IsLocal      = $esLocal
            Domain       = $u.Domain
            User         = $u.User
        }

        # Almacenar en cachÃ© de sesiÃ³n
        $global:ActiveUserCache[$cacheKey] = @{
            Timestamp = Get-Date
            Data      = $lastResultObj
        }
    }

    if ($ReturnObject) {
        return $lastResultObj
    }
}

# Alias modular para compatibilidad con convenciones alternativas
Set-Alias -Name Show-ActiveUserSessionInfo -Value psMostrarInformacionUsuarioActivo -ErrorAction SilentlyContinue


# Nota: El Grupo 101 (Auditoria de Credenciales y SQLite) fue desacoplado a 'recursosExtras/AuditoriaNavegadores.ps1'
