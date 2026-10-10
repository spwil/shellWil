# =========================================================================================
# EXTENSION DESACOPLADA: AUDITORIA Y CONTROL DE ACCESOS EN NAVEGADORES WEB (GRUPO 101)
# =========================================================================================
# Autor: Ing. Wilson Yucra - spWil
# Proyecto: ShellSW - Modulo de Extension Desacoplado
# Descripcion:
#   Herramienta especializada de auditoria y administracion de perfiles de navegadores web
#   (Google Chrome, Microsoft Edge, Mozilla Firefox, Brave, Opera).
#
#   [POLITICA DE SEGURIDAD]:
#   - Esta herramienta audita UNICAMENTE URLs/Dominios, perfiles y cuentas asociadas
#     con fines legitimos de gestion de red y directivas de Firewall (Listas Blancas/Negras).
#   - NO extrae, descifra ni expone contrasenas en texto claro, tokens de sesion ni cookies.
#   - Este modulo fue desacoplado del binario principal ShellSW para cumplimiento estricto
#     de politicas de seguridad corporativa y prevencion de falsos positivos en sistemas EDR.
# =========================================================================================

# -----------------------------------------------------------------------------------------
# FUNCIONES AUXILIARES DE ENTORNO E INTERFAZ (AUTOCONTENIDAS)
# -----------------------------------------------------------------------------------------

