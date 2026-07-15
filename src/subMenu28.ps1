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
