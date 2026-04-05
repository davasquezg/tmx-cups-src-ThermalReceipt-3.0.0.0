# Driver CUPS para Impresoras Térmicas Epson TM (ESC/POS)

Driver Linux CUPS para la familia de impresoras térmicas Epson TM serie, basado en el código fuente oficial de Epson con actualizaciones de compatibilidad para Ubuntu 25.10 y CUPS 3.x.

## Modelos compatibles

| Modelo | Resolución | PPD incluido | Estado |
|--------|-----------|--------------|--------|
| TM-T88V | 180 dpi | `tm-t88v-rastertotmtr-180.ppd` | ✅ Verificado (USB + UB-E04) |
| TM-T88VI | 180 dpi | `tm-t88vi-rastertotmtr-180.ppd` | ✅ Compatible |
| TM-T88VII | 180 dpi | `tm-t88vii-rastertotmtr-180.ppd` | ✅ Compatible |
| TM-T70II (ANK) | 180 dpi | `tm-t70ii-rastertotmtr-180.ppd` | ✅ Compatible |
| TM-H6000V | 180 dpi | `tm-ba-thermal-rastertotmtr-180.ppd` | ✅ Compatible |
| TM-m30 | 203 dpi | `tm-m30-rastertotmtr-203.ppd` | ✅ Compatible |
| TM-m30II | 203 dpi | `tm-m30ii-rastertotmtr-203.ppd` | ✅ Compatible |
| TM-T20III | 203 dpi | `tm-t20iii-rastertotmtr-203.ppd` | ✅ Compatible |
| TM-m10 | 203 dpi | `tm-ba-thermal-rastertotmtr-203.ppd` | ✅ Compatible |
| Genérico 180dpi | 180 dpi | `tm-ba-thermal-rastertotmtr-180.ppd` | ✅ Fallback |
| Genérico 203dpi | 203 dpi | `tm-ba-thermal-rastertotmtr-203.ppd` | ✅ Fallback |

## Compatibilidad de sistema

| Ubuntu | CUPS | GCC | Estado |
|--------|------|-----|--------|
| 25.10 (Questing Quokka) | 2.4.x | 14.x | ✅ Verificado |
| 24.04 LTS | 2.4.x | 13.x | ✅ Compatible |
| 22.04 LTS | 2.3.x | 11.x | ✅ Compatible |
| CUPS 3.x (futuro) | 3.x | cualquiera | ✅ Dual-path implementado |

## Dependencias

```bash
sudo apt install cmake build-essential libcups2-dev libcupsimage2-dev
```

## Compilar e instalar

```bash
chmod +x build.sh install.sh
./build.sh
sudo ./install.sh
```

## Configurar impresora

### Conexión USB
```bash
sudo lpadmin -p TM-T88V \
  -v usb://EPSON/TM-T88V \
  -P /usr/share/cups/model/EPSON/tm-t88v-rastertotmtr-180.ppd \
  -E
```

### Conexión de red — UB-E04 / Ethernet (socket RAW puerto 9100)
```bash
sudo lpadmin -p TM-T88V \
  -v socket://192.168.1.100:9100 \
  -P /usr/share/cups/model/EPSON/tm-t88v-rastertotmtr-180.ppd \
  -E
```

> **Nota UB-E04:** Para configurar la interfaz de red UB-E04, acceder a la web UI de la tarjeta (`http://192.168.192.168`, usuario/clave: `epson/epson`). Cambiar el switch DSW2-8 de OFF a ON para habilitar la tarjeta. Asignar IP estática según la red local.

### Impresión de prueba
```bash
# Impresión de texto
lpr -o media=RP80x200 -P TM-T88V /ruta/a/archivo.pdf

# Con opciones de papel
lpr -o media=RP80x200 \
    -o TmxPaperCut=CutPerJob \
    -o TmxPaperReduction=Bottom \
    -P TM-T88V archivo.pdf
```

## Opciones de impresión disponibles

| Opción PPD | Valores | Descripción |
|---|---|---|
| `TmxPaperReduction` | `Off`, `Top`, `Bottom`, `Both` | Reducción de márgenes en blanco |
| `TmxBuzzerAndDrawer` | `NotUsed`, `InternalBuzzer`, `ExternalBuzzer`, `OpenDrawer1`, `OpenDrawer2` | Buzzer y apertura de caja |
| `TmxPaperCut` | `NoCut`, `CutPerJob`, `CutPerPage` | Control de corte de papel |
| `PageSize` | `RP80x200`, `RP80x2000`, `RP58x200`, `RP58x2000` | Tamaño de papel |

## Arquitectura del driver

El filtro `rastertotmtr` es un filtro CUPS estándar que:
1. Recibe datos de raster CUPS (`application/vnd.cups-raster`)
2. Los convierte a comandos ESC/POS (GS v 0 — raster bit image)
3. Los envía directamente al dispositivo (USB o socket de red)

Compatible con CUPS 2.x (usando PPD para parámetros) y CUPS 3.x (leyendo opciones desde la línea de comandos).

## Historial de cambios

Ver [changelog.md](changelog.md).

## Licencia

GNU General Public License v2. Copyright (C) Seiko Epson Corporation 2019.