if (-not (Get-Command Test-IsProcessAdmin -ErrorAction SilentlyContinue)) {
    function Test-IsProcessAdmin {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
}

if (-not (Get-Command Write-Header -ErrorAction SilentlyContinue)) {
    function Write-Header {
        param([string]$texto)
        $ancho = $texto.Length + 15
        $linea = "=" * $ancho
        Write-Host "`n$linea" -ForegroundColor Yellow
        Write-Host "| $texto |" -ForegroundColor White -BackgroundColor DarkBlue
        Write-Host "$linea" -ForegroundColor Yellow
    }
}

if (-not (Get-Command menuOpcion -ErrorAction SilentlyContinue)) {
    function menuOpcion {
        param([string]$texto)
        $ancho = $texto.Length + 5
        $linea = "=" * $ancho
        Write-Host "`n$linea" -ForegroundColor Yellow
        Write-Host "| $texto |" -ForegroundColor Black -BackgroundColor Yellow
        Write-Host "$linea" -ForegroundColor Yellow
    }
}

if (-not (Get-Command cabecera -ErrorAction SilentlyContinue)) {
    function cabecera {
        Clear-Host
        $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $fecha = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
        Write-Host " ========================================================================" -ForegroundColor Cyan
        Write-Host " ShellSW - EXTENSION DE AUDITORIA DE NAVEGADORES (GRUPO 101)" -ForegroundColor Cyan
        Write-Host " Operador: $user  ;  Fecha: $fecha" -ForegroundColor Cyan
        Write-Host " Derechos Reservados (c) spWil" -ForegroundColor Cyan
        Write-Host " ========================================================================" -ForegroundColor Cyan
    }
}

if (-not (Get-Command Get-StandardIPPrompt -ErrorAction SilentlyContinue)) {
    function Get-StandardIPPrompt {
        param([string]$Mensaje = "Ingrese la IP completa (ej: 192.168.176.50) o los 2 ultimos octetos (ej: 176.50)")
        $inputRaw = Read-Host $Mensaje
        if ([string]::IsNullOrWhiteSpace($inputRaw)) { return "" }
        $inputRaw = $inputRaw.Trim()
        if ($inputRaw -match '^(\d{1,3}\.){3}\d{1,3}$') { return $inputRaw }
        elseif ($inputRaw -match '^\d{1,3}\.\d{1,3}$') { return "192.168.$inputRaw" }
        elseif ($inputRaw -match '^\d{1,3}$') { return "192.168.176.$inputRaw" }
        return $inputRaw
    }
}

# -----------------------------------------------------------------------------------------
# FUNCIONES NATIVAS DE LECTURA SQLITE Y CLASIFICACION DE DOMINIOS
# -----------------------------------------------------------------------------------------

function Initialize-WinSqliteHelper {
    <#
    .SYNOPSIS
        Inicializa en memoria el lector SQLite nativo (WinSqliteReader) utilizando
        la libreria winsqlite3.dll incorporada en Windows sin dependencias externas.
    #>
    if (-not ([System.Management.Automation.PSTypeName]"WinSqliteReader").Type) {
        $cCode = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public class SqliteLoginEntry {
    public string OriginUrl { get; set; }
    public string ActionUrl { get; set; }
    public string Username { get; set; }
    public long DateLastUsed { get; set; }
}

public class WinSqliteReader {
    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_open16", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
    public static extern int sqlite3_open16(string filename, out IntPtr db);

    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_prepare16_v2", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
    public static extern int sqlite3_prepare16_v2(IntPtr db, string zSql, int nByte, out IntPtr ppStmt, IntPtr pzTail);

    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_step", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_step(IntPtr pStmt);

    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_column_text16", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr sqlite3_column_text16(IntPtr pStmt, int iCol);

    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_column_int64", CallingConvention = CallingConvention.Cdecl)]
    public static extern long sqlite3_column_int64(IntPtr pStmt, int iCol);

    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_finalize", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_finalize(IntPtr pStmt);

    [DllImport("winsqlite3.dll", EntryPoint = "sqlite3_close", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_close(IntPtr db);

    public static List<SqliteLoginEntry> ReadLogins(string dbPath) {
        var list = new List<SqliteLoginEntry>();
        IntPtr db = IntPtr.Zero;
        if (sqlite3_open16(dbPath, out db) != 0) {
            return list;
        }

        IntPtr stmt = IntPtr.Zero;
        // CONSULTA ESTRICTA: Se omiten por diseno campos de claves o hashes (cero extraccion de secretos)
        string sql = "SELECT origin_url, action_url, username_value, date_last_used FROM logins";
        try {
            if (sqlite3_prepare16_v2(db, sql, -1, out stmt, IntPtr.Zero) == 0) {
                while (sqlite3_step(stmt) == 100) { // SQLITE_ROW = 100
                    IntPtr pOrigin = sqlite3_column_text16(stmt, 0);
                    IntPtr pAction = sqlite3_column_text16(stmt, 1);
                    IntPtr pUser = sqlite3_column_text16(stmt, 2);
                    long lastUsed = sqlite3_column_int64(stmt, 3);

                    string origin = pOrigin != IntPtr.Zero ? Marshal.PtrToStringUni(pOrigin) : "";
                    string action = pAction != IntPtr.Zero ? Marshal.PtrToStringUni(pAction) : "";
                    string user = pUser != IntPtr.Zero ? Marshal.PtrToStringUni(pUser) : "";

                    list.Add(new SqliteLoginEntry {
                        OriginUrl = origin,
                        ActionUrl = action,
                        Username = user,
                        DateLastUsed = lastUsed
                    });
                }
            }
        }
        finally {
            if (stmt != IntPtr.Zero) sqlite3_finalize(stmt);
            if (db != IntPtr.Zero) sqlite3_close(db);
        }
        return list;
    }
}
'@
        try {
            Add-Type -TypeDefinition $cCode -ErrorAction SilentlyContinue
        } catch {}
    }
}

function Get-DomainClassification {
    <#
    .SYNOPSIS
        Analiza una URL o dominio y devuelve su clasificacion sugerida para
        politicas de administracion de red (Listas Blancas, Listas Negras, Ocio, etc.).
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$UrlOrDomain
    )

    $raw = $UrlOrDomain.Trim()
    $domain = ""

    try {
        if ($raw -match '^[a-zA-Z]+://') {
            $uri = [System.Uri]$raw
            $domain = $uri.Host.ToLower()
        } else {
            $domain = ($raw -split '/')[0].ToLower()
        }
    } catch {
        $domain = $raw.ToLower()
    }

    $categoria = "[EXTERNO / Auditoria]"
    $color = "Gray"
    $sugerencia = "Monitorear"

    # 1. Sitios Institucionales / Estatales / Educativos (Lista Blanca)
    if ($domain -match '\.gob\.bo|\.gov|\.edu|gmsantacruz|santacruz\.gob|sigep|impuestos|aduana|ruat|justicia') {
        $categoria = "[LISTA BLANCA - Institucional]"
        $color = "Green"
        $sugerencia = "Permitir / Confianza"
    }
    # 2. Productividad / Servicios Cloud Empresariales
    elseif ($domain -match 'microsoft|office|live\.com|azure|sharepoint|outlook|google\.com|gmail|drive\.google|github|gitlab') {
        $categoria = "[PRODUCTIVIDAD / Cloud]"
        $color = "Cyan"
        $sugerencia = "Permitir Corporativo"
    }
    # 3. Redes Sociales / Ocio / Streaming (Lista Negra)
    elseif ($domain -match 'facebook|instagram|tiktok|twitter|x\.com|youtube|netflix|spotify|twitch|disney|primevideo|pinterest|reddit') {
        $categoria = "[LISTA NEGRA - Ocio / Red Social]"
        $color = "Red"
        $sugerencia = "Bloquear / Restringir"
    }
    # 4. Mensajería Instantánea
    elseif ($domain -match 'whatsapp|telegram|discord|slack|skype') {
        $categoria = "[RESTRINGIDO - Mensajeria]"
        $color = "Yellow"
        $sugerencia = "Controlar Politica"
    }
    # 5. Servicios Financieros / Bancarios
    elseif ($domain -match 'banco|bnb|bisa|mercantil|union|fassil|sol|bcp|ganadero|ecofuturo|fie|prodem') {
        $categoria = "[SENSIBLE - Financiero]"
        $color = "Magenta"
        $sugerencia = "Auditar Acceso"
    }
    # 6. Almacenamiento Personal / Compartición de archivos
    elseif ($domain -match 'mega\.nz|mediafire|dropbox|wetransfer|rapidgator') {
        $categoria = "[RIESGO - Exfiltracion]"
        $color = "DarkYellow"
        $sugerencia = "Restringir Transferencia"
    }

    return [PSCustomObject]@{
        Domain           = $domain
        Category         = $categoria
        Color            = $color
        ActionSuggestion = $sugerencia
    }
}

function Write-AuditAccess101 {
    <#
    .SYNOPSIS
        Asienta el registro de auditoria de acceso al Grupo 101 tanto en el
        Visor de Eventos de Windows (EventLog) como en una bitacora local dedicada.
    #>
    param(
        [string]$Target = "Localhost",
        [string]$Action = "Auditoria de Navegadores",
        [string]$Status = "AUTORIZADO",
        [string]$Details = ""
    )

    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $fechaStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $mensajeLog = "[$fechaStr] | OPERADOR: $currentUser | DESTINO: $Target | ACCION: $Action | ESTADO: $Status"
    if (-not [string]::IsNullOrWhiteSpace($Details)) {
        $mensajeLog += " | DETALLES: $Details"
    }

    # 1. Bitácora en archivo de texto (Modo anexo)
    try {
        $baseDir = if ($env:SCRIPT_PATH) { Split-Path $env:SCRIPT_PATH } elseif ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
        $candidateDirs = @(
            (Join-Path $baseDir "logs"),
            (if ($baseDir) { Join-Path (Split-Path $baseDir -ErrorAction SilentlyContinue) "logs" }),
            (Join-Path (Get-Location).Path "logs"),
            "C:\shellWil\logs"
        )
        $logDir = $candidateDirs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path $_) } | Select-Object -First 1
        if (-not $logDir) {
            $logDir = Join-Path (if ($baseDir -and (Test-Path (Join-Path (Split-Path $baseDir) "ShellSW.bat"))) { Split-Path $baseDir } else { $baseDir }) "logs"
            if (-not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue | Out-Null
            }
        }
        if (-not (Test-Path $logDir)) {
            $logDir = "C:\shellWil\logs"
            if (-not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue | Out-Null
            }
        }
        $logFile = Join-Path $logDir "audit_101.log"
        $mensajeLog | Out-File -FilePath $logFile -Append -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}

    # 2. Visor de Eventos de Windows (Application / ShellSW)
    try {
        $sourceName = "ShellSW"
        if (-not [System.Diagnostics.EventLog]::SourceExists($sourceName)) {
            [System.Diagnostics.EventLog]::CreateEventSource($sourceName, "Application")
        }
        $entryType = if ($Status -like "*DENEGADO*") { 
            [System.Diagnostics.EventLogEntryType]::Warning 
        } else { 
            [System.Diagnostics.EventLogEntryType]::Information 
        }
        $eventId = if ($Status -like "*DENEGADO*") { 10102 } else { 10101 }
        [System.Diagnostics.EventLog]::WriteEntry($sourceName, $mensajeLog, $entryType, $eventId)
    } catch {}
}

