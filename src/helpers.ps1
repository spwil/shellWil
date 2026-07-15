
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
            if ($p.Id -gt 4) { # Omitimos Idle y System
                try {
                    [RamUtil]::EmptyWorkingSet($p.Handle) | Out-Null
                } catch {}
            }
            if ($p) { $p.Dispose() }
        }
        Write-Host "RAM optimizada correctamente." -ForegroundColor Green
    } catch {
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
                } else {
                    Write-Host "[DEV] Error en la reconstruccion (Codigo de salida: $($p.ExitCode))." -ForegroundColor Red
                }
            } catch {
                Write-Host "[DEV] Fallo al ejecutar el script de ensamblado: $_" -ForegroundColor Red
            }
        }
    }
}

function psHabilitarAdministracionRemota {
    param(
        [string]$targetInput,
        [string]$baseIP = "192.168.176."
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
        } else {
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
        'netsh advfirewall firewall set rule group="Administracion remota" new enable=yes'
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
    } else {
        $where = Get-Command psexec -ErrorAction SilentlyContinue
        if ($where) {
            $psexecPath = $where.Definition
            $psexecFound = $true
        }
    }

    if ($psexecFound) {
        Write-Host "[*] Intentando habilitacion via PsExec (SMB puerto 445)..." -ForegroundColor Yellow
        $argsList = "\\$computerTarget -accepteula -s cmd.exe /c $fullCommand"
        $p = Start-Process -FilePath $psexecPath -ArgumentList $argsList -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
        if ($p -and $p.ExitCode -eq 0) {
            Write-Host "[OK] Habilitacion remota ejecutada exitosamente via PsExec!" -ForegroundColor Green
            $exito = $true
        } else {
            $code = if ($p) { $p.ExitCode } else { "N/A" }
            Write-Host "[-] PsExec no pudo completar la accion (Codigo: $code)." -ForegroundColor Yellow
        }
    } else {
        Write-Host "[-] PsExec.exe no detectado en C:\PSTools ni en el PATH. Omitiendo." -ForegroundColor Gray
    }

    # B. Método 2: WinRM / PSRemoting (WS-Man 5985)
    if (-not $exito) {
        Write-Host "[*] Intentando habilitacion via WinRM (PowerShell Remoting)..." -ForegroundColor Yellow
        try {
            Invoke-Command -ComputerName $computerTarget -ScriptBlock {
                netsh advfirewall firewall set rule group="Windows Management Instrumentation (WMI)" new enable=yes
                netsh advfirewall firewall set rule group="Instrumentacion de administracion de Windows (WMI)" new enable=yes
                netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=yes
                netsh advfirewall firewall set rule group="Compartir archivos e impresoras" new enable=yes
                netsh advfirewall firewall set rule group="Remote Administration" new enable=yes
                netsh advfirewall firewall set rule group="Administracion remota" new enable=yes
            } -ErrorAction Stop | Out-Null
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
            $result = Invoke-WmiMethod -Class Win32_Process -Name Create -ComputerName $computerTarget -ArgumentList $fullCommand -ErrorAction Stop
            if ($result -and $result.ReturnValue -eq 0) {
                Write-Host "[OK] Comando enviado via WMI con exito!" -ForegroundColor Green
                $exito = $true
            } else {
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
    } else {
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
        } else {
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
                        Servicio    = $serv
                        Nombre      = $serviceWmi.DisplayName
                        TipoInicio  = $serviceWmi.StartMode
                        Estado      = $serviceWmi.State
                        Metodo      = "WMI"
                    }
                } else {
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
                            Servicio    = $_.Name
                            Nombre      = $_.DisplayName
                            TipoInicio  = $_.StartType.ToString()
                            Estado      = $_.Status.ToString()
                        }
                    }
                } -ArgumentList (,$serviciosConsulta) -ErrorAction Stop
                
                foreach ($res in $remoteResults) {
                    $estadoResultados += [PSCustomObject]@{
                        Servicio    = $res.Servicio
                        Nombre      = $res.Nombre
                        TipoInicio  = $res.TipoInicio
                        Estado      = $res.Estado
                        Metodo      = "WinRM"
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
                            Servicio    = $serv
                            Nombre      = $serv # fallback
                            TipoInicio  = $startMode
                            Estado      = $state
                            Metodo      = "PsExec (sc)"
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
        } else {
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
    } else {
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
                } elseif ($act -eq "Stop") {
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
                } elseif ($act -eq "Stop") {
                    $isActOk = ($resAct -eq 0 -or $resAct -eq 5 -or $resAct -eq 6)
                } else {
                    $isActOk = $true # Acción "None"
                }

                if ($isModeOk -and $isActOk) {
                    Write-Host " -> Servicio ${serv}: Modo=$mode, Accion=$act [OK]" -ForegroundColor Green
                } else {
                    $wmiExito = $false
                    # Cambiamos a color amarillo para advertir que requiere fallback, sin asustar al usuario con un error rojo fatal
                    Write-Host " -> Servicio ${serv}: Requiere fallback (ModoRes=$resMode, ActRes=$resAct)." -ForegroundColor Yellow
                }
            } else {
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
                    } elseif ($act -eq "Stop") {
                        Stop-Service -Name $name -Force -ErrorAction SilentlyContinue
                    }
                }
            } -ArgumentList (,$serviciosConfig) -ErrorAction Stop
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
        } else {
            if (Test-Path ".\PsExec.exe") {
                $psexecPath = ".\PsExec.exe"
                $psexecFound = $true
            } else {
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
                } elseif ($act -eq "Stop") {
                    $argsAct = "\\$computerTarget -accepteula -s cmd.exe /c sc stop $serv"
                }
                
                if ($argsAct -ne "") {
                    Start-Process -FilePath $psexecPath -ArgumentList $argsAct -Wait -NoNewWindow -ErrorAction SilentlyContinue | Out-Null
                }
                
                if ($pConfig -and $pConfig.ExitCode -eq 0) {
                    Write-Host " -> Servicio $serv configurado via PsExec [OK]" -ForegroundColor Green
                } else {
                    $psExito = $false
                    $code = if ($pConfig) { $pConfig.ExitCode } else { "N/A" }
                    Write-Host " -> Error al configurar $serv via PsExec (Codigo: $code)." -ForegroundColor Red
                }
            }
            if ($psExito) {
                $exito = $true
            }
        } else {
            Write-Host "[-] PsExec.exe no detectado en C:\PSTools ni en el PATH. Omitiendo." -ForegroundColor Gray
        }
    }

    # 4. Reporte final
    if ($exito) {
        Write-Host "`n========================================================" -ForegroundColor Green
        Write-Host "   SERVICIOS WINDOWS UPDATE CONFIGURADOS CON EXITO" -ForegroundColor White -BackgroundColor DarkGreen
        Write-Host "========================================================" -ForegroundColor Green
        Write-Host "La accion de '$accion' se ejecuto correctamente."
    } else {
        Write-Host "`n========================================================" -ForegroundColor Red
        Write-Host "        ERROR AL CONFIGURAR LOS SERVICIOS REMOTOS" -ForegroundColor White -BackgroundColor DarkRed
        Write-Host "========================================================" -ForegroundColor Red
        Write-Host "No se pudo conectar por WMI, WinRM ni PsExec en $computerTarget."
    }
}

#******************************************************** SUB MENU.20 *************************************************************
#**********************************************************************************************************************************

