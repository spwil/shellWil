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
* **Hito Completado:** **Optimización de la Opción 100 (Captura de Pantalla Remota) en `subMenu25.ps1` con Autenticación Flexible (SSO / Caché de Memoria / Alternativas)**.
* **Cambios Clave Realizados:**
  1. **Autenticación Inteligente en Submenú 100 (Opción 1: PsExec):**
     - Se eliminó la obligación de digitar usuario y contraseña en cada captura individual.
     - **Modo 1 (Recomendado - SSO por defecto):** Con presionar <kbd>Enter</kbd> (o marcar `1`), utiliza de inmediato las credenciales de la sesión activa de Windows (`$env:USERDOMAIN\$env:USERNAME`) sin solicitar contraseña.
     - **Modo 2 (Caché en Memoria):** Si el operador introduce credenciales alternativas una vez, se guardan en la variable de sesión `$global:ShellCredencialCache` y se protegen de la limpieza de fin de ciclo en `finally`, permitiendo reutilizarlas en capturas subsiguientes con solo seleccionarlas.
     - **Modo 3 (Credenciales Alternativas):** Permite ingresar usuario de dominio o local (`.\Administrador`) y clave, guardándolas en memoria para la sesión activa.
  2. **Compatibilidad PsExec y WMI/CIM:**
     - En modo SSO, PsExec se invoca limpiamente sin los modificadores `-u` y `-p`, permitiendo que Windows herede el token de seguridad corporativo de forma transparente.
     - Si se usan credenciales alternativas, se enlaza automáticamente el recurso de red `\\$computerTarget\IPC$` con las credenciales explícitas para garantizar que la copia de scripts silenciosos a `\\$computerTarget\c$\Windows\Temp` y la detección de sesión interactiva (`explorer.exe`) no fallen por acceso denegado.
  3. **Compilación y verificación:**
     - Sintaxis validada en todos los módulos con AST Parser (0 errores).
     - Compilación exitosa con [build.ps1](build.ps1) generando el binario [ShellSW.bat](ShellSW.bat).

---

## 📍 3. ¿En qué punto nos hemos quedado?
La optimización de la **Opción 100: Captura de Pantalla Remota** en [src/subMenu25.ps1](src/subMenu25.ps1) está 100% implementada y compilada en [ShellSW.bat](ShellSW.bat).

* **Estado de Git:** Rama `main`, cambios listos en `ShellSW.bat`, `src/subMenu25.ps1` y `ESTADO_PROYECTO.md`.
* **Próxima acción técnica:** Probar la captura remota en `ShellSW.bat` -> opción `25` -> opción `100` -> opción `1`.
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
- [ ] Probar flujo completo de bajada en la PC secundaria mediante la opción `1011`.
- [ ] Revisión periódica de submódulos de administración según requerimientos del equipo de Helpdesk.