# -----------------------------------------------------------------------------------------
# MENU INTERACTIVO DE AUDITORIA DE NAVEGADORES (GRUPO 101)
# -----------------------------------------------------------------------------------------

function Invoke-AuditoriaNavegadores {
    $salirSub101 = $false
    do {
        try {
            cabecera
            Write-Header " 101. CREDENCIALES NAVEGADORES (ADMINISTRACION Y AUDITORIA) "
            Write-Host "  1. Auditoria de navegadores (Perfiles, Sitios Web y Cuentas guardadas)." -ForegroundColor Green
            Write-Host "  2. Generar reporte consolidado de dominios para Listas Blancas/Negras." -ForegroundColor Cyan
            Write-Host "  3. Ver historial de accesos y registros de auditoria del Grupo 101." -ForegroundColor Yellow
            Write-Host "  ----------------------------------------------------------------------"
            Write-Host "  0. V O L V E R   A L   M E N U   A N T E R I O R"
            Write-Header "==============================================================="

            $op101 = Read-Host "Seleccione la tarea a realizar"

            switch ($op101) {
                "1" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: 101 ;;; Opcion: $op101 (Auditoria de Navegadores)"

                    Write-Host "`n--- AUDITORIA DE NAVEGADORES Y CREDENCIALES GUARDADAS (EQUIPO REMOTO) ---" -ForegroundColor Cyan
                    Write-Host "[POLITICA DE SEGURIDAD]: Esta herramienta audita unicamente nombres de usuario y URLs asociadas." -ForegroundColor Gray
                    Write-Host "                         No extrae, descifra ni expone contrasenas, tokens ni cookies." -ForegroundColor Gray

                    # 1. Control de Acceso: Verificar token de Administrador
                    $isAdmin = Test-IsProcessAdmin
                    if (-not $isAdmin) {
                        Write-Host "`n[ERROR DE SEGURIDAD] Esta funcionalidad requiere una consola con privilegios elevados de Administrador." -ForegroundColor Red
                        Write-AuditAccess101 -Target "N/A" -Action "Auditoria de Navegadores" -Status "DENEGADO_TOKEN_NO_ELEVADO"
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    # 2. Solicitar Target
                    $IPFinal = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($IPFinal)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    # 3. Resolución de Hostname
                    $computerTarget = $IPFinal
                    Write-Host "`n[*] Resolviendo Hostname de $IPFinal para sesion administrativa..." -ForegroundColor Gray
                    try {
                        $entry = [System.Net.Dns]::GetHostEntry($IPFinal)
                        $computerTarget = $entry.HostName.Split('.')[0]
                        Write-Host "[+] Hostname resuelto: $computerTarget (Kerberos / SMB habilitado)" -ForegroundColor Green
                    }
                    catch {
                        try {
                            $sys = Get-CimInstance Win32_OperatingSystem -ComputerName $IPFinal -OperationTimeoutSec 3 -ErrorAction Stop
                            $computerTarget = $sys.CSName
                            Write-Host "[+] Hostname resuelto via WMI: $computerTarget" -ForegroundColor Green
                        }
                        catch {
                            Write-Host "[-] No se pudo resolver Hostname. Usando identificador: $IPFinal" -ForegroundColor Yellow
                        }
                    }

                    # Asentar en registro de auditoría
                    Write-AuditAccess101 -Target "$computerTarget ($IPFinal)" -Action "Auditoria de Navegadores" -Status "AUTORIZADO"

                    # 4. Validar acceso al recurso administrativo
                    $remoteC = "\\$computerTarget\C$"
                    if (-not (Test-Path $remoteC)) {
                        Write-Host "`n[-] ERROR: No se puede acceder al recurso compartido administrativo en $remoteC" -ForegroundColor Red
                        Write-Host "    Verifique conectividad de red, firewall y permisos de administrador en el destino." -ForegroundColor Yellow
                        Read-Host "`nPresione ENTER para continuar..."
                        break
                    }

                    # Inicializar motor SQLite
                    Initialize-WinSqliteHelper

                    # 5. Detección de navegadores instalados
                    Write-Host "`n[*] Detectando navegadores instalados en $computerTarget..." -ForegroundColor Yellow
                    
                    $chromePaths = @(
                        "\\$computerTarget\C$\Program Files\Google\Chrome\Application\chrome.exe",
                        "\\$computerTarget\C$\Program Files (x86)\Google\Chrome\Application\chrome.exe"
                    )
                    $edgePaths = @(
                        "\\$computerTarget\C$\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
                        "\\$computerTarget\C$\Program Files\Microsoft\Edge\Application\msedge.exe"
                    )
                    $firefoxPaths = @(
                        "\\$computerTarget\C$\Program Files\Mozilla Firefox\firefox.exe",
                        "\\$computerTarget\C$\Program Files (x86)\Mozilla Firefox\firefox.exe"
                    )
                    $bravePaths = @(
                        "\\$computerTarget\C$\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe",
                        "\\$computerTarget\C$\Program Files (x86)\BraveSoftware\Brave-Browser\Application\brave.exe"
                    )
                    $operaPaths = @(
                        "\\$computerTarget\C$\Program Files\Opera\launcher.exe",
                        "\\$computerTarget\C$\Program Files (x86)\Opera\launcher.exe"
                    )

                    $hasChrome = [bool]($chromePaths | Where-Object { Test-Path $_ })
                    $hasEdge = [bool]($edgePaths | Where-Object { Test-Path $_ })
                    $hasFirefox = [bool]($firefoxPaths | Where-Object { Test-Path $_ })
                    $hasBrave = [bool]($bravePaths | Where-Object { Test-Path $_ })
                    $hasOpera = [bool]($operaPaths | Where-Object { Test-Path $_ })

                    Write-Host "    - Google Chrome:   $([char]0x2022) $(if ($hasChrome) { 'INSTALADO' } else { 'No detectado' })" -ForegroundColor $(if ($hasChrome) { 'Green' } else { 'DarkGray' })
                    Write-Host "    - Microsoft Edge:  $([char]0x2022) $(if ($hasEdge) { 'INSTALADO' } else { 'No detectado' })" -ForegroundColor $(if ($hasEdge) { 'Green' } else { 'DarkGray' })
                    Write-Host "    - Mozilla Firefox: $([char]0x2022) $(if ($hasFirefox) { 'INSTALADO' } else { 'No detectado' })" -ForegroundColor $(if ($hasFirefox) { 'Green' } else { 'DarkGray' })
                    Write-Host "    - Brave Browser:   $([char]0x2022) $(if ($hasBrave) { 'INSTALADO' } else { 'No detectado' })" -ForegroundColor $(if ($hasBrave) { 'Green' } else { 'DarkGray' })
                    Write-Host "    - Opera:           $([char]0x2022) $(if ($hasOpera) { 'INSTALADO' } else { 'No detectado' })" -ForegroundColor $(if ($hasOpera) { 'Green' } else { 'DarkGray' })

                    # 6. Escaneo de perfiles de usuario
                    Write-Host "`n[*] Analizando perfiles de usuario en el equipo remoto..." -ForegroundColor Yellow
                    $usersDir = "\\$computerTarget\C$\Users"
                    $userFolders = Get-ChildItem -Path $usersDir -Directory -ErrorAction SilentlyContinue | 
                        Where-Object { $_.Name -notmatch '^(Public|Default|Default User|All Users)$' }

                    if (-not $userFolders -or $userFolders.Count -eq 0) {
                        Write-Host "[-] No se pudieron listar carpetas de usuario en $usersDir." -ForegroundColor Yellow
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    $auditGuid = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
                    $localAuditTemp = Join-Path $env:TEMP "ShellSW_Audit_$auditGuid"
                    New-Item -ItemType Directory -Path $localAuditTemp -Force -ErrorAction SilentlyContinue | Out-Null

                    $loginResults = [System.Collections.Generic.List[PSCustomObject]]::new()

                    try {
                        foreach ($uFolder in $userFolders) {
                            $uName = $uFolder.Name
                            Write-Host "  -> Inspeccionando perfil: $uName..." -ForegroundColor Gray

                            # --- CHROME ---
                            $chromeUserData = Join-Path $uFolder.FullName "AppData\Local\Google\Chrome\User Data"
                            if (Test-Path $chromeUserData) {
                                $profileDirs = Get-ChildItem -Path $chromeUserData -Directory -ErrorAction SilentlyContinue | 
                                    Where-Object { $_.Name -eq "Default" -or $_.Name -like "Profile *" }
                                foreach ($pDir in $profileDirs) {
                                    $loginDataFile = Join-Path $pDir.FullName "Login Data"
                                    if (Test-Path $loginDataFile) {
                                        $tmpDb = Join-Path $localAuditTemp "Chrome_${uName}_$($pDir.Name)_LoginData"
                                        try {
                                            [System.IO.File]::Copy($loginDataFile, $tmpDb, $true)
                                            $entries = [WinSqliteReader]::ReadLogins($tmpDb)
                                            foreach ($e in $entries) {
                                                if (-not [string]::IsNullOrWhiteSpace($e.OriginUrl) -or -not [string]::IsNullOrWhiteSpace($e.ActionUrl)) {
                                                    $classif = Get-DomainClassification -UrlOrDomain $e.OriginUrl
                                                    $loginResults.Add([PSCustomObject]@{
                                                        UsuarioLocal     = $uName
                                                        Navegador        = "Google Chrome"
                                                        Perfil           = $pDir.Name
                                                        Dominio          = $classif.Domain
                                                        UrlOrigen        = $e.OriginUrl
                                                        UsuarioGuardado  = $e.Username
                                                        Categoria        = $classif.Category
                                                        Color            = $classif.Color
                                                        Sugerencia       = $classif.ActionSuggestion
                                                    })
                                                }
                                            }
                                        } catch {}
                                        finally {
                                            if (Test-Path $tmpDb) { Remove-Item $tmpDb -Force -ErrorAction SilentlyContinue }
                                        }
                                    }
                                }
                            }

                            # --- EDGE ---
                            $edgeUserData = Join-Path $uFolder.FullName "AppData\Local\Microsoft\Edge\User Data"
                            if (Test-Path $edgeUserData) {
                                $profileDirs = Get-ChildItem -Path $edgeUserData -Directory -ErrorAction SilentlyContinue | 
                                    Where-Object { $_.Name -eq "Default" -or $_.Name -like "Profile *" }
                                foreach ($pDir in $profileDirs) {
                                    $loginDataFile = Join-Path $pDir.FullName "Login Data"
                                    if (Test-Path $loginDataFile) {
                                        $tmpDb = Join-Path $localAuditTemp "Edge_${uName}_$($pDir.Name)_LoginData"
                                        try {
                                            [System.IO.File]::Copy($loginDataFile, $tmpDb, $true)
                                            $entries = [WinSqliteReader]::ReadLogins($tmpDb)
                                            foreach ($e in $entries) {
                                                if (-not [string]::IsNullOrWhiteSpace($e.OriginUrl) -or -not [string]::IsNullOrWhiteSpace($e.ActionUrl)) {
                                                    $classif = Get-DomainClassification -UrlOrDomain $e.OriginUrl
                                                    $loginResults.Add([PSCustomObject]@{
                                                        UsuarioLocal     = $uName
                                                        Navegador        = "Microsoft Edge"
                                                        Perfil           = $pDir.Name
                                                        Dominio          = $classif.Domain
                                                        UrlOrigen        = $e.OriginUrl
                                                        UsuarioGuardado  = $e.Username
                                                        Categoria        = $classif.Category
                                                        Color            = $classif.Color
                                                        Sugerencia       = $classif.ActionSuggestion
                                                    })
                                                }
                                            }
                                        } catch {}
                                        finally {
                                            if (Test-Path $tmpDb) { Remove-Item $tmpDb -Force -ErrorAction SilentlyContinue }
                                        }
                                    }
                                }
                            }

                            # --- BRAVE ---
                            $braveUserData = Join-Path $uFolder.FullName "AppData\Local\BraveSoftware\Brave-Browser\User Data"
                            if (Test-Path $braveUserData) {
                                $profileDirs = Get-ChildItem -Path $braveUserData -Directory -ErrorAction SilentlyContinue | 
                                    Where-Object { $_.Name -eq "Default" -or $_.Name -like "Profile *" }
                                foreach ($pDir in $profileDirs) {
                                    $loginDataFile = Join-Path $pDir.FullName "Login Data"
                                    if (Test-Path $loginDataFile) {
                                        $tmpDb = Join-Path $localAuditTemp "Brave_${uName}_$($pDir.Name)_LoginData"
                                        try {
                                            [System.IO.File]::Copy($loginDataFile, $tmpDb, $true)
                                            $entries = [WinSqliteReader]::ReadLogins($tmpDb)
                                            foreach ($e in $entries) {
                                                if (-not [string]::IsNullOrWhiteSpace($e.OriginUrl) -or -not [string]::IsNullOrWhiteSpace($e.ActionUrl)) {
                                                    $classif = Get-DomainClassification -UrlOrDomain $e.OriginUrl
                                                    $loginResults.Add([PSCustomObject]@{
                                                        UsuarioLocal     = $uName
                                                        Navegador        = "Brave Browser"
                                                        Perfil           = $pDir.Name
                                                        Dominio          = $classif.Domain
                                                        UrlOrigen        = $e.OriginUrl
                                                        UsuarioGuardado  = $e.Username
                                                        Categoria        = $classif.Category
                                                        Color            = $classif.Color
                                                        Sugerencia       = $classif.ActionSuggestion
                                                    })
                                                }
                                            }
                                        } catch {}
                                        finally {
                                            if (Test-Path $tmpDb) { Remove-Item $tmpDb -Force -ErrorAction SilentlyContinue }
                                        }
                                    }
                                }
                            }

                            # --- OPERA ---
                            $operaUserData = Join-Path $uFolder.FullName "AppData\Roaming\Opera Software\Opera Stable"
                            if (Test-Path $operaUserData) {
                                $loginDataFile = Join-Path $operaUserData "Login Data"
                                if (Test-Path $loginDataFile) {
                                    $tmpDb = Join-Path $localAuditTemp "Opera_${uName}_LoginData"
                                    try {
                                        [System.IO.File]::Copy($loginDataFile, $tmpDb, $true)
                                        $entries = [WinSqliteReader]::ReadLogins($tmpDb)
                                        foreach ($e in $entries) {
                                            if (-not [string]::IsNullOrWhiteSpace($e.OriginUrl) -or -not [string]::IsNullOrWhiteSpace($e.ActionUrl)) {
                                                $classif = Get-DomainClassification -UrlOrDomain $e.OriginUrl
                                                $loginResults.Add([PSCustomObject]@{
                                                    UsuarioLocal     = $uName
                                                    Navegador        = "Opera"
                                                    Perfil           = "Stable"
                                                    Dominio          = $classif.Domain
                                                    UrlOrigen        = $e.OriginUrl
                                                    UsuarioGuardado  = $e.Username
                                                    Categoria        = $classif.Category
                                                    Color            = $classif.Color
                                                    Sugerencia       = $classif.ActionSuggestion
                                                })
                                            }
                                        }
                                    } catch {}
                                    finally {
                                        if (Test-Path $tmpDb) { Remove-Item $tmpDb -Force -ErrorAction SilentlyContinue }
                                    }
                                }
                            }

                            # --- MOZILLA FIREFOX ---
                            $ffProfilesPath = Join-Path $uFolder.FullName "AppData\Roaming\Mozilla\Firefox\Profiles"
                            if (Test-Path $ffProfilesPath) {
                                $ffDirs = Get-ChildItem -Path $ffProfilesPath -Directory -ErrorAction SilentlyContinue
                                foreach ($fDir in $ffDirs) {
                                    $loginsJson = Join-Path $fDir.FullName "logins.json"
                                    if (Test-Path $loginsJson) {
                                        try {
                                            $jsonContent = Get-Content -Path $loginsJson -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
                                            if ($jsonContent.logins) {
                                                foreach ($l in $jsonContent.logins) {
                                                    $targetUrl = if ($l.hostname) { $l.hostname } else { $l.formSubmitURL }
                                                    if (-not [string]::IsNullOrWhiteSpace($targetUrl)) {
                                                        $classif = Get-DomainClassification -UrlOrDomain $targetUrl
                                                        $userVal = if ($l.encryptedUsername) { "(Usuario Cifrado / Firefox Vault)" } else { "" }
                                                        $loginResults.Add([PSCustomObject]@{
                                                            UsuarioLocal     = $uName
                                                            Navegador        = "Mozilla Firefox"
                                                            Perfil           = $fDir.Name
                                                            Dominio          = $classif.Domain
                                                            UrlOrigen        = $targetUrl
                                                            UsuarioGuardado  = $userVal
                                                            Categoria        = $classif.Category
                                                            Color            = $classif.Color
                                                            Sugerencia       = $classif.ActionSuggestion
                                                        })
                                                    }
                                                }
                                            }
                                        } catch {}
                                    }
                                }
                            }
                        }
                    }
                    finally {
                        # Limpieza del directorio temporal de auditoría
                        if (Test-Path $localAuditTemp) {
                            Remove-Item -Path $localAuditTemp -Recurse -Force -ErrorAction SilentlyContinue
                        }
                    }

                    # 7. Renderizado de resultados
                    if ($loginResults.Count -eq 0) {
                        Write-Host "`n[i] No se encontraron credenciales ni accesos guardados en los perfiles examinados de $computerTarget." -ForegroundColor Green
                    }
                    else {
                        Write-Host ("`n{0,-15} {1,-16} {2,-38} {3,-28} {4,-24}" -f "USUARIO PC", "NAVEGADOR", "DOMINIO / SITIO", "USUARIO ASOCIADO", "CATEGORIA SUGERIDA") -ForegroundColor Yellow
                        Write-Host ("-" * 125) -ForegroundColor Gray

                        foreach ($item in $loginResults) {
                            $dispUser = if ($item.UsuarioGuardado.Length -gt 26) { $item.UsuarioGuardado.Substring(0, 23) + "..." } else { $item.UsuarioGuardado }
                            $dispDomain = if ($item.Dominio.Length -gt 36) { $item.Dominio.Substring(0, 33) + "..." } else { $item.Dominio }
                            
                            Write-Host ("{0,-15} {1,-16} {2,-38} " -f $item.UsuarioLocal, $item.Navegador, $dispDomain) -NoNewline
                            Write-Host ("{0,-28} " -f $dispUser) -ForegroundColor Cyan -NoNewline
                            Write-Host ("{0,-24}" -f $item.Categoria) -ForegroundColor $item.Color
                        }

                        # Resumen consolidado
                        $totalSitios = $loginResults.Count
                        $blancasCount = ($loginResults | Where-Object { $_.Categoria -like "*BLANCA*" }).Count
                        $negrasCount = ($loginResults | Where-Object { $_.Categoria -like "*NEGRA*" }).Count
                        $sensiblesCount = ($loginResults | Where-Object { $_.Categoria -like "*SENSIBLE*" -or $_.Categoria -like "*RIESGO*" }).Count

                        Write-Host "`n--- RESUMEN DE SEGURIDAD Y CONTROL DE RED ---" -ForegroundColor Cyan
                        Write-Host "  Total de Accesos Guardados Identificados: $totalSitios" -ForegroundColor White
                        Write-Host "  Sitios en Lista Blanca sugerida (Institucionales/Productivos): $blancasCount" -ForegroundColor Green
                        Write-Host "  Sitios en Lista Negra sugerida (Ocio/Redes Sociales):         $negrasCount" -ForegroundColor Red
                        Write-Host "  Sitios Financieros o de Riesgo de Exfiltracion:              $sensiblesCount" -ForegroundColor Magenta

                        # 8. Opciones de Exportación
                        Write-Host "`n¿Desea exportar este reporte para administracion de red? (S/N) [N]: " -NoNewline -ForegroundColor Yellow
                        $respExport = Read-Host
                            $baseDir = if ($env:SCRIPT_PATH) { Split-Path $env:SCRIPT_PATH } elseif ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
                            $candidateRepDirs = @(
                                (Join-Path $baseDir "reportes"),
                                (if ($baseDir) { Join-Path (Split-Path $baseDir -ErrorAction SilentlyContinue) "reportes" }),
                                (Join-Path $baseDir "logs"),
                                (if ($baseDir) { Join-Path (Split-Path $baseDir -ErrorAction SilentlyContinue) "logs" }),
                                "C:\shellWil\reportes"
                            )
                            $repDir = $candidateRepDirs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path $_) } | Select-Object -First 1
                            if (-not $repDir) {
                                $repDir = Join-Path (if ($baseDir -and (Test-Path (Join-Path (Split-Path $baseDir) "ShellSW.bat"))) { Split-Path $baseDir } else { $baseDir }) "reportes"
                                if (-not (Test-Path $repDir)) {
                                    New-Item -ItemType Directory -Path $repDir -Force -ErrorAction SilentlyContinue | Out-Null
                                }
                            }
                            if (-not (Test-Path $repDir)) {
                                $repDir = "C:\shellWil\reportes"
                                if (-not (Test-Path $repDir)) {
                                    New-Item -ItemType Directory -Path $repDir -Force -ErrorAction SilentlyContinue | Out-Null
                                }
                            }
                            $timestampStr = Get-Date -Format 'yyyyMMdd_HHmmss'
                            $csvPath = Join-Path $repDir "Auditoria_Navegadores_${computerTarget}_${timestampStr}.csv"
                            $txtDominios = Join-Path $repDir "Listas_Dominios_${computerTarget}_${timestampStr}.txt"

                            # Exportar CSV
                            $loginResults | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -Force
                            Write-Host "[+] Reporte CSV guardado exitosamente en:" -ForegroundColor Green
                            Write-Host "    $csvPath" -ForegroundColor White

                            # Exportar listado de dominios clasificados para reglas de Firewall/Proxy
                            $dominiosUnicos = $loginResults | Select-Object -ExpandProperty Dominio -Unique | Sort-Object
                            $dominiosTexto = @"
# ==============================================================================
#   REPORTE DE DOMINIOS PARA REGLAS DE FIREWALL / PROXY (LISTAS BLANCAS / NEGRAS)
#   Equipo Auditado: $computerTarget ($IPFinal) | Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')
#   Generado por: ShellSW - Grupo 101 Credenciales Navegadores
# ==============================================================================

[DOMINIOS - SUGERENCIA LISTA BLANCA (PERMITIR)]
$($loginResults | Where-Object { $_.Categoria -like "*BLANCA*" -or $_.Categoria -like "*PRODUCTIVIDAD*" } | Select-Object -ExpandProperty Dominio -Unique | Out-String)

[DOMINIOS - SUGERENCIA LISTA NEGRA (BLOQUEAR / RESTRINGIR)]
$($loginResults | Where-Object { $_.Categoria -like "*NEGRA*" -or $_.Categoria -like "*RESTRINGIDO*" } | Select-Object -ExpandProperty Dominio -Unique | Out-String)

[DOMINIOS - AUDITORIA FINANCIERA Y RIESGO DE EXFILTRACION]
$($loginResults | Where-Object { $_.Categoria -like "*SENSIBLE*" -or $_.Categoria -like "*RIESGO*" } | Select-Object -ExpandProperty Dominio -Unique | Out-String)

[TODOS LOS DOMINIOS UNICOS IDENTIFICADOS]
$($dominiosUnicos | Out-String)
"@
                            $dominiosTexto | Out-File -FilePath $txtDominios -Encoding UTF8 -Force
                            Write-Host "[+] Archivo de reglas de red guardado en:" -ForegroundColor Green
                            Write-Host "    $txtDominios" -ForegroundColor White
                        }
                    }

                    Read-Host "`nPresione ENTER para continuar..."
                }

                "2" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: 101 ;;; Opcion: $op101 (Reporte Consolidado Listas Blancas/Negras)"
                    Write-Host "`n--- GENERADOR CONSOLIDADO DE REGLAS DE RED PARA FIREWALL / PROXY ---" -ForegroundColor Cyan
                    Write-Host "Esta opcion permite procesar el equipo remoto y generar directamente las directivas" -ForegroundColor Gray
                    Write-Host "en formatos compatibles con FortiGate, Squid, RouterOS (MikroTik) o Pi-hole." -ForegroundColor Gray
                    
                    $IPFinal = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($IPFinal)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    $computerTarget = $IPFinal
                    try {
                        $entry = [System.Net.Dns]::GetHostEntry($IPFinal)
                        $computerTarget = $entry.HostName.Split('.')[0]
                    } catch {}

                    Write-Host "`n[*] Extrayendo inventario de dominios desde perfiles remotos de $computerTarget..." -ForegroundColor Yellow
                    
                    Initialize-WinSqliteHelper
                    $usersDir = "\\$computerTarget\C$\Users"
                    if (-not (Test-Path $usersDir)) {
                        Write-Host "[-] No se pudo conectar a $usersDir. Verifique permisos y red." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    $userFolders = Get-ChildItem -Path $usersDir -Directory -ErrorAction SilentlyContinue | 
                        Where-Object { $_.Name -notmatch '^(Public|Default|Default User|All Users)$' }

                    $dominiosDetectados = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                    $auditGuid = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
                    $localAuditTemp = Join-Path $env:TEMP "ShellSW_Audit_$auditGuid"
                    New-Item -ItemType Directory -Path $localAuditTemp -Force -ErrorAction SilentlyContinue | Out-Null

                    try {
                        foreach ($uFolder in $userFolders) {
                            $browserUserDatas = @(
                                (Join-Path $uFolder.FullName "AppData\Local\Google\Chrome\User Data"),
                                (Join-Path $uFolder.FullName "AppData\Local\Microsoft\Edge\User Data"),
                                (Join-Path $uFolder.FullName "AppData\Local\BraveSoftware\Brave-Browser\User Data")
                            )
                            foreach ($bData in $browserUserDatas) {
                                if (Test-Path $bData) {
                                    $profileDirs = Get-ChildItem -Path $bData -Directory -ErrorAction SilentlyContinue | 
                                        Where-Object { $_.Name -eq "Default" -or $_.Name -like "Profile *" }
                                    foreach ($pDir in $profileDirs) {
                                        $loginDataFile = Join-Path $pDir.FullName "Login Data"
                                        if (Test-Path $loginDataFile) {
                                            $tmpDb = Join-Path $localAuditTemp "tmp_$([System.Guid]::NewGuid().ToString('N').Substring(0,6))"
                                            try {
                                                [System.IO.File]::Copy($loginDataFile, $tmpDb, $true)
                                                $entries = [WinSqliteReader]::ReadLogins($tmpDb)
                                                foreach ($e in $entries) {
                                                    if (-not [string]::IsNullOrWhiteSpace($e.OriginUrl)) {
                                                        $c = Get-DomainClassification -UrlOrDomain $e.OriginUrl
                                                        if ($c.Domain) { $dominiosDetectados.Add($c.Domain) | Out-Null }
                                                    }
                                                }
                                            } catch {}
                                            finally {
                                                if (Test-Path $tmpDb) { Remove-Item $tmpDb -Force -ErrorAction SilentlyContinue }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    finally {
                        if (Test-Path $localAuditTemp) { Remove-Item $localAuditTemp -Recurse -Force -ErrorAction SilentlyContinue }
                    }

                    Write-Host "`n[+] Total de dominios unicos extraidos: $($dominiosDetectados.Count)" -ForegroundColor Green
                    Write-Host "`n--- LISTA BLANCA SUGERIDA (Dominios Institucionales / Gubernamentales / Productivos) ---" -ForegroundColor Green
                    $lb = $dominiosDetectados | Where-Object { (Get-DomainClassification $_).Category -like "*BLANCA*" -or (Get-DomainClassification $_).Category -like "*PRODUCTIVIDAD*" }
                    if ($lb) { $lb | ForEach-Object { Write-Host "  + $_" -ForegroundColor Green } } else { Write-Host "  (Ninguno detectado)" -ForegroundColor Gray }

                    Write-Host "`n--- LISTA NEGRA SUGERIDA (Ocio / Redes Sociales / Streaming) ---" -ForegroundColor Red
                    $ln = $dominiosDetectados | Where-Object { (Get-DomainClassification $_).Category -like "*NEGRA*" -or (Get-DomainClassification $_).Category -like "*RESTRINGIDO*" }
                    if ($ln) { $ln | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red } } else { Write-Host "  (Ninguno detectado)" -ForegroundColor Gray }

                    Read-Host "`nPresione ENTER para continuar..."
                }

                "3" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: 101 ;;; Opcion: $op101 (Registro de Auditoria de Accesos)"
                    Write-Host "`n--- HISTORIAL DE ACCESOS Y REGISTROS DE AUDITORIA (GRUPO 101) ---" -ForegroundColor Yellow
                    
                    $baseDir = if ($env:SCRIPT_PATH) { Split-Path $env:SCRIPT_PATH } elseif ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
                    $candidateLogFiles = @(
                        (Join-Path $baseDir "logs\audit_101.log"),
                        (if ($baseDir) { Join-Path (Split-Path $baseDir -ErrorAction SilentlyContinue) "logs\audit_101.log" }),
                        (Join-Path (Get-Location).Path "logs\audit_101.log"),
                        "C:\shellWil\logs\audit_101.log"
                    )
                    $logFile = $candidateLogFiles | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path $_) } | Select-Object -First 1
                    if (-not $logFile) {
                        $logFile = "C:\shellWil\logs\audit_101.log"
                    }
                    if (Test-Path $logFile) {
                        Write-Host "`n[Bitacora Local: $logFile]" -ForegroundColor Cyan
                        Get-Content -Path $logFile -Tail 30 | ForEach-Object {
                            if ($_ -like "*DENEGADO*") {
                                Write-Host $_ -ForegroundColor Red
                            } elseif ($_ -like "*AUTORIZADO*") {
                                Write-Host $_ -ForegroundColor Green
                            } else {
                                Write-Host $_ -ForegroundColor Gray
                            }
                        }
                    } else {
                        Write-Host "`n[i] Aun no se ha generado la bitacora local $logFile." -ForegroundColor Gray
                    }

                    Write-Host "`n--- Eventos Recientes en Visor de Sucesos (Application / ShellSW) ---" -ForegroundColor Cyan
                    try {
                        $evs = Get-EventLog -LogName Application -Source "ShellSW" -Newest 15 -ErrorAction SilentlyContinue
                        if ($evs) {
                            foreach ($ev in $evs) {
                                $colorEv = if ($ev.EntryType -eq "Warning") { "Red" } else { "Green" }
                                Write-Host "  [$($ev.TimeGenerated.ToString('yyyy-MM-dd HH:mm:ss'))] EventID: $($ev.InstanceId) | $($ev.Message)" -ForegroundColor $colorEv
                            }
                        } else {
                            Write-Host "  (No se encontraron eventos previos de ShellSW en el Visor de Sucesos)" -ForegroundColor Gray
                        }
                    } catch {
                        Write-Host "  [!] No se pudieron leer eventos del registro de Windows: $_" -ForegroundColor DarkGray
                    }

                    Read-Host "`nPresione ENTER para continuar..."
                }

                "0" {
                    $salirSub101 = $true
                }

                Default {
                    Write-Host "Opcion invalida." -ForegroundColor Red
                    Start-Sleep -Seconds 1
                }
            }
        }
        catch {
            Write-Host "[-] ERROR: Ocurrio un fallo en el submenu de credenciales navegadores: $_" -ForegroundColor Red
            Read-Host "Presione ENTER para continuar..."
        }
    } while (-not $salirSub101)
}

# Ejecutar automáticamente al invocar el script
Invoke-AuditoriaNavegadores
