<# :
@echo off
:: Guardamos la ruta exacta antes de entrar a PowerShell, estos fragmentos son para que que powershell se ejecute en una extension .bat;; Script Híbrido (Polyglot)
set "SCRIPT_PATH=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((Get-Content -Encoding UTF8 '%~f0') -join [Environment]::NewLine)"
exit /b
#>

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

function psReconstruirSiDesarrollo {
    $ruta = $env:SCRIPT_PATH
    if ($ruta) {
        # Resolver el directorio padre
        $parentDir = Split-Path $ruta
        $buildScript = Join-Path $parentDir "build.ps1"
        if (Test-Path $buildScript) {
            Write-Host "`n[DEV] Entorno de desarrollo detectado." -ForegroundColor Yellow
            Write-Host "[DEV] Ejecutando build.ps1 para actualizar ShellSW.bat..." -ForegroundColor Yellow
            try {
                # Iniciar la reconstrucción de forma síncrona
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

    # --- HABILITACIÓN REMOTA DE ADMINISTRACIÓN ---
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

    # 1. Resolución de Hostname
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

    # 3. Construcción del Bloque de Comandos de Firewall y Servicios
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

    # A. Método 1: PsExec (Puerto SMB 445)
    $psexecPath = "C:\PSTools\PsExec.exe"
    $psexecFound = $false
    if (Test-Path $psexecPath) {
        $psexecFound = $true
    }
    else {
        $where = Get-Command psexec -ErrorAction SilentlyContinue
        if ($where) {
            $psexecPath = $where.Definition
            $psexecFound = $true
        }
    }

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

    # B. Método 2: WinRM / PSRemoting (WS-Man 5985)
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

    # C. Método 3: WMI (WMI 135)
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

    # 1. Resolución de Hostname
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
            $psexecPath = "C:\PSTools\PsExec.exe"
            $psexecFound = $false
            if (Test-Path $psexecPath) { $psexecFound = $true }
            else {
                if (Test-Path ".\PsExec.exe") { $psexecPath = ".\PsExec.exe"; $psexecFound = $true }
                else {
                    $where = Get-Command psexec -ErrorAction SilentlyContinue
                    if ($where) { $psexecPath = $where.Definition; $psexecFound = $true }
                }
            }

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

    # A. Método 1: WMI (WMI 135) - Muy compatible sin WinRM
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
                
                # Validar éxito considerando códigos de retorno especiales en WMI:
                # ChangeStartMode: 0 = Éxito. (Para dosvc a veces falla con 2 [Acceso Denegado] pero se corrige por WinRM/PsExec).
                # StartService: 0 = Éxito, 10 = Ya iniciado (también éxito para nuestro propósito).
                # StopService: 0 = Éxito, 5 = Detenido/No acepta control, 6 = No activo (también éxito).
                $isModeOk = ($resMode -eq 0)
                $isActOk = $false
                
                if ($act -eq "Start") {
                    $isActOk = ($resAct -eq 0 -or $resAct -eq 10)
                }
                elseif ($act -eq "Stop") {
                    $isActOk = ($resAct -eq 0 -or $resAct -eq 5 -or $resAct -eq 6)
                }
                else {
                    $isActOk = $true # Acción "None"
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

    # B. Método 2: WinRM / PSRemoting (WinRM 5985)
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

    # C. Método 3: PsExec (SMB 445)
    if (-not $exito) {
        Write-Host "`n[*] WinRM no disponible. Intentando via PsExec (SMB)..." -ForegroundColor Yellow
        
        $psexecPath = "C:\PSTools\PsExec.exe"
        $psexecFound = $false
        if (Test-Path $psexecPath) {
            $psexecFound = $true
        }
        else {
            if (Test-Path ".\PsExec.exe") {
                $psexecPath = ".\PsExec.exe"
                $psexecFound = $true
            }
            else {
                $where = Get-Command psexec -ErrorAction SilentlyContinue
                if ($where) {
                    $psexecPath = $where.Definition
                    $psexecFound = $true
                }
            }
        }

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
# MODULO: INFORMACION DEL USUARIO ACTIVO (LOCAL Y DE DOMINIO)
#**********************************************************************************************************************************

function psMostrarInformacionUsuarioActivo {
    <#
    .SYNOPSIS
        Consulta y muestra en consola la información del usuario activo (local o de dominio)
        en un equipo remoto o local, respetando el formato visual y paleta de colores estándar.
    .PARAMETER TargetIP
        Dirección IP o Nombre de Equipo (Hostname) a consultar.
    .PARAMETER Credential
        Credencial opcional para autenticación en WMI/CIM.
    .PARAMETER TimeoutMs
        Tiempo de espera para comprobación de red previa.
    .PARAMETER ForceRefresh
        Fuerza la consulta ignorando la caché en memoria de la sesión.
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

    # Inicializar almacenamiento de caché de sesión si no existe
    if (-not $global:ActiveUserCache) {
        $global:ActiveUserCache = @{}
    }

    # Verificar si tenemos datos en caché válidos (vigencia de 45 segundos)
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

    # 1. Verificación rápida de conectividad en destinos remotos para evitar cuelgues (timeout 600ms)
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

    # 2. Resolución de Hostname y Datos de Dominio
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

    # 3. Detección del Usuario Activo
    $usuariosActivos = @()

    # Método A: Procesos explorer.exe interactivos vía WMI
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

    # Método B: Fallback a Win32_ComputerSystem.UserName
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

    # Método C: Fallback rápido mediante quser
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

    # Descartar duplicados manteniendo los únicos
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

    # 4. Caso: Sin sesión interactiva activa
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

    # 6. Procesar y presentar la información de cada usuario activo
    $lastResultObj = $null

    foreach ($u in $usuariosActivos) {
        $esLocal = ($u.Domain.ToUpper() -eq $targetHost.ToUpper()) -or 
                   ($u.Domain -eq ".") -or 
                   ([string]::IsNullOrEmpty($u.Domain)) -or 
                   (-not $partOfDomain)

        # Resolución de Nombre Completo
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

        # Resolución de Tipo de Cuenta
        $tipoCuenta = ""
        if ($esLocal) {
            $tipoCuenta = "Usuario Local (.\$($u.User))"
        } else {
            $nombreDominio = if ($domainFQDN) { $domainFQDN } elseif ($u.Domain) { $u.Domain } else { "Dominio" }
            $tipoCuenta = "Usuario de Dominio ($nombreDominio)"
        }

        # Resolución de Ruta de Perfil
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

        # Almacenar en caché de sesión
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

# ==============================================================================
#   HELPERS GRUPO 101: CREDENCIALES NAVEGADORES (AUDITORIA Y SEGURIDAD)
# ==============================================================================

function Initialize-WinSqliteHelper {
    <#
    .SYNOPSIS
        Inicializa en memoria el lector SQLite nativo (WinSqliteReader) utilizando
        la librería winsqlite3.dll incorporada en Windows sin dependencias externas.
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
        Analiza una URL o dominio y devuelve su clasificación sugerida para
        políticas de administración de red (Listas Blancas, Listas Negras, Ocio, etc.).
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
        Asienta el registro de auditoría de acceso al Grupo 101 tanto en el
        Visor de Eventos de Windows (EventLog) como en una bitácora local dedicada.
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
        $logDir = "C:\shellWil\logs"
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue | Out-Null
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


# =========================================================================================
# FUNCIONES AUXILIARES Y MODULARES PARA EL GRUPO 19: FORMATEO Y PREPARACION DE DISCOS / USB
# =========================================================================================

function Get-SafeDiskList {
    <#
    .SYNOPSIS
        Obtiene la lista de discos físicos conectados con detección segura del disco del sistema.
    #>
    $systemDiskNum = -1
    try {
        $sysDrive = $env:SystemDrive.Replace(":", "")
        if (Get-Command Get-Partition -ErrorAction SilentlyContinue) {
            $sysPart = Get-Partition -DriveLetter $sysDrive -ErrorAction SilentlyContinue
            if ($sysPart) { $systemDiskNum = $sysPart.DiskNumber }
        }
    } catch {}

    $list = @()
    if (Get-Command Get-Disk -ErrorAction SilentlyContinue) {
        try {
            $disks = Get-Disk | Sort-Object Number
            foreach ($d in $disks) {
                $isSys = ($d.Number -eq $systemDiskNum)
                $sizeGB = [Math]::Round($d.Size / 1GB, 2)
                $bus = if ($d.BusType) { $d.BusType.ToString() } else { "Desconocido" }
                $media = if ($bus -eq "USB") { "USB/Extraible" } else { "Fijo" }
                $list += [PSCustomObject]@{
                    Number            = $d.Number
                    FriendlyName      = $d.FriendlyName
                    BusType           = $bus
                    MediaType         = $media
                    SizeGB            = $sizeGB
                    PartitionStyle    = $d.PartitionStyle.ToString()
                    HealthStatus      = $d.HealthStatus.ToString()
                    OperationalStatus = $d.OperationalStatus.ToString()
                    IsSystem          = $isSys
                }
            }
            return $list
        } catch {}
    }

    # Fallback WMI Win32_DiskDrive (Compatibilidad Win 7)
    try {
        $wmiDisks = Get-WmiObject Win32_DiskDrive | Sort-Object Index
        foreach ($wd in $wmiDisks) {
            $idx = [int]$wd.Index
            $isSys = ($idx -eq $systemDiskNum)
            $sizeGB = if ($wd.Size) { [Math]::Round($wd.Size / 1GB, 2) } else { 0 }
            $bus = if ($wd.InterfaceType) { $wd.InterfaceType } else { "Desconocido" }
            $list += [PSCustomObject]@{
                Number            = $idx
                FriendlyName      = $wd.Caption
                BusType           = $bus
                MediaType         = (if ($bus -match "USB") { "USB/Extraible" } else { "Fijo" })
                SizeGB            = $sizeGB
                PartitionStyle    = "N/D"
                HealthStatus      = $wd.Status
                OperationalStatus = "Online"
                IsSystem          = $isSys
            }
        }
    } catch {}
    return $list
}

function Invoke-DiskpartBatch {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Commands
    )
    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        $Commands | Out-File -FilePath $tempFile -Encoding ascii
        Write-Host "`n------------------------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host " [DISKPART] Ejecutando secuencia de comandos por lotes:" -ForegroundColor Cyan
        foreach ($c in $Commands) {
            if ($c -and $c -ne "exit") {
                Write-Host "   > $c" -ForegroundColor DarkGray
            }
        }
        Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor DarkGray

        $output = & diskpart.exe /s "$tempFile" 2>&1
        $hasFatalError = $false
        foreach ($line in $output) {
            $lineStr = "$line".Trim()
            if (-not $lineStr) { continue }
            if ($lineStr -match "error de|código de error|no se puede|denegado|no es válido|demasiado largo|incorrecto|demasiado grande|error del servicio|falló") {
                Write-Host "  [Diskpart] $lineStr" -ForegroundColor Red
                $hasFatalError = $true
            }
            elseif ($lineStr -match "100 por ciento completado|correctamente|satisfactoriamente|formateó|asignó") {
                Write-Host "  [Diskpart] $lineStr" -ForegroundColor Green
            }
            elseif ($lineStr -match "por ciento completado") {
                Write-Host "  [Diskpart] $lineStr" -ForegroundColor Yellow
            }
            else {
                Write-Host "  [Diskpart] $lineStr" -ForegroundColor Gray
            }
        }

        if ($LASTEXITCODE -ne 0 -or $hasFatalError) {
            return 1
        }
        return 0
    }
    catch {
        Write-Host "`n[ERROR AL INVOCAR DISKPART]: $_" -ForegroundColor Red
        return 1
    }
    finally {
        if (Test-Path $tempFile) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function Show-FormatBootMatrix {
    cabecera
    Write-Header "OPCION 19.0: TABLA DE RELACION - FILESYSTEM vs PARTICION vs MODO DE ARRANQUE"

    Write-Host "`n==========================================================================================" -ForegroundColor Cyan
    Write-Host "               MATRIZ DE COMPATIBILIDAD PARA INSTALACION DE SISTEMAS OPERATIVOS            " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Cyan

    $matrix = @(
        [PSCustomObject]@{
            "Modo Arranque"  = "Legacy BIOS (CSM)"
            "Particion"      = "MBR"
            "FS Arranque"    = "NTFS / FAT32"
            "FS Sistema(C:)" = "NTFS"
            "Activa?"        = "SI (Req.)"
            "Max Disco"      = "<= 2.0 TB"
            "Lim. Archivo"   = "NTFS: Ilim. | FAT: 4GB"
            "Sec.Boot"       = "NO"
        },
        [PSCustomObject]@{
            "Modo Arranque"  = "UEFI Nativo"
            "Particion"      = "GPT"
            "FS Arranque"    = "FAT32 (ESP/EFI)"
            "FS Sistema(C:)" = "NTFS"
            "Activa?"        = "NO (Usa GUID)"
            "Max Disco"      = "> 2TB (18 EB)"
            "Lim. Archivo"   = "NTFS: Ilim. | FAT: 4GB"
            "Sec.Boot"       = "SI"
        },
        [PSCustomObject]@{
            "Modo Arranque"  = "USB Inst. BIOS"
            "Particion"      = "MBR"
            "FS Arranque"    = "NTFS / FAT32"
            "FS Sistema(C:)" = "N/A (Medio)"
            "Activa?"        = "SI (bootsect)"
            "Max Disco"      = "<= 2.0 TB"
            "Lim. Archivo"   = "NTFS soporta wim > 4GB"
            "Sec.Boot"       = "NO"
        },
        [PSCustomObject]@{
            "Modo Arranque"  = "USB Inst. UEFI"
            "Particion"      = "GPT o MBR"
            "FS Arranque"    = "FAT32 (UEFI)"
            "FS Sistema(C:)" = "N/A (Medio)"
            "Activa?"        = "NO (No req.)"
            "Max Disco"      = "Cualquiera"
            "Lim. Archivo"   = "FAT32 max 4GB (split)"
            "Sec.Boot"       = "SI"
        },
        [PSCustomObject]@{
            "Modo Arranque"  = "Almacen. exFAT"
            "Particion"      = "MBR o GPT"
            "FS Arranque"    = "No Booteable"
            "FS Sistema(C:)" = "No Windows"
            "Activa?"        = "No Aplica"
            "Max Disco"      = "Hasta 128PB"
            "Lim. Archivo"   = "16 EB (Ideal datos)"
            "Sec.Boot"       = "N/A"
        }
    )

    $matrix | Format-Table -AutoSize

    Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[REGLAS DE ORO PARA EL TECNICO / ADMINISTRADOR DE SISTEMAS]:" -ForegroundColor White
    Write-Host " 1. LEGACY BIOS (MBR):" -ForegroundColor Cyan
    Write-Host "    - Windows requiere obligatoriamente que la particion donde reside BOOTMGR este marcada como ACTIVA." -ForegroundColor Gray
    Write-Host "    - En discos MBR, si la particion no es 'Active' o no tiene codigo MBR ('bootsect /nt60 X: /mbr'), la BIOS dira 'No bootable device'." -ForegroundColor Gray
    Write-Host "    - El limite maximo de direccionamiento de sectores en MBR es de 2 TB (con sectores de 512 bytes)." -ForegroundColor Gray

    Write-Host "`n 2. UEFI NATIVO (GPT):" -ForegroundColor Cyan
    Write-Host "    - No existe el concepto de particion 'Activa' en tablas GPT. El firmware busca la particion EFI System (ESP) formateada en FAT32." -ForegroundColor Gray
    Write-Host "    - Requiere archivos en \EFI\BOOT\BOOTX64.EFI. Soporta discos de mas de 2 TB y arranque seguro (Secure Boot)." -ForegroundColor Gray
    Write-Host "    - Windows 11 exige obligatoriamente UEFI + GPT + TPM 2.0 + Secure Boot." -ForegroundColor Gray

    Write-Host "`n 3. PROBLEMA FRECUENTE CON USB UEFI Y FAT32 (install.wim > 4 GB):" -ForegroundColor Cyan
    Write-Host "    - Como el estandar UEFI exige FAT32 para arrancar, y Windows 10/11 moderno incluye 'install.wim' de mas de 4 GB:" -ForegroundColor Gray
    Write-Host "      a) Solucion oficial: Dividir el WIM con: dism /Split-Image /ImageFile:install.wim /SWMFile:install.swm /FileSize:3800" -ForegroundColor Yellow
    Write-Host "      b) Solucion de particion dual: 1 particion pequena FAT32 (arranque UEFI) + 1 particion NTFS (imagen completa)." -ForegroundColor Yellow
    Write-Host "      c) Driver UEFI:NTFS (Rufus): Carga un driver NTFS firmado en memoria para arrancar directamente en NTFS." -ForegroundColor Yellow

    Write-Host "`n 4. SISTEMA DE ARCHIVOS exFAT:" -ForegroundColor Cyan
    Write-Host "    - Disenado para pendrives y discos externos de alta capacidad. Supera el limite de 4 GB de FAT32 sin permisos complejos NTFS." -ForegroundColor Gray
    Write-Host "    - Maxima compatibilidad entre Windows, macOS, Linux, Smart TVs y consolas. NO permite instalar Windows C: sobre el." -ForegroundColor Gray
    Write-Host "==========================================================================================`n" -ForegroundColor Cyan
}

function Show-DiskTechnicalDetails {
    cabecera
    Write-Header "OPCION 19.1: INFORMACION TECNICA DETALLADA DE LA UNIDAD DE ALMACENAMIENTO"

    $discos = Get-SafeDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron unidades de almacenamiento en el equipo." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES DETECTADAS EN EL SISTEMA ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        $etiquetaSys = if ($d.IsSystem) { " [SISTEMA OPERATIVO C:]" } else { "" }
        $color = if ($d.IsSystem) { "Magenta" } elseif ($d.MediaType -match "USB") { "Green" } else { "White" }
        Write-Host ("  [Disco {0}] {1} | Bus: {2} | Tipo: {3} | Tamano: {4} GB | Particion: {5}{6}" -f $d.Number, $d.FriendlyName, $d.BusType, $d.MediaType, $d.SizeGB, $d.PartitionStyle, $etiquetaSys) -ForegroundColor $color
    }

    Write-Host ""
    $sel = Read-Host "Ingrese el numero de Disco para ver su ficha tecnica completa (o '0' para volver)"
    if ($null -eq $sel -or $sel -notmatch '^\d+$' -or $sel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$sel
    $targetDisk = $discos | Where-Object { $_.Number -eq $discoIndex }
    if ($null -eq $targetDisk) {
        Write-Host "[ERROR] El disco $discoIndex no existe en la lista." -ForegroundColor Red
        return
    }

    Write-Host "`n==========================================================================================" -ForegroundColor Cyan
    Write-Host "                     FICHA TECNICA DETALLADA: DISCO FISICO $discoIndex                     " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Cyan

    # 1. Datos físicos vía WMI / Storage
    $wmiDisk = Get-WmiObject Win32_DiskDrive | Where-Object { $_.Index -eq $discoIndex }
    if ($wmiDisk) {
        Write-Host " [DATOS DE FABRICANTE Y HARDWARE]" -ForegroundColor White -BackgroundColor DarkBlue
        Write-Host "  Modelo/Caption       : $($wmiDisk.Caption)"
        Write-Host "  Fabricante           : $($wmiDisk.Manufacturer)"
        Write-Host "  Numero de Serie      : $(if ($wmiDisk.SerialNumber) { $wmiDisk.SerialNumber.Trim() } else { 'N/D' })"
        Write-Host "  Firmware Revision    : $($wmiDisk.FirmwareRevision)"
        Write-Host "  Interfaz / Bus       : $($targetDisk.BusType)"
        Write-Host "  Tipo de Medio        : $($targetDisk.MediaType)"
        Write-Host "  Capacidad Total      : $([Math]::Round($wmiDisk.Size / 1GB, 2)) GB ($($wmiDisk.Size) bytes)"
        Write-Host "  Sectores Logicos/Fis.: $($wmiDisk.BytesPerSector) bytes / sector"
        Write-Host "  Total Cilindros/Cab. : Cilindros: $($wmiDisk.TotalCylinders) | Cabezas: $($wmiDisk.TotalHeads) | Sectores: $($wmiDisk.TotalSectors)"
    }

    # 2. S.M.A.R.T. y Fiabilidad (PowerShell 8+)
    if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
        $pDisk = Get-PhysicalDisk | Where-Object { $_.DeviceId -eq "$discoIndex" }
        if ($pDisk) {
            Write-Host "`n [ESTADO DE SALUD Y METRICAS S.M.A.R.T.]" -ForegroundColor White -BackgroundColor DarkBlue
            Write-Host "  Estado Operativo     : $($pDisk.OperationalStatus)"
            Write-Host "  Salud S.M.A.R.T.      : $($pDisk.HealthStatus)"
            try {
                $counter = $pDisk | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
                if ($counter) {
                    Write-Host "  Temperatura          : $(if ($counter.Temperature) { "$($counter.Temperature) C" } else { 'N/D' })"
                    Write-Host "  Desgaste (Wear %)    : $(if ($counter.Wear -ne $null) { "$($counter.Wear) %" } else { 'N/D' })"
                    Write-Host "  Horas de Uso (POH)   : $(if ($counter.PowerOnHours) { "$($counter.PowerOnHours) hrs" } else { 'N/D' })"
                    Write-Host "  Errores de Lectura   : $($counter.ReadErrorsTotal)"
                    Write-Host "  Errores de Escritura : $($counter.WriteErrorsTotal)"
                }
            } catch {}
        }
    }

    # 3. Topología de Particiones
    Write-Host "`n [TOPOLOGIA DE PARTICIONES DETECTADAS]" -ForegroundColor White -BackgroundColor DarkBlue
    if (Get-Command Get-Partition -ErrorAction SilentlyContinue) {
        $particiones = Get-Partition -DiskNumber $discoIndex -ErrorAction SilentlyContinue
        if ($particiones) {
            foreach ($p in $particiones) {
                $tamMB = [Math]::Round($p.Size / 1MB, 2)
                $letra = if ($p.DriveLetter) { "$($p.DriveLetter):" } else { "Sin Letra" }
                $activa = if ($p.IsActive -ne $null) { $p.IsActive } else { "N/A" }
                Write-Host ("  -> Particion #{0} | Tipo: {1} | Tamano: {2} MB | Letra: {3} | Activa: {4}" -f $p.PartitionNumber, $p.Type, $tamMB, $letra, $activa) -ForegroundColor Cyan
            }
        } else {
            Write-Host "  No se detectaron particiones estructuradas en este disco." -ForegroundColor Gray
        }
    } else {
        $wmiParts = Get-WmiObject Win32_DiskPartition | Where-Object { $_.DiskIndex -eq $discoIndex }
        if ($wmiParts) {
            foreach ($wp in $wmiParts) {
                Write-Host ("  -> Particion #{0} | Tipo: {1} | Tamano: {2} MB | Bootable: {3}" -f $wp.Index, $wp.Type, [Math]::Round($wp.Size / 1MB, 2), $wp.Bootable) -ForegroundColor Cyan
            }
        }
    }

    # 4. Volúmenes y Sistemas de Archivos
    Write-Host "`n [VOLUMENES LOGICOS ASOCIADOS]" -ForegroundColor White -BackgroundColor DarkBlue
    $volFound = $false
    if (Get-Command Get-Partition -ErrorAction SilentlyContinue) {
        $partsConLetra = Get-Partition -DiskNumber $discoIndex -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter }
        foreach ($pcl in $partsConLetra) {
            $vol = Get-Volume -DriveLetter $pcl.DriveLetter -ErrorAction SilentlyContinue
            if ($vol) {
                $volFound = $true
                $tGB = [Math]::Round($vol.Size / 1GB, 2)
                $rGB = [Math]::Round($vol.SizeRemaining / 1GB, 2)
                $pctLibre = if ($vol.Size -gt 0) { [Math]::Round(($vol.SizeRemaining / $vol.Size) * 100, 1) } else { 0 }
                Write-Host ("  Unidad [{0}:] Etiqueta: '{1}' | FS: {2} | Capacidad: {3} GB | Libre: {4} GB ({5}%)" -f $vol.DriveLetter, $vol.FileSystemLabel, $vol.FileSystem, $tGB, $rGB, $pctLibre) -ForegroundColor Green
            }
        }
    }
    if (-not $volFound) {
        Write-Host "  No hay letras de volumen montadas actualmente para este disco." -ForegroundColor Gray
    }

    Write-Host "==========================================================================================`n" -ForegroundColor Cyan
}

function Invoke-DiskSurfaceCheck {
    cabecera
    Write-Header "OPCION 19.2: VERIFICACION Y REVISION DE SUPERFICIE / SECTORES DE DISCO"

    Write-Host "`n--- UNIDADES LOGICAS DETECTADAS ---" -ForegroundColor Cyan
    $unidades = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 -or $_.DriveType -eq 3 }
    if ($null -eq $unidades) {
        Write-Host "[ERROR] No se encontraron unidades de almacenamiento validas." -ForegroundColor Red
        return
    }

    foreach ($u in $unidades) {
        $tamanoGB = if ($u.Size) { [Math]::Round($u.Size / 1GB, 2) } else { "N/D" }
        $libreGB = if ($u.FreeSpace) { [Math]::Round($u.FreeSpace / 1GB, 2) } else { "N/D" }
        $tipo = if ($u.DriveType -eq 2) { "USB/Extraible" } else { "Disco Local" }
        $esC = if ($u.DeviceID -eq $env:SystemDrive) { " [SISTEMA OPERATIVO]" } else { "" }
        Write-Host ("  -> Unidad: [{0}] | Tipo: {1} | FS: {2} | Etiqueta: {3} | Tamano: {4} GB | Libre: {5} GB{6}" -f $u.DeviceID, $tipo, $u.FileSystem, $u.VolumeName, $tamanoGB, $libreGB, $esC) -ForegroundColor Green
    }

    Write-Host "`n------------------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host " [0] DESCARTAR / CANCELAR (Volver al menu anterior)" -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor DarkGray

    $entrada = (Read-Host "Ingrese la letra de la unidad a examinar (Ej: D o D:) o '0' para descartar").Trim().ToUpper()

    if ($entrada -eq "0" -or $entrada -eq "C" -or $entrada -eq "CANCELAR" -or $entrada -eq "") {
        Write-Host "`n[INFO] Operacion descartada por el usuario. Regresando al menu anterior..." -ForegroundColor Yellow
        return
    }

    $letra = if ($entrada -match '^[A-Z]:$') { $entrada } elseif ($entrada -match '^[A-Z]$') { "$entrada" + ":" } else { "" }
    if ($letra -eq "") {
        Write-Host "[ERROR] Formato de letra no valido." -ForegroundColor Red
        return
    }

    $unidadSel = $unidades | Where-Object { $_.DeviceID -eq $letra }
    if ($null -eq $unidadSel) {
        Write-Host "[ERROR] La unidad $letra no existe en el sistema." -ForegroundColor Red
        return
    }

    Write-Host "`n--- SELECCIONE EL TIPO DE REVISION PARA LA UNIDAD $letra ---" -ForegroundColor Cyan
    Write-Host "  1. REVISION SUPERFICIAL (Rapida - Metadatos, indices y estructura de archivos)" -ForegroundColor White
    Write-Host "     * Analiza el sistema de archivos en pocos segundos/minutos sin desmontar la unidad."
    Write-Host "  2. REVISION PROFUNDA (Exhaustiva - Superficie completa y recuperacion de sectores danados)" -ForegroundColor White
    Write-Host "     * Ejecuta chkdsk /f /r /x. Busca sectores defectuosos (Bad Sectors) y repara errores."
    Write-Host "     * NOTA: Este proceso puede tomar bastante tiempo segun la velocidad y tamano del disco."
    Write-Host "  0. DESCARTAR y volver al menu anterior" -ForegroundColor Yellow

    $tipoScan = Read-Host "`nSeleccione el nivel de revision (1, 2 o 0)"

    if ($tipoScan -eq "0" -or $tipoScan -eq "") {
        Write-Host "[INFO] Analisis cancelado. Regresando al menu anterior..." -ForegroundColor Yellow
        return
    }

    if ($letra -eq $env:SystemDrive) {
        Write-Host "`n[ADVERTENCIA CRITICA] La unidad seleccionada es la del Sistema Operativo Windows ($letra)." -ForegroundColor Magenta
        if ($tipoScan -eq "2") {
            Write-Host "Windows no puede desmontar el disco C: en vivo para una revision profunda con /r." -ForegroundColor Yellow
            $respC = Read-Host "Desea programar el analisis CHKDSK /F /R para el proximo reinicio del equipo? (S/N)"
            if ($respC.ToUpper() -eq "S") {
                chkdsk.exe $letra /f /r
                Write-Host "`n[OK] Analisis profundo programado para el proximo reinicio." -ForegroundColor Green
            } else {
                Write-Host "Operacion cancelada por el usuario." -ForegroundColor Yellow
            }
            return
        }
    }

    switch ($tipoScan) {
        "1" {
            Write-Host "`nIniciando Revision Superficial de la unidad $letra..." -ForegroundColor Cyan
            try {
                if (Get-Command Repair-Volume -ErrorAction SilentlyContinue) {
                    Write-Host "Ejecutando: Repair-Volume -DriveLetter $($letra.Replace(':','')) -Scan" -ForegroundColor Gray
                    Repair-Volume -DriveLetter ($letra.Replace(":", "")) -Scan
                } else {
                    Write-Host "Ejecutando: chkdsk.exe $letra /scan" -ForegroundColor Gray
                    chkdsk.exe $letra /scan
                }
                Write-Host "`n[EXITO] Revision superficial finalizada en $letra." -ForegroundColor Green
            } catch {
                Write-Host "`n[ERROR OCURRIDO]: $_" -ForegroundColor Red
            }
        }
        "2" {
            Write-Host "`n==========================================================================================" -ForegroundColor Red
            Write-Host " ADVERTENCIA: SE DESMONTARA TEMPORALMENTE LA UNIDAD $letra PARA EL ANALISIS PROFUNDO" -ForegroundColor Yellow
            Write-Host "==========================================================================================" -ForegroundColor Red
            $conf = Read-Host "Confirma iniciar el escaneo exhaustivo de superficie en $letra? (S/N)"
            if ($conf.ToUpper() -ne "S") {
                Write-Host "Revision profunda cancelada." -ForegroundColor Yellow
                return
            }

            Write-Host "`nEjecutando: chkdsk.exe $letra /f /r /x" -ForegroundColor Cyan
            Write-Host "Por favor espere mientras Windows analiza la superficie del disco...`n" -ForegroundColor Yellow
            try {
                & chkdsk.exe $letra /f /r /x
                Write-Host "`n[EXITO] Revision profunda de sectores finalizada en la unidad $letra." -ForegroundColor Green
            } catch {
                Write-Host "`n[ERROR OCURRIDO]: $_" -ForegroundColor Red
            }
        }
        Default {
            Write-Host "Opcion de revision no valida. Operacion abortada." -ForegroundColor Yellow
        }
    }
}

function Format-DiskStorageMBR {
    cabecera
    Write-Header "OPCION 19.3: PREPARAR DISCO PARA WINDOWS LEGACY (MBR + FAT32/NTFS - PARTICION ACTIVA)"

    $discos = Get-SafeDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron discos en el sistema." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES FISICAS DISPONIBLES ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        $etiquetaSys = if ($d.IsSystem) { " [SISTEMA OPERATIVO C: - PROTEGIDO]" } else { "" }
        $color = if ($d.IsSystem) { "Magenta" } elseif ($d.MediaType -match "USB") { "Green" } else { "White" }
        Write-Host ("  [Disco {0}] {1} | Bus: {2} | Capacidad: {3} GB | Particion: {4}{5}" -f $d.Number, $d.FriendlyName, $d.BusType, $d.SizeGB, $d.PartitionStyle, $etiquetaSys) -ForegroundColor $color
    }

    Write-Host "`n[0] CANCELAR y volver al menu anterior" -ForegroundColor Yellow
    $discoSel = Read-Host "`nIngrese el numero de disco a preparar en MBR"
    if ($null -eq $discoSel -or $discoSel -notmatch '^\d+$' -or $discoSel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$discoSel
    $targetDisk = $discos | Where-Object { $_.Number -eq $discoIndex }
    if ($null -eq $targetDisk) {
        Write-Host "[ERROR] El disco $discoIndex no existe en el sistema." -ForegroundColor Red
        return
    }

    if ($targetDisk.IsSystem) {
        Write-Host "`n[BLOQUEO DE SEGURIDAD CRITICO] El Disco $discoIndex contiene el Sistema Operativo actual." -ForegroundColor Red
        Write-Host "No esta permitido formatear la unidad donde corre el script." -ForegroundColor Red
        return
    }

    # 1. Selección de Filesystem
    Write-Host "`n--- SELECCION DE SISTEMA DE ARCHIVOS (MBR / WINDOWS) ---" -ForegroundColor Cyan
    Write-Host "  1. NTFS  (Recomendado para Windows Vista / 7 / 8 / 10 / 11 en BIOS Legacy - Archivos sin limite)"
    Write-Host "  2. FAT32 (Compatible con S.O. clasicos: Windows 98 / Windows XP o herramientas MS-DOS/WinPE)"
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $fsOpt = Read-Host "`nElija el sistema de archivos (1 o 2)"
    $fs = switch ($fsOpt) {
        "1" { "ntfs" }
        "2" { "fat32" }
        Default { "" }
    }
    if ($fs -eq "") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    if ($fs -eq "fat32" -and $targetDisk.SizeGB -gt 32) {
        Write-Host "`n[AVISO TECNICO] Ha seleccionado FAT32 para un disco de $($targetDisk.SizeGB) GB." -ForegroundColor Yellow
        Write-Host "Windows y Diskpart tienen un limite nativo de 32 GB para FAT32. Para discos mayores a 32 GB en FAT32, se recomienda usar la opcion 19.6 (almacenamiento multiparticion) o NTFS." -ForegroundColor Gray
    }

    # 2. Selección de Modo de Formateo
    Write-Host "`n--- MODO DE FORMATEO ---" -ForegroundColor Cyan
    Write-Host "  1. Formateo RAPIDO (quick - inicializa tablas de particion en segundos)"
    Write-Host "  2. Formateo PROFUNDO (Escribe ceros y comprueba cada sector fisico de la unidad)"
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $modoOpt = Read-Host "`nElija el modo de formateo (1 o 2)"
    $paramQuick = switch ($modoOpt) {
        "1" { "quick" }
        "2" { "" }
        Default { "CANCEL" }
    }
    if ($paramQuick -eq "CANCEL") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    $labelInput = Read-Host "`nIngrese una etiqueta de volumen (Presione ENTER para 'WIN_MBR')"
    $etiqueta = if ($labelInput.Trim()) { $labelInput.Trim().Replace(" ", "_") -replace '[^\w\-]', '' } else { "WIN_MBR" }
    if ($fs -eq "fat32" -and $etiqueta.Length -gt 11) {
        $etiqueta = $etiqueta.Substring(0, 11)
    }

    # 3. Confirmación estricta de seguridad
    Write-Host "`n==========================================================================================" -ForegroundColor Red
    Write-Host "                       ADVERTENCIA CRITICA DE ELIMINACION DE DATOS                        " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red
    Write-Host " Se eliminaran TODAS las particiones y datos del siguiente dispositivo:" -ForegroundColor White
    Write-Host "  - Disco Objetivo  : [Disco $discoIndex] $($targetDisk.FriendlyName)" -ForegroundColor Yellow
    Write-Host "  - Capacidad       : $($targetDisk.SizeGB) GB ($($targetDisk.BusType))" -ForegroundColor Yellow
    Write-Host "  - Esquema         : MBR (Particion Primaria Unica - ACTIVA)" -ForegroundColor Yellow
    Write-Host "  - Sistema Archivos: $($fs.ToUpper()) ($etiqueta)" -ForegroundColor Yellow
    Write-Host "  - Modo Formateo   : $(if ($paramQuick -eq 'quick') { 'RAPIDO' } else { 'PROFUNDO' })" -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red

    $confirmacion = Read-Host "Para PROCEDER escriba exactamente 'CONFIRMAR'"
    if ($confirmacion.Trim().ToUpper() -ne "CONFIRMAR") {
        Write-Host "Confirmacion denegada. Proceso abortado de manera segura." -ForegroundColor Yellow
        return
    }

    # 4. Generación y ejecución de script Diskpart
    $diskpartCmds = @(
        "select disk $discoIndex",
        "clean",
        "convert mbr",
        "create partition primary",
        "select partition 1",
        "active",
        "format fs=$fs $paramQuick label=`"$etiqueta`"",
        "assign",
        "exit"
    )

    $exitCode = Invoke-DiskpartBatch -Commands $diskpartCmds
    if ($exitCode -eq 0) {
        Write-Host "`n[EXITO] El disco $discoIndex ha sido formateado en MBR y su particion esta ACTIVA." -ForegroundColor Green

        if ($fs -eq "ntfs") {
            # Inyectar código BOOTMGR si bootsect existe (solo NT60 para Windows Vista/7/8/10/11)
            try {
                $nuevoVol = Get-Partition -DiskNumber $discoIndex -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter } | Select-Object -First 1
                if ($nuevoVol -and (Get-Command bootsect.exe -ErrorAction SilentlyContinue)) {
                    $driveL = "$($nuevoVol.DriveLetter):"
                    Write-Host "Inyectando cargador maestro BOOTMGR (NT60) con bootsect en $driveL..." -ForegroundColor Cyan
                    & bootsect.exe /nt60 $driveL /mbr
                    Write-Host "[OK] Codigo BOOTMGR instalado con exito." -ForegroundColor Green
                }
            } catch {}
        } else {
            Write-Host "Sector de arranque MBR activo preparado sin sobrescritura de NT60 (ideal para Win 98 / XP / MS-DOS)." -ForegroundColor Cyan
        }

        Write-Host "`nEl disco esta listo para uso y preparado para arranque en sistemas Legacy BIOS." -ForegroundColor Cyan
    } else {
        Write-Host "`n[ERROR] Diskpart concluyo con codigo de error: $exitCode" -ForegroundColor Red
    }
}

function Format-DiskStorageGPT {
    cabecera
    Write-Header "OPCION 19.4: PREPARAR DISCO PARA WINDOWS UEFI (GPT + NTFS - PARTICION DE SISTEMA LISTA)"

    $discos = Get-SafeDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron discos en el sistema." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES FISICAS DISPONIBLES ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        $etiquetaSys = if ($d.IsSystem) { " [SISTEMA OPERATIVO C: - PROTEGIDO]" } else { "" }
        $color = if ($d.IsSystem) { "Magenta" } elseif ($d.MediaType -match "USB") { "Green" } else { "White" }
        Write-Host ("  [Disco {0}] {1} | Bus: {2} | Capacidad: {3} GB | Particion: {4}{5}" -f $d.Number, $d.FriendlyName, $d.BusType, $d.SizeGB, $d.PartitionStyle, $etiquetaSys) -ForegroundColor $color
    }

    Write-Host "`n[0] CANCELAR y volver al menu anterior" -ForegroundColor Yellow
    $discoSel = Read-Host "`nIngrese el numero de disco a preparar en GPT"
    if ($null -eq $discoSel -or $discoSel -notmatch '^\d+$' -or $discoSel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$discoSel
    $targetDisk = $discos | Where-Object { $_.Number -eq $discoIndex }
    if ($null -eq $targetDisk) {
        Write-Host "[ERROR] El disco $discoIndex no existe en el sistema." -ForegroundColor Red
        return
    }

    if ($targetDisk.IsSystem) {
        Write-Host "`n[BLOQUEO DE SEGURIDAD CRITICO] El Disco $discoIndex contiene el Sistema Operativo actual." -ForegroundColor Red
        Write-Host "No esta permitido formatear la unidad donde corre el script." -ForegroundColor Red
        return
    }

    # 1. Selección de Filesystem
    Write-Host "`n--- SELECCION DE SISTEMA DE ARCHIVOS (GPT / UEFI) ---" -ForegroundColor Cyan
    Write-Host "  1. NTFS  (ESTANDAR OBLIGATORIO para instalar Windows 8 / 10 / 11 en Modo UEFI)"
    Write-Host "  2. FAT32 (Para particiones UEFI especializadas o herramientas WinPE)"
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $fsOpt = Read-Host "`nElija el sistema de archivos (1 o 2)"
    $fs = switch ($fsOpt) {
        "1" { "ntfs" }
        "2" { "fat32" }
        Default { "" }
    }
    if ($fs -eq "") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    if ($fs -eq "fat32" -and $targetDisk.SizeGB -gt 32) {
        Write-Host "`n[AVISO TECNICO] Ha seleccionado FAT32 para un disco de $($targetDisk.SizeGB) GB." -ForegroundColor Yellow
        Write-Host "Windows y Diskpart tienen un limite nativo de 32 GB para FAT32. Si Diskpart reporta 'volumen demasiado grande', utilice NTFS." -ForegroundColor Gray
    }

    # 2. Selección de Modo de Formateo
    Write-Host "`n--- MODO DE FORMATEO ---" -ForegroundColor Cyan
    Write-Host "  1. Formateo RAPIDO (quick - inicializa tablas de particion en segundos)"
    Write-Host "  2. Formateo PROFUNDO (Escribe ceros y comprueba cada sector fisico de la unidad)"
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $modoOpt = Read-Host "`nElija el modo de formateo (1 o 2)"
    $paramQuick = switch ($modoOpt) {
        "1" { "quick" }
        "2" { "" }
        Default { "CANCEL" }
    }
    if ($paramQuick -eq "CANCEL") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    $labelInput = Read-Host "`nIngrese una etiqueta de volumen (Presione ENTER para 'WIN_UEFI')"
    $etiqueta = if ($labelInput.Trim()) { $labelInput.Trim().Replace(" ", "_") -replace '[^\w\-]', '' } else { "WIN_UEFI" }
    if ($fs -eq "fat32" -and $etiqueta.Length -gt 11) {
        $etiqueta = $etiqueta.Substring(0, 11)
    }

    # 3. Confirmación estricta de seguridad
    Write-Host "`n==========================================================================================" -ForegroundColor Red
    Write-Host "                       ADVERTENCIA CRITICA DE ELIMINACION DE DATOS                        " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red
    Write-Host " Se eliminaran TODAS las particiones y datos del siguiente dispositivo:" -ForegroundColor White
    Write-Host "  - Disco Objetivo  : [Disco $discoIndex] $($targetDisk.FriendlyName)" -ForegroundColor Yellow
    Write-Host "  - Capacidad       : $($targetDisk.SizeGB) GB ($($targetDisk.BusType))" -ForegroundColor Yellow
    Write-Host "  - Esquema         : GPT (Particion Primaria Unica UEFI)" -ForegroundColor Yellow
    Write-Host "  - Sistema Archivos: $($fs.ToUpper()) ($etiqueta)" -ForegroundColor Yellow
    Write-Host "  - Modo Formateo   : $(if ($paramQuick -eq 'quick') { 'RAPIDO' } else { 'PROFUNDO' })" -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red

    $confirmacion = Read-Host "Para PROCEDER escriba exactamente 'CONFIRMAR'"
    if ($confirmacion.Trim().ToUpper() -ne "CONFIRMAR") {
        Write-Host "Confirmacion denegada. Proceso abortado de manera segura." -ForegroundColor Yellow
        return
    }

    # 4. Generación y ejecución de script Diskpart
    $diskpartCmds = @(
        "select disk $discoIndex",
        "clean",
        "convert gpt",
        "create partition primary",
        "select partition 1",
        "format fs=$fs $paramQuick label=`"$etiqueta`"",
        "assign",
        "exit"
    )

    $exitCode = Invoke-DiskpartBatch -Commands $diskpartCmds
    if ($exitCode -eq 0) {
        Write-Host "`n[EXITO] El disco $discoIndex ha sido formateado en GPT con una particion unica." -ForegroundColor Green
        Write-Host "Nota UEFI: En tablas GPT el arranque es administrado por el firmware buscando particiones ESP/EFI." -ForegroundColor Cyan
        Write-Host "La particion ha quedado montada, en linea, asignada y ACTIVA/LISTA para transferir archivos de Windows." -ForegroundColor Green
    } else {
        Write-Host "`n[ERROR] Diskpart concluyo con codigo de error: $exitCode" -ForegroundColor Red
    }
}

function Invoke-DiskCleanWipe {
    <#
    .SYNOPSIS
        Limpia y reinicializa profundamente un disco duro o SSD eliminando todas las particiones,
        tablas MBR/GPT y firmas. Ofrece modo rápido (clean) o borrado seguro completo con ceros (clean all).
        Ideal para preparar discos desde cero antes de instalar un sistema operativo o recuperar unidades corruptas.
    #>
    cabecera
    Write-Header "OPCION 19.5: LIMPIEZA PROFUNDA DE DISCO (CLEAN / CLEAN ALL - BORRADO SEGURO)"

    $discos = Get-SafeDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron discos en el sistema." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES FISICAS DISPONIBLES PARA LIMPIEZA ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        $etiquetaSys = if ($d.IsSystem) { " [SISTEMA OPERATIVO C: - PROTEGIDO]" } else { "" }
        $color = if ($d.IsSystem) { "Magenta" } elseif ($d.MediaType -match "USB") { "Green" } else { "White" }
        Write-Host ("  [Disco {0}] {1} | Bus: {2} | Capacidad: {3} GB | Particion: {4}{5}" -f $d.Number, $d.FriendlyName, $d.BusType, $d.SizeGB, $d.PartitionStyle, $etiquetaSys) -ForegroundColor $color
    }

    Write-Host "`n[0] CANCELAR y volver al menu anterior" -ForegroundColor Yellow
    $discoSel = Read-Host "`nIngrese el numero de disco a limpiar/reinicializar"
    if ($null -eq $discoSel -or $discoSel -notmatch '^\d+$' -or $discoSel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$discoSel
    $targetDisk = $discos | Where-Object { $_.Number -eq $discoIndex }
    if ($null -eq $targetDisk) {
        Write-Host "[ERROR] El disco $discoIndex no existe en el sistema." -ForegroundColor Red
        return
    }

    if ($targetDisk.IsSystem) {
        Write-Host "`n[BLOQUEO DE SEGURIDAD CRITICO] El Disco $discoIndex contiene el Sistema Operativo actual." -ForegroundColor Red
        Write-Host "No esta permitido limpiar o borrar la unidad donde corre el sistema." -ForegroundColor Red
        return
    }

    # 1. Nivel de Limpieza
    Write-Host "`n--- NIVEL DE LIMPIEZA Y REINICIALIZACION ---" -ForegroundColor Cyan
    Write-Host "  1. Limpieza RAPIDA (CLEAN - Elimina al instante MBR/GPT, tablas y firmas de particion)"
    Write-Host "     * Deja el disco como 'Espacio No Asignado', listo para instalar Windows o Linux desde cero." -ForegroundColor DarkGray
    Write-Host "  2. Limpieza TOTAL / WIPE SEGURO (CLEAN ALL - Escribe ceros 0x00 en CADA sector fisico)"
    Write-Host "     * Destruye de forma irrecuperable todos los datos, elimina virus de arranque y repara sectores lentos." -ForegroundColor DarkGray
    Write-Host "     * Nota: En unidades grandes (>500 GB) puede tardar segun la velocidad del disco." -ForegroundColor Yellow
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $cleanOpt = Read-Host "`nElija el nivel de limpieza (1 o 2)"
    $cleanCmd = switch ($cleanOpt) {
        "1" { "clean" }
        "2" { "clean all" }
        Default { "" }
    }
    if ($cleanCmd -eq "") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    # 2. Confirmación de Seguridad
    Write-Host "`n==========================================================================================" -ForegroundColor Red
    Write-Host "               ADVERTENCIA CRITICA DE DESTRUCCION TOTAL DE DATOS                          " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red
    Write-Host " Se ELIMINARAN PERMANENTEMENTE todas las particiones, datos y estructuras del dispositivo:" -ForegroundColor White
    Write-Host "  - Disco Objetivo  : [Disco $discoIndex] $($targetDisk.FriendlyName)" -ForegroundColor Yellow
    Write-Host "  - Capacidad       : $($targetDisk.SizeGB) GB ($($targetDisk.BusType))" -ForegroundColor Yellow
    Write-Host "  - Operacion       : DISKPART $($cleanCmd.ToUpper())" -ForegroundColor $(if ($cleanCmd -eq 'clean all') { 'Red' } else { 'Yellow' })
    Write-Host "  - Resultado final : El disco quedara completamente VACIO (Sin formato, listo para particionar)" -ForegroundColor Green
    Write-Host "==========================================================================================" -ForegroundColor Red

    $confirmacion = Read-Host "Para PROCEDER escriba exactamente 'CONFIRMAR'"
    if ($confirmacion.Trim().ToUpper() -ne "CONFIRMAR") {
        Write-Host "Confirmacion denegada. Proceso abortado de manera segura." -ForegroundColor Yellow
        return
    }

    $diskpartCmds = @(
        "select disk $discoIndex",
        $cleanCmd,
        "exit"
    )

    Write-Host "`n[INICIO] Ejecutando $cleanCmd en Disco $discoIndex..." -ForegroundColor Cyan
    if ($cleanCmd -eq "clean all") {
        Write-Host "[AVISO] La escritura de ceros sector por sector esta en progreso. No desconecte la unidad ni apague el equipo..." -ForegroundColor Yellow
    }

    $exitCode = Invoke-DiskpartBatch -Commands $diskpartCmds
    if ($exitCode -eq 0) {
        Write-Host "`n[EXITO] El Disco $discoIndex ha sido limpiado y reinicializado correctamente." -ForegroundColor Green
        Write-Host "La unidad se encuentra como 'Espacio No Asignado' (RAW), lista para ser particionada e instalar S.O." -ForegroundColor Cyan
    } else {
        Write-Host "`n[ERROR] Diskpart concluyo con codigo de error: $exitCode" -ForegroundColor Red
    }
}

function Format-DiskStorageGeneral {
    <#
    .SYNOPSIS
        Formatea unidades extraíbles (USB/SD) y discos duros/SSDs en FAT32, NTFS o exFAT.
        Exclusivamente para almacenamiento de datos (NO booteable, sin flag activa ni bootsect).
    #>
    cabecera
    Write-Header "OPCION 19.6: FORMATEO DE ALMACENAMIENTO GENERAL (FAT32 / NTFS / exFAT)"

    $discos = Get-SafeDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron unidades de almacenamiento en el sistema." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES FISICAS DISPONIBLES (ALMACENAMIENTO DE DATOS) ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        $etiquetaSys = if ($d.IsSystem) { " [SISTEMA OPERATIVO C: - PROTEGIDO]" } else { "" }
        $color = if ($d.IsSystem) { "Magenta" } elseif ($d.MediaType -match "USB") { "Green" } else { "White" }
        Write-Host ("  [Disco {0}] {1} | Bus: {2} | Capacidad: {3} GB | Particion: {4}{5}" -f $d.Number, $d.FriendlyName, $d.BusType, $d.SizeGB, $d.PartitionStyle, $etiquetaSys) -ForegroundColor $color
    }

    Write-Host "`n[0] CANCELAR y volver al menu anterior" -ForegroundColor Yellow
    $discoSel = Read-Host "`nIngrese el numero de disco a formatear para almacenamiento"
    if ($null -eq $discoSel -or $discoSel -notmatch '^\d+$' -or $discoSel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$discoSel
    $targetDisk = $discos | Where-Object { $_.Number -eq $discoIndex }
    if ($null -eq $targetDisk) {
        Write-Host "[ERROR] El disco $discoIndex no existe en el sistema." -ForegroundColor Red
        return
    }

    if ($targetDisk.IsSystem) {
        Write-Host "`n[BLOQUEO DE SEGURIDAD CRITICO] El Disco $discoIndex contiene el Sistema Operativo actual." -ForegroundColor Red
        Write-Host "No esta permitido formatear la unidad donde corre el sistema." -ForegroundColor Red
        return
    }

    # 1. Esquema de particionado
    Write-Host "`n--- SELECCION DE ESQUEMA DE PARTICIONES ---" -ForegroundColor Cyan
    Write-Host "  1. MBR (Recomendado para <= 2TB, Smart TVs, autorradios y consolas)"
    Write-Host "  2. GPT (Recomendado para discos modernos, SSDs y unidades > 2TB)"
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $estiloOpt = Read-Host "`nElija el esquema de particion (1 o 2)"
    $estilo = switch ($estiloOpt) {
        "1" { "mbr" }
        "2" { "gpt" }
        Default { "" }
    }
    if ($estilo -eq "") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    # 2. Selección de Sistema de Archivos
    Write-Host "`n--- SELECCION DE SISTEMA DE ARCHIVOS (SOLO DATOS) ---" -ForegroundColor Cyan
    Write-Host "  1. FAT32 (Maxima compatibilidad universal. Limite de 4 GB por archivo individual)"
    Write-Host "  2. NTFS  (Para Windows y discos de alta capacidad. Soporta archivos gigantes y seguridad)"
    Write-Host "  3. exFAT (Estandar moderno para pendrives/discos externos sin limite de 4GB. Compatible Win/Mac/Linux)"
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $fsOpt = Read-Host "`nElija el sistema de archivos (1, 2 o 3)"
    $fs = switch ($fsOpt) {
        "1" { "fat32" }
        "2" { "ntfs" }
        "3" { "exfat" }
        Default { "" }
    }
    if ($fs -eq "") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    $esMultiPartFAT32 = ($fs -eq "fat32" -and $targetDisk.SizeGB -gt 32)
    $partCount = 1
    if ($esMultiPartFAT32) {
        $partCount = [Math]::Ceiling($targetDisk.SizeGB / 32)
        if ($estilo -eq "mbr" -and $partCount -gt 4) { $partCount = 4 }

        Write-Host "`n==========================================================================================" -ForegroundColor Cyan
        Write-Host " [ESTRUCTURACION FAT32 INTELIGENTE: PARTICIONADO MULTIPLE DE HASTA 32 GB]" -ForegroundColor Yellow
        Write-Host "==========================================================================================" -ForegroundColor Cyan
        Write-Host " Capacidad del disco : $($targetDisk.SizeGB) GB" -ForegroundColor White
        Write-Host " Limite nativo Win32 : Diskpart no formatea particiones individuales mayores a 32 GB en FAT32." -ForegroundColor Gray
        Write-Host " Solucion de diseno  : Se particionara el disco en $partCount volumenes FAT32 (hasta 32 GB c/u)." -ForegroundColor Green
        Write-Host " Beneficio           : 100% de la capacidad aprovechada en FAT32 puro, cada una con su letra." -ForegroundColor Green
        Write-Host "==========================================================================================" -ForegroundColor Cyan
    }

    # 3. Selección de Modo de Formateo (Rápido vs Profundo)
    Write-Host "`n--- MODO DE FORMATEO ---" -ForegroundColor Cyan
    Write-Host "  1. Formateo RAPIDO (quick - inicializa tablas y sistema de archivos en segundos)"
    Write-Host "  2. Formateo PROFUNDO (formato completo - verifica cada sector fisico y escribe ceros)"
    Write-Host "     * Nota: Realiza escaneo fisico cluster por cluster. Muestra porcentaje en tiempo real." -ForegroundColor DarkGray
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $modoOpt = Read-Host "`nElija el modo de formateo (1 o 2)"
    $esProfundo = ($modoOpt -eq "2")
    if ($modoOpt -ne "1" -and $modoOpt -ne "2") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    # Etiqueta por defecto segura de max 11 caracteres
    $defaultLabel = switch ($fs) {
        "fat32" { "DATOS_FAT32" }
        "ntfs"  { "DATOS_NTFS" }
        "exfat" { "DATOS_EXFAT" }
    }

    $labelInput = Read-Host "`nIngrese una etiqueta para el volumen (Presione ENTER para '$defaultLabel')"
    $etiqueta = if ($labelInput.Trim()) {
        # Limpiar caracteres no validos para etiquetas
        $labelInput.Trim().Replace(" ", "_") -replace '[^\w\-]', ''
    } else {
        $defaultLabel
    }

    # En FAT32 y exFAT el limite maximo de etiqueta es 11 caracteres (evita error en Diskpart)
    if ($fs -in @("fat32", "exfat") -and $etiqueta.Length -gt 11) {
        $etiqueta = $etiqueta.Substring(0, 11)
    }

    # 4. Confirmación estricta de seguridad
    Write-Host "`n==========================================================================================" -ForegroundColor Red
    Write-Host "                       ADVERTENCIA CRITICA DE FORMATEO DE DATOS                          " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red
    Write-Host " Se eliminaran permanentemente TODAS las particiones y archivos del dispositivo:" -ForegroundColor White
    Write-Host "  - Disco Objetivo  : [Disco $discoIndex] $($targetDisk.FriendlyName)" -ForegroundColor Yellow
    Write-Host "  - Capacidad       : $($targetDisk.SizeGB) GB ($($targetDisk.BusType))" -ForegroundColor Yellow
    Write-Host "  - Esquema         : $($estilo.ToUpper())" -ForegroundColor Yellow
    if ($esMultiPartFAT32) {
        Write-Host "  - Sistema Archivos: FAT32 (Dividido en $partCount particiones de hasta 32 GB c/u)" -ForegroundColor Green
    } else {
        Write-Host "  - Sistema Archivos: $($fs.ToUpper()) (Etiqueta: $etiqueta)" -ForegroundColor Yellow
    }
    Write-Host "  - Modo Formateo   : $(if ($esProfundo) { 'PROFUNDO (COMPLETO CON VERIFICACION DE SECTORES)' } else { 'RAPIDO (QUICK)' })" -ForegroundColor Yellow
    Write-Host "  - Propósito       : SOLO ALMACENAMIENTO DE DATOS (NO BOOTEABLE)" -ForegroundColor Green
    Write-Host "==========================================================================================" -ForegroundColor Red

    $confirmacion = Read-Host "Para PROCEDER escriba exactamente 'CONFIRMAR'"
    if ($confirmacion.Trim().ToUpper() -ne "CONFIRMAR") {
        Write-Host "Confirmacion denegada. Proceso abortado de manera segura." -ForegroundColor Yellow
        return
    }

    # 5. Generación de directivas Diskpart con secuencia validada paso a paso
    $paramQuick = if ($esProfundo) { "" } else { "quick" }

    if ($esMultiPartFAT32) {
        $baseLabel = if ($etiqueta.Length -gt 8) { $etiqueta.Substring(0, 8) } else { $etiqueta }
        $diskpartCmds = @(
            "select disk $discoIndex",
            "clean",
            "convert $estilo"
        )
        for ($i = 1; $i -le $partCount; $i++) {
            $partLabel = "${baseLabel}_$i"
            if ($partLabel.Length -gt 11) { $partLabel = $partLabel.Substring(0, 11) }

            if ($i -lt $partCount) {
                $diskpartCmds += "create partition primary size=32000"
            } else {
                $diskpartCmds += "create partition primary"
            }
            $diskpartCmds += "select partition $i"
            $diskpartCmds += "format fs=fat32 $paramQuick label=`"$partLabel`""
            $diskpartCmds += "assign"
        }
        $diskpartCmds += "exit"
    } else {
        $diskpartCmds = @(
            "select disk $discoIndex",
            "clean",
            "convert $estilo",
            "create partition primary",
            "select partition 1",
            "format fs=$fs $paramQuick label=`"$etiqueta`"",
            "assign",
            "exit"
        )
    }

    Write-Host "`n[INICIO] Ejecutando formateo en Disco $discoIndex..." -ForegroundColor Cyan
    if ($esProfundo) {
        Write-Host "[AVISO] El formateo profundo esta escaneando y verificando cada sector físico. Por favor espere..." -ForegroundColor Yellow
    }

    $exitCode = Invoke-DiskpartBatch -Commands $diskpartCmds
    if ($exitCode -eq 0) {
        Write-Host "`n[EXITO] El Disco $discoIndex ha sido formateado exitosamente en $($fs.ToUpper())." -ForegroundColor Green
        if ($esMultiPartFAT32) {
            Write-Host "Se crearon y montaron $partCount particiones en FAT32 aprovechando el 100% de la capacidad ($($targetDisk.SizeGB) GB)." -ForegroundColor Cyan
            Write-Host "Cada particion esta montada con su propia letra de unidad y lista para almacenar archivos." -ForegroundColor Green
        } else {
            Write-Host "La unidad ha quedado montada con una particion de datos lista para almacenar archivos." -ForegroundColor Cyan
        }
        Write-Host "Configuracion: Esquema $($estilo.ToUpper()), Modo $(if ($esProfundo) { 'Profundo' } else { 'Rapido' }), sin sectores de booteo." -ForegroundColor Green
    } else {
        Write-Host "`n[ERROR] Diskpart concluyo con codigo de error: $exitCode" -ForegroundColor Red
        if ($fs -eq "fat32" -and $targetDisk.SizeGB -gt 32) {
            Write-Host "`n[DIAGNOSTICO]: En Windows, la utilidad Diskpart no permite formatear particiones mayores a 32 GB en FAT32 ('El volumen es demasiado grande')." -ForegroundColor Yellow
            Write-Host "Para utilizar los $($targetDisk.SizeGB) GB completos de esta unidad, formatee en exFAT o NTFS." -ForegroundColor Cyan
        }
    }
}

function Format-DiskStorageLinux {
    <#
    .SYNOPSIS
        Prepara y formatea unidades de almacenamiento externas y discos duros para su uso en GNU/Linux.
        Soporta sistemas de archivos compatibles universalmente (exFAT, FAT32, NTFS) y particionado nativo Linux RAW.
        Exclusivamente para almacenamiento de datos (NO es USB Live ni medio booteable).
    #>
    cabecera
    Write-Header "OPCION 19.7: FORMATEO DE UNIDADES Y DISCOS PARA SISTEMAS GNU/LINUX"

    $discos = Get-SafeDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron unidades de almacenamiento en el sistema." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES FISICAS DISPONIBLES (DESTINO GNU/LINUX) ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        $etiquetaSys = if ($d.IsSystem) { " [SISTEMA OPERATIVO C: - PROTEGIDO]" } else { "" }
        $color = if ($d.IsSystem) { "Magenta" } elseif ($d.MediaType -match "USB") { "Green" } else { "White" }
        Write-Host ("  [Disco {0}] {1} | Bus: {2} | Capacidad: {3} GB | Particion: {4}{5}" -f $d.Number, $d.FriendlyName, $d.BusType, $d.SizeGB, $d.PartitionStyle, $etiquetaSys) -ForegroundColor $color
    }

    Write-Host "`n[0] CANCELAR y volver al menu anterior" -ForegroundColor Yellow
    $discoSel = Read-Host "`nIngrese el numero de disco a preparar para GNU/Linux"
    if ($null -eq $discoSel -or $discoSel -notmatch '^\d+$' -or $discoSel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$discoSel
    $targetDisk = $discos | Where-Object { $_.Number -eq $discoIndex }
    if ($null -eq $targetDisk) {
        Write-Host "[ERROR] El disco $discoIndex no existe en el sistema." -ForegroundColor Red
        return
    }

    if ($targetDisk.IsSystem) {
        Write-Host "`n[BLOQUEO DE SEGURIDAD CRITICO] El Disco $discoIndex contiene el Sistema Operativo actual." -ForegroundColor Red
        Write-Host "No esta permitido formatear la unidad donde corre el sistema." -ForegroundColor Red
        return
    }

    # 1. Esquema de particiones Linux
    Write-Host "`n--- SELECCION DE ESQUEMA DE PARTICIONES LINUX ---" -ForegroundColor Cyan
    Write-Host "  1. MBR (Universal para Linux, compatible con BIOS y discos <= 2TB)"
    Write-Host "  2. GPT (Recomendado para Linux moderno, UEFI y discos > 2TB)"
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $estiloOpt = Read-Host "`nElija el esquema de particion (1 o 2)"
    $estilo = switch ($estiloOpt) {
        "1" { "mbr" }
        "2" { "gpt" }
        Default { "" }
    }
    if ($estilo -eq "") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    # 2. Selección de Sistema de Archivos para GNU/Linux
    Write-Host "`n--- SELECCION DE SISTEMA DE ARCHIVOS COMPATIBLE CON GNU/LINUX ---" -ForegroundColor Cyan
    Write-Host "  1. exFAT (RECOMENDADO para almacenamiento masivo Linux - Kernel 5.7+ nativo, sin limite 4GB)" -ForegroundColor Green
    Write-Host "  2. FAT32 (Universal para cualquier distro Linux clásica o moderna - Formato vfat)"
    Write-Host "  3. NTFS  (Soporte nativo en GNU/Linux mediante controladores kernel ntfs3 y ntfs-3g)"
    Write-Host "  4. Particion Nativa Linux RAW (Tipo 83 en MBR / GUID Linux en GPT - Sin letra en Windows)"
    Write-Host "     * Crea la particion pura Linux lista para formatear en ext4/btrfs directamente en Linux." -ForegroundColor DarkGray
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow

    $fsLinuxOpt = Read-Host "`nElija la opcion deseada (1, 2, 3 o 4)"
    $esRawLinux = ($fsLinuxOpt -eq "4")
    $fs = switch ($fsLinuxOpt) {
        "1" { "exfat" }
        "2" { "fat32" }
        "3" { "ntfs" }
        "4" { "RAW_LINUX" }
        Default { "" }
    }
    if ($fs -eq "") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    $esMultiPartFAT32 = ($fs -eq "fat32" -and $targetDisk.SizeGB -gt 32)
    $partCount = 1
    if ($esMultiPartFAT32) {
        $partCount = [Math]::Ceiling($targetDisk.SizeGB / 32)
        if ($estilo -eq "mbr" -and $partCount -gt 4) { $partCount = 4 }

        Write-Host "`n==========================================================================================" -ForegroundColor Cyan
        Write-Host " [ESTRUCTURACION FAT32 INTELIGENTE: PARTICIONADO MULTIPLE DE HASTA 32 GB]" -ForegroundColor Yellow
        Write-Host "==========================================================================================" -ForegroundColor Cyan
        Write-Host " Capacidad del disco : $($targetDisk.SizeGB) GB" -ForegroundColor White
        Write-Host " Limite nativo Win32 : Diskpart no formatea particiones individuales mayores a 32 GB en FAT32." -ForegroundColor Gray
        Write-Host " Solucion de diseno  : Se particionara el disco en $partCount volumenes FAT32 (hasta 32 GB c/u)." -ForegroundColor Green
        Write-Host " Beneficio           : 100% de la capacidad aprovechada en FAT32 puro, compatible con GNU/Linux." -ForegroundColor Green
        Write-Host "==========================================================================================" -ForegroundColor Cyan
    }

    # 3. Selección de Modo (Rápido vs Profundo)
    Write-Host "`n--- MODO DE FORMATEO ---" -ForegroundColor Cyan
    Write-Host "  1. Formateo RAPIDO (quick - inicializa tablas y sistema de archivos en segundos)"
    Write-Host "  2. Formateo PROFUNDO (formato completo - verifica cada sector fisico y escribe ceros)"
    Write-Host "     * Nota: Realiza escaneo fisico cluster por cluster. Muestra porcentaje en tiempo real." -ForegroundColor DarkGray
    Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow
    $modoOpt = Read-Host "`nElija el modo de formateo (1 o 2)"
    $esProfundo = ($modoOpt -eq "2")
    if ($modoOpt -ne "1" -and $modoOpt -ne "2") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }

    $defaultLabel = "LINUX_DATA"
    $labelInput = Read-Host "`nIngrese una etiqueta de volumen (Presione ENTER para '$defaultLabel')"
    $etiqueta = if ($labelInput.Trim()) {
        $labelInput.Trim().Replace(" ", "_") -replace '[^\w\-]', ''
    } else {
        $defaultLabel
    }

    # En FAT32 y exFAT el limite maximo de etiqueta es 11 caracteres (evita error en Diskpart)
    if ($fs -in @("fat32", "exfat") -and $etiqueta.Length -gt 11) {
        $etiqueta = $etiqueta.Substring(0, 11)
    }

    # 4. Confirmación estricta de seguridad
    Write-Host "`n==========================================================================================" -ForegroundColor Red
    Write-Host "                       ADVERTENCIA CRITICA: DESTINO GNU/LINUX                             " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red
    Write-Host " Se eliminaran permanentemente TODAS las particiones y datos del dispositivo:" -ForegroundColor White
    Write-Host "  - Disco Objetivo  : [Disco $discoIndex] $($targetDisk.FriendlyName)" -ForegroundColor Yellow
    Write-Host "  - Capacidad       : $($targetDisk.SizeGB) GB ($($targetDisk.BusType))" -ForegroundColor Yellow
    Write-Host "  - Esquema Linux   : $($estilo.ToUpper())" -ForegroundColor Yellow
    if ($esMultiPartFAT32) {
        Write-Host "  - Sistema/Formato : FAT32 (Dividido en $partCount particiones de hasta 32 GB c/u)" -ForegroundColor Green
    } else {
        Write-Host "  - Sistema/Formato : $(if ($esRawLinux) { 'Particion Nativa Linux RAW (ID 83 / GUID Linux)' } else { $fs.ToUpper() + ' (Etiqueta: ' + $etiqueta + ')' })" -ForegroundColor Yellow
    }
    Write-Host "  - Modo Formateo   : $(if ($esProfundo) { 'PROFUNDO (COMPLETO CON VERIFICACION DE SECTORES)' } else { 'RAPIDO (QUICK)' })" -ForegroundColor Yellow
    Write-Host "  - Propósito       : SOLO ALMACENAMIENTO DE DATOS (NO BOOTEABLE NI LIVE USB)" -ForegroundColor Green
    Write-Host "==========================================================================================" -ForegroundColor Red

    $confirmacion = Read-Host "Para PROCEDER escriba exactamente 'CONFIRMAR'"
    if ($confirmacion.Trim().ToUpper() -ne "CONFIRMAR") {
        Write-Host "Confirmacion denegada. Proceso abortado de manera segura." -ForegroundColor Yellow
        return
    }

    # 5. Generación de directivas Diskpart con secuencia validada paso a paso
    $paramQuick = if ($esProfundo) { "" } else { "quick" }

    if ($esRawLinux) {
        # Partición nativa Linux RAW (ID 83 en MBR o GUID Linux en GPT)
        $partId = if ($estilo -eq "mbr") { "id=83" } else { "id=0fc63daf-8483-4772-8e79-3d69d8477de4" }
        $diskpartCmds = @(
            "select disk $discoIndex",
            "clean",
            "convert $estilo",
            "create partition primary $partId",
            "select partition 1",
            "exit"
        )
    } elseif ($esMultiPartFAT32) {
        $baseLabel = if ($etiqueta.Length -gt 8) { $etiqueta.Substring(0, 8) } else { $etiqueta }
        $diskpartCmds = @(
            "select disk $discoIndex",
            "clean",
            "convert $estilo"
        )
        for ($i = 1; $i -le $partCount; $i++) {
            $partLabel = "${baseLabel}_$i"
            if ($partLabel.Length -gt 11) { $partLabel = $partLabel.Substring(0, 11) }

            if ($i -lt $partCount) {
                $diskpartCmds += "create partition primary size=32000"
            } else {
                $diskpartCmds += "create partition primary"
            }
            $diskpartCmds += "select partition $i"
            $diskpartCmds += "format fs=fat32 $paramQuick label=`"$partLabel`""
            $diskpartCmds += "assign"
        }
        $diskpartCmds += "exit"
    } else {
        # Formato de almacenamiento estándar compatible con Linux (exFAT, FAT32, NTFS)
        $diskpartCmds = @(
            "select disk $discoIndex",
            "clean",
            "convert $estilo",
            "create partition primary",
            "select partition 1",
            "format fs=$fs $paramQuick label=`"$etiqueta`"",
            "assign",
            "exit"
        )
    }

    Write-Host "`n[INICIO] Aplicando particionado y formateo para GNU/Linux en Disco $discoIndex..." -ForegroundColor Cyan
    if ($esProfundo -and -not $esRawLinux) {
        Write-Host "[AVISO] El formateo profundo esta escaneando y verificando cada sector físico. Por favor espere..." -ForegroundColor Yellow
    }

    $exitCode = Invoke-DiskpartBatch -Commands $diskpartCmds

    if ($exitCode -eq 0) {
        Write-Host "`n[EXITO] El Disco $discoIndex ha sido preparado exitosamente para GNU/Linux." -ForegroundColor Green
        if ($esRawLinux) {
            Write-Host "La unidad contiene una particion pura de datos bajo esquema $($estilo.ToUpper()) con ID Linux nativo." -ForegroundColor Cyan
            Write-Host "Al conectarse a cualquier equipo GNU/Linux, sera reconocida de inmediato en /dev/sdX." -ForegroundColor Green
        } elseif ($esMultiPartFAT32) {
            Write-Host "Se crearon y montaron $partCount particiones en FAT32 aprovechando el 100% de la capacidad ($($targetDisk.SizeGB) GB)." -ForegroundColor Cyan
            Write-Host "Totalmente compatibles y reconocidas inmediatamente por cualquier distribucion GNU/Linux." -ForegroundColor Green
        } else {
            Write-Host "La unidad contiene una particion formateada en $($fs.ToUpper()) con etiqueta '$etiqueta' montada y lista." -ForegroundColor Cyan
            Write-Host "Totalmente compatible para lectura y escritura directa en cualquier distribucion GNU/Linux." -ForegroundColor Green
        }
    } else {
        Write-Host "`n[ERROR] Diskpart concluyo con codigo de error: $exitCode" -ForegroundColor Red
        if ($fs -eq "fat32" -and $targetDisk.SizeGB -gt 32) {
            Write-Host "`n[DIAGNOSTICO]: En Windows, la utilidad Diskpart no permite formatear particiones mayores a 32 GB en FAT32 ('El volumen es demasiado grande')." -ForegroundColor Yellow
            Write-Host "Para utilizar los $($targetDisk.SizeGB) GB completos de esta unidad en GNU/Linux, formatee en exFAT (opcion 1) o cree una particion RAW (opcion 4)." -ForegroundColor Cyan
        }
    }
}

function psSubMenuFormatHDD {
    $salirSub19 = $false
    do {
        cabecera
        Write-Header "OPCION 19. PREPARAR DISCO DE DESTINO (HDD / SSD / NVMe) PARA S.O. O ALMACENAMIENTO"
        Write-Host "  19.0 Tabla de relacion: Filesystem vs Particion vs Modo Arranque (BIOS/UEFI)" -ForegroundColor Cyan
        Write-Host "  19.1 Informacion tecnica detallada de la unidad (Particion, FS, Salud SMART)" -ForegroundColor Yellow
        Write-Host "  19.2 Verificacion de sectores y revision de superficie (Superficial vs Profunda)" -ForegroundColor Yellow
        Write-Host "  19.3 Preparar Disco para Windows Legacy (MBR + FAT32/NTFS) - Particion ACTIVA [Win 98/XP/7/10/11]" -ForegroundColor Yellow
        Write-Host "  19.4 Preparar Disco para Windows UEFI (GPT + NTFS) - Particion de Sistema Lista" -ForegroundColor Yellow
        Write-Host "  19.5 Limpieza y Reinicializacion Profunda de Disco (Clean / Clean All - Wipe Seguro)" -ForegroundColor Yellow
        Write-Host "  19.6 Formateo de Almacenamiento General (FAT32 / NTFS / exFAT) [Multi-Particion FAT32]" -ForegroundColor Green
        Write-Host "  19.7 Formateo de Unidades y Discos para GNU/Linux (Particion Nativa RAW / ext4)" -ForegroundColor Green
        Write-Host ""
        Write-Host "  0. V O L V E R   A L   S U B M E N U   2 0" -ForegroundColor White
        Write-Header "=============================================================================="

        $op19 = Read-Host "Seleccione la tarea a realizar en Preparacion de Disco de Destino"

        switch ($op19) {
            { $_ -in "19.0", "0.0", "table" } { Show-FormatBootMatrix }
            { $_ -in "19.1", "1" }             { Show-DiskTechnicalDetails }
            { $_ -in "19.2", "2" }             { Invoke-DiskSurfaceCheck }
            { $_ -in "19.3", "3" }             { Format-DiskStorageMBR }
            { $_ -in "19.4", "4" }             { Format-DiskStorageGPT }
            { $_ -in "19.5", "5" }             { Invoke-DiskCleanWipe }
            { $_ -in "19.6", "6" }             { Format-DiskStorageGeneral }
            { $_ -in "19.7", "7" }             { Format-DiskStorageLinux }
            "0" { $salirSub19 = $true }
            Default { Write-Host "Opcion invalida." -ForegroundColor Red }
        }

        if (-not $salirSub19) {
            Write-Host ""
            Read-Host "Presione ENTER para continuar en el menu de Formateo..."
        }
    } while (-not $salirSub19)
}

# =========================================================================================
# ORQUESTADOR DE EJECUCION EXTERNA PARA EL GRUPO 19 (DESACOPLAMIENTO MULTIVENTANA)
# =========================================================================================

function Invoke-FormatHDDExternalWindow {
    <#
    .SYNOPSIS
        Despacha la ejecución de las funciones del Grupo 19 (Preparación de Disco de Destino)
        a un proceso y ventana de consola independiente de PowerShell, liberando inmediatamente la
        consola principal para el operador.
    .PARAMETER OpcionDestino
        Código de la opción a ejecutar ("19", "19.0", "19.1", "19.2", "19.3", "19.4", "19.5", "19.6", "19.7").
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$OpcionDestino
    )

    $taskMap = @{
        "19"   = @{ Titulo = "Submenu 19: Preparar Disco de Destino (HDD/SSD/NVMe) para S.O. o Almacenamiento"; Cmd = "psSubMenuFormatHDD" }
        "19.0" = @{ Titulo = "19.0 Matriz Filesystem vs Particion vs Modo Arranque"; Cmd = "Show-FormatBootMatrix" }
        "19.1" = @{ Titulo = "19.1 Ficha Tecnica Detallada y Salud S.M.A.R.T.";     Cmd = "Show-DiskTechnicalDetails" }
        "19.2" = @{ Titulo = "19.2 Verificacion de Sectores y Revision Superficie";  Cmd = "Invoke-DiskSurfaceCheck" }
        "19.3" = @{ Titulo = "19.3 Preparar Disco para Windows Legacy (MBR + FAT32/NTFS) - Activa"; Cmd = "Format-DiskStorageMBR" }
        "19.4" = @{ Titulo = "19.4 Preparar Disco para Windows UEFI (GPT + NTFS)";  Cmd = "Format-DiskStorageGPT" }
        "19.5" = @{ Titulo = "19.5 Limpieza y Reinicializacion Profunda de Disco (Clean/Clean All)"; Cmd = "Invoke-DiskCleanWipe" }
        "19.6" = @{ Titulo = "19.6 Formateo de Almacenamiento General (FAT32/NTFS/exFAT)"; Cmd = "Format-DiskStorageGeneral" }
        "19.7" = @{ Titulo = "19.7 Formateo de Unidades y Discos para GNU/Linux"; Cmd = "Format-DiskStorageLinux" }
    }

    if (-not $taskMap.ContainsKey($OpcionDestino)) {
        Write-Host "[ERROR] Opcion de formateo '$OpcionDestino' no reconocida para ejecucion externa." -ForegroundColor Red
        return
    }

    $info = $taskMap[$OpcionDestino]
    $cleanOp = ($OpcionDestino -replace '[^\w]', '_')
    $tempFile = Join-Path $env:TEMP ("shellWil_FormatHDD_" + $cleanOp + "_" + (Get-Random -Minimum 1000 -Maximum 9999) + ".ps1")

    # Lista de funciones del módulo que deben exportarse al subproceso
    $requiredFunctions = @(
        'cabecera',
        'Write-Header',
        'Get-SafeDiskList',
        'Invoke-DiskpartBatch',
        'Show-FormatBootMatrix',
        'Show-DiskTechnicalDetails',
        'Invoke-DiskSurfaceCheck',
        'Format-DiskStorageMBR',
        'Format-DiskStorageGPT',
        'Invoke-DiskCleanWipe',
        'Format-DiskStorageGeneral',
        'Format-DiskStorageLinux',
        'psSubMenuFormatHDD'
    )

    # Construcción compatible con PowerShell 2.0 / 3.0 / 5.1 / 7+
    $sb = New-Object System.Text.StringBuilder

    [void]$sb.AppendLine("# ==========================================================================")
    [void]$sb.AppendLine("# CONSOLA SECUNDARIA AUTONOMA - SHELLSW (DISCOS Y PREPARACION S.O.)")
    [void]$sb.AppendLine("# Tarea: $($info.Titulo)")
    [void]$sb.AppendLine("# Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("# ==========================================================================")
    [void]$sb.AppendLine("try { `$Host.UI.RawUI.WindowTitle = 'ShellSW - Discos y Formateo [$OpcionDestino]' } catch {}")
    [void]$sb.AppendLine("[Console]::OutputEncoding = [System.Text.Encoding]::UTF8")
    [void]$sb.AppendLine("")

    # Definiciones de contingencia para cabeceras si no estuviesen cargadas en el entorno
    if (-not (Get-Command 'cabecera' -ErrorAction SilentlyContinue)) {
        [void]$sb.AppendLine(@'
function cabecera {
    Write-Host " ------------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " Ing. Wilson Yucra - Soft. Administracion y Gestion del Sistema Operativo" -ForegroundColor Cyan
    Write-Host " ------------------------------------------------------------------------" -ForegroundColor Cyan
}
'@)
    }

    if (-not (Get-Command 'Write-Header' -ErrorAction SilentlyContinue)) {
        [void]$sb.AppendLine(@'
function Write-Header {
    param([string]$texto)
    $ancho = $texto.Length + 15
    $linea = "=" * $ancho
    Write-Host "`n$linea" -ForegroundColor Yellow
    Write-Host "| $texto |" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "$linea" -ForegroundColor Yellow
}
'@)
    }

    # Serializar las funciones activas en memoria hacia el archivo runner
    foreach ($fn in $requiredFunctions) {
        $cmd = Get-Command $fn -ErrorAction SilentlyContinue
        if ($cmd) {
            [void]$sb.AppendLine("function $fn {")
            [void]$sb.AppendLine($cmd.Definition)
            [void]$sb.AppendLine("}`n")
        }
    }

    # Bloque de ejecución principal del subproceso
    [void]$sb.AppendLine("# --- EJECUCION DE LA TAREA SOLICITADA ---")
    [void]$sb.AppendLine("try {")
    [void]$sb.AppendLine("    $($info.Cmd)")
    [void]$sb.AppendLine("}")
    [void]$sb.AppendLine("catch {")
    [void]$sb.AppendLine("    Write-Host '`n[ERROR CRITICO EN VENTANA SECUNDARIA]: ' `$_.Exception.Message -ForegroundColor Red")
    [void]$sb.AppendLine("}")
    [void]$sb.AppendLine("finally {")
    if ($OpcionDestino -eq "19") {
        [void]$sb.AppendLine("    Write-Host '`n[Cerrando consola secundaria de formateo...]' -ForegroundColor Gray")
        [void]$sb.AppendLine("    Start-Sleep -Milliseconds 600")
        [void]$sb.AppendLine("    try { Remove-Item -Path `$MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue } catch {}")
        [void]$sb.AppendLine("    exit")
    } else {
        [void]$sb.AppendLine("    Write-Host '`n==========================================================================' -ForegroundColor Cyan")
        [void]$sb.AppendLine("    Write-Host ' [PROCESO FINALIZADO] Esta ventana permanecera abierta para su consulta.' -ForegroundColor Green")
        [void]$sb.AppendLine("    Write-Host ' Puede revisar los reportes y cerrarla cuando lo desee.' -ForegroundColor Gray")
        [void]$sb.AppendLine("    Write-Host '==========================================================================' -ForegroundColor Cyan")
        [void]$sb.AppendLine("    Write-Host ''")
        [void]$sb.AppendLine("    Read-Host 'Presione ENTER para cerrar esta ventana...'")
        [void]$sb.AppendLine("    try { Remove-Item -Path `$MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue } catch {}")
        [void]$sb.AppendLine("    exit")
    }
    [void]$sb.AppendLine("}")

    # Guardar en temporal con codificación UTF-8
    [System.IO.File]::WriteAllText($tempFile, $sb.ToString(), [System.Text.Encoding]::UTF8)

    # Lanzamiento del proceso de PowerShell en ventana externa independiente con elevación UAC
    $procArgs = @(
        "-NoExit",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$tempFile`""
    )

    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList $procArgs -Verb RunAs -ErrorAction Stop
    }
    catch {
        # Si el usuario deniega UAC o el entorno no soporta RunAs, lanzar sin elevación forzada
        Start-Process -FilePath "powershell.exe" -ArgumentList $procArgs -ErrorAction SilentlyContinue
    }

    # Panel informativo en la consola principal
    Write-Host "`n==========================================================================" -ForegroundColor Cyan
    Write-Host "  [OK] TAREA DESPLEGADA EN UNA VENTANA O CONSOLA INDEPENDIENTE" -ForegroundColor Green
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "  Accion Solicitada : $($info.Titulo)" -ForegroundColor White
    Write-Host "  Opcion / Codigo   : $OpcionDestino" -ForegroundColor Yellow
    Write-Host "  Estado Operativo  : Se ha abierto una consola secundaria de PowerShell." -ForegroundColor Gray
    Write-Host "  Disponibilidad    : Esta consola principal queda 100% LIBRE para su uso" -ForegroundColor Green
    Write-Host "                      inmediato en otras tareas del sistema." -ForegroundColor Gray
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host ""
}

# =========================================================================================
# FUNCIONES AUXILIARES Y MODULARES PARA EL GRUPO 21: PREPARACION DE DISPOSITIVOS EXTERNOS Y USB
# =========================================================================================

function Get-SafeUsbDiskList {
    <#
    .SYNOPSIS
        Obtiene la lista de unidades de almacenamiento USB / extraíbles físicas,
        con mapeo exacto de su índice físico, modelo, tamaño y letras montadas.
    #>
    $usbList = @()
    try {
        $sysDrive = $env:SystemDrive.Replace(":", "")
        $systemDiskNum = -1
        if (Get-Command Get-Partition -ErrorAction SilentlyContinue) {
            $sysPart = Get-Partition -DriveLetter $sysDrive -ErrorAction SilentlyContinue
            if ($sysPart) { $systemDiskNum = $sysPart.DiskNumber }
        }

        # 1. Intentar mediante Storage Cmdlets (Win 8/10/11)
        if (Get-Command Get-Disk -ErrorAction SilentlyContinue) {
            $disks = Get-Disk | Where-Object { 
                $_.BusType -eq "USB" -or $_.MediaType -eq "Removable" 
            } | Sort-Object Number

            foreach ($d in $disks) {
                $isSys = ($d.Number -eq $systemDiskNum)
                $sizeGB = [Math]::Round($d.Size / 1GB, 2)
                
                # Obtener letras de particiones
                $letters = @()
                $parts = Get-Partition -DiskNumber $d.Number -ErrorAction SilentlyContinue
                if ($parts) {
                    foreach ($p in $parts) {
                        if ($p.DriveLetter) { $letters += "$($p.DriveLetter):" }
                    }
                }
                $letterStr = if ($letters.Count -gt 0) { ($letters -join ", ") } else { "Sin Letra" }

                $usbList += [PSCustomObject]@{
                    Index        = [int]$d.Number
                    Model        = $d.FriendlyName
                    BusType      = "USB"
                    SizeGB       = $sizeGB
                    Letters      = $letterStr
                    IsSystem     = $isSys
                    Style        = $d.PartitionStyle.ToString()
                }
            }
            if ($usbList.Count -gt 0) { return $usbList }
        }
    } catch {}

    # 2. Fallback WMI Win32_DiskDrive (Compatibilidad Win 7)
    try {
        $wmiDisks = Get-WmiObject Win32_DiskDrive | Where-Object { 
            $_.InterfaceType -eq "USB" -or $_.MediaType -match "Removable|External" 
        } | Sort-Object Index

        foreach ($wd in $wmiDisks) {
            $idx = [int]$wd.Index
            $sizeGB = if ($wd.Size) { [Math]::Round($wd.Size / 1GB, 2) } else { 0 }
            
            # Obtener letras asociadas vía asociadores WMI
            $letters = @()
            try {
                $qParts = Get-WmiObject -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='$($wd.DeviceID)'} WHERE AssocClass=Win32_DiskDriveToDiskPartition" -ErrorAction SilentlyContinue
                foreach ($qp in $qParts) {
                    $qVols = Get-WmiObject -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($qp.DeviceID)'} WHERE AssocClass=Win32_LogicalDiskToPartition" -ErrorAction SilentlyContinue
                    foreach ($qv in $qVols) {
                        if ($qv.DeviceID) { $letters += $qv.DeviceID }
                    }
                }
            } catch {}
            $letterStr = if ($letters.Count -gt 0) { ($letters -join ", ") } else { "Sin Letra" }

            $usbList += [PSCustomObject]@{
                Index        = $idx
                Model        = $wd.Caption
                BusType      = "USB"
                SizeGB       = $sizeGB
                Letters      = $letterStr
                IsSystem     = ($idx -eq $systemDiskNum)
                Style        = "N/D"
            }
        }
    } catch {}

    return $usbList
}

function Show-UsbBootMatrix {
    cabecera
    Write-Header "OPCION 21.0: MATRIZ DE ARQUITECTURA DE ARRANQUE USB (LEGACY vs UEFI vs MULTIBOOT)"

    Write-Host "`n==========================================================================================" -ForegroundColor Cyan
    Write-Host "         MATRIZ COMPARATIVA PARA PREPARACION DE DISPOSITIVOS EXTERNOS / USB BOOTEABLE     " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Cyan

    $matrix = @(
        [PSCustomObject]@{
            "Modalidad"       = "Windows Legacy BIOS"
            "Tabla Part."     = "MBR"
            "Sistema Arch."   = "NTFS (Recom.) / FAT32"
            "Particion Act."  = "SI (OBLIGATORIA)"
            "Rol BootSect"    = "Inyecta firma NT60 en MBR/PBR"
            "Limite WIM"      = "Sin limite (NTFS soporta >4GB)"
            "Arranque UEFI"   = "No compatible de forma nativa"
        },
        [PSCustomObject]@{
            "Modalidad"       = "Windows UEFI Nativo"
            "Tabla Part."     = "GPT (ESP) / MBR"
            "Sistema Arch."   = "FAT32 (Estandar UEFI)"
            "Particion Act."  = "NO (Ignorada por UEFI)"
            "Rol BootSect"    = "No se utiliza (busca EFI)"
            "Limite WIM"      = "FAT32 max 4GB -> Split WIM (.swm)"
            "Arranque UEFI"   = "100% Nativo (Secure Boot)"
        },
        [PSCustomObject]@{
            "Modalidad"       = "Windows UEFI Dual-Part"
            "Tabla Part."     = "MBR o GPT"
            "Sistema Arch."   = "P1: FAT32 (2GB) + P2: NTFS"
            "Particion Act."  = "P1 Activa si MBR"
            "Rol BootSect"    = "Opcional en P1"
            "Limite WIM"      = "Sin limite (WIM en P2 NTFS)"
            "Arranque UEFI"   = "Excelente en placas modernas"
        },
        [PSCustomObject]@{
            "Modalidad"       = "Linux Live USB"
            "Tabla Part."     = "MBR o GPT (Hibrido)"
            "Sistema Arch."   = "FAT32 (etiqueta LINUX_LIVE)"
            "Particion Act."  = "Requerido para Legacy"
            "Rol BootSect"    = "Syslinux/GRUB2 MBR"
            "Limite WIM"      = "N/A (SquashFS kernel <4GB)"
            "Arranque UEFI"   = "Nativo con BOOTX64.EFI"
        },
        [PSCustomObject]@{
            "Modalidad"       = "Multiboot Ventoy CLI"
            "Tabla Part."     = "GPT o MBR (Dual VTOY)"
            "Sistema Arch."   = "P1 exFAT (ISOs) + P2 FAT (VTOY)"
            "Particion Act."  = "Automatizada por Ventoy"
            "Rol BootSect"    = "GRUB2 Multiplataforma"
            "Limite WIM"      = "Sin limite (Copia directa .ISO)"
            "Arranque UEFI"   = "Dual: Legacy BIOS + UEFI Secure"
        }
    )

    $matrix | Format-Table -AutoSize

    Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[REGLAS DE ORO PARA EL TECNICO / ADMINISTRADOR]:" -ForegroundColor White
    Write-Host " 1. BOOTSECT.EXE (/nt60 X: /mbr):" -ForegroundColor Cyan
    Write-Host "    - En modo Legacy BIOS, si el USB fue formateado sin inyectar bootsect, la BIOS podria indicar" -ForegroundColor Gray
    Write-Host "      'Operating System not found' o 'Non-system disk'. La opcion 21.2 asegura la escritura NT60." -ForegroundColor Gray
    Write-Host "`n 2. LIMITACION DE 4 GB DE FAT32 EN WINDOWS UEFI:" -ForegroundColor Cyan
    Write-Host "    - Los instaladores modernos de Win 10/11 incluyen 'install.wim' de 4.5 GB a 6.5 GB." -ForegroundColor Gray
    Write-Host "    - Opcion 21.3 resuelve esto dividiendo el WIM en partes .swm mediante DISM oficial." -ForegroundColor Yellow
    Write-Host "    - Opcion 21.4 resuelve esto con doble particion: arranque en FAT32 y datos en NTFS." -ForegroundColor Yellow
    Write-Host "`n 3. MULTIBOOT DE MULTIPLES SISTEMAS (Windows + Linux):" -ForegroundColor Cyan
    Write-Host "    - La herramienta universal por excelencia es Ventoy (Opcion 21.7), que permite arrastrar" -ForegroundColor Gray
    Write-Host "      multiples ISOs a la particion sin descomprimirlas, con soporte UEFI + Legacy simultaneo." -ForegroundColor Gray
    Write-Host "==========================================================================================`n" -ForegroundColor Cyan
}

function Deploy-IsoToUsb {
    param(
        [Parameter(Mandatory=$true)][string]$IsoPath,
        [Parameter(Mandatory=$true)][string]$TargetLetter,
        [bool]$CheckFat32Split = $false
    )
    if (-not (Test-Path $IsoPath)) {
        Write-Host "[ERROR] El archivo ISO no existe en la ruta: $IsoPath" -ForegroundColor Red
        return $false
    }

    $cleanTarget = if ($TargetLetter.EndsWith("\")) { $TargetLetter } else { "$TargetLetter\" }
    Write-Host "`n[ISO DEPLOY] Accediendo a la imagen ISO de instalacion: $IsoPath..." -ForegroundColor Cyan

    $isoDriveLetter = ""
    try {
        if (Get-Command Mount-DiskImage -ErrorAction SilentlyContinue) {
            $mountRes = Mount-DiskImage -ImagePath $IsoPath -PassThru -ErrorAction Stop
            Start-Sleep -Seconds 1
            $vol = Get-DiskImage -ImagePath $IsoPath | Get-Volume -ErrorAction SilentlyContinue
            if ($vol -and $vol.DriveLetter) {
                $isoDriveLetter = "$($vol.DriveLetter):\"
            }
        }
    } catch {
        Write-Host "[ADVERTENCIA] Mount-DiskImage no pudo montar automaticamente: $_" -ForegroundColor Yellow
    }

    if (-not $isoDriveLetter -or -not (Test-Path $isoDriveLetter)) {
        Write-Host "No se pudo montar la ISO de forma directa." -ForegroundColor Yellow
        $isoInput = Read-Host "Si la ISO ya esta montada en una unidad virtual, ingrese su letra (Ej: E:)"
        if ($isoInput -and (Test-Path "$isoInput\")) {
            $isoDriveLetter = if ($isoInput.EndsWith("\")) { $isoInput } else { "$isoInput\" }
        } else {
            Write-Host "[ERROR] No se pudo acceder a los archivos de la ISO." -ForegroundColor Red
            return $false
        }
    }

    Write-Host "  -> Unidad de origen (ISO) : $isoDriveLetter" -ForegroundColor Green
    Write-Host "  -> Unidad de destino (USB): $cleanTarget" -ForegroundColor Green

    # Comprobación de install.wim > 4GB en sistemas FAT32
    $wimPath = Join-Path $isoDriveLetter "sources\install.wim"
    $needsSplit = $false
    if ($CheckFat32Split -and (Test-Path $wimPath)) {
        $wimItem = Get-Item $wimPath -ErrorAction SilentlyContinue
        if ($wimItem -and ($wimItem.Length -gt 4100000000)) { # > 3.8 GB
            $needsSplit = $true
            Write-Host "`n[DETECCION CRITICA WIM] 'install.wim' pesa $([Math]::Round($wimItem.Length / 1GB, 2)) GB (supera los 4GB de FAT32)." -ForegroundColor Yellow
            Write-Host "Se ejecutara la copia con division automatica de WIM en fragmentos .SWM mediante DISM..." -ForegroundColor Cyan
        }
    }

    try {
        if ($needsSplit) {
            # 1. Copiar todos los archivos EXCEPTO install.wim con robocopy
            Write-Host "`nTransfiriendo archivos de instalacion base (excluyendo install.wim)..." -ForegroundColor White
            & robocopy.exe "$isoDriveLetter" "$cleanTarget" /E /XF "install.wim" /R:1 /W:1 /NP /NDL
            
            # 2. Ejecutar DISM Split-Image
            $targetSources = Join-Path $cleanTarget "sources"
            if (-not (Test-Path $targetSources)) { New-Item -ItemType Directory -Path $targetSources -Force | Out-Null }
            $swmDestination = Join-Path $targetSources "install.swm"

            Write-Host "`nEjecutando: dism.exe /Split-Image /ImageFile:`"$wimPath`" /SWMFile:`"$swmDestination`" /FileSize:3800" -ForegroundColor Cyan
            Write-Host "Por favor espere mientras DISM divide el archivo wim..." -ForegroundColor Yellow
            & dism.exe /Split-Image /ImageFile:"$wimPath" /SWMFile:"$swmDestination" /FileSize:3800

            if ($LASTEXITCODE -eq 0) {
                Write-Host "`n[EXITO DISM] Imagen WIM dividida correctamente en partes .swm compatibles con UEFI." -ForegroundColor Green
            } else {
                Write-Host "`n[ERROR DISM] Fallo al dividir la imagen WIM (Codigo: $LASTEXITCODE)." -ForegroundColor Red
            }
        } else {
            # Copia completa directa
            Write-Host "`nTransfiriendo archivos de instalacion a la memoria USB..." -ForegroundColor White
            & robocopy.exe "$isoDriveLetter" "$cleanTarget" /E /R:1 /W:1 /NP /NDL
            Write-Host "`n[EXITO COPIA] Transferencia de archivos finalizada con exito." -ForegroundColor Green
        }
        return $true
    }
    catch {
        Write-Host "`n[ERROR EN DESPLIEGUE]: $_" -ForegroundColor Red
        return $false
    }
    finally {
        # Desmontar ISO si fue montada automáticamente
        try {
            if (Get-Command Dismount-DiskImage -ErrorAction SilentlyContinue) {
                Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue | Out-Null
            }
        } catch {}
    }
}

function Format-UsbWindowsLegacy {
    param(
        [Parameter(Mandatory=$false)][bool]$InjectBootSect = $true,
        [Parameter(Mandatory=$false)][string]$IsoPath = ""
    )
    cabecera
    $tituloModo = if ($InjectBootSect) { "CON BOOTSECT (NT60 MBR)" } else { "SIN BOOTSECT (SOLO PARTICION ACTIVA)" }
    Write-Header "OPCION 21: PREPARACION USB WINDOWS - MODO LEGACY BIOS ($tituloModo)"

    $discos = Get-SafeUsbDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron memorias USB o unidades extraibles." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES EXTRAIBLES / USB DETECTADAS ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        $color = if ($d.IsSystem) { "Magenta" } else { "Green" }
        Write-Host ("  [Disco {0}] {1} | Tamano: {2} GB | Letra(s): {3}" -f $d.Index, $d.Model, $d.SizeGB, $d.Letters) -ForegroundColor $color
    }

    Write-Host "`n[0] CANCELAR y volver al menu anterior" -ForegroundColor Yellow
    $discoSel = Read-Host "`nIngrese el numero de disco USB a preparar"
    if ($null -eq $discoSel -or $discoSel -notmatch '^\d+$' -or $discoSel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$discoSel
    $targetDisk = $discos | Where-Object { $_.Index -eq $discoIndex }
    if ($null -eq $targetDisk) {
        Write-Host "[ERROR] El disco $discoIndex no existe en la lista de unidades USB." -ForegroundColor Red
        return
    }

    if ($targetDisk.IsSystem) {
        Write-Host "`n[BLOQUEO DE SEGURIDAD CRITICO] El disco seleccionado contiene el Sistema Operativo." -ForegroundColor Red
        return
    }

    Write-Host "`n==========================================================================================" -ForegroundColor Red
    Write-Host "                 ADVERTENCIA CRITICA DE ELIMINACION DE DATOS EN USB                       " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red
    Write-Host " Se eliminaran TODOS los datos en el [Disco $discoIndex] $($targetDisk.Model) ($($targetDisk.SizeGB) GB)." -ForegroundColor White
    Write-Host " Esquema: MBR / Particion Primaria Unica NTFS (ACTIVA)" -ForegroundColor Yellow
    Write-Host " BootSect: $(if ($InjectBootSect) { 'SI (Inyeccion bootsect /nt60 /mbr)' } else { 'NO (Sin tocar PBR)' })" -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red

    $confirmacion = Read-Host "Para PROCEDER escriba exactamente 'CONFIRMAR'"
    if ($confirmacion.Trim().ToUpper() -ne "CONFIRMAR") {
        Write-Host "Confirmacion denegada. Operacion cancelada." -ForegroundColor Yellow
        return
    }

    $diskpartCmds = @(
        "select disk $discoIndex",
        "clean",
        "convert mbr",
        "create partition primary",
        "active",
        "format fs=ntfs quick label=`"WIN_LEGACY`"",
        "assign",
        "exit"
    )

    $exitCode = Invoke-DiskpartBatch -Commands $diskpartCmds
    if ($exitCode -eq 0) {
        Write-Host "`n[EXITO] Unidad USB formateada en NTFS MBR y marcada como ACTIVA." -ForegroundColor Green
        Start-Sleep -Seconds 1
        
        $refreshed = Get-SafeUsbDiskList | Where-Object { $_.Index -eq $discoIndex }
        $letra = ($refreshed.Letters -split ",")[0].Trim()

        if ($InjectBootSect -and $letra) {
            Write-Host "`nInyectando cargador maestro BOOTMGR con bootsect.exe en $letra..." -ForegroundColor Cyan
            try {
                & bootsect.exe /nt60 "$letra" /mbr
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[OK] Codigo BOOTMGR inyectado correctamente en el MBR y PBR de $letra." -ForegroundColor Green
                } else {
                    Write-Host "[ADVERTENCIA] Bootsect finalizo con codigo: $LASTEXITCODE" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "[ERROR] No se pudo invocar bootsect.exe: $_" -ForegroundColor Red
            }
        }

        $confIso = Read-Host "`nDesea volcar los archivos desde una imagen ISO de Windows ahora? (S/N)"
        if ($confIso.ToUpper() -eq "S") {
            $isoInput = Read-Host "Ingrese la ruta completa del archivo .ISO de Windows"
            $isoInput = $isoInput.Trim().Trim('"').Trim("'")
            if (Test-Path $isoInput) {
                Deploy-IsoToUsb -IsoPath $isoInput -TargetLetter $letra -CheckFat32Split $false
            } else {
                Write-Host "[ERROR] Archivo ISO no encontrado: $isoInput" -ForegroundColor Red
            }
        } else {
            Write-Host "`n[OK] El USB quedo preparado y listo para que copies los archivos de instalacion manualmente." -ForegroundColor Green
        }
    } else {
        Write-Host "`n[ERROR] Diskpart concluyo con codigo de error: $exitCode" -ForegroundColor Red
    }
}

function Format-UsbWindowsUEFI {
    cabecera
    Write-Header "OPCION 21.3: PREPARACION USB WINDOWS - MODO UEFI NATIVO (GPT / FAT32 CON SPLIT WIM DISM)"

    $discos = Get-SafeUsbDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron memorias USB o unidades extraibles." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES EXTRAIBLES / USB DETECTADAS ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        $color = if ($d.IsSystem) { "Magenta" } else { "Green" }
        Write-Host ("  [Disco {0}] {1} | Tamano: {2} GB | Letra(s): {3}" -f $d.Index, $d.Model, $d.SizeGB, $d.Letters) -ForegroundColor $color
    }

    Write-Host "`n[0] CANCELAR y volver al menu anterior" -ForegroundColor Yellow
    $discoSel = Read-Host "`nIngrese el numero de disco USB a preparar en GPT-UEFI"
    if ($null -eq $discoSel -or $discoSel -notmatch '^\d+$' -or $discoSel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$discoSel
    $targetDisk = $discos | Where-Object { $_.Index -eq $discoIndex }
    if ($null -eq $targetDisk) {
        Write-Host "[ERROR] El disco $discoIndex no existe en la lista de unidades USB." -ForegroundColor Red
        return
    }

    if ($targetDisk.IsSystem) {
        Write-Host "`n[BLOQUEO DE SEGURIDAD CRITICO] El disco seleccionado contiene el Sistema Operativo." -ForegroundColor Red
        return
    }

    Write-Host "`n==========================================================================================" -ForegroundColor Red
    Write-Host "                 ADVERTENCIA CRITICA DE ELIMINACION DE DATOS EN USB                       " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red
    Write-Host " Se eliminaran TODOS los datos en el [Disco $discoIndex] $($targetDisk.Model) ($($targetDisk.SizeGB) GB)." -ForegroundColor White
    Write-Host " Esquema: GPT (GUID Partition Table) / Particion Primaria FAT32 (Etiqueta 'WIN_UEFI')" -ForegroundColor Yellow
    Write-Host " Compatibilidad: 100% Nativo UEFI (Soporte oficial de Secure Boot)" -ForegroundColor Yellow
    Write-Host " Division WIM: Automatizada con DISM si install.wim supera los 4GB" -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red

    $confirmacion = Read-Host "Para PROCEDER escriba exactamente 'CONFIRMAR'"
    if ($confirmacion.Trim().ToUpper() -ne "CONFIRMAR") {
        Write-Host "Confirmacion denegada. Operacion cancelada." -ForegroundColor Yellow
        return
    }

    $diskpartCmds = @(
        "select disk $discoIndex",
        "clean",
        "convert gpt",
        "create partition primary",
        "format fs=fat32 quick label=`"WIN_UEFI`"",
        "assign",
        "exit"
    )

    $exitCode = Invoke-DiskpartBatch -Commands $diskpartCmds
    if ($exitCode -eq 0) {
        Write-Host "`n[EXITO] Unidad USB formateada en GPT FAT32 para UEFI nativo." -ForegroundColor Green
        Start-Sleep -Seconds 1
        
        $refreshed = Get-SafeUsbDiskList | Where-Object { $_.Index -eq $discoIndex }
        $letra = ($refreshed.Letters -split ",")[0].Trim()

        $confIso = Read-Host "`nDesea volcar los archivos desde una imagen ISO de Windows ahora? (S/N)"
        if ($confIso.ToUpper() -eq "S") {
            $isoInput = Read-Host "Ingrese la ruta completa del archivo .ISO de Windows"
            $isoInput = $isoInput.Trim().Trim('"').Trim("'")
            if (Test-Path $isoInput) {
                Deploy-IsoToUsb -IsoPath $isoInput -TargetLetter $letra -CheckFat32Split $true
            } else {
                Write-Host "[ERROR] Archivo ISO no encontrado: $isoInput" -ForegroundColor Red
            }
        } else {
            Write-Host "`n[OK] El USB quedo preparado en FAT32 GPT. Recuerde que si copia install.wim manualmente, debe pesar menos de 4GB o usar DISM /Split-Image." -ForegroundColor Yellow
        }
    } else {
        Write-Host "`n[ERROR] Diskpart concluyo con codigo de error: $exitCode" -ForegroundColor Red
    }
}

function Format-UsbWindowsDualPartition {
    cabecera
    Write-Header "OPCION 21.4: PREPARACION USB WINDOWS - MODO UEFI DUAL-PARTITION (FAT32 BOOT + NTFS DATOS)"

    $discos = Get-SafeUsbDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron memorias USB o unidades extraibles." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES EXTRAIBLES / USB DETECTADAS ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        $color = if ($d.IsSystem) { "Magenta" } else { "Green" }
        Write-Host ("  [Disco {0}] {1} | Tamano: {2} GB | Letra(s): {3}" -f $d.Index, $d.Model, $d.SizeGB, $d.Letters) -ForegroundColor $color
    }

    Write-Host "`n[0] CANCELAR y volver al menu anterior" -ForegroundColor Yellow
    $discoSel = Read-Host "`nIngrese el numero de disco USB a preparar con particion dual"
    if ($null -eq $discoSel -or $discoSel -notmatch '^\d+$' -or $discoSel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$discoSel
    $targetDisk = $discos | Where-Object { $_.Index -eq $discoIndex }
    if ($null -eq $targetDisk) {
        Write-Host "[ERROR] El disco $discoIndex no existe en la lista de unidades USB." -ForegroundColor Red
        return
    }

    if ($targetDisk.IsSystem) {
        Write-Host "`n[BLOQUEO DE SEGURIDAD CRITICO] El disco seleccionado contiene el Sistema Operativo." -ForegroundColor Red
        return
    }

    Write-Host "`n==========================================================================================" -ForegroundColor Red
    Write-Host "                   ADVERTENCIA CRITICA DE PARTICIONADO DUAL UEFI                         " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red
    Write-Host " Se eliminaran TODOS los datos en el [Disco $discoIndex] $($targetDisk.Model) ($($targetDisk.SizeGB) GB)." -ForegroundColor White
    Write-Host " Estructura a crear:" -ForegroundColor Yellow
    Write-Host "  - Particion 1: 2048 MB (FAT32) -> Etiqueta 'BOOT_UEFI' (Cargador EFI + WinPE boot.wim)" -ForegroundColor Gray
    Write-Host "  - Particion 2: Resto de la unidad (NTFS) -> Etiqueta 'WIN_DATA' (Soporta install.wim > 4GB)" -ForegroundColor Gray
    Write-Host "==========================================================================================" -ForegroundColor Red

    $confirmacion = Read-Host "Para PROCEDER escriba exactamente 'CONFIRMAR'"
    if ($confirmacion.Trim().ToUpper() -ne "CONFIRMAR") {
        Write-Host "Confirmacion denegada. Operacion cancelada." -ForegroundColor Yellow
        return
    }

    Write-Host "`nSeleccione el esquema de particiones:" -ForegroundColor Cyan
    Write-Host "  [1] GPT (GUID Partition Table) -> [RECOMENDADO para UEFI nativo y visibilidad multi-particion]" -ForegroundColor Green
    Write-Host "  [2] MBR (Master Boot Record)   -> [Compatibilidad dual con equipos Legacy BIOS y UEFI antiguos]" -ForegroundColor Yellow
    $esqSel = Read-Host "Elija el esquema (1 para GPT [Default], 2 para MBR)"
    $useGpt = ($esqSel -ne "2")
    $tablaTexto = if ($useGpt) { "GPT" } else { "MBR" }

    $diskpartCmds = if ($useGpt) {
        @(
            "select disk $discoIndex",
            "clean",
            "convert gpt",
            "create partition primary size=2048",
            "format fs=fat32 quick label=`"BOOT_UEFI`"",
            "assign",
            "create partition primary",
            "format fs=ntfs quick label=`"WIN_DATA`"",
            "assign",
            "exit"
        )
    } else {
        @(
            "select disk $discoIndex",
            "clean",
            "convert mbr",
            "create partition primary size=2048",
            "active",
            "format fs=fat32 quick label=`"BOOT_UEFI`"",
            "assign",
            "create partition primary",
            "format fs=ntfs quick label=`"WIN_DATA`"",
            "assign",
            "exit"
        )
    }

    $exitCode = Invoke-DiskpartBatch -Commands $diskpartCmds
    if ($exitCode -eq 0) {
        Write-Host "`n[EXITO] Unidad USB particionada en modo Dual $tablaTexto (FAT32 Boot + NTFS Datos)." -ForegroundColor Green
        Start-Sleep -Seconds 3
        
        $confIso = Read-Host "`nDesea volcar los archivos desde una imagen ISO de Windows ahora? (S/N)"
        if ($confIso.ToUpper() -eq "S") {
            $isoPath = Read-Host "Ingrese la ruta completa del archivo .ISO de Windows"
            $isoPath = $isoPath.Trim().Trim('"').Trim("'")
            if (Test-Path $isoPath) {
                # Obtener las dos letras asignadas de forma robusta por partición y etiqueta
                $bootLetter = ""
                $dataLetter = ""
                
                $p1 = Get-Partition -DiskNumber $discoIndex -PartitionNumber 1 -ErrorAction SilentlyContinue
                $p2 = Get-Partition -DiskNumber $discoIndex -PartitionNumber 2 -ErrorAction SilentlyContinue
                if ($p1 -and $p1.DriveLetter) { $bootLetter = "$($p1.DriveLetter):" }
                if ($p2 -and $p2.DriveLetter) { $dataLetter = "$($p2.DriveLetter):" }

                if (-not $bootLetter -or -not $dataLetter) {
                    $vols = Get-Volume -ErrorAction SilentlyContinue
                    $vBoot = $vols | Where-Object { $_.FileSystemLabel -eq "BOOT_UEFI" -and $_.DriveLetter }
                    $vData = $vols | Where-Object { $_.FileSystemLabel -eq "WIN_DATA" -and $_.DriveLetter }
                    if ($vBoot) { $bootLetter = "$($vBoot.DriveLetter):" }
                    if ($vData) { $dataLetter = "$($vData.DriveLetter):" }
                }

                if (-not $bootLetter -or -not $dataLetter) {
                    $refreshed = Get-SafeUsbDiskList | Where-Object { $_.Index -eq $discoIndex }
                    $letraList = $refreshed.Letters -split ","
                    if ($letraList.Count -ge 2) {
                        $bootLetter = $letraList[0].Trim()
                        $dataLetter = $letraList[1].Trim()
                    }
                }

                if ($bootLetter -and $dataLetter) {
                    Write-Host "`n[ASIGNACION DETECTADA]:" -ForegroundColor Cyan
                    Write-Host "  -> Particion de arranque FAT32 (BOOT_UEFI) : $bootLetter" -ForegroundColor Green
                    Write-Host "  -> Particion de datos NTFS   (WIN_DATA)   : $dataLetter" -ForegroundColor Green

                    # 1. Copiar todo el contenido de la ISO a la partición de datos NTFS
                    Write-Host "`n[FASE 1] Volcando contenido completo de la ISO a la particion de datos ($dataLetter)..." -ForegroundColor Yellow
                    Deploy-IsoToUsb -IsoPath $isoPath -TargetLetter $dataLetter -CheckFat32Split $false

                    # 2. Configurar archivos de arranque y WinPE en la partición FAT32
                    Write-Host "`n[FASE 2] Configurando cargador EFI y entorno WinPE en particion de arranque ($bootLetter)..." -ForegroundColor Yellow
                    
                    if (Test-Path "$dataLetter\efi") {
                        Write-Host "  -> Sincronizando directorio EFI..." -ForegroundColor Cyan
                        & robocopy.exe "$dataLetter\efi" "$bootLetter\efi" /E /R:1 /W:1 /NP /NDL | Out-Null
                    }
                    if (Test-Path "$dataLetter\boot") {
                        Write-Host "  -> Sincronizando directorio BOOT (fuentes, sdi, bcd)..." -ForegroundColor Cyan
                        & robocopy.exe "$dataLetter\boot" "$bootLetter\boot" /E /R:1 /W:1 /NP /NDL | Out-Null
                    }
                    if (Test-Path "$dataLetter\bootmgr") {
                        Copy-Item "$dataLetter\bootmgr" "$bootLetter\" -Force -ErrorAction SilentlyContinue
                    }
                    if (Test-Path "$dataLetter\bootmgr.efi") {
                        Copy-Item "$dataLetter\bootmgr.efi" "$bootLetter\" -Force -ErrorAction SilentlyContinue
                    }
                    if (Test-Path "$dataLetter\setup.exe") {
                        Copy-Item "$dataLetter\setup.exe" "$bootLetter\" -Force -ErrorAction SilentlyContinue
                    }
                    if (Test-Path "$dataLetter\autorun.inf") {
                        Copy-Item "$dataLetter\autorun.inf" "$bootLetter\" -Force -ErrorAction SilentlyContinue
                    }
                    if (Test-Path "$dataLetter\boot.catalog") {
                        Copy-Item "$dataLetter\boot.catalog" "$bootLetter\" -Force -ErrorAction SilentlyContinue
                    }
                    if (Test-Path "$dataLetter\support") {
                        & robocopy.exe "$dataLetter\support" "$bootLetter\support" /E /R:1 /W:1 /NP /NDL | Out-Null
                    }

                    # COPIA CRITICA: Copiar sources\boot.wim a la partición FAT32 (Resuelve el error 0xc000000f)
                    $bootSourcesDir = Join-Path $bootLetter "sources"
                    if (-not (Test-Path $bootSourcesDir)) {
                        New-Item -ItemType Directory -Path $bootSourcesDir -Force | Out-Null
                    }

                    $srcBootWim = Join-Path $dataLetter "sources\boot.wim"
                    if (Test-Path $srcBootWim) {
                        $wimSizeMB = [Math]::Round((Get-Item $srcBootWim).Length / 1MB, 2)
                        Write-Host "  -> [RESOLUCION 0xc000000f] Copiando 'sources\boot.wim' ($wimSizeMB MB) a $bootSourcesDir..." -ForegroundColor Cyan
                        Copy-Item $srcBootWim (Join-Path $bootSourcesDir "boot.wim") -Force
                        Write-Host "  -> [OK] Entorno WinPE (boot.wim) transferido con exito a la particion FAT32." -ForegroundColor Green
                    } else {
                        Write-Host "  -> [ERROR CRITICO] No se encontro 'sources\boot.wim' en la ISO montada." -ForegroundColor Red
                    }

                    if (Test-Path "$dataLetter\sources\lang.ini") {
                        Copy-Item "$dataLetter\sources\lang.ini" (Join-Path $bootSourcesDir "lang.ini") -Force -ErrorAction SilentlyContinue
                    }
                    if (Test-Path "$dataLetter\sources\setup.exe") {
                        Copy-Item "$dataLetter\sources\setup.exe" "$bootSourcesDir\" -Force -ErrorAction SilentlyContinue
                    }
                    if (Test-Path "$dataLetter\sources\setupplatform.dll") {
                        Copy-Item "$dataLetter\sources\setupplatform.dll" "$bootSourcesDir\" -Force -ErrorAction SilentlyContinue
                    }
                    if (Test-Path "$dataLetter\sources\setupplatform.exe") {
                        Copy-Item "$dataLetter\sources\setupplatform.exe" "$bootSourcesDir\" -Force -ErrorAction SilentlyContinue
                    }

                    # 3. Validación y reparación del almacén BCD UEFI y Legacy BIOS
                    Write-Host "`n[FASE 3] Verificando y asegurando integridad del almacen BCD (Boot Configuration Data)..." -ForegroundColor Yellow
                    $bcdUefiPath = "$bootLetter\efi\microsoft\boot\bcd"
                    if (Test-Path $bcdUefiPath) {
                        try {
                            Write-Host "  -> Verificando BCD UEFI en $bcdUefiPath..." -ForegroundColor Cyan
                            & bcdedit.exe /store "$bcdUefiPath" /set '{default}' device "ramdisk=[boot]\sources\boot.wim,{7619dcc8-fafe-11d9-b411-000476eba25f}" 2>$null | Out-Null
                            & bcdedit.exe /store "$bcdUefiPath" /set '{default}' osdevice "ramdisk=[boot]\sources\boot.wim,{7619dcc8-fafe-11d9-b411-000476eba25f}" 2>$null | Out-Null
                            & bcdedit.exe /store "$bcdUefiPath" /set '{7619dcc8-fafe-11d9-b411-000476eba25f}' ramdisksdidevice "boot" 2>$null | Out-Null
                            & bcdedit.exe /store "$bcdUefiPath" /set '{7619dcc8-fafe-11d9-b411-000476eba25f}' ramdisksdipath "\boot\boot.sdi" 2>$null | Out-Null
                            Write-Host "  -> [OK] BCD UEFI validado y enlazado a [boot]\sources\boot.wim." -ForegroundColor Green
                        } catch {
                            Write-Host "  -> [AVISO] Comprobacion BCD finalizo con advertencia menor: $_" -ForegroundColor Yellow
                        }
                    }

                    $bcdBiosPath = "$bootLetter\boot\bcd"
                    if (Test-Path $bcdBiosPath) {
                        try {
                            & bcdedit.exe /store "$bcdBiosPath" /set '{default}' device "ramdisk=[boot]\sources\boot.wim,{7619dcc8-fafe-11d9-b411-000476eba25f}" 2>$null | Out-Null
                            & bcdedit.exe /store "$bcdBiosPath" /set '{default}' osdevice "ramdisk=[boot]\sources\boot.wim,{7619dcc8-fafe-11d9-b411-000476eba25f}" 2>$null | Out-Null
                            & bcdedit.exe /store "$bcdBiosPath" /set '{7619dcc8-fafe-11d9-b411-000476eba25f}' ramdisksdidevice "boot" 2>$null | Out-Null
                            & bcdedit.exe /store "$bcdBiosPath" /set '{7619dcc8-fafe-11d9-b411-000476eba25f}' ramdisksdipath "\boot\boot.sdi" 2>$null | Out-Null
                            Write-Host "  -> [OK] BCD Legacy BIOS validado correctamente." -ForegroundColor Green
                        } catch {}
                    }

                    # 4. Inyección de cargador de arranque con bootsect
                    try {
                        if (Get-Command bootsect.exe -ErrorAction SilentlyContinue) {
                            Write-Host "`n[FASE 4] Inyectando codigo de arranque con bootsect.exe (/nt60)..." -ForegroundColor Yellow
                            if ($useGpt) {
                                & bootsect.exe /nt60 $bootLetter /force 2>&1 | Out-Null
                            } else {
                                & bootsect.exe /nt60 $bootLetter /mbr 2>&1 | Out-Null
                            }
                            Write-Host "  -> [OK] Sector de Particion (NT60) actualizado en $bootLetter." -ForegroundColor Green
                        }
                    } catch {}

                    # 5. Generación de motor de enlace automático WinPE (Auto-Mount WIN_DATA)
                    # Resuelve el error "Falta un controlador de medios que tu PC necesita"
                    Write-Host "`n[FASE 5] Inyectando motor de enlace y auto-montaje de particion de datos para WinPE..." -ForegroundColor Yellow

                    $mountCmdContent = @'
@echo off
rem =========================================================================
rem ShellSW - Auto-montaje de particion NTFS de datos (WIN_DATA) en WinPE
rem Asigna letras a todas las particiones USB para que setup.exe detecte install.wim
rem =========================================================================
mountvol /E >nul 2>&1

set "DP_CMD=%TEMP%\mount_dual_dp.txt"
(
echo rescan
for /L %%i in (0,1,8) do (
    echo select disk %%i
    echo select partition 1
    echo assign
    echo select disk %%i
    echo select partition 2
    echo assign
)
) > "%DP_CMD%"

diskpart /s "%DP_CMD%" >nul 2>&1
if exist "%DP_CMD%" del "%DP_CMD%" >nul 2>&1
exit /b 0
'@

                    $autounattendContent = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>cmd.exe /c "for %d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do if exist %d:\mount_usb.cmd call %d:\mount_usb.cmd"</Path>
                    <Description>Auto Mount USB Data Partition</Description>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="x86" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>cmd.exe /c "for %d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do if exist %d:\mount_usb.cmd call %d:\mount_usb.cmd"</Path>
                    <Description>Auto Mount USB Data Partition</Description>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>cmd.exe /c "for %d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do if exist %d:\mount_usb.cmd call %d:\mount_usb.cmd"</Path>
                    <Description>Auto Mount USB Data Partition</Description>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>
</unattend>
'@

                    try {
                        [System.IO.File]::WriteAllText((Join-Path $bootLetter "mount_usb.cmd"), $mountCmdContent, [System.Text.Encoding]::ASCII)
                        [System.IO.File]::WriteAllText((Join-Path $bootLetter "autounattend.xml"), $autounattendContent, [System.Text.Encoding]::UTF8)

                        [System.IO.File]::WriteAllText((Join-Path $dataLetter "mount_usb.cmd"), $mountCmdContent, [System.Text.Encoding]::ASCII)
                        [System.IO.File]::WriteAllText((Join-Path $dataLetter "autounattend.xml"), $autounattendContent, [System.Text.Encoding]::UTF8)

                        Write-Host "  -> [OK] 'mount_usb.cmd' y 'autounattend.xml' inyectados en particion de arranque ($bootLetter) y datos ($dataLetter)." -ForegroundColor Green
                        Write-Host "  -> [RESOLUCION DEFINITIVA] WinPE asignara automaticamente letra a WIN_DATA al arrancar." -ForegroundColor Green
                    } catch {
                        Write-Host "  -> [AVISO] No se pudo escribir archivos auxiliares de montaje: $_" -ForegroundColor Yellow
                    }

                    Write-Host "`n==========================================================================================" -ForegroundColor Green
                    Write-Host " [EXITO COMPLETO] El USB Dual Partition ha sido creado y verificado con exito." -ForegroundColor Green
                    Write-Host "==========================================================================================" -ForegroundColor Green
                    Write-Host "  - Particion FAT32 ($bootLetter): Contiene EFI, BCD y WinPE (boot.wim) para arrancar en UEFI/Legacy." -ForegroundColor Cyan
                    Write-Host "  - Particion NTFS  ($dataLetter): Contiene el instalador completo e install.wim gigante." -ForegroundColor Cyan
                    Write-Host "  - Esquema Utilizado: $tablaTexto | Motor WinPE: Auto-montaje activo para install.wim." -ForegroundColor Green
                    Write-Host "  - Error 'Falta controlador de medios': Neutralizado mediante enlace por autounattend.xml." -ForegroundColor Green
                } else {
                    Write-Host "[ADVERTENCIA] No se detectaron ambas letras de particion. Verifique en Explorador de Windows." -ForegroundColor Yellow
                }
            } else {
                Write-Host "[ERROR] Ruta ISO no encontrada: $isoPath" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "`n[ERROR] Diskpart finalizo con codigo de error: $exitCode" -ForegroundColor Red
    }
}

function Format-UsbMultibootWindows {
    cabecera
    Write-Header "OPCION 21.5: MULTIBOOT WINDOWS (MULTIPLES VERSIONES WIN 7 / 10 / 11 EN UN USB)"

    Write-Host "`n--- OPCIONES DE ARQUITECTURA MULTIBOOT WINDOWS ---" -ForegroundColor Cyan
    Write-Host "  1. UNIFICAR MULTIPLES EDICIONES CON DISM (WIM Multiversion - Oficial Microsoft)" -ForegroundColor White
    Write-Host "     * Une indices de Windows 10, Windows 11 o Windows 7 en un solo install.wim unificado."
    Write-Host "     * El instalador de Windows presenta un menu interactivo para elegir la version a instalar."
    Write-Host "  2. PREPARAR ESTRUCTURA DE ALMACENAMIENTO MULTI-ISO (Carpetas de Instalacion)" -ForegroundColor White
    Write-Host "     * Prepara el pendrive con particiones y directorios organizados para utilidades de arranque."
    Write-Host "  3. VER GUIA DE CONFIGURACION BCD MULTIBOOT (BCDEdit)" -ForegroundColor White
    Write-Host "     * Muestra las directivas bcdedit para arrancar multiples archivos boot.wim / WinPE."
    Write-Host "  0. Volver al menu anterior" -ForegroundColor Yellow

    $subOp = Read-Host "`nSeleccione la tarea a realizar (1, 2, 3 o 0)"
    switch ($subOp) {
        "1" {
            Write-Host "`n--- UNIFICACION DE IMAGENES WIM MEDIANTE DISM ---" -ForegroundColor Cyan
            $srcWim = Read-Host "Ingrese la ruta del WIM origen (Ej: D:\sources\install.wim)"
            $srcWim = $srcWim.Trim().Trim('"').Trim("'")
            if (-not (Test-Path $srcWim)) {
                Write-Host "[ERROR] El archivo WIM origen no existe: $srcWim" -ForegroundColor Red
                return
            }

            Write-Host "`nObteniendo informacion de indices de: $srcWim..." -ForegroundColor Yellow
            & dism.exe /Get-WimInfo /WimFile:"$srcWim"

            $srcIndex = Read-Host "`nIngrese el numero de Indice a exportar (Ej: 1)"
            $destWim = Read-Host "Ingrese la ruta del WIM destino acumulador (Ej: U:\sources\install.wim)"
            $destWim = $destWim.Trim().Trim('"').Trim("'")
            $destName = Read-Host "Ingrese el nombre visible para esta edicion (Ej: Windows 10 Pro 64-bit)"

            Write-Host "`nEjecutando exportacion con DISM..." -ForegroundColor Cyan
            & dism.exe /Export-Image /SourceImageFile:"$srcWim" /SourceIndex:$srcIndex /DestinationImageFile:"$destWim" /DestinationName:"$destName"

            if ($LASTEXITCODE -eq 0) {
                Write-Host "`n[EXITO] Imagen exportada correctamente al WIM unificado." -ForegroundColor Green
                Write-Host "Puede repetir este proceso con otras ISOs para anadir Windows 11, Windows Server, etc." -ForegroundColor Cyan
            } else {
                Write-Host "`n[ERROR] DISM finalizo con error: $LASTEXITCODE" -ForegroundColor Red
            }
        }
        "2" {
            Write-Host "`n--- PREPARACION DE ESTRUCTURA MULTI-SISTEMA ---" -ForegroundColor Cyan
            $discos = Get-SafeUsbDiskList
            if ($null -eq $discos -or $discos.Count -eq 0) {
                Write-Host "[ERROR] No se detectaron memorias USB conectadas." -ForegroundColor Red
                return
            }
            foreach ($d in $discos) {
                Write-Host ("  [Disco {0}] {1} | {2} GB | Letra(s): {3}" -f $d.Index, $d.Model, $d.SizeGB, $d.Letters) -ForegroundColor Green
            }
            $targetLetter = (Read-Host "`nIngrese la letra de la unidad USB (Ej: F o F:)").Trim().ToUpper()
            $tL = if ($targetLetter -match '^[A-Z]:$') { $targetLetter } elseif ($targetLetter -match '^[A-Z]$') { "$targetLetter" + ":" } else { "" }
            if ($tL -and (Test-Path "$tL\")) {
                $dirs = @("ISOS", "Images\Win10", "Images\Win11", "Images\Win7", "Tools\WinPE", "Drivers")
                foreach ($dir in $dirs) {
                    $p = Join-Path "$tL\" $dir
                    if (-not (Test-Path $p)) {
                        New-Item -ItemType Directory -Path $p -Force | Out-Null
                    }
                }
                Write-Host "`n[EXITO] Estructura de carpetas creada correctamente en $tL\:" -ForegroundColor Green
                Get-ChildItem -Path "$tL\" -Directory | Select-Object Name | Format-Table -AutoSize
            } else {
                Write-Host "[ERROR] Letra de unidad no valida o no accesible." -ForegroundColor Red
            }
        }
        "3" {
            Write-Host "`n==========================================================================================" -ForegroundColor Cyan
            Write-Host "                   GUIA DE COMANDOS BCDEDIT PARA MULTIBOOT DE WINDOWS                     " -ForegroundColor Yellow
            Write-Host "==========================================================================================" -ForegroundColor Cyan
            Write-Host "Para anadir entradas adicionales de arranque (boot.wim) en el BCD de la memoria USB:" -ForegroundColor White
            Write-Host " 1. Copiar GUID de entrada base:" -ForegroundColor Gray
            Write-Host "    bcdedit /store X:\boot\bcd /copy {default} /d `"Instalador Windows 11`"" -ForegroundColor Cyan
            Write-Host " 2. Configurar la ruta del WIM correspondiente (sustituyendo el nuevo {GUID}):" -ForegroundColor Gray
            Write-Host "    bcdedit /store X:\boot\bcd /set {NUEVO-GUID} device ramdisk=[boot]\sources\win11_boot.wim,{ramdiskoptions}" -ForegroundColor Cyan
            Write-Host "    bcdedit /store X:\boot\bcd /set {NUEVO-GUID} osdevice ramdisk=[boot]\sources\win11_boot.wim,{ramdiskoptions}" -ForegroundColor Cyan
            Write-Host " 3. Repetir para cada sistema o herramienta WinPE (Hirens, Gandalf, Win10, etc.)." -ForegroundColor Gray
            Write-Host "==========================================================================================`n" -ForegroundColor Cyan
        }
        Default { Write-Host "Operacion cancelada o no valida." -ForegroundColor Yellow }
    }
}

function Format-UsbLinuxLive {
    cabecera
    Write-Header "OPCION 21.6: PREPARACION USB LIVE PARA SISTEMAS OPERATIVOS LINUX (UBUNTU / DEBIAN / KALI)"

    $discos = Get-SafeUsbDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron memorias USB o unidades extraibles." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES EXTRAIBLES / USB DETECTADAS ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        $color = if ($d.IsSystem) { "Magenta" } else { "Green" }
        Write-Host ("  [Disco {0}] {1} | Tamano: {2} GB | Letra(s): {3}" -f $d.Index, $d.Model, $d.SizeGB, $d.Letters) -ForegroundColor $color
    }

    Write-Host "`n[0] CANCELAR y volver al menu anterior" -ForegroundColor Yellow
    $discoSel = Read-Host "`nIngrese el numero de disco USB para crear instalador Linux Live"
    if ($null -eq $discoSel -or $discoSel -notmatch '^\d+$' -or $discoSel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$discoSel
    $targetDisk = $discos | Where-Object { $_.Index -eq $discoIndex }
    if ($null -eq $targetDisk) {
        Write-Host "[ERROR] El disco $discoIndex no existe en la lista de unidades USB." -ForegroundColor Red
        return
    }

    if ($targetDisk.IsSystem) {
        Write-Host "`n[BLOQUEO DE SEGURIDAD CRITICO] El disco seleccionado contiene el Sistema Operativo." -ForegroundColor Red
        return
    }

    Write-Host "`n==========================================================================================" -ForegroundColor Red
    Write-Host "                     ADVERTENCIA CRITICA DE FORMATEO LINUX LIVE                           " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red
    Write-Host " Se eliminaran TODOS los datos en el [Disco $discoIndex] $($targetDisk.Model)." -ForegroundColor White
    Write-Host " Esquema: MBR / Particion Primaria FAT32 Activa (Etiqueta 'LINUX_LIVE')" -ForegroundColor Yellow
    Write-Host " Compatibilidad: Arranque UEFI nativo (kernel EFI) y Legacy BIOS." -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Red

    $confirmacion = Read-Host "Para PROCEDER escriba exactamente 'CONFIRMAR'"
    if ($confirmacion.Trim().ToUpper() -ne "CONFIRMAR") {
        Write-Host "Confirmacion denegada. Operacion cancelada." -ForegroundColor Yellow
        return
    }

    $diskpartCmds = @(
        "select disk $discoIndex",
        "clean",
        "convert mbr",
        "create partition primary",
        "active",
        "format fs=fat32 quick label=`"LINUX_LIVE`"",
        "assign",
        "exit"
    )

    $exitCode = Invoke-DiskpartBatch -Commands $diskpartCmds
    if ($exitCode -eq 0) {
        Write-Host "`n[EXITO] Unidad USB formateada e inicializada para Linux Live." -ForegroundColor Green
        Start-Sleep -Seconds 1
        
        $refreshed = Get-SafeUsbDiskList | Where-Object { $_.Index -eq $discoIndex }
        $letra = ($refreshed.Letters -split ",")[0].Trim()

        $isoPath = Read-Host "`nIngrese la ruta completa del archivo .ISO de Linux (Ubuntu, Debian, Kali, Fedora, etc.)"
        $isoPath = $isoPath.Trim().Trim('"').Trim("'")
        if (Test-Path $isoPath) {
            Write-Host "`nIniciando despliegue de archivos Linux Live en $letra..." -ForegroundColor Cyan
            Deploy-IsoToUsb -IsoPath $isoPath -TargetLetter $letra -CheckFat32Split $false

            # Opcional: Persistencia casper-rw
            Write-Host "`n--- CONFIGURACION DE PERSISTENCIA (Opcional para Ubuntu / Debian / Kali) ---" -ForegroundColor Cyan
            Write-Host "La persistencia permite guardar documentos, configuraciones y actualizaciones en el pendrive Live."
            $confPers = Read-Host "Desea habilitar un archivo de persistencia 'casper-rw'? (S/N)"
            if ($confPers.ToUpper() -eq "S") {
                $tamanoMB = Read-Host "Ingrese el tamano de la persistencia en MB (Ej: 2048 para 2GB, 4096 para 4GB [max 4095MB])"
                if ($tamanoMB -match '^\d+$') {
                    $mbInt = [int]$tamanoMB
                    if ($mbInt -gt 4095) { $mbInt = 4095 } # Límite FAT32
                    $bytes = [int64]$mbInt * 1024 * 1024
                    $filePath = Join-Path "$letra\" "casper-rw"
                    Write-Host "Creando contenedor de persistencia: $filePath ($mbInt MB)..." -ForegroundColor Yellow
                    try {
                        & fsutil.exe file createnew "$filePath" $bytes
                        Write-Host "[OK] Archivo casper-rw creado. En el menu de arranque GRUB agregue el parametro 'persistent'." -ForegroundColor Green
                    } catch {
                        Write-Host "[ADVERTENCIA] No se pudo crear el archivo con fsutil: $_" -ForegroundColor Yellow
                    }
                }
            }
            Write-Host "`n[EXITO] USB Linux Live creado y listo para arrancar." -ForegroundColor Green
        } else {
            Write-Host "[ADVERTENCIA] No se especifico ISO valida. La unidad quedo formateada y lista para copia manual." -ForegroundColor Yellow
        }
    } else {
        Write-Host "`n[ERROR] Diskpart concluyo con codigo de error: $exitCode" -ForegroundColor Red
    }
}

function Invoke-VentoyMultibootDeploy {
    cabecera
    Write-Header "OPCION 21.7: MULTIBOOT UNIVERSAL ASISTIDO CON MOTOR VENTOY CLI (WINDOWS + LINUX)"

    Write-Host "`n==========================================================================================" -ForegroundColor Cyan
    Write-Host "               VENTOY: EL MOTOR DEFINITIVO PARA MULTIBOOT DIRECTO DE ISOS                " -ForegroundColor Yellow
    Write-Host "==========================================================================================" -ForegroundColor Cyan
    Write-Host " [COMO FUNCIONA]:" -ForegroundColor White
    Write-Host " 1. Ventoy instala un cargador inteligente en un sector protegido del USB." -ForegroundColor Gray
    Write-Host " 2. El resto de la unidad queda como una particion normal de datos (exFAT / NTFS)." -ForegroundColor Gray
    Write-Host " 3. NO necesitas descomprimir ni quemar ISOs: solo COPIAS Y PEGAS tus archivos .ISO" -ForegroundColor Green
    Write-Host "    (Windows 7, 10, 11, Ubuntu, HirensBoot, Clonezilla, etc.) directamente en la memoria." -ForegroundColor Green
    Write-Host " 4. Al arrancar en cualquier equipo (Legacy BIOS o UEFI con Secure Boot), Ventoy muestra" -ForegroundColor Gray
    Write-Host "    un menu grafico con todas las ISOs disponibles para arrancar al instante." -ForegroundColor Gray
    Write-Host "==========================================================================================" -ForegroundColor Cyan

    $discos = Get-SafeUsbDiskList
    if ($null -eq $discos -or $discos.Count -eq 0) {
        Write-Host "[ERROR] No se detectaron memorias USB conectadas." -ForegroundColor Red
        return
    }

    Write-Host "`n--- UNIDADES EXTRAIBLES DETECTADAS ---" -ForegroundColor Cyan
    foreach ($d in $discos) {
        Write-Host ("  [Disco {0}] {1} | Tamano: {2} GB | Letra(s): {3}" -f $d.Index, $d.Model, $d.SizeGB, $d.Letters) -ForegroundColor Green
    }

    Write-Host "`n[0] CANCELAR y volver" -ForegroundColor Yellow
    $discoSel = Read-Host "`nSeleccione el numero de disco USB donde instalar Ventoy"
    if ($null -eq $discoSel -or $discoSel -notmatch '^\d+$' -or $discoSel -eq "0") {
        Write-Host "Operacion cancelada." -ForegroundColor Yellow
        return
    }
    $discoIndex = [int]$discoSel
    $targetDisk = $discos | Where-Object { $_.Index -eq $discoIndex }
    if ($null -eq $targetDisk -or $targetDisk.IsSystem) {
        Write-Host "[ERROR] Unidad no valida o protegida." -ForegroundColor Red
        return
    }

    # Búsqueda de Ventoy2Disk.exe
    $ventoyPaths = @(
        (Join-Path $PSScriptRoot "recursosExtras\Ventoy\Ventoy2Disk.exe"),
        "e:\shellWil\recursosExtras\Ventoy\Ventoy2Disk.exe",
        (Join-Path $env:TEMP "Ventoy\Ventoy2Disk.exe")
    )
    $ventoyExe = ""
    foreach ($vp in $ventoyPaths) {
        if (Test-Path $vp) { $ventoyExe = $vp; break }
    }

    if (-not $ventoyExe) {
        Write-Host "`n[INFO] No se encontro 'Ventoy2Disk.exe' en la carpeta recursosExtras." -ForegroundColor Yellow
        Write-Host "Opciones disponibles:" -ForegroundColor Cyan
        Write-Host "  1. Indicar manualmente la ruta donde tienes descargado Ventoy2Disk.exe" -ForegroundColor White
        Write-Host "  2. Descargar automaticamente la version oficial de Ventoy desde GitHub" -ForegroundColor White
        Write-Host "  0. Cancelar operacion" -ForegroundColor Yellow

        $vOpt = Read-Host "`nElija una opcion (1, 2 o 0)"
        if ($vOpt -eq "1") {
            $mPath = Read-Host "Ingrese la ruta completa a Ventoy2Disk.exe"
            $mPath = $mPath.Trim().Trim('"').Trim("'")
            if (Test-Path $mPath) { $ventoyExe = $mPath } else { Write-Host "[ERROR] Archivo no encontrado." -ForegroundColor Red; return }
        }
        elseif ($vOpt -eq "2") {
            Write-Host "`nDescargando utilidades oficiales de Ventoy..." -ForegroundColor Cyan
            $ventoyZip = Join-Path $env:TEMP "ventoy_temp.zip"
            $ventoyFolder = Join-Path $env:TEMP "Ventoy"
            $url = "https://github.com/ventoy/Ventoy/releases/download/v1.1.05/ventoy-1.1.05-windows.zip"
            try {
                Invoke-WebRequest -Uri $url -OutFile $ventoyZip -UseBasicParsing
                Expand-Archive -Path $ventoyZip -DestinationPath $ventoyFolder -Force
                $found = Get-ChildItem -Path $ventoyFolder -Filter "Ventoy2Disk.exe" -Recurse | Select-Object -First 1
                if ($found) { $ventoyExe = $found.FullName }
            } catch {
                Write-Host "[ERROR DESCARGA] No se pudo descargar automaticamente Ventoy: $_" -ForegroundColor Red
                return
            }
        } else {
            Write-Host "Operacion cancelada." -ForegroundColor Yellow
            return
        }
    }

    if ($ventoyExe -and (Test-Path $ventoyExe)) {
        Write-Host "`n==========================================================================================" -ForegroundColor Red
        Write-Host " ¡ATENCION! SE FORMATEARA Y PREPARARA CON VENTOY EL DISCO $discoIndex ($($targetDisk.Model))" -ForegroundColor Yellow
        Write-Host "==========================================================================================" -ForegroundColor Red
        $conf = Read-Host "Escriba 'CONFIRMAR' para proceder con la instalacion de Ventoy"
        if ($conf.Trim().ToUpper() -ne "CONFIRMAR") {
            Write-Host "Confirmacion denegada. Operacion cancelada." -ForegroundColor Yellow
            return
        }

        Write-Host "`nInstalando bootloader Ventoy en el Disco $discoIndex..." -ForegroundColor Cyan
        try {
            & "$ventoyExe" VTOYCLI /I /Drive:$discoIndex
            if ($LASTEXITCODE -eq 0) {
                Write-Host "`n[EXITO TOTAL] Ventoy ha sido instalado en la memoria USB." -ForegroundColor Green
                Write-Host "Ahora puedes abrir la unidad en el Explorador de Windows y copiar directamente tus archivos .ISO." -ForegroundColor Cyan
            } else {
                Write-Host "Lanzando interfaz interactiva de Ventoy..." -ForegroundColor Yellow
                Start-Process "$ventoyExe"
            }
        } catch {
            Write-Host "[ERROR] Fallo al invocar Ventoy: $_" -ForegroundColor Red
        }
    }
}

function psSubMenuPrepararUSB {
    $salirSub21 = $false
    do {
        cabecera
        Write-Header "OPCION 21. CREAR MEDIO USB BOOTEABLE DE INSTALACION O RESCATE (ORIGEN)"
        Write-Host "  21.0 Tabla / Matriz tecnica: Tecnologias de arranque USB (Legacy vs UEFI vs Multiboot)" -ForegroundColor Cyan
        Write-Host "  21.1 USB Instalador Windows en MBR-Legacy - SIN BootSect (Formateo Activo)" -ForegroundColor Yellow
        Write-Host "  21.2 USB Instalador Windows en MBR-Legacy - CON BootSect (Inyeccion NT60 + ISO)" -ForegroundColor Yellow
        Write-Host "  21.3 USB Instalador Windows en GPT-UEFI (FAT32) con Split WIM oficial DISM" -ForegroundColor Yellow
        Write-Host "  21.4 USB Instalador Windows en Modo UEFI con Particion Dual (FAT32 Boot + NTFS Datos)" -ForegroundColor Yellow
        Write-Host "  21.5 Multiboot Windows (Legacy y UEFI) - Multiples Versiones Win 7/10/11 en un USB" -ForegroundColor Yellow
        Write-Host "  21.6 USB Instalador Live para Sistemas Operativos Linux (Ubuntu / Debian / Kali)" -ForegroundColor Yellow
        Write-Host "  21.7 Multiboot Universal Asistido con Motor Ventoy CLI (Windows + Linux en un USB)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  0. V O L V E R   A L   S U B M E N U   2 0" -ForegroundColor White
        Write-Header "=============================================================================="

        $op21 = Read-Host "Seleccione la tarea a realizar en Preparacion de Medios USB"

        switch ($op21) {
            { $_ -in "21.0", "0.0", "table" } { Show-UsbBootMatrix }
            { $_ -in "21.1", "1" }             { Format-UsbWindowsLegacy -InjectBootSect $false }
            { $_ -in "21.2", "2" }             { Format-UsbWindowsLegacy -InjectBootSect $true }
            { $_ -in "21.3", "3" }             { Format-UsbWindowsUEFI }
            { $_ -in "21.4", "4" }             { Format-UsbWindowsDualPartition }
            { $_ -in "21.5", "5" }             { Format-UsbMultibootWindows }
            { $_ -in "21.6", "6" }             { Format-UsbLinuxLive }
            { $_ -in "21.7", "7" }             { Invoke-VentoyMultibootDeploy }
            "0" { $salirSub21 = $true }
            Default { Write-Host "Opcion invalida." -ForegroundColor Red }
        }

        if (-not $salirSub21) {
            Write-Host ""
            Read-Host "Presione ENTER para continuar en el menu de Preparacion USB..."
        }
    } while (-not $salirSub21)
}

function Invoke-USBPreparationExternalWindow {
    <#
    .SYNOPSIS
        Despacha la ejecución de las funciones del Grupo 21 (Creación de Medios USB Booteables)
        a un proceso y ventana de consola independiente de PowerShell, liberando inmediatamente la
        consola principal para el operador.
    .PARAMETER OpcionDestino
        Código de la opción a ejecutar ("21", "21.0", "21.1", "21.2", "21.3", "21.4", "21.5", "21.6", "21.7").
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$OpcionDestino
    )

    $taskMap = @{
        "21"   = @{ Titulo = "Submenu 21: Crear Medio USB Booteable de Instalacion o Rescate (Origen)"; Cmd = "psSubMenuPrepararUSB" }
        "21.0" = @{ Titulo = "21.0 Matriz de Tecnologias de Arranque USB (Legacy vs UEFI)"; Cmd = "Show-UsbBootMatrix" }
        "21.1" = @{ Titulo = "21.1 USB Instalador Windows en MBR-Legacy - SIN BootSect"; Cmd = "Format-UsbWindowsLegacy -InjectBootSect `$false" }
        "21.2" = @{ Titulo = "21.2 USB Instalador Windows en MBR-Legacy - CON BootSect"; Cmd = "Format-UsbWindowsLegacy -InjectBootSect `$true" }
        "21.3" = @{ Titulo = "21.3 USB Instalador Windows en GPT-UEFI (FAT32 / Split WIM)"; Cmd = "Format-UsbWindowsUEFI" }
        "21.4" = @{ Titulo = "21.4 USB Instalador Windows en UEFI con Particion Dual (FAT32+NTFS)"; Cmd = "Format-UsbWindowsDualPartition" }
        "21.5" = @{ Titulo = "21.5 Multiboot Windows (Legacy y UEFI) - Multiples Versiones"; Cmd = "Format-UsbMultibootWindows" }
        "21.6" = @{ Titulo = "21.6 USB Instalador Live para Sistemas Operativos Linux"; Cmd = "Format-UsbLinuxLive" }
        "21.7" = @{ Titulo = "21.7 Multiboot Universal Asistido con Motor Ventoy CLI"; Cmd = "Invoke-VentoyMultibootDeploy" }
    }

    if (-not $taskMap.ContainsKey($OpcionDestino)) {
        Write-Host "[ERROR] Opcion '$OpcionDestino' no reconocida para preparacion USB." -ForegroundColor Red
        return
    }

    $info = $taskMap[$OpcionDestino]
    $cleanOp = ($OpcionDestino -replace '[^\w]', '_')
    $tempFile = Join-Path $env:TEMP ("shellWil_PrepUSB_" + $cleanOp + "_" + (Get-Random -Minimum 1000 -Maximum 9999) + ".ps1")

    # Lista de funciones del módulo que deben exportarse al subproceso
    $requiredFunctions = @(
        'cabecera',
        'Write-Header',
        'Get-SafeDiskList',
        'Get-SafeUsbDiskList',
        'Invoke-DiskpartBatch',
        'Show-UsbBootMatrix',
        'Deploy-IsoToUsb',
        'Format-UsbWindowsLegacy',
        'Format-UsbWindowsUEFI',
        'Format-UsbWindowsDualPartition',
        'Format-UsbMultibootWindows',
        'Format-UsbLinuxLive',
        'Invoke-VentoyMultibootDeploy',
        'psSubMenuPrepararUSB'
    )

    $sb = New-Object System.Text.StringBuilder

    [void]$sb.AppendLine("# ==========================================================================")
    [void]$sb.AppendLine("# CONSOLA SECUNDARIA AUTONOMA - SHELLSW (PREPARACION USB / RECUPERACION)")
    [void]$sb.AppendLine("# Tarea: $($info.Titulo)")
    [void]$sb.AppendLine("# Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("# ==========================================================================")
    [void]$sb.AppendLine("try { `$Host.UI.RawUI.WindowTitle = 'ShellSW - Preparacion USB [$OpcionDestino]' } catch {}")
    [void]$sb.AppendLine("[Console]::OutputEncoding = [System.Text.Encoding]::UTF8")
    [void]$sb.AppendLine("")

    if (-not (Get-Command 'cabecera' -ErrorAction SilentlyContinue)) {
        [void]$sb.AppendLine(@'
function cabecera {
    Write-Host " ------------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " Ing. Wilson Yucra - Soft. Administracion y Gestion del Sistema Operativo" -ForegroundColor Cyan
    Write-Host " ------------------------------------------------------------------------" -ForegroundColor Cyan
}
'@)
    }

    if (-not (Get-Command 'Write-Header' -ErrorAction SilentlyContinue)) {
        [void]$sb.AppendLine(@'
function Write-Header {
    param([string]$texto)
    $ancho = $texto.Length + 15
    $linea = "=" * $ancho
    Write-Host "`n$linea" -ForegroundColor Yellow
    Write-Host "| $texto |" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "$linea" -ForegroundColor Yellow
}
'@)
    }

    foreach ($fn in $requiredFunctions) {
        $cmd = Get-Command $fn -ErrorAction SilentlyContinue
        if ($cmd) {
            [void]$sb.AppendLine("function $fn {")
            [void]$sb.AppendLine($cmd.Definition)
            [void]$sb.AppendLine("}`n")
        }
    }

    [void]$sb.AppendLine("# --- EJECUCION DE LA TAREA SOLICITADA ---")
    [void]$sb.AppendLine("try {")
    [void]$sb.AppendLine("    $($info.Cmd)")
    [void]$sb.AppendLine("}")
    [void]$sb.AppendLine("catch {")
    [void]$sb.AppendLine("    Write-Host '`n[ERROR CRITICO EN VENTANA SECUNDARIA]: ' `$_.Exception.Message -ForegroundColor Red")
    [void]$sb.AppendLine("}")
    [void]$sb.AppendLine("finally {")
    if ($OpcionDestino -eq "21") {
        [void]$sb.AppendLine("    Write-Host '`n[Cerrando consola secundaria de preparacion USB...]' -ForegroundColor Gray")
        [void]$sb.AppendLine("    Start-Sleep -Milliseconds 600")
        [void]$sb.AppendLine("    try { Remove-Item -Path `$MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue } catch {}")
        [void]$sb.AppendLine("    exit")
    } else {
        [void]$sb.AppendLine("    Write-Host '`n==========================================================================' -ForegroundColor Cyan")
        [void]$sb.AppendLine("    Write-Host ' [PROCESO FINALIZADO] Esta ventana permanecera abierta para su consulta.' -ForegroundColor Green")
        [void]$sb.AppendLine("    Write-Host ' Puede revisar los reportes y cerrarla cuando lo desee.' -ForegroundColor Gray")
        [void]$sb.AppendLine("    Write-Host '==========================================================================' -ForegroundColor Cyan")
        [void]$sb.AppendLine("    Write-Host ''")
        [void]$sb.AppendLine("    Read-Host 'Presione ENTER para cerrar esta ventana...'")
        [void]$sb.AppendLine("    try { Remove-Item -Path `$MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue } catch {}")
        [void]$sb.AppendLine("    exit")
    }
    [void]$sb.AppendLine("}")

    [System.IO.File]::WriteAllText($tempFile, $sb.ToString(), [System.Text.Encoding]::UTF8)

    $procArgs = @(
        "-NoExit",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$tempFile`""
    )

    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList $procArgs -Verb RunAs -ErrorAction Stop
    }
    catch {
        Start-Process -FilePath "powershell.exe" -ArgumentList $procArgs -ErrorAction SilentlyContinue
    }

    Write-Host "`n==========================================================================" -ForegroundColor Cyan
    Write-Host "  [OK] TAREA DESPLEGADA EN UNA VENTANA O CONSOLA INDEPENDIENTE" -ForegroundColor Green
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "  Accion Solicitada : $($info.Titulo)" -ForegroundColor White
    Write-Host "  Opcion / Codigo   : $OpcionDestino" -ForegroundColor Yellow
    Write-Host "  Estado Operativo  : Se ha abierto una consola secundaria de PowerShell." -ForegroundColor Gray
    Write-Host "  Disponibilidad    : Esta consola principal queda 100% LIBRE para su uso" -ForegroundColor Green
    Write-Host "                      inmediato en otras tareas del sistema." -ForegroundColor Gray
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function psSubMenu20 {
    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header "Opcion  20. ---)) LOCAL: INFORMACION SISTEMA CMD [RAM] [HDD] - DISM - RESETEAR RED."
            Write-Host "1. Informacion de la MEMORIA RAM."
            Write-Host "2. Informacion del DISCO DURO."
            Write-Host "  2.1. Capacidad y tipo de DISCO DURO."
            Write-Host "3. Mostrar Unidades Logicas del DISCO DURO."
            Write-Host "4. Aplicaciones que se INICIAN con el SISTEMA OPERATIVO."
            Write-Host "5. Mostrar Errores con aplicaciones en el SISTEMA OPERATIVO."
            Write-Host "6. Mostrar informacion del BIOS."
            Write-Host "  6.1. Modo de Instalacion de Windows Legacy o UEFI."
            Write-Host "7. Mostrar informacion de la PC HARDWARE."
            Write-Host "8. Propiedades del Sistema Operativo (SYSTEMINFO)."
            Write-Host "  8.1. Mostrar Version de Windows."
            Write-Host "  8.2. Mostrar Version de Windows."
            Write-Host "  8.3. Mostrar Version de Windows Script Host."
            Write-Host "  8.4. Mostrar Version WinVer."
            Write-Host "******************************************************************************************"
            Write-Host "9. Escaneo de archivos protegidos del S.O. - Revision Rapida. (sfc /scannow)."
            Write-Host "10. Escanea danios en almacen de componentes "DISM 1" - Dism.exe /Online /Cleanup-Image /ScanHealth"
            Write-Host "11. Comprobacion RAPIDA si imagen esta marcada como daniado "DISM 2" - DISM /Online /Cleanup-Image /CheckHealth"
            Write-Host "12. Si es posible realiza operacion de reparacion automatica "DISM 3" - DISM /Online /Cleanup-Image /RestoreHealth"
            Write-Host "13. Limpia los componentes reemplazados "DISM 4" - Dism.exe /Online /Cleanup-Image /StartComponentCleanup"
            Write-Host "14. Revision Exhaustivo "ANALISIS PROFUNDO" (dism) - Escaneo, reparacion, limpieza y verificacion"
            Write-Host "******************************************************************************************"
            Write-Host "17. Listar Usuarios Windows"
            Write-Host "18. Recursos Compartidos de Windows"
            Write-Host "19. Preparar Disco de Destino (HDD / SSD / NVMe) para S.O. o Almacenamiento [VENTANA EXTERNA]" -ForegroundColor Cyan
            Write-Host "  19.0 Tabla de relacion: Filesystem vs Particion vs Modo Arranque [VENTANA EXTERNA]" -ForegroundColor Yellow
            Write-Host "  19.1 Informacion tecnica detallada de la unidad (Particion, FS, Salud SMART) [VENTANA EXTERNA]" -ForegroundColor Yellow
            Write-Host "  19.2 Verificacion de sectores y revision de superficie (Superficial vs Profunda) [VENTANA EXTERNA]" -ForegroundColor Yellow
            Write-Host "  19.3 Preparar Disco para Windows Legacy (MBR + FAT32/NTFS) - Particion ACTIVA [Win 98/XP/7/10/11] [VENTANA EXTERNA]" -ForegroundColor Yellow
            Write-Host "  19.4 Preparar Disco para Windows UEFI (GPT + NTFS) - Particion de Sistema Lista [VENTANA EXTERNA]" -ForegroundColor Yellow
            Write-Host "  19.5 Limpieza y Reinicializacion Profunda de Disco (Clean / Clean All - Wipe Seguro) [VENTANA EXTERNA]" -ForegroundColor Yellow
            Write-Host "  19.6 Formateo de Almacenamiento General (FAT32/NTFS/exFAT) [Multi-Particion FAT32] [VENTANA EXTERNA]" -ForegroundColor Green
            Write-Host "  19.7 Formateo de Unidades y Discos para GNU/Linux (Particion Nativa RAW / ext4) [VENTANA EXTERNA]" -ForegroundColor Green
            Write-Host "21. Crear Medio USB Booteable de Instalacion o Rescate (Origen) [VENTANA EXTERNA]" -ForegroundColor Cyan
            Write-Host "  21.0 Matriz tecnica de tecnologias de arranque USB (Legacy vs UEFI vs Multiboot)" -ForegroundColor Yellow
            Write-Host "  21.1 USB Instalador Windows en MBR-Legacy - SIN BootSect (Formateo Activo)" -ForegroundColor Yellow
            Write-Host "  21.2 USB Instalador Windows en MBR-Legacy - CON BootSect (Inyeccion NT60 + ISO)" -ForegroundColor Yellow
            Write-Host "  21.3 USB Instalador Windows en GPT-UEFI (FAT32) con Split WIM oficial DISM" -ForegroundColor Yellow
            Write-Host "  21.4 USB Instalador Windows en Modo UEFI con Particion Dual (FAT32 Boot + NTFS Datos)" -ForegroundColor Yellow
            Write-Host "  21.5 Multiboot Windows (Legacy y UEFI) - Multiples Versiones Win 7/10/11 en un USB" -ForegroundColor Yellow
            Write-Host "  21.6 USB Instalador Live para Sistemas Operativos Linux (Ubuntu / Debian / Kali)" -ForegroundColor Yellow
            Write-Host "  21.7 Multiboot Universal Asistido con Motor Ventoy CLI (Windows + Linux en un USB)" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Header "=============================================================================="
            
            $op = Read-Host "Seleccione la tarea a realizar"

            switch ($op) {
                "1" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* DETALLE DE MEMORIA RAM *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # 1. Obtener datos de hardware (Capa física)
                    $physicalMem = Get-WmiObject Win32_PhysicalMemory
                    $memArray = Get-WmiObject -Class Win32_PhysicalMemoryArray
                    # 2. Obtener datos del Sistema Operativo (Uso en tiempo real)
                    $osMem = Get-WmiObject Win32_OperatingSystem
                    $memTotal = [Math]::Round($osMem.TotalVisibleMemorySize / 1MB, 2)
                    $memLibre = [Math]::Round($osMem.FreePhysicalMemory / 1MB, 2)
                    $memEnUso = [Math]::Round($memTotal - $memLibre, 2)
                    $porcentajeUso = [Math]::Round(($memEnUso / $memTotal) * 100, 1)

                    # Función para traducir el tipo de memoria
                    function Get-MemoryType ($type, $speed) {
                        switch ($type) {
                            20 { return "DDR" }
                            21 { return "DDR2" }
                            24 { return "DDR3" }
                            26 { return "DDR4" }
                            34 { return "DDR5" }
                            0 {
                                # Si es 0, intentamos adivinar por la velocidad (MHz)
                                if ($speed -ge 4800) { return "DDR5 (Estimado)" }
                                if ($speed -ge 2133) { return "DDR4 (Estimado)" }
                                if ($speed -ge 1333) { return "DDR3 (Estimado)" }
                                return "Desconocido"
                            }
                            Default { return "Otro ($type)" }
                        }
                    }

                    # 3. Mostrar Capacidad de la Placa y Estado de Uso
                    Write-Host "Capacidad Maxima Soportada : $([Math]::Round($memArray.MaxCapacity / 1MB, 0)) GB"
                    Write-Host "Ranuras Totales            : $($memArray.MemoryDevices)"
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                    Write-Host "Memoria Total instalada    : $memTotal GB" -ForegroundColor White
                    Write-Host "Memoria en Uso             : $memEnUso GB ($porcentajeUso%)" -ForegroundColor Yellow
                    Write-Host "Memoria Disponible         : $memLibre GB" -ForegroundColor Green
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # 4. Detalle de los Módulos (Físico)
                    $detalleModulos = $physicalMem | Select-Object `
                        DeviceLocator, 
                    Manufacturer, 
                    @{Name = "Capacidad"; Expression = { [Math]::Round($_.Capacity / 1GB, 0), "GB" -join " " } },
                    @{Name = "Tipo"; Expression = { Get-MemoryType $_.SMBIOSMemoryType $_.Speed } },
                    @{Name = "Velocidad"; Expression = { $_.Speed, "MHz" -join " " } },
                    PartNumber

                    Write-Host "Detalle por Ranura:" -ForegroundColor Cyan
                    $detalleModulos | Format-Table -AutoSize
                }
                "2" { 
                    cabecera                
                    menuOpcion "Haz elegido el SUB_MENU:  $opcion ;;; Opcion:  $op "

                    #wmic diskdrive get caption,InterfaceType,name,serialnumber,Signature,Size,status
                    
                    Write-Host "`n******* DETALLE DE UNIDADES DE DISCO *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    Get-WmiObject Win32_DiskDrive | Select-Object `
                        Caption, 
                    InterfaceType, 
                    DeviceID, 
                    SerialNumber, 
                    @{Name = "Tamaño(GB)"; Expression = { [Math]::Round($_.Size / 1GB, 2) } }, 
                    Status | 
                    Format-Table -AutoSize

                    #otra alternativa
                    #Get-PhysicalDisk | Select-Object `
                    #FriendlyName, 
                    #SerialNumber, 
                    #MediaType, 
                    #@{Name="Tamaño(GB)"; Expression={[Math]::Round($_.Size / 1GB, 2)}}, 
                    #OperationalStatus, 
                    #HealthStatus | 
                    #Format-Table -AutoSize

                }
                "2.1" { 
                    #clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* CAPACIDAD Y TIPO DE DISCO DURO *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Verificar si existe Get-PhysicalDisk (Windows 8+)
                    if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
                        # Obtenemos todos los discos físicos ordenados por DeviceID
                        $discos = Get-PhysicalDisk | Sort-Object DeviceId

                        if ($null -eq $discos) {
                            Write-Host "No se detectaron unidades de disco en este equipo." -ForegroundColor Yellow
                        }
                        else {
                            foreach ($disk in $discos) {
                                # Intentamos obtener detalles adicionales de almacenamiento
                                $storageDetails = $null
                                try {
                                    $storageDetails = $disk | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
                                } catch {}

                                # Determinar el tipo de disco
                                $tipoDisco = "Disco Rigido (HDD)"
                                if ($disk.BusType -eq "USB" -or $disk.MediaType -eq "Removable" -or $disk.MediaType -eq "External") {
                                    $tipoDisco = "Unidad Extraible"
                                }
                                elseif ($disk.MediaType -eq "SSD") {
                                    $tipoDisco = "Disco Solido (SSD)"
                                }
                                elseif ($disk.FriendlyName -match "SSD|Solid State|NVMe") {
                                    $tipoDisco = "Disco Solido (SSD)"
                                }
                                elseif ($disk.BusType -eq "USB") {
                                    $tipoDisco = "Unidad Extraible"
                                }

                                # Estado de salud
                                $salud = $disk.HealthStatus

                                # Formatear capacidad
                                $capacidadGB = "$([Math]::Round($disk.Size / 1GB, 2)) GB"

                                Write-Host "[ Unidad: $($disk.FriendlyName) ]" -ForegroundColor White -BackgroundColor DarkBlue
                                
                                # Preparar variables para evitar lógica compleja en el hashtable
                                $usoVida = "N/A"
                                if ($storageDetails -and $storageDetails.Wear -ne $null) {
                                    $usoVida = "$($storageDetails.Wear)%"
                                }

                                $temp = "N/A"
                                if ($storageDetails -and $storageDetails.Temperature -ne $null) {
                                    $temp = "$($storageDetails.Temperature)°C"
                                }

                                $nSerie = "Desconocido"
                                if ($disk.SerialNumber) {
                                    $nSerie = $disk.SerialNumber.Trim()
                                }

                                # Tabla de información técnica compatible en formato de lista idéntico al de la imagen
                                New-Object PSObject -Property @{
                                    "Numero"      = $disk.DeviceId
                                    "Modelo"      = $disk.FriendlyName
                                    "Tipo"        = $tipoDisco
                                    "Protocolo"   = $disk.BusType  # NVMe, SATA, USB
                                    "Capacidad"   = $capacidadGB
                                    "EstadoSalud" = $salud
                                    "Uso_Vida"    = $usoVida
                                    "Temp"        = $temp
                                    "N_Serie"     = $nSerie
                                } | Select-Object Numero, Modelo, Tipo, Protocolo, Capacidad, EstadoSalud, Uso_Vida, Temp, N_Serie | Format-List
                                
                                Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                            }
                        }
                    }
                    else {
                        Write-Host "Nota: Get-PhysicalDisk no esta disponible en este sistema operativo (compatible en Windows 8+)." -ForegroundColor Yellow
                        Write-Host "Obteniendo informacion detallada de unidades fisicas a traves de WMI..." -ForegroundColor Yellow
                        Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                        
                        $discosWmi = Get-WmiObject Win32_DiskDrive | Sort-Object Index
                        foreach ($d in $discosWmi) {
                            # Determinar el tipo de disco para Windows 7
                            $tipoDisco = "Disco Rigido (HDD)"
                            if ($d.InterfaceType -eq "USB" -or $d.MediaType -match "External|Removable" -or $d.Model -match "USB|SD Card|Card Reader") {
                                $tipoDisco = "Unidad Extraible"
                            }
                            elseif ($d.Model -match "SSD|Solid State|NVMe|SATA SSD") {
                                $tipoDisco = "Disco Solido (SSD)"
                            }

                            # Estado de salud
                            $salud = $d.Status
                            if ($salud -eq "OK") { $salud = "Healthy" }

                            # Capacidad en GB
                            $capacidadGB = "$([Math]::Round([double]$d.Size / 1GB, 2)) GB"

                            $nSerie = "Desconocido"
                            if ($d.SerialNumber) {
                                $nSerie = $d.SerialNumber.Trim()
                            }

                            Write-Host "[ Unidad: $($d.Model) ]" -ForegroundColor White -BackgroundColor DarkBlue
                            
                            New-Object PSObject -Property @{
                                "Numero"      = $d.Index
                                "Modelo"      = $d.Model
                                "Tipo"        = $tipoDisco
                                "Protocolo"   = $d.InterfaceType  # IDE, SCSI, USB, etc.
                                "Capacidad"   = $capacidadGB
                                "EstadoSalud" = $salud
                                "Uso_Vida"    = "N/A (Requiere Windows 8+)"
                                "Temp"        = "N/A (Requiere Windows 8+)"
                                "N_Serie"     = $nSerie
                            } | Select-Object Numero, Modelo, Tipo, Protocolo, Capacidad, EstadoSalud, Uso_Vida, Temp, N_Serie | Format-List
                            
                            Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                        }
                    }
                }
                "3" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* REPORTE DE UNIDADES DE ALMACENAMIENTO *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtenemos discos locales (DriveType=3) usando WMI para compatibilidad total
                    $unidades = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3"

                    foreach ($u in $unidades) {
                        
                        # Forzamos [double] para evitar errores de desbordamiento en discos grandes
                        $totalBytes = [double]$u.Size
                        $freeBytes = [double]$u.FreeSpace
                        
                        # Conversión a GB (1024^3)
                        $totalGB = [Math]::Round($totalBytes / 1GB, 2)
                        $libreGB = [Math]::Round($freeBytes / 1GB, 2)
                        $usadoGB = [Math]::Round($totalGB - $libreGB, 2)
                        
                        # Cálculo de porcentaje de uso
                        if ($totalGB -gt 0) {
                            $porcentajeUsado = [Math]::Round(($usadoGB / $totalGB) * 100, 1)
                        }
                        else {
                            $porcentajeUsado = 0
                        }

                        # Creación de objeto compatible con PowerShell 2.0
                        $discoReporte = New-Object PSObject
                        $discoReporte | Add-Member -MemberType NoteProperty -Name "Unidad" -Value $u.DeviceID
                        # $discoReporte | Add-Member -MemberType NoteProperty -Name "Nombre" -Value ($u.VolumeName if ($u.VolumeName) { $u.VolumeName } else { "Sin Etiqueta" })
                        $discoReporte | Add-Member -MemberType NoteProperty -Name "Formato" -Value $u.FileSystem
                        $discoReporte | Add-Member -MemberType NoteProperty -Name "Total (GB)" -Value $totalGB
                        $discoReporte | Add-Member -MemberType NoteProperty -Name "Libre (GB)" -Value $libreGB
                        $discoReporte | Add-Member -MemberType NoteProperty -Name "Ocupado (GB)" -Value "$usadoGB ($porcentajeUsado%)"
                        
                        # Salida del objeto
                        $discoReporte
                    }

                    # ****
                    Write-Host "`n******* ANALISIS DE ALMACENAMIENTO (DISCOS LOCALES) *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                    # Obtenemos los discos logicos tipo 3 (Discos Locales)
                    Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
                        # Calculos matematicos
                        $sizeGB = [Math]::Round($_.Size / 1GB, 2)
                        $freeGB = [Math]::Round($_.FreeSpace / 1GB, 2)
                        $usedGB = [Math]::Round($sizeGB - $freeGB, 2)
                        $percentFree = [Math]::Round(($freeGB / $sizeGB) * 100, 1)
                        $percentUsed = 100 - $percentFree
                        # Crear un objeto con la informacion detallada compatible
                        New-Object PSObject -Property @{
                            "Unidad"        = $_.DeviceID
                            "Nombre"        = $_.VolumeName
                            "Formato"       = $_.FileSystem
                            "Tamaño Total"  = "$sizeGB GB"
                            "Espacio Libre" = "$freeGB GB ($percentFree%)"
                            "Espacio Usado" = "$usedGB GB ($percentUsed%)"
                            "Estado"        = $_.Status
                        } | Select-Object Unidad, Nombre, Formato, "Tamaño Total", "Espacio Libre", "Espacio Usado", Estado
                    } | Format-Table -AutoSize
                    Write-Host "Nota: Si el espacio libre es menor al 10%, se recomienda limpieza." -ForegroundColor Yellow
                    # ****

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                }
                "4" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* PROGRAMAS DE INICIO CON ESTADO DE PROCESO *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # 1. Foto instantánea de procesos (optimizamos RAM al no llamar a Get-Process en cada ciclo)
                    $procesosActivos = Get-Process | Select-Object Name, Id

                    # 2. Obtener comandos de inicio
                    $startupCommands = Get-WmiObject -Class Win32_StartupCommand

                    foreach ($item in $startupCommands) {
                        # LIMPIEZA DEL COMANDO: 
                        # Extraemos el nombre limpio del ejecutable ignorando comillas, rutas y parámetros (.exe)
                        # Ejemplo: "C:\Archivos de programa\App.exe" --silent  =>  App
                        $rawCommand = $item.Command.Split('"').Where({ $_ -ne "" })[0]
                        $nombreLimpio = [System.IO.Path]::GetFileNameWithoutExtension($rawCommand)

                        # 3. Buscar coincidencia en procesos activos
                        $procesoMatch = $procesosActivos | Where-Object { $_.Name -eq $nombreLimpio }
                        
                        # 4. Definir color y texto según si está activo o no
                        $statusColor = "Gray"
                        $pidDisplay = "No activo"
                        
                        if ($procesoMatch) {
                            $statusColor = "Green"
                            $pidDisplay = ($procesoMatch.Id -join ", ") # Por si hay varias instancias abiertas
                        }

                        # 5. Mostrar la información en formato lista organizada
                        Write-Host "[ $($item.Caption.ToUpper()) ]" -ForegroundColor White -BackgroundColor DarkBlue
                        Write-Host "PID          : " -NoNewline; Write-Host $pidDisplay -ForegroundColor $statusColor
                        Write-Host "Ejecutable   : $($item.Command)"
                        Write-Host "Usuario      : $($item.User)"
                        Write-Host "Ubicación    : $($item.Location)"
                        if ($item.Description -and $item.Description -ne $item.Caption) {
                            Write-Host "Descripción  : $($item.Description)"
                        }
                        Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                    }

                }
                "5" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* REPORTE DETALLADO DE PROGRAMAS DE INICIO *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtenemos la información de inicio
                    $startupItems = Get-WmiObject -Class Win32_StartupCommand

                    foreach ($item in $startupItems) {
                        # Resaltamos el nombre del programa en azul
                        Write-Host "[ $($item.Caption.ToUpper()) ]" -ForegroundColor White -BackgroundColor DarkBlue
                        
                        # Creamos un objeto personalizado para mostrar los datos ordenados
                        New-Object PSObject -Property @{
                            "Comando/Ruta" = $item.Command
                            "Usuario"      = $item.User
                            "Ubicación"    = $item.Location
                            "Descripción"  = $item.Description
                        } | Select-Object "Comando/Ruta", Usuario, "Ubicación", "Descripción" | Format-List
                        
                        Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                    }

                }
                "6" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* DETALLE DEL SISTEMA (BIOS/FIRMWARE) *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtenemos la información de la BIOS mediante WMI
                    $bios = Get-WmiObject -Class Win32_BIOS

                    if ($bios) {
                        # Creamos un objeto compatible con PowerShell 2.0 (Windows 7)
                        $infoBIOS = New-Object PSObject
                        
                        # Usamos la sintaxis completa para evitar parámetros ambiguos
                        $infoBIOS | Add-Member -MemberType NoteProperty -Name "Fabricante" -Value $bios.Manufacturer
                        $infoBIOS | Add-Member -MemberType NoteProperty -Name "Nombre_Version" -Value $bios.Name
                        $infoBIOS | Add-Member -MemberType NoteProperty -Name "Version_SMBIOS" -Value $bios.SMBIOSBIOSVersion
                        $infoBIOS | Add-Member -MemberType NoteProperty -Name "N_Serie" -Value $bios.SerialNumber
                        $infoBIOS | Add-Member -MemberType NoteProperty -Name "Estado" -Value $bios.Status
                        $infoBIOS | Add-Member -MemberType NoteProperty -Name "Idioma" -Value $bios.CurrentLanguage

                        # Mostramos la información
                        $infoBIOS | Format-List
                    }
                    else {
                        Write-Host "No se pudo obtener información de la BIOS." -ForegroundColor Red
                    }

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                }
                "6.1" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    # Método directo basado en la variable de entorno de firmware
                    $firmware = $env:firmware_type

                    if ($null -eq $firmware) {
                        # Si la variable está vacía, consultamos la carpeta de Windows
                        if (Test-Path "$env:windir\Panther\setupact.log") {
                            # (Usa el código del log anterior como respaldo)
                        }
                        else {
                            Write-Host "Modo de arranque: Legacy / BIOS (Detectado por exclusión)" -ForegroundColor Yellow
                        }
                    }
                    else {
                        Write-Host "Modo de arranque: $firmware" -ForegroundColor Yellow
                    }
                }
                "7" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* DETALLE DEL PROCESADOR (CPU) *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtenemos la información de la CPU
                    $cpu = Get-WmiObject -Class Win32_Processor

                    if ($cpu) {
                        # 1. Procesamos la arquitectura antes para evitar el error del 'if'
                        $archText = "32-bit"
                        if ($cpu.AddressWidth -eq 64) {
                            $archText = "64-bit"
                        }

                        # 2. Creamos el objeto (Sintaxis compatible con PS 2.0)
                        $infoCPU = New-Object PSObject
                        
                        # 3. Asignamos los miembros usando la sintaxis completa y segura
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Modelo" -Value $cpu.Name
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Fabricante" -Value $cpu.Manufacturer
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Arquitectura" -Value $archText
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Nucleos_Fisicos" -Value $cpu.NumberOfCores
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Hilos_Logicos" -Value $cpu.NumberOfLogicalProcessors
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Velocidad_Base" -Value "$($cpu.MaxClockSpeed) MHz"
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Socket" -Value $cpu.SocketDesignation
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "ID_Procesador" -Value $cpu.ProcessorId

                        # Mostramos el resultado
                        $infoCPU | Format-List
                    }
                    else {
                        Write-Host "No se pudo obtener información del procesador." -ForegroundColor Red
                    }

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                }
                "8" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n==================================================================" -ForegroundColor White
                    Write-Host "         REPORTE DETALLADO DE SISTEMA (Mantenimiento SW)" -ForegroundColor Cyan
                    Write-Host "==================================================================" -ForegroundColor White

                    # 1. Recolección previa de datos (WMI)
                    $os = Get-WmiObject Win32_OperatingSystem
                    $cs = Get-WmiObject Win32_ComputerSystem
                    $bios = Get-WmiObject Win32_BIOS
                    $cpu = Get-WmiObject Win32_Processor

                    # 2. Preparación de variables de tiempo y memoria
                    $totalRAM = [Math]::Round([double]$cs.TotalPhysicalMemory / 1GB, 2)
                    $freeRAM = [Math]::Round([double]$os.FreePhysicalMemory / 1MB, 2)
                    $lastBoot = $os.ConvertToDateTime($os.LastBootUpTime)
                    $installDate = $os.ConvertToDateTime($os.InstallDate)
                    $arch = if ($os.OSArchitecture) { $os.OSArchitecture } else { "No detectada" }

                    # --- SECCION 1: IDENTIFICACIÓN DEL EQUIPO ---
                    Write-Host "[ IDENTIFICACION DEL HARDWARE ]" -ForegroundColor Yellow
                    $ident = New-Object PSObject
                    $ident | Add-Member -MemberType NoteProperty -Name "Equipo" -Value $cs.Name
                    $ident | Add-Member -MemberType NoteProperty -Name "Fabricante" -Value $cs.Manufacturer
                    $ident | Add-Member -MemberType NoteProperty -Name "Modelo" -Value $cs.Model
                    $ident | Add-Member -MemberType NoteProperty -Name "N_Serie" -Value $bios.SerialNumber
                    $ident | Format-List

                    # --- SECCIÓN 2: SOFTWARE Y SISTEMA OPERATIVO ---
                    Write-Host "[ SISTEMA OPERATIVO ]" -ForegroundColor Yellow
                    $soft = New-Object PSObject
                    $soft | Add-Member -MemberType NoteProperty -Name "Nombre_SO" -Value $os.Caption
                    $soft | Add-Member -MemberType NoteProperty -Name "Version" -Value $os.Version
                    $soft | Add-Member -MemberType NoteProperty -Name "Arquitectura" -Value $arch
                    $soft | Add-Member -MemberType NoteProperty -Name "Instalacion" -Value $installDate
                    $soft | Add-Member -MemberType NoteProperty -Name "Directorio" -Value $os.WindowsDirectory
                    $soft | Format-List

                    # --- SECCIÓN 3: COMPONENTES PRINCIPALES (CPU/RAM) ---
                    Write-Host "[ COMPONENTES INTERNOS ]" -ForegroundColor Yellow

                    $hard = New-Object PSObject
                    $hard | Add-Member -MemberType NoteProperty -Name "Procesador" -Value $cpu.Name
                    $hard | Add-Member -MemberType NoteProperty -Name "Nucleos_Hilos" -Value "$($cpu.NumberOfCores) Cores / $($cpu.NumberOfLogicalProcessors) Threads"
                    $hard | Add-Member -MemberType NoteProperty -Name "RAM_Total" -Value "$totalRAM GB"
                    $hard | Add-Member -MemberType NoteProperty -Name "RAM_Disponible" -Value "$freeRAM GB"
                    $hard | Add-Member -MemberType NoteProperty -Name "BIOS_Version" -Value $bios.SMBIOSBIOSVersion
                    $hard | Format-List

                    # --- SECCIÓN 4: ESTADO Y CONTEXTO ---
                    Write-Host "[ ESTADO Y RED ]" -ForegroundColor Yellow
                    $estado = New-Object PSObject
                    $estado | Add-Member -MemberType NoteProperty -Name "Dominio_Grupo" -Value $cs.Domain
                    $estado | Add-Member -MemberType NoteProperty -Name "Usuario_Logueado" -Value $cs.UserName
                    $estado | Add-Member -MemberType NoteProperty -Name "Ultimo_Reinicio" -Value $lastBoot
                    $estado | Add-Member -MemberType NoteProperty -Name "Uptime_Minutos" -Value ([Math]::Round((Get-Date).Subtract($lastBoot).TotalMinutes, 0))
                    $estado | Format-List

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                }
                "8.1" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"
                
                    systeminfo | find /i "Sistema Operativo"

                }
                "8.2" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    wmic cpu get caption

                }
                "8.3" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    # slmgr /dlv
                    Start-Process "slmgr" -ArgumentList "/dlv" -Wait
                    

                }
                "8.4" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Start-Process "winver" -Wait
                }
                "9" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "Ejecutando: Sfc /Scannow"
                    Sfc /Scannow
                    Write-Host "Analisis de escaneo terminado: OK"

                    Write-Host "Presione Enter para volver..." -ForegroundColor Green
                    Read-Host
                }
                "10" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "******* ANALISIS DE INTEGRIDAD DE IMAGEN (DISM) /ScanHealth *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtener la versión de Windows a través de WMI (Compatible con Win 7)
                    $os = Get-WmiObject Win32_OperatingSystem
                    $version = [double]$os.Version.Substring(0, 3) # Ej: 6.1 (Win7), 6.3 (Win8.1), 10.0 (Win10/11)

                    Write-Host "Sistema detectado: $($os.Caption)" -ForegroundColor Gray

                    # Lógica de ejecución según versión
                    if ($version -ge 6.2) {
                        # Windows 8, 8.1, 10 y 11
                        Write-Host "Iniciando ScanHealth nativo..." -ForegroundColor Yellow
                        
                        # Ejecución de DISM
                        & dism.exe /Online /Cleanup-Image /ScanHealth

                        # Comprobación de éxito ($LASTEXITCODE es el equivalente a %errorlevel%)
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "La operacion se completo con exito.  ::: OK" -ForegroundColor Green
                        }
                        else {
                            Write-Host "Ocurrió un error durante la operación (COdigo: $LASTEXITCODE)." -ForegroundColor Red
                        }
                    }
                    elseif ($version -eq 6.1) {
                        # Windows 7
                        Write-Host "Nota: En Windows 7, /ScanHealth no existe nativamente en DISM." -ForegroundColor Yellow
                        Write-Host "Se recomienda usar 'sfc /scannow' o instalar System Update Readiness Tool." -ForegroundColor Gray
                        
                        # Alternativa segura para Windows 7
                        Write-Host "Ejecutando comprobaciOn alternativa (SFC)..." -ForegroundColor White
                        & sfc /scannow
                    }
                    else {
                        Write-Host "Lo sentimos, esta opción no esta disponible en este sistema operativo." -ForegroundColor Red
                    }

                }
                "11" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "/CheckHealth: Realiza una comprobacion rapida para ver si la imagen esta marcada como daniada, solo verifica una marca de corrupcion"
                    Write-Host "******* VERIFICACION DE SALUD DE IMAGEN (DISM) /CheckHealth *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtener la versión del SO mediante WMI
                    $os = Get-WmiObject Win32_OperatingSystem
                    $version = [double]$os.Version.Substring(0, 3)

                    Write-Host "Sistema detectado: $($os.Caption)" -ForegroundColor Gray

                    # DISM /CheckHealth solo está disponible en versiones >= 6.2 (Win 8/10/11)
                    if ($version -ge 6.2) {
                        Write-Host "Ejecutando DISM /CheckHealth..." -ForegroundColor Yellow
                        
                        # Ejecutamos DISM nativo
                        & dism.exe /Online /Cleanup-Image /CheckHealth

                        # $LASTEXITCODE es el equivalente nativo a %errorlevel%
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "La operacion se completo con exito. ::: OK" -ForegroundColor Green
                        }
                        else {
                            Write-Host "Ocurrio un error durante la operacion (Codigo: $LASTEXITCODE)." -ForegroundColor Red
                        }
                    } 
                    elseif ($version -eq 6.1) {
                        # Caso específico para Windows 7
                        Write-Host "Nota: En Windows 7, DISM no soporta /CheckHealth nativamente." -ForegroundColor Yellow
                        Write-Host "Se recomienda usar 'sfc /verifyonly' para verificar integridad." -ForegroundColor White
                        
                        & sfc /verifyonly

                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "La verificacion se completo. Revise los resultados arriba." -ForegroundColor Green
                        }
                        else {
                            Write-Host "SFC detecto problemas o no pudo ejecutarse." -ForegroundColor Red
                        }
                    }
                    else {
                        Write-Host "Esta opcion no es compatible con versiones anteriores a Windows 7." -ForegroundColor Red
                    }

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                }
                "12" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "Para reparar la imagen del sistema operativo, buscando y restaurando archivos corruptos o dañados mediante la comparacion con copias de archivos sanos de los servidores de Windows Update. Esta herramienta es util para solucionar problemas con los archivos de sistema, especialmente cuando el comando SFC /ScanNow no es suficiente o no funciona"
                    Write-Host "******* REPARACION DE IMAGEN DE SISTEMA (DISM) /RestoreHealth *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtener versión del sistema operativo
                    $os = Get-WmiObject Win32_OperatingSystem
                    $version = [double]$os.Version.Substring(0, 3)

                    Write-Host "Sistema detectado: $($os.Caption)" -ForegroundColor Gray

                    # DISM /RestoreHealth requiere Windows 8 o superior (v6.2+)
                    if ($version -ge 6.2) {
                        Write-Host "Iniciando reparacion automatica (/RestoreHealth)..." -ForegroundColor Yellow
                        Write-Host "Este proceso puede tardar varios minutos y requiere internet." -ForegroundColor Gray
                        
                        # Ejecutamos DISM nativo
                        & dism.exe /Online /Cleanup-Image /RestoreHealth

                        # Verificamos el código de salida
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "La imagen se reparo correctamente.   :::  OK" -ForegroundColor Green
                        }
                        else {
                            Write-Host "Ocurrio un error ($LASTEXITCODE). Verifique su conexion a Internet." -ForegroundColor Red
                        }
                    } 
                    elseif ($version -eq 6.1) {
                        # Caso Windows 7: No existe RestoreHealth nativo
                        Write-Host "Nota: Windows 7 no soporta /RestoreHealth via DISM." -ForegroundColor Yellow
                        Write-Host "Ejecutando reparacion de archivos de sistema (SFC)..." -ForegroundColor White
                        
                        & sfc /scannow

                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "SFC finalizo con exito." -ForegroundColor Green
                        }
                        else {
                            Write-Host "SFC encontro errores o no pudo completarse." -ForegroundColor Red
                        }
                    }
                    else {
                        Write-Host "Opcion no compatible con esta version de Windows." -ForegroundColor Red
                    }

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Green
                }
                "13" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "Para eliminar archivos antiguos y de sistema que ya no son necesarios, con el fin de optimizar y liberar espacio en tu sistema Windows."
                    Write-Host "`n******* LIMPIEZA DE COMPONENTES (DISM / StartComponentCleanup) *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtener versión del sistema operativo
                    $os = Get-WmiObject Win32_OperatingSystem
                    $version = [double]$os.Version.Substring(0, 3)

                    Write-Host "Sistema detectado: $($os.Caption)" -ForegroundColor Gray

                    # /StartComponentCleanup requiere Windows 8 o superior (v6.2+)
                    if ($version -ge 6.2) {
                        Write-Host "Iniciando limpieza de la carpeta WinSxS..." -ForegroundColor Yellow
                        Write-Host "Este proceso reduce el tamanio de la carpeta de sistema." -ForegroundColor Gray
                        
                        # Ejecutamos DISM nativo
                        & dism.exe /Online /Cleanup-Image /StartComponentCleanup

                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "Limpieza de componentes completada con exito.   :::  OK" -ForegroundColor Green
                        }
                        else {
                            Write-Host "Ocurrio un error ($LASTEXITCODE) durante la limpieza." -ForegroundColor Red
                        }
                    } 
                    elseif ($version -eq 6.1) {
                        # Caso Windows 7: Usamos el motor de limpieza de disco nativo
                        Write-Host "Nota: Windows 7 no soporta /StartComponentCleanup." -ForegroundColor Yellow
                        Write-Host "Iniciando limpieza de actualizaciones obsoletas via Cleanmgr..." -ForegroundColor White
                        
                        # Inicia la limpieza de archivos de sistema de forma automatizada
                        # Nota: Requiere que el usuario haya corrido Cleanmgr con SAGESET antes, 
                        # o simplemente lo lanzamos para que el técnico elija.
                        & cleanmgr.exe /sagerun:1
                        
                        Write-Host "Se ha lanzado el Liberador de espacio en disco (Windows 7)." -ForegroundColor Green
                    }
                    else {
                        Write-Host "Opcion no compatible con versiones anteriores a Windows 7." -ForegroundColor Red
                    }

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                }
                "14" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "Ejecutando.....: Dism.exe /Online /Cleanup-Image /ScanHealth"
                    Dism.exe /Online /Cleanup-Image /ScanHealth
                    Write-Host "Analisis terminado: Dism.exe /Online /Cleanup-Image /ScanHealth  ::: OK" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Ejecutando.....: Dism.exe /Online /Cleanup-Image /RestoreHealth"
                    Dism.exe /Online /Cleanup-Image /RestoreHealth
                    Write-Host "Analisis terminado: Dism.exe /Online /Cleanup-Image /RestoreHealth  ::: OK" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Ejecutando.....: Dism.exe /Online /Cleanup-Image /StartComponentCleanup"
                    Dism.exe /Online /Cleanup-Image /StartComponentCleanup
                    Write-Host "Analisis terminado: Dism.exe /Online /Cleanup-Image /StartComponentCleanup  ::: OK" -ForegroundColor Green
                    
                    Write-Host
                    Write-Host "Ejecutando.....: Sfc /Scannow"
                    Sfc /Scannow
                    Write-Host "Analisis terminado: Sfc /Scannow ::: OK" -ForegroundColor Green
                }

                "17" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    query user

                }
                "18" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    net share
                }
                "19" { 
                    Invoke-FormatHDDExternalWindow -OpcionDestino "19"
                }
                "19.0" { 
                    Invoke-FormatHDDExternalWindow -OpcionDestino "19.0"
                }
                "19.1" { 
                    Invoke-FormatHDDExternalWindow -OpcionDestino "19.1"
                }
                "19.2" { 
                    Invoke-FormatHDDExternalWindow -OpcionDestino "19.2"
                }
                "19.3" { 
                    Invoke-FormatHDDExternalWindow -OpcionDestino "19.3"
                }
                "19.4" { 
                    Invoke-FormatHDDExternalWindow -OpcionDestino "19.4"
                }
                "19.5" { 
                    Invoke-FormatHDDExternalWindow -OpcionDestino "19.5"
                }
                "19.6" { 
                    Invoke-FormatHDDExternalWindow -OpcionDestino "19.6"
                }
                "19.7" { 
                    Invoke-FormatHDDExternalWindow -OpcionDestino "19.7"
                }

                "21" { 
                    Invoke-USBPreparationExternalWindow -OpcionDestino "21"
                }
                "21.0" { 
                    Invoke-USBPreparationExternalWindow -OpcionDestino "21.0"
                }
                "21.1" { 
                    Invoke-USBPreparationExternalWindow -OpcionDestino "21.1"
                }
                "21.2" { 
                    Invoke-USBPreparationExternalWindow -OpcionDestino "21.2"
                }
                "21.3" { 
                    Invoke-USBPreparationExternalWindow -OpcionDestino "21.3"
                }
                "21.4" { 
                    Invoke-USBPreparationExternalWindow -OpcionDestino "21.4"
                }
                "21.5" { 
                    Invoke-USBPreparationExternalWindow -OpcionDestino "21.5"
                }
                "21.6" { 
                    Invoke-USBPreparationExternalWindow -OpcionDestino "21.6"
                }
                "21.7" { 
                    Invoke-USBPreparationExternalWindow -OpcionDestino "21.7"
                }

                

                "0" { 
                    #$salirSub = $true 
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            } #Cierra switch
            if (-not $salirSub) { Read-Host "SUB_MENU 20: Presione ENTER para continuar..." }

        } # Cierra try

        catch {
            Write-Host "`n[ERROR NO ESPERADO]: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Presione Enter para continuar..."
        }
		
        finally {
            # *************************************************************************************
            # BLOQUE DE LIMPIEZA Y REFRESCO (Se ejecuta después de cada opción)
            # *************************************************************************************
            
            # 1. Liberar memoria de objetos COM/WMI/CIM colgados
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()

            # 2. Eliminar variables temporales de la sesión para evitar errores de "cadena de entrada"
            # Mantenemos variables críticas del script
            Get-Variable | Where-Object { 
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. Pequeña pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }

    } while (-not $salirSub)
}

#************************************************* FIN SUB MENU.20*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.21 ******************************************************
#**********************************************************************************************************************************
function psSubMenu21 {
    

    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header "21. ---)) LOCAL: VENTANAS ADMINISTRACION WINDOWS - ANTIVIRUS."
            Write-Host "1. Reestablecer la tienda de Windows."
            Write-Host "2. Clave de Sistema Operativo Windows."
            Write-Host "3. Eliminar "Desktop.ini" (Aviso que se ejecuta automaticamente)."
            Write-Host "-----------------------------------------------------------."
            Write-Host "4. Web Definicion ANTIVIRUS DE WINDOWS."
            Write-Host "***********************************************************."
            Write-Host "5. Administracion de Discos Duros."
            Write-Host "6. Administrador de dispositivos."
            Write-Host "7. Administracion de Impresion."
            Write-Host "8. Conexion de Red."
            Write-Host "9. Herramienta de Diagnostico DirectX."
            Write-Host "10. Informacion del Sistema - VENTANA."
            Write-Host "***********************************************************."
            Write-Host ""
            Write-Host "0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Header "=========================================================="
            
            $op21 = Read-Host "Seleccione la tarea a realizar"

            switch ($op21) {
                "1" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process "wsreset" -Wait

                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
                "2" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    $licencia = (Get-WmiObject SoftwareLicensingService).OA3xOriginalProductKey

                    if ([string]::IsNullOrWhiteSpace($licencia)) {
                        Write-Warning "No se encontró una clave OA3.0 en el firmware de este equipo."
                    }
                    else {
                        Write-Host "La clave detectada es: $licencia" -ForegroundColor Green
                    }

                    Write-Host "Proceso ejecutado..."
                    Write-Host ""

                }
                "3" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    # 1. Definimos las rutas usando variables de entorno para mayor compatibilidad
                    $rutas = @(
                        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\desktop.ini",
                        "$env:Public\Desktop\desktop.ini"
                    )

                    Write-Host "Has elegido ELIMINAR archivos desktop.ini." -ForegroundColor Cyan

                    foreach ($ruta in $rutas) {
                        if (Test-Path -Path $ruta) {
                            try {
                                # -Force es necesario porque desktop.ini tiene atributos de sistema/oculto
                                Remove-Item -Path $ruta -Force -ErrorAction Stop
                                Write-Host "Eliminado con exito: $ruta" -ForegroundColor Green
                            }
                            catch {
                                Write-Warning "No se pudo eliminar $ruta. Es posible que requiera permisos de Administrador."
                            }
                        }
                        else {
                            Write-Host "El archivo no existe en: $ruta" -ForegroundColor Gray
                        }
                    }

                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                    
                }
                
                "4" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process "https://www.microsoft.com/en-us/wdsi/definitions"       

                    # Este comando descarga e instala las últimas definiciones silenciosamente
                    Update-MpSignature     

                    Write-Host "Proceso ejecutado..."
                    Write-Host ""  

                }
                "5" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process diskmgmt.msc
                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
                "6" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process devmgmt.msc
                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
                
                "7" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process printmanagement.msc
                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
                "8" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process ncpa.cpl
                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
        
                "9" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process dxdiag  -Wait
                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
                "10" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process msinfo32
                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
                
                "0" { 
                    #$salirSub = $true 
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            } #Cierra switch
            if (-not $salirSub) { Read-Host "SUB_MENU 21: Presione ENTER para continuar..." }

        } # Cierra try

        catch {
            Write-Host "`n[ERROR NO ESPERADO]: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Presione Enter para continuar..."
        }
		
        finally {
            # *************************************************************************************
            # BLOQUE DE LIMPIEZA Y REFRESCO (Se ejecuta después de cada opción)
            # *************************************************************************************
            
            # 1. Liberar memoria de objetos COM/WMI/CIM colgados
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()

            # 2. Eliminar variables temporales de la sesión para evitar errores de "cadena de entrada"
            # Mantenemos variables críticas del script
            Get-Variable | Where-Object { 
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. Pequeña pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }

    } while (-not $salirSub)
}

#************************************************* FIN SUB MENU.21*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.22 ******************************************************
#**********************************************************************************************************************************
function psSubMenu22 {
    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header " 22. ---)) LOCAL: SERVICIOS WINDOWS - HERRAMIENTAS AVANZADOS."
            Write-Host "  1. Ver estado Servicio Actualizacion Windows 7 en adelante."
            Write-Host "  2. Detener Servicio Actualizacion Windows 7 en adelante."
            Write-Host "  3. Iniciar Servicio Actualizacion Windows 10."
            Write-Host "  4. Agregar Registro Detener Actualizacion Windows."
            Write-Host "  -----------------------------------------------------------."
            Write-Host "  5. Abrir ventana de Administrador de Servicios de Windows."
            Write-Host "  -----------------------------------------------------------."
            Write-Host "  6. Herramienta de eliminacion de Software malintencionado."
            Write-Host "  -----------------------------------------------------------."
            Write-Host "  7. Pasos para restaurar indice de Windows."
            Write-Host "  8. Aplicaciones y procesos en la PC."
            Write-Host "     8.1 Cerrar aplicaciones de Usuario."
            Write-Host ""
            Write-Host "  0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Header "==========================================================="
            
            $op22 = Read-Host "Seleccione la tarea a realizar"

            switch ($op22) {
                "1" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    # Configuración de codificación para evitar problemas con tildes en versiones antiguas
                    $OutputEncoding = [System.Text.Encoding]::UTF8

                    Write-Host "Este script verifica si los servicios de los cuales depende Windows Update estan corriendo" -ForegroundColor Cyan
                    Write-Host ""

                    # Pausa inicial (Equivalente a TIMEOUT /T 4)
                    Start-Sleep -Seconds 4

                    # Lista de servicios a verificar
                    # Nota: UsoSvc y WaasMedicSvc solo aparecerán en Windows 10/11
                    $servicios = @(
                        "BITS", 
                        "UsoSvc", 
                        "wuauserv", 
                        "WaasMedicSvc"
                    )

                    foreach ($nombreSvc in $servicios) {
                        # Intentamos obtener el servicio silenciosamente
                        $svc = Get-Service -Name $nombreSvc -ErrorAction SilentlyContinue
                        
                        if ($svc) {
                            # Si el servicio existe, mostramos su nombre real y su estado
                            $estado = $svc.Status.ToString().ToUpper()
                            
                            # Color diferenciador: Verde si corre, Rojo si está detenido
                            $color = if ($estado -eq "RUNNING") { "Green" } else { "Yellow" }
                            
                            Write-Host "Servicio: $($svc.DisplayName) ($nombreSvc)"
                            Write-Host "ESTADO: $estado" -ForegroundColor $color
                        }
                        else {
                            # Si el servicio no existe (como UsoSvc en Win 7)
                            Write-Host "Servicio: $nombreSvc - [NO INSTALADO EN ESTE SISTEMA]" -ForegroundColor Gray
                        }
                        
                        Write-Host ("-" * 30)
                        Start-Sleep -Seconds 2
                    }

                    Write-Host ""
                    Write-Host "-------------------------------------------------------" -ForegroundColor White
                    Write-Host "Si todo aca dice STOPPED o STOPPING, entonces SERVICIOS DETENIDOS" -ForegroundColor Cyan
                    Write-Host "-------------------------------------------------------"
                    Write-Host ""

                    # Write-Host "Presione una tecla para continuar . . ."
                    # $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

                }
                "2" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    # 1. Verificación de privilegios de Administrador (Compatible con PS v2.0+)
                    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                        Write-Host "ERROR: Este script DEBE ejecutarse como Administrador." -ForegroundColor Red
                        Write-Host "Haga clic derecho sobre el archivo y seleccione 'Ejecutar con PowerShell'."
                        Write-Host "Presione una tecla para salir..."
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        exit
                    }

                    Write-Host "--- DESACTIVACION DE SERVICIOS DE ACTUALIZACION ---" -ForegroundColor Cyan
                    Write-Host "Este script desactiva BITS, wuauserv y servicios de mantenimiento (Win10+)."
                    Write-Host "Presione CTRL+C en los proximos 10 segundos para cancelar..."

                    Start-Sleep -Seconds 10

                    # Lista de servicios y su ruta en el registro
                    # Nota: UsoSvc y WaasMedicSvc no existen en Win7, el script los saltará automáticamente.
                    $servicios = @("UsoSvc", "WaasMedicSvc", "BITS", "wuauserv")
                    $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services"

                    Write-Host "`n[1/3] Modificando Registro para desactivar el inicio..." -ForegroundColor Yellow
                    foreach ($svcName in $servicios) {
                        $fullPath = "$registryPath\$svcName"
                        
                        if (Test-Path $fullPath) {
                            # Configurar Start = 4 (Deshabilitado)
                            Set-ItemProperty -Path $fullPath -Name "Start" -Value 4 -Force
                            Write-Host "OK: $svcName configurado como Deshabilitado."
                            
                            # Caso especial: Cambiar ObjectName a 'Guest' para bloquear ejecución (el 'truco' del original)
                            if ($svcName -eq "wuauserv") {
                                Set-ItemProperty -Path $fullPath -Name "ObjectName" -Value "Guest" -Force
                                Write-Host "CRITICO: Credenciales de $svcName cambiadas a 'Guest'." -ForegroundColor Cyan
                            }
                        }
                        else {
                            Write-Host "SKIP: $svcName no existe en este sistema (Normal en Windows 7)." -ForegroundColor Gray
                        }
                    }

                    Start-Sleep -Seconds 2

                    Write-Host "`n[2/3] Deteniendo servicios activos..." -ForegroundColor Yellow
                    foreach ($svcName in $servicios) {
                        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
                        if ($svc) {
                            if ($svc.Status -ne 'Stopped') {
                                Write-Host "Deteniendo $svcName..." -NoNewline
                                Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
                                Write-Host " [HECHO]" -ForegroundColor Green
                            }
                            else {
                                Write-Host "$svcName ya se encuentra detenido." -ForegroundColor Gray
                            }
                        }
                        Start-Sleep -Milliseconds 500
                    }

                    Write-Host "`n[3/3] Verificación final de estado:" -ForegroundColor Yellow
                    Write-Host "-------------------------------------------------------"
                    foreach ($svcName in $servicios) {
                        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
                        if ($svc) {
                            $color = if ($svc.Status -eq 'Stopped') { "Green" } else { "Red" }
                            Write-Host "Servicio: $($svcName.PadRight(15)) Estado: $($svc.Status)" -ForegroundColor $color
                        }
                    }
                    Write-Host "-------------------------------------------------------"
                    Write-Host "Si el estado es STOPPED, la operacion fue exitosa."
                    Write-Host "`nPresione cualquier tecla para continuar..."
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

                }

                "3" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    # 1. Verificación de privilegios de Administrador (Compatible PS v2.0+)
                    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                        Write-Host "ERROR: Este script DEBE ejecutarse como Administrador." -ForegroundColor Red
                        Write-Host "Haga clic derecho sobre el archivo y seleccione 'Ejecutar con PowerShell'."
                        Pause
                        exit
                    }

                    Clear-Host
                    Write-Host "--- RESTAURACIÓN DE SERVICIOS DE ACTUALIZACIÓN ---" -ForegroundColor Cyan
                    Write-Host "Restaurando permisos de ejecución e identidad LocalSystem..."
                    Write-Host "Presione CTRL+C en los próximos 10 segundos para cancelar..."

                    Start-Sleep -Seconds 10

                    # Lista de servicios a restaurar
                    $servicios = @("wuauserv", "UsoSvc", "BITS", "WaasMedicSvc")
                    $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services"

                    Write-Host "`n[1/2] Restaurando identidad y tipo de inicio en el Registro..." -ForegroundColor Yellow

                    foreach ($svcName in $servicios) {
                        $fullPath = "$registryPath\$svcName"
                        
                        if (Test-Path $fullPath) {
                            # 1. Restaurar Identidad a 'LocalSystem' (fundamental para que el servicio arranque)
                            Set-ItemProperty -Path $fullPath -Name "ObjectName" -Value "LocalSystem" -Force
                            
                            # 2. Restaurar Inicio a '3' (Manual)
                            Set-ItemProperty -Path $fullPath -Name "Start" -Value 3 -Force
                            
                            Write-Host "OK: $svcName restaurado a LocalSystem y modo Manual." -ForegroundColor Green
                            Start-Sleep -Seconds 2
                        }
                        else {
                            Write-Host "SKIP: $svcName no existe en este sistema (ignorado)." -ForegroundColor Gray
                        }
                    }

                    Write-Host "`n[2/2] Finalizando..." -ForegroundColor Yellow
                    Write-Host "------------------------------------------------------------------------------------------"
                    Write-Host "LISTO, todo restaurado." -ForegroundColor White
                    Write-Host "ES NECESARIO REINICIAR el sistema para que los cambios de identidad surtan efecto." -ForegroundColor Red
                    Write-Host "Una vez reiniciada la PC, los servicios podrán arrancar cuando Windows los necesite."
                    Write-Host "------------------------------------------------------------------------------------------"

                    Write-Host "`nPresione cualquier tecla para continuar . . ."
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    
                }
                
                "4" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op22"

                    # 1. Verificacion de privilegios de Administrador
                    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
                    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
                    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

                    if (-not $currentPrincipal.IsInRole($adminRole)) {
                        Write-Host 'ERROR: Ejecute PowerShell como ADMINISTRADOR.' -ForegroundColor Red
                        Write-Host 'Presione una tecla para salir...'
                        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                        exit
                    }

                    $regPath = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
                    Write-Host '--- FORZANDO DESACTIVACION DE ACTUALIZACIONES ---' -ForegroundColor Cyan

                    # Funcion para crear la clave y el valor
                    function Set-WindowsUpdatePolicy {
                        param($Name, $Value)
                        try {
                            $fullPath = "HKLM:\$regPath"
                            if (!(Test-Path $fullPath)) { 
                                New-Item -Path $fullPath -Force | Out-Null 
                            }
                            Set-ItemProperty -Path $fullPath -Name $Name -Value $Value -PropertyType 'DWord' -Force -ErrorAction 'Stop'
                            return $true
                        }
                        catch {
                            # Fallback a REG.EXE para maxima compatibilidad en Windows 7
                            $cmd = "reg add ""HKLM\$regPath"" /v $Name /t REG_DWORD /d $Value /f"
                            Invoke-Expression $cmd | Out-Null
                            return $?
                        }
                    }

                    # Aplicar las politicas
                    $items = @{ 'NoAutoUpdate' = 1; 'AUOptions' = 1 }

                    foreach ($key in $items.Keys) {
                        $val = $items[$key]
                        Write-Host "Configurando $key... " -NoNewline
                        if (Set-WindowsUpdatePolicy -Name $key -Value $val) {
                            Write-Host 'OK' -ForegroundColor Green
                        }
                        else {
                            Write-Host 'FALLO' -ForegroundColor Red
                        }
                    }

                    # 2. Refrescar las politicas del sistema
                    Write-Host 'Actualizando directivas de grupo...' -ForegroundColor Yellow
                    gpupdate /force | Out-Null

                    Write-Host '-------------------------------------------------------'
                    Write-Host 'PROCESO COMPLETADO' -ForegroundColor Cyan
                    Write-Host 'Si hubo fallos, revise si un antivirus bloquea el registro.'
                    Write-Host '-------------------------------------------------------'

                    
                }

                "5" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    Start-Process services.msc

                    Write-Host "Proceso ejecutado..."

                }
                "6" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    Start-Process mrt

                    Write-Host "Proceso ejecutado..."                    
                }
                
                "7" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    # Titulo principal
                    Write-Host '===========================================================' -ForegroundColor Cyan
                    Write-Host '    GUIA DE REPARACION: DISM CON FUENTE EXTERNA (WIM)' -ForegroundColor Cyan
                    Write-Host '===========================================================' -ForegroundColor Cyan
                    Write-Host ' Realice estos pasos cuando "DISM /RestoreHealth" falle.' -ForegroundColor White
                    Write-Host ''

                    # Paso 1
                    Write-Host ' 1. MONTAR LA IMAGEN' -ForegroundColor Yellow
                    Write-Host '    Monte la imagen ISO de Windows en su sistema.'
                    Write-Host ''

                    # Paso 2
                    Write-Host ' 2. OBTENER INFORMACION DEL ARCHIVO WIM' -ForegroundColor Yellow
                    Write-Host '    Abra una terminal como administrador y ejecute:'
                    Write-Host '    dism /get-wiminfo /wimfile:N:\sources\install.wim' -ForegroundColor Green -BackgroundColor Black
                    Write-Host ''
                    Write-Host '    NOTA: Reemplace ' -NoNewline
                    Write-Host 'N:\sources\install.wim' -ForegroundColor Magenta -NoNewline
                    Write-Host ' con su ruta real.'
                    Write-Host '    En el listado, busque el INDICE que corresponde a su version de Windows.'
                    Write-Host ''

                    # Paso 3
                    Write-Host ' 3. EJECUTAR RESTAURACION CON FUENTE' -ForegroundColor Yellow
                    Write-Host '    Escriba el siguiente comando siguiendo este formato:'
                    Write-Host '    dism /online /cleanup-image /RestoreHealth /source:N:\sources\install.wim:6 /limitaccess' -ForegroundColor Green -BackgroundColor Black
                    Write-Host ''
                    Write-Host '    IMPORTANTE REVISAR:' -ForegroundColor Red
                    Write-Host '    * El numero de INDICE (al final de la ruta, ej: :6)'
                    Write-Host '    * La ruta exacta donde esta el archivo.'
                    Write-Host '    * La extension (.wim o .esd).'
                    Write-Host ''

                    # Paso final
                    Write-Host ' 4. VERIFICACION FINAL' -ForegroundColor Yellow
                    Write-Host '    Al terminar, ejecute el comando para reparar archivos de sistema:'
                    Write-Host '    sfc /scannow' -ForegroundColor Green -BackgroundColor Black
                    Write-Host ''

                    Write-Host '===========================================================' -ForegroundColor Cyan
                    Write-Host ' '
                    
                    #$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

                }

                "8.1" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    # ==============================================================================
                    # Script: Monitor_Aplicaciones_Mejorado.ps1
                    # Compatibilidad: Windows 7, 8.1, 10, 11 (PowerShell 2.0+)
                    # Mejora: Opción de salida explícita y cancelación de cierre.
                    # ==============================================================================

                    Write-Host "Analizando aplicaciones abiertas con ventana activa..." -ForegroundColor Yellow
                    Write-Host ""

                    # 1. Obtener procesos con ventana principal
                    $procesosUsuario = Get-Process | Where-Object { $_.MainWindowTitle -ne "" }

                    $reporteApps = foreach ($p in $procesosUsuario) {
                        $ramMB = [Math]::Round($p.WorkingSet64 / 1MB, 2)
                        
                        New-Object PSObject -Property @{
                            ID         = $p.Id
                            Aplicacion = $p.ProcessName
                            Ventana    = if ($p.MainWindowTitle.Length -gt 45) { $p.MainWindowTitle.Substring(0, 42) + "..." } else { $p.MainWindowTitle }
                            RAM_MB     = $ramMB
                        }
                    }

                    # 2. Mostrar tabla de aplicaciones
                    $reporteApps | Select-Object ID, Aplicacion, RAM_MB, Ventana | 
                    Sort-Object RAM_MB -Descending | 
                    Format-Table -AutoSize

                    Write-Host ""
                    Write-Host "--- GESTION DE PROCESOS ---" -ForegroundColor Cyan
                    Write-Host "Opciones: Ingrese el [PID] para cerrar, o la letra [S] para Salir sin cambios." -ForegroundColor White

                    # 3. Interacción con opción de salida mejorada
                    $entrada = Read-Host "Seleccione una opcion"

                    # Validar si el usuario quiere salir (Letra S o vacío)
                    if ($entrada -eq "S" -or $entrada -eq "s" -or $entrada -eq "") {
                        Write-Host "Operacion cancelada por el usuario." -ForegroundColor Yellow
                    } 
                    # Validar si la entrada es un número (PID)
                    elseif ($entrada -match '^\d+$') {
                        try {
                            $target = Get-Process -Id $entrada -ErrorAction Stop
                            Stop-Process -Id $entrada -Force
                            Write-Host "La aplicacion '$($target.ProcessName)' (PID: $entrada) ha sido cerrada." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "Error: No se encontro el PID o acceso denegado." -ForegroundColor Red
                        }
                    } 
                    else {
                        Write-Host "Entrada no valida. No se realizaron cambios." -ForegroundColor Red
                    }

                    # 4. Cierre del script (estándar de compatibilidad)
                    Write-Host ""
                    Write-Host "Saliendo del programa..." -ForegroundColor Gray
                    Start-Sleep -Seconds 2

                    Write-Host "Proceso ejecutado..."                    
                }
                
                "0" { 
                    #$salirSub = $true 
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            } # Cierra switch
            if (-not $salirSub) { 
                Read-Host "SUB_MENU 22: Presione ENTER para continuar..." 
            }
        } # Cierra try

        catch {
            Write-Host "`n[ERROR NO ESPERADO]: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Presione Enter para continuar..."
        }
		
        finally {
            # *************************************************************************************
            # BLOQUE DE LIMPIEZA Y REFRESCO (Se ejecuta después de cada opción)
            # *************************************************************************************
            
            # 1. Liberar memoria de objetos COM/WMI/CIM colgados
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()

            # 2. Eliminar variables temporales de la sesión para evitar errores de "cadena de entrada"
            # Mantenemos variables críticas del script
            Get-Variable | Where-Object { 
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. Pequeña pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }
    } while (-not $salirSub)
}

#************************************************* FIN SUB MENU.22*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.23 ******************************************************
#**********************************************************************************************************************************
function psSubMenu23 {
    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header " 23. ---)) LOCAL: HELPDESK LOCAL - HERRAMIENTAS DE SISTEMA."
            Write-Host "  1. Abrir PowerShell Administrador."
            Write-Host "  2. Mostrar Unidades Logicas de Almacenamiento."
            Write-Host "     2.1. Mostrar Unidadles logicas - DETALLE."
            Write-Host "  3. Informacion Corta de PC."
            Write-Host "     3.1. Informacion Corta de Procesador."
            Write-Host "  4. Mostrar Direccion IP Ethernet Asignada."
            Write-Host "     4.1. Mostrar Interfaces con Direcciones IP Ethernet."
            Write-Host "     4.2. Mostrar Direccion IP PUBLICA"
            Write-Host "  5. Gestion de Red Local:" -ForegroundColor Green
            Write-Host "    5.1. Resetear IP Red LAN." -ForegroundColor Cyan
            Write-Host "    5.2. Resetear IP Red y Asignar DHCP." -ForegroundColor Cyan
            Write-Host "    5.3. Mostrar Claves MAC Address." -ForegroundColor Cyan
            Write-Host "    5.4. Actualizacion y Diagnostico de Politicas (gpupdate)." -ForegroundColor Yellow
            Write-Host "  6. OPTIMIZACION Y LIMPIEZA DE SISTEMA:" -ForegroundColor Green
            Write-Host "    6.1. Eliminar Archivos TEMPORALES CARPETAS" -ForegroundColor DarkCyan
            Write-Host "    6.2. Eliminar Archivos Temporales ProgramData." -ForegroundColor DarkCyan
            Write-Host "    6.3. Liberar RAM." -ForegroundColor DarkCyan
            Write-Host "    6.4. Liberar Procesador." -ForegroundColor DarkCyan
            Write-Host "    6.5. Vaciar Papelera de Reciclaje" -ForegroundColor DarkCyan
            Write-Host "    6.6. Eliminacion avanzada de temporales (Todos los usuarios)" -ForegroundColor Yellow
            Write-Host "  12. Revisiones Instaladas de Windows."
            Write-Host "  20 ---)) HERRAMIENTAS PC y PORTATIL (Laptops)." -ForegroundColor Green
            Write-Host ""
            Write-Host "  0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Header "===================================================================="
            
            $op23 = Read-Host "Seleccione la tarea a realizar"

            switch ($op23) {
                "1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    Start-Process powershell -Verb RunAs

                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
                "2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    # 1. Obtener Unidades Lógicas (Equivalente a Get-PSDrive)
                    Write-Host "--- UNIDADES LOGICAS DEL SISTEMA ---" -ForegroundColor Green
                    Get-PSDrive -PSProvider FileSystem | Select-Object Name, 
                    @{Name = "Used(GB)"; Expression = { "{0:N2}" -f ($_.Used / 1GB) } }, 
                    @{Name = "Free(GB)"; Expression = { "{0:N2}" -f ($_.Free / 1GB) } }, 
                    @{Name = "Total(GB)"; Expression = { "{0:N2}" -f (($_.Used + $_.Free) / 1GB) } } | Format-Table -AutoSize

                    Write-Host "`n--- DISCOS FISICOS DETECTADOS ---" -ForegroundColor Green

                    # 2. Obtener Discos Físicos (Compatible con Windows 7, 8, 10 y 11)
                    # Usamos Win32_DiskDrive porque Get-PhysicalDisk falla en Windows 7
                    Get-WmiObject -Class Win32_DiskDrive | Select-Object Model, 
                    @{Name = "Interface"; Expression = { $_.InterfaceType } }, 
                    @{Name = "Size(GB)"; Expression = { "{0:N2}" -f ($_.Size / 1GB) } }, 
                    Status | Format-Table -AutoSize

                    Write-Host "`nPresione una tecla para salir..."
                    # $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    Write-Host ""

                }

                "2.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    # 1. Obtener información extendida de las unidades usando .NET
                    # Este método es compatible con todas las versiones de PowerShell y Windows
                    $drives = [System.IO.DriveInfo]::GetDrives()

                    Write-Host "--- DETALLE DE ALMACENAMIENTO DEL SISTEMA ---" -ForegroundColor Cyan
                    Write-Host ""

                    $reporte = foreach ($d in $drives) {
                        # Inicializamos variables para evitar errores en unidades vacías (como lectoras de DVD)
                        $totalGB = 0
                        $freeGB = 0
                        $percentFree = 0
                        $status = "Listo"

                        if ($d.IsReady) {
                            $totalGB = [Math]::Round($d.TotalSize / 1GB, 2)
                            $freeGB = [Math]::Round($d.TotalFreeSpace / 1GB, 2)
                            # Calcular porcentaje de espacio libre
                            if ($totalGB -gt 0) {
                                $percentFree = [Math]::Round(($freeGB / $totalGB) * 100, 1)
                            }
                        }
                        else {
                            $status = "No disponible / Sin medio"
                        }

                        # Creamos un objeto personalizado para un formato limpio
                        New-Object PSObject -Property @{
                            'Letra'     = $d.Name
                            'Etiqueta'  = if ($d.IsReady) { $d.VolumeLabel } else { "---" }
                            'Formato'   = if ($d.IsReady) { $d.DriveFormat } else { "---" }
                            'Tipo'      = $d.DriveType
                            'Total(GB)' = $totalGB
                            'Libre(GB)' = $freeGB
                            'Libre(%)'  = $percentFree
                            'Estado'    = $status
                        }
                    }

                    # 2. Mostrar la tabla organizada por nombre de unidad
                    $reporte | Select-Object Letra, Etiqueta, Tipo, Formato, 'Total(GB)', 'Libre(GB)', 'Libre(%)', Estado | Format-Table -AutoSize

                    Write-Host ""
                    Write-Host "Nota: Las unidades con 0.00 GB suelen ser lectores de tarjetas o CD-ROM sin disco." -ForegroundColor Gray
                    
                    #$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")  #Espera que el usuario presione una tecla
                    Write-Host ""
                    
                }
                
                "3" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    # 1. Obtener información del Sistema
                    $sysInfo = Get-WmiObject -Class Win32_ComputerSystem
                    # 2. Obtener información de la BIOS
                    $biosInfo = Get-WmiObject -Class Win32_BIOS
                    # 3. Obtener información del Sistema Operativo (Extra para contexto)
                    $osInfo = Get-WmiObject -Class Win32_OperatingSystem

                    Write-Host "--- INFORMACION DEL HARDWARE Y SISTEMA ---" -ForegroundColor Cyan

                    # Presentación organizada de datos del sistema
                    $propiedadesSistema = @{
                        'Fabricante'      = $sysInfo.Manufacturer
                        'Modelo'          = $sysInfo.Model
                        'Usuario Actual'  = $sysInfo.UserName
                        'RAM Total (GB)'  = [Math]::Round($sysInfo.TotalPhysicalMemory / 1GB, 2)
                        'Tipo de Sistema' = $sysInfo.SystemType
                    }

                    New-Object PSObject -Property $propiedadesSistema | Select-Object Fabricante, Modelo, 'RAM Total (GB)', 'Tipo de Sistema', 'Usuario Actual' | Format-List

                    Write-Host "--- DETALLES DE LA BIOS ---" -ForegroundColor Cyan

                    # Presentación organizada de datos de la BIOS
                    $propiedadesBios = @{
                        'Nombre'          = $biosInfo.Name
                        'Version'         = $biosInfo.SMBIOSBIOSVersion
                        'Fabricante BIOS' = $biosInfo.Manufacturer
                        'Numero Serie'    = $biosInfo.SerialNumber
                        'Version Mayor'   = $biosInfo.SMBIOSMajorVersion
                    }

                    New-Object PSObject -Property $propiedadesBios | Select-Object 'Numero Serie', Fabricante, Version, Nombre | Format-List

                    Write-Host "--- SISTEMA OPERATIVO ---" -ForegroundColor Cyan
                    Write-Host "Version: $($osInfo.Caption) ($($osInfo.Version))"
                    Write-Host "Arquitectura: $($osInfo.OSArchitecture)"
                    Write-Host ""

            
                }

                "3.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    # 1. Obtener información del procesador usando WMI (Compatible con PS 2.0 en adelante)
                    $cpuInfo = Get-WmiObject -Class Win32_Processor

                    Write-Host "--- DETALLES DEL PROCESADOR (CPU) ---" -ForegroundColor Cyan
                    Write-Host ""

                    # 2. Creamos un objeto con las propiedades más relevantes, limpiando datos técnicos innecesarios
                    $reporte = $cpuInfo | Select-Object `
                        Name, 
                    Manufacturer, 
                    @{Name = "Nucleos_Fisicos"; Expression = { $_.NumberOfCores } },
                    @{Name = "Hilos_Logicos"; Expression = { $_.NumberOfLogicalProcessors } },
                    @{Name = "Velocidad_Max(MHz)"; Expression = { $_.MaxClockSpeed } },
                    @{Name = "Arquitectura"; Expression = {
                            switch ($_.Architecture) {
                                0 { "x86 (32-bit)" }
                                6 { "Itanium" }
                                9 { "x64 (64-bit)" }
                                default { "Desconocida" }
                            }
                        }
                    },
                    SocketDesignation,
                    L2CacheSize,
                    L3CacheSize

                    # 3. Mostrar resultados en formato de lista para mejor lectura
                    $reporte | Format-List



                    Write-Host "------------------------------------------------------------"
                    Write-Host "Informacion obtenida via WMI - Compatible Win7 y posteriores" -ForegroundColor Cyan
                    Write-Host ""

                }
                "4" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    # 1. Obtener configuraciones de red con IP habilitada
                    # Usamos Get-WmiObject por ser el estandar mas compatible con Windows 7
                    $networkConfigs = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE"

                    Write-Host "--- DIRECCIONES IP ACTIVAS EN EL SISTEMA ---" -ForegroundColor Cyan
                    Write-Host ""

                    # 2. Procesar y limpiar la informacion
                    $reporte = foreach ($config in $networkConfigs) {
                        # Extraemos solo la primera direccion IPv4 (usualmente la principal)
                        # y eliminamos las llaves si existen
                        $ipPrincipal = $config.IPAddress[0]
                        $macAddress = $config.MACAddress
                        $descripcion = $config.Description

                        New-Object PSObject -Property @{
                            'Adaptador'    = $descripcion
                            'Direccion_IP' = $ipPrincipal
                            'MAC_Address'  = $macAddress
                            'DHCP'         = if ($config.DHCPEnabled) { "Si" } else { "No" }
                        }
                    }

                    # 3. Mostrar tabla formateada
                    $reporte | Select-Object Adaptador, Direccion_IP, DHCP, MAC_Address | Format-Table -AutoSize



                    Write-Host "-------------------------------------------------------"
                    Write-Host "Nota: Se muestra la IPv4 principal por adaptador." -ForegroundColor Cyan
                    Write-Host " "

                }
                
                "4.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    # 1. Configuración de entorno y limpieza
                    Write-Host "===========================================================" -ForegroundColor Cyan
                    Write-Host "    REPORTE DE TODAS LAS INTERFACES Y DIRECCIONES IP      " -ForegroundColor Cyan
                    Write-Host "      Compatibilidad Universal: Windows 7, 8, 10 y 11      " -ForegroundColor Cyan
                    Write-Host "===========================================================" -ForegroundColor Cyan

                    # 2. Obtener datos de Hardware (Win32_NetworkAdapter) y Configuración (Win32_NetworkAdapterConfiguration)
                    # Usamos Get-WmiObject para asegurar funcionamiento en PowerShell 2.0 (Win 7)
                    $allHW = Get-WmiObject -Class Win32_NetworkAdapter
                    $allConfigs = Get-WmiObject -Class Win32_NetworkAdapterConfiguration

                    $reporteGlobal = foreach ($hw in $allHW) {
                        # Relacionamos el hardware con su configuración de IP usando el Index
                        $config = $allConfigs | Where-Object { $_.Index -eq $hw.DeviceID }
                        
                        # Extraemos IPs y Máscaras (si existen)
                        $ipv4 = "---"
                        $mask = "---"
                        if ($config.IPAddress) {
                            $ipv4 = $config.IPAddress | Where-Object { $_ -like '*.*.*.*' } | Select-Object -First 1
                            $mask = $config.IPSubnet | Where-Object { $_ -like '*.*.*.*' } | Select-Object -First 1
                        }

                        # Clasificación de Tecnología
                        $tipo = "Fisica (Ethernet)"
                        if ($hw.Name -match "Wi-Fi|Wireless|802.11") { $tipo = "Wi-Fi" }
                        elseif ($hw.Name -match "Bluetooth") { $tipo = "Bluetooth" }
                        elseif ($hw.Name -match "Virtual|VMware|VirtualBox|Hyper-V|TAP|VPN|Pseudo") { $tipo = "Virtual" }

                        # Estado de conexión
                        $estado = switch ($hw.NetConnectionStatus) {
                            2 { "Conectado" }
                            7 { "Deshabilitado" }
                            default { "Desconectado/Inactivo" }
                        }

                        # Solo incluimos interfaces con MAC o que sean relevantes para el usuario
                        if ($hw.MACAddress -and $hw.NetConnectionID) {
                            New-Object PSObject -Property @{
                                'Interface'    = $hw.NetConnectionID
                                'Tecnologia'   = $tipo
                                'Estado'       = $estado
                                'Direccion_IP' = $ipv4
                                'Mascara'      = $mask
                            }
                        }
                    }

                    # 3. Mostrar el reporte unificado
                    $reporteGlobal | Select-Object Tecnologia, Interface, Estado, Direccion_IP, Mascara | Sort-Object Tecnologia | Format-Table -AutoSize



                    Write-Host "-----------------------------------------------------------"
                    Write-Host "DETALLE DE ANALISIS:" -ForegroundColor Yellow
                    Write-Host "* FISICAS: Conexiones por cable (Ethernet)."
                    Write-Host "* WI-FI: Adaptadores inalambricos."
                    Write-Host "* BLUETOOTH: Enlaces de red de corto alcance."
                    Write-Host "* VIRTUALES: Adaptadores de software (VPN, Maquinas Virtuales)."
                    Write-Host "-----------------------------------------------------------"

                    Write-Host " "
                }
                "4.2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    # 1. Obtener la IP Pública directamente en la consola
                    Write-Host "Consultando IP publica actual..." -ForegroundColor Cyan

                    try {
                        # Usamos el cliente Web de .NET para maxima compatibilidad con Windows 7 (PS 2.0)
                        $webClient = New-Object System.Net.WebClient
                        $ipPublica = $webClient.DownloadString("http://ifconfig.me/ip").Trim()
                        Write-Host "Tu IP Publica es: " -NoNewline
                        Write-Host $ipPublica -ForegroundColor Green -BackgroundColor Black
                    }
                    catch {
                        Write-Host "No se pudo obtener la IP automaticamente." -ForegroundColor Red
                    }

                    Write-Host "`n-------------------------------------------------------"

                    # 2. Abrir el navegador en un sitio de verificacion
                    Write-Host "Abriendo navegador para verificacion visual..." -ForegroundColor Yellow

                    $url = "https://www.cualesmiip.com"

                    # Usamos Start-Process de forma generica para que abra el NAVEGADOR PREDETERMINADO
                    # Esto asegura que funcione en Win 7 (IE/Chrome) y Win 10/11 (Edge)
                    try {
                        Start-Process $url
                    }
                    catch {
                        # Fallback: Intento directo si el anterior falla en entornos muy antiguos
                        [System.Diagnostics.Process]::Start($url)
                    }

                    Write-Host "-------------------------------------------------------"
                    Write-Host " "                

                }
                "5.1" {
                    cabecera
                    menuOpcion "Se encuentra en: Gestion de Red Local -> Resetear IP Red LAN"

                    Write-Host "`n******* RESTABLECIMIENTO DE PROTOCOLO IP (TCP/IP) *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    $logPath = "C:\temp"
                    $logFile = "$logPath\resetLan.txt"

                    if (-not (Test-Path $logPath)) {
                        New-Item -Path $logPath -ItemType Directory -Force | Out-Null
                    }

                    Write-Host "Iniciando reset de interfaz IP..." -ForegroundColor Yellow

                    & netsh int ip reset $logFile

                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "El protocolo IP se restablecio correctamente." -ForegroundColor Green
                        Write-Host "Log generado en: $logFile" -ForegroundColor Gray
                        Write-Host "NOTA: ES NECESARIO REINICIAR EL EQUIPO PARA APLICAR CAMBIOS." -ForegroundColor Red -BackgroundColor White
                    }
                    else {
                        Write-Host "Ocurrio un error al intentar restablecer el protocolo (Codigo: $LASTEXITCODE)." -ForegroundColor Red
                    }

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Green
                }
                "5.2" {
                    cabecera
                    menuOpcion "Se encuentra en: Gestion de Red Local -> Resetear IP y Asignar DHCP"

                    Write-Host "Resetear IP Red y Asignar DHCP"
                    netsh winsock reset
                    netsh int ip reset c:\resetLan.txt
                    ipconfig /release
                    ipconfig /renew
                    ipconfig /flushdns
                }
                "5.3" {
                    cabecera
                    menuOpcion "Se encuentra en: Gestion de Red Local -> Mostrar Claves MAC Address"

                    getmac /v /fo list
                }
                "5.4" {
                    cabecera
                    menuOpcion "Se encuentra en: Gestion de Red Local -> Actualizacion y Diagnostico de Politicas"

                    Write-Host "ipconfig /flushdns: ---------> E J E C U T A N D O <---------" -ForegroundColor Yellow
                    ipconfig /flushdns
                    ipconfig /registerdns
                    ipconfig /displaydns
                        
                    Write-Host "netsh interface ip delete arpcache: ---------> E J E C U T A N D O <---------" -ForegroundColor Yellow
                    netsh interface ip delete arpcache
                        
                    Write-Host "netsh winsock reset catalog: ---------> E J E C U T A N D O <---------" -ForegroundColor Yellow
                    netsh winsock reset catalog
                        
                    Write-Host "wuauclt /detectnow: ---------> E J E C U T A N D O <---------" -ForegroundColor Yellow
                    wuauclt /detectnow
                        
                    Write-Host "GPUPDATE /FORCE: ---------> E J E C U T A N D O <---------" -ForegroundColor Yellow
                    GPUPDATE /FORCE

                    Write-Host "Proceso realizado..." -ForegroundColor Green
                    Write-Host ""
                }
                "6.1" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"
                        
                    # 1. Definir rutas usando variables de entorno de forma segura
                    $userTemp = "$env:TEMP"             # C:\Users\Nombre\AppData\Local\Temp
                    $systemTemp = "$env:SystemRoot\Temp"  # C:\Windows\Temp
                    $prefetch = "$env:SystemRoot\Prefetch"

                    Write-Host "Iniciando limpieza profunda de temporales..." -ForegroundColor Yellow

                    # 2. Limpieza de Temporales de Usuario
                    Write-Host " > Limpiando Temp de Usuario..." -NoNewline
                    Remove-Item -Path "$userTemp\*" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host " [OK]" -ForegroundColor Green

                    # 3. Limpieza de Temporales del Sistema
                    Write-Host " > Limpiando Temp de Windows..." -NoNewline
                    Remove-Item -Path "$systemTemp\*" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host " [OK]" -ForegroundColor Green

                    # 4. Limpieza de Prefetch
                    Write-Host " > Limpiando Prefetch..." -NoNewline
                    Remove-Item -Path "$prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host " [OK]" -ForegroundColor Green

                    # 5. Abrir carpetas para verificación (Opcional, emulando tu .bat)
                    Start-Process explorer.exe $userTemp
                    Start-Process explorer.exe $prefetch

                    Write-Host "Limpieza finalizada correctamente." -ForegroundColor White -BackgroundColor DarkGreen
                    Write-Host ""
                }
                "6.2" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"
                        
                    # 1. Definimos las carpetas que NO queremos tocar bajo ninguna circunstancia
                    $excluir = @("*Microsoft*", "*Package Cache*", "*Antivirus*", "*SoftwareLicensing*", "*NVIDIA*")

                    # 2. Ejecutamos la búsqueda con filtros de seguridad
                    Get-ChildItem -Path "C:\ProgramData" -Recurse -File -Force -ErrorAction SilentlyContinue | 
                    Where-Object {
                        # Filtro 1: Que no esté en la lista de exclusión
                        $itemPath = $_.FullName
                        $safe = $true
                        foreach ($pattern in $excluir) {
                            if ($itemPath -like $pattern) { $safe = $false; break }
                        }

                        # Filtro 2: Solo extensiones típicas de basura y con más de 7 días
                        $safe -and 
                        ($_.Extension -match "\.(tmp|log|bak|old|chk|temp)$") -and 
                        ($_.LastWriteTime -lt (Get-Date).AddDays(-7))
                    } | 
                    Remove-Item -Force -ErrorAction SilentlyContinue
                        
                    Write-Host "Proceso finalizado" -ForegroundColor Green
                    Write-Host ""
                }
                "6.3" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"
                    psLimpiarRAM

                    Write-Host "Presione Enter para volver..." -ForegroundColor Green
                }
                "6.4" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    Write-Host "--- Reporte de Estado Inicial del Procesador ---" -ForegroundColor Yellow

                    # 1. Obtener carga total del procesador usando WMI (Máxima compatibilidad)
                    $cpuLoad = (Get-WmiObject Win32_Processor).LoadPercentage
                    Write-Host "Carga actual del sistema: $cpuLoad%" -ForegroundColor Cyan

                    # 2. Identificar procesos que consumen más del 20% de CPU
                    # Usamos Get-Process y seleccionamos los primeros 10 por uso de tiempo de CPU
                    $procesosPesados = Get-Process | Sort-Object CPU -Descending | Select-Object -First 10

                    Write-Host "`nTop 10 procesos por consumo acumulado:" -ForegroundColor Yellow
                    $procesosPesados | Format-Table Name, ID, CPU, PriorityClass -AutoSize

                    # 3. Acción de optimización: Cambiar prioridad a 'BelowNormal' 
                    # Esto evita que los procesos "estrangulen" el sistema sin llegar a cerrarlos bruscamente.
                    foreach ($proc in $procesosPesados) {
                        if ($proc.Name -ne "Idle" -and $proc.Name -ne "powershell") {
                            try {
                                $proc.PriorityClass = "BelowNormal"
                                Write-Host "Prioridad ajustada para: $($proc.Name) (ID: $($proc.Id))" -ForegroundColor Green
                            }
                            catch {
                                Write-Host "No se pudo cambiar prioridad de: $($proc.Name) (Permisos insuficientes)" -ForegroundColor Gray
                            }
                        }
                    }

                    # 4. Limpieza de memoria de trabajo (Working Set)
                    # Ayuda a liberar presión indirecta sobre el procesador al reducir el paginado
                    Write-Host "`nLiberando memoria de trabajo innecesaria..." -ForegroundColor Yellow
                    [System.GC]::Collect()

                    Write-Host "`nOptimizacion completada." -ForegroundColor White
                    Write-Host "`nProceso finalizado..." -ForegroundColor Yellow
                    Write-Host ""
                }
                "6.5" { 

                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    Write-Host "--- INICIANDO LIMPIEZA DE PAPELERA DE RECICLAJE ---" -ForegroundColor Cyan

                    # Intentar el método moderno (Win 10/11) y si falla, usar el método universal (Win 7)
                    try {
                        # El parámetro -Force evita que pida confirmación por cada archivo
                        # -ErrorAction Stop nos permite saltar al 'catch' si el comando no existe
                        Clear-RecycleBin -Confirm:$false -ErrorAction Stop
                        Write-Host "Papelera vaciada usando comando nativo." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Comando nativo no disponible. Usando metodo de compatibilidad (Win 7)..." -ForegroundColor Yellow
                        try {
                            # Método COM: funciona desde Windows XP hasta Windows 11
                            $shell = New-Object -ComObject Shell.Application
                            $recycler = $shell.Namespace(0xa) # 0xa es el ID constante para la Papelera
                            $recycler.Items() | ForEach-Object { Remove-Item $_.Path -Recurse -Force }
                            Write-Host "Papelera vaciada con exito." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "ERROR: No se pudo completar la limpieza." -ForegroundColor Red
                        }
                    }

                    # Abrir la ventana de la Papelera de Reciclaje para verificación visual
                    Write-Host "`nAbriendo la papelera de reciclaje para verificacion..." -ForegroundColor Yellow
                    try {
                        Start-Process "explorer.exe" "shell:RecycleBinFolder"
                    }
                    catch {
                        # Fallback de seguridad mediante .NET en caso de que Start-Process falle
                        [System.Diagnostics.Process]::Start("explorer.exe", "shell:RecycleBinFolder") | Out-Null
                    }

                    Write-Host "-------------------------------------------------------"
                    Write-Host " "

                }
                "6.6" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    Write-Host "===========================================================" -ForegroundColor Cyan
                    Write-Host "   ELIMINACION DE TEMPORALES PARA TODOS LOS USUARIOS       " -ForegroundColor Cyan
                    Write-Host "===========================================================" -ForegroundColor Cyan
                    Write-Host ""

                    # 1. Obtener perfiles de usuario locales y de dominio
                    $profiles = $null
                    if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
                        $profiles = Get-CimInstance -ClassName Win32_UserProfile -ErrorAction SilentlyContinue
                    }
                    else {
                        $profiles = Get-WmiObject -Class Win32_UserProfile -ErrorAction SilentlyContinue
                    }

                    $profilePaths = @()
                    if ($profiles) {
                        foreach ($p in $profiles) {
                            # Evitar carpetas de sistema (SYSTEM, LocalService, NetworkService) y Default
                            if ($p.Special -eq $false -and $p.LocalPath -and (Test-Path $p.LocalPath)) {
                                $profilePaths += $p.LocalPath
                            }
                        }
                    }

                    # Fallback si WMI falla
                    if ($profilePaths.Count -eq 0) {
                        $profilePaths = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue | 
                        Where-Object { $_.Name -notin "Default", "Default User", "All Users", "Public" } | 
                        Select-Object -ExpandProperty FullName
                    }

                    Write-Host "Perfiles de usuario detectados a procesar: $($profilePaths.Count)" -ForegroundColor Yellow
                    Write-Host ""

                    $totalArchivosEliminados = 0
                    $totalCarpetasEliminadas = 0
                    $totalEspacioLiberado = 0

                    foreach ($path in $profilePaths) {
                        $tempPath = Join-Path $path "AppData\Local\Temp"
                        $userName = Split-Path $path -Leaf
                        
                        Write-Host "Procesando perfil: $userName ($path)..." -ForegroundColor Cyan

                        if (Test-Path $tempPath) {
                            Write-Host "  Ruta Temp: $tempPath" -ForegroundColor Gray
                            
                            # Obtener elementos en la carpeta Temp
                            $items = Get-ChildItem -Path "$tempPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                            
                            $eliminadosUser = 0
                            $fallidosUser = 0
                            $espacioUser = 0

                            # Eliminar archivos individualmente
                            foreach ($item in $items) {
                                if (-not $item.PSIsContainer) {
                                    $size = $item.Length
                                    try {
                                        Remove-Item -Path $item.FullName -Force -Recurse -ErrorAction Stop
                                        $totalEspacioLiberado += $size
                                        $espacioUser += $size
                                        $eliminadosUser++
                                        $totalArchivosEliminados++
                                    }
                                    catch {
                                        # Archivo en uso por el usuario/sistema o sin permisos
                                        $fallidosUser++
                                    }
                                }
                            }

                            # Eliminar directorios vacíos recursivamente
                            $dirs = Get-ChildItem -Path "$tempPath\*" -Recurse -Force -ErrorAction SilentlyContinue | 
                            Where-Object { $_.PSIsContainer } | 
                            Sort-Object FullName -Descending
                            foreach ($dir in $dirs) {
                                try {
                                    Remove-Item -Path $dir.FullName -Force -ErrorAction Stop
                                    $totalCarpetasEliminadas++
                                }
                                catch {
                                    # Directorio no está vacío o en uso
                                }
                            }

                            $mbLiberados = [Math]::Round($espacioUser / 1MB, 2)
                            Write-Host "  -> Archivos eliminados: $eliminadosUser | Bloqueados/En uso: $fallidosUser" -ForegroundColor Green
                            Write-Host "  -> Espacio liberado: $mbLiberados MB" -ForegroundColor Green
                        }
                        else {
                            Write-Host "  -> Directorio Temp no inicializado para este usuario." -ForegroundColor Yellow
                        }
                        Write-Host ""
                    }

                    $totalMBLiberados = [Math]::Round($totalEspacioLiberado / 1MB, 2)
                    Write-Host "-----------------------------------------------------------" -ForegroundColor Gray
                    Write-Host "RESUMEN GLOBAL DE LIMPIEZA MULTI-USUARIO:" -ForegroundColor Cyan
                    Write-Host "Total archivos eliminados: $totalArchivosEliminados" -ForegroundColor White
                    Write-Host "Total carpetas eliminadas: $totalCarpetasEliminadas" -ForegroundColor White
                    Write-Host "Total espacio liberado:    $totalMBLiberados MB" -ForegroundColor Green
                    Write-Host "-----------------------------------------------------------" -ForegroundColor Gray
                    Write-Host ""
                }
                "12" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    # 1. Obtener los parches de seguridad y actualizaciones (QuickFixEngineering)
                    # Usamos Get-WmiObject para asegurar compatibilidad con PS 2.0 (Win 7)
                    Write-Host "Consultando el historial de actualizaciones instaladas..." -ForegroundColor Cyan
                    Write-Host "Esto puede tardar unos segundos dependiendo del equipo..." -ForegroundColor Gray

                    $updates = Get-WmiObject -Class Win32_QuickFixEngineering

                    # 2. Formatear y mostrar la información relevante
                    $reporte = foreach ($update in $updates) {
                        New-Object PSObject -Property @{
                            'ID_Parche'     = $update.HotFixID
                            'Descripcion'   = $update.Description
                            'Instalado_Por' = $update.InstalledBy
                            'Fecha'         = $update.InstalledOn
                        }
                    }

                    # 3. Mostrar tabla organizada por fecha (si es posible)
                    $reporte | Select-Object ID_Parche, Descripcion, Fecha, Instalado_Por | Format-Table -AutoSize



                    Write-Host "-------------------------------------------------------"
                    Write-Host "Total de parches detectados: $($updates.Count)" -ForegroundColor Yellow
                    Write-Host "-------------------------------------------------------"

                    Write-Host " "

                }


                
                "20" {
                    psSubMenuPortatil
                }
                "0" { 
                    #$salirSub = $true 
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            } # Cierra switch            
            if (-not $salirSub) { Read-Host "SUB_MENU 23: Presione ENTER para continuar..." }

        } # Cierra try

        catch {
            Write-Host "`n[ERROR NO ESPERADO]: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Presione Enter para continuar..."
        }
		
        finally {
            # *************************************************************************************
            # BLOQUE DE LIMPIEZA Y REFRESCO (Se ejecuta después de cada opción)
            # *************************************************************************************
            
            # 1. Liberar memoria de objetos COM/WMI/CIM colgados
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()

            # 2. Eliminar variables temporales de la sesión para evitar errores de "cadena de entrada"
            # Mantenemos variables críticas del script
            Get-Variable | Where-Object { 
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. Pequeña pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }

    } while (-not $salirSub)
}

function psSubMenuPortatil {
    $salirSubPortatil = $false
    do {
        try {
            # cabecera con informacion del autor
            cabecera
            Write-Header " 23.20. ---)) LOCAL: HERRAMIENTAS PC PORTATIL."
            Write-Host "  1. BitLocker - Dell - HP - Lenovo" -ForegroundColor Green
            Write-Host "    1.1. Deshabilitar BitLocker (Deshabilitar protectores C: - Mantenimiento)"
            Write-Host "    1.2. Activar BitLocker (Habilitar protectores C: - Fin Mantenimiento)"
            Write-Host "    1.3. Verificar Estado de BitLocker" -ForegroundColor Yellow
            Write-Host "    1.4. Desactivar Cifrado BitLocker de forma Permanente"
            Write-Host "    1.5. Activar Cifrado de BitLocker de forma Permanente"
            Write-Host "    1.6. Mostrar Progreso de Desactivacion (Descifrado)" -ForegroundColor Yellow
            Write-Host "  2. Estado de bateria Laptop (Diagnostico de Salud y Desgaste)." -ForegroundColor Green
            Write-Host ""
            Write-Host "  0. V O L V E R   A L   M E N U   A N T E R I O R   (SUB-MENU 23)"
            Write-Header "===================================================================="
            
            $opPortatil = Read-Host "Seleccione la tarea a realizar"

            switch ($opPortatil) {
                "1" {
                    Write-Host "Por favor seleccione una opcion valida (1.1 - 1.6) para gestionar BitLocker." -ForegroundColor Yellow
                }
                "1.1" {
                    cabecera
                    menuOpcion "HERRAMIENTAS PC PORTATIL -> Activar BitLocker (Mantenimiento)"
                    Write-Host "Consultando estado actual de BitLocker..." -ForegroundColor Cyan
                    manage-bde -status C:
                    Write-Host "`nEjecutando: manage-bde -protectors -disable C:" -ForegroundColor Yellow
                    manage-bde -protectors -disable C:
                    Write-Host "`nProceso ejecutado."
                }
                "1.2" {
                    cabecera
                    menuOpcion "HERRAMIENTAS PC PORTATIL -> Desactivar BitLocker"
                    Write-Host "Ejecutando: manage-bde -protectors -enable C:" -ForegroundColor Yellow
                    manage-bde -protectors -enable C:
                    Write-Host "`nProceso ejecutado."
                }
                "1.3" {
                    cabecera
                    menuOpcion "HERRAMIENTAS PC PORTATIL -> Verificar estado de BitLocker"
                    Write-Host "Consultando estado actual de BitLocker en la unidad C:..." -ForegroundColor Cyan
                    manage-bde -status C:
                    Write-Host "`nProceso ejecutado."
                }
                "1.4" {
                    cabecera
                    menuOpcion "HERRAMIENTAS PC PORTATIL -> Desactivar BitLocker permanentemente"
                    Write-Host "¡ATENCION! Esta opcion desactivara y descifrara BitLocker permanentemente en C:." -ForegroundColor Red
                    $confirm = Read-Host "¿Esta seguro de que desea continuar? (S/N)"
                    if ($confirm -eq "S" -or $confirm -eq "s") {
                        Write-Host "Iniciando descifrado permanente de BitLocker en la unidad C:..." -ForegroundColor Yellow
                        manage-bde -off C:
                        Write-Host "`nProceso iniciado con exito. Puede monitorear el progreso usando la opcion 1.6." -ForegroundColor Green
                    }
                    else {
                        Write-Host "Operacion cancelada." -ForegroundColor Cyan
                    }
                }
                "1.5" {
                    cabecera
                    menuOpcion "HERRAMIENTAS PC PORTATIL -> Activar Cifrado de BitLocker permanentemente"
                    Write-Host "¡ATENCION! Esta opcion activara e iniciara el cifrado de BitLocker permanentemente en C:." -ForegroundColor Red
                    $confirm = Read-Host "¿Esta seguro de que desea continuar? (S/N)"
                    if ($confirm -eq "S" -or $confirm -eq "s") {
                        Write-Host "Iniciando cifrado permanente de BitLocker en la unidad C:..." -ForegroundColor Yellow
                        manage-bde -on C:
                        Write-Host "`nProceso iniciado con exito. Puede monitorear el progreso usando la opcion 1.6." -ForegroundColor Green
                    }
                    else {
                        Write-Host "Operacion cancelada." -ForegroundColor Cyan
                    }
                }
                "1.6" {
                    cabecera
                    menuOpcion "HERRAMIENTAS PC PORTATIL -> Progreso de desactivacion de BitLocker"
                    Write-Host "Consultando el estado de progreso en la unidad C:..." -ForegroundColor Cyan
                    $status = manage-bde -status C:
                    $status | Out-String | Write-Host
                    
                    # Intentar extraer porcentaje cifrado y estado de conversion
                    $statusText = $status -join "`n"
                    $porcentajeMatch = [regex]::Match($statusText, '(Percentage Encrypted|Porcentaje cifrado)\s*:\s*([\d,.]+%)', 'IgnoreCase')
                    $estadoMatch = [regex]::Match($statusText, '(Conversion Status|Estado de conversi.n)\s*:\s*([^\r\n]+)', 'IgnoreCase')
                    
                    if ($porcentajeMatch.Success -or $estadoMatch.Success) {
                        Write-Host "`n--- RESUMEN DE PROGRESO DE DESCIFRADO ---" -ForegroundColor Yellow
                        if ($estadoMatch.Success) {
                            Write-Host "Estado actual: $($estadoMatch.Groups[2].Value.Trim())" -ForegroundColor Green
                        }
                        if ($porcentajeMatch.Success) {
                            $pctStr = $porcentajeMatch.Groups[2].Value.Trim()
                            Write-Host "Porcentaje Cifrado: $pctStr" -ForegroundColor Cyan
                            # Mostrar el inverso para indicar progreso de descifrado
                            $numPart = $pctStr -replace '[^\d,.]', ''
                            # Cambiar coma por punto si es necesario para convertir a double en PowerShell
                            $numPart = $numPart -replace ',', '.'
                            if ([double]::TryParse($numPart, [ref]$val)) {
                                $progresoDescifrado = 100 - $val
                                Write-Host "Progreso de Descifrado: $progresoDescifrado%" -ForegroundColor Green
                                
                                # Dibujar barra de progreso simple en consola
                                $barLength = 20
                                $filled = [Math]::Round(($progresoDescifrado / 100) * $barLength)
                                $empty = $barLength - $filled
                                $bar = "[" + ("#" * $filled) + ("." * $empty) + "]"
                                Write-Host "Progreso: $bar" -ForegroundColor Green
                            }
                        }
                        Write-Host "----------------------------------------"
                    }
                }
                "2" {
                    cabecera
                    menuOpcion "HERRAMIENTAS PC PORTATIL -> Estado de bateria Laptop"
                    
                    Write-Host "===========================================================" -ForegroundColor Cyan
                    Write-Host "      ANALISIS DE SALUD Y DESGASTE DE LA BATERIA           " -ForegroundColor Cyan
                    Write-Host "===========================================================" -ForegroundColor Cyan
                    Write-Host ""

                    # 1. Determinar si el equipo es Laptop o PC de Escritorio
                    $isLaptop = $false
                    $baterias = $null
                    if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
                        $baterias = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
                    }
                    else {
                        $baterias = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
                    }
                    
                    if ($baterias) {
                        $isLaptop = $true
                    }
                    else {
                        $chassisTypes = @()
                        if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
                            $chassisTypes = (Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction SilentlyContinue).ChassisTypes
                        }
                        else {
                            $chassisTypes = (Get-WmiObject -Class Win32_SystemEnclosure -ErrorAction SilentlyContinue).ChassisTypes
                        }
                        
                        foreach ($t in $chassisTypes) {
                            # Códigos de chasis portátiles comunes
                            if ($t -in 8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32) {
                                $isLaptop = $true
                                break
                            }
                        }
                    }

                    # Mostrar detección
                    if ($isLaptop) {
                        Write-Host "Tipo de equipo detectado: PC Portatil (Laptop)" -ForegroundColor Green
                        Write-Host "Detected System Type: Laptop" -ForegroundColor Green
                    }
                    else {
                        Write-Host "Tipo de equipo detectado: PC de Escritorio (Desktop)" -ForegroundColor Yellow
                        Write-Host "Detected System Type: Desktop" -ForegroundColor Yellow
                    }
                    Write-Host ""

                    # 2. Mostrar Fórmulas
                    Write-Host "Formula para calcular la salud / Battery health formula:" -ForegroundColor Cyan
                    Write-Host "  Espanol: Porcentaje de Vida Util = (Capacidad de Carga Completa / Capacidad de Diseno) * 100" -ForegroundColor Gray
                    Write-Host "  English: Battery Health Percentage = (Full Charge Capacity / Design Capacity) * 100" -ForegroundColor Gray
                    Write-Host ""

                    # 3. Generar reporte HTML en C:\bateriaReporte.html
                    $rutaHTML = "C:\bateriaReporte.html"
                    Write-Host "Generando reporte de bateria en C:\bateriaReporte.html... / Generating battery report..." -ForegroundColor Gray
                    
                    try {
                        $pOutput = powercfg /batteryreport /output $rutaHTML 2>&1
                        if (Test-Path $rutaHTML) {
                            Write-Host "Reporte generado en: $rutaHTML" -ForegroundColor Green
                        }
                        else {
                            Write-Host "No se pudo generar el reporte. Asegurese de ejecutar el script como Administrador." -ForegroundColor Red
                            Write-Host "Detalle del sistema: $pOutput" -ForegroundColor Gray
                        }
                    }
                    catch {
                        Write-Host "No se pudo generar el reporte mediante powercfg: $($_.Exception.Message)" -ForegroundColor Red
                    }
                    Write-Host ""

                    # 4. Obtener y mostrar datos reales de batería si es una Laptop
                    if ($isLaptop) {
                        $designedCapacityVal = 0
                        $fullChargeCapacityVal = 0
                        $cycleCountVal = $null
                        $manufacturer = "Desconocido"
                        $chemistry = "Desconocido"
                        $parsedOK = $false

                        # Intentar obtener datos a través de WMI/CIM en root/wmi
                        if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
                            $staticData = Get-CimInstance -Namespace "root\wmi" -ClassName "BatteryStaticData" -ErrorAction SilentlyContinue
                            $fullChargeData = Get-CimInstance -Namespace "root\wmi" -ClassName "BatteryFullChargedCapacity" -ErrorAction SilentlyContinue
                            $cycleData = Get-CimInstance -Namespace "root\wmi" -ClassName "BatteryCycleCount" -ErrorAction SilentlyContinue
                            
                            if ($staticData) {
                                $designedCapacityVal = $staticData[0].DesignedCapacity
                                $chemistry = $staticData[0].Chemistry
                                $manufacturer = $staticData[0].ManufacturerName
                            }
                            if ($fullChargeData) {
                                $fullChargeCapacityVal = $fullChargeData[0].FullChargedCapacity
                            }
                            if ($cycleData) {
                                $cycleCountVal = $cycleData[0].CycleCount
                            }
                        }
                        
                        if ($designedCapacityVal -eq 0 -and (Get-Command Get-WmiObject -ErrorAction SilentlyContinue)) {
                            $staticData = Get-WmiObject -Namespace "root\wmi" -Class "BatteryStaticData" -ErrorAction SilentlyContinue
                            $fullChargeData = Get-WmiObject -Namespace "root\wmi" -Class "BatteryFullChargedCapacity" -ErrorAction SilentlyContinue
                            $cycleData = Get-WmiObject -Namespace "root\wmi" -Class "BatteryCycleCount" -ErrorAction SilentlyContinue
                            
                            if ($staticData) {
                                $designedCapacityVal = $staticData[0].DesignedCapacity
                                $chemistry = $staticData[0].Chemistry
                                $manufacturer = $staticData[0].ManufacturerName
                            }
                            if ($fullChargeData) {
                                $fullChargeCapacityVal = $fullChargeData[0].FullChargedCapacity
                            }
                            if ($cycleData) {
                                $cycleCountVal = $cycleData[0].CycleCount
                            }
                        }

                        # Fallback a Win32_Battery
                        if ($designedCapacityVal -eq 0) {
                            $win32Battery = $null
                            if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
                                $win32Battery = Get-CimInstance -ClassName "Win32_Battery" -ErrorAction SilentlyContinue
                            }
                            else {
                                $win32Battery = Get-WmiObject -Class "Win32_Battery" -ErrorAction SilentlyContinue
                            }
                            
                            if ($win32Battery) {
                                $designedCapacityVal = $win32Battery[0].DesignCapacity
                                $fullChargeCapacityVal = $win32Battery[0].FullChargeCapacity
                                $manufacturer = $win32Battery[0].Manufacturer
                                $chemistry = $win32Battery[0].Chemistry
                            }
                        }

                        if ($designedCapacityVal -gt 0 -and $fullChargeCapacityVal -gt 0) {
                            $parsedOK = $true
                        }

                        if ($parsedOK) {
                            $porcentajeVida = [Math]::Round(($fullChargeCapacityVal / $designedCapacityVal) * 100, 1)
                            $porcentajeDesgaste = [Math]::Round(100 - $porcentajeVida, 1)
                            
                            Write-Host "--- DATOS GENERALES DE LA BATERIA ---" -ForegroundColor Cyan
                            Write-Host "Fabricante:        $manufacturer"
                            Write-Host "Quimica:           $chemistry"
                            Write-Host "Capacidad Diseno:  $designedCapacityVal mWh"
                            Write-Host "Capacidad Actual:  $fullChargeCapacityVal mWh"
                            if ($null -ne $cycleCountVal) {
                                Write-Host "Ciclos de Carga:   $cycleCountVal"
                            }
                            
                            Write-Host "`n--- REPORTE DE SALUD Y DESGASTE ---" -ForegroundColor Yellow
                            Write-Host "Porcentaje de Salud (Vida Util): " -NoNewline
                            if ($porcentajeVida -ge 90) {
                                Write-Host "$porcentajeVida%" -ForegroundColor Green
                            }
                            elseif ($porcentajeVida -ge 75) {
                                Write-Host "$porcentajeVida%" -ForegroundColor Yellow
                            }
                            else {
                                Write-Host "$porcentajeVida%" -ForegroundColor Red
                            }
                            
                            Write-Host "Porcentaje de Desgaste:          " -NoNewline
                            if ($porcentajeDesgaste -le 10) {
                                Write-Host "$porcentajeDesgaste%" -ForegroundColor Green
                            }
                            elseif ($porcentajeDesgaste -le 25) {
                                Write-Host "$porcentajeDesgaste%" -ForegroundColor Yellow
                            }
                            else {
                                Write-Host "$porcentajeDesgaste%" -ForegroundColor Red
                            }
                            
                            Write-Host "`n--- INTERPRETACION TECNICA ---" -ForegroundColor Cyan
                            if ($porcentajeVida -ge 90) {
                                Write-Host "ESTADO: EXCELENTE" -ForegroundColor Green
                                Write-Host "La bateria esta en optimas condiciones and retiene la mayor parte de su capacidad original."
                                Write-Host "`nRECOMENDACIONES DE EXPERTO:" -ForegroundColor Yellow
                                Write-Host "1. Evite descargar la bateria por completo por debajo del 20%; las descargas profundas estresan las celdas de Ion-Litio."
                                Write-Host "2. No mantenga la laptop cargando permanentemente al 100% en ambientes de alta temperatura (esto acelera el desgaste quimico)."
                                Write-Host "3. Si la marca de su laptop posee herramientas de gestion (Dell Power Manager, HP Support Assistant, Lenovo Vantage), configure un limite de carga al 80% si planea utilizarla conectada a la corriente la mayor parte del tiempo."
                            }
                            elseif ($porcentajeVida -ge 75) {
                                Write-Host "ESTADO: BUENO / NORMAL" -ForegroundColor Yellow
                                Write-Host "La bateria presenta un nivel de desgaste normal debido al uso transcurrido. La autonomia es adecuada."
                                Write-Host "`nRECOMENDACIONES DE EXPERTO:" -ForegroundColor Yellow
                                Write-Host "1. Mantenga habitos de carga estables, evitando descargas completas recurrentes."
                                Write-Host "2. Realice una calibracion de bateria cada 3 meses: carguela al 100%, dejela descargar completamente hasta que el equipo se apague solo, y vuelva a cargarla al 100% de manera ininterrumpida con el equipo apagado. Esto recalibra el chip indicador."
                                Write-Host "3. Asegurese de que las rejillas de ventilacion del portatil esten limpias, ya que el calor excesivo es el peor enemigo de la vida util de la bateria."
                            }
                            elseif ($porcentajeVida -ge 50) {
                                Write-Host "ESTADO: REGULAR / DESGASTADO" -ForegroundColor Red
                                Write-Host "La bateria tiene un desgaste considerable. La duracion de la carga es menor y el rendimiento movil se vera reducido."
                                Write-Host "`nRECOMENDACIONES DE EXPERTO:" -ForegroundColor Yellow
                                Write-Host "1. Evite ejecutar aplicaciones de alto rendimiento (juegos, edicion de video) operando unicamente con bateria, ya que la alta demanda de corriente incrementa el estres termico."
                                Write-Host "2. Desactive servicios en segundo plano y reduzca el brillo de pantalla para maximizar los periodos de uso portatil."
                                Write-Host "3. Vaya planificando el reemplazo de la bateria si su ritmo de trabajo requiere movilidad constante."
                            }
                            else {
                                Write-Host "ESTADO: CRITICO / REEMPLAZAR" -ForegroundColor Red -BackgroundColor Black
                                Write-Host "La bateria ha cumplido su ciclo de vida util y la retencion de carga es minima o nula."
                                Write-Host "`nRECOMENDACIONES DE EXPERTO:" -ForegroundColor Yellow
                                Write-Host "1. Se aconseja encarecidamente cambiar la bateria por una original o compatible certificada para restaurar la portabilidad."
                                Write-Host "2. PRECAUCION: Examine visualmente si la bateria se encuentra inflada (esto se nota si el touchpad o el teclado se sienten duros o levantados). Si detecta hinchazon, retire la bateria de inmediato, ya que representa un peligro fisico (riesgo de incendio o explosion)."
                                Write-Host "3. Si utiliza la laptop fija conectada permanentemente, puede optar por remover la bateria (si es extraible) para evitar calor innecesario, o bien limitar estrictamente la carga via software."
                            }
                        }
                        else {
                            Write-Host "No se pudieron extraer los datos detallados de la bateria a traves de WMI/CIM." -ForegroundColor Yellow
                            Write-Host "Por favor, revise el reporte detallado generado en la ruta indicada." -ForegroundColor Yellow
                        }
                    }
                    else {
                        # Recomendaciones para PC de Escritorio
                        Write-Host "RECOMENDACIONES DE EXPERTO (PC DE ESCRITORIO O SERVIDOR):" -ForegroundColor Yellow
                        Write-Host "1. Al tratarse de un equipo de escritorio, se recomienda encarecidamente el uso de un UPS (No-Break) o Sistema de Alimentacion Ininterrumpida."
                        Write-Host "2. Un UPS protegera su PC contra apagones repentinos (que pueden causar corrupcion de archivos y danos en el sistema operativo o SSD/HDD) y contra sobretensiones electricas."
                        Write-Host "3. Realice mantenimientos preventivos de limpieza de polvo interno de la PC y renovacion de pasta termica cada 12 o 18 meses para asegurar temperaturas optimas en el procesador."
                    }

                    # 5. Preguntar si se desea abrir el reporte generado
                    if (Test-Path $rutaHTML) {
                        Write-Host ""
                        $openBrowser = Read-Host "¿Desea abrir el reporte HTML detallado en el navegador? (S/N)"
                        if ($openBrowser -eq "S" -or $openBrowser -eq "s") {
                            Write-Host "Abriendo el reporte en el navegador..." -ForegroundColor Gray
                            try {
                                Start-Process $rutaHTML
                            }
                            catch {
                                Write-Host "No se pudo abrir automaticamente. Puede encontrar el archivo en: $rutaHTML" -ForegroundColor Red
                            }
                        }
                    }
                }
                "0" {
                    $salirSubPortatil = $true
                }
                Default {
                    Write-Host "Opcion invalida." -ForegroundColor Red
                }
            }
            if (-not $salirSubPortatil) { Read-Host "HERRAMIENTAS PC PORTATIL: Presione ENTER para continuar..." }
        }
        catch {
            Write-Host "`n[ERROR NO ESPERADO]: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Presione Enter para continuar..."
        }
    } while (-not $salirSubPortatil)
}

#************************************************* FIN SUB MENU.23*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.24 ******************************************************
#****************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************
function psSubMenu24 {
    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header " 24. ***)) LOCAL: COMANDOS WINDOWS 11 *****"
            Write-Host "  1. Abrir Dispositivos e Impresoras."
            Write-Host "  2. Configuracion de Dispositivos General."
            Write-Host "  3. Accesibilidad - Filtros de Color."
            Write-Host "  4. Accesibilidad - Puntero Mouse."
            Write-Host "  5. Accesibilidad - Cursor Texto."
            Write-Host "  6. PANTALLA PRINCIPAL - CONFIGURACION."
            Write-Host "  7. Pantalla de Dispositivos e Impresoras."
            Write-Host ""
            Write-Host "  0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Header "===================================================================="
            
            $op24 = Read-Host "Seleccione la tarea a realizar"

            switch ($op24) {
                "1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"

                    Write-Host "--- ABRIENDO PANEL DE DISPOSITIVOS E IMPRESORAS ---" -ForegroundColor Cyan

                    try {
                        # El comando 'shell:::' funciona en el explorador de archivos de todas las versiones de Windows
                        Start-Process "shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}"
                        Write-Host "Ventana abierta correctamente." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Error: No se pudo abrir la ventana de impresoras." -ForegroundColor Red
                    }

                }
                "2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"

                    # Obtener la version mayor del sistema (6 = Win 7/8, 10 = Win 10/11)
                    $osVersion = [Environment]::OSVersion.Version.Major

                    if ($osVersion -ge 10) {
                        Write-Host "Detectado Windows 10/11. Abriendo Configuracion Moderna..." -ForegroundColor Cyan
                        Start-Process "ms-settings:printers"
                    }
                    else {
                        Write-Host "Detectado Windows antiguo. Abriendo Panel de Control clasico..." -ForegroundColor Yellow
                        Start-Process "control" -ArgumentList "printers"
                    }

                    Write-Host " "

                }

                "3" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"

                    
                    # 1. Identificar la versión del sistema
                    $osVersion = [Environment]::OSVersion.Version.Major

                    Write-Host "--- AABRIENDO CONFIGURACION DE COLOR Y ACCESIBILIDAD ---" -ForegroundColor Cyan
                    
                    # $os = Get-WmiObject Win32_OperatingSystem

                    if ($osVersion -ge 10) {
                        # Windows 10 y 11: Abrir filtros de color directamente
                        Write-Host "Detectado Windows 10/11. Abriendo Filtros de Color..." -ForegroundColor Green
                        Start-Process "ms-settings:easeofaccess-colorfilter"
                    } 
                    else {
                        # Windows 7 y 8: Abrir el Centro de Accesibilidad clásico
                        Write-Host "Windows 7/8 detectado. Abriendo Centro de Accesibilidad (Optimizar presentacion visual)..." -ForegroundColor Yellow
                        # El ID 0x17 corresponde a la optimización de pantalla
                        Start-Process "control.exe" -ArgumentList "/name Microsoft.EaseOfAccessCenter", "/page pageVisualOptimization"
                        
                        # Para win 10
                        Write-Host "Windows 10 o posterior..." -ForegroundColor Yellow
                        Start-Process "ms-settings:easeofaccess-colorfilter"
                    }

                    Write-Host " "
            
                }

                "4" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"


                    # 1. Identificar la versión del sistema
                    $osVersion = [Environment]::OSVersion.Version.Major
                    Write-Host "--- ABRIENDO CONFIGURACION DE PUNTERO Y MOUSE ---" -ForegroundColor Cyan


                    if ($osVersion -ge 10) {
                        # Windows 10 y 11: Abrir la interfaz moderna de Accesibilidad
                        Write-Host "Detectado Windows 10/11. Abriendo configuracion moderna..." -ForegroundColor Green
                        Start-Process "ms-settings:easeofaccess-mousepointer"
                    } 
                    else {
                        # Windows 7 y 8: Abrir las Propiedades del Mouse clásicas
                        Write-Host "Detectado Windows 7/8. Abriendo Panel de Control clasico..." -ForegroundColor Yellow
                        # 'main.cpl' es el archivo de sistema para las propiedades del mouse
                        Start-Process "control.exe" -ArgumentList "main.cpl,,1" 

                        # Para win 10
                        Write-Host "Windows 10 o posterior..." -ForegroundColor Yellow
                        Start-Process "ms-settings:easeofaccess-mousepointer"
                    }
                    Write-Host " "

                }            

                "5" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"


                    # 1. Identificar la versión del sistema
                    $osVersion = [Environment]::OSVersion.Version.Major
                    Write-Host "--- ABRIENDO CONFIGURACION DE CURSOR DE TEXTO ---" -ForegroundColor Cyan

                    if ($osVersion -ge 10) {
                        # Windows 10 y 11: Abrir la interfaz moderna de accesibilidad del cursor
                        Write-Host "Detectado Windows 10/11. Abriendo configuracion moderna..." -ForegroundColor Green
                        Start-Process "ms-settings:easeofaccess-cursor"
                    } 
                    else {
                        # Windows 7 y 8: Abrir el Centro de Accesibilidad en la sección de optimización visual
                        Write-Host "Detectado Windows 7/8. Abriendo Centro de Accesibilidad clasico..." -ForegroundColor Yellow
                        # Esta página permite ajustar el grosor del cursor de parpadeo en versiones antiguas
                        Start-Process "control.exe" -ArgumentList "/name Microsoft.EaseOfAccessCenter", "/page pageVisualOptimization"

                        # Para win 10
                        Write-Host "Windows 10 o posterior..." -ForegroundColor Yellow
                        Start-Process "ms-settings:easeofaccess-cursor"


                    }
                    Write-Host " "

                }
                "6" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"

                    # 1. Identificar la versión del sistema
                    $osVersion = [Environment]::OSVersion.Version.Major

                    Write-Host "--- ABRIENDO CONFIGURACION ADICIONAL (EXTRAS) ---" -ForegroundColor Cyan

                    if ($osVersion -ge 10) {
                        # Windows 10 y 11: Intentar abrir la sección de Extras moderna
                        Write-Host "Detectado Windows 10/11. Abriendo Extras/Configuracion adicional..." -ForegroundColor Green
                        # Nota: Si el fabricante no incluyó extras, esta página podría abrir el Inicio de Configuración
                        Start-Process "ms-settings:extras"
                    } 
                    else {
                        # Windows 7 y 8: Abrir el Panel de Control principal
                        # Dado que 'extras' no existe como tal, abrimos la vista de iconos para que el usuario elija
                        Write-Host "Detectado Windows 7/8. Abriendo Panel de Control (Vista de iconos)..." -ForegroundColor Yellow
                        Start-Process "control.exe"
                    }
                    Write-Host " "

                }

                "7" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"
                    
                    Write-Host "--- ACCEDIENDO A DISPOSITIVOS E IMPRESORAS ---" -ForegroundColor Cyan

                    try {
                        # El protocolo 'shell:::' es el método más estable entre versiones de SO
                        Start-Process "shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}"
                        Write-Host "Ventana abierta con exito." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Error: No se pudo invocar la interfaz de dispositivos." -ForegroundColor Red
                    }
                    Write-Host " "

                }
                
                "0" { 
                    # $salirSub = $true 
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            }  # Cierra switch
            if (-not $salirSub) { Read-Host "SUB_MENU 24: Presione ENTER para continuar..." }
        } #Cierra try

        catch {
            Write-Host "`n[ERROR NO ESPERADO]: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Presione Enter para continuar..."
        }
		
        finally {
            # *************************************************************************************
            # BLOQUE DE LIMPIEZA Y REFRESCO (Se ejecuta después de cada opción)
            # *************************************************************************************
            
            # 1. Liberar memoria de objetos COM/WMI/CIM colgados
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()

            # 2. Eliminar variables temporales de la sesión para evitar errores de "cadena de entrada"
            # Mantenemos variables críticas del script
            Get-Variable | Where-Object { 
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. Pequeña pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }

    } while (-not $salirSub)
}

#************************************************* FIN SUB MENU.24*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.25 ******************************************************
#**********************************************************************************************************************************
function psSubMenu25 {
    # ==============================================================================
    #   FUNCIONES AUXILIARES DE CONEXION Y ANALISIS REMOTO (OPTIMIZACION Y LIMPIEZA)
    # ==============================================================================

    function Get-StandardIPPrompt {
        param(
            [string]$Mensaje = "Ingrese la IP completa (ej: 192.168.176.50) o los 2 ultimos octetos (ej: 176.50)",
            [pscredential]$Credential = $null,
            [switch]$OmitUserInfo
        )
        $inputRaw = Read-Host $Mensaje
        if ([string]::IsNullOrWhiteSpace($inputRaw)) {
            return ""
        }
        $inputRaw = $inputRaw.Trim()

        $resolvedIP = ""
        # Modalidad 1: IP Completa (formato X.X.X.X)
        if ($inputRaw -match '^(\d{1,3}\.){3}\d{1,3}$') {
            $resolvedIP = $inputRaw
        }
        # Modalidad 2: 2 ultimos octetos (ej: 176.50 o 13.15) -> Asume prefijo 192.168.
        elseif ($inputRaw -match '^\d{1,3}\.\d{1,3}$') {
            $resolvedIP = "192.168.$inputRaw"
        }
        # Tolerancia: 1 octeto (ej: 50) -> Asume prefijo 192.168.176.
        elseif ($inputRaw -match '^\d{1,3}$') {
            $resolvedIP = "192.168.176.$inputRaw"
        }
        # Nombre de equipo (Hostname) o formato extendido
        else {
            $resolvedIP = $inputRaw
        }

        # Visualizar inmediatamente la tarjeta del usuario activo como primera salida tras digitar la IP
        if (-not $OmitUserInfo -and -not [string]::IsNullOrWhiteSpace($resolvedIP)) {
            psMostrarInformacionUsuarioActivo -TargetIP $resolvedIP -Credential $Credential
        }

        return $resolvedIP
    }

    function Parse-RemoteTarget {
        param([string]$Target)
        if ([string]::IsNullOrWhiteSpace($Target)) {
            return ""
        }
        $Target = $Target.Trim()
        if ($Target -match '^(\d{1,3}\.){3}\d{1,3}$') {
            return $Target
        }
        elseif ($Target -match '^\d{1,3}\.\d{1,3}$') {
            return "192.168.$Target"
        }
        elseif ($Target -match '^\d{1,3}$') {
            return "192.168.176.$Target"
        }
        return $Target
    }

    # ==============================================================================
    #   FUNCIONES DE SONDEO RAPIDO, SNMP NATIVO Y CLASIFICACION DE HARDWARE
    # ==============================================================================

    function Test-PortQuick {
        param(
            [string]$ComputerName,
            [int]$Port,
            [int]$TimeoutMs = 120
        )
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $async = $tcp.BeginConnect($ComputerName, $Port, $null, $null)
            if ($async.AsyncWaitHandle.WaitOne($TimeoutMs, $false) -and $tcp.Connected) {
                $tcp.Close()
                return $true
            }
            $tcp.Close()
            return $false
        } catch {
            return $false
        }
    }

    function Enable-LocalTrustedHostsConfig {
        try {
            $wsmanService = Get-Service -Name "WinRM" -ErrorAction SilentlyContinue
            if ($wsmanService -and $wsmanService.Status -ne "Running") {
                Start-Service -Name "WinRM" -ErrorAction SilentlyContinue
            }
            $currentTH = (Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue).Value
            if ($currentTH -ne "*") {
                Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force -ErrorAction SilentlyContinue
            }
        } catch {}
    }

    function Invoke-InstalarRSATLocal {
        cabecera
        menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: 11.3"
        Write-Host "`n--- INSTALACION DE COMPONENTES RSAT LOCALES ---" -ForegroundColor Cyan

        $isAdmin = Test-IsProcessAdmin
        if (-not $isAdmin) {
            Write-Host "`n[ERROR] La instalacion de componentes RSAT requiere privilegios de Administrador (Token Elevado)." -ForegroundColor Red
            Write-Host "Por favor ejecute la consola con 'Ejecutar como Administrador' para realizar esta accion." -ForegroundColor Yellow
            return
        }

        try {
            # Asegurar servicios previos necesarios para Features on Demand
            $preReqServices = @("wuauserv", "bits", "cryptsvc", "TrustedInstaller")
            foreach ($s in $preReqServices) {
                try {
                    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
                    if ($svc) {
                        if ($svc.StartType -eq "Disabled") {
                            Set-Service -Name $s -StartupType Manual -ErrorAction SilentlyContinue
                        }
                        if ($svc.Status -ne "Running") {
                            Start-Service -Name $s -ErrorAction SilentlyContinue
                        }
                    }
                } catch {}
            }

            # Importar explícitamente Dism
            Import-Module -Name Dism -ErrorAction SilentlyContinue

            if (-not (Get-Command -Name Get-WindowsCapability -ErrorAction SilentlyContinue)) {
                throw "El cmdlet 'Get-WindowsCapability' no esta disponible en este equipo."
            }

            Write-Host "Consultando componentes RSAT pendientes de instalacion..." -ForegroundColor Gray
            $capabilities = Get-WindowsCapability -Online -ErrorAction Stop | Where-Object { $_.Name -like "Rsat.*" -and $_.State -eq "NotPresent" }
            if (-not $capabilities -or $capabilities.Count -eq 0) {
                Write-Host "[OK] Todos los componentes de RSAT ya estan instalados en este equipo." -ForegroundColor Green
                return
            }

            Write-Host "Se encontraron $($capabilities.Count) componentes disponibles para instalar." -ForegroundColor Cyan
            
            # Bypass temporal de WSUS si aplica localmente
            $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
            $wsusBypassed = $false
            $originalUseWUServer = $null
            
            if (Test-Path $regPath) {
                $val = Get-ItemProperty -Path $regPath -Name "UseWUServer" -ErrorAction SilentlyContinue
                if ($val -and $val.UseWUServer -eq 1) {
                    Write-Host "Detectado WSUS activo. Desactivando temporalmente para descargar directamente de Windows Update..." -ForegroundColor Yellow
                    $originalUseWUServer = 1
                    Set-ItemProperty -Path $regPath -Name "UseWUServer" -Value 0 -Force -ErrorAction SilentlyContinue
                    Restart-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
                    $wsusBypassed = $true
                }
            }

            try {
                foreach ($cap in $capabilities) {
                    Write-Host "Instalando $($cap.Name)..." -ForegroundColor Yellow
                    try {
                        Add-WindowsCapability -Online -Name $cap.Name -ErrorAction Stop | Out-Null
                        Write-Host "Instalado con exito: $($cap.Name)" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "ERROR al instalar $($cap.Name): $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
            finally {
                # Restaurar configuración original de WSUS
                if ($wsusBypassed -and $originalUseWUServer -ne $null) {
                    Write-Host "Restaurando configuracion original de WSUS..." -ForegroundColor Gray
                    Set-ItemProperty -Path $regPath -Name "UseWUServer" -Value $originalUseWUServer -Force -ErrorAction SilentlyContinue
                    Restart-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
                }
            }
            Write-Host "`n[EXITO] Proceso de instalacion de componentes RSAT completado." -ForegroundColor Green
        }
        catch {
            Write-Host "`nError al instalar componentes RSAT localmente: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    function Invoke-HabilitarServiciosRSATLocal {
        cabecera
        menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: 11.1"
        Write-Host "`n==========================================================================" -ForegroundColor Cyan
        Write-Host "       HABILITACION Y CONFIGURACION DE SERVICIOS RSAT (PC LOCAL)          " -ForegroundColor White -BackgroundColor DarkBlue
        Write-Host "==========================================================================" -ForegroundColor Cyan

        $isAdmin = Test-IsProcessAdmin
        $modoAuditoria = $false

        if (-not $isAdmin) {
            Write-Host "`n[AVISO DE PRIVILEGIOS DE ADMINISTRADOR]" -ForegroundColor Yellow
            Write-Host "El proceso actual se esta ejecutando como USUARIO ESTANDAR (No Elevado)." -ForegroundColor White
            Write-Host "Para iniciar servicios del sistema, configurar el Firewall y WinRM," -ForegroundColor Gray
            Write-Host "se requieren privilegios de Administrador local (Token Elevado)." -ForegroundColor Gray
            Write-Host ""
            Write-Host "  [1] Auto-elevar con UAC (Abrir consola como Administrador)" -ForegroundColor Cyan
            Write-Host "  [2] Proporcionar credenciales de Administrador (Dominio / Local)" -ForegroundColor Cyan
            Write-Host "  [3] Continuar en Modo AUDITORIA / DIAGNOSTICO (Solo Lectura)" -ForegroundColor Gray
            Write-Host "  [0] Cancelar y regresar al menu" -ForegroundColor Yellow
            Write-Host ""

            $opEle = Read-Host "Seleccione una alternativa [3]"
            if ([string]::IsNullOrWhiteSpace($opEle)) { $opEle = "3" }

            switch ($opEle.Trim()) {
                "1" {
                    $scriptFile = if ($env:SCRIPT_PATH -and (Test-Path $env:SCRIPT_PATH)) { 
                        $env:SCRIPT_PATH 
                    } elseif (Test-Path "E:\shellWil\ShellSW.bat") { 
                        "E:\shellWil\ShellSW.bat" 
                    } else { 
                        Join-Path $PSScriptRoot "..\ShellSW.bat" 
                    }

                    Write-Host "`n[*] Solicitando elevacion UAC de Windows..." -ForegroundColor Cyan
                    try {
                        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$scriptFile`"" -Verb RunAs -ErrorAction Stop
                        Write-Host "[OK] Solicitud de elevacion enviada. Se abrira una nueva consola con privilegios." -ForegroundColor Green
                        return
                    } catch {
                        Write-Host "[-] Elevacion cancelada o rechazada: $($_.Exception.Message)" -ForegroundColor Yellow
                        Write-Host "Continuando en Modo Auditoria..." -ForegroundColor Gray
                        $modoAuditoria = $true
                    }
                }
                "2" {
                    Write-Host "`nIngrese credenciales con permisos de Administrador (ej: DOMINIO\Usuario o .\Administrador):" -ForegroundColor Cyan
                    $admCred = Get-Credential
                    if ($admCred) {
                        Write-Host "[*] Credenciales recibidas para $($admCred.UserName)." -ForegroundColor Green
                        Write-Host "[*] Iniciando proceso elevado con credenciales administrativas..." -ForegroundColor Cyan
                        try {
                            $scriptFile = if ($env:SCRIPT_PATH -and (Test-Path $env:SCRIPT_PATH)) { $env:SCRIPT_PATH } else { "E:\shellWil\ShellSW.bat" }
                            Start-Process -FilePath "powershell.exe" -Credential $admCred -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { (Get-Content '$scriptFile') | iex; subMenu25 }`"" -ErrorAction Stop
                            Write-Host "[OK] Proceso iniciado con las credenciales suministradas." -ForegroundColor Green
                            return
                        } catch {
                            Write-Host "[-] No se pudo iniciar el proceso delegado: $($_.Exception.Message)" -ForegroundColor Yellow
                            Write-Host "Continuando en Modo Auditoria..." -ForegroundColor Gray
                            $modoAuditoria = $true
                        }
                    } else {
                        Write-Host "Operacion cancelada por el usuario." -ForegroundColor Yellow
                        return
                    }
                }
                "3" {
                    Write-Host "`n[*] Continuando en Modo Auditoria (Solo Lectura)..." -ForegroundColor Yellow
                    $modoAuditoria = $true
                }
                "0" {
                    Write-Host "Operacion cancelada." -ForegroundColor Yellow
                    return
                }
                default {
                    Write-Host "Opcion no reconocida. Continuando en Modo Auditoria..." -ForegroundColor Yellow
                    $modoAuditoria = $true
                }
            }
        }

        # -------------------------------------------------------------------------
        # FASE 1: DIRECTIVA DE EJECUCION DE SCRIPTS (Manejo inteligente de GPO)
        # -------------------------------------------------------------------------
        Write-Host "`n--- [1/5] DIRECTIVA DE EJECUCION DE SCRIPTS ---" -ForegroundColor Yellow
        try {
            $polList = Get-ExecutionPolicy -List
            $mPol = ($polList | Where-Object { $_.Scope -eq 'MachinePolicy' }).ExecutionPolicy
            $uPol = ($polList | Where-Object { $_.Scope -eq 'UserPolicy' }).ExecutionPolicy
            $hasGpo = ($mPol -ne 'Undefined' -or $uPol -ne 'Undefined')

            if ($hasGpo) {
                $gpoName = if ($mPol -ne 'Undefined') { "MachinePolicy: $mPol" } else { "UserPolicy: $uPol" }
                Write-Host "[INFO] Directiva de Dominio (GPO) detectada activa ($gpoName)." -ForegroundColor Cyan
                Write-Host "[*] Aplicando ambito 'Process' (Bypass) para garantizar ejecucion sin alterar GPO..." -ForegroundColor Gray
                Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
                Write-Host "[OK] Politica temporal 'Bypass' aplicada con exito a este proceso (GPO respetada)." -ForegroundColor Green
            }
            else {
                $effectivePol = Get-ExecutionPolicy
                if ($effectivePol -in @('RemoteSigned', 'Unrestricted', 'Bypass')) {
                    Write-Host "[OK] Directiva efectiva actual ya permite ejecucion de scripts: $effectivePol" -ForegroundColor Green
                }
                else {
                    if ($isAdmin -and -not $modoAuditoria) {
                        try {
                            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -ErrorAction Stop
                            Write-Host "[OK] Directiva establecida a RemoteSigned para LocalMachine." -ForegroundColor Green
                        } catch {
                            try {
                                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
                                Write-Host "[OK] Directiva establecida a RemoteSigned para CurrentUser." -ForegroundColor Green
                            } catch {
                                Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
                                Write-Host "[OK] Directiva establecida a Bypass para el proceso actual." -ForegroundColor Green
                            }
                        }
                    } else {
                        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
                        Write-Host "[OK] Directiva establecida a Bypass para el proceso actual." -ForegroundColor Green
                    }
                }
            }
        } catch {
            Write-Host "[-] Aviso en directiva de ejecucion: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # -------------------------------------------------------------------------
        # FASE 2: SERVICIOS DEL SISTEMA PARA RSAT Y ADMINISTRACION
        # -------------------------------------------------------------------------
        Write-Host "`n--- [2/5] SERVICIOS DEL SISTEMA PARA RSAT ---" -ForegroundColor Yellow
        $rsatServices = @(
            @{ Name = "WinRM"; Display = "Administracion remota de Windows (WinRM)"; DesiredMode = "Automatic"; Required = $true },
            @{ Name = "RemoteRegistry"; Display = "Registro remoto (RemoteRegistry)"; DesiredMode = "Manual"; Required = $false },
            @{ Name = "LanmanWorkstation"; Display = "Estacion de trabajo (LanmanWorkstation / SMB)"; DesiredMode = "Automatic"; Required = $true },
            @{ Name = "LanmanServer"; Display = "Servidor (LanmanServer / Comparticion)"; DesiredMode = "Automatic"; Required = $false },
            @{ Name = "RpcSs"; Display = "Llamada a procedimiento remoto (RPC)"; DesiredMode = "Automatic"; Required = $true },
            @{ Name = "wuauserv"; Display = "Windows Update (Descarga/FOD de componentes RSAT)"; DesiredMode = "Manual"; Required = $false }
        )

        foreach ($s in $rsatServices) {
            $svcName = $s.Name
            $svcDisp = $s.Display
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue

            if (-not $svc) {
                Write-Host "[-] Servicio $svcDisp no encontrado en este sistema." -ForegroundColor DarkYellow
                continue
            }

            $currentStatus = $svc.Status
            $startType = $svc.StartType

            if ($isAdmin -and -not $modoAuditoria) {
                if ($startType -eq "Disabled") {
                    try {
                        Set-Service -Name $svcName -StartupType $s.DesiredMode -ErrorAction SilentlyContinue
                        Write-Host "[*] $($svcName): Modo de inicio cambiado de Disabled a $($s.DesiredMode)." -ForegroundColor Gray
                    } catch {}
                }

                if ($currentStatus -ne "Running" -and ($s.Required -or $svcName -eq "RemoteRegistry")) {
                    try {
                        Write-Host "[*] Iniciando servicio $($svcName)..." -ForegroundColor Gray
                        Start-Service -Name $svcName -ErrorAction Stop
                        $currentStatus = "Running"
                        Write-Host "[OK] $($svcDisp): INICIADO correctamente." -ForegroundColor Green
                    } catch {
                        Write-Host "[-] No se pudo iniciar $($svcName): $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                } else {
                    $color = if ($currentStatus -eq "Running") { "Green" } else { "Gray" }
                    Write-Host "[OK] $($svcDisp): $currentStatus (Inicio: $startType)" -ForegroundColor $color
                }
            } else {
                $color = if ($currentStatus -eq "Running") { "Green" } else { "Yellow" }
                Write-Host "    $($svcDisp): $currentStatus (Inicio: $startType)" -ForegroundColor $color
            }
        }

        # -------------------------------------------------------------------------
        # FASE 3: WINRM (PSREMOTING) Y TRUSTEDHOSTS
        # -------------------------------------------------------------------------
        Write-Host "`n--- [3/5] WINRM (PSREMOTING) Y TRUSTEDHOSTS ---" -ForegroundColor Yellow
        if ($isAdmin -and -not $modoAuditoria) {
            try {
                Write-Host "[*] Verificando y habilitando WinRM (Enable-PSRemoting)..." -ForegroundColor Gray
                Enable-PSRemoting -SkipNetworkProfileCheck -Force -ErrorAction Stop
                Write-Host "[OK] PSRemoting habilitado localmente." -ForegroundColor Green
            } catch {
                Write-Host "[-] Aviso en Enable-PSRemoting: $($_.Exception.Message)" -ForegroundColor Yellow
            }

            try {
                $thVal = (Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue).Value
                if ([string]::IsNullOrWhiteSpace($thVal) -or $thVal -ne "*") {
                    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force -ErrorAction SilentlyContinue
                    Write-Host "[OK] TrustedHosts configurado a '*' (Permite gestion remota en cualquier host)." -ForegroundColor Green
                } else {
                    Write-Host "[OK] TrustedHosts ya configurado a '*'." -ForegroundColor Green
                }
            } catch {
                Write-Host "[-] Aviso al configurar TrustedHosts: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            $thVal = (Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue).Value
            Write-Host "    TrustedHosts actual: $(if ($thVal) { $thVal } else { 'No configurado o restringido' })" -ForegroundColor Gray
        }

        # -------------------------------------------------------------------------
        # FASE 4: REGLAS DE FIREWALL PARA ADMINISTRACION
        # -------------------------------------------------------------------------
        Write-Host "`n--- [4/5] REGLAS DE FIREWALL DE WINDOWS ---" -ForegroundColor Yellow
        if ($isAdmin -and -not $modoAuditoria) {
            $fwGroups = @(
                "Windows Remote Management",
                "Administracion remota de Windows",
                "Windows Management Instrumentation (WMI)",
                "Instrumentacion de administracion de Windows (WMI)",
                "File and Printer Sharing",
                "Compartir archivos e impresoras"
            )
            foreach ($grp in $fwGroups) {
                try {
                    netsh advfirewall firewall set rule group="$grp" new enable=yes 2>$null | Out-Null
                } catch {}
            }
            Write-Host "[OK] Reglas de Firewall habilitadas para WinRM, WMI y Comparticion de archivos." -ForegroundColor Green
        } else {
            Write-Host "[*] Modo diagnostico: No se modificaron reglas de firewall (requiere permisos de administrador)." -ForegroundColor Gray
        }

        # -------------------------------------------------------------------------
        # FASE 5: AUDITORIA DE COMPONENTES Y MODULOS RSAT LOCALES
        # -------------------------------------------------------------------------
        Write-Host "`n--- [5/5] AUDITORIA DE HERRAMIENTAS RSAT EN ESTA PC ---" -ForegroundColor Yellow

        $rsatModulos = @(
            @{ Modulo = "ActiveDirectory"; Desc = "Active Directory (Usuarios, Equipos, PowerShell)"; MSC = "dsa.msc" },
            @{ Modulo = "DnsServer"; Desc = "Herramientas de Servidor DNS"; MSC = "dnsmgmt.msc" },
            @{ Modulo = "DhcpServer"; Desc = "Herramientas de Servidor DHCP"; MSC = "dhcpmgmt.msc" },
            @{ Modulo = "GroupPolicy"; Desc = "Administracion de Directivas de Grupo (GPMC)"; MSC = "gpmc.msc" },
            @{ Modulo = "ServerManager"; Desc = "Administrador del Servidor (Server Manager)"; MSC = "ServerManager.exe" }
        )

        $hayFaltantes = $false
        Write-Host ("{0,-20} {1,-14} {2,-35}" -f "COMPONENTE", "ESTADO", "DESCRIPCION") -ForegroundColor DarkGray
        Write-Host ("{0,-20} {1,-14} {2,-35}" -f "----------", "------", "-----------") -ForegroundColor DarkGray

        foreach ($rm in $rsatModulos) {
            $modAvailable = [bool](Get-Module -ListAvailable -Name $rm.Modulo -ErrorAction SilentlyContinue)
            $mscAvailable = Test-Path "$env:SystemRoot\System32\$($rm.MSC)"
            $instalado = ($modAvailable -or $mscAvailable)

            if ($instalado) {
                Write-Host ("{0,-20} " -f $rm.Modulo) -NoNewline
                Write-Host "[INSTALADO]   " -ForegroundColor Green -NoNewline
                Write-Host $rm.Desc -ForegroundColor Gray
            } else {
                $hayFaltantes = $true
                Write-Host ("{0,-20} " -f $rm.Modulo) -NoNewline
                Write-Host "[NO PRESENTE] " -ForegroundColor Yellow -NoNewline
                Write-Host $rm.Desc -ForegroundColor Gray
            }
        }

        Write-Host "`n--------------------------------------------------------------------------" -ForegroundColor Cyan
        if ($hayFaltantes) {
            Write-Host "[AVISO] Se detectaron herramientas RSAT pendientes de instalacion en esta PC." -ForegroundColor Yellow
            Write-Host "Puede instalarlas utilizando la opcion 11.3 de este mismo submenu." -ForegroundColor Cyan
            $instDirecta = Read-Host "¿Desea iniciar la instalacion de los componentes RSAT ahora? (S/N) [N]"
            if ($instDirecta -and $instDirecta.Trim().ToUpper() -eq "S") {
                if (-not $isAdmin) {
                    Write-Host "[-] La instalacion de RSAT requiere privilegios de Administrador. Ejecute la opcion como Administrador." -ForegroundColor Red
                } else {
                    Write-Host "`n[*] Redirigiendo a la instalacion de componentes RSAT (Opcion 11.3)..." -ForegroundColor Cyan
                    Invoke-InstalarRSATLocal
                }
            }
        } else {
            Write-Host "[TODO OK] Todos los componentes RSAT principales y servicios se encuentran activos." -ForegroundColor Green
        }
        Write-Host "==========================================================================" -ForegroundColor Cyan
    }

    function Invoke-HabilitarServiciosRSATRemoto {
        cabecera
        menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: 12.1"
        Write-Host "`n==========================================================================" -ForegroundColor Cyan
        Write-Host "       HABILITACION Y CONFIGURACION DE SERVICIOS RSAT (PC REMOTA)         " -ForegroundColor White -BackgroundColor DarkBlue
        Write-Host "==========================================================================" -ForegroundColor Cyan

        $targetInput = Get-StandardIPPrompt -Mensaje "Ingrese la IP completa (ej: 192.168.176.50) o los 2 ultimos octetos"
        if ([string]::IsNullOrWhiteSpace($targetInput)) {
            Write-Host "Operacion cancelada." -ForegroundColor Red
            return
        }

        # 1. Resolver Hostname y evaluar conectividad
        $targetMachine = $targetInput
        $ipRemota = $targetInput
        Write-Host "`n[*] Verificando enlace de red con $targetInput (Ping)..." -ForegroundColor Yellow
        $pingOk = Test-Connection -ComputerName $targetInput -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($pingOk) {
            Write-Host "[+] Ping respondido por $targetInput." -ForegroundColor Green
        } else {
            Write-Host "[-] El equipo no responde a Ping (posible firewall o equipo apagado)." -ForegroundColor Yellow
        }

        try {
            $dns = [System.Net.Dns]::GetHostEntry($targetInput)
            if ($dns -and $dns.HostName) {
                $targetMachine = $dns.HostName.Split('.')[0]
                Write-Host "[+] Hostname resuelto via DNS: $targetMachine" -ForegroundColor Green
            }
        } catch {
            try {
                $nbt = nbtstat -a $targetInput
                $linea = $nbt | Where-Object { $_ -match "<\x00>.*UNIQUE" } | Select-Object -First 1
                if ($linea -and $linea -match "^\s*([A-Za-z0-9\-]+)") {
                    $targetMachine = $Matches[1].Trim()
                    Write-Host "[+] Hostname resuelto via NetBIOS: $targetMachine" -ForegroundColor Green
                }
            } catch {}
        }

        # 2. Selección de Credenciales Administrativas
        Write-Host "`n--- AUTENTICACION ADMINISTRATIVA REMOTA ---" -ForegroundColor Yellow
        Write-Host " [1] Usuario actual de Windows (Inicio de sesion unico / Integrado)"
        Write-Host " [2] Usuario de Dominio (ej: DOMINIO\Usuario)"
        Write-Host " [3] Usuario Local de la PC Remota (ej: .\Administrador)"
        $authOpt = Read-Host "Seleccione una opcion [1-3] (Por defecto: 1)"
        if ([string]::IsNullOrWhiteSpace($authOpt)) { $authOpt = "1" }

        $cred = $null
        $usu = ""
        $claTexto = ""
        if ($authOpt -eq "2") {
            $domDefecto = $env:USERDOMAIN
            $dom = Read-Host "Ingrese Dominio [Presione Enter para '$domDefecto']"
            if ([string]::IsNullOrWhiteSpace($dom)) { $dom = $domDefecto }
            $uName = Read-Host "Ingrese nombre de usuario de Dominio"
            if (-not [string]::IsNullOrWhiteSpace($uName)) {
                $usu = "$dom\$uName"
                $cla = Read-Host "Ingrese contrasena" -AsSecureString
                $cred = New-Object System.Management.Automation.PSCredential ($usu, $cla)
                $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))
            }
        } elseif ($authOpt -eq "3") {
            $uName = Read-Host "Ingrese nombre de usuario local (ej: Administrador)"
            if (-not [string]::IsNullOrWhiteSpace($uName)) {
                $usu = if ($uName -match "\\|\@") { $uName } else { ".\$uName" }
                $cla = Read-Host "Ingrese contrasena local" -AsSecureString
                $cred = New-Object System.Management.Automation.PSCredential ($usu, $cla)
                $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))
            }
        }

        # 3. Comprobación de puertos de administración
        $port445 = $false
        $port5985 = $false
        try {
            $tSMB = New-Object System.Net.Sockets.TcpClient
            $cSMB = $tSMB.BeginConnect($targetMachine, 445, $null, $null)
            if ($cSMB.AsyncWaitHandle.WaitOne(1000, $false)) { $tSMB.EndConnect($cSMB); $port445 = $true }
            $tSMB.Close()
        } catch {}
        try {
            $tRM = New-Object System.Net.Sockets.TcpClient
            $cRM = $tRM.BeginConnect($targetMachine, 5985, $null, $null)
            if ($cRM.AsyncWaitHandle.WaitOne(1000, $false)) { $tRM.EndConnect($cRM); $port5985 = $true }
            $tRM.Close()
        } catch {}

        Write-Host "  Puerto 445 (SMB)   : $(if ($port445) { '[ABIERTO]' } else { '[CERRADO]' })" -ForegroundColor $(if ($port445) { 'Green' } else { 'Yellow' })
        Write-Host "  Puerto 5985 (WinRM): $(if ($port5985) { '[ABIERTO]' } else { '[CERRADO]' })" -ForegroundColor $(if ($port5985) { 'Green' } else { 'Yellow' })

        # 4. Script de configuración integral en la PC Remota
        $setupRemoteScript = @'
try {
    # A. Habilitar WinRM y PSRemoting
    try {
        Enable-PSRemoting -SkipNetworkProfileCheck -Force -ErrorAction SilentlyContinue
    } catch {}

    # B. Configurar servicios requeridos para RSAT
    $svcs = @(
        @{ Name = "WinRM"; Mode = "Automatic" },
        @{ Name = "RemoteRegistry"; Mode = "Manual" },
        @{ Name = "wuauserv"; Mode = "Manual" },
        @{ Name = "bits"; Mode = "Manual" },
        @{ Name = "cryptsvc"; Mode = "Automatic" },
        @{ Name = "TrustedInstaller"; Mode = "Manual" },
        @{ Name = "LanmanWorkstation"; Mode = "Automatic" },
        @{ Name = "LanmanServer"; Mode = "Automatic" },
        @{ Name = "RpcSs"; Mode = "Automatic" }
    )
    foreach ($item in $svcs) {
        $n = $item.Name
        try {
            $svc = Get-Service -Name $n -ErrorAction SilentlyContinue
            if ($svc) {
                if ($svc.StartType -eq "Disabled") {
                    Set-Service -Name $n -StartupType $item.Mode -ErrorAction SilentlyContinue
                }
                if ($svc.Status -ne "Running" -and $n -in @("WinRM","RemoteRegistry","wuauserv","bits","cryptsvc","LanmanWorkstation","LanmanServer","RpcSs")) {
                    Start-Service -Name $n -ErrorAction SilentlyContinue
                }
            }
        } catch {}
    }

    # C. Reglas de Firewall
    $groups = @(
        "Windows Remote Management",
        "Administracion remota de Windows",
        "Windows Management Instrumentation (WMI)",
        "Instrumentacion de administracion de Windows (WMI)",
        "File and Printer Sharing",
        "Compartir archivos e impresoras",
        "Remote Administration",
        "Administracion remota"
    )
    foreach ($g in $groups) {
        netsh advfirewall firewall set rule group="$g" new enable=yes 2>$null | Out-Null
    }

    # D. Directiva de Servicing para Windows Update (Bypass WSUS para FOD)
    $servReg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing"
    if (-not (Test-Path $servReg)) { New-Item -Path $servReg -Force | Out-Null }
    Set-ItemProperty -Path $servReg -Name "RepairContentServerSource" -Value 2 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $servReg -Name "UseWindowsUpdate" -Value 1 -Force -ErrorAction SilentlyContinue

    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f 2>$null | Out-Null

    # E. ExecutionPolicy
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -ErrorAction SilentlyContinue
    } catch {}

    return "OK"
} catch {
    return $_.Exception.Message
}
'@

        Write-Host "`n[*] Aplicando configuracion de servicios RSAT en $targetMachine..." -ForegroundColor Cyan
        $metodoExitoso = ""

        # Método A: WinRM
        if ($port5985) {
            try {
                Write-Host "[*] Intentando configuracion via WinRM..." -ForegroundColor Gray
                $sb = [ScriptBlock]::Create($setupRemoteScript)
                $res = if ($cred) {
                    Invoke-Command -ComputerName $targetMachine -Credential $cred -ScriptBlock $sb -ErrorAction Stop
                } else {
                    Invoke-Command -ComputerName $targetMachine -ScriptBlock $sb -ErrorAction Stop
                }
                if ($res -eq "OK") { $metodoExitoso = "WinRM" }
            } catch {
                Write-Host "[-] WinRM aviso: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        # Método B: WMI
        if (-not $metodoExitoso) {
            try {
                Write-Host "[*] Intentando configuracion via WMI..." -ForegroundColor Gray
                $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($setupRemoteScript))
                $cmdLine = "powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
                $procClass = if ($cred) {
                    Get-WmiObject -List -ComputerName $targetMachine -Credential $cred -Class Win32_Process -ErrorAction Stop
                } else {
                    Get-WmiObject -List -ComputerName $targetMachine -Class Win32_Process -ErrorAction Stop
                }
                if ($procClass) {
                    $r = $procClass.Create($cmdLine)
                    if ($r.ReturnValue -eq 0) {
                        $metodoExitoso = "WMI"
                        Write-Host "[OK] Proceso iniciado via WMI. Esperando 5 segundos..." -ForegroundColor Green
                        Start-Sleep -Seconds 5
                    }
                }
            } catch {
                Write-Host "[-] WMI aviso: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        # Método C: PsExec
        if (-not $metodoExitoso -and $port445) {
            $psexecPath = "C:\PSTools\PsExec.exe"
            if (-not (Test-Path $psexecPath)) {
                $where = Get-Command psexec -ErrorAction SilentlyContinue
                if ($where) { $psexecPath = $where.Definition }
            }
            if (Test-Path $psexecPath) {
                Write-Host "[*] Intentando configuracion via PsExec..." -ForegroundColor Gray
                $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($setupRemoteScript))
                $argBase = "-accepteula -s -h powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
                $argExec = if ($usu -ne "") { "\\$targetMachine -u `"$usu`" -p `"$claTexto`" $argBase" } else { "\\$targetMachine $argBase" }
                $p = Start-Process -FilePath $psexecPath -ArgumentList $argExec -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
                if ($p -and $p.ExitCode -eq 0) {
                    $metodoExitoso = "PsExec"
                }
            }
        }

        Write-Host "`n--------------------------------------------------------------------------" -ForegroundColor Cyan
        if ($metodoExitoso) {
            Write-Host "[EXITO] Servicios y entorno RSAT habilitados en $targetMachine (Via $metodoExitoso)." -ForegroundColor Green
            Write-Host "  * WinRM y PSRemoting activos" -ForegroundColor Gray
            Write-Host "  * Servicios Windows Update, BITS, CryptSvc y TrustedInstaller configurados" -ForegroundColor Gray
            Write-Host "  * Reglas de Firewall habilitadas para administracion" -ForegroundColor Gray
            Write-Host "  * Directiva Servicing configurada para descarga directa de FOD" -ForegroundColor Gray
            Write-Host "`nEl equipo $targetMachine se encuentra PREPARADO para la instalacion (Opcion 12.3)." -ForegroundColor Green
        } else {
            Write-Host "[ERROR] No se pudo completar la habilitacion en $targetMachine." -ForegroundColor Red
            Write-Host "Verifique conectividad, puertos de firewall y credenciales de administrador." -ForegroundColor Yellow
        }
        Write-Host "==========================================================================" -ForegroundColor Cyan
        Write-Host " "
        Read-Host "Presione ENTER para continuar..."
    }

    function Invoke-InstalarRSATRemoto {
        cabecera
        menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: 12.3"
        Write-Host "`n==========================================================================" -ForegroundColor Cyan
        Write-Host "        INSTALACION DE COMPONENTES RSAT EN PC REMOTA                      " -ForegroundColor White -BackgroundColor DarkBlue
        Write-Host "==========================================================================" -ForegroundColor Cyan

        $targetInput = Get-StandardIPPrompt -Mensaje "Ingrese la IP completa (ej: 192.168.176.131) o Nombre de Equipo"
        if ([string]::IsNullOrWhiteSpace($targetInput)) {
            Write-Host "Operacion cancelada." -ForegroundColor Red
            return
        }

        # 1. Enlace y Resolucion Canonica de Nombre de Equipo (WMI -> DNS -> NetBIOS)
        $targetMachine = $targetInput.Trim()
        $ipRemota = $targetInput.Trim()
        Write-Host "`n[*] Verificando enlace de red con $targetInput (Ping)..." -ForegroundColor Yellow
        $pingOk = Test-Connection -ComputerName $targetInput -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($pingOk) {
            Write-Host "[+] Ping respondido por $targetInput." -ForegroundColor Green
        } else {
            Write-Host "[-] El equipo no responde a Ping (posible cortafuegos o equipo apagado)." -ForegroundColor Yellow
        }

        Write-Host "[*] Resolviendo identidad y CSName de $targetInput..." -ForegroundColor Gray
        try {
            $sys = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $targetInput -ErrorAction Stop
            if ($sys -and $sys.CSName) {
                $targetMachine = $sys.CSName.Trim()
                Write-Host "[+] Nombre canonico resuelto via WMI: $targetMachine" -ForegroundColor Green
            }
        } catch {
            try {
                $dns = [System.Net.Dns]::GetHostEntry($targetInput)
                if ($dns -and $dns.HostName) {
                    $targetMachine = $dns.HostName.Split('.')[0]
                    Write-Host "[+] Hostname resuelto via DNS: $targetMachine" -ForegroundColor Green
                }
            } catch {
                try {
                    $nbt = nbtstat -a $targetInput
                    $linea = $nbt | Where-Object { $_ -match "<\x00>.*UNIQUE" } | Select-Object -First 1
                    if ($linea -and $linea -match "^\s*([A-Za-z0-9\-]+)") {
                        $targetMachine = $Matches[1].Trim()
                        Write-Host "[+] Hostname resuelto via NetBIOS: $targetMachine" -ForegroundColor Green
                    }
                } catch {}
            }
        }

        # 2. Diagnostico de Puertos
        $port445 = $false
        $port5985 = $false
        try {
            $tSMB = New-Object System.Net.Sockets.TcpClient
            $cSMB = $tSMB.BeginConnect($targetMachine, 445, $null, $null)
            if ($cSMB.AsyncWaitHandle.WaitOne(1000, $false)) { $tSMB.EndConnect($cSMB); $port445 = $true }
            $tSMB.Close()
        } catch {}
        try {
            $tRM = New-Object System.Net.Sockets.TcpClient
            $cRM = $tRM.BeginConnect($targetMachine, 5985, $null, $null)
            if ($cRM.AsyncWaitHandle.WaitOne(1000, $false)) { $tRM.EndConnect($cRM); $port5985 = $true }
            $tRM.Close()
        } catch {}

        Write-Host "  Puerto 445 (SMB)   : $(if ($port445) { '[ABIERTO]' } else { '[CERRADO]' })" -ForegroundColor $(if ($port445) { 'Green' } else { 'Yellow' })
        Write-Host "  Puerto 5985 (WinRM): $(if ($port5985) { '[ABIERTO]' } else { '[CERRADO]' })" -ForegroundColor $(if ($port5985) { 'Green' } else { 'Yellow' })

        # 3. Autenticacion
        Write-Host "`n--- OPCIONES DE AUTENTICACION ---" -ForegroundColor Yellow
        Write-Host " [1] Usuario actual de Windows (Inicio de sesion unico / Integrado)"
        Write-Host " [2] Usuario de Dominio (ej: DOMINIO\Usuario)"
        Write-Host " [3] Usuario Local de la PC Remota (ej: .\Administrador)"
        $authOpt = Read-Host "Seleccione una opcion [1-3] (Por defecto: 1)"
        if ([string]::IsNullOrWhiteSpace($authOpt)) { $authOpt = "1" }

        $cred = $null
        $usu = ""
        $claTexto = ""
        if ($authOpt -eq "2") {
            $domDefecto = $env:USERDOMAIN
            $dom = Read-Host "Ingrese Dominio [Presione Enter para '$domDefecto']"
            if ([string]::IsNullOrWhiteSpace($dom)) { $dom = $domDefecto }
            $uName = Read-Host "Ingrese usuario de Dominio"
            if (-not [string]::IsNullOrWhiteSpace($uName)) {
                $usu = "$dom\$uName"
                $cla = Read-Host "Ingrese contrasena" -AsSecureString
                $cred = New-Object System.Management.Automation.PSCredential ($usu, $cla)
                $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))
            }
        } elseif ($authOpt -eq "3") {
            $uName = Read-Host "Ingrese Administrador Local (ej: Administrador)"
            if (-not [string]::IsNullOrWhiteSpace($uName)) {
                $usu = if ($uName -match "\\|\@") { $uName } else { ".\$uName" }
                $cla = Read-Host "Ingrese contrasena local" -AsSecureString
                $cred = New-Object System.Management.Automation.PSCredential ($usu, $cla)
                $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))
            }
        }

        # Conectar sesion de red administrativa IPC$ localmente si hay credenciales explicitas
        if ($usu -ne "" -and $claTexto -ne "") {
            cmd.exe /c "net use \\$targetMachine\IPC$ /user:`"$usu`" `"$claTexto`"" 2>&1 | Out-Null
        }

        # 4. FASE DE AUDITORIA PREVIA EN VIVO (Verificar que tiene descargado/instalado)
        Write-Host "`n[*] Consultando catalogo e inventario de herramientas RSAT en $targetMachine..." -ForegroundColor Cyan
        $remoteCaps = $null
        if ($port5985) {
            try {
                $sbAudit = {
                    Get-WindowsCapability -Online -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "Rsat.*" } | Select-Object Name, State
                }
                if ($cred -ne $null) {
                    $remoteCaps = Invoke-Command -ComputerName $targetMachine -Credential $cred -ScriptBlock $sbAudit -ErrorAction Stop
                } else {
                    $remoteCaps = Invoke-Command -ComputerName $targetMachine -ScriptBlock $sbAudit -ErrorAction Stop
                }
            } catch {
                Write-Host "[-] Aviso en consulta WinRM: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        $rsatCatalog = @(
            @{ Key = "Rsat.ActiveDirectory.DS-LDS.Tools"; Display = "Herramientas de Active Directory DS y LDS (ADUC)" },
            @{ Key = "Rsat.Dns.Tools"; Display = "Herramientas del Servidor DNS" },
            @{ Key = "Rsat.DHCP.Tools"; Display = "Herramientas de Administracion de DHCP" },
            @{ Key = "Rsat.GroupPolicy.Management.Tools"; Display = "Consola de Administracion de Directivas de Grupo (GPMC)" },
            @{ Key = "Rsat.ServerManager.Tools"; Display = "Consola Administrador del Servidor (Server Manager)" },
            @{ Key = "Rsat.FileServices.Tools"; Display = "Herramientas de Servicios de Archivos y Almacenamiento" },
            @{ Key = "Rsat.CertificateServices.Tools"; Display = "Herramientas de Servicios de Certificados (AD CS)" },
            @{ Key = "Rsat.BitLocker.Recovery.Tools"; Display = "Visor de Recuperacion de Contrasenas de BitLocker" },
            @{ Key = "Rsat.FailoverCluster.Management.Tools"; Display = "Administrador de Clustered de Conmutacion por Error" },
            @{ Key = "Rsat.RemoteAccess.Management.Tools"; Display = "Herramientas de Administracion de Acceso Remoto" },
            @{ Key = "Rsat.RemoteDesktop.Services.Tools"; Display = "Herramientas de Servicios de Escritorio Remoto (RDS)" },
            @{ Key = "Rsat.VolumeActivation.Tools"; Display = "Herramientas de Activacion por Volumen" },
            @{ Key = "Rsat.WSUS.Tools"; Display = "Herramientas de Windows Server Update Services (WSUS)" },
            @{ Key = "Rsat.IPAM.Client.Tools"; Display = "Cliente de Administracion de Direcciones IP (IPAM)" },
            @{ Key = "Rsat.StorageReplica.Tools"; Display = "Modulo de Replica de Almacenamiento" },
            @{ Key = "Rsat.Shielded.VM.Tools"; Display = "Herramientas para Maquinas Virtuales Blindadas" }
        )

        $installedCount = 0
        $pendingCount = 0
        $pendingCapsList = @()

        if ($remoteCaps) {
            Write-Host "`n==========================================================================" -ForegroundColor Cyan
            Write-Host "       ESTADO ACTUAL DE COMPONENTES RSAT EN: $targetMachine               " -ForegroundColor White -BackgroundColor DarkBlue
            Write-Host "==========================================================================" -ForegroundColor Cyan
            foreach ($item in $rsatCatalog) {
                $capObj = $remoteCaps | Where-Object { $_.Name -like "$($item.Key)*" } | Select-Object -First 1
                $dispName = $item.Display.PadRight(58)
                if ($capObj -and ($capObj.State -eq "Installed" -or $capObj.State -eq 4 -or "$($capObj.State)" -match "Installed|4")) {
                    $installedCount++
                    Write-Host " [OK] $dispName : " -NoNewline -ForegroundColor Gray
                    Write-Host "INSTALADO" -ForegroundColor Green
                } else {
                    $pendingCount++
                    $capFullName = if ($capObj) { $capObj.Name } else { "$($item.Key)~~~~0.0.1.0" }
                    $pendingCapsList += $capFullName
                    Write-Host " [!]  $dispName : " -NoNewline -ForegroundColor Gray
                    Write-Host "NO INSTALADO" -ForegroundColor Yellow
                }
            }
            Write-Host "--------------------------------------------------------------------------" -ForegroundColor Cyan
            Write-Host "  Resumen: $installedCount instaladas | $pendingCount pendientes (Total catalogo: $($remoteCaps.Count))" -ForegroundColor White
            Write-Host "==========================================================================" -ForegroundColor Cyan

            if ($pendingCount -eq 0) {
                Write-Host "`n[TODO OK] ¡Todos los componentes de RSAT ya se encuentran instalados en $targetMachine!" -ForegroundColor Green
                Write-Host "El equipo remoto ya cuenta con el paquete completo de herramientas administrativas." -ForegroundColor Gray
                Write-Host "`nOpciones disponibles:" -ForegroundColor Yellow
                Write-Host " [1] Volver al menu principal (Recomendado - No requiere ninguna instalacion)" -ForegroundColor Cyan
                Write-Host " [2] Forzar reinstalacion / reparacion de componentes RSAT" -ForegroundColor White
                $optYaInst = Read-Host "Seleccione una opcion [1-2] (Por defecto: 1)"
                if ([string]::IsNullOrWhiteSpace($optYaInst) -or $optYaInst.Trim() -eq "1") {
                    Write-Host "`nOperacion finalizada. Regresando al menu principal..." -ForegroundColor Green
                    Write-Host " "
                    Read-Host "Presione ENTER para continuar..."
                    return
                }
            }
        } else {
            Write-Host "[!] No se pudo obtener el inventario previo en vivo via WinRM. Se continuara con el asistente." -ForegroundColor Yellow
        }

        # 5. Seleccion de Componentes a Instalar
        Write-Host "`n--- SELECCION DE COMPONENTES RSAT A INSTALAR ---" -ForegroundColor Yellow
        if ($pendingCount -gt 0) {
            Write-Host " [1] Instalar unicamente los $pendingCount componentes PENDIENTES detectados [Recomendado]" -ForegroundColor Cyan
        } else {
            Write-Host " [1] Paquete Esencial (Active Directory DS/LDS, DNS, DHCP, GPMC) [Recomendado - Rapido]" -ForegroundColor Cyan
        }
        Write-Host " [2] Paquete Esencial de Administracion (AD, DNS, DHCP, GPMC)" -ForegroundColor White
        Write-Host " [3] Todos los componentes RSAT disponibles (~21)" -ForegroundColor White
        Write-Host " [4] Personalizado (Ingresar patron, ej: Rsat.ActiveDirectory* o Rsat.Dns*)" -ForegroundColor White
        $compOpt = Read-Host "Seleccione una opcion [1-4] (Por defecto: 1)"
        if ([string]::IsNullOrWhiteSpace($compOpt)) { $compOpt = "1" }

        $targetPatterns = @()
        $criterioLabel = ""
        if ($compOpt -eq "1" -and $pendingCount -gt 0) {
            $targetPatterns = $pendingCapsList
            $criterioLabel = "Componentes Pendientes ($pendingCount)"
        } elseif ($compOpt -eq "3") {
            $targetPatterns = @("Rsat.*")
            $criterioLabel = "Todos los componentes RSAT"
        } elseif ($compOpt -eq "4") {
            $customPat = Read-Host "Ingrese el patron a buscar (ej: Rsat.ActiveDirectory*)"
            $targetPatterns = if ([string]::IsNullOrWhiteSpace($customPat)) { @("Rsat.*") } else { @($customPat.Trim()) }
            $criterioLabel = "Personalizado ($($targetPatterns -join ', '))"
        } else {
            $targetPatterns = @(
                "Rsat.ActiveDirectory.DS-LDS.Tools*",
                "Rsat.Dns.Tools*",
                "Rsat.DHCP.Tools*",
                "Rsat.GroupPolicy.Management.Tools*"
            )
            $criterioLabel = "Paquete Esencial de Administracion"
        }
        Write-Host "[*] Criterio de instalacion: $criterioLabel" -ForegroundColor Cyan

        # 6. Seleccion del Origen de Instalacion (Internet / Archivos Locales / Red)
        Write-Host "`n--- ORIGEN DE ARCHIVOS DE INSTALACION (FOD / RSAT) ---" -ForegroundColor Yellow
        Write-Host " [1] Microsoft Update por Internet (Descarga directa automatica) [Por defecto]" -ForegroundColor Cyan
        Write-Host " [2] Carpeta local en la PC remota (ej: C:\FOD o C:\Instaladores\RSAT)" -ForegroundColor White
        Write-Host " [3] Carpeta compartida en la red UNC (ej: \\SERVIDOR\Software\RSAT_FOD)" -ForegroundColor White
        Write-Host " [4] Copiar paquetes FOD desde esta PC hacia la PC remota" -ForegroundColor White
        $origOpt = Read-Host "Seleccione origen [1-4] (Por defecto: 1)"
        if ([string]::IsNullOrWhiteSpace($origOpt)) { $origOpt = "1" }

        $sourcePath = ""
        if ($origOpt -eq "2") {
            $pLocal = Read-Host "Ingrese la ruta de la carpeta FOD en la PC remota (ej: C:\FOD)"
            $sourcePath = if ([string]::IsNullOrWhiteSpace($pLocal)) { "" } else { $pLocal.Trim() }
        } elseif ($origOpt -eq "3") {
            $pUNC = Read-Host "Ingrese la ruta UNC compartida de red (ej: \\SERVIDOR\Share\FOD)"
            $sourcePath = if ([string]::IsNullOrWhiteSpace($pUNC)) { "" } else { $pUNC.Trim() }
        } elseif ($origOpt -eq "4") {
            $pMyPC = Read-Host "Ingrese la ruta de la carpeta FOD en ESTA PC local (ej: D:\FOD)"
            if (Test-Path $pMyPC) {
                $destRemote = "\\$targetMachine\C$\Windows\Temp\FOD"
                Write-Host "[*] Copiando archivos FOD desde $pMyPC hacia $destRemote..." -ForegroundColor Cyan
                if (-not (Test-Path $destRemote)) { New-Item -Path $destRemote -ItemType Directory -Force | Out-Null }
                Copy-Item -Path "$pMyPC\*" -Destination $destRemote -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "[+] Archivos FOD transferidos con exito a la PC remota." -ForegroundColor Green
                $sourcePath = "C:\Windows\Temp\FOD"
            } else {
                Write-Host "[-] Ruta local $pMyPC no encontrada. Se continuara con Microsoft Update." -ForegroundColor Yellow
            }
        }

        # 7. Worker Script Remoto (Contexto SYSTEM)
        $workerBody = @'
$logFile = "C:\Windows\Temp\Install-RSAT.log"
$statFile = "C:\Windows\Temp\Install-RSAT.status"

function Write-WorkerLog {
    param([string]$msg, [string]$type = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$type] $msg"
    Add-Content -Path $logFile -Value $line -Encoding UTF8 -Force -ErrorAction SilentlyContinue
}

try {
    "IN_PROGRESS|0|0" | Out-File -FilePath $statFile -Encoding UTF8 -Force
    Write-WorkerLog ("Iniciando instalacion remota de RSAT en contexto SYSTEM (" + $env:USERNAME + ")...") "INFO"

    # A. Verificacion y configuracion de servicios criticos
    $services = @("wuauserv", "bits", "cryptsvc", "TrustedInstaller")
    foreach ($s in $services) {
        try {
            $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
            if ($svc) {
                if ($svc.StartType -eq "Disabled") {
                    Set-Service -Name $s -StartupType Manual -ErrorAction SilentlyContinue
                    Write-WorkerLog ("Servicio " + $s + " cambiado de Disabled a Manual.") "INFO"
                }
                if ($svc.Status -ne "Running") {
                    Start-Service -Name $s -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                    Write-WorkerLog ("Servicio " + $s + " iniciado.") "INFO"
                } else {
                    Write-WorkerLog ("Servicio " + $s + " verificado y activo.") "INFO"
                }
            }
        } catch {
            Write-WorkerLog ("Aviso en servicio " + $s + ": " + $_.Exception.Message) "WARN"
        }
    }

    # B. Bypass de WSUS y directiva Servicing (Descarga directa desde Microsoft Update)
    $wsusReg = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    $servicingReg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing"
    $origUseWUServer = $null
    $origRepairSource = $null
    $wsusModified = $false
    $servicingModified = $false

    if ([string]::IsNullOrEmpty($offlineSource)) {
        try {
            if (Test-Path $wsusReg) {
                $p = Get-ItemProperty -Path $wsusReg -Name "UseWUServer" -ErrorAction SilentlyContinue
                if ($p -and $p.UseWUServer -eq 1) {
                    $origUseWUServer = 1
                    Set-ItemProperty -Path $wsusReg -Name "UseWUServer" -Value 0 -Force -ErrorAction SilentlyContinue
                    $wsusModified = $true
                    Write-WorkerLog "Bypass WSUS: UseWUServer establecido a 0 temporalmente." "INFO"
                }
            }

            if (-not (Test-Path $servicingReg)) {
                New-Item -Path $servicingReg -Force | Out-Null
            }
            $pServ = Get-ItemProperty -Path $servicingReg -Name "RepairContentServerSource" -ErrorAction SilentlyContinue
            if ($pServ) {
                $origRepairSource = $pServ.RepairContentServerSource
            }
            Set-ItemProperty -Path $servicingReg -Name "RepairContentServerSource" -Value 2 -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $servicingReg -Name "UseWindowsUpdate" -Value 1 -Force -ErrorAction SilentlyContinue
            $servicingModified = $true
            Write-WorkerLog "Directiva Servicing configurada para descarga directa de Windows Update." "INFO"

            Stop-Service -Name "wuauserv" -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Start-Service -Name "wuauserv" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            Write-WorkerLog "Servicio Windows Update reiniciado correctamente." "INFO"
        } catch {
            Write-WorkerLog ("Aviso en directivas de Windows Update: " + $_.Exception.Message) "WARN"
        }
    } else {
        Write-WorkerLog ("Utilizando repositorio de archivos FOD local/red: " + $offlineSource) "INFO"
    }

    # C. Escaneo de Componentes RSAT a instalar
    Import-Module Dism -ErrorAction SilentlyContinue
    Write-WorkerLog "Consultando catalogo de capacidades DISM en Windows..." "INFO"
    $allCaps = Get-WindowsCapability -Online -ErrorAction Stop | Where-Object { $_.Name -like "Rsat.*" }
    
    $toInstall = @()
    foreach ($cap in $allCaps) {
        if ($cap.State -ne "Installed") {
            foreach ($pat in $targetPatterns) {
                if ($cap.Name -like $pat) {
                    $toInstall += $cap
                    break
                }
            }
        }
    }

    $successCount = 0
    $failCount = 0

    if ($toInstall.Count -eq 0) {
        Write-WorkerLog "Todos los componentes solicitados ya se encuentran instalados en el equipo." "INFO"
        "COMPLETED_NOTHING_TODO" | Out-File -FilePath $statFile -Encoding UTF8 -Force
    }
    else {
        Write-WorkerLog ("Se encontraron " + $toInstall.Count + " componentes para instalar.") "INFO"
        $idx = 0
        foreach ($cap in $toInstall) {
            $idx++
            ("INSTALLING:" + $cap.Name + "|" + $idx + "|" + $toInstall.Count) | Out-File -FilePath $statFile -Encoding UTF8 -Force
            Write-WorkerLog ("[" + $idx + "/" + $toInstall.Count + "] Iniciando descarga e instalacion de " + $cap.Name + "...") "START"
            try {
                if (-not [string]::IsNullOrEmpty($offlineSource)) {
                    Add-WindowsCapability -Online -Name $cap.Name -Source $offlineSource -LimitAccess -ErrorAction Stop | Out-Null
                } else {
                    Add-WindowsCapability -Online -Name $cap.Name -ErrorAction Stop | Out-Null
                }

                $chk = Get-WindowsCapability -Online -Name $cap.Name -ErrorAction SilentlyContinue
                if ($chk -and $chk.State -eq "Installed") {
                    Write-WorkerLog ("[" + $idx + "/" + $toInstall.Count + "] Instalado con EXITO: " + $cap.Name) "SUCCESS"
                    $successCount++
                } else {
                    Write-WorkerLog ("[" + $idx + "/" + $toInstall.Count + "] Estado no confirmado para: " + $cap.Name) "FAIL"
                    $failCount++
                }
            } catch {
                Write-WorkerLog ("[" + $idx + "/" + $toInstall.Count + "] ERROR al instalar " + $cap.Name + ": " + $_.Exception.Message) "FAIL"
                $failCount++
            }
        }

        if ($failCount -eq 0 -and $successCount -gt 0) {
            ("COMPLETED_SUCCESS:" + $successCount) | Out-File -FilePath $statFile -Encoding UTF8 -Force
        } elseif ($successCount -gt 0 -and $failCount -gt 0) {
            ("COMPLETED_PARTIAL:OK=" + $successCount + ",FAIL=" + $failCount) | Out-File -FilePath $statFile -Encoding UTF8 -Force
        } else {
            ("COMPLETED_FAILED:" + $failCount) | Out-File -FilePath $statFile -Encoding UTF8 -Force
        }
    }
} catch {
    Write-WorkerLog ("Error critico general: " + $_.Exception.Message) "ERROR"
    ("COMPLETED_FATAL:" + $_.Exception.Message) | Out-File -FilePath $statFile -Encoding UTF8 -Force
} finally {
    Write-WorkerLog "Restaurando directivas y servicios originales..." "INFO"
    try {
        if ($wsusModified -and $origUseWUServer -ne $null) {
            Set-ItemProperty -Path $wsusReg -Name "UseWUServer" -Value $origUseWUServer -Force -ErrorAction SilentlyContinue
        }
        if ($servicingModified) {
            if ($origRepairSource -ne $null) {
                Set-ItemProperty -Path $servicingReg -Name "RepairContentServerSource" -Value $origRepairSource -Force -ErrorAction SilentlyContinue
            } else {
                Remove-ItemProperty -Path $servicingReg -Name "RepairContentServerSource" -ErrorAction SilentlyContinue
            }
            Remove-ItemProperty -Path $servicingReg -Name "UseWindowsUpdate" -ErrorAction SilentlyContinue
        }
        Stop-Service -Name "wuauserv" -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Start-Service -Name "wuauserv" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    } catch {}

    Write-WorkerLog "Operacion de instalacion de RSAT concluida." "DONE"
}
'@

        $patternsFormatted = ($targetPatterns | ForEach-Object { "`"$_`"" }) -join ", "
        $workerHeader = "`$targetPatterns = @($patternsFormatted)`n`$offlineSource = `"$sourcePath`"`n"
        $fullWorkerScript = $workerHeader + $workerBody

        # 8. Despliegue e Inicio de Tarea Programada en la PC Remota
        Write-Host "`n[*] Desplegando tarea programada bajo NT AUTHORITY\SYSTEM en $targetMachine..." -ForegroundColor Yellow
        $initScriptBlock = {
            param($scriptContent)
            if (-not (Test-Path "C:\Windows\Temp")) {
                New-Item -Path "C:\Windows\Temp" -ItemType Directory -Force | Out-Null
            }
            Remove-Item "C:\Windows\Temp\Install-RSAT.log" -Force -ErrorAction SilentlyContinue
            Remove-Item "C:\Windows\Temp\Install-RSAT.status" -Force -ErrorAction SilentlyContinue
            Remove-Item "C:\Windows\Temp\Install-RSAT-Worker.ps1" -Force -ErrorAction SilentlyContinue

            [System.IO.File]::WriteAllText("C:\Windows\Temp\Install-RSAT-Worker.ps1", $scriptContent, [System.Text.Encoding]::UTF8)

            $taskName = "Install-RSAT-Task"
            try {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
            } catch {}

            $registered = $false
            try {
                $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Windows\Temp\Install-RSAT-Worker.ps1"
                $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
                $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
                Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Settings $settings -Force | Out-Null
                Start-ScheduledTask -TaskName $taskName | Out-Null
                $registered = $true
            } catch {
                $cmdCreate = "schtasks.exe /create /f /tn `"$taskName`" /ru `"SYSTEM`" /rl HIGHEST /tr `"powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Windows\Temp\Install-RSAT-Worker.ps1`" /sc ONCE /st 00:00"
                cmd.exe /c $cmdCreate 2>&1 | Out-Null
                cmd.exe /c "schtasks.exe /run /tn `"$taskName`"" 2>&1 | Out-Null
                $registered = $true
            }
            return $registered
        }

        $lanzado = $false
        if ($port5985) {
            try {
                if ($cred -ne $null) {
                    $lanzado = Invoke-Command -ComputerName $targetMachine -Credential $cred -ScriptBlock $initScriptBlock -ArgumentList $fullWorkerScript -ErrorAction Stop
                } else {
                    $lanzado = Invoke-Command -ComputerName $targetMachine -ScriptBlock $initScriptBlock -ArgumentList $fullWorkerScript -ErrorAction Stop
                }
            } catch {
                Write-Host "[-] WinRM error al desplegar: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        if (-not $lanzado -and $port445) {
            $psexecPath = "C:\PSTools\PsExec.exe"
            if (-not (Test-Path $psexecPath)) {
                $where = Get-Command psexec -ErrorAction SilentlyContinue
                if ($where) { $psexecPath = $where.Definition }
            }
            if (Test-Path $psexecPath) {
                Write-Host "[*] Intentando despliegue de tarea via PsExec..." -ForegroundColor Gray
                try {
                    $remoteTemp = "\\$targetMachine\C$\Windows\Temp"
                    if (Test-Path $remoteTemp) {
                        [System.IO.File]::WriteAllText("$remoteTemp\Install-RSAT-Worker.ps1", $fullWorkerScript, [System.Text.Encoding]::UTF8)
                        $cmdTask = "schtasks.exe /create /f /tn `"Install-RSAT-Task`" /ru `"SYSTEM`" /rl HIGHEST /tr `"powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Windows\Temp\Install-RSAT-Worker.ps1`" /sc ONCE /st 00:00 & schtasks.exe /run /tn `"Install-RSAT-Task`""
                        $argBase = "-accepteula -s cmd.exe /c `"$cmdTask`""
                        $argExec = if ($usu -ne "") { "\\$targetMachine -u `"$usu`" -p `"$claTexto`" $argBase" } else { "\\$targetMachine $argBase" }
                        $p = Start-Process -FilePath $psexecPath -ArgumentList $argExec -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
                        if ($p -and $p.ExitCode -eq 0) { $lanzado = $true }
                    }
                } catch {}
            }
        }

        if (-not $lanzado) {
            Write-Host "[ERROR] No se pudo desplegar ni iniciar la tarea en $targetMachine." -ForegroundColor Red
            Write-Host "Verifique conectividad, cortafuegos o credenciales de administrador." -ForegroundColor Yellow
            Write-Host " "
            Read-Host "Presione ENTER para continuar..."
            return
        }

        Write-Host "[+] Tarea iniciada con exito en $targetMachine." -ForegroundColor Green

        # 9. Seleccion de Modalidad de Monitoreo
        Write-Host "`n--- MODALIDAD DE MONITOREO DEL PROGRESO ---" -ForegroundColor Yellow
        Write-Host " [1] Monitorear en NUEVA VENTANA (Recomendado - Libera esta consola de inmediato)" -ForegroundColor Cyan
        Write-Host " [2] Monitorear en ESTA CONSOLA (En linea - Bloqueante)" -ForegroundColor White
        $monOpt = Read-Host "Seleccione una modalidad [1-2] (Por defecto: 1)"
        if ([string]::IsNullOrWhiteSpace($monOpt)) { $monOpt = "1" }

        # Script de Monitoreo Detallado (en nueva ventana o en consola)
        $monitorScriptCode = @"
`$Host.UI.RawUI.WindowTitle = "MONITOR RSAT: $targetMachine | shellWil"
try {
    if (`$Host.UI.RawUI.BufferSize.Width -lt 115) {
        `$Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size(115, 3000)
        `$Host.UI.RawUI.WindowSize = New-Object Management.Automation.Host.Size(115, 42)
    }
} catch {}

Clear-Host
Write-Host "==========================================================================================" -ForegroundColor Cyan
Write-Host "                MONITOR DE INSTALACION DE COMPONENTES RSAT REMOTO                         " -ForegroundColor White -BackgroundColor DarkBlue
Write-Host "==========================================================================================" -ForegroundColor Cyan
Write-Host "  Equipo Destino : $targetMachine" -ForegroundColor Yellow
Write-Host "  Criterio       : $criterioLabel" -ForegroundColor White
Write-Host "  Hora de Inicio : `$((Get-Date).ToString('HH:mm:ss'))" -ForegroundColor Gray
Write-Host "==========================================================================================`n" -ForegroundColor Cyan

# Autenticacion IPC si hay credenciales explicitas
if ("$usu" -ne "" -and "$claTexto" -ne "") {
    cmd.exe /c "net use \\$targetMachine\IPC$ /user:`"$usu`" `"$claTexto`"" 2>&1 | Out-Null
}

Write-Host "[*] Conectando con $targetMachine y transmitiendo progreso en tiempo real...`n" -ForegroundColor Gray

`$startTime = Get-Date
`$lastLine = 0
`$terminado = `$false
`$maxMinutes = 35
`$lastActivityTime = Get-Date
`$finalStatus = ""
`$ultimoComponente = ""

while (-not `$terminado) {
    Start-Sleep -Seconds 3
    `$elapsed = "{0:mm\:ss}" -f ((Get-Date) - `$startTime)

    `$newLines = @()
    `$status = "RUNNING"

    # 1. Lectura directa via SMB
    `$logSMB = "\\$targetMachine\C$\Windows\Temp\Install-RSAT.log"
    `$statSMB = "\\$targetMachine\C$\Windows\Temp\Install-RSAT.status"
    `$smbOk = `$false

    if (Test-Path `$logSMB) {
        try {
            `$all = Get-Content `$logSMB -Encoding UTF8 -ErrorAction SilentlyContinue
            if (`$all) {
                `$total = `$all.Count
                if (`$total -gt `$lastLine) {
                    `$newLines = `$all[`$lastLine..(`$total - 1)]
                    `$lastLine = `$total
                    `$lastActivityTime = Get-Date
                }
            }
            `$smbOk = `$true
        } catch {}
    }
    if (Test-Path `$statSMB) {
        try {
            `$stVal = (Get-Content `$statSMB -Raw -ErrorAction SilentlyContinue).Trim()
            if (-not [string]::IsNullOrWhiteSpace(`$stVal)) { `$status = `$stVal }
        } catch {}
    }

    # 2. Fallback WinRM si SMB no estuvo accesible
    if (-not `$smbOk) {
        try {
            `$pollRes = Invoke-Command -ComputerName "$targetMachine" -ScriptBlock {
                param(`$from)
                `$l = "C:\Windows\Temp\Install-RSAT.log"
                `$s = "C:\Windows\Temp\Install-RSAT.status"
                `$lines = @()
                `$tot = 0
                if (Test-Path `$l) {
                    try {
                        `$a = Get-Content `$l -Encoding UTF8 -ErrorAction SilentlyContinue
                        if (`$a) {
                            `$tot = `$a.Count
                            if (`$tot -gt `$from) { `$lines = `$a[`$from..(`$tot - 1)] }
                        }
                    } catch {}
                }
                `$st = "RUNNING"
                if (Test-Path `$s) {
                    try { `$st = (Get-Content `$s -Raw -ErrorAction SilentlyContinue).Trim() } catch {}
                }
                return @{ Lines = `$lines; Total = `$tot; Status = `$st }
            } -ArgumentList `$lastLine -ErrorAction SilentlyContinue

            if (`$pollRes) {
                if (`$pollRes.Total -gt `$lastLine) {
                    `$newLines = `$pollRes.Lines
                    `$lastLine = `$pollRes.Total
                    `$lastActivityTime = Get-Date
                }
                if (`$pollRes.Status) { `$status = `$pollRes.Status }
            }
        } catch {}
    }

    # 3. Procesar y colorear lineas de log
    if (`$newLines -and `$newLines.Count -gt 0) {
        foreach (`$l in `$newLines) {
            if (`$l -match "\[SUCCESS\]") {
                Write-Host "  [`$elapsed] `$l" -ForegroundColor Green
            } elseif (`$l -match "\[FAIL\]|\[ERROR\]") {
                Write-Host "  [`$elapsed] `$l" -ForegroundColor Red
            } elseif (`$l -match "\[START\]") {
                Write-Host "  [`$elapsed] `$l" -ForegroundColor Cyan
            } elseif (`$l -match "\[WARN\]") {
                Write-Host "  [`$elapsed] `$l" -ForegroundColor Yellow
            } else {
                Write-Host "  [`$elapsed] `$l" -ForegroundColor Gray
            }
        }
    } else {
        # Latido dinamico con detalle del componente actual
        `$inactiveSec = ((Get-Date) - `$lastActivityTime).TotalSeconds
        if (`$inactiveSec -ge 10) {
            if (`$status -match "^INSTALLING:(.+?)\|(\d+)\|(\d+)") {
                `$cName = `$Matches[1]
                `$cIdx = `$Matches[2]
                `$cTot = `$Matches[3]
                Write-Host "   >>> [`$elapsed] [DESCARGANDO/INSTALANDO] `$cName (Progreso: `$cIdx de `$cTot)..." -ForegroundColor DarkCyan
            } elseif (`$status -like "IN_PROGRESS*") {
                Write-Host "   >>> [`$elapsed] [INICIALIZANDO] Preparando servicios del sistema y catalogo DISM en $targetMachine..." -ForegroundColor DarkCyan
            } else {
                Write-Host "   >>> [`$elapsed] [EN PROGRESO] Operacion activa en PC remota..." -ForegroundColor DarkCyan
            }
            `$lastActivityTime = Get-Date
        }
    }

    # 4. Evaluacion de fin de proceso
    if (`$status -like "COMPLETED_*") {
        `$terminado = `$true
        `$finalStatus = `$status
    }

    # 5. Deteccion de fallo prematuro de la tarea programada
    if (-not `$terminado -and ((Get-Date) - `$startTime).TotalSeconds -gt 15) {
        try {
            `$tChk = schtasks.exe /query /s "$targetMachine" /tn "Install-RSAT-Task" /fo CSV -ErrorAction SilentlyContinue 2>`$null | ConvertFrom-Csv
            if (`$tChk) {
                `$stTask = `$tChk.Status -or `$tChk.Estado
                if (`$stTask -and `$stTask -notmatch "Running|Ejecutando" -and `$status -notlike "COMPLETED_*") {
                    # Tarea finalizo inesperadamente
                    `$terminado = `$true
                    `$finalStatus = "TASK_STOPPED_UNEXPECTEDLY"
                }
            }
        } catch {}
    }

    if (((Get-Date) - `$startTime).TotalMinutes -gt `$maxMinutes) {
        Write-Host "`n[-] Se supero el tiempo limite de `$maxMinutes minutos." -ForegroundColor Red
        break
    }
}

Write-Host "`n==========================================================================================" -ForegroundColor Cyan
if (`$finalStatus -like "COMPLETED_SUCCESS*" -or `$finalStatus -eq "COMPLETED_NOTHING_TODO") {
    Write-Host "[EXITO] Instalacion de RSAT completada correctamente en $targetMachine." -ForegroundColor Green
} elseif (`$finalStatus -like "COMPLETED_PARTIAL*") {
    Write-Host "[AVISO] Instalacion finalizada con algunos componentes instalados y otros con advertencia." -ForegroundColor Yellow
} elseif (`$finalStatus -eq "TASK_STOPPED_UNEXPECTEDLY") {
    Write-Host "[-] La tarea remota se detuvo de forma imprevista." -ForegroundColor Red
    Write-Host "Revise el registro en la PC remota: C:\Windows\Temp\Install-RSAT.log" -ForegroundColor Yellow
} else {
    Write-Host "[-] Instalacion finalizada con estado: `$finalStatus." -ForegroundColor Red
    Write-Host "Revise el registro en la PC remota: C:\Windows\Temp\Install-RSAT.log" -ForegroundColor Yellow
}
Write-Host "Tiempo total transcurrido: `$elapsed" -ForegroundColor Gray
Write-Host "==========================================================================================" -ForegroundColor Cyan

# Limpieza remota
try {
    Invoke-Command -ComputerName "$targetMachine" -ScriptBlock {
        Unregister-ScheduledTask -TaskName "Install-RSAT-Task" -Confirm:`$false -ErrorAction SilentlyContinue | Out-Null
        Remove-Item "C:\Windows\Temp\Install-RSAT-Worker.ps1" -Force -ErrorAction SilentlyContinue
    } -ErrorAction SilentlyContinue | Out-Null
} catch {}

Write-Host "`nPresione cualquier tecla para continuar..." -ForegroundColor Gray
try { [void][System.Console]::ReadKey(`$true) } catch {}
"@

        if ($monOpt.Trim() -eq "1") {
            # Modalidad 1: Nueva Ventana Independiente (Consola Libre)
            $monitorFile = Join-Path $env:TEMP "shellWil_MonitorRSAT_${targetMachine}.ps1"
            [System.IO.File]::WriteAllText($monitorFile, $monitorScriptCode, [System.Text.Encoding]::UTF8)

            Write-Host "`n[*] Abriendo monitor de progreso en una NUEVA VENTANA..." -ForegroundColor Green
            Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$monitorFile`""

            Write-Host "`n==========================================================================" -ForegroundColor Cyan
            Write-Host "  [OK] PROCESO DESPLEGADO Y MONITOR INICIADO EN NUEVA VENTANA INDEPENDIENTE" -ForegroundColor Green
            Write-Host "==========================================================================" -ForegroundColor Cyan
            Write-Host "  Equipo Destino : $targetMachine" -ForegroundColor White
            Write-Host "  Componentes    : $criterioLabel" -ForegroundColor White
            Write-Host "  Estado         : Tarea programada iniciada en contexto SYSTEM" -ForegroundColor Gray
            Write-Host "  Monitoreo      : Se abrio una ventana secundaria para seguir el avance en vivo." -ForegroundColor Gray
            Write-Host "                   Esta consola queda completamente LIBRE para su uso." -ForegroundColor Green
            Write-Host "==========================================================================" -ForegroundColor Cyan
            Write-Host " "
            Read-Host "Presione ENTER para continuar..."
        } else {
            # Modalidad 2: Monitoreo en Esta Misma Consola (Bloqueante)
            Write-Host "`n[*] Iniciando monitoreo en esta consola..." -ForegroundColor Cyan
            $sbExec = [ScriptBlock]::Create($monitorScriptCode)
            & $sbExec
        }
    }


    function Get-NativeSnmpSummary {
        param(
            [string]$TargetIP,
            [string]$Community = "public",
            [int]$TimeoutMs = 400
        )
        $resObj = [PSCustomObject]@{
            SysDescr = $null
            SysName  = $null
            IsActive = $false
        }

        $fnOidToBytes = {
            param([string]$oid)
            $parts = $oid.Split('.') | ForEach-Object { [int]$_ }
            $bytes = New-Object 'System.Collections.Generic.List[byte]'
            $bytes.Add([byte](40 * $parts[0] + $parts[1]))
            for ($i = 2; $i -lt $parts.Count; $i++) {
                $val = $parts[$i]
                $temp = New-Object 'System.Collections.Generic.List[byte]'
                $temp.Add([byte]($val -band 0x7f))
                $val = $val -shr 7
                while ($val -gt 0) {
                    $temp.Insert(0, [byte](($val -band 0x7f) -bor 0x80))
                    $val = $val -shr 7
                }
                $bytes.AddRange($temp)
            }
            return $bytes.ToArray()
        }

        $fnBuildSnmp = {
            param([string]$comm, [string]$oid)
            $oidBytes = & $fnOidToBytes $oid
            $varbind = New-Object 'System.Collections.Generic.List[byte]'
            $varbind.Add(0x06); $varbind.Add([byte]$oidBytes.Length); $varbind.AddRange($oidBytes)
            $varbind.Add(0x05); $varbind.Add(0x00)

            $varbindList = New-Object 'System.Collections.Generic.List[byte]'
            $varbindList.Add(0x30); $varbindList.Add([byte]$varbind.Count); $varbindList.AddRange($varbind)

            $pdu = New-Object 'System.Collections.Generic.List[byte]'
            $pdu.Add(0x02); $pdu.Add(0x04); $pdu.AddRange(@(0x00, 0x00, 0x00, 0x01))
            $pdu.Add(0x02); $pdu.Add(0x01); $pdu.Add(0x00)
            $pdu.Add(0x02); $pdu.Add(0x01); $pdu.Add(0x00)
            $pdu.AddRange($varbindList)

            $commBytes = [System.Text.Encoding]::ASCII.GetBytes($comm)
            $msg = New-Object 'System.Collections.Generic.List[byte]'
            $msg.Add(0x02); $msg.Add(0x01); $msg.Add(0x01)
            $msg.Add(0x04); $msg.Add([byte]$commBytes.Length); $msg.AddRange($commBytes)

            $env = New-Object 'System.Collections.Generic.List[byte]'
            $env.Add(0xa0); $env.Add([byte]$pdu.Count); $env.AddRange($pdu)
            $msg.AddRange($env)

            $pkt = New-Object 'System.Collections.Generic.List[byte]'
            $pkt.Add(0x30); $pkt.Add([byte]$msg.Count); $pkt.AddRange($msg)
            return $pkt.ToArray()
        }

        $fnQueryOid = {
            param([string]$oid)
            $sock = $null
            try {
                $sock = New-Object System.Net.Sockets.UdpClient
                $sock.Client.ReceiveTimeout = $TimeoutMs
                $pkt = & $fnBuildSnmp $Community $oid
                $sock.Connect($TargetIP, 161)
                $sock.Send($pkt, $pkt.Length) | Out-Null
                $ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
                $resp = $sock.Receive([ref]$ep)

                $oidB = & $fnOidToBytes $oid
                $oidIdx = -1
                for ($i = 0; $i -le ($resp.Length - $oidB.Length); $i++) {
                    $m = $true
                    for ($j = 0; $j -lt $oidB.Length; $j++) {
                        if ($resp[$i + $j] -ne $oidB[$j]) { $m = $false; break }
                    }
                    if ($m) { $oidIdx = $i; break }
                }
                if ($oidIdx -eq -1) { return $null }
                $vIdx = $oidIdx + $oidB.Length
                if ($vIdx -ge $resp.Length) { return $null }
                $vTag = $resp[$vIdx]
                $lByte = $resp[$vIdx + 1]
                $dIdx = $vIdx + 2
                $vLen = $lByte
                if ($lByte -band 0x80) {
                    $nBytes = $lByte -band 0x7f
                    $vLen = 0
                    for ($k = 0; $k -lt $nBytes; $k++) { $vLen = ($vLen -shl 8) + $resp[$dIdx + $k] }
                    $dIdx += $nBytes
                }
                if (($dIdx + $vLen) -gt $resp.Length) { return $null }
                if ($vTag -eq 0x04) {
                    return [System.Text.Encoding]::ASCII.GetString($resp, $dIdx, $vLen)
                }
                return $null
            } catch {
                return $null
            } finally {
                if ($sock) { $sock.Close() }
            }
        }

        $d = & $fnQueryOid "1.3.6.1.2.1.1.1.0"
        if ($d) {
            $resObj.SysDescr = $d.Trim()
            $resObj.IsActive = $true
        }
        $n = & $fnQueryOid "1.3.6.1.2.1.1.5.0"
        if ($n) {
            $resObj.SysName = $n.Trim()
            $resObj.IsActive = $true
        }
        return $resObj
    }

    function Get-NetworkDeviceProfile {
        param(
            [string]$TargetIP,
            [string]$HostName,
            [string]$MACAddress
        )

        $ouiDB = @{
            '00:17:61' = 'ZKTeco (Biometrico)'; '6C:DF:FB' = 'ZKTeco (Biometrico)'; 'E0:69:95' = 'ZKTeco (Biometrico)'
            'C4:2F:90' = 'ZKTeco (Biometrico)'; '00:0B:82' = 'Grandstream (Biometrico/VoIP)'; '2C:26:17' = 'Anviz (Biometrico)'
            '50:13:95' = 'Suprema (Biometrico)'
            '00:26:73' = 'Ricoh (Fotocopiadora)'; '00:00:85' = 'Canon (Fotocopiadora/Impresora)'; '00:20:6B' = 'Konica Minolta (Fotocopiadora)'
            '00:04:F2' = 'Polycom/Ricoh'; '00:17:C8' = 'Kyocera (Fotocopiadora)'; '00:C0:EE' = 'Kyocera (Fotocopiadora)'
            '00:00:AA' = 'Xerox (Fotocopiadora)'; '00:80:77' = 'Brother (Fotocopiadora/Impresora)'; '00:1B:A9' = 'Toshiba (Fotocopiadora)'
            '78:8C:77' = 'Sharp (Fotocopiadora)'; '00:00:07' = 'Xerox (Fotocopiadora)'
            '00:1E:0B' = 'HP (Impresora)'; '00:25:B3' = 'HP (Impresora)'; '3C:D9:2B' = 'HP (Impresora)'
            '70:5A:0F' = 'HP (Impresora)'; 'A4:5D:36' = 'HP (Impresora)'; '00:00:48' = 'Epson (Impresora)'
            '00:26:AB' = 'Epson (Impresora)'; '00:01:E6' = 'Hewlett Packard (Impresora)'; '00:05:9A' = 'Zebra (Impresora)'
            '58:38:79' = 'Hikvision (CCTV)'; '44:19:B6' = 'Hikvision (CCTV)'; 'C0:56:E3' = 'Hikvision (CCTV)'
            'B4:A3:82' = 'Hikvision (CCTV)'; '28:57:BE' = 'Hikvision (CCTV)'; '54:C4:15' = 'Dahua (CCTV)'
            'E0:50:8B' = 'Dahua (CCTV)'; '38:AF:29' = 'Dahua (CCTV)'; 'B0:C5:54' = 'Dahua (CCTV)'
            '00:40:8C' = 'Axis (CCTV)'; '48:EA:63' = 'Uniview (CCTV)'
            '00:00:0C' = 'Cisco Systems'; '00:01:42' = 'Cisco Systems'; '00:1C:7F' = 'Cisco Systems'
            '00:1A:A1' = 'Cisco Systems'; '48:8F:5A' = 'HPE Aruba'; '6C:3B:6B' = 'HPE Aruba'
            'CC:2D:E0' = 'HPE ProCurve'; 'D4:CA:6D' = 'MikroTik'; 'D4:F5:EF' = 'Huawei'
            'C0:06:C3' = 'D-Link'; '50:D4:F7' = 'TP-Link'
            '24:A4:3C' = 'Ubiquiti Networks'; 'F0:9F:C2' = 'Ubiquiti Networks'
            '50:C7:BF' = 'TP-Link WiFi'; 'E8:48:B8' = 'TP-Link WiFi'
            'F8:BC:12' = 'Dell (Computadora)'; '7C:57:58' = 'Dell (Computadora)'; '00:14:22' = 'Dell (Computadora)'
            '18:66:DA' = 'Dell (Computadora)'; 'B8:CA:3A' = 'Dell (Computadora)'; 'AC:16:2D' = 'Hewlett Packard (PC)'
            'B0:4F:13' = 'Hewlett Packard (PC)'; 'A0:B3:CC' = 'Lenovo (Computadora)'; 'E4:54:E8' = 'Lenovo (Computadora)'
            '00:59:07' = 'Lenovo (Computadora)'
        }

        # 1. Prospeccion rapida de puertos Windows
        $p135 = Test-PortQuick $TargetIP 135 100
        $p445 = Test-PortQuick $TargetIP 445 100
        $p3389 = $false
        $p5985 = $false
        if ($p135 -or $p445) {
            $p3389 = Test-PortQuick $TargetIP 3389 100
            $p5985 = Test-PortQuick $TargetIP 5985 100
        }

        $fabricanteOUI = "No identificado"
        if ($MACAddress -and $MACAddress.Length -ge 8) {
            $pref = $MACAddress.Substring(0, 8).ToUpper()
            if ($ouiDB.ContainsKey($pref)) {
                $fabricanteOUI = $ouiDB[$pref]
            }
        }

        # Si responde puertos Windows (135 o 445), se clasifica como Computadora
        if ($p135 -or $p445) {
            return [PSCustomObject]@{
                IsComputer    = $true
                DeviceType    = "Computadora (Windows PC / Servidor)"
                Port135       = $p135
                Port445       = $p445
                Port3389      = $p3389
                Port5985      = $p5985
                OpenPorts     = @()
                Manufacturer  = $fabricanteOUI
                SnmpData      = $null
                EffectiveHost = $HostName
            }
        }

        # Sondeo de puertos para dispositivos de red no-PC
        $p9100 = Test-PortQuick $TargetIP 9100 120
        $p515  = Test-PortQuick $TargetIP 515 100
        $p631  = Test-PortQuick $TargetIP 631 100
        $p4370 = Test-PortQuick $TargetIP 4370 120
        $p5005 = Test-PortQuick $TargetIP 5005 100
        $p554  = Test-PortQuick $TargetIP 554 100
        $p8000 = Test-PortQuick $TargetIP 8000 100
        $p37777= Test-PortQuick $TargetIP 37777 100
        $p34567= Test-PortQuick $TargetIP 34567 100
        $p8291 = Test-PortQuick $TargetIP 8291 100
        $p22   = Test-PortQuick $TargetIP 22 100
        $p23   = Test-PortQuick $TargetIP 23 100
        $p80   = Test-PortQuick $TargetIP 80 100
        $p443  = Test-PortQuick $TargetIP 443 100
        $p8080 = Test-PortQuick $TargetIP 8080 100

        # Sondeo SNMP
        $snmpInfo = Get-NativeSnmpSummary $TargetIP "public" 400

        $openPortsList = @()
        if ($p9100) { $openPortsList += "9100 (RAW Print)" }
        if ($p515)  { $openPortsList += "515 (LPD Print)" }
        if ($p631)  { $openPortsList += "631 (IPP Print)" }
        if ($p4370) { $openPortsList += "4370 (ZKTeco Biometric)" }
        if ($p5005) { $openPortsList += "5005 (Suprema Biometric)" }
        if ($p554)  { $openPortsList += "554 (RTSP Video)" }
        if ($p8000) { $openPortsList += "8000 (Hikvision SDK)" }
        if ($p37777){ $openPortsList += "37777 (Dahua SDK)" }
        if ($p34567){ $openPortsList += "34567 (XM DVR)" }
        if ($p8291) { $openPortsList += "8291 (MikroTik Winbox)" }
        if ($p22)   { $openPortsList += "22 (SSH)" }
        if ($p23)   { $openPortsList += "23 (Telnet)" }
        if ($p80)   { $openPortsList += "80 (HTTP Web)" }
        if ($p443)  { $openPortsList += "443 (HTTPS Web)" }
        if ($p8080) { $openPortsList += "8080 (HTTP Alt)" }
        if ($snmpInfo.IsActive) { $openPortsList += "161 (SNMP UDP)" }

        # Si SNMP trajo un sysName mas preciso, actualizar HostName
        $effectiveHost = $HostName
        if ([string]::IsNullOrWhiteSpace($effectiveHost) -or $effectiveHost -eq $TargetIP) {
            if ($snmpInfo.SysName) {
                $effectiveHost = $snmpInfo.SysName
            }
        }

        # Logica de clasificacion
        $hUpper = "$effectiveHost $($snmpInfo.SysDescr) $fabricanteOUI".ToUpper()
        $tipo = "Dispositivo de Red (Generico)"

        if ($p4370 -or $p5005 -or ($hUpper -match "ZK|BIO|RELOJ|ANVIZ|TIMESTATION|CONTROL-ASISTENCIA|SUPREMA") -or ($fabricanteOUI -match "ZKTeco|Anviz|Suprema")) {
            $tipo = "Reloj biometrico / Control de Asistencia"
        }
        elseif (($hUpper -match "DVR|NVR|XVR|HIK-NVR|DAHUA-NVR|GRABADOR|HIKVISION-NVR") -or 
                (($p8000 -or $p37777 -or $p34567) -and ($hUpper -notmatch "CAM|IPC") -and $p554)) {
            $tipo = "DVR / NVR (Grabador de Video de Seguridad)"
        }
        elseif ($p554 -or ($hUpper -match "CAM|IPC|CAMERA|DOMO|TUBO|BULLET|CCTV|HIK-CAM|DAHUA-CAM|HIKVISION|DAHUA|UNIVIEW|AXIS") -or ($fabricanteOUI -match "Hikvision|Dahua|Axis|Uniview")) {
            $tipo = "Camara CCTV / Seguridad IP"
        }
        elseif (($hUpper -match "RICOH|AFICIO|KONICA|BIZHUB|KYOCERA|TASKALFA|XEROX|WORKCENTRE|ALTALINK|VERSALINK|TOSHIBA|ESTUDIO|SHARP|MX-|DEVELOP|IMAGERUNNER|IR-ADV|COPIADORA|FOTOCOPIADORA") -or
                ($p9100 -and ($p80 -or $p443) -and ($fabricanteOUI -match "Ricoh|Canon|Konica|Kyocera|Xerox|Toshiba|Sharp"))) {
            $tipo = "Fotocopiadora (Multifuncional Corporativa)"
        }
        elseif ($p9100 -or $p515 -or $p631 -or ($hUpper -match "PRN|PRINT|EPSON|BROTHER|HP-PRINT|LASERJET|DESKJET|PAGEWIDE|ZEBRA|SATO|IMPRESORA|HEWLETT PACKARD") -or ($fabricanteOUI -match "HP|Epson|Brother|Zebra")) {
            $tipo = "Impresora de red"
        }
        elseif ($p8291 -or ($hUpper -match "ROUTER|GW|GATEWAY|MIKROTIK|FORTINET|CISCO-ROUTER|PFSENSE|OPNSENSE|EDGEROUTER|FIREWALL") -or ($fabricanteOUI -match "MikroTik")) {
            $tipo = "Router / Gateway / Firewall"
        }
        elseif ($p8080 -or ($hUpper -match "WIFI|AP-|AP_|WIRELESS|ACCESSPOINT|UNIFI|UAP|AIRMAX|TENDA|MERCUSYS") -or ($fabricanteOUI -match "Ubiquiti")) {
            $tipo = "Router inalambrico / Access Point"
        }
        elseif ($p22 -or $p23 -or ($snmpInfo.IsActive) -or ($hUpper -match "SW|SWITCH|SW-|CATALYST|PROCURVE|ARUBA|EDGESWITCH|CISCO") -or ($fabricanteOUI -match "Cisco|Aruba|ProCurve|Huawei")) {
            $tipo = "Switch de datos / Red"
        }
        elseif ($hUpper -match "SCANNER|ESCANER|AVISION|FUJITSU") {
            $tipo = "Escaner de red"
        }
        elseif ($p22 -and -not $p135 -and -not $p445) {
            $tipo = "Servidor Linux / Unix"
        }

        $isComputerGuess = $false
        if ($openPortsList.Count -eq 0 -and ($hUpper -match "DESKTOP|LAPTOP|PC|WIN|SRV|SERVER|WS-|HMP")) {
            $isComputerGuess = $true
            $tipo = "Computadora (Windows PC - Firewall Activo / Puertos Filtrados)"
        }

        return [PSCustomObject]@{
            IsComputer    = $isComputerGuess
            DeviceType    = $tipo
            Port135       = $false
            Port445       = $false
            Port3389      = $false
            Port5985      = $false
            OpenPorts     = $openPortsList
            Manufacturer  = $fabricanteOUI
            SnmpData      = $snmpInfo
            EffectiveHost = $effectiveHost
        }
    }

    function Get-RemoteConnectionContext {
        $defTarget = ""
        if ($global:RemoteTargetIP) {
            $defTarget = $global:RemoteTargetIP
        }
        
        Write-Host "`n--- Conexion Remota ---" -ForegroundColor Yellow
        $prompt = "Ingrese la IP completa (ej: 192.168.176.50) o los 2 ultimos octetos (ej: 176.50)"
        if ($defTarget) {
            $prompt += " [$defTarget]"
        }
        $inputTarget = Read-Host $prompt
        
        if ($inputTarget.Trim() -eq "") {
            if ($defTarget) {
                $target = $defTarget
            }
            else {
                Write-Host "[ERROR] Debe especificar un destino." -ForegroundColor Red
                return $null
            }
        }
        else {
            $target = Parse-RemoteTarget $inputTarget
        }

        # Visualizar inmediatamente la tarjeta del usuario activo como primera salida tras digitar la IP
        psMostrarInformacionUsuarioActivo -TargetIP $target

        # 1. Comprobación rápida de conectividad (.NET Ping con timeout 1000ms)
        Write-Host "Verificando conexion con $target (Ping rapido)..." -ForegroundColor Yellow
        $pingExitoso = $false
        try {
            $pingObj = New-Object System.Net.NetworkInformation.Ping
            $reply = $pingObj.Send($target, 1000)
            if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                $pingExitoso = $true
            }
        }
        catch {
            $pingExitoso = Test-Connection -ComputerName $target -Count 1 -Quiet -ErrorAction SilentlyContinue
        }

        if (-not $pingExitoso) {
            Write-Host "[AVISO] El equipo $target no respondio al ping en 1s. Verifique si esta encendido o tiene firewall." -ForegroundColor Yellow
            $confirmar = Read-Host "¿Desea intentar la conexion de todas formas? (S/N) [N]"
            if ($confirmar.ToUpper() -ne "S") {
                return $null
            }
        }

        # 2. Resolución rápida de Hostname para soporte Kerberos / Dominio
        $targetHost = $target
        try {
            $dnsTask = [System.Net.Dns]::GetHostEntry($target)
            if ($dnsTask -and $dnsTask.HostName) {
                $targetHost = $dnsTask.HostName.Split('.')[0]
            }
        }
        catch {}

        # 3. Selección y configuración de credenciales (3 tipos solicitados)
        $cred = $null
        $tipoCred = "1"
        if ($global:RemoteTargetIP -eq $target -and $global:RemoteTargetCred -ne $null) {
            $usarExistente = Read-Host "¿Usar las credenciales guardadas para $target? (S/N) [S]"
            if ($usarExistente -eq "" -or $usarExistente.ToUpper() -eq "S") {
                $cred = $global:RemoteTargetCred
                $tipoCred = if ($global:RemoteAuthType) { $global:RemoteAuthType } else { "1" }
            }
        }
        
        if ($null -eq $cred) {
            Write-Host "`nSeleccione el tipo de autenticacion para ${target}:" -ForegroundColor Yellow
            Write-Host "1. Credenciales de la sesion actual (SSO/Dominio Local)"
            Write-Host "2. Credenciales de Usuario de Dominio (ej: DOMINIO\Usuario)"
            Write-Host "3. Credenciales de Usuario Local (ej: .\Administrador o $target\Administrador)"
            $tipoCred = Read-Host "Seleccione opcion [1]"
            if ([string]::IsNullOrWhiteSpace($tipoCred)) { $tipoCred = "1" }
            
            if ($tipoCred -eq "2" -or $tipoCred -eq "3") {
                $promptUser = if ($tipoCred -eq "2") { "Usuario de Dominio (ej: DOMINIO\Usuario)" } else { "Usuario Local (ej: .\Administrador)" }
                Write-Host "Ingrese las credenciales para ${promptUser}:" -ForegroundColor Yellow
                $rawCred = Get-Credential
                
                if ($rawCred) {
                    $uName = $rawCred.UserName
                    # Saneamiento para Tipo 3 (Usuario Local): Si no tiene '\' ni '@', anteponer '.\'
                    # para evitar que Windows intente resolver en el Controlador de Dominio causando demoras de 30s
                    if ($tipoCred -eq "3" -and $uName -notmatch '\\' -and $uName -notmatch '@') {
                        $fixedUser = ".\$uName"
                        $cred = New-Object System.Management.Automation.PSCredential($fixedUser, $rawCred.Password)
                    }
                    else {
                        $cred = $rawCred
                    }
                }
            }
        }
        
        $global:RemoteTargetIP = $target
        $global:RemoteTargetHostName = $targetHost
        $global:RemoteTargetCred = $cred
        $global:RemoteAuthType = $tipoCred
        
        return New-Object PSObject -Property @{
            ComputerName = $target
            HostName     = $targetHost
            Credential   = $cred
            AuthType     = $tipoCred
        }
    }

    function Mount-RemoteCShare {
        param(
            [string]$ComputerName,
            $Credential
        )
        $driveName = "RemoteC_Clean"
        if (Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue) {
            Remove-PSDrive -Name $driveName -Force -ErrorAction SilentlyContinue
        }
        
        $rootPath = "\\$ComputerName\C$"
        Write-Host "Conectando al recurso administrativo $rootPath..." -ForegroundColor Yellow
        
        try {
            if ($null -ne $Credential) {
                New-PSDrive -Name $driveName -PSProvider FileSystem -Root $rootPath -Credential $Credential -Scope Global -ErrorAction Stop | Out-Null
            }
            else {
                New-PSDrive -Name $driveName -PSProvider FileSystem -Root $rootPath -Scope Global -ErrorAction Stop | Out-Null
            }
            Write-Host "Conectado exitosamente al recurso compartido C$." -ForegroundColor Green
            return $driveName
        }
        catch {
            # Si hay error 1219 (conexiones múltiples con credenciales distintas), intentar limpiar la sesión previa
            if ($_.Exception.Message -match "1219" -or $_.Exception.Message -match "multiple connections") {
                try {
                    cmd.exe /c "net use `"$rootPath`" /delete /y" 2>&1 | Out-Null
                    Start-Sleep -Milliseconds 300
                    if ($null -ne $Credential) {
                        New-PSDrive -Name $driveName -PSProvider FileSystem -Root $rootPath -Credential $Credential -Scope Global -ErrorAction Stop | Out-Null
                    }
                    else {
                        New-PSDrive -Name $driveName -PSProvider FileSystem -Root $rootPath -Scope Global -ErrorAction Stop | Out-Null
                    }
                    Write-Host "Conectado exitosamente al recurso compartido C$ tras restablecer sesion." -ForegroundColor Green
                    return $driveName
                } catch {}
            }
            Write-Host "[ERROR] No se pudo mapear la unidad C$ remota." -ForegroundColor Red
            Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
    }

    function Dismount-RemoteCShare {
        param([string]$driveName)
        if ($driveName -and (Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue)) {
            Remove-PSDrive -Name $driveName -Force -ErrorAction SilentlyContinue
            Write-Host "Unidad remota C$ desmontada." -ForegroundColor Gray
        }
    }

    function Invoke-RemotePowerShellEncoded {
        param(
            [string]$ComputerName,
            $Credential,
            [string]$ScriptContent
        )
        $scriptBytes = [System.Text.Encoding]::Unicode.GetBytes($ScriptContent)
        $scriptBase64 = [Convert]::ToBase64String($scriptBytes)
        $cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand $scriptBase64"
        
        try {
            if ($null -ne $Credential) {
                $res = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $cmd -ComputerName $ComputerName -Credential $Credential -ErrorAction Stop
            }
            else {
                $res = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $cmd -ComputerName $ComputerName -ErrorAction Stop
            }
            return $res
        }
        catch {
            Write-Host "[ERROR] Fallo al invocar proceso WMI en $ComputerName : $_" -ForegroundColor Red
            return $null
        }
    }

    # ==============================================================================
    #   MODULOS INDEPENDIENTES DEL GRUPO 13: OPTIMIZACION Y LIMPIEZA REMOTA
    # ==============================================================================

    function Invoke-RemoteCleanTempFolders {
        param(
            [Parameter(Mandatory=$true)]$ctx,
            [switch]$Silent
        )
        $ipRemota = $ctx.ComputerName
        $cred = $ctx.Credential
        
        if (-not $Silent) {
            Write-Host "Iniciando limpieza ultrarrapida de temporales en el equipo remoto $ipRemota..." -ForegroundColor Yellow
        }
        
        $remoteScript = @'
$delFiles = 0
$delDirs = 0
$delBytes = [int64]0

function Clean-TargetFolder {
    param([string]$targetDir)
    if (-not (Test-Path -LiteralPath $targetDir)) { return }
    $items = Get-ChildItem -LiteralPath $targetDir -Recurse -Force -ErrorAction SilentlyContinue
    if ($items) {
        foreach ($f in ($items | Where-Object { -not $_.PSIsContainer })) {
            try {
                $len = $f.Length
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                $script:delFiles++
                $script:delBytes += $len
            } catch {}
        }
        $dirs = $items | Where-Object { $_.PSIsContainer } | Sort-Object -Property @{Expression={$_.FullName.Length}} -Descending
        foreach ($d in $dirs) {
            try {
                Remove-Item -LiteralPath $d.FullName -Force -Confirm:$false -ErrorAction Stop
                $script:delDirs++
            } catch {}
        }
    }
}

# 1. Limpieza de Windows Temp y Prefetch
Clean-TargetFolder "C:\Windows\Temp"
Clean-TargetFolder "C:\Windows\Prefetch"

# 2. Limpieza de Temp de usuario activo
try {
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    if (-not $cs) { $cs = Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue }
    if ($cs -and $cs.UserName) {
        $uName = $cs.UserName.Split('\')[-1]
        Clean-TargetFolder "C:\Users\$uName\AppData\Local\Temp"
    }
} catch {}

$mb = [Math]::Round($script:delBytes / 1MB, 2)
"Files:$script:delFiles|Dirs:$script:delDirs|MB:$mb" | Out-File -FilePath "C:\Windows\Temp\clean_temp_quick_res.txt" -Encoding UTF8 -Force
'@
        $res = Invoke-RemotePowerShellEncoded -ComputerName $ipRemota -Credential $cred -ScriptContent $remoteScript
        $returnObj = [PSCustomObject]@{ Files = 0; Dirs = 0; MB = 0.0; Success = $false }

        if ($res -and $res.ReturnValue -eq 0 -and $res.ProcessId) {
            $remotePid = $res.ProcessId
            $timeout = 25
            $elapsed = 0
            while ($elapsed -lt $timeout) {
                Start-Sleep -Seconds 1
                try {
                    if ($null -ne $cred) {
                        $proc = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -Credential $cred -ErrorAction SilentlyContinue
                    } else {
                        $proc = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -ErrorAction SilentlyContinue
                    }
                } catch { $proc = $null }
                if ($null -eq $proc) { break }
                $elapsed++
            }

            $drive = Mount-RemoteCShare -ComputerName $ipRemota -Credential $cred
            if ($null -ne $drive) {
                $resPath = "${drive}:\Windows\Temp\clean_temp_quick_res.txt"
                if (Test-Path -LiteralPath $resPath) {
                    $rawRes = Get-Content -LiteralPath $resPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
                    if ($rawRes) {
                        $stats = @{}
                        $rawRes.Trim() -split '\|' | ForEach-Object {
                            $kv = $_ -split ':'
                            if ($kv.Length -eq 2) { $stats[$kv[0]] = $kv[1] }
                        }
                        $returnObj.Files = [int]$stats['Files']
                        $returnObj.Dirs = [int]$stats['Dirs']
                        $returnObj.MB = [double]$stats['MB']
                        $returnObj.Success = $true
                    }
                    Remove-Item -Path $resPath -Force -ErrorAction SilentlyContinue
                }
                Dismount-RemoteCShare -driveName $drive
            }
        }

        if (-not $Silent) {
            if ($returnObj.Success) {
                Write-Host "`n[OK] Limpieza remota de temporales finalizada exitosamente:" -ForegroundColor Green
                Write-Host "  -> Archivos eliminados : $($returnObj.Files)" -ForegroundColor White
                Write-Host "  -> Carpetas eliminadas : $($returnObj.Dirs)" -ForegroundColor White
                Write-Host "  -> Espacio liberado    : $($returnObj.MB) MB" -ForegroundColor Green
            } else {
                Write-Host "[ERROR] No se pudo completar la limpieza de temporales remota." -ForegroundColor Red
            }
        }
        return $returnObj
    }

    function Invoke-RemoteCleanProgramData {
        param(
            [Parameter(Mandatory=$true)]$ctx,
            [switch]$Silent
        )
        $ipRemota = $ctx.ComputerName
        $cred = $ctx.Credential
        
        if (-not $Silent) {
            Write-Host "Iniciando mantenimiento de ProgramData optimizado en $ipRemota..." -ForegroundColor Yellow
            Write-Host " > Modo acelerado: Poda selectiva de carpetas (evita traversing innecesario de Package Cache/Microsoft)..." -ForegroundColor Cyan
        }
        
        $remoteProgDataScript = @'
$excluirCarpetas = @("Microsoft", "Package Cache", "SoftwareLicensing", "Antivirus", "Windows Defender", "NVIDIA", "Docker", "Apple", "OEM", "Intel", "AMD")
$progData = "C:\ProgramData"
$dias = (Get-Date).AddDays(-7)
$exts = @(".tmp", ".log", ".bak", ".old", ".chk", ".temp")

$totalEliminados = 0
$totalBytes = [int64]0
$carpetasEscaneadas = 0

if (Test-Path -LiteralPath $progData) {
    # 1. Archivos en la raiz directa de ProgramData
    $rootFiles = Get-ChildItem -LiteralPath $progData -File -Force -ErrorAction SilentlyContinue
    foreach ($rf in $rootFiles) {
        if ($exts -contains $rf.Extension.ToLower() -and $rf.LastWriteTime -lt $dias) {
            try {
                $len = $rf.Length
                Remove-Item -LiteralPath $rf.FullName -Force -ErrorAction Stop
                $totalEliminados++
                $totalBytes += $len
            } catch {}
        }
    }

    # 2. Subdirectorios podando las exclusiones antes de entrar recursivamente
    $subDirs = Get-ChildItem -LiteralPath $progData -Directory -Force -ErrorAction SilentlyContinue
    foreach ($dir in $subDirs) {
        $omitir = $false
        foreach ($exc in $excluirCarpetas) {
            if ($dir.Name -like "*$exc*") { $omitir = $true; break }
        }
        if ($omitir) { continue }

        $carpetasEscaneadas++
        try {
            $files = Get-ChildItem -LiteralPath $dir.FullName -Recurse -File -Force -ErrorAction SilentlyContinue
            foreach ($f in $files) {
                if ($exts -contains $f.Extension.ToLower() -and $f.LastWriteTime -lt $dias) {
                    try {
                        $len = $f.Length
                        Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                        $totalEliminados++
                        $totalBytes += $len
                    } catch {}
                }
            }
        } catch {}
    }
}
$mb = [Math]::Round($totalBytes / 1MB, 2)
"Scanned:$carpetasEscaneadas|Deleted:$totalEliminados|MB:$mb" | Out-File -FilePath "C:\Windows\Temp\clean_progdata_res.txt" -Encoding UTF8 -Force
'@
        $res = Invoke-RemotePowerShellEncoded -ComputerName $ipRemota -Credential $cred -ScriptContent $remoteProgDataScript
        $returnObj = [PSCustomObject]@{ Scanned = 0; Deleted = 0; MB = 0.0; Success = $false }

        if ($res -and $res.ReturnValue -eq 0 -and $res.ProcessId) {
            $remotePid = $res.ProcessId
            $timeout = 30
            $elapsed = 0
            while ($elapsed -lt $timeout) {
                Start-Sleep -Seconds 1
                try {
                    if ($null -ne $cred) {
                        $proc = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -Credential $cred -ErrorAction SilentlyContinue
                    } else {
                        $proc = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -ErrorAction SilentlyContinue
                    }
                } catch { $proc = $null }
                if ($null -eq $proc) { break }
                $elapsed++
            }

            $drive = Mount-RemoteCShare -ComputerName $ipRemota -Credential $cred
            if ($null -ne $drive) {
                $resPath = "${drive}:\Windows\Temp\clean_progdata_res.txt"
                if (Test-Path -LiteralPath $resPath) {
                    $rawRes = Get-Content -LiteralPath $resPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
                    if ($rawRes) {
                        $stats = @{}
                        $rawRes.Trim() -split '\|' | ForEach-Object {
                            $kv = $_ -split ':'
                            if ($kv.Length -eq 2) { $stats[$kv[0]] = $kv[1] }
                        }
                        $returnObj.Scanned = [int]$stats['Scanned']
                        $returnObj.Deleted = [int]$stats['Deleted']
                        $returnObj.MB = [double]$stats['MB']
                        $returnObj.Success = $true
                    }
                    Remove-Item -Path $resPath -Force -ErrorAction SilentlyContinue
                }
                Dismount-RemoteCShare -driveName $drive
            }
        }

        if (-not $Silent) {
            if ($returnObj.Success) {
                Write-Host "`n[OK] Mantenimiento de ProgramData completado exitosamente:" -ForegroundColor Green
                Write-Host "  -> Carpetas analizadas : $($returnObj.Scanned)" -ForegroundColor White
                Write-Host "  -> Archivos obsoletos  : $($returnObj.Deleted)" -ForegroundColor White
                Write-Host "  -> Espacio liberado    : $($returnObj.MB) MB" -ForegroundColor Green
            } else {
                Write-Host "[ERROR] No se pudo completar el mantenimiento de ProgramData." -ForegroundColor Red
            }
        }
        return $returnObj
    }

    function Invoke-RemoteCleanRAM {
        param(
            [Parameter(Mandatory=$true)]$ctx,
            [switch]$Silent
        )
        $ipRemota = $ctx.ComputerName
        $cred = $ctx.Credential
        
        if (-not $Silent) {
            Write-Host "Optimizando memoria RAM en el equipo remoto $ipRemota..." -ForegroundColor Yellow
        }
        
        $remoteScriptContent = @'
$codigoC = "
    using System;
    using System.Runtime.InteropServices;
    public class RamUtil {
        [DllImport(\"psapi.dll\")]
        public static extern bool EmptyWorkingSet(IntPtr hProcess);
    }
"
if (-not ([System.Management.Automation.PSTypeName]"RamUtil").Type) {
    Add-Type -TypeDefinition $codigoC -ErrorAction SilentlyContinue
}
$procesos = [System.Diagnostics.Process]::GetProcesses()
$count = 0
foreach ($p in $procesos) {
    if ($p.Id -gt 4) {
        try {
            if ([RamUtil]::EmptyWorkingSet($p.Handle)) {
                $count++
            }
        } catch {}
    }
    if ($p) { $p.Dispose() }
}
Write-Output "Optimizado $count procesos."
'@
        $res = Invoke-RemotePowerShellEncoded -ComputerName $ipRemota -Credential $cred -ScriptContent $remoteScriptContent
        $success = ($res -and $res.ReturnValue -eq 0)
        if ($success) {
            Start-Sleep -Seconds 2
            if (-not $Silent) {
                Write-Host "[OK] Memoria RAM optimizada exitosamente en el equipo remoto $ipRemota." -ForegroundColor White -BackgroundColor DarkGreen
            }
        } else {
            if (-not $Silent) {
                Write-Host "[ERROR] No se pudo ejecutar la optimizacion de RAM remota." -ForegroundColor Red
            }
        }
        return [PSCustomObject]@{ Success = $success; ProcessId = if ($res) { $res.ProcessId } else { $null } }
    }

    function Invoke-RemoteCleanCPU {
        param(
            [Parameter(Mandatory=$true)]$ctx,
            [switch]$Silent
        )
        $ipRemota = $ctx.ComputerName
        $cred = $ctx.Credential
        
        if (-not $Silent) {
            Write-Host "Ajustando prioridad de procesos en el equipo remoto $ipRemota..." -ForegroundColor Yellow
        }
        
        $remoteScriptContent = @'
$procesosPesados = Get-Process | Sort-Object CPU -Descending | Select-Object -First 10
$count = 0
foreach ($proc in $procesosPesados) {
    if ($proc.Name -ne "Idle" -and $proc.Name -ne "powershell") {
        try {
            $proc.PriorityClass = "BelowNormal"
            $count++
        } catch {}
    }
}
[System.GC]::Collect()
Write-Output "Ajustada prioridad para $count procesos pesados."
'@
        $res = Invoke-RemotePowerShellEncoded -ComputerName $ipRemota -Credential $cred -ScriptContent $remoteScriptContent
        $success = ($res -and $res.ReturnValue -eq 0)
        if ($success) {
            Start-Sleep -Seconds 2
            if (-not $Silent) {
                Write-Host "[OK] Procesador y prioridades de tareas optimizadas en $ipRemota." -ForegroundColor White -BackgroundColor DarkGreen
            }
        } else {
            if (-not $Silent) {
                Write-Host "[ERROR] No se pudo ejecutar la optimizacion de CPU remota." -ForegroundColor Red
            }
        }
        return [PSCustomObject]@{ Success = $success; ProcessId = if ($res) { $res.ProcessId } else { $null } }
    }

    function Invoke-RemoteCleanRecycleBin {
        param(
            [Parameter(Mandatory=$true)]$ctx,
            [switch]$Silent
        )
        $ipRemota = $ctx.ComputerName
        $cred = $ctx.Credential
        
        if (-not $Silent) {
            Write-Host "Vaciando Papelera de Reciclaje remota en $ipRemota..." -ForegroundColor Yellow
        }
        
        $remoteRecycleScript = @'
try {
    if (Get-Command Clear-RecycleBin -ErrorAction SilentlyContinue) {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    }
} catch {}
cmd.exe /c "rd /s /q C:\`$Recycle.Bin" 2>&1 | Out-Null
'@
        $res = Invoke-RemotePowerShellEncoded -ComputerName $ipRemota -Credential $cred -ScriptContent $remoteRecycleScript
        $success = ($res -and $res.ReturnValue -eq 0)
        if ($success) {
            Start-Sleep -Seconds 2
            if (-not $Silent) {
                Write-Host "[OK] Papelera de reciclaje remota vaciada correctamente en $ipRemota." -ForegroundColor White -BackgroundColor DarkGreen
            }
        } else {
            if (-not $Silent) {
                Write-Host "[ERROR] No se pudo vaciar la papelera en el equipo remoto." -ForegroundColor Red
            }
        }
        return [PSCustomObject]@{ Success = $success; ProcessId = if ($res) { $res.ProcessId } else { $null } }
    }

    function Invoke-RemoteCleanAdvancedProfiles {
        param(
            [Parameter(Mandatory=$true)]$ctx,
            [switch]$Silent
        )
        $ipRemota = $ctx.ComputerName
        $cred = $ctx.Credential
        
        $drive = Mount-RemoteCShare -ComputerName $ipRemota -Credential $cred
        if ($null -eq $drive) {
            return [PSCustomObject]@{ TotalFiles = 0; TotalFolders = 0; TotalMB = 0.0; TotalErrors = 0; Success = $false }
        }

        if (-not $Silent) {
            Write-Host "Preparando ejecucion remota de limpieza profunda de temporales con desglose de usuarios..." -ForegroundColor Yellow
        }
        
        $remoteScriptContent = @'
$profilePaths = @()
try {
    # 1. Obtener perfiles de usuario locales y de dominio desde el Registro de Windows
    $profileKeys = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" -ErrorAction Stop
    foreach ($pk in $profileKeys) {
        $path = $pk.ProfileImagePath
        if ($path -and (Test-Path -LiteralPath $path)) {
            if ($path -notmatch "System32" -and $path -notmatch "ServiceProfiles") {
                if ($path -notin $profilePaths) {
                    $profilePaths += $path
                }
            }
        }
    }
}
catch {
    try {
        $profiles = Get-WmiObject -Class Win32_UserProfile -Filter "Special=False" -ErrorAction Stop
        foreach ($p in $profiles) {
            if ($p.LocalPath -and (Test-Path -LiteralPath $p.LocalPath)) {
                if ($p.LocalPath -notin $profilePaths) {
                    $profilePaths += $p.LocalPath
                }
            }
        }
    }
    catch {
        $fallbackPath = "C:\Users"
        if (Test-Path -LiteralPath $fallbackPath) {
            $folders = Get-ChildItem -LiteralPath $fallbackPath -Directory -ErrorAction SilentlyContinue
            foreach ($f in $folders) {
                if ($f.Name -notin "Default", "Default User", "All Users", "Public", "Publico") {
                    $profilePaths += $f.FullName
                }
            }
        }
    }
}

$report = @()
$global:progressData = @{}
$global:lastUpdate = [DateTime]::MinValue
$UserTimeoutSeconds = 30

function Write-ProgressFile {
    param([string]$currentUser, [string]$status)
    $now = Get-Date
    if (($now - $global:lastUpdate).TotalSeconds -lt 1 -and $status -ne "Done" -and $status -ne "Error" -and $status -notmatch "Timeout") {
        return
    }
    $global:lastUpdate = $now
    $lines = @()
    foreach ($u in $global:progressData.Keys) {
        $data = $global:progressData[$u]
        $lines += "User:$u|Path:$($data.Path)|Files:$($data.Files)|Folders:$($data.Folders)|Bytes:$($data.Bytes)|Status:$($data.Status)"
    }
    try {
        $lines | Out-File -FilePath "C:\Windows\Temp\clean_temp_progress.txt" -Encoding UTF8 -Force
    } catch {}
}

function Clear-FolderContents {
    param(
        [string]$FolderPath,
        [string]$userName,
        [ref]$errs,
        [DateTime]$userStartTime,
        [int]$timeoutSecs
    )
    if (-not (Test-Path -LiteralPath $FolderPath)) { return }
    $dirs = @()
    try {
        Get-ChildItem -LiteralPath $FolderPath -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Name -like "clean_temp_*") { return }
            if (((Get-Date) - $userStartTime).TotalSeconds -gt $timeoutSecs) { throw "UserFolderTimeout" }
            $item = $_
            if ($item.PSIsContainer) {
                $dirs += $item
            } else {
                $len = $item.Length
                try {
                    Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
                    $global:progressData[$userName].Files++
                    $global:progressData[$userName].Bytes += $len
                    Write-ProgressFile -currentUser $userName -status "In Progress"
                } catch { $errs.Value++ }
            }
        }
    }
    catch {
        if ($_.ToString() -match "UserFolderTimeout" -or $_.Exception.Message -match "UserFolderTimeout") {
            throw "UserFolderTimeout"
        }
        $errs.Value++
    }
    
    if ($dirs.Count -gt 0) {
        $sortedDirs = $dirs | Sort-Object -Property @{Expression={$_.FullName.Length}} -Descending
        foreach ($dir in $sortedDirs) {
            if (((Get-Date) - $userStartTime).TotalSeconds -gt $timeoutSecs) { throw "UserFolderTimeout" }
            try {
                Remove-Item -LiteralPath $dir.FullName -Force -Confirm:$false -ErrorAction Stop
                $global:progressData[$userName].Folders++
                Write-ProgressFile -currentUser $userName -status "In Progress"
            } catch { $errs.Value++ }
        }
    }
}

try {
    foreach ($path in $profilePaths) {
        $uName = Split-Path $path -Leaf
        $global:progressData[$uName] = @{
            Path    = $path
            Files   = 0
            Folders = 0
            Bytes   = [int64]0
            Status  = "Pending"
        }
    }
    $global:progressData["_SYSTEM_"] = @{
        Path    = "Sistema (Temp/Prefetch/Update/ServiceProfiles)"
        Files   = 0
        Folders = 0
        Bytes   = [int64]0
        Status  = "Pending"
    }
    Write-ProgressFile -currentUser "System" -status "Init"

    foreach ($path in $profilePaths) {
        $userName = Split-Path $path -Leaf
        $global:progressData[$userName].Status = "In Progress"
        Write-ProgressFile -currentUser $userName -status "In Progress"
        $uErrors = 0
        $userStartTime = Get-Date
        try {
            Clear-FolderContents -FolderPath (Join-Path $path "AppData\Local\Temp") -userName $userName -errs ([ref]$uErrors) -userStartTime $userStartTime -timeoutSecs $UserTimeoutSeconds
            Clear-FolderContents -FolderPath (Join-Path $path "AppData\LocalLow\Temp") -userName $userName -errs ([ref]$uErrors) -userStartTime $userStartTime -timeoutSecs $UserTimeoutSeconds
            Clear-FolderContents -FolderPath (Join-Path $path "AppData\Local\Microsoft\Windows\INetCache") -userName $userName -errs ([ref]$uErrors) -userStartTime $userStartTime -timeoutSecs $UserTimeoutSeconds
            Clear-FolderContents -FolderPath (Join-Path $path "AppData\Local\Microsoft\Windows\Temporary Internet Files") -userName $userName -errs ([ref]$uErrors) -userStartTime $userStartTime -timeoutSecs $UserTimeoutSeconds
            Clear-FolderContents -FolderPath (Join-Path $path "AppData\Local\CrashDumps") -userName $userName -errs ([ref]$uErrors) -userStartTime $userStartTime -timeoutSecs $UserTimeoutSeconds
            $global:progressData[$userName].Status = "Done"
            Write-ProgressFile -currentUser $userName -status "Done"
        }
        catch {
            if ($_.ToString() -match "UserFolderTimeout" -or $_.Exception.Message -match "UserFolderTimeout") {
                $global:progressData[$userName].Status = "Timeout"
                Write-ProgressFile -currentUser $userName -status "Timeout"
            } else {
                $global:progressData[$userName].Status = "Error"
                Write-ProgressFile -currentUser $userName -status "Error"
            }
        }
        $uData = $global:progressData[$userName]
        $report += "User:$userName|Path:$path|Files:$($uData.Files)|Folders:$($uData.Folders)|Bytes:$($uData.Bytes)|Errors:$uErrors|Status:$($uData.Status)"
    }
    
    $userName = "_SYSTEM_"
    $global:progressData[$userName].Status = "In Progress"
    Write-ProgressFile -currentUser $userName -status "In Progress"
    $sysErrors = 0
    $sysStartTime = Get-Date
    try {
        $systemPaths = @(
            "C:\Windows\Temp",
            "C:\Windows\Prefetch",
            "C:\Windows\SoftwareDistribution\Download",
            "C:\Windows\System32\config\systemprofile\AppData\Local\Temp",
            "C:\Windows\ServiceProfiles\LocalService\AppData\Local\Temp",
            "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Temp"
        )
        foreach ($sysPath in $systemPaths) {
            Clear-FolderContents -FolderPath $sysPath -userName $userName -errs ([ref]$sysErrors) -userStartTime $sysStartTime -timeoutSecs $UserTimeoutSeconds
        }
        $global:progressData[$userName].Status = "Done"
        Write-ProgressFile -currentUser $userName -status "Done"
    }
    catch {
        if ($_.ToString() -match "UserFolderTimeout" -or $_.Exception.Message -match "UserFolderTimeout") {
            $global:progressData[$userName].Status = "Timeout"
            Write-ProgressFile -currentUser $userName -status "Timeout"
        } else {
            $global:progressData[$userName].Status = "Error"
            Write-ProgressFile -currentUser $userName -status "Error"
        }
    }
    $sysData = $global:progressData[$userName]
    $report += "User:$userName|Path:$($sysData.Path)|Files:$($sysData.Files)|Folders:$($sysData.Folders)|Bytes:$($sysData.Bytes)|Errors:$sysErrors|Status:$($sysData.Status)"

    $outputPath = "C:\Windows\Temp\clean_temp_results.txt"
    $report | Out-File -FilePath $outputPath -Encoding UTF8 -Force
}
catch {
    $errPath = "C:\Windows\Temp\clean_temp_errors.txt"
    $_ | Out-File -FilePath $errPath -Encoding UTF8 -Force
}
'@
        $scriptBytes = [System.Text.Encoding]::Unicode.GetBytes($remoteScriptContent)
        $scriptBase64 = [Convert]::ToBase64String($scriptBytes)
        $cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand $scriptBase64"
        
        if (-not $Silent) {
            Write-Host "Ejecutando script de limpieza profunda en segundo plano..." -ForegroundColor Yellow
        }
        
        $totalFiles = 0
        $totalFolders = 0
        $totalBytes = [int64]0
        $totalErrors = 0
        $hasResults = $false

        try {
            if ($null -ne $cred) {
                $result = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $cmd -ComputerName $ipRemota -Credential $cred
            } else {
                $result = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $cmd -ComputerName $ipRemota
            }

            if ($result.ReturnValue -eq 0 -and $result.ProcessId) {
                $remotePid = $result.ProcessId
                if (-not $Silent) {
                    Write-Host "Proceso remoto iniciado exitosamente (PID: $remotePid)." -ForegroundColor Green
                    Write-Host "Realizando limpieza profunda en tiempo real (monitoreando progreso)...`n" -ForegroundColor Yellow
                }
                
                $timeout = 300
                $elapsed = 0
                $lastReport = @{}
                $progressFilePath = "${drive}:\Windows\Temp\clean_temp_progress.txt"
                
                while ($elapsed -lt $timeout) {
                    Start-Sleep -Seconds 2
                    $procCheck = $null
                    try {
                        if ($null -ne $cred) {
                            $procCheck = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -Credential $cred -ErrorAction Stop
                        } else {
                            $procCheck = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -ErrorAction Stop
                        }
                    } catch {
                        $procCheck = "SimulatedActive"
                    }
                    
                    if (Test-Path -LiteralPath $progressFilePath) {
                        try {
                            $progressContent = Get-Content -LiteralPath $progressFilePath -Encoding UTF8 -ErrorAction Stop
                            if ($progressContent) {
                                foreach ($line in $progressContent) {
                                    $parts = $line -split '\|'
                                    $stats = @{}
                                    foreach ($part in $parts) {
                                        if ($part -match "^([^:]+):(.*)$") {
                                            $stats[$Matches[1]] = $Matches[2]
                                        }
                                    }
                                    $uName = $stats["User"]
                                    $uPath = $stats["Path"]
                                    if (-not $uName) { continue }
                                    
                                    $uFiles = [int]$stats["Files"]
                                    $uFolders = [int]$stats["Folders"]
                                    $uBytes = [int64]$stats["Bytes"]
                                    $uStatus = $stats["Status"]
                                    
                                    $prev = $lastReport[$uName]
                                    if ($null -eq $prev -or $prev.Files -ne $uFiles -or $prev.Folders -ne $uFolders -or $prev.Status -ne $uStatus) {
                                        $mbUser = [Math]::Round($uBytes / 1MB, 2)
                                        $displayContext = if ($uName -eq "_SYSTEM_") { "Sistema (Temp/Prefetch/Update/ServiceProfiles)" } else { "Carpeta: $uPath (Usuario: $uName)" }
                                        
                                        if (-not $Silent) {
                                            if ($uStatus -eq "Done") {
                                                Write-Host " -> [COMPLETADO] $displayContext | Archivos: $uFiles | Carpetas: $uFolders | Liberado: $mbUser MB" -ForegroundColor Green
                                            } elseif ($uStatus -eq "Timeout") {
                                                Write-Host " -> [OMITIDO (TIMEOUT)] $displayContext | Archivos: $uFiles | Carpetas: $uFolders | Excedio limite 30s" -ForegroundColor Yellow
                                            } elseif ($uStatus -eq "Error") {
                                                Write-Host " -> [ERROR] $displayContext | Limpieza interrumpida" -ForegroundColor Red
                                            } elseif ($uStatus -eq "In Progress") {
                                                Write-Host " -> [PROGRESO] $displayContext | Archivos: $uFiles | Carpetas: $uFolders | Liberado: $mbUser MB..." -ForegroundColor Yellow
                                            }
                                        }
                                        $lastReport[$uName] = @{ Files = $uFiles; Folders = $uFolders; Status = $uStatus }
                                    }
                                }
                            }
                        } catch {}
                    }
                    if ($null -eq $procCheck) { break }
                    $elapsed += 2
                }

                $resultsPath = "${drive}:\Windows\Temp\clean_temp_results.txt"
                $errorsPath = "${drive}:\Windows\Temp\clean_temp_errors.txt"
                
                for ($i = 0; $i -lt 6; $i++) {
                    if (Test-Path -LiteralPath $resultsPath) { $hasResults = $true; break }
                    if (Test-Path -LiteralPath $errorsPath) { break }
                    Start-Sleep -Milliseconds 500
                }

                if ($hasResults) {
                    if (-not $Silent) {
                        Write-Host "`n--- DETALLE FINAL DE LIMPIEZA POR USUARIO ---" -ForegroundColor Cyan
                    }
                    Get-Content -Path $resultsPath | ForEach-Object {
                        $parts = $_ -split '\|'
                        $userStats = @{}
                        foreach ($part in $parts) {
                            if ($part -match "^([^:]+):(.*)$") {
                                $userStats[$Matches[1]] = $Matches[2]
                            }
                        }
                        $uName = $userStats["User"]
                        $uPath = $userStats["Path"]
                        $uFiles = [int]$userStats["Files"]
                        $uFolders = [int]$userStats["Folders"]
                        $uBytes = [int64]$userStats["Bytes"]
                        $uErrors = [int]$userStats["Errors"]
                        $uStatus = $userStats["Status"]
                        
                        $totalFiles += $uFiles
                        $totalFolders += $uFolders
                        $totalBytes += $uBytes
                        $totalErrors += $uErrors
                        
                        $mbUser = [Math]::Round($uBytes / 1MB, 2)
                        $displayContext = if ($uName -eq "_SYSTEM_") { "Sistema (Temp/Prefetch/Update/ServiceProfiles)" } else { "Carpeta: $uPath (Usuario: $uName)" }
                        
                        if (-not $Silent) {
                            $statusLabel = if ($uStatus -eq "Timeout") { " [OMITIDO POR TIMEOUT]" } else { "" }
                            $color = if ($uStatus -eq "Timeout") { "Yellow" } else { "White" }
                            Write-Host "[$displayContext]$statusLabel" -ForegroundColor $color
                            Write-Host "  -> Archivos eliminados: $uFiles" -ForegroundColor Green
                            Write-Host "  -> Carpetas eliminadas: $uFolders" -ForegroundColor Green
                            Write-Host "  -> Espacio liberado   : $mbUser MB" -ForegroundColor Green
                            Write-Host "  -> Errores/Bloqueados : $uErrors" -ForegroundColor Yellow
                            Write-Host ""
                        }
                    }
                    
                    $totalMBLiberados = [Math]::Round($totalBytes / 1MB, 2)
                    if (-not $Silent) {
                        Write-Host "-----------------------------------------------------------" -ForegroundColor Gray
                        Write-Host "RESUMEN GLOBAL DE LIMPIEZA MULTI-USUARIO REMOTA (AVANZADA):" -ForegroundColor Cyan
                        Write-Host "Total archivos eliminados: $totalFiles" -ForegroundColor White
                        Write-Host "Total carpetas eliminadas: $totalFolders" -ForegroundColor White
                        Write-Host "Total espacio liberado:    $totalMBLiberados MB" -ForegroundColor Green
                        Write-Host "Total errores/bloqueados:  $totalErrors" -ForegroundColor Yellow
                        Write-Host "-----------------------------------------------------------" -ForegroundColor Gray
                    }
                }
                
                Remove-Item -Path "${drive}:\Windows\Temp\clean_temp_results.txt" -Force -ErrorAction SilentlyContinue
                Remove-Item -Path "${drive}:\Windows\Temp\clean_temp_progress.txt" -Force -ErrorAction SilentlyContinue
                Remove-Item -Path "${drive}:\Windows\Temp\clean_temp_errors.txt" -Force -ErrorAction SilentlyContinue
                Dismount-RemoteCShare -driveName $drive
            } else {
                if (-not $Silent) {
                    Write-Host "[ERROR] El proceso remoto retorno un error: $($result.ReturnValue)" -ForegroundColor Red
                }
                Dismount-RemoteCShare -driveName $drive
            }
        }
        catch {
            if (-not $Silent) {
                Write-Host "[ERROR] Fallo la llamada WMI: $_" -ForegroundColor Red
            }
            Dismount-RemoteCShare -driveName $drive
        }

        return [PSCustomObject]@{
            TotalFiles   = $totalFiles
            TotalFolders = $totalFolders
            TotalMB      = [Math]::Round($totalBytes / 1MB, 2)
            TotalErrors  = $totalErrors
            Success      = $hasResults
        }
    }

    function Invoke-RemoteCleanGeneral {
        param(
            [Parameter(Mandatory=$true)]$ctx
        )
        $ipRemota = $ctx.ComputerName
        $swMaster = [System.Diagnostics.Stopwatch]::StartNew()
        
        Write-Host "`n==========================================================================" -ForegroundColor Cyan
        Write-Host "   INICIANDO LIMPIEZA GENERAL Y MANTENIMIENTO INTEGRAL EN $ipRemota" -ForegroundColor Yellow
        Write-Host "==========================================================================" -ForegroundColor Cyan
        
        # 1. Liberar RAM
        Write-Host "`n[FASE 1/6] Optimizando Memoria RAM..." -ForegroundColor Yellow
        $resRAM = Invoke-RemoteCleanRAM -ctx $ctx -Silent
        if ($resRAM.Success) {
            Write-Host "  -> Memoria RAM optimizada exitosamente (API EmptyWorkingSet)." -ForegroundColor Green
        } else {
            Write-Host "  -> [AVISO] No se pudo optimizar la RAM." -ForegroundColor Yellow
        }

        # 2. Liberar CPU
        Write-Host "`n[FASE 2/6] Optimizando Procesador y Prioridades..." -ForegroundColor Yellow
        $resCPU = Invoke-RemoteCleanCPU -ctx $ctx -Silent
        if ($resCPU.Success) {
            Write-Host "  -> Prioridades de procesos pesados ajustadas a BelowNormal." -ForegroundColor Green
        } else {
            Write-Host "  -> [AVISO] No se pudo ajustar la prioridad de CPU." -ForegroundColor Yellow
        }

        # 3. Limpiar Temporales de Carpetas (Windows Temp, Prefetch, Temp usuario activo)
        Write-Host "`n[FASE 3/6] Limpiando Archivos Temporales de Carpetas del Sistema..." -ForegroundColor Yellow
        $resTemp = Invoke-RemoteCleanTempFolders -ctx $ctx -Silent
        if ($resTemp.Success) {
            Write-Host "  -> Archivos eliminados : $($resTemp.Files)" -ForegroundColor White
            Write-Host "  -> Carpetas eliminadas : $($resTemp.Dirs)" -ForegroundColor White
            Write-Host "  -> Espacio liberado    : $($resTemp.MB) MB" -ForegroundColor Green
        } else {
            Write-Host "  -> [AVISO] No se pudo completar la limpieza de temporales de carpetas." -ForegroundColor Yellow
        }

        # 4. Limpieza de ProgramData (Poda selectiva)
        Write-Host "`n[FASE 4/6] Mantenimiento de Archivos Temporales en ProgramData..." -ForegroundColor Yellow
        $resProg = Invoke-RemoteCleanProgramData -ctx $ctx -Silent
        if ($resProg.Success) {
            Write-Host "  -> Carpetas analizadas : $($resProg.Scanned)" -ForegroundColor White
            Write-Host "  -> Archivos obsoletos  : $($resProg.Deleted)" -ForegroundColor White
            Write-Host "  -> Espacio liberado    : $($resProg.MB) MB" -ForegroundColor Green
        } else {
            Write-Host "  -> [AVISO] No se pudo completar la limpieza de ProgramData." -ForegroundColor Yellow
        }

        # 5. Vaciar Papelera de Reciclaje
        Write-Host "`n[FASE 5/6] Vaciando Papelera de Reciclaje Remota..." -ForegroundColor Yellow
        $resRecycle = Invoke-RemoteCleanRecycleBin -ctx $ctx -Silent
        if ($resRecycle.Success) {
            Write-Host "  -> Papelera de reciclaje vaciada para todos los usuarios." -ForegroundColor Green
        } else {
            Write-Host "  -> [AVISO] No se pudo vaciar la papelera." -ForegroundColor Yellow
        }

        # 6. Limpieza Avanzada Multi-Usuario (Perfiles)
        Write-Host "`n[FASE 6/6] Limpieza Avanzada de Temporales (Todos los Usuarios)..." -ForegroundColor Yellow
        $resAdv = Invoke-RemoteCleanAdvancedProfiles -ctx $ctx
        
        $swMaster.Stop()
        $totalDuracion = [Math]::Round($swMaster.Elapsed.TotalSeconds, 2)
        $advFiles = 0
        $advDirs = 0
        $advMB = 0.0
        if ($resAdv) {
            $advFiles = $resAdv.TotalFiles
            $advDirs = $resAdv.TotalFolders
            $advMB = $resAdv.TotalMB
        }
        $granTotalArchivos = $resTemp.Files + $resProg.Deleted + $advFiles
        $granTotalCarpetas = $resTemp.Dirs + $advDirs
        $granTotalMB = [Math]::Round($resTemp.MB + $resProg.MB + $advMB, 2)

        Write-Host "`n==========================================================================" -ForegroundColor Green
        Write-Host "   RESUMEN MAESTRO: LIMPIEZA GENERAL COMPLETADA EN $ipRemota" -ForegroundColor White -BackgroundColor DarkGreen
        Write-Host "==========================================================================" -ForegroundColor Green
        Write-Host ("  Total Archivos Eliminados : {0}" -f $granTotalArchivos) -ForegroundColor White
        Write-Host ("  Total Carpetas Eliminadas : {0}" -f $granTotalCarpetas) -ForegroundColor White
        Write-Host ("  Total Espacio Liberado    : {0} MB" -f $granTotalMB) -ForegroundColor Green
        Write-Host ("  Tiempo Total Transcurrido : {0} segundos" -f $totalDuracion) -ForegroundColor Cyan
        Write-Host "==========================================================================" -ForegroundColor Green
    }

    function Ejecutar-DefragRemoto {
        param(
            [string]$ipRemota,
            $cred,
            [string]$driveLetter
        )

        $drive = Mount-RemoteCShare -ComputerName $ipRemota -Credential $cred
        if ($null -eq $drive) {
            return
        }

        # 1. Crear el script de desfragmentación remota
        $remoteScriptContent = @'
param(
    [string]$DriveLetter = "C"
)
$DriveLetter = $DriveLetter.Replace(":", "").Trim().ToUpper()

# Deteccion de tipo de disco (HDD vs SSD)
$mediaType = "HDD"
try {
    $partition = Get-WmiObject -Class Win32_LogicalDiskToPartition | Where-Object { $_.Dependent -match "${DriveLetter}:" }
    $partDeviceID = $partition.Antecedent.Split('=')[1].Trim('"')
    
    if ($partDeviceID -match "Disk #(\d+)") {
        $diskIndex = [int]$Matches[1]
        
        $diskDrive = Get-WmiObject -Class Win32_DiskDrive | Where-Object { $_.Index -eq $diskIndex }
        
        # Intentar MSFT_PhysicalDisk para MediaType preciso
        try {
            $physDisk = Get-CimInstance -Namespace Root\Microsoft\Windows\Storage -ClassName MSFT_PhysicalDisk -Filter "DeviceId = '$diskIndex'" -ErrorAction Stop
            if ($physDisk.MediaType -eq 4) {
                $mediaType = "SSD"
            } elseif ($physDisk.MediaType -eq 3) {
                $mediaType = "HDD"
            }
        }
        catch {
            # Fallback en base al modelo del disco
            if ($diskDrive.Model -match "SSD|NVME|Solid State|Flash") {
                $mediaType = "SSD"
            }
        }
    }
}
catch {}

Write-Output "Tipo de Soporte Detectado para unidad ${DriveLetter}:: $mediaType"

if ($mediaType -eq "SSD") {
    Write-Output "Iniciando optimizacion SSD (Trim/ReTrim) en unidad ${DriveLetter}:..."
    if (Get-Command Optimize-Volume -ErrorAction SilentlyContinue) {
        Optimize-Volume -DriveLetter $DriveLetter -ReTrim -Verbose
    } else {
        defrag.exe ${DriveLetter}: /O /U /V /H
    }
} else {
    Write-Output "Iniciando desfragmentacion HDD en unidad ${DriveLetter}:..."
    defrag.exe ${DriveLetter}: /U /V /H
}
Write-Output "Proceso de optimizacion completado con exito."
'@

        $remoteScriptPath = "${drive}:\Windows\Temp\defrag_remote.ps1"
        $logPath = "${drive}:\Windows\Temp\defrag_remote.log"
        
        # Eliminar log anterior si existe
        if (Test-Path $logPath) {
            Remove-Item -Path $logPath -Force -ErrorAction SilentlyContinue
        }

        try {
            $remoteScriptContent | Out-File -FilePath $remoteScriptPath -Encoding ascii -Force -ErrorAction Stop
            Write-Host "Script de desfragmentacion copiado al equipo remoto." -ForegroundColor Green
        }
        catch {
            Write-Host "[ERROR] No se pudo copiar el script de desfragmentacion: $_" -ForegroundColor Red
            Dismount-RemoteCShare -driveName $drive
            return
        }

        # 2. Iniciar el proceso remoto en segundo plano usando cmd.exe para redirigir la salida
        $cmd = "cmd.exe /c `"powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Windows\Temp\defrag_remote.ps1 -DriveLetter $driveLetter > C:\Windows\Temp\defrag_remote.log 2>&1`""
        Write-Host "Iniciando desfragmentacion/optimizacion en el equipo remoto..." -ForegroundColor Yellow

        try {
            if ($null -ne $cred) {
                $result = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $cmd -ComputerName $ipRemota -Credential $cred
            }
            else {
                $result = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $cmd -ComputerName $ipRemota
            }

            if ($result.ReturnValue -eq 0 -and $result.ProcessId) {
                $remotePid = $result.ProcessId
                Write-Host "Proceso remoto iniciado exitosamente (PID: $remotePid)." -ForegroundColor Green
                Write-Host "----------------------------------------------------------------------" -ForegroundColor Gray
                Write-Host "Monitoreando progreso en tiempo real..." -ForegroundColor Cyan
                Write-Host "Presione la tecla 'Q' en cualquier momento para enviarlo a segundo plano." -ForegroundColor Yellow
                Write-Host "----------------------------------------------------------------------" -ForegroundColor Gray

                $elapsed = 0
                $finished = $false
                $aborted = $false
                $lastLineCount = 0
                $maxTimeout = 3600  # 1 hora maximo de seguridad

                while ($elapsed -lt $maxTimeout) {
                    Start-Sleep -Milliseconds 1500
                    $elapsed += 1.5

                    # Verificar estado del proceso
                    if ($null -ne $cred) {
                        $procCheck = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -Credential $cred -ErrorAction SilentlyContinue
                    }
                    else {
                        $procCheck = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -ErrorAction SilentlyContinue
                    }

                    # Leer y emitir contenido nuevo del log
                    if (Test-Path $logPath) {
                        try {
                            $lines = Get-Content -Path $logPath -ErrorAction SilentlyContinue
                            if ($lines -and $lines.Count -gt $lastLineCount) {
                                for ($i = $lastLineCount; $i -lt $lines.Count; $i++) {
                                    Write-Host $lines[$i] -ForegroundColor Gray
                                }
                                $lastLineCount = $lines.Count
                            }
                        } catch {}
                    }

                    # Finalizar si el proceso ya no existe
                    if ($null -eq $procCheck) {
                        $finished = $true
                        break
                    }

                    # Detectar si el usuario pulso la tecla Q
                    if ($Host.UI.RawUI.KeyAvailable) {
                        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp,IncludeKeyDown")
                        if ($key.Character -eq 'q' -or $key.Character -eq 'Q') {
                            $aborted = $true
                            break
                        }
                    }
                }

                if ($finished) {
                    Write-Host "----------------------------------------------------------------------" -ForegroundColor Gray
                    Write-Host "[OK] Optimizacion remota finalizada exitosamente." -ForegroundColor Green
                    
                    # Limpiar archivos temporales
                    Remove-Item -Path $logPath -Force -ErrorAction SilentlyContinue
                    Remove-Item -Path $remoteScriptPath -Force -ErrorAction SilentlyContinue
                }
                elseif ($aborted) {
                    Write-Host "----------------------------------------------------------------------" -ForegroundColor Gray
                    Write-Host "[!] Monitoreo cancelado por el usuario." -ForegroundColor Yellow
                    Write-Host "El proceso continuara ejecutandose de forma silenciosa en segundo plano (PID: $remotePid)." -ForegroundColor Green
                    Write-Host "Los archivos de registro se conservaran en C:\Windows\Temp\" -ForegroundColor Gray
                }
                else {
                    Write-Host "----------------------------------------------------------------------" -ForegroundColor Gray
                    Write-Host "[!] Se alcanzo el tiempo limite de monitoreo local." -ForegroundColor Yellow
                    Write-Host "El proceso sigue ejecutandose en el equipo remoto (PID: $remotePid)." -ForegroundColor Green
                }
            }
            else {
                Write-Host "[ERROR] El proceso remoto retorno un error: $($result.ReturnValue)" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "[ERROR] Fallo la llamada WMI para crear el proceso: $_" -ForegroundColor Red
        }
        finally {
            Dismount-RemoteCShare -driveName $drive
        }
    }

    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header " 25. +++)) AD: COMANDOS RED - ADMINISTRACION REMOTA +++++"
            Write-Host "  1. Mostrar Hostname y MAC x IP."
            Write-Host "    1.1 Mostrar direccion IP de PC REMOTO."
            Write-Host "    1.2 Asignar direccion IP fija a PC REMOTO."
            Write-Host "    1.3 Asignar direccion AUTOMATICA, IP DHCP A PC REMOTO."
            Write-Host "    1.4 || MOSTRAR || INTERFACES de RED - en PC REMOTO." -ForegroundColor Cyan
            Write-Host "    1.5 || DESHABILITAR || INTERFACES de RED - en PC REMOTO." -ForegroundColor Green
            Write-Host "    1.6 || HABILITAR || INTERFACES de RED - en PC REMOTO." -ForegroundColor Green
            Write-Host "    1.7 || DESHABILITAR || ZONA CUBIERTA MOVIL - en PC REMOTO." -ForegroundColor Yellow
            Write-Host "    1.8 || HABILITAR || ZONA CUBIERTA MOVIL - en PC REMOTO." -ForegroundColor Yellow
            Write-Host "    1.9 || HABILITAR || WMI, RPC y PSRemoting - en PC REMOTO." -ForegroundColor Green
            Write-Host "  2. Red Grupo de Trabajo y/o Dominio"
            Write-Host "    2.1 Listar Equipos de un Dominio (todo el segmento)"
            Write-Host "    2.2 Auditoria y Deteccion de Equipos en Red (Nueva Ventana)" -ForegroundColor Cyan
            Write-Host "  3. Reinciar PC remotamente." -ForegroundColor Green
            Write-Host "  4. Apagar PC Remotamente." -ForegroundColor Yellow
            Write-Host "  5. Escritorio Publico PC Remoto." -ForegroundColor Cyan
            Write-Host "  6. Carpeta Boot Inicio PC Remoto."
            Write-Host "  7. Abrir CMD remoto con PsTools."
            Write-Host "  8. Abrir PowerShell remoto con PsTools."
            Write-Host "  9. OPCIONES DE PANEL DE CONTROL"
            Write-Host "    9.1 Modificar Opciones de Energia" -ForegroundColor Cyan
            Write-Host "  ----------------------------------------"
            Write-Host "  10. Impresoras DISPONIBLES en PC Remota."
            Write-Host "    10.1 Impresora HABILITADO en PC REMOTA" -ForegroundColor Cyan
            Write-Host "    10.2 Mostrar Impresoras con P.S. en PC Remota."
            Write-Host "  ----------------------------------------"
            Write-Host "  11. Habilitacion de RSAT - LOCAL"
            Write-Host "    11.1 Habilitar servicios RSAT y ejecucion remota (Local)" -ForegroundColor Cyan
            Write-Host "    11.2 Denegar/Deshabilitar ejecucion remota (Local)" -ForegroundColor Yellow
            Write-Host "    11.3 Instalar todos los componentes de RSAT (Local)" -ForegroundColor Green
            Write-Host "  ----------------------------------------"
            Write-Host "  12. Habilitacion de RSAT - REMOTO"
            Write-Host "    12.1 Habilitar servicios RSAT y ejecucion remota (Remoto)" -ForegroundColor Cyan
            Write-Host "    12.2 Denegar/Deshabilitar ejecucion de scripts (Remoto)" -ForegroundColor Yellow
            Write-Host "    12.3 Instalar componentes de RSAT (Remoto)" -ForegroundColor Green
            Write-Host "  ----------------------------------------"
            Write-Host "  13. OPTIMIZACION Y LIMPIEZA DE SISTEMA REMOTO:" -ForegroundColor Green
            Write-Host "    13.1. Eliminar Archivos TEMPORALES CARPETAS Remoto" -ForegroundColor DarkCyan
            Write-Host "    13.2. Eliminar Archivos Temporales ProgramData Remoto" -ForegroundColor DarkCyan
            Write-Host "    13.3. Liberar RAM Remoto" -ForegroundColor DarkCyan
            Write-Host "    13.4. Liberar Procesador Remoto" -ForegroundColor DarkCyan
            Write-Host "    13.5. Vaciar Papelera de Reciclaje Remoto" -ForegroundColor DarkCyan
            Write-Host "    13.6. Eliminacion avanzada de temporales (Todos los usuarios) Remoto" -ForegroundColor Yellow
            Write-Host "    13.7. Limpieza General de Archivos en PC Remoto" -ForegroundColor Cyan
            Write-Host "  ----------------------------------------"
            Write-Host "  14. defragmentacion PC Remoto" -ForegroundColor Cyan
            Write-Host "    14.1 Desfragmentar Unidad C: (Principal)" -ForegroundColor DarkCyan
            Write-Host "    14.2 Desfragmentar Otras Unidades" -ForegroundColor DarkCyan
            Write-Host "  ----------------------------------------"
            Write-Host "  30. REFRESH." -ForegroundColor Red
            Write-Host "  31. REFRESH DESDE GITHUB (ONLINE)." -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Header "==============================================================="
            
            $op25 = Read-Host "Seleccione la tarea a realizar"

            switch ($op25) {
                "1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # 1. Solicitar IP estandarizada (IP completa o 2 ultimos octetos)
                    $IPCompleta = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($IPCompleta)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    Write-Host "`nConsultando informacion de red para: $IPCompleta" -ForegroundColor Cyan

                    # 3. Ejecutar nbtstat
                    # Se usa --% para asegurar que los argumentos se pasen correctamente en versiones antiguas
                    nbtstat -a $IPCompleta



                    Write-Host "-------------------------------------------------------" -ForegroundColor Cyan
                    Write-Host "FINALIZADO" -ForegroundColor Cyan
                    Write-Host " "
                    
                    Read-Host "Presione ENTER para continuar..."

                }

                "1.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # 1. Entrada de datos estandarizada
                    $ipRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($ipRemota)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    Write-Host "`n--- Consultando informacion de red para $ipRemota... ---" -ForegroundColor Yellow

                    # A. Ping rapido (.NET Ping con timeout 800ms)
                    $pingOk = $false
                    try {
                        $pObj = New-Object System.Net.NetworkInformation.Ping
                        $r = $pObj.Send($ipRemota, 800)
                        if ($r.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                            $pingOk = $true
                        }
                    } catch {}
                    if (-not $pingOk) {
                        Write-Warning "El equipo $ipRemota no respondio a ping (Timeout 800ms). Es posible que este apagado o tenga firewall activo."
                    }

                    # B. Resolucion de MAC via ARP / Get-NetNeighbor
                    $macRemota = ""
                    try {
                        $neighbor = Get-NetNeighbor -IPAddress $ipRemota -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
                        if ($neighbor -and $neighbor.LinkLayerAddress) {
                            $macRemota = $neighbor.LinkLayerAddress.ToUpper().Replace("-", ":")
                        }
                    } catch {}
                    if ([string]::IsNullOrEmpty($macRemota)) {
                        try {
                            $arpLines = arp -a $ipRemota
                            foreach ($al in $arpLines) {
                                if ($al -match '([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}') {
                                    $macRemota = $Matches[0].ToUpper().Replace("-", ":")
                                    break
                                }
                            }
                        } catch {}
                    }
                    if ([string]::IsNullOrEmpty($macRemota)) { $macRemota = "No disponible" }

                    # C. Resolucion de Hostname (DNS Asincrono no bloqueante + Fallback NetBIOS)
                    $computerTarget = $ipRemota
                    $resolvedHost = ""
                    Write-Host "[*] Resolviendo Hostname de $ipRemota..." -ForegroundColor Gray
                    try {
                        $asyncDns = [System.Net.Dns]::BeginGetHostEntry($ipRemota, $null, $null)
                        if ($asyncDns.AsyncWaitHandle.WaitOne(400, $false)) {
                            $entry = [System.Net.Dns]::EndGetHostEntry($asyncDns)
                            if ($entry -and $entry.HostName) {
                                $resolvedHost = $entry.HostName.Split('.')[0]
                                $computerTarget = $resolvedHost
                                Write-Host "[+] Hostname resuelto via DNS: $computerTarget (Kerberos habilitado)" -ForegroundColor Green
                            }
                        }
                    } catch {}

                    if ([string]::IsNullOrEmpty($resolvedHost)) {
                        try {
                            $nbt = nbtstat -a $ipRemota 2>$null
                            $lineaName = $nbt | Where-Object { $_ -match "<\x00>.*UNIQUE" } | Select-Object -First 1
                            if ($lineaName -and $lineaName -match "^\s*([A-Za-z0-9\-]+)") {
                                $resolvedHost = $Matches[1].Trim()
                                $computerTarget = $resolvedHost
                                Write-Host "[+] Hostname resuelto via NetBIOS: $computerTarget" -ForegroundColor Green
                            }
                        } catch {}
                    }

                    if ([string]::IsNullOrEmpty($resolvedHost)) {
                        Write-Host "[-] No se pudo resolver Hostname. Usando IP directamente ($ipRemota)." -ForegroundColor Yellow
                    }

                    # D. Sondeo Rapido de Dispositivo y Clasificacion (< 800 ms)
                    Write-Host "[*] Identificando perfil y servicios del equipo..." -ForegroundColor Gray
                    $devProfile = Get-NetworkDeviceProfile -TargetIP $ipRemota -HostName $computerTarget -MACAddress $macRemota
                    if ($devProfile.EffectiveHost -and $devProfile.EffectiveHost -ne $ipRemota) {
                        $computerTarget = $devProfile.EffectiveHost
                    }

                    # =========================================================================
                    # CASO A: EL EQUIPO NO ES UNA COMPUTADORA (Impresora, Switch, Camara, etc.)
                    # =========================================================================
                    if (-not $devProfile.IsComputer) {
                        Write-Host "`n===========================================================" -ForegroundColor Cyan
                        Write-Host "        DISPOSITIVO DE RED DETECTADO (NO ES UNA PC)        " -ForegroundColor Cyan
                        Write-Host "===========================================================" -ForegroundColor Cyan
                        Write-Host ""
                        Write-Host "  Tipo de Dispositivo:  " -NoNewline
                        Write-Host "$($devProfile.DeviceType)" -ForegroundColor Green
                        Write-Host "  Direccion IP:         " -NoNewline
                        Write-Host "$ipRemota" -ForegroundColor Yellow
                        Write-Host "  Nombre de Host:       " -NoNewline
                        $hDisplay = if ($computerTarget -and $computerTarget -ne $ipRemota) { $computerTarget } else { "(Sin Hostname registrado)" }
                        Write-Host "$hDisplay" -ForegroundColor Yellow
                        Write-Host "  Direccion MAC:        " -NoNewline
                        Write-Host "$macRemota" -ForegroundColor Yellow
                        Write-Host "  Fabricante (OUI):     " -NoNewline
                        Write-Host "$($devProfile.Manufacturer)" -ForegroundColor Cyan
                        
                        $portsStr = if ($devProfile.OpenPorts.Count -gt 0) { $devProfile.OpenPorts -join ", " } else { "Ningun puerto estandar responde (Posible bloqueo o filtrado)" }
                        Write-Host "  Servicios / Puertos:  " -NoNewline
                        Write-Host "$portsStr" -ForegroundColor Gray

                        if ($devProfile.SnmpData -and $devProfile.SnmpData.SysDescr) {
                            Write-Host "  Descripcion SNMP:     " -NoNewline
                            Write-Host "$($devProfile.SnmpData.SysDescr)" -ForegroundColor White
                        }
                        if ($devProfile.SnmpData -and $devProfile.SnmpData.SysName) {
                            Write-Host "  Nombre SNMP (sysName):" -NoNewline
                            Write-Host "$($devProfile.SnmpData.SysName)" -ForegroundColor White
                        }

                        $estadoEnlace = if ($pingOk -or $devProfile.OpenPorts.Count -gt 0 -or $macRemota -ne "No disponible") { "En linea / Activo en la red" } else { "Inaccesible / Desconectado" }
                        Write-Host "  Estado de Conexion:   " -NoNewline
                        Write-Host "$estadoEnlace" -ForegroundColor Green
                        Write-Host "===========================================================`n" -ForegroundColor Cyan

                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    # =========================================================================
                    # CASO B: EL EQUIPO ES UNA COMPUTADORA (Windows PC / Servidor / Workgroup)
                    # =========================================================================
                    Write-Host "[+] Computadora detectada ($($devProfile.DeviceType)). Iniciando conexion WMI..." -ForegroundColor Cyan

                    # Gestion de Credenciales y reintentos para Dominio / Grupo de Trabajo
                    $sys = $null
                    $cred = $null
                    $targetWmi = if ($resolvedHost) { $resolvedHost } else { $ipRemota }
                    $reintentarConCred = $true
                    $credProporcionada = $null

                    if ($global:RemoteTargetIP -eq $ipRemota -and $global:RemoteTargetCred -ne $null) {
                        $credProporcionada = $global:RemoteTargetCred
                    }

                    while ($reintentarConCred) {
                        $reintentarConCred = $false
                        try {
                            if ($cred) {
                                $sys = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $targetWmi -Credential $cred -ErrorAction Stop
                            } else {
                                $sys = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $targetWmi -ErrorAction Stop
                            }
                        }
                        catch {
                            $errMsg = $_.Exception.Message
                            $esAccesoDenegado = ($errMsg -match "Acceso denegado" -or $errMsg -match "Access is denied" -or $errMsg -match "0x80070005")
                            $esRpcNoDisponible = ($errMsg -match "RPC" -or $errMsg -match "0x800706BA" -or $errMsg -match "no disponible")

                            if ($esAccesoDenegado) {
                                Write-Host "`n[!] ERROR DE AUTENTICACION: Acceso denegado (0x80070005)" -ForegroundColor Red
                                Write-Host "    El equipo $ipRemota ($computerTarget) rechazo las credenciales actuales." -ForegroundColor Yellow
                                Write-Host "    Causa habitual: El equipo se encuentra en un GRUPO DE TRABAJO (Workgroup)" -ForegroundColor Yellow
                                Write-Host "    o requiere una cuenta de administrador local especifica (ej: .\Administrador).`n" -ForegroundColor Yellow

                                if ($credProporcionada) {
                                    $resp = Read-Host "¿Desea reintentar usando las credenciales guardadas para $ipRemota? (S/N) [S]"
                                    if ($resp -eq "" -or $resp.ToUpper() -eq "S") {
                                        $cred = $credProporcionada
                                        $reintentarConCred = $true
                                        $credProporcionada = $null
                                        $targetWmi = $ipRemota
                                        Enable-LocalTrustedHostsConfig
                                        Write-Host "[*] Reintentando conexion con credenciales guardadas..." -ForegroundColor Cyan
                                        continue
                                    }
                                }

                                $respIngresar = Read-Host "¿Desea ingresar credenciales para autenticar en $ipRemota? (S/N) [S]"
                                if ($respIngresar -eq "" -or $respIngresar.ToUpper() -eq "S") {
                                    Write-Host "Ingrese credenciales para $ipRemota (ej: .\Administrador o DOMINIO\Usuario):" -ForegroundColor Cyan
                                    $rawCred = Get-Credential
                                    if ($rawCred) {
                                        $uName = $rawCred.UserName
                                        if ($uName -notmatch '\\' -and $uName -notmatch '@') {
                                            $fixedUser = ".\$uName"
                                            $cred = New-Object System.Management.Automation.PSCredential($fixedUser, $rawCred.Password)
                                        } else {
                                            $cred = $rawCred
                                        }
                                        $global:RemoteTargetIP = $ipRemota
                                        $global:RemoteTargetCred = $cred
                                        $targetWmi = $ipRemota
                                        $reintentarConCred = $true
                                        Enable-LocalTrustedHostsConfig
                                        Write-Host "[*] Reintentando conexion con credenciales suministradas..." -ForegroundColor Cyan
                                        continue
                                    }
                                }
                            }
                            elseif ($esRpcNoDisponible) {
                                Write-Host "`n[!] ERROR DE COMUNICACION: Servidor RPC no disponible (0x800706BA)" -ForegroundColor Red
                                Write-Host "    El equipo remoto tiene bloqueado WMI/RPC en el Firewall de Windows" -ForegroundColor Yellow
                                Write-Host "    o los servicios de administracion remota estan detenidos.`n" -ForegroundColor Yellow

                                $respHab = Read-Host "¿Desea intentar HABILITAR WMI, RPC y Firewall en $ipRemota ahora? (S/N) [S]"
                                if ($respHab -eq "" -or $respHab.ToUpper() -eq "S") {
                                    if ($cred) {
                                        $usu = $cred.UserName
                                        $pass = $cred.GetNetworkCredential().Password
                                        psHabilitarAdministracionRemota -targetInput $ipRemota -username $usu -passwordText $pass
                                    } else {
                                        psHabilitarAdministracionRemota -targetInput $ipRemota
                                    }
                                    Write-Host "[*] Esperando 3 segundos y reintentando conexion..." -ForegroundColor Cyan
                                    Start-Sleep -Seconds 3
                                    $reintentarConCred = $true
                                    continue
                                }
                            }
                            else {
                                Write-Host "ERROR: No se pudo establecer conexion con $ipRemota ($computerTarget)." -ForegroundColor Red
                                Write-Host "Detalle: $($errMsg)" -ForegroundColor Gray
                            }
                        }
                    }

                    if (-not $sys) {
                        Write-Host "`nNo fue posible recuperar los datos del equipo remoto." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    # Funcion de consulta WMI segura utilizando credenciales si estan disponibles
                    function Get-SubMenuWmiSafe {
                        param(
                            [string]$Class,
                            [string]$Filter = $null,
                            [switch]$SilentlyContinue
                        )
                        $p = @{
                            Class        = $Class
                            ComputerName = $targetWmi
                        }
                        if ($cred) { $p["Credential"] = $cred }
                        if ($Filter) { $p["Filter"] = $Filter }
                        if ($SilentlyContinue) {
                            $p["ErrorAction"] = "SilentlyContinue"
                        } else {
                            $p["ErrorAction"] = "Stop"
                        }
                        return (Get-WmiObject @p)
                    }

                    try {
                        $marca = if ($sys.Manufacturer) { $sys.Manufacturer.Trim() } else { "Desconocido" }
                        $modelo = if ($sys.Model) { $sys.Model.Trim() } else { "Desconocido" }

                        # Dominio / Grupo de trabajo
                        $redGrupo = ""
                        if ($sys.PartOfDomain) {
                            $redGrupo = "Dominio: $($sys.Domain)"
                        } else {
                            $redGrupo = "Grupo de Trabajo: $($sys.Domain)"
                        }

                        $os = Get-SubMenuWmiSafe -Class Win32_OperatingSystem -SilentlyContinue
                        $osName = if ($os -and $os.Caption) { $os.Caption.Trim() } else { "Windows (Desconocido)" }
                        $osVer = if ($os -and $os.Version) { $os.Version.Trim() } else { "" }
                        $osArch = if ($os -and $os.OSArchitecture) { $os.OSArchitecture.Trim() } else { "" }
                        $osDisplay = $osName
                        if ($osVer) { $osDisplay += " ($osVer)" }
                        if ($osArch) { $osDisplay += " $osArch" }

                        # Microprocesador (CPU)
                        $cpu = Get-SubMenuWmiSafe -Class Win32_Processor -SilentlyContinue | Select-Object -First 1
                        $cpuName = if ($cpu -and $cpu.Name) { $cpu.Name.Trim() } else { "Desconocido" }

                        # Memoria RAM
                        $ramSum = (Get-SubMenuWmiSafe -Class Win32_PhysicalMemory -SilentlyContinue | Measure-Object -Property Capacity -Sum).Sum
                        if (-not $ramSum) {
                            $ramSum = $sys.TotalPhysicalMemory
                        }
                        $ramGB = if ($ramSum) { [Math]::Round($ramSum / 1GB, 2) } else { 0 }

                        # Almacenamiento Total (Discos Fisicos)
                        $disks = Get-SubMenuWmiSafe -Class Win32_DiskDrive -SilentlyContinue
                        $totalStorageBytes = 0
                        $diskDetails = @()
                        if ($disks) {
                            foreach ($disk in $disks) {
                                if ($disk.Size) {
                                    $totalStorageBytes += $disk.Size
                                    $sizeGB = [Math]::Round($disk.Size / 1GB, 2)
                                    $diskDetails += "      - $($disk.Model): $sizeGB GB"
                                }
                            }
                        }
                        $totalStorageGB = [Math]::Round($totalStorageBytes / 1GB, 2)

                        # --- MOSTRAR INFORMACION DEL EQUIPO ---
                        Write-Host "`n===========================================================" -ForegroundColor Cyan
                        Write-Host "            CARACTERISTICAS Y ESPECIFICACIONES             " -ForegroundColor Cyan
                        Write-Host "===========================================================" -ForegroundColor Cyan
                        Write-Host ""
                        Write-Host "  Nombre del Equipo (Hostname): " -NoNewline
                        Write-Host "$($sys.Name)" -ForegroundColor Green
                        Write-Host "  Red / Grupo:                  " -NoNewline
                        if ($sys.PartOfDomain) {
                            Write-Host "$redGrupo" -ForegroundColor Green
                        } else {
                            Write-Host "$redGrupo" -ForegroundColor Yellow
                        }
                        Write-Host "  Marca y Modelo:               " -NoNewline
                        Write-Host "$marca / $modelo" -ForegroundColor Yellow
                        Write-Host "  Sistema Operativo:            " -NoNewline
                        Write-Host "$osDisplay" -ForegroundColor Yellow
                        Write-Host "  Microprocesador:              " -NoNewline
                        Write-Host "$cpuName" -ForegroundColor Yellow
                        Write-Host "  Memoria RAM Instalada:        " -NoNewline
                        Write-Host "$ramGB GB" -ForegroundColor Yellow
                        Write-Host "  Almacenamiento Total:         " -NoNewline
                        Write-Host "$totalStorageGB GB" -ForegroundColor Yellow
                        foreach ($detail in $diskDetails) {
                            Write-Host $detail -ForegroundColor Gray
                        }
                        Write-Host ""

                        # (La informacion del usuario activo ya fue visualizada como primer paso tras digitar la IP)

                        # --- OBTENER ADAPTADORES DE RED REMOTOS ---
                        $nicConfigs = Get-SubMenuWmiSafe -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = TRUE" -SilentlyContinue
                        
                        Write-Host "===========================================================" -ForegroundColor Cyan
                        Write-Host "             CONFIGURACION DE RED Y CONECTIVIDAD           " -ForegroundColor Cyan
                        Write-Host "===========================================================" -ForegroundColor Cyan
                        Write-Host ""
                        Write-Host "  --- Adaptadores de Red Activos ---" -ForegroundColor Yellow
                        Write-Host ""

                        $hayAdaptadorActivo = $false

                        if ($nicConfigs) {
                            foreach ($config in $nicConfigs) {
                                $ips = @()
                                if ($config.IPAddress) {
                                    foreach ($ip in $config.IPAddress) {
                                        if ($ip -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
                                            $ips += $ip
                                        }
                                    }
                                }
                                if ($ips.Count -eq 0) { continue }

                                $hayAdaptadorActivo = $true
                                $adapterInfo = Get-SubMenuWmiSafe -Class Win32_NetworkAdapter -Filter "Index = $($config.Index)" -SilentlyContinue
                                
                                $tipoConectividad = "Ethernet (Cableado)"
                                if ($adapterInfo) {
                                    $netConnectionId = $adapterInfo.NetConnectionID
                                    $adapterTypeId = $adapterInfo.AdapterTypeId
                                    if (($netConnectionId -match "Wi-Fi|Wireless|WLAN|Inalámbrica|Inalambrica") -or 
                                        ($config.Description -match "Wi-Fi|Wireless|WLAN|802\.11") -or 
                                        ($adapterTypeId -eq 9)) {
                                        $tipoConectividad = "Wi-Fi (Inalambrico)"
                                    }
                                } else {
                                    if ($config.Description -match "Wi-Fi|Wireless|WLAN|802\.11") {
                                        $tipoConectividad = "Wi-Fi (Inalambrico)"
                                    }
                                }

                                $dhcpStatus = if ($config.DHCPEnabled) { "DHCP" } else { "IP Fija (Estatica)" }
                                $mac = if ($config.MACAddress) { $config.MACAddress.Trim() } else { "No disponible" }

                                $gateways = @()
                                if ($config.DefaultIPGateway) {
                                    foreach ($gw in $config.DefaultIPGateway) {
                                        if ($gw -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
                                            $gateways += $gw
                                        }
                                    }
                                }

                                $dnsServers = @()
                                if ($config.DNSServerSearchOrder) {
                                    foreach ($dns in $config.DNSServerSearchOrder) {
                                        if ($dns -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
                                            $dnsServers += $dns
                                        }
                                    }
                                }

                                Write-Host "  [+] Adaptador:  " -NoNewline
                                Write-Host $config.Description -ForegroundColor Cyan
                                Write-Host "      Estado:     " -NoNewline
                                Write-Host "Conectado / Activo" -ForegroundColor Green
                                Write-Host "      Conexion:   " -NoNewline
                                Write-Host $tipoConectividad -ForegroundColor Gray
                                Write-Host "      Asignacion: " -NoNewline
                                Write-Host $dhcpStatus -ForegroundColor Gray
                                Write-Host "      Direccion MAC: " -NoNewline
                                Write-Host $mac -ForegroundColor Yellow
                                Write-Host "      IP(s):      " -NoNewline
                                Write-Host ($ips -join ", ") -ForegroundColor Yellow
                                if ($gateways.Count -gt 0) {
                                    Write-Host "      Gateway:    " -NoNewline
                                    Write-Host ($gateways -join ", ") -ForegroundColor Gray
                                }
                                if ($dnsServers.Count -gt 0) {
                                    Write-Host "      DNS:        " -NoNewline
                                    Write-Host ($dnsServers -join ", ") -ForegroundColor Green
                                } else {
                                    Write-Host "      DNS:        " -NoNewline
                                    Write-Host "No configurados" -ForegroundColor DarkGray
                                }
                                Write-Host ""
                            }
                        }

                        if (-not $hayAdaptadorActivo) {
                            Write-Host "  No se detectaron adaptadores de red activos con IPv4 configurada en el equipo remoto." -ForegroundColor Red
                        }

                        Write-Host "===========================================================" -ForegroundColor Cyan
                        Write-Host ""
                    }
                    catch {
                        Write-Host "ERROR al consultar especificaciones de $ipRemota ($computerTarget)." -ForegroundColor Red
                        Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Gray
                    }

                    [System.GC]::Collect()
                    Read-Host "Presione ENTER para continuar..."
                }

                "1.2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # --- CONFIGURACIÓN DE RED REMOTA CON COMPARATIVA ANTES/DESPUÉS ---
                    $ipRemota = Get-StandardIPPrompt -Mensaje "Ingrese la IP ACTUAL completa (ej: 192.168.176.50) o los 2 ultimos octetos (ej: 176.50)"
                    if ([string]::IsNullOrWhiteSpace($ipRemota)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    Write-Host "`n--- Conectando a: $ipRemota ---" -ForegroundColor Yellow

                    if (-not (Test-Connection -ComputerName $ipRemota -Count 1 -Quiet)) {
                        Write-Warning "El equipo $ipRemota no responde a ping. Es posible que este apagado o tenga el firewall activo."
                    }

                    try {
                        # 1. CAPTURA DE DATOS INICIALES (EL "ANTES")
                        $nicInfo = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $ipRemota `
                            -Filter "IPEnabled = TRUE" | Where-Object { $_.Description -notmatch "Virtual|Pseudo|Bluetooth|VPN" } | Select-Object -First 1

                        if (-not $nicInfo) { throw "No se pudo establecer comunicacion inicial con $ipRemota." }
                        
                        $interfaceName = (Get-WmiObject -Class Win32_NetworkAdapter -ComputerName $ipRemota -Filter "Index=$($nicInfo.Index)").NetConnectionId
                        $macAddress = $nicInfo.MACAddress
                        $hostName = (Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ipRemota).CSName

                        # MOSTRAR REPORTE INICIAL
                        Write-Host "`n====================================================" -ForegroundColor White
                        Write-Host "         ESTADO ACTUAL (ANTES DEL CAMBIO)" -ForegroundColor Yellow
                        Write-Host "====================================================" -ForegroundColor White
                        Write-Host " HOSTNAME:      $hostName"
                        Write-Host " MAC ADDRESS:   $macAddress"
                        Write-Host " INTERFAZ:      $interfaceName"
                        Write-Host " IP ACTUAL:     $($nicInfo.IPAddress[0])"
                        Write-Host " GATEWAY:       $($nicInfo.DefaultIPGateway -join ', ')"
                        Write-Host " DNS ACTUALES:  $($nicInfo.DNSServerSearchOrder -join ', ')"
                        Write-Host "====================================================`n"

                        # 2. SOLICITUD DE NUEVOS DATOS
                        $nuevaIP = Read-Host "Ingrese la NUEVA IP completa para este equipo"
                        $nuevoGW = Read-Host "Ingrese el NUEVO GATEWAY (Default: 192.168.176.1)"
                        if ($nuevoGW -eq "") { $nuevoGW = "192.168.176.1" }

                        Write-Host "`n[!] Aplicando cambios forzados mediante inyeccion Netsh..." -ForegroundColor Magenta

                        # 3. CONSTRUCCIÓN E INYECCIÓN DE COMANDOS (DIFERIDA Y ASÍNCRONA)
                        $cmdIP = "netsh interface ip set address name=\`"$interfaceName\`" static $nuevaIP 255.255.255.0 $nuevoGW 1"
                        $cmdDNS1 = "netsh interface ip set dns name=\`"$interfaceName\`" static 172.25.108.100"
                        $cmdDNS2 = "netsh interface ip add dns name=\`"$interfaceName\`" 192.168.13.214 index=2"
                        
                        $fullCommand = "cmd.exe /c start /b `"`" cmd.exe /c `"ping -n 5 127.0.0.1 >nul & $cmdIP & $cmdDNS1 & $cmdDNS2`""
                        $process = Get-WmiObject -List -ComputerName $ipRemota -Class Win32_Process
                        $process.Create($fullCommand) | Out-Null

                        Write-Host "[*] Comandos diferidos enviados. Esperando 15 segundos para reconexion..." -ForegroundColor Cyan
                        Start-Sleep -Seconds 15

                        # 4. CAPTURA DE DATOS FINALES (EL "DESPUÉS")
                        Write-Host "[*] Generando reporte de validacion...`n" -ForegroundColor Magenta
                        
                        try {
                            # 1. Comprobar primero con ping rápido para evitar hangs de WMI
                            Write-Host "[*] Verificando conectividad IP con ping a $nuevaIP..." -ForegroundColor Gray
                            if (-not (Test-Connection -ComputerName $nuevaIP -Count 1 -Quiet)) {
                                throw "El equipo no responde a ping en la nueva IP $nuevaIP."
                            }

                            # 2. Conexión WMI controlada con Timeout de 5 segundos
                            $options = New-Object System.Management.ConnectionOptions
                            $options.Timeout = New-Object System.TimeSpan(0, 0, 5) # 5 segundos
                            $scope = New-Object System.Management.ManagementScope("\\$nuevaIP\root\cimv2", $options)
                            $scope.Connect()

                            $query = New-Object System.Management.ObjectQuery("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE Index = $($nicInfo.Index)")
                            $searcher = New-Object System.Management.ManagementObjectSearcher($scope, $query)
                            $confirm = $searcher.Get() | Select-Object -First 1

                            if ($confirm) {
                                Write-Host "====================================================" -ForegroundColor White
                                Write-Host "        ESTADO FINAL (DESPUES DEL CAMBIO)" -ForegroundColor Green
                                Write-Host "====================================================" -ForegroundColor White
                                Write-Host " HOSTNAME:      $hostName"
                                Write-Host " MAC ADDRESS:   $macAddress"
                                Write-Host "----------------------------------------------------"
                                Write-Host " NUEVA IP:      $($confirm.IPAddress[0])" -ForegroundColor Cyan
                                Write-Host " MASCARA:       $($confirm.IPSubnet[0])"
                                Write-Host " NUEVO GW:      $($confirm.DefaultIPGateway -join ', ')" -ForegroundColor Cyan
                                Write-Host " NUEVOS DNS:    $($confirm.DNSServerSearchOrder -join ', ')" -ForegroundColor Cyan
                                Write-Host "====================================================" -ForegroundColor White
                                Write-Host "¡Cambio verificado exitosamente!" -ForegroundColor Green
                            } else {
                                throw "No se pudo recuperar la informacion de red de la interfaz con indice $($nicInfo.Index)."
                            }
                        } 
                        catch {
                            Write-Host "----------------------------------------------------"
                            Write-Host "AVISO: El equipo cambio su IP pero no responde WMI aun o la red se cayo." -ForegroundColor Yellow
                            Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Gray
                            Write-Host "Verifique manualmente: ping $nuevaIP" -ForegroundColor White
                            Write-Host "----------------------------------------------------"
                        }
                    }
                    catch {
                        Write-Host "`n[ERROR CRITICO]: $($_.Exception.Message)" -ForegroundColor Red
                    }

                    # --- EL TRUCO PARA QUE NO SE CUELGUE ---
                    # Forzamos la limpieza antes de volver a mostrar el menú
                    [System.GC]::Collect()
                    Write-Host "`nEl cambio de IP ha finalizado..."

                    Read-Host "Presione ENTER para continuar..."

                }

                "1.3" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # --- CONFIGURACIÓN DE RED REMOTA: REGRESO A DHCP (CORREGIDO) ---
                    $ipRemota = Get-StandardIPPrompt -Mensaje "Ingrese la IP ACTUAL completa (ej: 192.168.176.50) o los 2 ultimos octetos (ej: 176.50)"
                    if ([string]::IsNullOrWhiteSpace($ipRemota)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    Write-Host "`n--- Conectando a: $ipRemota ---" -ForegroundColor Yellow

                    if (-not (Test-Connection -ComputerName $ipRemota -Count 1 -Quiet)) {
                        Write-Warning "El equipo $ipRemota no responde a ping. Es posible que este apagado o tenga el firewall activo."
                    }

                    try {
                        # 1. CAPTURA DE DATOS INICIALES (EL "ANTES")
                        # Usamos WMI para obtener la identidad del equipo antes del cambio
                        $nicInfo = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $ipRemota `
                            -Filter "IPEnabled = TRUE" | Where-Object { $_.Description -notmatch "Virtual|Pseudo|Bluetooth|VPN" } | Select-Object -First 1

                        if (-not $nicInfo) { throw "No se pudo establecer comunicacion inicial con $ipRemota." }
                        
                        # Obtener nombre de interfaz, MAC y Hostname para el reporte
                        $interfaceName = (Get-WmiObject -Class Win32_NetworkAdapter -ComputerName $ipRemota -Filter "Index=$($nicInfo.Index)").NetConnectionId
                        $macAddress = $nicInfo.MACAddress
                        $hostName = (Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ipRemota).CSName

                        # REPORTE INICIAL
                        Write-Host "`n====================================================" -ForegroundColor White
                        Write-Host "         ESTADO ACTUAL (ANTES DEL CAMBIO)" -ForegroundColor Yellow
                        Write-Host "====================================================" -ForegroundColor White
                        Write-Host " HOSTNAME:      $hostName"
                        Write-Host " MAC ADDRESS:   $macAddress"
                        Write-Host " INTERFAZ:      $interfaceName"
                        Write-Host " IP ESTATICA:   $($nicInfo.IPAddress[0])"
                        Write-Host "====================================================`n"

                        Write-Host "[!] Forzando cambio a DHCP y DNS Automatico..." -ForegroundColor Magenta

                        # 2. CONSTRUCCIÓN DEL COMANDO (DIFERIDA Y ASÍNCRONA)
                        $cmdIP = "netsh interface ip set address name=\`"$interfaceName\`" source=dhcp"
                        $cmdDNS = "netsh interface ip set dns name=\`"$interfaceName\`" source=dhcp"
                        $fullCommand = "cmd.exe /c start /b `"`" cmd.exe /c `"ping -n 5 127.0.0.1 >nul & $cmdIP & $cmdDNS`""

                        # 3. EJECUCIÓN MEDIANTE PROCESO INDEPENDIENTE
                        # Esto asegura que el cambio se complete aunque la red se reinicie
                        $process = Get-WmiObject -List -ComputerName $ipRemota -Class Win32_Process
                        $resultado = $process.Create($fullCommand)

                        if ($resultado.ReturnValue -eq 0) {
                            Write-Host "[OK] Comandos inyectados correctamente." -ForegroundColor Green
                            Write-Host "[*] La red se esta reiniciando para obtener IP del servidor DHCP..." -ForegroundColor Cyan
                            Write-Host "[*] Espere 15 segundos..." -ForegroundColor Gray
                            Start-Sleep -Seconds 15

                            # 4. REPORTE FINAL
                            Write-Host "`n====================================================" -ForegroundColor White
                            Write-Host "        ESTADO FINAL (MODO DINAMICO)" -ForegroundColor Green
                            Write-Host "====================================================" -ForegroundColor White
                            Write-Host " HOSTNAME:      $hostName"
                            Write-Host " MAC ADDRESS:   $macAddress"
                            Write-Host "----------------------------------------------------"
                            Write-Host " CONFIGURACION: DHCP ACTIVADO" 
                            Write-Host " DNS:           AUTOMATICO"
                            Write-Host "====================================================" -ForegroundColor White
                            Write-Host "El equipo ya no depende de una IP fija." -ForegroundColor White
                        }
                        else {
                            Write-Host "Fallo al iniciar el proceso remoto. Codigo: $($resultado.ReturnValue)" -ForegroundColor Red
                        }
                    }
                    catch {
                        Write-Host "`n[ERROR]: $($_.Exception.Message)" -ForegroundColor Red
                    }

                    Write-Host "`nScript finalizado."
                    
                    Read-Host "Presione ENTER para continuar..."
                }

                "1.4" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # Solicitud estandarizada de IP remota
                    $ipRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($ipRemota)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    Write-Host "`nConsultando interfaces en: $ipRemota...`n" -ForegroundColor Cyan

                    try {
                        # Consulta de todos los adaptadores sin filtrar por estado o tipo fisico
                        $interfaces = Get-WmiObject -Class Win32_NetworkAdapter -ComputerName $ipRemota -ErrorAction Stop

                        # Presentacion de resultados en formato tabla
                        $interfaces | Select-Object Name, NetConnectionID, NetConnectionStatus, PhysicalAdapter, AdapterType | 
                        Format-Table -AutoSize
                        
                        Write-Host "`n[EXITO] Auditoria completada." -ForegroundColor Green
                        Write-Host " "
                    }
                    catch {
                        Write-Host "`n[ERROR] No se pudo conectar al equipo o consultar la informacion." -ForegroundColor Red
                        Write-Host "Detalle: $_" -ForegroundColor Yellow
                    }

                    
                }

                "1.5" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # 1. Entrada de red estandarizada
                    $ipRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($ipRemota)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    Write-Host "`nConectando a $ipRemota...`n" -ForegroundColor Cyan

                    if (-not (Test-Connection -ComputerName $ipRemota -Count 1 -Quiet)) {
                        Write-Warning "El equipo $ipRemota no responde a ping. Es posible que este apagado o bloquee el trafico."
                    }

                    try {
                        # 2. Listar interfaces fisicas (PhysicalAdapter = True)
                        $interfaces = Get-WmiObject -Class Win32_NetworkAdapter -ComputerName $ipRemota -Filter "PhysicalAdapter = True" -ErrorAction Stop
                        
                        # Mostrar tabla numerada para seleccion
                        $lista = @()
                        for ($i = 0; $i -lt $interfaces.Count; $i++) {
                            $obj = New-Object PSObject -Property @{
                                Indice = $i
                                Nombre = $interfaces[$i].Name
                                Estado = $interfaces[$i].NetConnectionStatus
                            }
                            $lista += $obj | Select-Object Indice, Nombre, Estado
                        }
                        $lista | Format-Table -AutoSize

                        # 3. Seleccion y confirmacion
                        $idx = Read-Host "Ingrese el indice de la interfaz que desea DESHABILITAR"
                        
                        if ($idx -ge 0 -and $idx -lt $interfaces.Count) {
                            $seleccion = $interfaces[$idx]
                            
                            # Nueva confirmacion de seguridad
                            $confirmar = Read-Host "ADVERTENCIA: Esta a punto de deshabilitar '$($seleccion.Name)'. Desea continuar? (S/N)"
                            
                            if ($confirmar -eq "S" -or $confirmar -eq "s") {
                                Write-Host " "
                                Write-Host "Deshabilitando: $($seleccion.Name)..." -ForegroundColor Yellow
                                
                                # Ejecutar metodo Disable()
                                $resultado = $seleccion.Disable()
                                
                                if ($resultado.ReturnValue -eq 0) {
                                    Write-Host "[EXITO] Interfaz deshabilitada correctamente." -ForegroundColor Green
                                    Write-Host " "
                                }
                                else {
                                    Write-Host "[ERROR] El sistema devolvio el codigo: $($resultado.ReturnValue). Se requieren privilegios de Administrador en el destino." -ForegroundColor Red
                                }
                            }
                            else {
                                Write-Host "[INFO] Operacion cancelada por el usuario." -ForegroundColor Yellow
                                Write-Host " "
                            }
                        }
                        else {
                            Write-Host "[ERROR] Indice invalido." -ForegroundColor Red
                        }
                    }
                    catch {
                        Write-Host "`n[ERROR] No se pudo conectar o gestionar la interfaz." -ForegroundColor Red
                        Write-Host "Detalle: $_" -ForegroundColor Yellow
                    }

                    
                }

                "1.6" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    
                }

                "1.7" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    Write-Host ""
                    Write-Host "========================================================"
                    Write-Host " BLOQUEO DE ZONA DE COBERTURA MOVIL"
                    Write-Host " Dominio : gmsantacruz.gov.bo"
                    Write-Host "========================================================"
                    Write-Host ""

                    $IP = Get-StandardIPPrompt

                    if ([string]::IsNullOrWhiteSpace($IP)) {
                        Write-Host ""
                        Write-Host "Debe ingresar un valor." -ForegroundColor Red
                        return
                    }

                    Write-Host ""
                    Write-Host "Direccion IP : $IP" -ForegroundColor Yellow
                    Write-Host ""

                    ##########################################################
                    # Verificar conectividad
                    ##########################################################

                    Write-Host "Verificando conectividad..." -ForegroundColor Cyan

                    if (!(Test-Connection -ComputerName $IP -Count 2 -Quiet)) {
                        Write-Host ""
                        Write-Host "ERROR"
                        Write-Host "El equipo no responde."
                        return
                    }

                    Write-Host "Conexion correcta." -ForegroundColor Green
                    Write-Host ""

                    ##########################################################
                    # Obtener HostName mediante WMI
                    ##########################################################

                    Write-Host "Obteniendo nombre del equipo..." -ForegroundColor Cyan

                    try {
                        $Equipo = Get-WmiObject `
                            Win32_ComputerSystem `
                            -ComputerName $IP `
                            -ErrorAction Stop

                        $HostName = $Equipo.Name

                        Write-Host "Nombre del equipo : $HostName" -ForegroundColor Yellow

                    }
                    catch {
                        Write-Host ""
                        Write-Host "ERROR"
                        Write-Host "No fue posible obtener el nombre del equipo."
                        Write-Host $_.Exception.Message
                        return
                    }

                    ##########################################################
                    # Verificar WinRM
                    ##########################################################

                    Write-Host ""
                    Write-Host "Verificando WinRM..." -ForegroundColor Cyan

                    $WinRM = $true

                    try {
                        Test-WSMan `
                            -ComputerName $HostName `
                            -ErrorAction Stop | Out-Null
                    }
                    catch {
                        $WinRM = $false
                    }

                    ##########################################################
                    # Habilitar WinRM
                    ##########################################################

                    if (!$WinRM) {
                        Write-Host ""
                        Write-Host "WinRM no esta habilitado."
                        Write-Host "Intentando habilitar WinRM..."

                        try {
                            Invoke-WmiMethod `
                                -Class Win32_Process `
                                -Name Create `
                                -ComputerName $HostName `
                                -ArgumentList "cmd.exe /c winrm.cmd quickconfig -quiet" `
                                -ErrorAction Stop | Out-Null

                            Start-Sleep 8

                            Test-WSMan `
                                -ComputerName $HostName `
                                -ErrorAction Stop | Out-Null

                            Write-Host "WinRM habilitado correctamente." -ForegroundColor Green

                        }
                        catch {
                            Write-Host ""
                            Write-Host "ERROR"
                            Write-Host "No fue posible habilitar WinRM."
                            Write-Host $_.Exception.Message
                            return
                        }
                    }

                    ##########################################################
                    # Aplicar configuracion
                    ##########################################################

                    Write-Host ""
                    Write-Host "Aplicando configuracion..." -ForegroundColor Yellow

                    try {
                        Invoke-Command `
                            -ComputerName $HostName `
                            -Authentication Kerberos `
                            -ErrorAction Stop `
                            -ScriptBlock {

                            $Ruta = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Network Connections"

                            if (!(Test-Path $Ruta)) {
                                New-Item `
                                    -Path $Ruta `
                                    -Force | Out-Null
                            }

                            New-ItemProperty `
                                -Path $Ruta `
                                -Name NC_ShowSharedAccessUI `
                                -PropertyType DWord `
                                -Value 0 `
                                -Force | Out-Null

                            Set-Service `
                                SharedAccess `
                                -StartupType Disabled `
                                -ErrorAction SilentlyContinue

                            Stop-Service `
                                SharedAccess `
                                -Force `
                                -ErrorAction SilentlyContinue

                            return "OK"
                        }
                        Write-Host ""
                        Write-Host "=============================================="
                        Write-Host "Proceso finalizado correctamente." -ForegroundColor Green
                        Write-Host "=============================================="
                        Write-Host ""
                    }
                    catch {
                        Write-Host ""
                        Write-Host "ERROR"
                        Write-Host ""
                        Write-Host $_.Exception.Message
                        Write-Host ""
                    }
                    
                }

                "1.8" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    Write-Host ""
                    Write-Host "========================================================"
                    Write-Host " RESTAURAR ZONA DE COBERTURA MOVIL"
                    Write-Host " Dominio : gmsantacruz.gov.bo"
                    Write-Host "========================================================"
                    Write-Host ""

                    $IP = Get-StandardIPPrompt

                    if ([string]::IsNullOrWhiteSpace($IP)) {
                        Write-Host ""
                        Write-Host "Debe ingresar un valor." -ForegroundColor Red
                        return
                    }

                    Write-Host ""
                    Write-Host "Direccion IP : $IP" -ForegroundColor Yellow
                    Write-Host ""

                    Write-Host "Verificando conectividad..." -ForegroundColor Cyan

                    if (!(Test-Connection -ComputerName $IP -Count 2 -Quiet)) {
                        Write-Host ""
                        Write-Host "ERROR" -ForegroundColor Red
                        Write-Host "El equipo no responde."
                        return
                    }

                    Write-Host "Conexion correcta." -ForegroundColor Green
                    Write-Host ""

                    Write-Host "Obteniendo nombre del equipo..." -ForegroundColor Cyan

                    try {
                        $Equipo = Get-WmiObject `
                            Win32_ComputerSystem `
                            -ComputerName $IP `
                            -ErrorAction Stop

                        $HostName = $Equipo.Name

                        Write-Host "Nombre del equipo : $HostName" -ForegroundColor Yellow
                    }
                    catch {
                        Write-Host ""
                        Write-Host "ERROR" -ForegroundColor Red
                        Write-Host $_.Exception.Message
                        return
                    }

                    Write-Host ""
                    Write-Host "Verificando WinRM..."

                    try {
                        Test-WSMan `
                            -ComputerName $HostName `
                            -ErrorAction Stop | Out-Null
                    }
                    catch {
                        Write-Host ""
                        Write-Host "ERROR" -ForegroundColor Red
                        Write-Host "WinRM no esta disponible."
                        return
                    }

                    Write-Host ""
                    Write-Host "Restaurando configuracion..." -ForegroundColor Cyan

                    try {
                        Invoke-Command `
                            -ComputerName $HostName `
                            -Authentication Kerberos `
                            -ErrorAction Stop `
                            -ScriptBlock {

                            $Ruta = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Network Connections"

                            if (Test-Path $Ruta) {
                                Remove-ItemProperty `
                                    -Path $Ruta `
                                    -Name "NC_ShowSharedAccessUI" `
                                    -ErrorAction SilentlyContinue
                            }

                            Set-Service `
                                -Name SharedAccess `
                                -StartupType Manual `
                                -ErrorAction SilentlyContinue

                            Start-Service `
                                -Name SharedAccess `
                                -ErrorAction SilentlyContinue

                            return "OK"
                        }

                        Write-Host ""
                        Write-Host "=============================================="
                        Write-Host " CONFIGURACION RESTAURADA" -ForegroundColor Green
                        Write-Host "=============================================="
                        Write-Host ""
                        Write-Host "Equipo : $HostName"
                        Write-Host "Zona de cobertura movil habilitada." -ForegroundColor Green
                        Write-Host ""

                    }
                    catch {
                        Write-Host ""
                        Write-Host "ERROR"  -ForegroundColor Red
                        Write-Host $_.Exception.Message
                        Write-Host ""
                    }
                }

                "1.9" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    $target = Get-StandardIPPrompt
                    if (-not [string]::IsNullOrWhiteSpace($target)) {
                        psHabilitarAdministracionRemota -targetInput $target
                    } else {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                    }
                    Read-Host "Presione ENTER para continuar..."
                }

                "2.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    $baseIP = "192.168.176."
                    $rangoInicio = 1
                    $rangoFin = 254

                    Write-Host "--- Iniciando auditoria de red en: $baseIP$rangoInicio al $rangoFin ---" -ForegroundColor Yellow
                    Write-Host "Analizando configuraciones de red... por favor espere.`n" -ForegroundColor Gray

                    $resultados = @()

                    foreach ($i in $rangoInicio..$rangoFin) {
                        $ipActual = $baseIP + $i
                        
                        # Intento de ping rápido
                        if (Test-Connection -ComputerName $ipActual -Count 1 -BufferSize 16 -Quiet) {
                            try {
                                # Consulta WMI para obtener configuración de red y nombre de host simultáneamente
                                $nic = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $ipActual `
                                    -Filter "IPEnabled = TRUE" -ErrorAction Stop | 
                                Where-Object { $_.Description -notmatch "Virtual|VPN|Pseudo|Bluetooth" } | 
                                Select-Object -First 1

                                if ($nic) {
                                    $sys = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ipActual
                                    
                                    # Determinamos el estado visualmente
                                    $estadoIP = "ESTATICO"
                                    if ($nic.DHCPEnabled) {
                                        $estadoIP = "DHCP"
                                    }
                                    
                                    $obj = New-Object PSObject -Property @{
                                        IP         = $ipActual
                                        HostName   = $sys.CSName
                                        Estado     = $estadoIP
                                        MACAddress = $nic.MACAddress
                                    }
                                    $resultados += $obj | Select-Object IP, HostName, Estado, MACAddress
                                    
                                    # Feedback en consola durante el escaneo
                                    $color = "Yellow"
                                    if ($estadoIP -eq "DHCP") {
                                        $color = "Cyan"
                                    }
                                    Write-Host "[+] Detectado: ${ipActual} - ${estadoIP} ($($sys.CSName))" -ForegroundColor $color
                                }
                            }
                            catch {
                                Write-Host "[!] ${ipActual}: Sin acceso a datos (WMI bloqueado)." -ForegroundColor DarkGray
                            }
                        }
                    }

                    # Presentación de resultados finales en tabla
                    if ($resultados.Count -gt 0) {
                        Write-Host "`n" + ("=" * 60) -ForegroundColor White
                        Write-Host "                REPORTE FINAL DE RED" -ForegroundColor Green
                        Write-Host ("=" * 60) -ForegroundColor White
                        
                        $resultados | Sort-Object Estado | Format-Table -AutoSize
                        
                        Write-Host "Total de equipos detectados: $($resultados.Count)" -ForegroundColor Cyan
                    }
                    else {
                        Write-Host "`nNo se detectaron equipos activos en el segmento." -ForegroundColor Red
                    }

                    Write-Host "`nEl Proceso ha finalizado..."        

                    Read-Host "Presione ENTER para continuar..."
                }

                "2.2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    Write-Host "==========================================================================" -ForegroundColor Cyan
                    Write-Host "     AUDITORIA Y DETECCION AVANZADA DE EQUIPOS EN RED (NUEVA VENTANA)     " -ForegroundColor Cyan
                    Write-Host "==========================================================================" -ForegroundColor Cyan
                    Write-Host ""

                    # 1. Extracción de IP del equipo solicitante y propuesta de segmento CIDR
                    $solicitanteIP = "127.0.0.1"
                    $redSugerida = "192.168.176.0/24"
                    try {
                        $ad = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
                            Where-Object { 
                                $_.IPAddress -notlike "127.*" -and 
                                $_.IPAddress -notlike "169.254*" -and 
                                $_.InterfaceAlias -notmatch "VPN|Radmin|Hamachi|vEthernet|Virtual|Pseudo|Loopback" 
                            } | 
                            Sort-Object { 
                                if ($_.IPAddress -like "192.168.*") { 1 } 
                                elseif ($_.IPAddress -like "10.*" -or $_.IPAddress -like "172.*") { 2 } 
                                else { 3 } 
                            } | Select-Object -First 1

                        if ($ad) {
                            $solicitanteIP = $ad.IPAddress
                            $octetos = $solicitanteIP.Split('.')
                            if ($octetos.Count -eq 4) {
                                $redSugerida = "$($octetos[0]).$($octetos[1]).$($octetos[2]).0/24"
                            }
                        }
                    } catch {}

                    Write-Host "  [+] IP del Equipo Solicitante:  " -NoNewline -ForegroundColor White
                    Write-Host "$solicitanteIP" -ForegroundColor Green
                    Write-Host "  [+] Segmento de Red Detectado:  " -NoNewline -ForegroundColor White
                    Write-Host "$redSugerida" -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "  Ingrese la direccion de red a escanear (ej. 192.168.176.0/24, 192.168.176. o 176)" -ForegroundColor Cyan
                    $entradaRed = Read-Host "  [Presione ENTER para usar $redSugerida]"
                    $entradaRed = $entradaRed.Trim()

                    $segmentoElegido = $redSugerida
                    if (-not [string]::IsNullOrWhiteSpace($entradaRed)) {
                        if ($entradaRed -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.0/\d{1,2}$') {
                            $segmentoElegido = $entradaRed
                        }
                        elseif ($entradaRed -match '^(\d{1,3}\.\d{1,3}\.\d{1,3})\.?$') {
                            $segmentoElegido = "$($Matches[1]).0/24"
                        }
                        elseif ($entradaRed -match '^\d{1,3}$') {
                            $segmentoElegido = "192.168.$entradaRed.0/24"
                        }
                        else {
                            $segmentoElegido = $entradaRed
                        }
                    }

                    Write-Host "`n[*] Preparando ejecucion en una NUEVA VENTANA..." -ForegroundColor Yellow

                    # 2. Generación del código del script auditor autónomo
                    $scannerCode = @'
param(
    [string]$NetworkCIDR = "192.168.176.0/24",
    [string]$RequestingIP = "127.0.0.1"
)

# Configuración visual de la ventana de auditoría
$Host.UI.RawUI.WindowTitle = "AUDITORIA DE RED: $NetworkCIDR | Solicitante: $RequestingIP | shellWil"
try {
    if ($Host.UI.RawUI.BufferSize.Width -lt 125) {
        $Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size(130, 3500)
        $Host.UI.RawUI.WindowSize = New-Object Management.Automation.Host.Size(130, 45)
    }
} catch {}

Clear-Host
Write-Host "==========================================================================================================" -ForegroundColor Cyan
Write-Host "                    AUDITORIA AVANZADA: ESCANEO Y DETECCION DE EQUIPOS EN RED                             " -ForegroundColor Cyan
Write-Host "==========================================================================================================" -ForegroundColor Cyan
Write-Host "  IP Solicitante : " -NoNewline -ForegroundColor White
Write-Host "$RequestingIP" -ForegroundColor Green
Write-Host "  Segmento de Red: " -NoNewline -ForegroundColor White
Write-Host "$NetworkCIDR" -ForegroundColor Yellow
Write-Host "  Fecha y Hora   : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" -ForegroundColor Gray
Write-Host "==========================================================================================================" -ForegroundColor Cyan

# Extracción de base IP para el segmento
$baseIP = "192.168.176."
if ($NetworkCIDR -match '^(\d{1,3}\.\d{1,3}\.\d{1,3})\.') {
    $baseIP = "$($Matches[1])."
}
$rangoInicio = 1
$rangoFin = 254

# Detección del Gateway por defecto
$defaultGW = ""
try {
    $cfgGW = Get-CimInstance Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -contains $RequestingIP } | Select-Object -First 1
    if ($cfgGW -and $cfgGW.DefaultIPGateway) {
        $defaultGW = $cfgGW.DefaultIPGateway[0]
    }
} catch {}
if ([string]::IsNullOrEmpty($defaultGW)) {
    $defaultGW = "${baseIP}1"
}

# Diccionario OUI para clasificación por hardware (MAC)
$ouiDB = @{
    # Relojes Biométricos
    '00:17:61' = 'Reloj biometrico'; '6C:DF:FB' = 'Reloj biometrico'; 'E0:69:95' = 'Reloj biometrico'
    'C4:2F:90' = 'Reloj biometrico'; '00:0B:82' = 'Reloj biometrico'; '2C:26:17' = 'Reloj biometrico'
    '50:13:95' = 'Reloj biometrico'
    # Fotocopiadoras / Multifuncionales corporativas
    '00:26:73' = 'Fotocopiadora'; '00:00:85' = 'Fotocopiadora'; '00:20:6B' = 'Fotocopiadora'
    '00:04:F2' = 'Fotocopiadora'; '00:17:C8' = 'Fotocopiadora'; '00:C0:EE' = 'Fotocopiadora'
    '00:00:AA' = 'Fotocopiadora'; '00:80:77' = 'Fotocopiadora'; '00:1B:A9' = 'Fotocopiadora'
    '78:8C:77' = 'Fotocopiadora'; '00:00:07' = 'Fotocopiadora'
    # Impresoras de red estándar
    '00:1E:0B' = 'Impresora de red'; '00:25:B3' = 'Impresora de red'; '3C:D9:2B' = 'Impresora de red'
    '70:5A:0F' = 'Impresora de red'; 'A4:5D:36' = 'Impresora de red'; '00:00:48' = 'Impresora de red'
    '00:26:AB' = 'Impresora de red'; '00:01:E6' = 'Impresora de red'
    # Cámaras CCTV / Vigilancia IP
    '58:38:79' = 'Camara CCTV'; '44:19:B6' = 'Camara CCTV'; 'C0:56:E3' = 'Camara CCTV'
    'B4:A3:82' = 'Camara CCTV'; '28:57:BE' = 'Camara CCTV'; '54:C4:15' = 'Camara CCTV'
    'E0:50:8B' = 'Camara CCTV'; '38:AF:29' = 'Camara CCTV'; 'B0:C5:54' = 'Camara CCTV'
    '00:40:8C' = 'Camara CCTV'; '48:EA:63' = 'Camara CCTV'
    # Switches de datos
    '00:00:0C' = 'Switch de datos'; '00:01:42' = 'Switch de datos'; '00:1C:7F' = 'Switch de datos'
    '00:1A:A1' = 'Switch de datos'; '48:8F:5A' = 'Switch de datos'; '6C:3B:6B' = 'Switch de datos'
    'CC:2D:E0' = 'Switch de datos'; 'D4:CA:6D' = 'Switch de datos'; 'D4:F5:EF' = 'Switch de datos'
    'C0:06:C3' = 'Switch de datos'
    # Routers Inalámbricos / Access Points
    '24:A4:3C' = 'Router inalambrico'; 'F0:9F:C2' = 'Router inalambrico'
    '50:C7:BF' = 'Router inalambrico'; 'E8:48:B8' = 'Router inalambrico'
    # Computadoras / Laptops / Servidores
    'F8:BC:12' = 'Computadora'; '7C:57:58' = 'Computadora'; '00:14:22' = 'Computadora'
    '18:66:DA' = 'Computadora'; 'B8:CA:3A' = 'Computadora'; 'AC:16:2D' = 'Computadora'
    'B0:4F:13' = 'Computadora'; 'A0:B3:CC' = 'Computadora'; 'E4:54:E8' = 'Computadora'
    '00:59:07' = 'Computadora'
}

# Función auxiliar de sondeo ultrarrápido de puerto TCP (timeout en ms)
$fnTestPort = {
    param([string]$ip, [int]$port, [int]$timeoutMs = 120)
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $asyncRes = $tcpClient.BeginConnect($ip, $port, $null, $null)
        if ($asyncRes.AsyncWaitHandle.WaitOne($timeoutMs, $false) -and $tcpClient.Connected) {
            $tcpClient.Close()
            return $true
        }
        $tcpClient.Close()
        return $false
    } catch { return $false }
}

# --- FASE 1: ESCANEO ASÍNCRONO MULTIHILO (PING PARALELO) ---
Write-Host "`n[*] Enviando sondeo ICMP (Ping) en paralelo a ${baseIP}${rangoInicio} al ${rangoFin}..." -ForegroundColor Yellow
$pingTasks = @()
$pingObjects = @()
foreach ($i in $rangoInicio..$rangoFin) {
    $target = "$baseIP$i"
    $p = New-Object System.Net.NetworkInformation.Ping
    $pingObjects += $p
    $pingTasks += $p.SendPingAsync($target, 300)
}
[System.Threading.Tasks.Task]::WaitAll($pingTasks)

$pingActiveMap = @{}
for ($idx = 0; $idx -lt $pingTasks.Count; $idx++) {
    if ($pingTasks[$idx].Result.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
        $pingActiveMap[$pingTasks[$idx].Result.Address.ToString()] = $true
    }
}
foreach ($p in $pingObjects) { try { $p.Dispose() } catch {} }

# --- FASE 2: CARGA DE TABLA ARP PARA CAPTURA DE MACS ---
$arpCache = @{}
try {
    Get-NetNeighbor -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.IPAddress -and $_.LinkLayerAddress -and $_.LinkLayerAddress -ne "00-00-00-00-00-00") {
            $arpCache[$_.IPAddress] = $_.LinkLayerAddress.ToUpper().Replace("-", ":")
        }
    }
} catch {}
try {
    $arpLines = arp -a
    foreach ($line in $arpLines) {
        if ($line -match '^\s*(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+([0-9a-fA-F\-]{17})\s+(\S+)') {
            $ipEntry = $Matches[1]
            $macEntry = $Matches[2].ToUpper().Replace("-", ":")
            if (-not $arpCache.ContainsKey($ipEntry)) {
                $arpCache[$ipEntry] = $macEntry
            }
        }
    }
} catch {}

# --- FASE 3: EVALUACIÓN Y CLASIFICACIÓN DETALLADA DE CADA DIRECCIÓN IP ---
Write-Host "[+] Sondeo inicial completado. Clasificando equipos e identificando IPs libres...`n" -ForegroundColor Gray
Write-Host ("  {0,-5} {1,-16} | {2,-24} | {3,-16} | {4,-22} | {5}" -f "EST", "DIRECCION IP", "TIPO DE EQUIPO", "ASIGNACION IP", "NOMBRE DE EQUIPO", "MAC ADDRESS") -ForegroundColor White
Write-Host ("  " + ("-" * 110)) -ForegroundColor Gray

$resultados = @()
$ipsSinAsignar = @()

foreach ($i in $rangoInicio..$rangoFin) {
    $ipActual = "$baseIP$i"
    $isAlivePing = $pingActiveMap.ContainsKey($ipActual)
    $hasArp = $arpCache.ContainsKey($ipActual)

    # Si NO responde a Ping y NO existe en ARP -> IP LIBRE / SIN ASIGNAR
    if (-not $isAlivePing -and -not $hasArp) {
        $ipsSinAsignar += $ipActual
        Write-Host "  [-] " -NoNewline -ForegroundColor DarkGray
        Write-Host ("{0,-16}" -f $ipActual) -NoNewline -ForegroundColor DarkGray
        Write-Host " | " -NoNewline -ForegroundColor DarkGray
        Write-Host ("{0,-24}" -f "SIN ASIGNAR") -NoNewline -ForegroundColor DarkGray
        Write-Host " | " -NoNewline -ForegroundColor DarkGray
        Write-Host ("{0,-16}" -f "LIBRE") -NoNewline -ForegroundColor DarkGray
        Write-Host " | " -NoNewline -ForegroundColor DarkGray
        Write-Host ("{0,-22}" -f "SIN ASIGNAR") -NoNewline -ForegroundColor DarkGray
        Write-Host " | " -NoNewline -ForegroundColor DarkGray
        Write-Host "(No Asignada)" -ForegroundColor DarkGray
        continue
    }

    # IP ACTIVA: A. Obtención precisa de MAC
    $mac = if ($arpCache.ContainsKey($ipActual)) { $arpCache[$ipActual] } else { "" }
    if ([string]::IsNullOrEmpty($mac)) {
        try {
            $n = Get-NetNeighbor -IPAddress $ipActual -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($n -and $n.LinkLayerAddress) { $mac = $n.LinkLayerAddress.ToUpper().Replace("-", ":") }
        } catch {}
    }
    if ([string]::IsNullOrEmpty($mac) -and ($ipActual -eq $RequestingIP)) {
        try {
            $localNic = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPAddress -contains $ipActual } | Select-Object -First 1
            if ($localNic -and $localNic.MACAddress) { $mac = $localNic.MACAddress.ToUpper().Replace("-", ":") }
        } catch {}
    }
    if ([string]::IsNullOrEmpty($mac)) { $mac = "No disponible" }

    # B. Resolución de Hostname (DNS Asíncrono no bloqueante + Fallback NetBIOS)
    $hostName = ""
    try {
        $asyncDns = [System.Net.Dns]::BeginGetHostEntry($ipActual, $null, $null)
        if ($asyncDns.AsyncWaitHandle.WaitOne(100, $false)) {
            $entry = [System.Net.Dns]::EndGetHostEntry($asyncDns)
            if ($entry -and $entry.HostName) { $hostName = $entry.HostName.Split('.')[0] }
        }
    } catch {}

    if ([string]::IsNullOrEmpty($hostName)) {
        try {
            $nbt = nbtstat -a $ipActual 2>$null
            $linea = $nbt | Where-Object { $_ -match "<\x00>.*UNIQUE" } | Select-Object -First 1
            if ($linea -and $linea -match "^\s*([A-Za-z0-9\-]+)") {
                $hostName = $Matches[1].Trim()
            }
        } catch {}
    }

    # C. Verificación precisa de Asignación de IP (FIJA / ESTATICA vs DINAMICA / DHCP)
    # Se elimina la relación errónea con el comando 'arp -a'. Se verifica por adaptador real y perfiles.
    $estadoIP = "FIJA (ESTATICA)"
    if ($ipActual -eq $RequestingIP) {
        try {
            $cfgLocal = Get-CimInstance Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -contains $ipActual } | Select-Object -First 1
            if ($cfgLocal -and $cfgLocal.DHCPEnabled) { $estadoIP = "DINAMICA (DHCP)" } else { $estadoIP = "FIJA (ESTATICA)" }
        } catch {}
    } elseif (& $fnTestPort $ipActual 135 70) {
        try {
            $nicRem = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $ipActual -Filter "IPEnabled = TRUE" -ErrorAction Stop |
                Where-Object { $_.Description -notmatch "Virtual|VPN|Pseudo|Bluetooth" } | Select-Object -First 1
            if ($nicRem) {
                if ($nicRem.DHCPEnabled) { $estadoIP = "DINAMICA (DHCP)" } else { $estadoIP = "FIJA (ESTATICA)" }
                if ($mac -eq "No disponible" -and $nicRem.MACAddress) { $mac = $nicRem.MACAddress.ToUpper().Replace("-", ":") }
            }
            $sysRem = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ipActual -ErrorAction SilentlyContinue
            if ($sysRem -and $sysRem.CSName) { $hostName = $sysRem.CSName }
        } catch {}
    }

    # D. Clasificación del Tipo de Dispositivo (9 Categorías Específicas)
    $tipoEquipo = ""

    # 1. Reloj Biométrico (Puertos 4370 ZK/Anviz, 5005 Suprema o firmas de host)
    if ((& $fnTestPort $ipActual 4370) -or (& $fnTestPort $ipActual 5005) -or ($hostName -match "ZK|BIO|RELOJ|ANVIZ|TIMESTATION|CONTROL-ASISTENCIA")) {
        $tipoEquipo = "Reloj biometrico"
    }
    # 2. Fotocopiadora (Multifuncionales corporativas de alto rendimiento)
    elseif (($hostName -match "RICOH|AFICIO|KONICA|BIZHUB|KYOCERA|TASKALFA|XEROX|WORKCENTRE|ALTALINK|VERSALINK|TOSHIBA|ESTUDIO|SHARP|MX-|DEVELOP|IMAGERUNNER|IR-ADV|COPIADORA|FOTOCOPIADORA") -or
            ((& $fnTestPort $ipActual 9100) -and ((& $fnTestPort $ipActual 21) -or (& $fnTestPort $ipActual 80) -or (& $fnTestPort $ipActual 443)) -and ($mac.StartsWith("00:26:73") -or $mac.StartsWith("00:00:85") -or $mac.StartsWith("00:20:6B") -or $mac.StartsWith("00:04:F2") -or $mac.StartsWith("00:17:C8") -or $mac.StartsWith("00:C0:EE") -or $mac.StartsWith("00:00:AA") -or $mac.StartsWith("00:80:77") -or $mac.StartsWith("00:1B:A9") -or $mac.StartsWith("78:8C:77")))) {
        $tipoEquipo = "Fotocopiadora"
    }
    # 3. Impresora de red (Impresoras láser o inyección estándar)
    elseif ((& $fnTestPort $ipActual 9100) -or (& $fnTestPort $ipActual 515) -or (& $fnTestPort $ipActual 631) -or ($hostName -match "PRN|PRINT|EPSON|BROTHER|HP-PRINT|LASERJET|DESKJET|PAGEWIDE|ZEBRA|SATO|IMPRESORA")) {
        $tipoEquipo = "Impresora de red"
    }
    # 4. DVR (Grabadores de Video Digital / NVR / XVR de seguridad)
    elseif (($hostName -match "DVR|NVR|XVR|HIK-NVR|DAHUA-NVR|GRABADOR|HIKVISION-NVR") -or 
            (((& $fnTestPort $ipActual 8000) -or (& $fnTestPort $ipActual 37777) -or (& $fnTestPort $ipActual 34567)) -and ($hostName -notmatch "CAM|IPC") -and (& $fnTestPort $ipActual 554))) {
        $tipoEquipo = "DVR"
    }
    # 5. Cámara CCTV (Cámaras IP, domos o tubos de videovigilancia)
    elseif ((& $fnTestPort $ipActual 554) -or (& $fnTestPort $ipActual 8899) -or ($hostName -match "CAM|IPC|CAMERA|DOMO|TUBO|BULLET|CCTV|HIK-CAM|DAHUA-CAM")) {
        $tipoEquipo = "Camara CCTV"
    }
    # 6. Router (Gateway de red, puertos de enrutamiento o router de borde)
    elseif (($ipActual -eq $defaultGW) -or (& $fnTestPort $ipActual 8291) -or ($hostName -match "ROUTER|GW|GATEWAY|MIKROTIK|FORTINET|CISCO-ROUTER|PFSENSE|OPNSENSE|EDGEROUTER|FIREWALL")) {
        $tipoEquipo = "Router"
    }
    # 7. Router Inalámbrico (Access Point / AP / WiFi Router)
    elseif ((& $fnTestPort $ipActual 8080) -or ($hostName -match "WIFI|AP-|AP_|WIRELESS|ACCESSPOINT|UNIFI|UAP|AIRMAX|TENDA|MERCUSYS")) {
        $tipoEquipo = "Router inalambrico"
    }
    # 8. Computadora (Estaciones de trabajo, PC, laptops o servidores Windows)
    elseif ((& $fnTestPort $ipActual 445) -or (& $fnTestPort $ipActual 135) -or (& $fnTestPort $ipActual 3389) -or ($hostName -match "DESKTOP|LAPTOP|PC|WIN|SRV|SERVER|WS-|HMP")) {
        $tipoEquipo = "Computadora"
    }
    # 9. Switch de datos (Switches administrables o infraestructura de distribución)
    elseif ((& $fnTestPort $ipActual 22) -or (& $fnTestPort $ipActual 23) -or (& $fnTestPort $ipActual 161) -or ($hostName -match "SW|SWITCH|SW-|CATALYST|PROCURVE|ARUBA|EDGESWITCH")) {
        $tipoEquipo = "Switch de datos"
    }
    else {
        # Búsqueda complementaria por OUI en la base de datos de fabricantes
        if ($mac.Length -ge 8) {
            $prefix = $mac.Substring(0, 8).ToUpper()
            if ($ouiDB.ContainsKey($prefix)) {
                $tipoEquipo = $ouiDB[$prefix]
            }
        }
        if ([string]::IsNullOrEmpty($tipoEquipo)) {
            $tipoEquipo = "Dispositivo de Red"
        }
    }

    if ([string]::IsNullOrEmpty($hostName)) { $hostName = "(Sin Hostname)" }

    # Guardar en resultados
    $obj = [PSCustomObject]@{
        IP         = $ipActual
        HostName   = $hostName
        Tipo       = $tipoEquipo
        Estado     = $estadoIP
        MACAddress = $mac
    }
    $resultados += $obj

    # Asignar color según el tipo de equipo
    $colorTipo = switch ($tipoEquipo) {
        "Computadora"         { "Green" }
        "Impresora de red"    { "Cyan" }
        "Fotocopiadora"       { "DarkCyan" }
        "Switch de datos"     { "White" }
        "Router"              { "Yellow" }
        "Router inalambrico"  { "DarkYellow" }
        "Reloj biometrico"    { "Magenta" }
        "DVR"                 { "DarkRed" }
        "Camara CCTV"         { "Yellow" }
        Default               { "Gray" }
    }

    Write-Host "  [+] " -NoNewline -ForegroundColor Green
    Write-Host ("{0,-16}" -f $ipActual) -NoNewline -ForegroundColor Yellow
    Write-Host " | " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-24}" -f $tipoEquipo) -NoNewline -ForegroundColor $colorTipo
    Write-Host " | " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-16}" -f $estadoIP) -NoNewline -ForegroundColor White
    Write-Host " | " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-22}" -f $hostName) -NoNewline -ForegroundColor Cyan
    Write-Host " | " -NoNewline -ForegroundColor Gray
    Write-Host "$mac" -ForegroundColor Gray
}

# --- FASE 4: REPORTE FINAL TABULADO Y RESUMEN ESTADÍSTICO ---
Write-Host "`n" + ("=" * 110) -ForegroundColor White
Write-Host "                    REPORTE DE AUDITORIA: EQUIPOS DETECTADOS EN EL SEGMENTO                      " -ForegroundColor Green
Write-Host ("=" * 110) -ForegroundColor White

if ($resultados.Count -gt 0) {
    $resultados | Sort-Object { [version]$_.IP } | Format-Table -Property @{Label="IP"; Expression={$_.IP}; Width=16}, @{Label="HostName"; Expression={$_.HostName}; Width=22}, @{Label="Tipo de Dispositivo"; Expression={$_.Tipo}; Width=24}, @{Label="Asignacion"; Expression={$_.Estado}; Width=16}, @{Label="MAC Address"; Expression={$_.MACAddress}; Width=19} -AutoSize
} else {
    Write-Host "`n[!] No se detectaron equipos activos en el segmento." -ForegroundColor Red
}

Write-Host ("-" * 80) -ForegroundColor Gray
Write-Host "RESUMEN DE EQUIPOS DETECTADOS:" -ForegroundColor Yellow
Write-Host ("-" * 80) -ForegroundColor Gray

$cPC     = ($resultados | Where-Object { $_.Tipo -eq "Computadora" }).Count
$cImp    = ($resultados | Where-Object { $_.Tipo -eq "Impresora de red" }).Count
$cFoto   = ($resultados | Where-Object { $_.Tipo -eq "Fotocopiadora" }).Count
$cSwitch = ($resultados | Where-Object { $_.Tipo -eq "Switch de datos" }).Count
$cRouter = ($resultados | Where-Object { $_.Tipo -eq "Router" }).Count
$cWiFi   = ($resultados | Where-Object { $_.Tipo -eq "Router inalambrico" }).Count
$cBio    = ($resultados | Where-Object { $_.Tipo -eq "Reloj biometrico" }).Count
$cDVR    = ($resultados | Where-Object { $_.Tipo -eq "DVR" }).Count
$cCam    = ($resultados | Where-Object { $_.Tipo -eq "Camara CCTV" }).Count
$cOtros  = ($resultados | Where-Object { $_.Tipo -eq "Dispositivo de Red" }).Count

Write-Host "  - Computadoras (PCs / Servidores):     $cPC" -ForegroundColor Green
Write-Host "  - Impresoras de Red:                   $cImp" -ForegroundColor Cyan
Write-Host "  - Fotocopiadoras / Multifuncionales:   $cFoto" -ForegroundColor DarkCyan
Write-Host "  - Switches de Datos:                   $cSwitch" -ForegroundColor White
Write-Host "  - Routers / Gateways:                  $cRouter" -ForegroundColor Yellow
Write-Host "  - Routers Inalambricos (AP / WiFi):    $cWiFi" -ForegroundColor DarkYellow
Write-Host "  - Relojes Biometricos:                 $cBio" -ForegroundColor Magenta
Write-Host "  - Grabadores DVR / NVR:                $cDVR" -ForegroundColor DarkRed
Write-Host "  - Camaras de Seguridad CCTV:           $cCam" -ForegroundColor Yellow
if ($cOtros -gt 0) {
    Write-Host "  - Otros Dispositivos de Red:           $cOtros" -ForegroundColor Gray
}
Write-Host ("-" * 80) -ForegroundColor Gray
Write-Host "  Total de Equipos Activos:              $($resultados.Count)" -ForegroundColor Green
Write-Host "  Total de IPs Libres (SIN ASIGNAR):     $($ipsSinAsignar.Count)" -ForegroundColor DarkGray
Write-Host "  Total de Direcciones Auditadas:        $($resultados.Count + $ipsSinAsignar.Count)" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Gray

Write-Host "`n[+] Auditoria completada. Esta ventana permanece abierta para su consulta." -ForegroundColor Green
Write-Host "Presione cualquier tecla para cerrar esta ventana..." -ForegroundColor Gray
try {
    [void][System.Console]::ReadKey($true)
} catch {}
'@

                    # 3. Guardar el ejecutable de escaneo en la carpeta temporal del usuario
                    $scannerFile = Join-Path $env:TEMP "shellWil_ScanRed.ps1"
                    [System.IO.File]::WriteAllText($scannerFile, $scannerCode, [System.Text.Encoding]::UTF8)

                    # 4. Lanzamiento del proceso en NUEVA VENTANA de PowerShell independiente
                    Write-Host "  [+] Lanzando auditoria en una NUEVA VENTANA..." -ForegroundColor Green
                    Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$scannerFile`"", "-NetworkCIDR", "`"$segmentoElegido`"", "-RequestingIP", "`"$solicitanteIP`""

                    Write-Host "`n==========================================================================" -ForegroundColor Cyan
                    Write-Host "  [OK] El escaneo ha sido iniciado en una ventana independiente." -ForegroundColor Green
                    Write-Host "       Puede revisar el progreso y resultados en dicha ventana mientras" -ForegroundColor Gray
                    Write-Host "       este menu principal continua disponible para otras tareas." -ForegroundColor Gray
                    Write-Host "==========================================================================" -ForegroundColor Cyan
                    Write-Host ""
                    Read-Host "Presione ENTER para volver al menu principal..."
                }

                "3" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # 2. Solicitar la entrada del usuario (Equivalente a SET /P)
                    Write-Host "==============================================" -ForegroundColor Cyan
                    Write-Host "   REINICIO REMOTO DE EQUIPOS (Win 7 - 11)    " -ForegroundColor Cyan
                    Write-Host "==============================================" -ForegroundColor Cyan

                    $IPRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($IPRemota)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    # 3. Validar si el equipo responde (Ping) antes de intentar el comando
                    Write-Host "`nVerificando conexion con $IPRemota" -ForegroundColor Yellow

                    if (Test-Connection -ComputerName $IPRemota -Count 1 -Quiet) {
                        Write-Host "[OK] Equipo detectado en la red." -ForegroundColor Green
                        Write-Host "Enviando orden de reinicio forzado..." -ForegroundColor Yellow
                        
                        # 4. Ejecutar el comando de apagado
                        # /r = Reiniciar
                        # /f = Forzar cierre de apps
                        # /t 1 = Tiempo 1 segundo
                        # /m = Nombre/IP del equipo remoto
                        shutdown /r /f /t 1 /m \\$IPRemota
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "EXITO: La orden de reinicio ha sido aceptada por $IPRemota." -ForegroundColor Green
                        }
                        else {
                            Write-Host "ERROR: Acceso denegado o error de red (Codigo: $LASTEXITCODE)." -ForegroundColor Red
                            Write-Host "Asegurese de tener permisos de Admin y que el equipo remoto acepte comandos." -ForegroundColor Gray
                        }
                    }
                    else {
                        Write-Host "ERROR: No se pudo establecer contacto con $IPRemota." -ForegroundColor Red
                        Write-Host "El equipo esta apagado o el firewall bloquea el trafico." -ForegroundColor Gray
                    }
                    
                    Read-Host "Presione ENTER para continuar..."

                }

                "4" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # 2. Solicitar la entrada del usuario (Equivalente a SET /P)
                    Write-Host "==============================================" -ForegroundColor Cyan
                    Write-Host "   APAGADO REMOTO DE EQUIPOS (Win 7 - 11)    " -ForegroundColor Cyan
                    Write-Host "==============================================" -ForegroundColor Cyan

                    $IPRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($IPRemota)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    # 3. Validar si el equipo responde (Ping) antes de intentar el comando
                    Write-Host "`nVerificando conexion con $IPRemota" -ForegroundColor Yellow

                    if (Test-Connection -ComputerName $IPRemota -Count 1 -Quiet) {
                        Write-Host "[OK] Equipo detectado en la red." -ForegroundColor Green
                        Write-Host "Enviando orden de apagado forzado..." -ForegroundColor Yellow
                        
                        # 4. Ejecutar el comando de apagado
                        # /s = Apagar
                        # /f = Forzar cierre de apps
                        # /t 1 = Tiempo 1 segundo
                        # /m = Nombre/IP del equipo remoto
                        shutdown /s /f /t 1 /m \\$IPRemota
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "EXITO: La orden de apagado ha sido aceptada por $IPRemota." -ForegroundColor Green
                        }
                        else {
                            Write-Host "ERROR: Acceso denegado o error de red (Codigo: $LASTEXITCODE)." -ForegroundColor Red
                            Write-Host "Asegurese de tener permisos de Admin y que el equipo remoto acepte comandos." -ForegroundColor Gray
                        }
                    }
                    else {
                        Write-Host "ERROR: No se pudo establecer contacto con $IPRemota." -ForegroundColor Red
                        Write-Host "El equipo esta apagado o el firewall bloquea el trafico." -ForegroundColor Gray
                    }


                }

                "5" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # ==============================================================================
                    # CONFIGURACIÓN DE POLÍTICA CON MENSAJES DE ESTADO
                    # ==============================================================================
                    try {
                        $politicaActual = Get-ExecutionPolicy
                        
                        # Si la política es Restringida, intentamos elevarla a RemoteSigned
                        if ($politicaActual -eq "Restricted") {
                            Write-Host "Detectada politica 'Restricted'. Intentando cambiar..." -ForegroundColor Yellow
                            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
                            $nuevaPolitica = Get-ExecutionPolicy
                            Write-Host "Cambio exitoso. Politica actual de ejecucion: $nuevaPolitica" -ForegroundColor Green
                        } 
                        else {
                            # Si ya es Bypass, Unrestricted o RemoteSigned, informamos al usuario
                            Write-Host "Politica existente detectada: $politicaActual. No se requieren cambios." -ForegroundColor Cyan
                        }
                    } 
                    catch {
                        # Esta sección se activa si hay una invalidación (como el error de ámbito que tuviste)
                        $politicaEfectiva = Get-ExecutionPolicy
                        Write-Host "Nota: No se pudo modificar la politica (Scope Conflict)." -ForegroundColor Gray
                        Write-Host "Tipo de politica ejecutandose actualmente: $politicaEfectiva" -ForegroundColor White
                    }

                    # ==============================================================================
                    # 2. DEFINICIÓN DE RED Y ENTRADA DE USUARIO
                    Write-Host "==============================================" -ForegroundColor Cyan
                    Write-Host "     EXPLORADOR DE ESCRITORIO PUBLICO REMOTO  " -ForegroundColor Cyan
                    Write-Host "==============================================" -ForegroundColor Cyan

                    $IPRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($IPRemota)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    # ==============================================================================
                    # 3. CONSTRUCCIÓN DE RUTA Y APERTURA
                    # ==============================================================================
                    $rutaRemota = "\\$IPRemota\c$\Users\Public\Desktop"

                    Write-Host "`nIntentando conectar con: $rutaRemota..." -ForegroundColor Yellow

                    # Validamos si la ruta es accesible antes de intentar abrirla
                    if (Test-Path $rutaRemota) {
                        Write-Host "[OK] Conexion establecida. Abriendo carpeta..." -ForegroundColor Green
                        Start-Process explorer.exe -ArgumentList $rutaRemota
                    }
                    else {
                        Write-Host "ERROR: No se pudo acceder a la ruta." -ForegroundColor Red
                        Write-Host "Verifique que:" -ForegroundColor Gray
                        Write-Host "1. El equipo remoto este encendido."
                        Write-Host "2. Tenga permisos de Administrador (el recurso c$ es administrativo)."
                        Write-Host "3. Comparticion de archivos este activa en la PC remota."
                    }

                }            

                "6" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # ==============================================================================
                    # 1. CONFIGURACIÓN DE POLÍTICA CON MENSAJES DE ESTADO
                    # ==============================================================================
                    try {
                        $politicaActual = Get-ExecutionPolicy
                        if ($politicaActual -eq "Restricted") {
                            Write-Host "Detectada politica 'Restricted'. Intentando cambiar..." -ForegroundColor Yellow
                            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
                            Write-Host "Cambio exitoso. Politica actual: $(Get-ExecutionPolicy)" -ForegroundColor Green
                        } 
                        else {
                            Write-Host "Tipo de politica ejecutandose actualmente: $politicaActual" -ForegroundColor Cyan
                        }
                    } 
                    catch {
                        Write-Host "Nota: Usando politica de ejecucion efectiva: $(Get-ExecutionPolicy)" -ForegroundColor Gray
                    }

                    # ==============================================================================
                    # 2. ENTRADA DE USUARIO Y DEFINICIÓN DE RUTA
                    # ==============================================================================
                    Write-Host "`n==============================================" -ForegroundColor Cyan
                    Write-Host "    ACCESO A CARPETA STARTUP (Win 7 - 11)     " -ForegroundColor Cyan
                    Write-Host "==============================================" -ForegroundColor Cyan

                    $IPRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($IPRemota)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    # Definimos la ruta completa al menú de inicio (Carpeta de Inicio común para todos los usuarios)
                    $rutaStartUp = "\\$IPRemota\c$\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"

                    # ==============================================================================
                    # 3. VALIDACIÓN Y APERTURA DE LA CARPETA
                    # ==============================================================================
                    Write-Host "`nVerificando acceso a: $rutaStartUp" -ForegroundColor Yellow

                    if (Test-Path $rutaStartUp) {
                        Write-Host "[OK] Conexion exitosa. Abriendo carpeta StartUp..." -ForegroundColor Green
                        # Abre la carpeta en una nueva ventana del Explorador de Windows
                        Start-Process explorer.exe -ArgumentList $rutaStartUp
                    }
                    else {
                        Write-Host "ERROR: No se pudo acceder a la ruta." -ForegroundColor Red
                        Write-Host "Verifique permisos de Admin y que el recurso c$ esté habilitado en $IPRemota." -ForegroundColor Gray
                    }


                }
                "7" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # ==============================================================================
                    # 1. CONFIGURACIÓN DE POLÍTICA DE EJECUCIÓN
                    # ==============================================================================
                    try {
                        $politicaActual = Get-ExecutionPolicy
                        if ($politicaActual -eq "Restricted") {
                            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
                        }
                        Write-Host "Politica de ejecucion activa: $(Get-ExecutionPolicy)" -ForegroundColor Cyan
                    }
                    catch {
                        Write-Host "Nota: Usando politica de ejecucion del sistema: $(Get-ExecutionPolicy)" -ForegroundColor Cyan
                    }

                    Write-Host "Reiniciar PC: shutdown /g /f /t 2" -ForegroundColor Yellow
                    Write-Host "Apagar PC: shutdown /s /f /t 5" -ForegroundColor Yellow
                    Write-Host " "

                    # ==============================================================================
                    # 2. ENTRADA DE DATOS (Equivalente a SET /P)
                    # ==============================================================================
                    Write-Host "`n--- CONEXION REMOTA PSEXEC ---" -ForegroundColor Cyan

                    $usu = Read-Host "Introduzca Usuario dominio (gmsantacruz\usuario)"
                    $cla = Read-Host "Introduzca clave de usuario" -AsSecureString # Se oculta la clave por seguridad
                    $credOpt = $null
                    if (-not [string]::IsNullOrWhiteSpace($usu) -and $null -ne $cla) {
                        $credOpt = New-Object System.Management.Automation.PSCredential("gmsantacruz\$usu", $cla)
                    }
                    $IPFinal = Get-StandardIPPrompt -Credential $credOpt
                    if ([string]::IsNullOrWhiteSpace($IPFinal)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    # Convertir la clave segura a texto plano para PsExec (requerido por la herramienta)
                    $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))
                    $psexecPath = "C:\PSTools\PsExec.exe"

                    # ==============================================================================
                    # 3. VALIDACIÓN Y EJECUCIÓN
                    # ==============================================================================
                    if (Test-Path $psexecPath) {
                        Write-Host "`nIniciando sesion remota en $IPFinal..." -ForegroundColor Yellow
                        
                        # Argumentos: 
                        # -u Dominio\Usuario
                        # -p Clave
                        # -i Interactiva
                        # cmd (comando a ejecutar)
                        # Start-Process -FilePath $psexecPath -ArgumentList "\\$IPFinal -u gmsantacruz\$usu -p $claTexto -i cmd" -Wait

                        # -h: Este es el parámetro crucial para ejecutar con privilegios elevados (Run as Administrator)
                        # -i: Mantiene la sesión interactiva para que veas la ventana
                        # -accepteula: Evita interrupciones de licencia

                        $argumentos = "\\$IPFinal -u gmsantacruz\$usu -p $claTexto -h -i -accepteula cmd.exe"

                        Start-Process -FilePath $psexecPath -ArgumentList $argumentos #-Wait
                    } 
                    else {
                        Write-Host "ERROR: No se encontro PsExec.exe en $psexecPath" -ForegroundColor Red
                    }

                    Write-Host "`nSesion finalizada." -ForegroundColor Cyan

                }

                "8" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # ==============================================================================
                    # 1. CONFIGURACIÓN DE PRIVILEGIOS
                    # ==============================================================================
                    try {
                        $politicaActual = Get-ExecutionPolicy
                        if ($politicaActual -eq "Restricted") {
                            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
                        }
                        Write-Host "Politica de ejecucion activa: $(Get-ExecutionPolicy)" -ForegroundColor Cyan
                    }
                    catch {
                        Write-Host "Nota: Usando politica del sistema: $(Get-ExecutionPolicy)" -ForegroundColor Gray
                    }

                    # Sugerencias visuales de comandos útiles
                    Write-Host "`n[ COMANDOS UTILES ]" -ForegroundColor Gray
                    Write-Host "Reiniciar PC: Restart-Computer -Force" -ForegroundColor Yellow
                    Write-Host "Apagar PC: Stop-Computer -Force" -ForegroundColor Yellow

                    # ==============================================================================
                    # 2. ENTRADA DE DATOS MEJORADA
                    # ==============================================================================
                    Write-Host "`n--- CONEXION REMOTA PSEXEC (POWERSHELL MODE) ---" -ForegroundColor Cyan

                    $usu = Read-Host "Introduzca Usuario dominio (gmsantacruz\usuario)"
                    $cla = Read-Host "Introduzca clave de usuario" -AsSecureString 
                    $credOpt = $null
                    if (-not [string]::IsNullOrWhiteSpace($usu) -and $null -ne $cla) {
                        $credOpt = New-Object System.Management.Automation.PSCredential("gmsantacruz\$usu", $cla)
                    }
                    $IPFinal = Get-StandardIPPrompt -Credential $credOpt
                    if ([string]::IsNullOrWhiteSpace($IPFinal)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    # Conversión de credencial
                    $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))
                    $psexecPath = "C:\PSTools\PsExec.exe"

                    # ==============================================================================
                    # 3. EJECUCIÓN CON SOPORTE PARA AUTOCOMPLETADO
                    # ==============================================================================
                    if (Test-Path $psexecPath) {
                        Write-Host "`nAbriendo consola PowerShell en $IPFinal..." -ForegroundColor Green
                        Write-Host "Espere a que cargue el prompt remoto..." -ForegroundColor Gray

                        # -h: Parámetro esencial para solicitar privilegios elevados (High Integrity Token)
                        # -i: Permite que la sesión sea interactiva
                        # -accepteula: Omite el aviso de licencia de Sysinternals
                        # -NoExit: Mantiene la consola abierta tras cargar el perfil
                        # -ExecutionPolicy Bypass: Evita bloqueos por políticas de ejecución en la PC remota

                        $argumentos = "\\$IPFinal -u gmsantacruz\$usu -p $claTexto -h -i -accepteula powershell.exe -NoExit -ExecutionPolicy Bypass"

                        Start-Process -FilePath $psexecPath -ArgumentList $argumentos #-Wait
                    } 
                    else {
                        Write-Host "ERROR: PsExec.exe no detectado en $psexecPath" -ForegroundColor Red
                    }

                    Write-Host "`nSesion finalizada correctamente." -ForegroundColor Cyan
                    
                    Read-Host "Presione ENTER para continuar..."

                }

                "9" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    

                    Write-Host "`nSesion finalizada correctamente." -ForegroundColor Cyan
                    Read-Host "Presione ENTER para continuar..."

                }

                "9.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # 1. Entrada de red estandarizada
                    Write-Host "--- Configuracion de Energia GMSANTACRUZ ---" -ForegroundColor Cyan
                    $ipRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($ipRemota)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    # 2. Entrada de tiempo de pantalla
                    Write-Host "`n--- Configuracion de Tiempos ---" -ForegroundColor White
                    $minutosPantalla = Read-Host "Minutos para apagar la PANTALLA (Ej. 30)"

                    # Validación de entradas numéricas
                    if ($minutosPantalla -notmatch '^\d+$') {
                        Write-Host "ERROR: El valor de minutos debe ser numerico." -ForegroundColor Red
                        Pause
                        break
                    }

                    Write-Host "`nConectando a: $ipRemota..." -ForegroundColor Yellow

                    try {
                        # Verificamos conexión básica
                        if (Test-Connection -ComputerName $ipRemota -Count 1 -Quiet) {
                            
                            $process = [wmiclass]"\\$ipRemota\root\cimv2:Win32_Process"
                            Write-Host "Aplicando configuraciones en el equipo remoto..." -ForegroundColor Magenta

                            # Definición de comandos
                            # monitor-timeout: Valor ingresado por usuario
                            # standby-timeout: 0 (Nunca)
                            $comandos = @(
                                "powercfg /change monitor-timeout-ac $minutosPantalla",
                                "powercfg /change monitor-timeout-dc $minutosPantalla",
                                "powercfg /change standby-timeout-ac 0",
                                "powercfg /change standby-timeout-dc 0"
                            )

                            $errorDetectado = $false
                            foreach ($cmd in $comandos) {
                                $resultado = $process.Create($cmd)
                                if ($resultado.ReturnValue -ne 0) {
                                    Write-Host "Fallo en: $cmd (Código: $($resultado.ReturnValue))" -ForegroundColor Red
                                    $errorDetectado = $true
                                }
                            }

                            if (-not $errorDetectado) {
                                Write-Host "`n================================================" -ForegroundColor White
                                Write-Host " ¡EXITO! Configuracion aplicada en $ipRemota" -ForegroundColor Green
                                Write-Host " Pantalla: $minutosPantalla minutos" -ForegroundColor White
                                Write-Host " Suspension: Nunca" -ForegroundColor White
                                Write-Host "================================================" -ForegroundColor White
                            }

                        }
                        else {
                            Write-Host "ERROR: El equipo $ipRemota no responde (Offline)." -ForegroundColor Red
                        }
                    }
                    catch {
                        Write-Host "ERROR CRITICO: No se pudo completar la accion." -ForegroundColor Red
                        Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Gray
                    }

                    #Read-Host
                    
                    Read-Host "Presione ENTER para continuar..."

                }

                "10" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    Write-Host "MOSTRAR IMPRESORAS DISPONIBLES EN UNA PC REMOTA" -ForegroundColor Cyan

                    $computer = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($computer)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }
                    $psExecPath = "C:\PSTools\psexec.exe"

                    if (-not (Test-Path $psExecPath)) {
                        Write-Host "[-] Error: No se encontró PsExec en C:\PSTools" -ForegroundColor Red
                        return
                    }

                    if ($computer) {
                        Write-Host "[*] Consultando todas las impresoras en $computer..." -ForegroundColor Cyan

                        # Ejecutamos WMIC. Agregamos '2>$null' para ignorar el banner de PsExec
                        # El comando busca Name, Default, Network y Status
                        $rawOutput = & $psExecPath \\$computer -accepteula -s cmd /c "wmic printer get Name,Default,Network,Status /format:csv" 2>$null

                        # Encabezado
                        Write-Host "`nREPORTE DE IMPRESORAS: $computer" -ForegroundColor White
                        $formato = "{0,-45} {1,-10} {2,-10} {3,-12}"
                        Write-Host ($formato -f "NOMBRE", "RED", "ESTADO", "PREDETERMINADA")
                        Write-Host ("-" * 82)

                        $encontradas = 0

                        foreach ($line in $rawOutput) {
                            # LIMPIEZA PROFUNDA: Quitamos espacios, retornos de carro y nulos
                            $cleanLine = $line.Trim().Replace("`0", "")
                            
                            # Si la línea tiene comas (formato CSV) y no es el encabezado de WMIC
                            if ($cleanLine -match "," -and -not $cleanLine.StartsWith("Node")) {
                                $data = $cleanLine -split ","
                                
                                # Validamos que tengamos suficientes columnas
                                if ($data.Count -ge 4) {
                                    $encontradas++
                                    # Estructura WMIC CSV: [0]Node, [1]Default, [2]Name, [3]Network, [4]Status
                                    $esPredet = $data[1].Trim()
                                    $nombre = $data[2].Trim()
                                    $esRed = $data[3].Trim()
                                    $estado = $data[4].Trim()

                                    $txtRed = "Local"
                                    if ($esRed -eq "TRUE") {
                                        $txtRed = "SI"
                                    }
                                    $txtPredet = ""
                                    if ($esPredet -eq "TRUE") {
                                        $txtPredet = "<-- PREDET."
                                    }

                                    Write-Host ($formato -f $nombre, $txtRed, $estado, $txtPredet)
                                }
                            }
                        }

                        if ($encontradas -eq 0) {
                            Write-Host "[-] No se detectaron impresoras o hubo un problema de conexión." -ForegroundColor Yellow
                            Write-Host "[!] Verifique que el firewall permita SMB (Puerto 445) y WMI en la PC remota." -ForegroundColor Gray
                        }
                        else {
                            Write-Host "`n[*] Total de impresoras encontradas: $encontradas" -ForegroundColor Green
                        }
                    }

                    Read-Host "Presione ENTER para continuar..."

                }

                "10.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # ==============================================================================
                    # SCRIPT: CONSULTA DE IMPRESORAS REMOTAS CON AUTO-ACTIVACIÓN DE SERVICIO
                    # Objetivo: Obtener modelo, fabricante, puerto y estado de impresoras de un usuario
                    # Compatibilidad: Windows 7, 8.1, 10 y 11 (PC de Escritorio)
                    # ==============================================================================

                    function Mostrar-ImpresorasUsuarioRemoto {
                        param (
                            [string]$ip,
                            [string]$usuarioTarget
                        )

                        Write-Host ''
                        Write-Host '========================================================================' -ForegroundColor Yellow
                        Write-Host '             INSPECCIONANDO IMPRESORAS EN EL EQUIPO REMOTO              ' -ForegroundColor Yellow
                        Write-Host '========================================================================' -ForegroundColor Yellow

                        # 1. VERIFICACIÓN Y AUTO-ACTIVACIÓN DEL SERVICIO REMOTEREGISTRY
                        Write-Host ' -> Verificando estado del servicio "Registro Remoto"...' -ForegroundColor Cyan
                        try {
                            $servicioReg = Get-WmiObject -Class Win32_Service -ComputerName $ip -Filter "Name='RemoteRegistry'" -ErrorAction Stop
                            
                            if ($servicioReg.StartMode -eq 'Disabled') {
                                Write-Host '    [!] El servicio estaba DESHABILITADO. Cambiando a Automatico...' -ForegroundColor DarkYellow
                                $null = $servicioReg.ChangeStartMode('Automatic')
                                Start-Sleep -Milliseconds 500
                            }
                            
                            if ($servicioReg.State -ne 'Running') {
                                Write-Host '    [!] El servicio estaba DETENIDO. Iniciando servicio remotamente...' -ForegroundColor DarkYellow
                                $null = $servicioReg.StartService()
                                Start-Sleep -Seconds 2
                            }
                            Write-Host ' -> Servicio "Registro Remoto" ACTIVO y operando.' -ForegroundColor Green
                        }
                        catch {
                            Write-Host ' [!] ERROR CRÍTICO: No se pudo verificar o iniciar el servicio "RemoteRegistry".' -ForegroundColor Red
                            Write-Host '     Asegurese de estar ejecutando PowerShell como Administrador.' -ForegroundColor DarkYellow
                            Write-Host '========================================================================' -ForegroundColor Yellow
                            return
                        }

                        # 2. CONEXIÓN AL REGISTRO REMOTO PARA BUSCAR EL SID DEL USUARIO
                        try {
                            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('Users', $ip)
                            
                            $userSID = $null
                            $subKeys = $reg.GetSubKeyNames()
                            
                            foreach ($key in $subKeys) {
                                if ($key -match '^S-1-5-21-') {
                                    try {
                                        $objSID = New-Object System.Security.Principal.SecurityIdentifier($key)
                                        $resolvedUser = $objSID.Translate([System.Security.Principal.NTAccount])
                                        if ($resolvedUser.Value -match $usuarioTarget) {
                                            $userSID = $key
                                            break
                                        }
                                    }
                                    catch { continue }
                                }
                            }

                            if (-not $userSID) {
                                Write-Host " [!] Error: No se encontro perfil o sesion activa para el usuario '$usuarioTarget'." -ForegroundColor Red
                                Write-Host '     El usuario debe haber iniciado sesion al menos una vez en esta PC.' -ForegroundColor DarkYellow
                                $reg.Close()
                                Write-Host '========================================================================' -ForegroundColor Yellow
                                return
                            }

                            # 3. LEER LA IMPRESORA PREDETERMINADA DEL USUARIO
                            $pathPredeterminada = "$userSID\Software\Microsoft\Windows NT\CurrentVersion\Windows"
                            $keyWindows = $reg.OpenSubKey($pathPredeterminada)
                            $deviceString = $null
                            if ($keyWindows) {
                                $deviceString = $keyWindows.GetValue('Device')
                            }
                            $nombrePredeterminada = ''
                            if ($deviceString) {
                                $nombrePredeterminada = ($deviceString -split ',')[0]
                            }
                            if ($keyWindows) { $keyWindows.Close() }

                            # 4. CONSULTAR IMPRESORAS VÍA WMI (Compatible desde Windows 7)
                            $wmiImpresoras = Get-WmiObject -Class Win32_Printer -ComputerName $ip -ErrorAction SilentlyContinue

                            if (-not $wmiImpresoras) {
                                Write-Host ' [!] No se pudieron extraer las impresoras del sistema a traves de WMI.' -ForegroundColor Red
                                $reg.Close()
                                Write-Host '========================================================================' -ForegroundColor Yellow
                                return
                            }

                            # 5. PROCESAR E IMPRIMIR LA TABLA DE DATOS PUNTUALES
                            Write-Host ''
                            $resultadoTabla = foreach ($impresora in $wmiImpresoras) {
                                
                                # Clasificación del estado "Predeterminado"
                                $esPredeterminada = 'No'
                                if ($impresora.Name -eq $nombrePredeterminada) {
                                    $esPredeterminada = 'PREDETERMINADO'
                                }

                                # Identificación simplificada de Fabricantes basado en el Driver
                                $fabricante = 'Generico / Virtual'
                                if ($impresora.DriverName -match 'HP|Hewlett') { $fabricante = 'HP' }
                                elseif ($impresora.DriverName -match 'Epson') { $fabricante = 'Epson' }
                                elseif ($impresora.DriverName -match 'Canon') { $fabricante = 'Canon' }
                                elseif ($impresora.DriverName -match 'Brother') { $fabricante = 'Brother' }
                                elseif ($impresora.DriverName -match 'Ricoh') { $fabricante = 'Ricoh' }
                                elseif ($impresora.DriverName -match 'Zebra') { $fabricante = 'Zebra' }
                                else { $fabricante = ($impresora.DriverName -split ' ')[0] }

                                # Estado operacional puntual (Activo / No Activo)
                                $estadoActivo = 'Activo'
                                if ($impresora.DetectedErrorState -ne 0 -or $impresora.PrinterStatus -eq 1 -or $impresora.WorkOffline) {
                                    $estadoActivo = 'No Activo'
                                }

                                # AJUSTE: Mapeo ordenado incluyendo el Nombre/Modelo de la impresora
                                New-Object PSObject -Property @{
                                    'Nombre / Modelo' = $impresora.Name
                                    'Fabricante'      = $fabricante
                                    'Predeterminado'  = $esPredeterminada
                                    'Puerto'          = $impresora.PortName
                                    'Estado'          = $estadoActivo
                                } | Select-Object 'Nombre / Modelo', Fabricante, Predeterminado, Puerto, Estado
                            }

                            # Mostrar tabla organizada de forma limpia y ajustada automáticamente al ancho
                            $resultadoTabla | Format-Table -AutoSize
                            $reg.Close()

                        }
                        catch [UnauthorizedAccessException] {
                            Write-Host ' [!] ERROR DE PRIVILEGIOS: Acceso denegado al registro remoto.' -ForegroundColor Red
                            Write-Host '     Asegurese de que su cuenta tenga permisos de administrador en la PC destino.' -ForegroundColor DarkYellow
                        }
                        catch {
                            Write-Host ' [!] ERROR INESPERADO al comunicarse con la base del registro de la PC remota.' -ForegroundColor Red
                        }
                        Write-Host '========================================================================' -ForegroundColor Yellow
                    }

                    # --- Bloque de Control / Ejecución Inicial ---
                    Write-Host '--- Monitor de Impresoras GMSANTACRUZ ---' -ForegroundColor Cyan
                    $ipRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($ipRemota)) {
                        Write-Host 'Operacion cancelada.' -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }
                    $fullIP = $ipRemota
                    Write-Host "`n--- Consultando Host: $fullIP ---" -ForegroundColor Cyan
                            
                    try {
                        # 3. Ejecución optimizada de quser (query user)
                        $resultado = quser /server:$fullIP 2>&1

                        if ($resultado -like "*No hay ningún usuario*" -or $resultado -like "*No user exists*") {
                            Write-Host "Estado: Equipo encendido, pero sin sesiones activas." -ForegroundColor Cyan
                        }
                        elseif ($resultado -like "*Error*") {
                            Write-Host "Error: No se pudo establecer conexion RPC con $fullIP." -ForegroundColor Red
                            Write-Host "Verifique que el equipo esté en línea y el Firewall permita RPC." -ForegroundColor Gray
                        }
                        else {
                            $resultado | Where-Object { $_.Trim() -ne "" }
                        }
                    }
                    catch {
                        Write-Host "Error inesperado al ejecutar el comando." -ForegroundColor Red
                    }

                    Write-Host ""
                    Write-Host '========================================================================' -ForegroundColor Yellow
                    $usuarioInput = Read-Host 'Ingrese el NOMBRE DE USUARIO de dominio'

                    if ([string]::IsNullOrEmpty($usuarioInput)) {
                        Write-Host 'ERROR: El nombre de usuario no puede estar vacio.' -ForegroundColor Red
                        $null = Read-Host -Prompt 'Presione ENTER para salir...'
                        break
                    }

                    Write-Host ''
                    Write-Host "Verificando enlace de red con $ipRemota..." -ForegroundColor Yellow

                    if (Test-Connection -ComputerName $ipRemota -Count 1 -Quiet) {
                        Mostrar-ImpresorasUsuarioRemoto -ip $ipRemota -usuarioTarget $usuarioInput
                    }
                    else {
                        Write-Host "ERROR: El equipo $ipRemota se encuentra fuera de linea (Offline)." -ForegroundColor Red
                    }

                    Write-Host ''                    
            
                }

                "10.2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # 1. Entrada de datos
                    $targetIP = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($targetIP)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    if ($true) {
                        Write-Host "`n--- Filtrando Impresoras Fisicas en: $targetIP ---" -ForegroundColor Yellow

                        try {
                            # 2. Obtención de datos WMI
                            $printers = Get-WmiObject -Class Win32_Printer -ComputerName $targetIP -ErrorAction Stop

                            if ($printers) {
                                # 3. Filtrado y Procesamiento
                                $reporte = $printers | ForEach-Object {
                                    # Filtro para ignorar impresoras virtuales comunes
                                    if ($_.Name -notmatch "PDF|XPS|OneNote|Microsoft|Send To|Fax") {
                                        
                                        # Determinación de estado (Online/Offline)
                                        $estado = "Conectado"
                                        if ($_.WorkOffline -eq $true -or $_.PrinterStatus -eq 7) { 
                                            $estado = "Sin Conexion" 
                                        }

                                        # Construcción del objeto de salida
                                        $fabricante = $_.DriverName
                                        if ($_.DriverName -match ' ') {
                                            $fabricante = $_.DriverName.Split(' ')[0]
                                        }
                                        $predeterminada = ""
                                        if ($_.Default) {
                                            $predeterminada = "  [ACTIVA]"
                                        }

                                        New-Object PSObject -Property @{
                                            Fabricante     = $fabricante
                                            Nombre         = $_.Name
                                            Estado         = $estado
                                            Predeterminada = $predeterminada
                                            Puerto         = $_.PortName
                                        } | Select-Object Fabricante, Nombre, Estado, Predeterminada, Puerto
                                    }
                                }

                                # 4. Mostrar resultados
                                if ($reporte) {
                                    $reporte | Sort-Object Estado | Format-Table -AutoSize
                                }
                                else {
                                    Write-Host "No se encontraron impresoras físicas (solo virtuales)." -ForegroundColor Cyan
                                }
                            }
                        }
                        catch {
                            Write-Host "ERROR: No se pudo conectar a $targetIP. Verifique red y permisos." -ForegroundColor Red
                        }
                    }
            
                    else {
                        Write-Host "Entrada invalida." -ForegroundColor Red
                    }

                    Write-Host "`Consulta finalizado..." -ForegroundColor Cyan
                }

                "11" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    Write-Host "Por favor seleccione una sub-opcion especifica (11.1, 11.2 o 11.3)" -ForegroundColor Yellow
                }

                "11.1" {
                    Invoke-HabilitarServiciosRSATLocal
                }

                "11.2" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    Write-Host "Deshabilitando ejecucion remota y de scripts localmente..." -ForegroundColor Cyan
                    
                    $isAdmin = Test-IsProcessAdmin
                    if (-not $isAdmin) {
                        Write-Host "`n[ERROR] Esta accion requiere privilegios de Administrador (Token Elevado)." -ForegroundColor Red
                        Write-Host "Por favor ejecute la consola como Administrador." -ForegroundColor Yellow
                    } else {
                        # 1. Deshabilitar PSRemoting
                        try {
                            Write-Host "Deteniendo y deshabilitando servicio WinRM..." -ForegroundColor Gray
                            Disable-PSRemoting -Force -ErrorAction Stop
                            Write-Host "[OK] PSRemoting deshabilitado localmente." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "ADVERTENCIA: No se pudo deshabilitar PSRemoting localmente: $($_.Exception.Message)" -ForegroundColor Yellow
                        }

                        # 2. Configurar ExecutionPolicy con deteccion de GPO
                        try {
                            $polList = Get-ExecutionPolicy -List
                            $mPol = ($polList | Where-Object { $_.Scope -eq 'MachinePolicy' }).ExecutionPolicy
                            $uPol = ($polList | Where-Object { $_.Scope -eq 'UserPolicy' }).ExecutionPolicy
                            if ($mPol -ne 'Undefined' -or $uPol -ne 'Undefined') {
                                Write-Host "[INFO] Directiva de Dominio (GPO) presente. No se modifican directivas corporativas persistentes." -ForegroundColor Cyan
                            } else {
                                Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope LocalMachine -Force -ErrorAction Stop
                                Write-Host "[OK] Politica establecida a Restricted para LocalMachine." -ForegroundColor Green
                            }
                        }
                        catch {
                            try {
                                Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser -Force -ErrorAction Stop
                                Write-Host "[OK] Politica establecida a Restricted para CurrentUser." -ForegroundColor Green
                            }
                            catch {
                                Write-Host "[-] Aviso al restringir directiva: $($_.Exception.Message)" -ForegroundColor Yellow
                            }
                        }
                    }
                }

                "11.3" {
                    Invoke-InstalarRSATLocal
                }

                "12" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    Write-Host "Por favor seleccione una sub-opcion especifica (12.1, 12.2 o 12.3)" -ForegroundColor Yellow
                }

                "12.1" {
                    Invoke-HabilitarServiciosRSATRemoto
                }

                "12.2" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    $ipRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($ipRemota)) { 
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                    }
                    else {
                        
                        Write-Host "Deshabilitando ejecucion remota en $ipRemota..." -ForegroundColor Cyan
                        $process = Get-WmiObject -List -ComputerName $ipRemota -Class Win32_Process -ErrorAction SilentlyContinue
                        if ($process) {
                            $cmd = "powershell.exe -NoProfile -Command `"try { Disable-PSRemoting -Force } catch {}; try { Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope LocalMachine -Force } catch { Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser -Force }`""
                            $result = $process.Create($cmd)
                            if ($result.ReturnValue -eq 0) {
                                Write-Host "Comando de deshabilitacion enviado correctamente via WMI. Esperando 5 segundos..." -ForegroundColor Green
                                Start-Sleep -Seconds 5
                            }
                            else {
                                Write-Host "Error al crear proceso via WMI (Codigo: $($result.ReturnValue))." -ForegroundColor Red
                            }
                        }
                        else {
                            Write-Host "WMI no responde. Intentando via PsExec si esta disponible..." -ForegroundColor Yellow
                            $psexecPath = "C:\PSTools\PsExec.exe"
                            if (Test-Path $psexecPath) {
                                $arg = "\\$ipRemota -accepteula -s powershell.exe -NoProfile -Command `"try { Disable-PSRemoting -Force } catch {}; try { Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope LocalMachine -Force } catch { Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser -Force }`""
                                Start-Process -FilePath $psexecPath -ArgumentList $arg -Wait -NoNewWindow
                                Write-Host "Comando enviado via PsExec." -ForegroundColor Green
                            }
                            else {
                                Write-Host "ERROR: No se pudo conectar via WMI ni se encontro PsExec en C:\PSTools\PsExec.exe" -ForegroundColor Red
                            }
                        }
                    }
                }

                "12.3" {
                    Invoke-InstalarRSATRemoto
                }

                "13" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    Write-Host "Por favor seleccione una sub-opcion especifica (13.1 a 13.7)" -ForegroundColor Yellow
                    Write-Host ""
                }

                "13.1" {
                    cabecera
                    menuOpcion "Se encuentra en: OPTIMIZACION Y LIMPIEZA REMOTA -> Eliminar Archivos TEMPORALES CARPETAS"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        Invoke-RemoteCleanTempFolders -ctx $ctx
                    }
                    Write-Host ""
                }

                "13.2" {
                    cabecera
                    menuOpcion "Se encuentra en: OPTIMIZACION Y LIMPIEZA REMOTA -> Eliminar Archivos Temporales ProgramData"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        Invoke-RemoteCleanProgramData -ctx $ctx
                    }
                    Write-Host ""
                }

                "13.3" {
                    cabecera
                    menuOpcion "Se encuentra en: OPTIMIZACION Y LIMPIEZA REMOTA -> Liberar RAM Remoto"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        Invoke-RemoteCleanRAM -ctx $ctx
                    }
                    Write-Host ""
                }

                "13.4" {
                    cabecera
                    menuOpcion "Se encuentra en: OPTIMIZACION Y LIMPIEZA REMOTA -> Liberar Procesador Remoto"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        Invoke-RemoteCleanCPU -ctx $ctx
                    }
                    Write-Host ""
                }

                "13.5" {
                    cabecera
                    menuOpcion "Se encuentra en: OPTIMIZACION Y LIMPIEZA REMOTA -> Vaciar Papelera de Reciclaje"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        Invoke-RemoteCleanRecycleBin -ctx $ctx
                    }
                    Write-Host ""
                }

                "13.6" {
                    cabecera
                    menuOpcion "Se encuentra en: OPTIMIZACION Y LIMPIEZA REMOTA -> Eliminacion Avanzada (Todos los Usuarios)"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        Invoke-RemoteCleanAdvancedProfiles -ctx $ctx
                    }
                    Write-Host ""
                }

                "13.7" {
                    cabecera
                    menuOpcion "Se encuentra en: OPTIMIZACION Y LIMPIEZA REMOTA -> Limpieza General de Archivos en PC Remoto"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        Invoke-RemoteCleanGeneral -ctx $ctx
                    }
                    Write-Host ""
                }

                "14" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    Write-Host "Por favor seleccione una sub-opcion especifica (14.1 o 14.2)" -ForegroundColor Yellow
                    Write-Host ""
                    Read-Host "Presione ENTER para continuar..."
                }

                "14.1" {
                    cabecera
                    menuOpcion "Se encuentra en: DEFRAGMENTACION REMOTA -> Unidad C: (Principal)"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        $ipRemota = $ctx.ComputerName
                        $cred = $ctx.Credential
                        
                        Ejecutar-DefragRemoto -ipRemota $ipRemota -cred $cred -driveLetter "C"
                    }
                    Write-Host ""
                }

                "14.2" {
                    cabecera
                    menuOpcion "Se encuentra en: DEFRAGMENTACION REMOTA -> Otras Unidades"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        $ipRemota = $ctx.ComputerName
                        $cred = $ctx.Credential
                        
                        Write-Host "Obteniendo listado de unidades logicas en el equipo remoto..." -ForegroundColor Yellow
                        try {
                            if ($null -ne $cred) {
                                $disks = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType = 3" -ComputerName $ipRemota -Credential $cred -ErrorAction Stop
                            } else {
                                $disks = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType = 3" -ComputerName $ipRemota -ErrorAction Stop
                            }

                            if ($disks) {
                                Write-Host "`n=== UNIDADES LOGICAS DETECTADAS EN EL EQUIPO REMOTO ===" -ForegroundColor Cyan
                                Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                                Write-Host ("{0,-10} {1,-25} {2,-14} {3,-14}" -f "Unidad", "Etiqueta", "Tamano (GB)", "Libre (GB)") -ForegroundColor White
                                foreach ($d in $disks) {
                                    $sizeGB = [Math]::Round($d.Size / 1GB, 2)
                                    $freeGB = [Math]::Round($d.FreeSpace / 1GB, 2)
                                    $label = if ($d.VolumeName) { $d.VolumeName } else { "[Sin Etiqueta]" }
                                    Write-Host ("{0,-10} {1,-25} {2,-14} {3,-14}" -f $d.DeviceID, $label, $sizeGB, $freeGB) -ForegroundColor White
                                }
                                Write-Host "------------------------------------------------------------------`n" -ForegroundColor Gray

                                $letra = Read-Host "Ingrese la letra de la unidad a desfragmentar (ej. D)"
                                $letra = $letra.Replace(":", "").Trim().ToUpper()

                                $validLetters = $disks | ForEach-Object { $_.DeviceID.Replace(":", "").Trim().ToUpper() }
                                if ($letra -and $validLetters -contains $letra) {
                                    Ejecutar-DefragRemoto -ipRemota $ipRemota -cred $cred -driveLetter $letra
                                }
                                else {
                                    Write-Host "[ERROR] La unidad seleccionada no existe o no es valida." -ForegroundColor Red
                                }
                            }
                            else {
                                Write-Host "[ADVERTENCIA] No se detectaron unidades de disco local en el equipo remoto." -ForegroundColor Yellow
                            }
                        }
                        catch {
                            Write-Host "[ERROR] No se pudo obtener el listado de unidades: $_" -ForegroundColor Red
                        }
                    }
                    Write-Host ""
                }

                "30" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    Write-Host "`n[!] Reiniciando herramienta..." -ForegroundColor Cyan

                    # Si estamos en entorno de desarrollo, reconstruir primero
                    psReconstruirSiDesarrollo

                    # Start-Sleep -Milliseconds 500
                    Start-Sleep -Seconds 2
                    
                    # Recuperamos la ruta que guardamos en la cabecera .bat
                    $ruta = $env:SCRIPT_PATH
                    Write-Host "Ruta del Software:....... $ruta" -ForegroundColor Green
                    Start-Sleep -Seconds 3
                    
                    if ($ruta -and (Test-Path $ruta)) {
                        # Lanzamos el proceso usando CMD para que interprete el .bat correctamente
                        Start-Process cmd.exe -ArgumentList "/c `"$ruta`""
                        exit
                    }
                    else {
                        Write-Error "Error: No se pudo localizar la variable SCRIPT_PATH."
                        Pause
                    }
                }

                "31" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    Write-Host "`n[!] Descargando y reiniciando desde repositorio remoto..." -ForegroundColor Cyan
                    Start-Sleep -Seconds 2
                    Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "irm https://raw.githubusercontent.com/spwil/shellWil/main/ShellSW.bat | iex"
                    exit
                }

                "100" {
                    $salirSub100 = $false
                    do {
                        try {
                            cabecera
                            Write-Header " 100. CAPTURA DE PANTALLA REMOTA (SCREENSHOT) "
                            Write-Host "  1. Tomar captura usando PsExec (Recomendado)." -ForegroundColor Green
                            Write-Host "  2. Tomar captura usando Tarea Programada (Alternativa)." -ForegroundColor Yellow
                            Write-Host "  --------------------------------------------------"
                            Write-Host "  0. V O L V E R   A L   M E N U   A N T E R I O R"
                            Write-Header "==============================================================="
                            
                            $op100 = Read-Host "Seleccione la tarea a realizar"
                            
                            switch ($op100) {
                                "1" {
                                    cabecera
                                    menuOpcion "Se encuentra en el SUB_MENU: 100 ;;; Opcion: $op100"
                                    
                                    Write-Host "`n--- CAPTURA DE PANTALLA REMOTA CON PSEXEC ---" -ForegroundColor Cyan
                                    
                                    $usu = Read-Host "Introduzca Usuario dominio (gmsantacruz\usuario)"
                                    $cla = Read-Host "Introduzca clave de usuario" -AsSecureString
                                    $credOpt = $null
                                    if (-not [string]::IsNullOrWhiteSpace($usu) -and $null -ne $cla) {
                                        $credOpt = New-Object System.Management.Automation.PSCredential("gmsantacruz\$usu", $cla)
                                    }
                                    $IPFinal = Get-StandardIPPrompt -Credential $credOpt
                                    if ([string]::IsNullOrWhiteSpace($IPFinal)) {
                                        Write-Host "Operacion cancelada." -ForegroundColor Red
                                        Read-Host "Presione ENTER para continuar..."
                                        break
                                    }
                                    
                                    $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))
                                    $psexecPath = "C:\PSTools\PsExec.exe"
                                    
                                    if (-not (Test-Path $psexecPath)) {
                                        Write-Host "[-] ERROR: PsExec.exe no detectado en $psexecPath" -ForegroundColor Red
                                        Write-Host "Coloque PsExec.exe en C:\PSTools\ para habilitar esta funcion." -ForegroundColor Gray
                                        Read-Host "Presione ENTER para continuar..."
                                        break
                                    }
                                    
                                    # Resolución de Hostname para soporte Kerberos en Dominio
                                    $computerTarget = $IPFinal
                                    Write-Host "[*] Resolviendo Hostname de $IPFinal..." -ForegroundColor Gray
                                    try {
                                        $entry = [System.Net.Dns]::GetHostEntry($IPFinal)
                                        $computerTarget = $entry.HostName.Split('.')[0]
                                        Write-Host "[+] Hostname resuelto: $computerTarget (Kerberos habilitado)" -ForegroundColor Green
                                    }
                                    catch {
                                        Write-Host "[-] No se pudo resolver Hostname. Usando IP directamente: $IPFinal" -ForegroundColor Yellow
                                    }
                                    
                                    # 1. Detectar ID de sesión activa del usuario (con reintento de habilitación de administración remota)
                                    Write-Host "[*] Detectando sesion de usuario activa..." -ForegroundColor Gray
                                    $sessionId = $null
                                    $intentosMax = 2
                                    $intento = 0
                                    
                                    while ($null -eq $sessionId -and $intento -lt $intentosMax) {
                                        $intento++
                                        try {
                                            # Obtener ID de la sesión donde corre explorer.exe
                                            $sessionId = (Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" -ComputerName $computerTarget).SessionId | Select-Object -First 1
                                        }
                                        catch {
                                            Write-Host "[-] No se pudo consultar la sesion via WMI (Intento $intento de $intentosMax)." -ForegroundColor Yellow
                                        }
                                        
                                        # Fallback a qwinsta si falla WMI
                                        if ($null -eq $sessionId) {
                                            $qwinstaOut = qwinsta /server:$computerTarget
                                            foreach ($line in $qwinstaOut) {
                                                if ($line -like "*Active*") {
                                                    $parts = $line -split '\s+'
                                                    if ($parts[2] -match '^\d+$') { $sessionId = $parts[2] }
                                                    elseif ($parts[3] -match '^\d+$') { $sessionId = $parts[3] }
                                                }
                                            }
                                        }
                                        
                                        # Si falla la detección en el primer intento, ejecutamos el script de habilitación remota reutilizando la función
                                        if ($null -eq $sessionId -and $intento -lt $intentosMax) {
                                            Write-Host "`n[!] No se pudo conectar a $computerTarget. Intentando habilitar WMI/RPC/WinRM con las credenciales proporcionadas..." -ForegroundColor Magenta
                                            psHabilitarAdministracionRemota -targetInput $computerTarget -username $usu -passwordText $claTexto
                                            Write-Host "[*] Reintentando conexion..." -ForegroundColor Cyan
                                            Start-Sleep -Seconds 3
                                        }
                                    }
                                    
                                    if ($null -eq $sessionId) {
                                        Write-Host "[-] ERROR: No se pudo identificar una sesion de usuario activa en $computerTarget." -ForegroundColor Red
                                        Write-Host "Es posible que la PC este bloqueada, sin usuarios activos o inaccesible por completo." -ForegroundColor Gray
                                        Read-Host "Presione ENTER para continuar..."
                                        break
                                    }
                                    
                                    Write-Host "[+] Sesion activa detectada: ID $sessionId" -ForegroundColor Green
                                    
                                    # 2. Generar el script de captura temporal y el wrapper VBS para ejecución silenciosa
                                    $localTempScript = Join-Path $env:TEMP "cap_temp.ps1"
                                    $localTempVBS = Join-Path $env:TEMP "run_temp.vbs"
                                    $remoteTempDir = "\\$computerTarget\c$\Windows\Temp"
                                    $remoteTempScript = "$remoteTempDir\cap.ps1"
                                    $remoteTempVBS = "$remoteTempDir\run.vbs"
                                    
                                    $scriptCode = @"
[System.Reflection.Assembly]::LoadWithPartialName('System.Drawing') | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
try {
    `$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    `$bmp = New-Object System.Drawing.Bitmap `$bounds.Width, `$bounds.Height
    `$graphics = [System.Drawing.Graphics]::FromImage(`$bmp)
    `$graphics.CopyFromScreen(`$bounds.Location, [System.Drawing.Point]::Empty, `$bounds.Size)
    `$graphics.Dispose()
    `$bmp.Save('C:\Windows\Temp\screen.png', [System.Drawing.Imaging.ImageFormat]::Png)
    `$bmp.Dispose()
    Write-Output "Captura de pantalla realizada con exito."
} catch {
    Write-Error `$_.Exception.Message
}
"@

                                    # El parámetro 0 oculta la ventana por completo. True hace que wscript espere a que termine PowerShell.
                                    $vbsCode = @"
Set objShell = CreateObject("WScript.Shell")
objShell.Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Windows\Temp\cap.ps1", 0, True
"@
                                    
                                    try {
                                        # Escribir archivos temporales locales
                                        $scriptCode | Out-File -FilePath $localTempScript -Encoding utf8 -Force
                                        $vbsCode | Out-File -FilePath $localTempVBS -Encoding ascii -Force
                                        
                                        # Copiar archivos al host remoto
                                        if (Test-Path $remoteTempDir) {
                                            Copy-Item -Path $localTempScript -Destination $remoteTempScript -Force | Out-Null
                                            Copy-Item -Path $localTempVBS -Destination $remoteTempVBS -Force | Out-Null
                                        } else {
                                            throw "No se puede acceder al recurso compartido administrativo en $remoteTempDir"
                                        }
                                    }
                                    catch {
                                        Write-Host "[-] ERROR: Fallo al copiar los scripts de ejecucion al host remoto: $_" -ForegroundColor Red
                                        Read-Host "Presione ENTER para continuar..."
                                        break
                                    }
                                    
                                    # 3. Ejecutar de forma silenciosa mediante wscript.exe en la sesión interactiva del usuario
                                    Write-Host "[*] Ejecutando captura de pantalla de forma silenciosa..." -ForegroundColor Yellow
                                    $argumentos = "\\$computerTarget -u gmsantacruz\$usu -p $claTexto -s -i $sessionId -accepteula wscript.exe C:\Windows\Temp\run.vbs"
                                    
                                    $proc = Start-Process -FilePath $psexecPath -ArgumentList $argumentos -NoNewWindow -PassThru -Wait
                                    
                                    # 4. Recuperar la imagen, guardarla en C:\spscreen y abrirla
                                    $remoteImage = "\\$computerTarget\c$\Windows\Temp\screen.png"
                                    $localDestFolder = "C:\spscreen"
                                    
                                    if (-not (Test-Path $localDestFolder)) {
                                        New-Item -ItemType Directory -Path $localDestFolder -Force | Out-Null
                                        Write-Host "[*] Creado directorio local $localDestFolder" -ForegroundColor Gray
                                    }
                                    
                                    $localImageName = "Captura_${computerTarget}_$(Get-Date -Format 'yyyyMMdd_HHmmss').png"
                                    $localImageFullPath = Join-Path $localDestFolder $localImageName
                                    
                                    if (Test-Path $remoteImage) {
                                        Move-Item -Path $remoteImage -Destination $localImageFullPath -Force
                                        Write-Host "[+] EXITO: Captura guardada en $localImageFullPath" -ForegroundColor Green
                                        # Abrir la imagen en el visor predeterminado
                                        Start-Process $localImageFullPath
                                    } else {
                                        Write-Host "[-] ERROR: No se genero la captura. Verifique los permisos de administrador en la maquina destino." -ForegroundColor Red
                                    }
                                    
                                    # 5. Limpieza local y remota de rastros
                                    if (Test-Path $remoteTempScript) { Remove-Item -Path $remoteTempScript -Force | Out-Null }
                                    if (Test-Path $remoteTempVBS) { Remove-Item -Path $remoteTempVBS -Force | Out-Null }
                                    if (Test-Path $localTempScript) { Remove-Item -Path $localTempScript -Force | Out-Null }
                                    if (Test-Path $localTempVBS) { Remove-Item -Path $localTempVBS -Force | Out-Null }
                                    
                                    Read-Host "`nPresione ENTER para continuar..."
                                }
                                
                                "2" {
                                    cabecera
                                    menuOpcion "Se encuentra en el SUB_MENU: 100 ;;; Opcion: $op100"
                                    Write-Host "`n--- CAPTURA DE PANTALLA REMOTA CON TAREA PROGRAMADA ---" -ForegroundColor Cyan
                                    Write-Host "[INFO] Esta funcionalidad esta en fase de planificacion y diseño." -ForegroundColor Yellow
                                    Write-Host "En proximas versiones podra ejecutarse sin requerir PsExec." -ForegroundColor Gray
                                    Read-Host "`nPresione ENTER para continuar..."
                                }
                                
                                "0" {
                                    $salirSub100 = $true
                                }
                            }
                        }
                        catch {
                            Write-Host "[-] ERROR: Ocurrio un fallo en el submenu de captura: $_" -ForegroundColor Red
                            Read-Host "Presione ENTER para continuar..."
                        }
                    } while (-not $salirSub100)
                }

                "101" {
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
                                    Write-Host "                         No extrae, descifra ni expone contraseñas, tokens ni cookies." -ForegroundColor Gray

                                    # 1. Control de Acceso: Verificar token de Administrador
                                    $isAdmin = Test-IsProcessAdmin
                                    if (-not $isAdmin) {
                                        Write-Host "`n[ERROR DE SEGURIDAD] Esta funcionalidad requiere una consola con privilegios elevados de Administrador." -ForegroundColor Red
                                        Write-AuditAccess101 -Target "N/A" -Action "Auditoria de Navegadores" -Status "DENEGADO_TOKEN_NO_ELEVADO"
                                        Read-Host "Presione ENTER para continuar..."
                                        break
                                    }

                                    # 2. Solicitar Target aplicando lineamientos de subMenu25
                                    $IPFinal = Get-StandardIPPrompt
                                    if ([string]::IsNullOrWhiteSpace($IPFinal)) {
                                        Write-Host "Operacion cancelada." -ForegroundColor Red
                                        Read-Host "Presione ENTER para continuar..."
                                        break
                                    }

                                    # 3. Resolución de Hostname prioritario para Kerberos y procesos internos
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

                                    # Asentar en registro de auditoría el acceso autorizado
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

                                    # 5. Detección de navegadores instalados en la máquina remota
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

                                    # 6. Escaneo de perfiles de usuario en el equipo remoto
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
                                                                if (-not [string]::IsNullOrWhiteSpace($e.OriginUrl)) {
                                                                    $classif = Get-DomainClassification -UrlOrDomain $e.OriginUrl
                                                                    $loginResults.Add([PSCustomObject]@{
                                                                        UsuarioLocal     = $uName
                                                                        Navegador        = "Google Chrome"
                                                                        Perfil           = $pDir.Name
                                                                        UrlOrigen        = $e.OriginUrl
                                                                        Dominio          = $classif.Domain
                                                                        UsuarioGuardado  = if ([string]::IsNullOrWhiteSpace($e.Username)) { "(Sin usuario / Acceso guardado)" } else { $e.Username }
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

                                            # --- MICROSOFT EDGE ---
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
                                                                if (-not [string]::IsNullOrWhiteSpace($e.OriginUrl)) {
                                                                    $classif = Get-DomainClassification -UrlOrDomain $e.OriginUrl
                                                                    $loginResults.Add([PSCustomObject]@{
                                                                        UsuarioLocal     = $uName
                                                                        Navegador        = "Microsoft Edge"
                                                                        Perfil           = $pDir.Name
                                                                        UrlOrigen        = $e.OriginUrl
                                                                        Dominio          = $classif.Domain
                                                                        UsuarioGuardado  = if ([string]::IsNullOrWhiteSpace($e.Username)) { "(Sin usuario / Acceso guardado)" } else { $e.Username }
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
                                                                if (-not [string]::IsNullOrWhiteSpace($e.OriginUrl)) {
                                                                    $classif = Get-DomainClassification -UrlOrDomain $e.OriginUrl
                                                                    $loginResults.Add([PSCustomObject]@{
                                                                        UsuarioLocal     = $uName
                                                                        Navegador        = "Brave Browser"
                                                                        Perfil           = $pDir.Name
                                                                        UrlOrigen        = $e.OriginUrl
                                                                        Dominio          = $classif.Domain
                                                                        UsuarioGuardado  = if ([string]::IsNullOrWhiteSpace($e.Username)) { "(Sin usuario / Acceso guardado)" } else { $e.Username }
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
                                                            if (-not [string]::IsNullOrWhiteSpace($e.OriginUrl)) {
                                                                $classif = Get-DomainClassification -UrlOrDomain $e.OriginUrl
                                                                $loginResults.Add([PSCustomObject]@{
                                                                    UsuarioLocal     = $uName
                                                                    Navegador        = "Opera"
                                                                    Perfil           = "Default"
                                                                    UrlOrigen        = $e.OriginUrl
                                                                    Dominio          = $classif.Domain
                                                                    UsuarioGuardado  = if ([string]::IsNullOrWhiteSpace($e.Username)) { "(Sin usuario / Acceso guardado)" } else { $e.Username }
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
                                            $firefoxProfiles = Join-Path $uFolder.FullName "AppData\Roaming\Mozilla\Firefox\Profiles"
                                            if (Test-Path $firefoxProfiles) {
                                                $ffDirs = Get-ChildItem -Path $firefoxProfiles -Directory -ErrorAction SilentlyContinue
                                                foreach ($ffDir in $ffDirs) {
                                                    $loginsJson = Join-Path $ffDir.FullName "logins.json"
                                                    if (Test-Path $loginsJson) {
                                                        try {
                                                            $jsonRaw = Get-Content -LiteralPath $loginsJson -Raw -Encoding UTF8 -ErrorAction Stop
                                                            $ffObj = $jsonRaw | ConvertFrom-Json
                                                            if ($ffObj -and $ffObj.logins) {
                                                                foreach ($lg in $ffObj.logins) {
                                                                    $targetUrl = if ($lg.hostname) { $lg.hostname } else { $lg.formSubmitURL }
                                                                    if (-not [string]::IsNullOrWhiteSpace($targetUrl)) {
                                                                        $classif = Get-DomainClassification -UrlOrDomain $targetUrl
                                                                        $userDisplay = if ($lg.encryptedUsername) { "[Protegido por Firefox / NSS]" } else { "(Formulario guardado)" }
                                                                        $loginResults.Add([PSCustomObject]@{
                                                                            UsuarioLocal     = $uName
                                                                            Navegador        = "Mozilla Firefox"
                                                                            Perfil           = $ffDir.Name
                                                                            UrlOrigen        = $targetUrl
                                                                            Dominio          = $classif.Domain
                                                                            UsuarioGuardado  = $userDisplay
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
                                        # Purga absoluta de archivos temporales
                                        if (Test-Path $localAuditTemp) {
                                            Remove-Item -Path $localAuditTemp -Recurse -Force -ErrorAction SilentlyContinue
                                        }
                                    }

                                    # 7. Presentación de Resultados en Consola
                                    Write-Host "`n==========================================================================================================" -ForegroundColor Cyan
                                    Write-Host "                     RESULTADOS DE AUDITORIA DE NAVEGADORES - EQUIPO: $computerTarget" -ForegroundColor Cyan
                                    Write-Host "==========================================================================================================" -ForegroundColor Cyan

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
                                        if ($respExport -match '^[sS]$') {
                                            $repDir = "C:\shellWil\reportes"
                                            if (-not (Test-Path $repDir)) {
                                                New-Item -ItemType Directory -Path $repDir -Force -ErrorAction SilentlyContinue | Out-Null
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
                                    
                                    $logFile = "C:\shellWil\logs\audit_101.log"
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

                "0" { 
                    # $salirSub = $true 
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            } #Cierra switch
            if (-not $salirSub) { Read-Host "SUB_MENU 25: Presione ENTER para continuar..." }
        } # Cierra try

        catch {
            Write-Host "`n[ERROR NO ESPERADO]: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Presione Enter para continuar..."
        }
		
        finally {
            # *************************************************************************************
            # BLOQUE DE LIMPIEZA Y REFRESCO (Se ejecuta después de cada opción)
            # *************************************************************************************
            
            # 1. Liberar memoria de objetos COM/WMI/CIM colgados
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()

            # 2. Eliminar variables temporales de la sesión para evitar errores de "cadena de entrada"
            # Mantenemos variables críticas del script
            Get-Variable | Where-Object { 
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID|RemoteTarget' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. Pequeña pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }

    } while (-not $salirSub)
}

#************************************************* FIN SUB MENU.25*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.26 ******************************************************
#**********************************************************************************************************************************
function psSubMenu26 {
    # DetecciÃ³n y fallback de Active Directory usando ADSI (LDAP nativo sin RSAT)
    if (-not (Get-Command Get-ADUser -ErrorAction SilentlyContinue)) {
        Write-Host "[INFO] Modulo ActiveDirectory (RSAT) no detectado. Cargando emulacion LDAP nativa..." -ForegroundColor Yellow
        Start-Sleep -Milliseconds 500

        # Declarar funciones de compatibilidad
        function Get-ADUser {
            param(
                [Parameter(Position = 0, Mandatory = $true)]
                [string]$Identity,
                [Parameter(Position = 1)]
                [string[]]$Properties
            )
            
            $searcher = [adsisearcher]"(samAccountName=$Identity)"
            $result = $searcher.FindOne()
            if ($result) {
                $entry = $result.GetDirectoryEntry()
                
                # FunciÃ³n para traducir fechas de LargeInteger
                filter Get-ADDate {
                    if ($null -eq $_ -or $_.Value -eq 0 -or $_.Value -eq 9223372036854775807) { return $null }
                    try {
                        if ($_ -is [System.Int64] -or $_ -is [System.Int32]) {
                            return [DateTime]::FromFileTime($_)
                        }
                        # Intento de invocacion de LargeInteger compatible con PowerShell 2.0 (sin -shl)
                        $high = $_.GetType().InvokeMember("HighPart", [System.Reflection.BindingFlags]::GetProperty, $null, $_, $null)
                        $low = $_.GetType().InvokeMember("LowPart", [System.Reflection.BindingFlags]::GetProperty, $null, $_, $null)
                        $intVal = ([int64]$high * 4294967296) + [uint32]$low
                        return [DateTime]::FromFileTime($intVal)
                    }
                    catch {}
                    return $null
                }

                $prop = @{}
                $prop["Name"] = [string]$entry.Properties["name"].Value
                $prop["DisplayName"] = [string]$entry.Properties["displayName"].Value
                $prop["SamAccountName"] = [string]$entry.Properties["samAccountName"].Value
                $prop["Title"] = [string]$entry.Properties["title"].Value
                $prop["Office"] = [string]$entry.Properties["physicalDeliveryOfficeName"].Value
                $prop["Department"] = [string]$entry.Properties["department"].Value
                $prop["Description"] = [string]$entry.Properties["description"].Value
                $prop["OfficePhone"] = [string]$entry.Properties["telephoneNumber"].Value
                $prop["PostalCode"] = [string]$entry.Properties["postalCode"].Value
                $prop["GivenName"] = [string]$entry.Properties["givenName"].Value
                $prop["Surname"] = [string]$entry.Properties["sn"].Value
                $prop["UserPrincipalName"] = [string]$entry.Properties["userPrincipalName"].Value
                $prop["ObjectClass"] = [string]$entry.SchemaClassName
                if ($entry.Guid) {
                    $prop["ObjectGUID"] = [Guid]$entry.Guid
                }
                else {
                    $prop["ObjectGUID"] = $null
                }

                if ($entry.Properties["objectSid"].Value) { 
                    $prop["SID"] = (New-Object System.Security.Principal.SecurityIdentifier($entry.Properties["objectSid"].Value, 0)).Value 
                }
                else {
                    $prop["SID"] = $null
                }

                $uac = $entry.Properties["userAccountControl"].Value
                if ($uac) {
                    $prop["Enabled"] = -not ($uac -band 2)
                    $prop["PasswordExpired"] = [bool]($uac -band 0x800000)
                    $prop["PasswordNeverExpires"] = [bool]($uac -band 0x10000)
                }
                else {
                    $prop["Enabled"] = $true
                    $prop["PasswordExpired"] = $false
                    $prop["PasswordNeverExpires"] = $false
                }

                $prop["PasswordLastSet"] = $entry.Properties["pwdLastSet"].Value | Get-ADDate
                $prop["AccountExpirationDate"] = $entry.Properties["accountExpires"].Value | Get-ADDate
                
                $lastLogonVal = $entry.Properties["lastLogonTimestamp"].Value
                if ($null -eq $lastLogonVal) { $lastLogonVal = $entry.Properties["lastLogon"].Value }
                $prop["LastLogonDate"] = $lastLogonVal | Get-ADDate

                $managerDN = $entry.Properties["manager"].Value
                if ($managerDN) {
                    $prop["Manager"] = ($managerDN -split ',')[0].Replace('CN=', '')
                }
                else {
                    $prop["Manager"] = $null
                }

                $groups = @()
                foreach ($g in $entry.Properties["memberOf"]) {
                    $groups += $g
                }
                $prop["MemberOf"] = $groups

                return New-Object PSObject -Property $prop
            }
            return $null
        }

        function Set-ADAccountPassword {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Identity,
                [Parameter(Mandatory = $true)]
                [System.Security.SecureString]$NewPassword,
                [switch]$Reset
            )
            
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewPassword)
            $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            
            $searcher = [adsisearcher]"(samAccountName=$Identity)"
            $result = $searcher.FindOne()
            if ($result) {
                $entry = $result.GetDirectoryEntry()
                $entry.Invoke("SetPassword", $PlainPassword)
                $entry.CommitChanges()
            }
            else {
                throw "No se pudo encontrar al usuario '$Identity' en el dominio."
            }
        }

        function Set-ADUser {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Identity,
                [bool]$ChangePasswordAtLogon
            )
            
            $searcher = [adsisearcher]"(samAccountName=$Identity)"
            $result = $searcher.FindOne()
            if ($result) {
                $entry = $result.GetDirectoryEntry()
                if ($ChangePasswordAtLogon) {
                    $entry.Properties["pwdLastSet"].Value = 0
                }
                else {
                    $entry.Properties["pwdLastSet"].Value = -1
                }
                $entry.CommitChanges()
            }
            else {
                throw "No se pudo encontrar al usuario '$Identity' en el dominio."
            }
        }
    }

    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header " 26. ===)) AD: COMANDOS AD ====="
            Write-Host "  1. GESTION DE USUARIO DE DOMINIO | ACTIVE DIRECTORY |"
            Write-Host "    1.1 Mostrar Datos de Usuario de Dominio con C.I, Cargo, Lugar."
            Write-Host "    1.2 Mostrar ultima conexion de Usuario"
            Write-Host "    1.3 Mostrar Datos de Usuario de Dominio, fecha cambio clave." -ForegroundColor Green
            Write-Host "    1.4. Cambiar Clave de Usuario de Dominio." -ForegroundColor Red
            Write-Host "    1.5 Reporte detallado de Usuario de Dominio."
            Write-Host "  2. GESTION DE USUARIO REMOTO RECURSOS COMPARTIDOS"
            Write-Host "    2.1 Mostrar usuario PC Remota." -ForegroundColor Cyan
            Write-Host "    2.2 Mostrar usuarios activos y no activos del Dominio - PC Remota." -ForegroundColor Cyan
            Write-Host "    2.5 Mostrar Carpetas Compartidas en PC Remota."
            Write-Host "  3. GESTION DE USUARIO | USUARIO LOCAL |"
            Write-Host "    3.1 Cambiar contrasenia de USUARIO LOCAL en PC REMOTO" -ForegroundColor Cyan            
            Write-Host "  30. REFRESH." -ForegroundColor Red
            Write-Host "  31. REFRESH DESDE GITHUB (ONLINE)." -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Header "==============================="
            
            $op26 = Read-Host "Seleccione la tarea a realizar"

            switch ($op26) {
                "1.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    Write-Host "OfficePhone : Carnet de Identidad de persona" -ForegroundColor Cyan
                    Write-Host ""
                    # 1. Solicitar el nombre de usuario
                    $dato = Read-Host "Introduzca el usuario de dominio"

                    # 2. Definir las propiedades extendidas que queremos extraer
                    $propiedades = @(
                        "Description",    # DescripciÃ³n
                        "Title",          # Cargo / Puesto
                        "Office",         # Oficina (PhysicalDeliveryOfficeName)
                        "Department",     # Ãrea / Departamento
                        "Manager",        # Dependencia (Jefe Directo)
                        "OfficePhone",    # TelÃ©fono
                        "PostalCode",     # CÃ³digo Postal
                        "SID"             # Identificador de Seguridad
                    )

                    try {
                        # Ejecutar la consulta y forzar el formato de lista detallada
                        Get-ADUser -Identity $dato -Properties $propiedades | Format-List `
                            DistinguishedName, 
                        Enabled, 
                        GivenName, 
                        Name, 
                        ObjectClass, 
                        ObjectGUID, 
                        @{Label = "Cargo"; Expression = { $_.Title } },
                        @{Label = "Descripcion"; Expression = { $_.Description } },
                        @{Label = "Oficina"; Expression = { $_.Office } },
                        @{Label = "Area"; Expression = { $_.Department } },
                        @{Label = "Dependencia (Manager)"; Expression = { $_.Manager } },
                        OfficePhone, 
                        PostalCode, 
                        SamAccountName, 
                        SID, 
                        Surname, 
                        UserPrincipalName
                    }
                    catch {
                        Write-Host "Error: No se encontro al usuario '$dato' o no hay conexion con el AD." -ForegroundColor Red
                    }

                }
                "1.2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # 1. Solicitar el nombre de usuario
                    $usuario = Read-Host "Introduzca el usuario de dominio"

                    try {
                        # 2. Obtener datos bÃ¡sicos y Ãºltima conexiÃ³n del AD
                        $adUser = Get-ADUser -Identity $usuario -Properties LastLogonDate, Description, Title

                        if ($adUser) {
                            Write-Host "--- INFORMACION DE CONEXION ---" -ForegroundColor Cyan
                            Write-Host "Usuario:        $($adUser.Name)"
                            Write-Host "Ultimo Logueo:  $($adUser.LastLogonDate)"
                            Write-Host "Estado:         $(if($adUser.Enabled){'Activo'}else{'Deshabilitado'})"
                            
                            # 3. Intentar obtener los equipos desde los Logs de Seguridad (Event ID 4624)
                            # Nota: Esto requiere privilegios de admin y que los logs no se hayan sobrescrito
                            Write-Host "Buscando rastros en logs de seguridad (esto puede tardar)..." -ForegroundColor Yellow
                            
                            $hoy = Get-Date
                            $eventos = Get-WinEvent -FilterHashtable @{
                                LogName   = 'Security'; 
                                ID        = 4624; 
                                StartTime = $hoy.AddDays(-7) # Ãšltimos 7 dÃ­as
                            } -ErrorAction SilentlyContinue | Where-Object {
                                $_.Properties[5].Value -eq $usuario
                            }

                            if ($eventos) {
                                Write-Host "Equipos detectados recientemente:" -ForegroundColor Green
                                $eventos | ForEach-Object {
                                    $computadora = $_.Properties[18].Value
                                    if ($computadora -and $computadora -ne "-") {
                                        $fecha = $_.TimeCreated
                                        Write-Host "- [$fecha] en el equipo: $computadora"
                                    }
                                } | Select-Object -Unique
                            }
                            else {
                                Write-Host "No se encontraron registros recientes en los logs locales de este equipo." -ForegroundColor Gray
                            }
                        }
                    }
                    catch {
                        Write-Host "Error: No se pudo encontrar al usuario o acceder a los logs." -ForegroundColor Red
                    }


                }

                "1.3" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # 1. Solicitar usuario
                    $dato = Read-Host "Introduzca el usuario de dominio"

                    # 2. Definir propiedades a consultar
                    $props = @(
                        "PasswordExpired", "PasswordLastSet", "PasswordNeverExpires", 
                        "AccountExpirationDate", "MemberOf", "Description", 
                        "Office", "OfficePhone", "DisplayName"
                    )

                    try {
                        $user = Get-ADUser -Identity $dato -Properties $props

                        # 3. Determinar lÃ³gica de expiraciÃ³n de cuenta
                        $estadoExp = if ($null -eq $user.AccountExpirationDate) { "Sin fecha de expiracion" } 
                        else { "Expira el: $($user.AccountExpirationDate)" }

                        # 4. Mostrar Resumen Corto pero Completo
                        Write-Host "--- RESUMEN DE USUARIO: $($user.DisplayName) ---" -ForegroundColor Cyan
                        
                        $user | Select-Object `
                        @{Label = "Nombre Completo"; Expression = { $_.DisplayName } },
                        @{Label = "Estado Cuenta"; Expression = { if ($_.Enabled) { "Activo" }else { "Deshabilitado" } } },
                        @{Label = "Oficina"; Expression = { $_.Office } },
                        @{Label = "Descripcion"; Expression = { $_.Description } },
                        @{Label = "Ultimo Cambio Pass"; Expression = { $_.PasswordLastSet } },
                        @{Label = "Pass Expirada"; Expression = { $_.PasswordExpired } },
                        @{Label = "Pass Nunca Expira"; Expression = { $_.PasswordNeverExpires } },
                        @{Label = "Expiracion de Usuario"; Expression = { $estadoExp } } | 
                        Format-List

                        # Apartado de Grupos (Resumen corto)
                        Write-Host "Membresia de Grupos:" -ForegroundColor Yellow
                        $user.MemberOf | ForEach-Object { Write-Host " - $(($_ -split ',')[0].Replace('CN=',''))" }

                    }
                    catch {
                        Write-Host "Error: No se pudo encontrar al usuario '$dato'." -ForegroundColor Red
                    }


                }

                "1.4" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # 1. Solicitar el nombre de usuario (Equivalente a SET /P)
                    $usuarioAD = Read-Host "Introduzca el usuario de dominio"

                    # 2. Solicitar la contraseÃ±a de forma segura (Asteriscos)
                    # Usamos un bloque try/catch para manejar errores de permisos o de usuario no encontrado
                    try {
                        Write-Host "Preparando cambio de contrasenia para: $usuarioAD" -ForegroundColor Cyan
                        
                        # Captura la contraseÃ±a de forma segura (AsSecureString oculta la entrada)
                        $NuevaContrasenia = Read-Host "Introduzca la nueva contrasenia para $usuarioAD" -AsSecureString

                        # 3. Aplicar el cambio (Equivalente a Reset de Administrador)
                        Set-ADAccountPassword -Identity $usuarioAD -NewPassword $NuevaContrasenia -Reset
                        
                        # 4. Forzar que el usuario cambie la contraseÃ±a en el prÃ³ximo inicio de sesiÃ³n (Opcional pero recomendado)
                        Set-ADUser -Identity $usuarioAD -ChangePasswordAtLogon $false

                        Write-Host "EXITO: La contrasenia se ha actualizado correctamente." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "ERROR: No se pudo cambiar la contrasenia." -ForegroundColor Red
                        Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor White
                    }

                    

                }            

                "1.5" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # 1. Entrada de datos
                    $dato = Read-Host "Introduzca el usuario de dominio"

                    try {
                        # 2. ObtenciÃ³n de datos extendidos
                        # Agregamos: Enabled (Estado), Office (Oficina) y Description (DescripciÃ³n)
                        $user = Get-ADUser -Identity $dato -Properties LastLogonDate, MemberOf, AccountExpirationDate, Title, Department, PasswordLastSet, Enabled, Office, Description

                        if ($user) {
                            Write-Host "`n====================================================" -ForegroundColor Cyan
                            Write-Host "   REPORTE DETALLADO DE SEGURIDAD: $($user.Name)"
                            Write-Host "====================================================" -ForegroundColor Cyan

                            # --- NUEVO APARTADO: DATOS DE FILIACIÃ“N ---
                            Write-Host "[*] DATOS GENERALES:" -ForegroundColor Yellow
                            $estado = if ($user.Enabled) { "ACTIVO" } else { "DESHABILITADO" }
                            Write-Host "    Estado Usuario: $estado"
                            Write-Host "    Oficina:        $($user.Office)"
                            Write-Host "    Descripcion:    $($user.Description)"
                            Write-Host "    Cargo:          $($user.Title)"
                            Write-Host "    Area/Depto:     $($user.Department)"

                            # --- APARTADO: ULTIMO CAMBIO DE CONTRASEÃ‘A ---
                            Write-Host "`n[*] FECHA ULTIMO CAMBIO DE CONTRASENIA:" -ForegroundColor Yellow
                            if ($user.PasswordLastSet) { 
                                Write-Host "    $($user.PasswordLastSet)" 
                            }
                            else { 
                                Write-Host "    El usuario nunca ha cambiado su contrasenia." 
                            }
                            
                            # --- APARTADO: CONEXIÃ“N Y ESTADO ---
                            Write-Host "`n[*] ULTIMA CONEXION ESTABLECIDA:" -ForegroundColor Yellow
                            if ($user.LastLogonDate) { 
                                Write-Host "    $($user.LastLogonDate)" 
                            }
                            else { 
                                Write-Host "    Nunca ha iniciado sesiÃ³n o el dato no se ha replicado." 
                            }

                            # --- APARTADO: EXPIRACIÃ“N DE CUENTA ---
                            Write-Host "`n[*] ESTADO DE LA CUENTA Y EXPIRACION:" -ForegroundColor Yellow
                            if ($null -eq $user.AccountExpirationDate) {
                                Write-Host "    La cuenta no tiene fecha de expiracion (Nunca expira)."
                            }
                            else {
                                $fechaExp = $user.AccountExpirationDate
                                Write-Host "    FECHA DE EXPIRACION: $fechaExp"
                                if ($fechaExp -lt (Get-Date)) {
                                    Write-Host "    AVISO: La cuenta ya ha expirado." -ForegroundColor Red
                                }
                            }

                            # --- APARTADO: MEMBRESÃA DE GRUPOS ---
                            Write-Host "`n[*] GRUPOS A LOS QUE PERTENECE:" -ForegroundColor Yellow
                            if ($user.MemberOf) {
                                foreach ($grupoDN in $user.MemberOf) {
                                    $nombreGrupo = ($grupoDN -split ",")[0].Replace("CN=", "")
                                    Write-Host "    - $nombreGrupo"
                                }
                            }
                            else {
                                Write-Host "    El usuario no pertenece a grupos adicionales."
                            }

                            # --- APARTADO: RASTREO DE EQUIPOS ---
                            Write-Host "`n[*] RASTREO DE EQUIPOS RECIENTES (LOGS LOCALES):" -ForegroundColor Yellow
                            $eventos = Get-WinEvent -FilterHashtable @{LogName = 'Security'; ID = 4624 } -MaxEvents 100 -ErrorAction SilentlyContinue | 
                            Where-Object { $_.Properties[5].Value -eq $dato }
                            
                            if ($eventos) {
                                $eventos | ForEach-Object {
                                    $pc = $_.Properties[18].Value
                                    if ($pc -and $pc -ne "-") { 
                                        Write-Host "    - Detectado en: $pc ($($_.TimeCreated))" 
                                    }
                                } | Select-Object -Unique
                            }
                            else {
                                Write-Host "    No se hallaron registros en este equipo."
                            }
                            Write-Host "====================================================" -ForegroundColor Cyan
                        }
                    }
                    catch {
                        Write-Host "`nError: No se pudo obtener informacion del usuario '$dato'." -ForegroundColor Red
                        Write-Host "Detalle: $($_.Exception.Message)"
                    }

                    Write-Host "`n====================================================" -ForegroundColor Cyan

                }

                "2.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # 1. DefiniciÃ³n del segmento de red base
                    $baseIP = "192.168.176."

                    # 2. Captura del Ãºltimo OCTETO con validaciÃ³n simple
                    $hostID = Read-Host "Ingrese el ultimo OCTETO del segmento 192.168.176.XXX"

                    if ($hostID -match '^\d{1,3}$') {
                        $fullIP = $baseIP + $hostID
                        Write-Host "`n--- Consultando Host: $fullIP ---" -ForegroundColor Cyan
                        
                        try {
                            # 3. EjecuciÃ³n optimizada de quser (query user)
                            # Redirigimos el error 2 al flujo de Ã©xito para procesar el texto de "No hay usuarios"
                            $resultado = quser /server:$fullIP 2>&1

                            # 4. Procesamiento de la respuesta
                            if ($resultado -like "*No hay ningÃºn usuario*" -or $resultado -like "*No user exists*") {
                                Write-Host "Estado: Equipo encendido, pero sin sesiones activas." -ForegroundColor Cyan
                            }
                            elseif ($resultado -like "*Error*") {
                                Write-Host "Error: No se pudo establecer conexion RPC con $fullIP." -ForegroundColor Red
                                Write-Host "Verifique que el equipo estÃ© en lÃ­nea y el Firewall permita RPC." -ForegroundColor Gray
                            }
                            else {
                                # Limpiamos lÃ­neas vacÃ­as y mostramos la tabla de quser
                                $resultado | Where-Object { $_.Trim() -ne "" }
                            }
                        }
                        catch {
                            Write-Host "Error inesperado al ejecutar el comando." -ForegroundColor Red
                        }
                    }
                    else {
                        Write-Host "Entrada invalida. Debe ingresar solo numeros (0-255)." -ForegroundColor Red
                    }

                    # Pausa para ver los resultados antes de cerrar la consola
                    # Write-Host "`nPresione cualquier tecla para finalizar esta consulta..."
                    # $null = [Console]::ReadKey()
                    
                }

                "2.2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    Write-Host "--- Auditoria de Usuarios: Equipo Remoto ---" -ForegroundColor Cyan

                    # 1. Solicitud de entrada con validacion basica
                    $octeto = Read-Host "Ingrese el ultimo octeto de la IP (192.168.176.XXX)"

                    if ($octeto -notmatch '^\d{1,3}$') {
                        Write-Host "[ERROR] El octeto ingresado no es valido." -ForegroundColor Red
                        break
                    }

                    $ip = "192.168.176.$octeto"
                    Write-Host "Conectando a $ip..." -ForegroundColor Yellow

                    # 2. Bloque de ejecucion con manejo de errores
                    try {
                        # Consultar usuario actual
                        $pc = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ip -ErrorAction Stop
                        $usuarioActual = $pc.UserName

                        # Consultar perfiles historicos (Excluye cuentas especiales del sistema)
                        $perfiles = Get-WmiObject -Class Win32_UserProfile -ComputerName $ip -Filter "Special=False" -ErrorAction Stop

                        # 3. Presentacion de resultados
                        Write-Host "`n--- Resultado de la Auditoria ---" -ForegroundColor Green
                        
                        # Mostrar usuario activo
                        Write-Host "Usuario Activo Actualmente:" -ForegroundColor White
                        if ($null -eq $usuarioActual) {
                            Write-Host "  No hay ningun usuario con sesion iniciada." -ForegroundColor Gray
                        }
                        else {
                            Write-Host "  $usuarioActual" -ForegroundColor Cyan
                        }

                        # Mostrar historial de perfiles (Solo nombres)
                        Write-Host "`nUsuarios que han iniciado sesion anteriormente:" -ForegroundColor White
                        $listaUsuarios = foreach ($perfil in $perfiles) {
                            $nombreUsuario = $perfil.LocalPath.Split('\')[-1]
                            
                            New-Object PSObject -Property @{
                                Usuario = $nombreUsuario
                            } | Select-Object Usuario
                        }

                        if ($null -eq $listaUsuarios) {
                            Write-Host "  No se encontraron perfiles de usuario adicionales." -ForegroundColor Gray
                        }
                        else {
                            $listaUsuarios | Sort-Object Usuario | Format-Table -AutoSize
                        }

                    }
                    catch {
                        Write-Host "`n[ERROR] No se pudo conectar al equipo $ip." -ForegroundColor Red
                        Write-Host "Razon: $_" -ForegroundColor Red
                        Write-Host "Asegurese de tener permisos de administrador en la maquina remota." -ForegroundColor Yellow
                    }
                    Write-Host "`Consulta finalizado..." -ForegroundColor Cyan

                }


                "2.5" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # 1. ConfiguraciÃ³n del segmento
                    $segmento = "192.168.176."
                    $hostID = Read-Host "Ingrese el ultimo OCTETO del segmento 192.168.176.XXX"

                    # Validar que la entrada sea numÃ©rica
                    if ($hostID -match '^\d{1,3}$') {
                        $targetIP = $segmento + $hostID
                        Write-Host "`n--- Buscando recursos compartidos en: $targetIP ---" -ForegroundColor Yellow

                        try {
                            # 2. Uso de Get-WmiObject para mÃ¡xima compatibilidad (Win7 en adelante)
                            # Filtramos Type=0 para mostrar solo carpetas compartidas por el usuario
                            # (Type 2147483648 son recursos administrativos ocultos)
                            $shares = Get-WmiObject -Class Win32_Share -ComputerName $targetIP -ErrorAction Stop | 
                            Where-Object { $_.Type -eq 0 }

                            if ($shares) {
                                Write-Host "Recursos encontrados:" -ForegroundColor Green
                                $shares | Select-Object @{Name = "Carpeta"; Expression = { $_.Name } }, 
                                @{Name = "Ruta Local"; Expression = { $_.Path } }, 
                                @{Name = "Descripcion"; Expression = { $_.Description } } | 
                                Format-Table -AutoSize
                            }
                            else {
                                Write-Host "No se encontraron carpetas compartidas (pÃºblicas) en este equipo." -ForegroundColor Cyan
                            }
                        }
                        catch {
                            Write-Host "ERROR: No se pudo conectar a $targetIP." -ForegroundColor Red
                            Write-Host "Causas posibles: Equipo apagado, IP incorrecta o Firewall bloqueando WMI/RPC." -ForegroundColor Gray
                        }
                    }
                    else {
                        Write-Host "Entrada invalida. Ingrese solo nÃºmeros." -ForegroundColor Red
                    }

                    Write-Host "`Consulta finalizado..." -ForegroundColor Cyan

                }

                "3.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # ==============================================================================
                    #   HERRAMIENTA REMOTA DE GESTIÃ“N DE USUARIOS LOCALES (GMSANTACRUZ)
                    #   Compatibilidad: Windows 7 hasta Windows 11
                    # ==============================================================================

                    Clear-Host
                    Write-Host "==================================================" -ForegroundColor Cyan
                    Write-Host "     GESTOR DE USUARIOS LOCALES REMOTOS           " -ForegroundColor Cyan
                    Write-Host "==================================================" -ForegroundColor Cyan

                    do {
                        # 1. ConstrucciÃ³n de la DirecciÃ³n IP
                        Write-Host "--- Estructura de Red ---\n" -ForegroundColor White
                        $ultimoOcteto = Read-Host "Ingrese el ULTIMO octeto para el segmento 192.168.176.xxx"
                        
                        # ValidaciÃ³n bÃ¡sica de entrada numÃ©rica
                        if ($ultimoOcteto -notmatch '^\d+$' -or [int]$ultimoOcteto -lt 1 -or [int]$ultimoOcteto -gt 254) {
                            Write-Host "[ERROR] El octeto ingresado no es valido." -ForegroundColor Red
                            break
                        }
                        
                        $ipRemota = "192.168.176.$ultimoOcteto"
                        Write-Host "Conectando a: $ipRemota..." -ForegroundColor Yellow

                        # 2. Manejo opcional de credenciales de Dominio
                        $opcionCred = Read-Host "Â¿Desea usar credenciales de un usuario de Dominio? (SI/NO)"
                        $usarCredenciales = $false
                        $credenciales = $null

                        if ($opcionCred.ToUpper() -eq "SI") {
                            Write-Host "Solicitando credenciales de Administrador de Dominio..." -ForegroundColor Yellow
                            $credenciales = Get-Credential
                            $usarCredenciales = $true
                        }

                        # 3. Listar cuentas locales mediante ADSI (WinNT)
                        Write-Host "`nObteniendo listado de cuentas locales de la PC remota..." -ForegroundColor Yellow
                        
                        try {
                            # ConexiÃ³n al contenedor de la mÃ¡quina remota
                            if ($usarCredenciales) {
                                # Se utiliza el ensamblador nativo de .NET para pasar las credenciales de forma segura
                                $username = $credenciales.UserName
                                $password = $credenciales.GetNetworkCredential().Password
                                $pcRemotaObj = New-Object System.DirectoryServices.DirectoryEntry("WinNT://$ipRemota,computer", $username, $password)
                            }
                            else {
                                $pcRemotaObj = [ADSI]"WinNT://$ipRemota,computer"
                            }

                            # Filtrar solo objetos de tipo "User" (Cuentas de usuario)
                            $usuariosLocales = $pcRemotaObj.Children | Where-Object { $_.SchemaClassName -eq "user" }

                            if ($null -eq $usuariosLocales) {
                                Write-Host "[ERROR] No se pudieron recuperar los usuarios o la lista esta vacia." -ForegroundColor Red
                                break
                            }

                            # Mostrar los usuarios en una tabla limpia
                            Write-Host "`n--- Cuentas Locales Detectadas ---" -ForegroundColor White
                            $listaVisual = @()
                            foreach ($u in $usuariosLocales) {
                                # Propiedades extendidas nativas de la cuenta
                                $disabled = $u.Properties.UserFlags.Value -band 2 # 2 = ADS_UF_ACCOUNTDISABLE
                                $estado = if ($disabled) { "Deshabilitado" } else { "Activo" }
                                
                                $obj = New-Object PSObject -Property @{
                                    "Nombre de Usuario" = $u.Name
                                    "Estado"            = $estado
                                    "Descripcion"       = $u.Description
                                }
                                $listaVisual += $obj | Select-Object "Nombre de Usuario", Estado, Descripcion
                            }
                            
                            $listaVisual | Format-Table -AutoSize
                            
                        }
                        catch {
                            Write-Host "[ERROR CRITICO] No se pudo establecer la conexion remota via RPC/ADSI: $_" -ForegroundColor Red
                            break
                        }

                        # 4. SelecciÃ³n del usuario al que se le cambiarÃ¡ la contraseÃ±a
                        Write-Host "--------------------------------------------------" -ForegroundColor Cyan
                        $usuarioSeleccionado = Read-Host "Ingrese el NOMBRE del usuario local a modificar"
                        
                        # Validar que el usuario ingresado exista en el listado previo
                        $existeUsuario = $listaVisual | Where-Object { $_."Nombre de Usuario".ToUpper() -eq $usuarioSeleccionado.ToUpper() }

                        if (-not $existeUsuario) {
                            Write-Host "[ERROR] El usuario '$usuarioSeleccionado' no pertenece a las cuentas locales de la PC remota." -ForegroundColor Red
                            break
                        }

                        # 5. Ingreso y cambio de la nueva contraseÃ±a
                        $nuevaPassword = Read-Host "Ingrese la NUEVA CONTRASENIA para el usuario ($usuarioSeleccionado)"
                        $confirmarPassword = Read-Host "Confirme la NUEVA CONTRASENIA"

                        if ($nuevaPassword -ne $confirmarPassword) {
                            Write-Host "[ERROR] Las contrasenias no coinciden. Operacion cancelada." -ForegroundColor Red
                            break
                        }

                        # 6. Aplicar el cambio de contraseÃ±a de forma remota
                        try {
                            Write-Host "`nAplicando cambios en el sistema remoto..." -ForegroundColor Yellow
                            
                            # Obtener el objeto ADSI especÃ­fico del usuario seleccionado
                            if ($usarCredenciales) {
                                $username = $credenciales.UserName
                                $password = $credenciales.GetNetworkCredential().Password
                                $usuarioObj = New-Object System.DirectoryServices.DirectoryEntry("WinNT://$ipRemota/$usuarioSeleccionado,user", $username, $password)
                            }
                            else {
                                $usuarioObj = [ADSI]"WinNT://$ipRemota/$usuarioSeleccionado,user"
                            }

                            # Invocar el mÃ©todo nativo .SetPassword() de la API de Windows
                            $usuarioObj.SetPassword($nuevaPassword)
                            $usuarioObj.CommitChanges()

                            Write-Host "[EXITO] La contrasenia del usuario local '$usuarioSeleccionado' ha sido cambiada correctamente en $ipRemota." -ForegroundColor Green

                        }
                        catch {
                            Write-Host "[ERROR] Fallo al cambiar la contrasenia: $_" -ForegroundColor Red
                        }

                    } while ($false)

                    Write-Host "`n==================================================" -ForegroundColor Cyan
                    Write-Host "`Proceso finalizado..." -ForegroundColor Cyan
                    
                }

                "3.2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    
                }

                "3.3" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"
   
                }

                "30" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    Write-Host "`n[!] Reiniciando herramienta..." -ForegroundColor Cyan

                    # Si estamos en entorno de desarrollo, reconstruir primero
                    psReconstruirSiDesarrollo

                    # Start-Sleep -Milliseconds 500
                    Start-Sleep -Seconds 2
                    
                    # Recuperamos la ruta que guardamos en la cabecera .bat
                    $ruta = $env:SCRIPT_PATH
                    Write-Host "Ruta del Software:....... $ruta" -ForegroundColor Green
                    Start-Sleep -Seconds 3
                    
                    if ($ruta -and (Test-Path $ruta)) {
                        # Lanzamos el proceso usando CMD para que interprete el .bat correctamente
                        Start-Process cmd.exe -ArgumentList "/c `"$ruta`""
                        exit
                    }
                    else {
                        Write-Error "Error: No se pudo localizar la variable SCRIPT_PATH."
                        Pause
                    }
                }

                "31" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"
                    Write-Host "`n[!] Descargando y reiniciando desde repositorio remoto..." -ForegroundColor Cyan
                    Start-Sleep -Seconds 2
                    Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "irm https://raw.githubusercontent.com/spwil/shellWil/main/ShellSW.bat | iex"
                    exit
                }
                
                "0" { 
                    # $salirSub = $true 
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            } # Cierra switch
            if (-not $salirSub) { Read-Host "SUB_MENU 26: Presione ENTER para continuar..." }
        } # Cierra try
        catch {
            Write-Host "`n[ERROR NO ESPERADO]: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Presione Enter para continuar..."
        }
        
        finally {
            # *************************************************************************************
            # BLOQUE DE LIMPIEZA Y REFRESCO (Se ejecuta despuÃ©s de cada opciÃ³n)
            # *************************************************************************************
            
            # 1. Liberar memoria de objetos COM/WMI/CIM colgados
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()

            # 2. Eliminar variables temporales de la sesiÃ³n para evitar errores de "cadena de entrada"
            # Mantenemos variables crÃ­ticas del script
            Get-Variable | Where-Object { 
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. PequeÃ±a pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }
    } while (-not $salirSub)
}

#************************************************* FIN SUB MENU.26*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.27 ******************************************************
#**********************************************************************************************************************************
function psSubMenu27 {
    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header " 27. ###)) ONLINE: Herramientas en INTERNET #####"
            Write-Host "  1. Revision TECLADO PC online - wikiversus.com"
            Write-Host "  2. Revision Teclado PC online - https://en.key-test.ru"
            Write-Host "  3. Revision Teclado PC online - https://www.onlinemictest.com/es/prueba-de-teclado"
            Write-Host "  4. Revisar MOUSE PC online - https://keyboardtester.co/mouse-click-tester"
            Write-Host "  5. Web Recortar Videos - https://online-video-cutter.com/es."
            Write-Host "  ------------------------------------------------------"
            Write-Host "  10. Testear Monitor PC - https://www.eizo.be/monitor-test."
            Write-Host "  ------------------------------------------------------"
            Write-Host "  20. Buscador de Seriales 1 - https://smartserials.com."
            Write-Host "  21. Buscador de Seriales 2 - https://keygenninja.com."
            Write-Host "  0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Host ""
            Write-Header "==============================="
            
            $op27 = Read-Host "Seleccione la tarea a realizar"

            switch ($op27) {
                "1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op27"

                    # Abrir en Chrome (Modo Incógnito)
                    Start-Process "chrome.exe" -ArgumentList "--incognito", "https://www.wikiversus.com/gaming/teclados/test-key-rollover-y-anti-ghosting/"

                    # Abrir en Brave (Modo Incógnito)
                    Start-Process "msedge.exe" -ArgumentList "-inprivate", "https://www.wikiversus.com/gaming/teclados/test-key-rollover-y-anti-ghosting/"
                }
                "2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op27"

                    Start-Process "chrome.exe" -ArgumentList "--incognito", "https://en.key-test.ru/"

                }

                "3" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op27"

                    Start-Process "chrome.exe" -ArgumentList "--incognito", "https://www.onlinemictest.com/es/prueba-de-teclado/"

                }

                "4" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op27"

                    Start-Process "chrome.exe" -ArgumentList "https://keyboardtester.co/mouse-click-tester"

                }            

                "5" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op27"

                    Start-Process "chrome.exe" -ArgumentList "https://online-video-cutter.com/es/"
                }

                "10" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op27"

                    Start-Process "chrome.exe" -ArgumentList "https://www.eizo.be/monitor-test/"

                }

                "20" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op27"

                    Start-Process "chrome.exe" -ArgumentList "https://smartserials.com"

                }

                "21" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op27"

                    Start-Process "chrome.exe" -ArgumentList "https://keygenninja.com/"

                }

                "0" { 
                    #$salirSub = $true # Antigua sentencia para volver al MENU DE INICIO
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            } # Cierra switch
            if (-not $salirSub) { Read-Host "SUB_MENU 27: Presione ENTER para continuar..." }  # VERIFICAR SI CORRESPONDE AQUI

        } # Cierra try

        catch {
            Write-Host "`n[ERROR NO ESPERADO]: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Presione Enter para continuar..."
        }
    
        finally {
            # *************************************************************************************
            # BLOQUE DE LIMPIEZA Y REFRESCO (Se ejecuta después de cada opción)
            # *************************************************************************************
                
            # 1. Liberar memoria de objetos COM/WMI/CIM colgados
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()

            # 2. Eliminar variables temporales de la sesión para evitar errores de "cadena de entrada"
            # Mantenemos variables críticas del script
            Get-Variable | Where-Object { 
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. Pequeña pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }
    } while (-not $salirSub)
}

#************************************************* FIN SUB MENU.27*****************************************************************
#**********************************************************************************************************************************

#************************************************ MENU PRINCIPAL ******************************************************************
#**********************************************************************************************************************************
function psSubMenu28 {
    $salirSub = $false
    do {
        try {
            cabecera
            Write-Header " 28. ---)) AD: GESTION HELPDESK -----"
            Write-Host "  1. Habilitar ejecucion remota de scripts (en PC REMOTA)" -ForegroundColor Cyan
            Write-Host "  2. Ejecutar GPUPDATE /FORCE en PC REMOTA" -ForegroundColor Yellow
            Write-Host "  3. Mostrar Caracteristicas de PC Remoto (Info Hardware/OS/Red)" -ForegroundColor Green
            Write-Host "  ------------------------------------------------------"
            Write-Host "  4. Habilitacion de Administracion Remota"
            Write-Host "    4.1 || HABILITAR || WMI, RPC y PSRemoting - en PC REMOTO." -ForegroundColor Green
            Write-Host "  ------------------------------------------------------"
            Write-Host "  5. Servicios Windows Update"
            Write-Host "    5.1 || HABILITAR || Servicios de Actualizacion (Remoto)" -ForegroundColor Green
            Write-Host "    5.2 || DESHABILITAR || Servicios de Actualizacion (Remoto)" -ForegroundColor Red
            Write-Host "    5.3 || ESTADO || de Servicios Windows Update (Remoto)" -ForegroundColor Cyan
            Write-Host "  ------------------------------------------------------"
            Write-Host "  0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Host ""
            Write-Header "==============================="
            
            $op28 = Read-Host "Seleccione la tarea a realizar"

            # Helper para pedir IP / Hostname y resolverlo
            $obtenerDestino = {
                $baseIP = "192.168.176."
                $ultimoOcteto = Read-Host "Ingrese el ultimo octeto de la IP (192.168.176.XXX), IP completa o Nombre de Equipo"
                if ($ultimoOcteto -eq "") { return $null }
                
                $ipRemota = ""
                $targetMachine = ""
                
                if ($ultimoOcteto -match "^[a-zA-Z]") {
                    # Es un hostname directo
                    $targetMachine = $ultimoOcteto
                }
                else {
                    # Es un octeto o IP
                    $ipRemota = if ($ultimoOcteto -match "\.") { $ultimoOcteto } else { $baseIP + $ultimoOcteto }
                    Write-Host "Resolviendo nombre de equipo (Hostname) necesario para WinRM..." -ForegroundColor Cyan
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
                            Write-Host "ADVERTENCIA: No se pudo resolver la IP automaticamente." -ForegroundColor Yellow
                            $manualHost = Read-Host "Ingrese el NOMBRE DE EQUIPO (Hostname) del equipo remoto manualmente"
                            if ($manualHost -ne "") {
                                $targetMachine = $manualHost
                            }
                            else {
                                $targetMachine = $ipRemota # fallback a la IP
                            }
                        }
                    }
                }
                return @{ IP = $ipRemota; Hostname = $targetMachine }
            }

            switch ($op28) {
                "1" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op28"
                    $destino = & $obtenerDestino
                    if ($destino) {
                        $target = $destino.Hostname
                        $ip = if ($destino.IP) { $destino.IP } else { $target }
                        
                        Write-Host "Habilitando ejecucion remota de scripts en $target ($ip)..." -ForegroundColor Cyan
                        
                        # Usamos WMI primero (RPC/DCOM) por máxima compatibilidad en habilitación inicial
                        $process = Get-WmiObject -List -ComputerName $ip -Class Win32_Process -ErrorAction SilentlyContinue
                        if ($process) {
                            $cmd = "powershell.exe -NoProfile -Command `"try { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force } catch {}; try { Enable-PSRemoting -SkipNetworkProfileCheck -Force } catch {}`""
                            $result = $process.Create($cmd)
                            if ($result.ReturnValue -eq 0) {
                                Write-Host "[OK] Comando de habilitacion enviado correctamente via WMI." -ForegroundColor Green
                            }
                            else {
                                Write-Host "Error al enviar comando via WMI (Codigo: $($result.ReturnValue))." -ForegroundColor Red
                            }
                        }
                        else {
                            $psexecPath = "C:\PSTools\PsExec.exe"
                            if (Test-Path $psexecPath) {
                                $arg = "\\$ip -accepteula -s powershell.exe -NoProfile -Command `"try { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force } catch {}; try { Enable-PSRemoting -SkipNetworkProfileCheck -Force } catch {}`""
                                Start-Process -FilePath $psexecPath -ArgumentList $arg -Wait -NoNewWindow
                                Write-Host "[OK] Comando enviado via PsExec." -ForegroundColor Green
                            }
                            else {
                                Write-Host "ERROR: No se pudo conectar via WMI ni se encontro PsExec en C:\PSTools\PsExec.exe" -ForegroundColor Red
                            }
                        }
                    }
                }
                "2" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op28"
                    $destino = & $obtenerDestino
                    if ($destino) {
                        $target = $destino.Hostname
                        $ip = if ($destino.IP) { $destino.IP } else { $target }
                        
                        Write-Host "Ejecutando GPUPDATE /FORCE en $target..." -ForegroundColor Cyan
                        
                        try {
                            # Intentamos usar WinRM interactivo para ver los resultados en tiempo real
                            Invoke-Command -ComputerName $target -ScriptBlock {
                                gpupdate /force
                            } -ErrorAction Stop
                        }
                        catch {
                            Write-Host "WinRM no disponible. Intentando ejecucion en segundo plano via WMI..." -ForegroundColor Yellow
                            $process = Get-WmiObject -List -ComputerName $ip -Class Win32_Process -ErrorAction SilentlyContinue
                            if ($process) {
                                $result = $process.Create("cmd.exe /c gpupdate /force")
                                if ($result.ReturnValue -eq 0) {
                                    Write-Host "[OK] Proceso gpupdate lanzado en segundo plano via WMI." -ForegroundColor Green
                                }
                                else {
                                    Write-Host "Error al ejecutar gpupdate via WMI (Codigo: $($result.ReturnValue))." -ForegroundColor Red
                                }
                            }
                            else {
                                $psexecPath = "C:\PSTools\PsExec.exe"
                                if (Test-Path $psexecPath) {
                                    & $psexecPath \\$ip -accepteula -s cmd.exe /c "gpupdate /force"
                                    Write-Host "[OK] GPUPDATE ejecutado via PsExec." -ForegroundColor Green
                                }
                                else {
                                    Write-Host "ERROR: No se pudo realizar la conexion." -ForegroundColor Red
                                }
                            }
                        }
                    }
                }
                "3" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op28"
                    
                    # Para WMI, preferimos usar la IP si está disponible, o el Hostname
                    $baseIP = "192.168.176."
                    $ultimoOcteto = Read-Host "Ingrese el ultimo octeto de la IP (192.168.176.XXX), IP completa o Nombre de Equipo"
                    if ($ultimoOcteto -ne "") {
                        $ip = if ($ultimoOcteto -match "^[a-zA-Z]") { $ultimoOcteto } elseif ($ultimoOcteto -match "\.") { $ultimoOcteto } else { $baseIP + $ultimoOcteto }
                        
                        Write-Host "`nConsultando caracteristicas extendidas en: $ip..." -ForegroundColor Cyan
                        try {
                            # 1. Sistema Operativo y Hostname
                            $os = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ip -ErrorAction Stop
                            $cs = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ip -ErrorAction Stop
                            $cpu = Get-WmiObject -Class Win32_Processor -ComputerName $ip -ErrorAction Stop | Select-Object -First 1
                            $bios = Get-WmiObject -Class Win32_BIOS -ComputerName $ip -ErrorAction Stop
                            
                            # Obtener Monitor Instalado
                            $monitors = Get-WmiObject -Class Win32_PnPEntity -ComputerName $ip -Filter "Service='monitor'" -ErrorAction SilentlyContinue
                            if ($monitors) {
                                $monitorModels = ($monitors | Select-Object -ExpandProperty Name) -join ", "
                            } else {
                                $desktopMonitors = Get-WmiObject -Class Win32_DesktopMonitor -ComputerName $ip -ErrorAction SilentlyContinue
                                if ($desktopMonitors) {
                                    $monitorModels = ($desktopMonitors | Select-Object -ExpandProperty Name) -join ", "
                                } else {
                                    $monitorModels = "No detectado"
                                }
                            }
                            
                            # 2. Determinar Tipo de Arranque (UEFI vs Legacy) y Tabla (GPT vs MBR)
                            $bootStyle = "LEGACY (BIOS)"
                            $partitionStyle = "MBR"
                            
                            $partitions = Get-WmiObject -Class Win32_DiskPartition -ComputerName $ip -ErrorAction SilentlyContinue
                            if ($partitions) {
                                if ($partitions | Where-Object { $_.Type -like "*GPT*" -or $_.Type -like "*EFI*" -or $_.Name -like "*EFI*" }) {
                                    $bootStyle = "UEFI"
                                }
                                else {
                                    if (Test-Path "\\$ip\c$\Windows\Boot\EFI" -ErrorAction SilentlyContinue) {
                                        $bootStyle = "UEFI"
                                    }
                                }
                                if ($partitions | Where-Object { $_.Type -like "*GPT*" }) {
                                    $partitionStyle = "GPT"
                                }
                            }
                            else {
                                if (Test-Path "\\$ip\c$\Windows\Boot\EFI" -ErrorAction SilentlyContinue) {
                                    $bootStyle = "UEFI"
                                    $partitionStyle = "GPT"
                                }
                            }
                            
                            # Intentar afinar partición de disco de sistema 0
                            try {
                                $bootDisk = Get-WmiObject -Class Win32_DiskDrive -ComputerName $ip | Where-Object { $_.Index -eq 0 } -ErrorAction SilentlyContinue
                                if ($bootDisk -and $bootDisk.GPTSignature -ne $null) {
                                    $partitionStyle = "GPT"
                                }
                            }
                            catch {}

                            # 3. Detectar Usuario Activo (Local o Dominio)
                            $activeUser = "Ninguno (Sin sesion activa)"
                            try {
                                $explorers = Get-WmiObject -Class Win32_Process -ComputerName $ip -Filter "Name='explorer.exe'" -ErrorAction Stop
                                if ($explorers) {
                                    $users = @()
                                    foreach ($exp in $explorers) {
                                        $owner = $exp.GetOwner()
                                        if ($owner.ReturnValue -eq 0) {
                                            $users += "$($owner.Domain)\$($owner.User)"
                                        }
                                    }
                                    if ($users.Count -gt 0) {
                                        $activeUser = ($users | Select-Object -Unique) -join ", "
                                    }
                                }
                                else {
                                    if ($cs.UserName) { $activeUser = $cs.UserName }
                                }
                            }
                            catch {
                                if ($cs.UserName) { $activeUser = $cs.UserName }
                            }
                            
                            # 4. Discos Físicos (HDD vs SSD)
                            $disksInfo = try {
                                Get-WmiObject -Namespace root\Microsoft\Windows\Storage -Class MSFT_PhysicalDisk -ComputerName $ip -ErrorAction Stop | ForEach-Object {
                                    $type = if ($_.MediaType -eq 3) { "HDD" } elseif ($_.MediaType -eq 4) { "SSD" } else { "Desconocido" }
                                    "   - Disco $($_.DeviceId): $($_.Model.Trim()) ($type)"
                                }
                            }
                            catch {
                                Get-WmiObject -Class Win32_DiskDrive -ComputerName $ip | ForEach-Object {
                                    "   - Disco $($_.Index): $($_.Model.Trim()) (Interfaz: $($_.InterfaceType))"
                                }
                            }

                            # 5. Unidades Lógicas disponibles
                            $logicalDrivesInfo = try {
                                Get-WmiObject -Class Win32_LogicalDisk -ComputerName $ip -Filter "DriveType=3" -ErrorAction Stop | ForEach-Object {
                                    $totalGB = [Math]::Round($_.Size / 1GB, 2)
                                    $freeGB = [Math]::Round($_.FreeSpace / 1GB, 2)
                                    $pctFree = if ($_.Size -gt 0) { [Math]::Round(($_.FreeSpace / $_.Size) * 100, 1) } else { 0 }
                                    "   - Unidad $($_.DeviceID) ($($_.VolumeName)) [$($_.FileSystem)] -> Total: $totalGB GB | Libre: $freeGB GB ($pctFree% libre)"
                                }
                            }
                            catch {
                                @("   - No se pudieron consultar las unidades logicas.")
                            }
                            
                            # 6. Adaptadores de Red activos (Detalle completo)
                            $adaptersInfo = Get-WmiObject -Class Win32_NetworkAdapter -ComputerName $ip | 
                            Where-Object { $_.PhysicalAdapter -and $_.NetConnectionStatus -eq 2 } | 
                            ForEach-Object {
                                $config = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $ip -Filter "Index=$($_.Index)" -ErrorAction SilentlyContinue
                                $ips = "N/A"
                                $masks = "N/A"
                                $gateways = "N/A"
                                $dns = "N/A"
                                if ($config) {
                                    if ($config.IPAddress) { $ips = $config.IPAddress[0] }
                                    if ($config.IPSubnet) { $masks = $config.IPSubnet[0] }
                                    if ($config.DefaultIPGateway) { $gateways = $config.DefaultIPGateway -join ", " }
                                    if ($config.DNSServerSearchOrder) { $dns = $config.DNSServerSearchOrder -join ", " }
                                }
                                $netType = if ($_.Name -match "Wireless|Wi-Fi|WiFi|802\.11") { "Wi-Fi" } else { "Ethernet" }
                                "   - $($_.Name) ($netType)`n     IP: $ips | Mascara: $masks`n     Gateway: $gateways`n     DNS: $dns`n     MAC: $($_.MACAddress)"
                            }

                            # 7. Gestión de Impresoras (Predeterminada vs Disponibles con Estado)
                            $defaultPrinterInfo = "Ninguna o sin informacion."
                            $availablePrinters = @()
                            try {
                                $printers = Get-WmiObject -Class Win32_Printer -ComputerName $ip -ErrorAction Stop
                                if ($printers) {
                                    foreach ($p in $printers) {
                                        $estado = if ($p.WorkOffline -or $p.PrinterStatus -eq 7) { "No Activo" } else { "Activo" }
                                        $desc = "$($p.Name) [Puerto: $($p.PortName)] (Estado: $estado)"
                                        if ($p.Default) {
                                            $defaultPrinterInfo = $desc
                                        }
                                        else {
                                            $availablePrinters += "   - $desc"
                                        }
                                    }
                                }
                            }
                            catch {
                                $defaultPrinterInfo = "Error al consultar impresoras."
                            }

                            # Imprimir Reporte Formateado Completo
                            Write-Host "`n======================================================================" -ForegroundColor White
                            Write-Host "          INFORMACION DETALLADA DE SOPORTE REMOTO: $($os.CSName)" -ForegroundColor Green
                            Write-Host "======================================================================" -ForegroundColor White
                            Write-Host " Hostname:            $($os.CSName)"
                            Write-Host " Fabricante:          $($cs.Manufacturer)" -ForegroundColor White
                            Write-Host " Modelo PC:           $($cs.Model)" -ForegroundColor White
                            Write-Host " Service TAG (S/N):   $($bios.SerialNumber)" -ForegroundColor Cyan
                            Write-Host " Version BIOS:        $($bios.Name)"
                            Write-Host " Monitor Instalado:   $monitorModels" -ForegroundColor White
                            Write-Host " Usuario Activo:      $activeUser" -ForegroundColor Cyan
                            Write-Host " Sistema de Arranque: $bootStyle ($partitionStyle)" -ForegroundColor Yellow
                            Write-Host " Sistema Operativo:   $($os.Caption) ($($os.OSArchitecture))"
                            Write-Host " Version S.O.:        $($os.Version) (Build $($os.BuildNumber))"
                            Write-Host " Procesador:          $($cpu.Name.Trim())"
                            Write-Host " Memoria RAM:         $([Math]::Round($cs.TotalPhysicalMemory / 1GB, 2)) GB"
                            
                            Write-Host "`n Unidades de Disco Fisico:" -ForegroundColor Green
                            if ($disksInfo) { $disksInfo | ForEach-Object { Write-Host $_ } } else { Write-Host "   No se detectaron unidades físicas." -ForegroundColor Yellow }
                            
                            Write-Host "`n Unidades Logicas Disponibles:" -ForegroundColor Green
                            if ($logicalDrivesInfo) { $logicalDrivesInfo | ForEach-Object { Write-Host $_ } } else { Write-Host "   No se detectaron unidades lógicas." -ForegroundColor Yellow }
                            
                            Write-Host "`n Adaptadores de Red Activos:" -ForegroundColor Green
                            if ($adaptersInfo) { $adaptersInfo | ForEach-Object { Write-Host $_ } } else { Write-Host "   No se encontraron adaptadores de red activos." -ForegroundColor Yellow }
                            
                            Write-Host "`n Gestion de Impresion:" -ForegroundColor Green
                            Write-Host "  * Impresora Predeterminada:" -ForegroundColor White
                            Write-Host "    $defaultPrinterInfo" -ForegroundColor Cyan
                            if ($availablePrinters) {
                                Write-Host "  * Otras Impresoras Disponibles:" -ForegroundColor White
                                $availablePrinters | ForEach-Object { Write-Host $_ }
                            }
                            Write-Host "======================================================================`n" -ForegroundColor White
                            
                        }
                        catch {
                            Write-Host "ERROR: No se pudo conectar o extraer informacion del equipo $ip." -ForegroundColor Red
                            Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Gray
                        }
                    }
                }
                "4" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op28"
                    Write-Host "Por favor seleccione una sub-opcion especifica (4.1)" -ForegroundColor Yellow
                }
                "4.1" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op28"
                    psHabilitarAdministracionRemota
                }
                "5" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op28"
                    Write-Host "Por favor seleccione una sub-opcion especifica (5.1, 5.2 o 5.3)" -ForegroundColor Yellow
                }
                "5.1" {
                    psGestionarServiciosUpdateRemoto -accion "Habilitar"
                }
                "5.2" {
                    psGestionarServiciosUpdateRemoto -accion "Deshabilitar"
                }
                "5.3" {
                    psGestionarServiciosUpdateRemoto -accion "Estado"
                }
                "0" {
                    menuPrincipal
                }
                Default {
                    Write-Host "Opcion invalida." -ForegroundColor Red
                }
            }
            if (-not $salirSub) { Read-Host "SUB_MENU 28: Presione ENTER para continuar..." }
        }
        catch {
            Write-Host "`n[ERROR NO ESPERADO]: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Presione Enter para continuar..."
        }
        finally {
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            Get-Variable | Where-Object { 
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 200
        }
    } while (-not $salirSub)
}
function menuPrincipal {
    Clear-Host
    $salirPrincipal = $false

    # 1. Validacion de privilegios de Administrador
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "ERROR: Debes ejecutar este script como ADMINISTRADOR." -ForegroundColor Red
        Pause
        exit
    }

    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header " ATENCION: ESTA HERRAMIENTA REALIZA CAMBIOS EN EL SISTEMA OPERATIVO"
            Write-Host "  1.  Hostname e IP" -ForegroundColor Green
            Write-Host "  3.  Desfragmentar Unidad C: (Principal)" -ForegroundColor DarkCyan
            Write-Host "  4.  Desfragmentar Otras Unidades (HDD)"
            Write-Host "    4.1 Optimizar Unidades de SSD (alternativa a defrag)."
            Write-Host "  5.  Eliminar Archivos Temporales S.O." -ForegroundColor DarkCyan
            Write-Host "  7.  Resetear Internet Explorer"
            Write-Host "  9.  Abrir Internet Explorer con Topacio"
            Write-Host "  10. Ping Infraestructura"
            Write-Host "  11. Revisar Unidades (CHKDSK) - Reparar, localizar y desmontar - chkdsk.exe /F /R /X." -ForegroundColor DarkCyan
            Write-Host "  12. Mostrar Todo el Contenido de UNIDAD (ATTRIB)."
            Write-Host "  13. Abrir Google CHROME con Buscador (Modo Incognito)."
            Write-Host "  14. Abrir Propiedades de INTERNET EXPLORER."
            Write-Host "  15. Cerrar Proceso Explorer.exe (explorer)." -ForegroundColor DarkCyan
            Write-Host "  16. Abrir Proceso Explorer.exe (explorer)."
            Write-Host "  17. Abrir Administrador de Tareas (taskmgr)."
            Write-Host "  18. Abrir Simbolo de SISTEMA (cmd)."
            Write-Host "  19. Abrir PowerShell Administrador"
            Write-Host "  20. ---)) LOCAL: INFORMACION SISTEMA CMD [RAM] [HDD] - DISM - RESETEAR RED."
            Write-Host "  21. ---)) LOCAL: VENTANAS ADMINISTRACION WINDOWS - ANTIVIRUS."
            Write-Host "  22. ---)) LOCAL: SERVICIOS WINDOWS - HERRAMIENTAS AVANZADOS."
            Write-Host "  23. ---)) LOCAL: HELPDESK LOCAL - HERRAMIENTAS DE SISTEMA." -ForegroundColor Green
            Write-Host "  24. ***)) LOCAL: COMANDOS WINDOWS 11 *****"
            Write-Host "  25. +++)) AD: COMANDOS RED - ADMINISTRACION REMOTA +++++" -ForegroundColor Cyan
            Write-Host "  26. ===)) AD: COMANDOS AD =====" -ForegroundColor Cyan
            Write-Host "  27. ###)) ONLINE: Herramientas en INTERNET #####"
            Write-Host "  28. ---)) AD: GESTION HELPDESK -----" -ForegroundColor Cyan
            Write-Host "  29. ***)) LOCAL: APAGADO Y REINICIADO DE PC *****"
            Write-Host "    29.1 Apagar PC." -ForegroundColor Green
            Write-Host "    29.2 Reiniciar Sistema Operativo (shutdown)." -ForegroundColor Green
            Write-Host "  30. REFRESH (Modo LOCAL)."
            Write-Host "  31. REFRESH desde GitHub (Online)." -ForegroundColor Cyan
            Write-Host "  0.  Salir"
            Write-Host "======================================================================" -ForegroundColor Yellow
            
            #Write-Host $header -ForegroundColor Cyan

            # 3. Bucle Principal

            $opcion = Read-Host "Seleccione una opcion"

            switch ($opcion) {
                "1" { 
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion (Hostname e IP)"

                    # --- OBTENER ESPECIFICACIONES DEL EQUIPO ---
                    # 1. Hostname
                    $hostname = [System.Net.Dns]::GetHostName()

                    # 2. Marca y Modelo
                    $sys = Get-WmiObject Win32_ComputerSystem
                    $marca = if ($sys.Manufacturer) { $sys.Manufacturer.Trim() } else { "Desconocido" }
                    $modelo = if ($sys.Model) { $sys.Model.Trim() } else { "Desconocido" }

                    # 3. Dominio / Grupo de trabajo
                    $redGrupo = ""
                    if ($sys.PartOfDomain) {
                        $redGrupo = "Dominio: $($sys.Domain)"
                    } else {
                        $redGrupo = "Grupo de Trabajo: $($sys.Domain)"
                    }

                    # 4. Sistema Operativo
                    $os = Get-WmiObject Win32_OperatingSystem
                    $osName = if ($os.Caption) { $os.Caption.Trim() } else { "Windows (Desconocido)" }
                    $osVer = if ($os.Version) { $os.Version.Trim() } else { "" }
                    $osArch = if ($os.OSArchitecture) { $os.OSArchitecture.Trim() } else { "" }
                    $osDisplay = $osName
                    if ($osVer) { $osDisplay += " ($osVer)" }
                    if ($osArch) { $osDisplay += " $osArch" }

                    # 5. Microprocesador (CPU)
                    $cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
                    $cpuName = if ($cpu -and $cpu.Name) { $cpu.Name.Trim() } else { "Desconocido" }

                    # 6. Memoria RAM
                    $ramSum = (Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum
                    if (-not $ramSum) {
                        $ramSum = $sys.TotalPhysicalMemory
                    }
                    $ramGB = if ($ramSum) { [Math]::Round($ramSum / 1GB, 2) } else { 0 }

                    # 7. Almacenamiento Total (Discos Físicos)
                    $disks = Get-WmiObject Win32_DiskDrive
                    $totalStorageBytes = 0
                    $diskDetails = @()
                    foreach ($disk in $disks) {
                        if ($disk.Size) {
                            $totalStorageBytes += $disk.Size
                            $sizeGB = [Math]::Round($disk.Size / 1GB, 2)
                            $diskDetails += "      - $($disk.Model): $sizeGB GB"
                        }
                    }
                    $totalStorageGB = [Math]::Round($totalStorageBytes / 1GB, 2)

                    # --- MOSTRAR INFORMACIÓN DEL EQUIPO ---
                    Write-Host "===========================================================" -ForegroundColor Cyan
                    Write-Host "            CARACTERISTICAS Y ESPECIFICACIONES             " -ForegroundColor Cyan
                    Write-Host "===========================================================" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "  Nombre del Equipo (Hostname): " -NoNewline
                    Write-Host "$hostname" -ForegroundColor Green
                    Write-Host "  Red / Grupo:                  " -NoNewline
                    Write-Host "$redGrupo" -ForegroundColor Green
                    Write-Host "  Marca y Modelo:               " -NoNewline
                    Write-Host "$marca / $modelo" -ForegroundColor Yellow
                    Write-Host "  Sistema Operativo:            " -NoNewline
                    Write-Host "$osDisplay" -ForegroundColor Yellow
                    Write-Host "  Microprocesador:              " -NoNewline
                    Write-Host "$cpuName" -ForegroundColor Yellow
                    Write-Host "  Memoria RAM Instalada:        " -NoNewline
                    Write-Host "$ramGB GB" -ForegroundColor Yellow
                    Write-Host "  Almacenamiento Total:         " -NoNewline
                    Write-Host "$totalStorageGB GB" -ForegroundColor Yellow
                    foreach ($detail in $diskDetails) {
                        Write-Host $detail -ForegroundColor Gray
                    }
                    Write-Host ""

                    # --- OBTENER ADAPTADORES DE RED ---
                    $interfaces = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()

                    Write-Host "===========================================================" -ForegroundColor Cyan
                    Write-Host "             CONFIGURACION DE RED Y CONECTIVIDAD           " -ForegroundColor Cyan
                    Write-Host "===========================================================" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "  --- Adaptadores de Red Activos ---" -ForegroundColor Yellow
                    Write-Host ""

                    $hayAdaptadorActivo = $false

                    foreach ($adapter in $interfaces) {
                        # Solo procesar adaptadores activos/conectados que no sean de loopback
                        if ($adapter.OperationalStatus -eq "Up" -and $adapter.NetworkInterfaceType -ne "Loopback") {
                            $properties = $adapter.GetIPProperties()
                            
                            # Obtener IPs
                            $ips = @()
                            foreach ($unicast in $properties.UnicastAddresses) {
                                if ($unicast.Address.AddressFamily -eq "InterNetwork") {
                                    $ips += $unicast.Address.ToString()
                                }
                            }

                            if ($ips.Count -gt 0) {
                                $hayAdaptadorActivo = $true
                                
                                # Tipo de Conectividad (Wired Ethernet vs Wi-Fi)
                                $tipoConectividad = switch ($adapter.NetworkInterfaceType) {
                                    "Wireless80211" { "Wi-Fi (Inalambrico)" }
                                    "Ethernet"      { "Ethernet (Cableado)" }
                                    Default         { $adapter.NetworkInterfaceType.ToString() }
                                }

                                # DHCP o IP Fija
                                $adapterGuid = $adapter.Id.Trim("{}").ToLower()
                                $wmiConfig = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.SettingID.Trim("{}").ToLower() -eq $adapterGuid }
                                $dhcpStatus = "Desconocido"
                                if ($wmiConfig) {
                                    if ($wmiConfig.DHCPEnabled) {
                                        $dhcpStatus = "DHCP"
                                    } else {
                                        $dhcpStatus = "IP Fija (Estatica)"
                                    }
                                }

                                # Direccion MAC
                                $macRaw = $adapter.GetPhysicalAddress().ToString()
                                $mac = if ($macRaw) { ($macRaw -split '(?<=\G.{2})' | Where-Object { $_ }) -join ":" } else { "No disponible" }

                                Write-Host "  [+] Adaptador:  " -NoNewline
                                Write-Host $adapter.Description -ForegroundColor Cyan
                                Write-Host "      Estado:     " -NoNewline
                                Write-Host "Conectado / Activo" -ForegroundColor Green
                                Write-Host "      Conexion:   " -NoNewline
                                Write-Host $tipoConectividad -ForegroundColor Gray
                                Write-Host "      Asignacion: " -NoNewline
                                Write-Host $dhcpStatus -ForegroundColor Gray
                                Write-Host "      Direccion MAC: " -NoNewline
                                Write-Host $mac -ForegroundColor Yellow
                                Write-Host "      IP(s):      " -NoNewline
                                Write-Host ($ips -join ", ") -ForegroundColor Yellow

                                # Obtener Puerta de Enlace (Gateway)
                                $gateways = @()
                                foreach ($gateway in $properties.GatewayAddresses) {
                                    $gateways += $gateway.Address.ToString()
                                }
                                if ($gateways.Count -gt 0) {
                                    Write-Host "      Gateway:    " -NoNewline
                                    Write-Host ($gateways -join ", ") -ForegroundColor Gray
                                }

                                # Obtener Servidores DNS
                                $dnsServers = @()
                                foreach ($dns in $properties.DnsAddresses) {
                                    if ($dns.AddressFamily -eq "InterNetwork") {
                                        $dnsServers += $dns.ToString()
                                    }
                                }
                                if ($dnsServers.Count -gt 0) {
                                    Write-Host "      DNS:        " -NoNewline
                                    Write-Host ($dnsServers -join ", ") -ForegroundColor Green
                                }
                                else {
                                    Write-Host "      DNS:        " -NoNewline
                                    Write-Host "No configurados" -ForegroundColor DarkGray
                                }
                                Write-Host ""
                            }
                        }
                    }

                    if (-not $hayAdaptadorActivo) {
                        Write-Host "  No se detectaron adaptadores de red activos con IPv4 configurada." -ForegroundColor Red
                    }

                    Write-Host "===========================================================" -ForegroundColor Cyan
                    Write-Host ""
                }
                "3" { 
                    # clear-Host 
                    cabecera
                    menuOpcion "Haz elegido la opcion:  $opcion"

                    Write-Host "Desfragmentando C:..." -ForegroundColor Green
                    DEFRAG.exe C:\ /B /U /V /H
                    # El parámetro /B en el comando defrag se usa para realizar una optimización de arranque
                    Write-Host " "
                }
                "4" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    # $u = Read-Host "Letra de unidad (ej. D:)"
                    # if ($u) { defrag $u /U /V } 
                        
                    fsutil fsinfo drives
                    powershell.exe Get-Volume
                    $unit = Read-Host "Letra de la unidad a desfragmentar y presiona ENTER"
                    DEFRAG.exe /U /O /V /H ${unit}":"
                        
                    # /A /U /V /H
                        
                    #Read-Host "Presione Enter para volver..."
                    Write-Host " "
                }

                "4.1" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"
                        
                    fsutil fsinfo drives
                    # powershell.exe Get-WmiObject Win32_LogicalDisk
                    powershell.exe Get-Volume
                    Write-Host ""
                    $unidad = Read-Host "Letra de la unidad a desfragmentar y presiona ENTER"
                    Optimize-Volume -DriveLetter ${unidad} -ReTrim -Verbose
                        
                    Write-Host " "
                }
                "5" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"
                        
                    Write-Host "Iniciando Liberador de espacio (Configuracion 64)..." -ForegroundColor Yellow
                    try {
                        # Ejecuta el proceso de limpieza
                        Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:64" -Wait
                        Write-Host "Limpieza completada con exito." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Error al ejecutar Cleanmgr." -ForegroundColor Red
                    }
                        
                    Write-Host " "
                }

                "7" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process iexplore.exe
                    taskkill.exe /F /IM iexplore.exe /T

                    # Limpiar todo (Equivalente a 255)
                    Write-Host "Iniciado limpieza de todo lo (Equivalente a 255)"
                    Start-Process "rundll32.exe" -ArgumentList "InetCpl.cpl,ClearMyTracksByProcess 255" -Wait
                    Write-Host " [OK]" -ForegroundColor Green

                    # Limpiar datos específicos incluyendo complementos (Equivalente a 4351)
                    Write-Host "Iniciado limpieza de datos específicos incluyendo complementos (Equivalente a 4351)"
                    Start-Process "rundll32.exe" -ArgumentList "InetCpl.cpl,ClearMyTracksByProcess 4351" -Wait
                    Write-Host " [OK]" -ForegroundColor Green

                    Start-Process "rundll32.exe" -ArgumentList "inetcpl.cpl,ResetIEtoDefaults" -Wait
                    Write-Host "Proceso de restablecimiento finalizado." -ForegroundColor Green

                    Write-Host ""

                }

                "9" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"
                        

                    Write-Host "Iniciando IE..." -ForegroundColor Yellow
                    Start-Process -FilePath "C:\Program Files\Internet Explorer\iexplore.exe" -ArgumentList "https://topacioprod.gmsantacruz.gob.bo/"

                    Write-Host ""

                }
                "10" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    # Definimos las IPs y sus etiquetas en una tabla para facilitar cambios
                    $destinos = @(
                        @{Nombre = "DNS Google 1 - 8.8.8.8"; IP = "8.8.8.8" },
                        @{Nombre = "Bolivianita - 192.168.13.249"; IP = "192.168.13.249" },
                        @{Nombre = "Berilo 1 - 192.168.13.243"; IP = "192.168.13.243" },
                        @{Nombre = "Berilo 2 - 192.168.13.36"; IP = "192.168.13.36" },
                        @{Nombre = "SRV H. PLAN - 192.168.176.254"; IP = "192.168.176.254" },
                        @{Nombre = "DNS 1 GAM - 172.25.108.100"; IP = "172.25.108.100" },
                        @{Nombre = "DNS 2 GAM - 192.168.13.214"; IP = "192.168.13.214" }
                    )

                    Write-Host "Iniciando monitoreo de red en ventanas independientes..." -ForegroundColor Cyan

                    foreach ($item in $destinos) {
                        # Ejecutamos CMD, le pasamos el título y el comando Ping infinito (-t)
                        Start-Process cmd.exe -ArgumentList "/c title $($item.Nombre) && ping $($item.IP) -t"
                    }

                        
                    Write-Host ""

                }
                "10.1" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    $ip = Read-Host "IP/Host para Ping"

                    if ($ip) {
                        # start: abre nueva ventana
                        # cmd /k: ejecuta el comando y mantiene la ventana abierta
                        # ping -t: ping continuo en CMD
                        Start-Process cmd.exe "/k ping $ip -t"
                    }

                    Write-Host ""
                }
                "11" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"
                        
                    # 1. Mostrar información de las unidades de forma legible
                    Write-Host "--- UNIDADES DETECTADAS ---" -ForegroundColor Cyan
                    Get-WmiObject Win32_LogicalDisk | Select-Object DeviceID, VolumeName, 
                    @{Name = "Tipo"; Expression = { $_.Description } }, 
                    @{Name = "Tamaño(GB)"; Expression = { [Math]::Round($_.Size / 1GB, 2) } } | Format-Table -AutoSize

                    # 2. CAPTURA DE DATO: Solicitar la letra de la unidad
                    $letra = Read-Host "Escribe la letra de la unidad a REVISAR (ejemplo: D)"

                    # Limpiar la entrada (por si el usuario escribió "D:" o "d ")
                    $unidad = $letra.Replace(":", "").Trim().ToUpper()

                    # 3. Validación y ejecución
                    if (-not [string]::IsNullOrWhiteSpace($unidad) -and $unidad.Length -eq 1) {
                            
                        $pathUnidad = "${unidad}:"
                        Write-Host "Preparando CHKDSK para la unidad $pathUnidad..." -ForegroundColor Yellow
                        Write-Host "Nota: Si la unidad está en uso, se solicitara programar para el proximo reinicio." -ForegroundColor Gray

                        # Ejecución de chkdsk con los parámetros originales
                        # /F (Corregir), /R (Recuperar sectores), /X (Forzar desmontaje)
                        chkdsk.exe $pathUnidad /F /R /X
                    }
                    else {
                        Write-Host "Error: Letra de unidad no valida." -ForegroundColor Red
                    }                

                    Write-Host ""
                }
                "12" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    # 1. Mostrar información de las unidades de forma profesional
                    Write-Host "--- UNIDADES DISPONIBLES ---" -ForegroundColor Cyan
                    Get-WmiObject Win32_LogicalDisk | Select-Object DeviceID, VolumeName, Description | Format-Table -AutoSize

                    # 2. CAPTURA DE DATO: Solicitar la letra de la unidad
                    $letraInput = Read-Host "Escribe la letra de la UNIDAD para quitar atributos"
                    $unidad = $letraInput.Replace(":", "").Trim().ToUpper() + ":\"

                    # 3. Validación de existencia
                    if (Test-Path $unidad) {
                        Write-Host "`nQuitando atributos (Solo lectura, Sistema, Oculto) en $unidad..." -ForegroundColor Yellow
                            
                        # Buscamos todos los archivos y carpetas de forma recursiva
                        $elementos = Get-ChildItem -Path $unidad -Recurse -Force -ErrorAction SilentlyContinue

                        foreach ($item in $elementos) {
                            try {
                                # Establecemos los atributos a "Normal" (equivale a quitar R, S, H, A)
                                Set-ItemProperty -Path $item.FullName -Name Attributes -Value "Normal"
                            }
                            catch {
                                # Algunos archivos del sistema pueden estar bloqueados, los ignoramos
                                continue
                            }
                        }
                            
                        Write-Host "Proceso completado en $unidad" -ForegroundColor Green
                    }
                    else {
                        Write-Host "Error: La unidad $unidad no existe o no es válida." -ForegroundColor Red
                    }

                    Write-Host ""
                }
                "13" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process "chrome.exe" -ArgumentList "--incognito"

                    Write-Host ""
                }
                "14" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"
                        
                    Start-Process "control.exe" -ArgumentList "inetcpl.cpl"

                    Write-Host ""
                }
                "15" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process "taskkill.exe" -ArgumentList "/F /IM explorer.exe" -NoNewWindow -Wait

                    Write-Host ""
                }
                "16" { 
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process "explorer.exe"               

                    Write-Host ""
                }

                "17" { 
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process taskmgr

                    Write-Host ""
                }

                "18" { 
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process cmd

                    Write-Host ""
                }

                "19" { 
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process "PowerShell.exe"

                    Write-Host ""
                }

                "20" { 
                    # Llamada a submenu.20
                    psSubMenu20
                }
                "21" { 
                    # Llamada a submenu.21
                    psSubMenu21
                }
                "22" { 
                    # Llamada a submenu.22
                    psSubMenu22
                }
                "23" { 
                    # Llamada a submenu.23
                    psSubMenu23
                }
                "24" { 
                    # Llamada a submenu.24
                    psSubMenu24
                }
                "25" { 
                    # Llamada a submenu.25
                    psSubMenu25
                }
                "26" { 
                    # Llamada a submenu.26
                    psSubMenu26
                }
                "27" { 
                    # Llamada a submenu.27
                    psSubMenu27
                }
                "28" {
                    # Llamada a submenu.28
                    psSubMenu28
                }
                
                "29.1" {
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process "shutdown.exe" -ArgumentList "/s /f /t 5"

                    Write-Host ""
                        
                }
                "29.2" {
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process "shutdown.exe" -ArgumentList "/g /f /t 5"

                    Write-Host ""
                        
                }
                "30" {
                    cabecera
                    Write-Host "`n[!] Reiniciando herramienta..." -ForegroundColor Cyan

                    # Si estamos en entorno de desarrollo, reconstruir primero
                    psReconstruirSiDesarrollo

                    # Start-Sleep -Milliseconds 500
                    Start-Sleep -Seconds 2
                        
                    # Recuperamos la ruta que guardamos en la cabecera .bat
                    $ruta = $env:SCRIPT_PATH
                    Write-Host "Ruta del Software:....... $ruta" -ForegroundColor Green
                    Start-Sleep -Seconds 3
                        
                    if ($ruta -and (Test-Path $ruta)) {
                        # Lanzamos el proceso usando CMD para que interprete el .bat correctamente
                        Start-Process cmd.exe -ArgumentList "/c `"$ruta`""
                        exit
                    }
                    else {
                        Write-Error "Error: No se pudo localizar la variable SCRIPT_PATH."
                        Pause
                    }
                }

                "31" {
                    cabecera
                    Write-Host "`n[!] Descargando y reiniciando desde repositorio remoto..." -ForegroundColor Cyan
                    Start-Sleep -Seconds 2
                    Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "irm https://raw.githubusercontent.com/spwil/shellWil/main/ShellSW.bat | iex"
                    exit
                }

                "1010" {
                    cabecera
                    menuOpcion "MODO DESARROLLADOR: PUBLICAR EN GITHUB (Opcion 1010)"
                    
                    # 1. Resolver ruta del repositorio
                    $repoPath = if ($env:SCRIPT_PATH) { Split-Path $env:SCRIPT_PATH } else { $PSScriptRoot }
                    if (-not $repoPath) { $repoPath = Get-Location }

                    # 2. Detección técnica estricta de entorno de desarrollo
                    $esDesarrollo = $false
                    $gitPath = Get-Command git -ErrorAction SilentlyContinue
                    
                    if ($gitPath -and (Test-Path (Join-Path $repoPath ".git"))) {
                        Push-Location $repoPath
                        try {
                            $remoteUrl = git remote get-url origin 2>$null
                            # Validamos que el origin coincida con el repositorio del proyecto
                            if ($remoteUrl -like "*spwil/shellWil*") {
                                $esDesarrollo = $true
                            }
                        }
                        finally {
                            Pop-Location
                        }
                    }

                    if (-not $esDesarrollo) {
                        Write-Host "`n[INFO] Esta opcion solo esta disponible en el entorno de desarrollo autorizado." -ForegroundColor Yellow
                        Write-Host "No se detecto la carpeta local de Git o el repositorio origin correcto." -ForegroundColor Gray
                        Write-Host ""
                    }
                    else {
                        # 3. Auto-compilación automática
                        Write-Host "`n[*] Iniciando auto-compilacion del script unificado (build.ps1)..." -ForegroundColor Cyan
                        psReconstruirSiDesarrollo

                        # 4. Mostrar resumen de cambios
                        Push-Location $repoPath
                        try {
                            Write-Host "`n[*] Resumen de archivos modificados para subir:" -ForegroundColor Yellow
                            $gitStatus = git status -s
                            if ([string]::IsNullOrEmpty($gitStatus)) {
                                Write-Host "No hay cambios pendientes de confirmacion en el repositorio." -ForegroundColor Green
                                Pop-Location
                                break
                            }
                            Write-Host $gitStatus -ForegroundColor Gray
                            Write-Host ""

                            # 5. Solicitar descripción del commit
                            $desc = Read-Host "Ingrese la descripcion para el commit (Mensaje de Git)"
                            if ([string]::IsNullOrEmpty($desc)) {
                                Write-Host "`n[!] Operacion cancelada: El mensaje de commit no puede estar vacio." -ForegroundColor Red
                                Pop-Location
                                break
                            }

                            # 6. Confirmación de seguridad
                            $confirmar = Read-Host "¿Proceder con la actualizacion en GitHub? (S/N) [N]"
                            if ($confirmar -notmatch "^[sS]$") {
                                Write-Host "`n[!] Operacion cancelada por el usuario." -ForegroundColor Yellow
                                Pop-Location
                                break
                            }

                            # 7. Ejecución de Git
                            Write-Host "`n[*] Agregando archivos al area de preparacion (git add -A)..." -ForegroundColor Gray
                            git add -A
                            
                            Write-Host "[*] Confirmando cambios localmente (git commit)..." -ForegroundColor Gray
                            $commitResult = git commit -m "$desc" 2>&1
                            Write-Host $commitResult -ForegroundColor Gray

                            # Detectar rama activa actual dinámicamente
                            $activeBranch = git branch --show-current
                            if ([string]::IsNullOrEmpty($activeBranch)) {
                                $activeBranch = "main" # fallback
                            }

                            Write-Host "[*] Subiendo cambios a GitHub en la rama '$activeBranch' (git push)..." -ForegroundColor Yellow
                            $pushResult = git push origin $activeBranch 2>&1
                            
                            # Comprobar código de salida
                            if ($LASTEXITCODE -eq 0) {
                                Write-Host "`n[OK] ¡Repositorio de GitHub actualizado exitosamente en la rama '$activeBranch'!" -ForegroundColor Green
                            }
                            else {
                                Write-Host "`n[ERROR] Ocurrio un problema al subir los cambios." -ForegroundColor Red
                                Write-Host "Detalle del error:" -ForegroundColor Red
                                Write-Host $pushResult -ForegroundColor Gray
                            }
                        }
                        catch {
                            Write-Host "`n[ERROR NO ESPERADO] Error al interactuar con Git: $_" -ForegroundColor Red
                        }
                        finally {
                            Pop-Location
                        }
                    }
                    Write-Host ""
                }

                "0" { 
                    #$salirPrincipal = $true 
                    Write-Host "C E R R A N D O   A P L I C A C I O N  ..." -ForegroundColor Magenta

                    Write-Host "La tarea ha finalizado. La consola se cerrara en 3 segundos..." -ForegroundColor Cyan
                    Start-Sleep -Seconds 3

                    # Comando para cerrar
                    exit
                }

                Default { 
                    Write-Host "OPCION INVALIDO." -ForegroundColor Red 
                    Start-Sleep -Seconds 1
                }
            } # Cierra switch
            if (-not $salirSub) { Read-Host "MENU PRINCIPAL: Presione ENTER para continuar..." }
        } # Cierra try

        catch {
            Write-Host "`n[ERROR NO ESPERADO]: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Presione Enter para continuar..."            
        } # Cierra catch

        finally {
            # *************************************************************************************
            # BLOQUE DE LIMPIEZA Y REFRESCO (Se ejecuta después de cada opción)
            # *************************************************************************************
            
            # 1. Liberar memoria de objetos COM/WMI/CIM colgados
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()

            # 2. Eliminar variables temporales de la sesión para evitar errores de "cadena de entrada"
            # Mantenemos variables críticas del script
            Get-Variable | Where-Object { 
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. Pequeña pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }

    } while (-not $salirPrincipal)
}
#************************************************* FIN PRINCIPAL ******************************************************************
#**********************************************************************************************************************************


# Ejecutar el MENU PRINCIPAL
menuPrincipal
