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
