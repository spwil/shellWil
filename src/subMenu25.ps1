function psSubMenu25 {
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
            Write-Host "    11.1 Habilitar ejecucion remota y de scripts (Local)" -ForegroundColor Cyan
            Write-Host "    11.2 Denegar/Deshabilitar ejecucion remota (Local)" -ForegroundColor Yellow
            Write-Host "    11.3 Instalar todos los componentes de RSAT (Local)" -ForegroundColor Green
            Write-Host "  ----------------------------------------"
            Write-Host "  12. Habilitacion de RSAT - REMOTO"
            Write-Host "    12.1 Habilitar ejecucion de scripts (Remoto)" -ForegroundColor Cyan
            Write-Host "    12.2 Denegar/Deshabilitar ejecucion de scripts (Remoto)" -ForegroundColor Yellow
            Write-Host "    12.3 Instalar todos los componentes de RSAT (Remoto)" -ForegroundColor Green
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

                    # 1. Solicitar los 2 ultimos octeto al usuario
                    # Se usa Read-Host que es el equivalente a 'SET /P'
                    $segmentoFinal = Read-Host "Introduzca los 2 ultimos segmentos IP (192.168.XXX.xxx) y presione Enter"

                    # 2. Construir la dirección IP completa
                    $IPCompleta = "192.168.$segmentoFinal"

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

                    # 1. Entrada de datos
                    $baseIP = "192.168.176."
                    $ultimoOcteto = Read-Host "Ingrese el ultimo octeto de la IP (192.168.176.XXX)"
                    $ipRemota = $baseIP + $ultimoOcteto

                    Write-Host "`n--- Consultando informacion de red... ---" -ForegroundColor Yellow

                    if (-not (Test-Connection -ComputerName $ipRemota -Count 1 -Quiet)) {
                        Write-Warning "El equipo $ipRemota no responde a ping. Es posible que este apagado o tenga el firewall activo."
                    }

                    # Resolución de Hostname para soporte Kerberos en Dominio
                    $computerTarget = $ipRemota
                    Write-Host "[*] Resolviendo Hostname de $ipRemota..." -ForegroundColor Gray
                    try {
                        $entry = [System.Net.Dns]::GetHostEntry($ipRemota)
                        $computerTarget = $entry.HostName.Split('.')[0]
                        Write-Host "[+] Hostname resuelto: $computerTarget (Kerberos habilitado)" -ForegroundColor Green
                    }
                    catch {
                        # Intento por NetBIOS/nbtstat
                        $nbt = nbtstat -a $ipRemota
                        $lineaName = $nbt | Where-Object { $_ -match "<\x00>.*UNIQUE" } | Select-Object -First 1
                        if ($lineaName -and $lineaName -match "^\s*([A-Za-z0-9\-]+)") {
                            $computerTarget = $Matches[1].Trim()
                            Write-Host "[+] Hostname resuelto via NetBIOS: $computerTarget" -ForegroundColor Green
                        } else {
                            Write-Host "[-] No se pudo resolver Hostname. Usando IP directamente (NTLM)." -ForegroundColor Yellow
                        }
                    }

                    try {
                        # 2. Consultas WMI Optimizadas usando el Hostname (o IP fallback)
                        $sysInfo = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $computerTarget -ErrorAction Stop
                        
                        # Obtenemos la configuracion de red filtrando solo adaptadores físicos activos
                        $nic = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $computerTarget `
                            -Filter "IPEnabled = TRUE" -ErrorAction Stop | 
                        Where-Object { $_.Description -notmatch "Virtual|Pseudo|Bluetooth|VPN" } | 
                        Select-Object -First 1

                        if ($nic) {
                            # 3. Formateo de la salida
                            $dnsActuales = "N/A"
                            if ($nic.DNSServerSearchOrder) {
                                $dnsActuales = $nic.DNSServerSearchOrder -join ", "
                            }
                            $tipoIP = "ESTATICA (MANUAL)"
                            if ($nic.DHCPEnabled) {
                                $tipoIP = "DINAMICA (DHCP)"
                            }

                            Write-Host "`n================================================" -ForegroundColor White
                            Write-Host " INFORMACION DETALLADA DEL EQUIPO" -ForegroundColor Green
                            Write-Host "================================================" -ForegroundColor White
                            
                            Write-Host " HOST NAME:       $($sysInfo.CSName)" -ForegroundColor Cyan
                            Write-Host " DIRECCION MAC:   $($nic.MACAddress)" -ForegroundColor Yellow
                            Write-Host " TIPO DE IP:      $tipoIP"
                            Write-Host "------------------------------------------------"
                            Write-Host " DIRECCION IP:    $($nic.IPAddress[0])"
                            Write-Host " MASCARA:         $($nic.IPSubnet[0])"
                            Write-Host " GATEWAY:         $($nic.DefaultIPGateway -join ', ')"
                            Write-Host " DNS:             $dnsActuales"
                            Write-Host "================================================`n"
                        } 
                        else {
                            Write-Host "No se encontro un adaptador de red activo en $ipRemota." -ForegroundColor Red
                        }
                    }
                    catch {
                        Write-Host "ERROR: No se pudo establecer conexion con $ipRemota ($computerTarget)." -ForegroundColor Red
                        Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Gray
                    }

                    
                }

                "1.2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # --- CONFIGURACIÓN DE RED REMOTA CON COMPARATIVA ANTES/DESPUÉS ---
                    $baseIP = "192.168.176."
                    $ultimoOctetoActual = Read-Host "Ingrese el ultimo octeto de la IP ACTUAL (192.168.176.XXX)"
                    $ipRemota = $baseIP + $ultimoOctetoActual

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
                    $baseIP = "192.168.176."
                    $ultimoOctetoActual = Read-Host "Ingrese el ultimo octeto de la IP ACTUAL (192.168.176.XXX)"
                    $ipRemota = $baseIP + $ultimoOctetoActual

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

                    # Solicitud del ultimo octeto para la IP remota
                    $octeto4 = Read-Host "Ingrese el ULTIMO octeto de la IP remota (192.168.176.XXX)"
                    $ipRemota = "192.168.176.$octeto4"

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

                    # 1. Entrada de red
                    $octeto4 = Read-Host "Ingrese el ULTIMO octeto de la IP remota (192.168.176.XXX)"
                    $ipRemota = "192.168.176.$octeto4"

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

                    $Segmento = "192.168.176."

                    $Octeto = Read-Host "Ingrese el ultimo octeto del segmento 192.168.176.XXX"

                    if ([string]::IsNullOrEmpty($Octeto)) {
                        Write-Host ""
                        Write-Host "Debe ingresar un valor." -ForegroundColor Red
                        return
                    }

                    $IP = $Segmento + $Octeto

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

                    $Segmento = "192.168.176."

                    $Octeto = Read-Host "Ingrese el ultimo octeto del segmento 192.168.176.XXX"

                    if ([string]::IsNullOrEmpty($Octeto)) {
                        Write-Host ""
                        Write-Host "Debe ingresar un valor." -ForegroundColor Red
                        return
                    }

                    $IP = $Segmento + $Octeto

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

                    # --- HABILITACIÓN REMOTA DE ADMINISTRACIÓN ---
                    $baseIP = "192.168.176."
                    $ultimoOcteto = Read-Host "Ingrese el ultimo octeto de la IP (192.168.176.XXX) o la IP completa"
                    if ($ultimoOcteto -eq "") {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                    }
                    else {
                        $ipRemota = $ultimoOcteto
                        if ($ultimoOcteto -notmatch "\.") {
                            $ipRemota = $baseIP + $ultimoOcteto
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

                "3" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # 1. Definir el segmento de red
                    $segmento = "192.168"

                    # 2. Solicitar la entrada del usuario (Equivalente a SET /P)
                    Write-Host "==============================================" -ForegroundColor Cyan
                    Write-Host "   REINICIO REMOTO DE EQUIPOS (Win 7 - 11)    " -ForegroundColor Cyan
                    Write-Host "==============================================" -ForegroundColor Cyan

                    $ultimoOcteto = Read-Host "Introduzca los 2 ultimos segmentos IP para $segmento.XXX.xxx"
                    $IPRemota = "$segmento.$ultimoOcteto"

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

                    # 1. Definir el segmento de red
                    $segmento = "192.168"

                    # 2. Solicitar la entrada del usuario (Equivalente a SET /P)
                    Write-Host "==============================================" -ForegroundColor Cyan
                    Write-Host "   APAGADO REMOTO DE EQUIPOS (Win 7 - 11)    " -ForegroundColor Cyan
                    Write-Host "==============================================" -ForegroundColor Cyan

                    $ultimoOcteto = Read-Host "Introduzca los 2 ultimos segmentos IP para $segmento.XXX.xxx"
                    $IPRemota = "$segmento.$ultimoOcteto"

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
                    # ==============================================================================
                    $segmentoBase = "192.168"

                    Write-Host "==============================================" -ForegroundColor Cyan
                    Write-Host "     EXPLORADOR DE ESCRITORIO PUBLICO REMOTO  " -ForegroundColor Cyan
                    Write-Host "==============================================" -ForegroundColor Cyan

                    # El usuario debe ingresar algo como "176.80"
                    $ultimoOcteto = Read-Host "Introduzca los 2 ultimos segmentos IP para $segmentoBase.XXX.xxx"
                    $IPRemota = "$segmentoBase.$ultimoOcteto"

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
                    $segmentoBase = "192.168"

                    Write-Host "`n==============================================" -ForegroundColor Cyan
                    Write-Host "    ACCESO A CARPETA STARTUP (Win 7 - 11)     " -ForegroundColor Cyan
                    Write-Host "==============================================" -ForegroundColor Cyan

                    # El usuario debe ingresar algo como "176.80"
                    $ultimoOcteto = Read-Host "Introduzca los 2 ultimos segmentos IP para $segmentoBase.XXX.xxx"
                    $IPRemota = "$segmentoBase.$ultimoOcteto"

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
                    $ipPC = Read-Host "Introduzca ultimo octeto IP (192.168.176.xxx)"

                    # Convertir la clave segura a texto plano para PsExec (requerido por la herramienta)
                    $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))

                    $IPFinal = "192.168.176.$ipPC"
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
                    $ipPC = Read-Host "Introduzca ultimo octeto IP (192.168.176.xxx)"

                    # Conversión de credencial
                    $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))

                    $IPFinal = "192.168.176.$ipPC"
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

                    # 1. Entrada de red (Dos últimos octetos)
                    Write-Host "--- Configuracion de Energia GMSANTACRUZ ---" -ForegroundColor Cyan
                    $octeto3 = "176"
                    $octeto4 = Read-Host "Ingrese el CUARTO octeto (192.168.$octeto3.XXX)"
                    $ipRemota = "192.168.$octeto3.$octeto4"

                    # 2. Entrada de tiempo de pantalla
                    Write-Host "`n--- Configuracion de Tiempos ---" -ForegroundColor White
                    $minutosPantalla = Read-Host "Minutos para apagar la PANTALLA (Ej. 30)"

                    # Validación de entradas numéricas
                    if ($octeto3 -notmatch '^\d+$' -or $octeto4 -notmatch '^\d+$' -or $minutosPantalla -notmatch '^\d+$') {
                        Write-Host "ERROR: Todos los valores deben ser numericos." -ForegroundColor Red
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

                    $computer = Read-Host "`nIngrese el nombre o IP de la PC remota"
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
                    $octeto3 = '176'
                    $octeto4 = Read-Host 'Ingrese el CUARTO octeto (192.168.176.XXX)'

                    # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                    # 2. Captura del último OCTETO con validación simple
                    $baseIP = "192.168.$octeto3."
                    $hostID = $octeto4

                    if ($hostID -match '^\d{1,3}$') {
                        $fullIP = $baseIP + $hostID
                        Write-Host "`n--- Consultando Host: $fullIP ---" -ForegroundColor Cyan
                                
                        try {
                            # 3. Ejecución optimizada de quser (query user)
                            # Redirigimos el error 2 al flujo de éxito para procesar el texto de "No hay usuarios"
                            $resultado = quser /server:$fullIP 2>&1

                            # 4. Procesamiento de la respuesta
                            if ($resultado -like "*No hay ningún usuario*" -or $resultado -like "*No user exists*") {
                                Write-Host "Estado: Equipo encendido, pero sin sesiones activas." -ForegroundColor Cyan
                            }
                            elseif ($resultado -like "*Error*") {
                                Write-Host "Error: No se pudo establecer conexion RPC con $fullIP." -ForegroundColor Red
                                Write-Host "Verifique que el equipo esté en línea y el Firewall permita RPC." -ForegroundColor Gray
                            }
                            else {
                                # Limpiamos líneas vacías y mostramos la tabla de quser
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
                    #Write-Host "`nPresione cualquier tecla para finalizar esta consulta..."
                    # $null = [Console]::ReadKey()   # Esperar a presionar una tecla
                    Write-Host ""
                    Write-Host '========================================================================' -ForegroundColor Yellow
                    # Read-Host "  P R E S I O N E   ||| E N T E R |||   P A R A   C O N T I N U A R ..."
                    # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                    $usuarioInput = Read-Host 'Ingrese el NOMBRE DE USUARIO de dominio'
                    $ipRemota = "192.168.$octeto3.$octeto4"

                    if ($octeto4 -notmatch '^\d+$') {
                        Write-Host 'ERROR: El octeto ingresado debe ser un numero valido.' -ForegroundColor Red
                        $null = Read-Host -Prompt 'Presione ENTER para salir...'
                        # exit
                    }

                    if ([string]::IsNullOrEmpty($usuarioInput)) {
                        Write-Host 'ERROR: El nombre de usuario no puede estar vacio.' -ForegroundColor Red
                        $null = Read-Host -Prompt 'Presione ENTER para salir...'
                        # exit
                    }

                    Write-Host ''
                    Write-Host "Verificando enlace de red con $ipRemota..." -ForegroundColor Yellow

                    if (Test-Connection -ComputerName $ipRemota -Count 1 -Quiet) {
                        Mostrar-ImpresorasUsuarioRemoto -ip $ipRemota -usuarioTarget $usuarioInput
                    }
                    else {
                        Write-Host "ERROR: El equipo $ipRemota se encuentra fuera de linea (Offline)." -ForegroundColor Red
                    }

                    # Cierre limpio de consola
                    Write-Host ''                    
            
                }

                "10.2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # 1. Entrada de datos
                    $baseIP = "192.168.176."
                    $hostID = Read-Host "Ingrese el ultimo OCTETO del segmento 192.168.176.XXX"

                    if ($hostID -match '^\d{1,3}$') {
                        $targetIP = $baseIP + $hostID
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
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    Write-Host "Habilitando ejecucion remota y de scripts localmente..." -ForegroundColor Cyan
                    
                    # 1. Habilitar PSRemoting sin verificación de red pública
                    try {
                        Write-Host "Iniciando servicio WinRM (PSRemoting)..." -ForegroundColor Gray
                        Enable-PSRemoting -SkipNetworkProfileCheck -Force -ErrorAction Stop
                        Write-Host "[OK] PSRemoting habilitado localmente." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "ADVERTENCIA: No se pudo habilitar PSRemoting localmente." -ForegroundColor Yellow
                        Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Gray
                    }

                    # 2. Configurar ExecutionPolicy con escalamiento de ámbitos
                    try {
                        Write-Host "Estableciendo politica de ejecucion a RemoteSigned (LocalMachine)..." -ForegroundColor Gray
                        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -ErrorAction Stop
                        Write-Host "[OK] Politica establecida a RemoteSigned para LocalMachine." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Restriccion detectada para LocalMachine. Intentando para CurrentUser..." -ForegroundColor Yellow
                        try {
                            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
                            Write-Host "[OK] Politica establecida a RemoteSigned para CurrentUser." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "GPO bloquea cambios de politica de ejecucion persistentes." -ForegroundColor Red
                            Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Gray
                            Write-Host "Intentando habilitar temporalmente para este proceso..." -ForegroundColor Cyan
                            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
                            Write-Host "[OK] Politica establecida a Bypass para el proceso actual." -ForegroundColor Green
                        }
                    }
                }

                "11.2" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    Write-Host "Deshabilitando ejecucion remota y de scripts localmente..." -ForegroundColor Cyan
                    
                    # 1. Deshabilitar PSRemoting
                    try {
                        Write-Host "Deteniendo y deshabilitando servicio WinRM..." -ForegroundColor Gray
                        Disable-PSRemoting -Force -ErrorAction Stop
                        Write-Host "[OK] PSRemoting deshabilitado localmente." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "ADVERTENCIA: No se pudo deshabilitar PSRemoting localmente." -ForegroundColor Yellow
                        Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Gray
                    }

                    # 2. Configurar ExecutionPolicy a Restricted
                    try {
                        Write-Host "Estableciendo politica de ejecucion a Restricted (LocalMachine)..." -ForegroundColor Gray
                        Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope LocalMachine -Force -ErrorAction Stop
                        Write-Host "[OK] Politica establecida a Restricted para LocalMachine." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Restriccion detectada para LocalMachine. Intentando para CurrentUser..." -ForegroundColor Yellow
                        try {
                            Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser -Force -ErrorAction Stop
                            Write-Host "[OK] Politica establecida a Restricted para CurrentUser." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "GPO bloquea cambios de politica de ejecucion." -ForegroundColor Red
                            Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Gray
                        }
                    }
                }

                "11.3" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    Write-Host "Buscando componentes de RSAT localmente..." -ForegroundColor Cyan
                    try {
                        # Importar explícitamente Dism
                        Import-Module -Name Dism -ErrorAction SilentlyContinue

                        if (-not (Get-Command -Name Get-WindowsCapability -ErrorAction SilentlyContinue)) {
                            throw "El cmdlet 'Get-WindowsCapability' no está disponible en este equipo."
                        }

                        $capabilities = Get-WindowsCapability -Online | Where-Object { $_.Name -like "Rsat.*" -and $_.State -eq "NotPresent" }
                        if ($capabilities.Count -eq 0) {
                            Write-Host "Todos los componentes de RSAT ya estan instalados." -ForegroundColor Green
                        }
                        else {
                            Write-Host "Se encontraron $($capabilities.Count) componentes para instalar." -ForegroundColor Cyan
                            
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
                                        Write-Host "Instalado con éxito: $($cap.Name)" -ForegroundColor Green
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
                            Write-Host "Instalacion de RSAT completada." -ForegroundColor Green
                        }
                    }
                    catch {
                        Write-Host "Error al instalar RSAT localmente: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }

                "12" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    Write-Host "Por favor seleccione una sub-opcion especifica (12.1, 12.2 o 12.3)" -ForegroundColor Yellow
                }

                "12.1" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    $baseIP = "192.168.176."
                    $ultimoOcteto = Read-Host "Ingrese el ultimo octeto de la IP (192.168.176.XXX) o IP completa"
                    if ($ultimoOcteto -eq "") { 
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                    }
                    else {
                        $ipRemota = $ultimoOcteto
                        if ($ultimoOcteto -notmatch "\.") {
                            $ipRemota = $baseIP + $ultimoOcteto
                        }
                        
                        Write-Host "Habilitando ejecucion remota en $ipRemota..." -ForegroundColor Cyan
                        $process = Get-WmiObject -List -ComputerName $ipRemota -Class Win32_Process -ErrorAction SilentlyContinue
                        if ($process) {
                            $cmd = "powershell.exe -NoProfile -Command `"try { Enable-PSRemoting -SkipNetworkProfileCheck -Force } catch {}; try { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force } catch { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force }`""
                            $result = $process.Create($cmd)
                            if ($result.ReturnValue -eq 0) {
                                Write-Host "Comando de habilitacion enviado correctamente via WMI. Esperando 5 segundos..." -ForegroundColor Green
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
                                $arg = "\\$ipRemota -accepteula -s powershell.exe -NoProfile -Command `"try { Enable-PSRemoting -SkipNetworkProfileCheck -Force } catch {}; try { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force } catch { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force }`""
                                Start-Process -FilePath $psexecPath -ArgumentList $arg -Wait -NoNewWindow
                                Write-Host "Comando enviado via PsExec." -ForegroundColor Green
                            }
                            else {
                                Write-Host "ERROR: No se pudo conectar via WMI ni se encontro PsExec en C:\PSTools\PsExec.exe" -ForegroundColor Red
                            }
                        }
                    }
                }

                "12.2" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    $baseIP = "192.168.176."
                    $ultimoOcteto = Read-Host "Ingrese el ultimo octeto de la IP (192.168.176.XXX) o IP completa"
                    if ($ultimoOcteto -eq "") { 
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                    }
                    else {
                        $ipRemota = $ultimoOcteto
                        if ($ultimoOcteto -notmatch "\.") {
                            $ipRemota = $baseIP + $ultimoOcteto
                        }
                        
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
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    $baseIP = "192.168.176."
                    $ultimoOcteto = Read-Host "Ingrese el ultimo octeto de la IP (192.168.176.XXX), IP completa o Nombre de Equipo"
                    if ($ultimoOcteto -eq "") { 
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                    }
                    else {
                        # 1. Solicitar opcionalmente credenciales administrativas (locales o de dominio)
                        $cred = $null
                        $usu = ""
                        $claTexto = ""
                        $usarCred = Read-Host "¿Desea especificar credenciales de administrador (local o de dominio) para la conexion? (S/N) [N]"
                        if ($usarCred -eq "S" -or $usarCred -eq "s") {
                            $usu = Read-Host "Introduzca usuario (ej: gmsantacruz\usuario o .\administrador)"
                            if ($usu -ne "") {
                                $cla = Read-Host "Introduzca clave de usuario" -AsSecureString
                                $cred = New-Object System.Management.Automation.PSCredential ($usu, $cla)
                                # Convertir la contraseña a texto plano para PsExec
                                $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))
                            }
                        }

                        # Determinar si es IP o Hostname directamente
                        $targetMachine = ""
                        $ipRemota = ""
                        
                        if ($ultimoOcteto -match "^[a-zA-Z]") {
                            $targetMachine = $ultimoOcteto
                            Write-Host "Usando Nombre de Equipo proporcionado: $targetMachine" -ForegroundColor Green
                        }
                        else {
                            $ipRemota = $ultimoOcteto
                            if ($ultimoOcteto -notmatch "\.") {
                                $ipRemota = $baseIP + $ultimoOcteto
                            }
                            Write-Host "Direccion IP de destino: $ipRemota" -ForegroundColor Cyan
                            
                            Write-Host "Resolviendo nombre de equipo (Hostname) necesario para la conexion..." -ForegroundColor Cyan
                            try {
                                $sys = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ipRemota -ErrorAction Stop
                                $targetMachine = $sys.CSName
                                Write-Host "Nombre de equipo resuelto exitosamente via WMI: $targetMachine" -ForegroundColor Green
                            }
                            catch {
                                try {
                                    $targetMachine = [System.Net.Dns]::GetHostEntry($ipRemota).HostName
                                    Write-Host "Nombre de equipo resuelto via DNS: $targetMachine" -ForegroundColor Green
                                }
                                catch {
                                    Write-Host "ADVERTENCIA: No se pudo resolver la IP a un Nombre de Equipo automaticamente." -ForegroundColor Yellow
                                    $manualHost = Read-Host "Ingrese el NOMBRE DE EQUIPO (Hostname) del equipo remoto manualmente"
                                    if ($manualHost -ne "") {
                                        $targetMachine = $manualHost
                                    }
                                }
                            }
                        }
                        
                        if ([string]::IsNullOrEmpty($targetMachine)) {
                            Write-Host "ERROR: Se requiere un nombre de equipo para continuar." -ForegroundColor Red
                        }
                        else {
                            # 2. Definir el ScriptBlock a ejecutar
                            $scriptString = {
                                Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
                                Import-Module -Name Dism -ErrorAction SilentlyContinue

                                if (-not (Get-Command -Name Get-WindowsCapability -ErrorAction SilentlyContinue)) {
                                    throw "El cmdlet 'Get-WindowsCapability' no está disponible en este equipo."
                                }

                                # Gestion del servicio wuauserv
                                $originalStartType = $null
                                $wuauservHabilitado = $false
                                $serviceWMI = Get-WmiObject -Class Win32_Service -Filter "Name='wuauserv'"
                                if ($serviceWMI) {
                                    $originalStartType = $serviceWMI.StartMode
                                    if ($originalStartType -eq "Disabled") {
                                        Write-Output "Detectado que el servicio Windows Update (wuauserv) esta DESHABILITADO."
                                        Write-Output "Habilitandolo temporalmente en modo Manual para la instalacion..."
                                        $serviceWMI.ChangeStartMode("Manual") | Out-Null
                                        $wuauservHabilitado = $true
                                    }
                                }

                                try {
                                    Write-Output "Buscando componentes de RSAT..."
                                    $capabilities = Get-WindowsCapability -Online | Where-Object { $_.Name -like "Rsat.*" -and $_.State -eq "NotPresent" }
                                    if ($capabilities.Count -eq 0) {
                                        Write-Output "Todos los componentes de RSAT ya estan instalados."
                                    }
                                    else {
                                        Write-Output "Se encontraron $($capabilities.Count) componentes para instalar."
                                        
                                        # Bypass de WSUS
                                        $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
                                        $wsusBypassed = $false
                                        $originalUseWUServer = $null
                                        
                                        if (Test-Path $regPath) {
                                            try {
                                                $val = Get-ItemProperty -Path $regPath -Name "UseWUServer" -ErrorAction Stop
                                                if ($val -and $val.UseWUServer -eq 1) {
                                                    Write-Output "Detectado WSUS activo. Desactivando temporalmente..."
                                                    $originalUseWUServer = 1
                                                    Set-ItemProperty -Path $regPath -Name "UseWUServer" -Value 0 -Force -ErrorAction Stop
                                                    Restart-Service -Name "wuauserv" -Force -ErrorAction Stop
                                                    $wsusBypassed = $true
                                                }
                                            }
                                            catch {
                                                Write-Output "ADVERTENCIA: No se pudo configurar WSUS o reiniciar wuauserv: $($_.Exception.Message)"
                                            }
                                        }
                                        
                                        try {
                                            foreach ($cap in $capabilities) {
                                                Write-Output "Instalando $($cap.Name)..."
                                                try {
                                                    Add-WindowsCapability -Online -Name $cap.Name -ErrorAction Stop | Out-Null
                                                    Write-Output "Instalado: $($cap.Name)"
                                                }
                                                catch {
                                                    Write-Output "ERROR al instalar $($cap.Name): $($_.Exception.Message)"
                                                }
                                            }
                                        }
                                        finally {
                                            if ($wsusBypassed -and $originalUseWUServer -ne $null) {
                                                Write-Output "Restaurando configuracion original de WSUS..."
                                                Set-ItemProperty -Path $regPath -Name "UseWUServer" -Value $originalUseWUServer -Force -ErrorAction SilentlyContinue
                                                Restart-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
                                            }
                                        }
                                        Write-Output "Instalacion de RSAT completada."
                                    }
                                }
                                finally {
                                    if ($wuauservHabilitado -and $originalStartType -eq "Disabled") {
                                        Write-Output "Restaurando el estado DESHABILITADO del servicio Windows Update..."
                                        $serviceWMIRestore = Get-WmiObject -Class Win32_Service -Filter "Name='wuauserv'"
                                        if ($serviceWMIRestore) {
                                            $serviceWMIRestore.ChangeStartMode("Disabled") | Out-Null
                                        }
                                    }
                                }
                            }.ToString()

                            # 3. Decidir método de ejecución (PsExec vs Invoke-Command)
                            $psexecPath = "C:\PSTools\PsExec.exe"
                            if ((Test-Path $psexecPath) -and ($usu -ne "")) {
                                Write-Host "Iniciando instalacion remota via PsExec (Contexto SYSTEM) para evitar restricciones de WinRM..." -ForegroundColor Green
                                
                                # Convertir comando a Base64 para evitar problemas de escape de comillas
                                $bytes = [System.Text.Encoding]::Unicode.GetBytes($scriptString)
                                $encoded = [Convert]::ToBase64String($bytes)
                                
                                # Ejecución con PsExec
                                $argumentos = "\\$targetMachine -u `"$usu`" -p `"$claTexto`" -h -s powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
                                Start-Process -FilePath $psexecPath -ArgumentList $argumentos -Wait
                            }
                            else {
                                # Fallback a Invoke-Command si no hay PsExec o no se proporcionaron credenciales
                                Write-Host "Iniciando instalacion via Invoke-Command (WinRM)..." -ForegroundColor Yellow
                                if ($usu -ne "") {
                                    Write-Host "Nota: Si experimenta 'Acceso denegado', intente instalar PsExec en C:\PSTools\PsExec.exe para ejecución en contexto SYSTEM." -ForegroundColor Cyan
                                }
                                try {
                                    $sb = [ScriptBlock]::Create($scriptString)
                                    if ($cred -ne $null) {
                                        Invoke-Command -ComputerName $targetMachine -Credential $cred -ScriptBlock $sb -ErrorAction Stop
                                    }
                                    else {
                                        Invoke-Command -ComputerName $targetMachine -ScriptBlock $sb -ErrorAction Stop
                                    }
                                }
                                catch {
                                    Write-Host "ERROR al ejecutar Invoke-Command en $targetMachine." -ForegroundColor Red
                                    Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Gray
                                    Write-Host "Asegurese de usar credenciales con privilegios de Administrador en el equipo de destino." -ForegroundColor Yellow
                                }
                            }
                        }
                    }
                }

                "13" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                                        
                    Write-Host " "
                    Read-Host "Presione ENTER para continuar..."

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
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
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
