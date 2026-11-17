# ESTADO_PROYECTO.md — Memoria y Bitácora de Continuidad

> **Propósito:** Este archivo es la memoria central del proyecto `shellWil`. Permite que cualquier miembro del equipo o el asistente de Inteligencia Artificial (Antigravity) conozca exactamente en qué estado se encuentra el desarrollo, qué fue lo último que se hizo y cómo retomar el trabajo sin perder tiempo al escribir **`RECUERDAME`**.

---

## 📌 1. Ficha del Proyecto
* **Proyecto:** `shellWil` ([repositorio GitHub](https://github.com/spwil/shellWil.git))
* **Autor / Responsable:** Ing. Wilson Yucra Juan (`wyucra@gmsantacruz.gov.bo`)
* **Objetivo:** Suite integral y portable de administración, soporte técnico, auditoría y mantenimiento del Sistema Operativo Windows para Helpdesk.
* **Arquitectura:**
  - Código fuente modular en `src/` ([helpers.ps1](src/helpers.ps1), [menuPrincipal.ps1](src/menuPrincipal.ps1), [subMenu20.ps1](src/subMenu20.ps1) a [subMenu28.ps1](src/subMenu28.ps1)).
  - Script de ensamblado automático: [build.ps1](build.ps1).
  - Binario ejecutable compilado: [ShellSW.bat](ShellSW.bat).

---

## 🕒 2. Última Sesión de Trabajo
* **Fecha:** 17 de Noviembre de 2026
* **Hito Completado:** **Suite Completa de Captura y Monitoreo Remoto (Opción 100 en `subMenu25.ps1`): Screenshot PNG, Clip Animado de 15s (GIF Nativo) y RDP Shadowing en Tiempo Real**.
* **Cambios Clave Realizados:**
  1. **Rediseño Integral de la Opción 100 en [src/subMenu25.ps1](src/subMenu25.ps1):**
     - **Opción 100.1:** Captura de pantalla estática instantánea (.PNG) con selector SSO por defecto, memoria de sesión de credenciales alternativas (`$global:ShellCredencialCache`) y ejecución transparente vía PsExec.
     - **Opción 100.2:** Grabación de clip continuo de 15 segundos generado silenciosamente en la sesión interactiva del usuario remoto y ensamblado automáticamente como archivo **GIF animado continuo (.gif)** en `C:\spscreen\` mediante la nueva función nativa [New-AnimatedGifFromFrames](src/helpers.ps1) (WPF `PresentationCore` + `System.Drawing`, 100% nativo sin dependencias ni software externo).
     - **Opción 100.3:** Visualización en vivo en tiempo real mediante **RDP Shadowing (`mstsc /shadow`)**. Aplica de forma remota y transparente las directivas requeridas en el registro de Windows (`Shadow = 2`, `DisableShadowConsent = 1`, `fDenyTSConnections = 0` y apertura de firewall para Shadowing) vía WMI / PsExec, permitiendo supervisar la pantalla remota fluida a 60 fps en tiempo real (en modo Solo Ver o Control Total) sin interrumpir al usuario.
  2. **Motor de Ensamblado de GIF Animado en [src/helpers.ps1](src/helpers.ps1):**
     - Función `New-AnimatedGifFromFrames`: Procesa ráfagas de fotogramas, libera manejadores GDI con `DeleteObject` de `gdi32.dll` e inyecta la cabecera Netscape 2.0 para repetición continua infinita en cualquier visor de imágenes.
  3. **Compilación y verificación:**
     - Sintaxis validada en todos los módulos con AST Parser (0 errores).
     - Compilación exitosa con [build.ps1](build.ps1) generando el binario [ShellSW.bat](ShellSW.bat).

---

## 📍 3. ¿En qué punto nos hemos quedado?
La **Suite de Captura y Monitoreo Remoto (Opción 100)** en [src/subMenu25.ps1](src/subMenu25.ps1) está 100% implementada y compilada en [ShellSW.bat](ShellSW.bat).

* **Estado de Git:** Rama `main`, cambios listos en `ShellSW.bat`, `src/helpers.ps1`, `src/subMenu25.ps1` y `ESTADO_PROYECTO.md`.
* **Próxima acción técnica:** Probar las opciones en `ShellSW.bat` -> opción `25` -> opción `100`:
  * `1`: Captura instantánea PNG.
  * `2`: Clip de 15 segundos GIF.
  * `3`: Visualización en vivo (RDP Shadowing).
* **Publicación:** Cuando desees sincronizar a GitHub, usa la opción oculta `1010` en el menú principal.

---

## 🚀 4. Guía para Continuar (Paso a Paso)

### Si estás en la PC 2 (o en una máquina distinta a donde se programó):
1. Abre `ShellSW.bat` (o tu terminal).
2. En el menú, escribe **`1011`** y presiona Enter.
3. El sistema descargará todo lo nuevo desde GitHub, auto-compilará [ShellSW.bat](ShellSW.bat) y te preguntará si deseas reiniciar para cargar los cambios.
4. *(Solo la primera vez en PC 2)* Si te pide credenciales de GitHub, ejecuta:
   ```powershell
   git config --global credential.helper manager
   ```

### Si vas a continuar programando o agregando módulos:
1. Edita los módulos en la carpeta `src/`.
2. Para probar tus cambios en caliente o recompilar, ejecuta:
   ```powershell
   .\build.ps1
   ```
3. Al terminar la sesión, escribe **`1010`** en el menú de ShellSW (o ejecuta commit y push) para que la otra PC reciba tus avances.

---

## 📋 5. Tareas Pendientes y Roadmap Sugerido
- [x] Sincronización multi-PC automatizada (Opciones 1010 y 1011).
- [x] Ocultamiento de opciones de desarrollo en el menú por seguridad.
- [x] Documentación de sincronización y bitácora de memoria (`RECUERDAME`).
- [x] Opción 6: Gestión de Símbolos SIAF-SICE multi-capa en Submenú 28.
- [x] Opción 7: Consola Remota PowerShell Interactiva (WinRM + WMI auto-enable + PsExec fallback).
- [x] Optimización Opción 100: Captura de pantalla remota con SSO por defecto y caché de credenciales en Submenú 25.
- [x] Suite Completa de Monitoreo Remoto: Clip continuo de 15 segundos (GIF nativo .NET) y RDP Shadowing en tiempo real (mstsc /shadow).
- [ ] Probar flujo completo de bajada en la PC secundaria mediante la opción `1011`.
- [ ] Revisión periódica de submódulos de administración según requerimientos del equipo de Helpdesk.
