#!/bin/sh
# install.sh — EPSON TM series CUPS driver installer
# Soporta instalación clásica (deb) y CUPS snap (Ubuntu 25.10+)

echo "EPSON TM series CUPS driver installer"
echo "---------------------------------------"
echo ""

ROOT_UID=0

if [ 0 -ne "$(id -u)" ]
then
    echo "This script requires root user access."
    echo "Re-run as: sudo ./install.sh"
    exit 1
fi

# Verificar que el binario exista
if [ ! -f ./build/rastertotmtr ]
then
    echo "ERROR: ./build/rastertotmtr not found."
    echo "Please run ./build.sh first."
    exit 1
fi

INSTALL=/usr/bin/install

# ─────────────────────────────────────────────────────────────────────────────
# Detectar si CUPS está instalado como snap (Ubuntu 25.10+)
# ─────────────────────────────────────────────────────────────────────────────
CUPS_IS_SNAP=0
if snap list cups >/dev/null 2>&1; then
    CUPS_IS_SNAP=1
fi

if [ "$CUPS_IS_SNAP" = "1" ]; then
    echo "[INFO] CUPS snap detectado"

    # El snap de CUPS expone sus directorios en rutas del sistema a través de
    # bind mounts. El filtro debe instalarse en la ruta del host que el snap
    # mapea a su ServerBin interno.
    # La ruta canónica para filtros del usuario en CUPS snap es:
    #   /var/snap/cups/common/etc/cups/  (configuración)
    # Sin embargo el snap NO permite añadir filtros externos al squashfs.
    #
    # SOLUCIÓN CORRECTA para CUPS snap:
    # El snap tiene un directorio para PPDs de usuario:
    #   /var/snap/cups/current/etc/cups/ppd/  — NO, eso es colas
    # Los PPDs adicionales del usuario van en:
    #   cups.lpadmin -p ... -P /ruta/al/ppd  (los copia internamente)
    #
    # El filtro rastertotmtr debe estar disponible para el snap en:
    #   /usr/lib/cups/filter/   — el snap hace bind mount de /usr/lib/cups
    #                             hacia su ServerBin en la mayoría de sistemas
    # En Ubuntu 25.10 con CUPS snap, la ruta accesible es:
    #   /usr/lib/cups/filter/   (el snap tiene acceso a esta ruta del host)

    FILTERDIR=/usr/lib/cups/filter
    PPDDIR=/usr/share/cups/model/EPSON

    echo "[INFO] Rutas para CUPS snap:"
    echo "       FILTERDIR = $FILTERDIR"
    echo "       PPDDIR    = $PPDDIR"
    echo ""
    echo "[AVISO] Con CUPS snap, el filtro se instala en $FILTERDIR"
    echo "        Si CUPS snap no lo encuentra, usa 'cups.lpadmin' en lugar de 'lpadmin'"
    echo "        y agrega la impresora desde http://localhost:631"
    echo ""
else
    echo "[INFO] CUPS clásico (deb) detectado"

    # ─────────────────────────────────────────────────────────────────────────
    # Detectar rutas desde cupsd.conf (instalación clásica)
    # ─────────────────────────────────────────────────────────────────────────
    CUPS_CONF=/etc/cups/cupsd.conf

    if [ ! -f "$CUPS_CONF" ]; then
        echo "[WARN] No se encontró $CUPS_CONF — usando rutas por defecto"
        FILTERDIR=/usr/lib/cups/filter
        PPDDIR=/usr/share/cups/model/EPSON
    else
        SERVERROOT=$(grep '^ServerRoot' "$CUPS_CONF" | awk '{print $2}')
        SERVERBIN=$(grep '^ServerBin' "$CUPS_CONF" | awk '{print $2}')
        DATADIR=$(grep '^DataDir' "$CUPS_CONF" | awk '{print $2}')

        if [ -z "$FILTERDIR" ]; then
            if [ -z "$SERVERBIN" ]; then
                FILTERDIR=/usr/lib/cups/filter
            elif [ "${SERVERBIN#/}" != "$SERVERBIN" ]; then
                FILTERDIR=$SERVERBIN/filter
            else
                FILTERDIR=$SERVERROOT/$SERVERBIN/filter
            fi
        fi

        if [ -z "$PPDDIR" ]; then
            if [ -z "$DATADIR" ]; then
                PPDDIR=/usr/share/cups/model/EPSON
            elif [ "${DATADIR#/}" != "$DATADIR" ]; then
                PPDDIR=$DATADIR/model/EPSON
            else
                PPDDIR=$SERVERROOT/$DATADIR/model/EPSON
            fi
        fi
    fi

    echo "       FILTERDIR = $FILTERDIR"
    echo "       PPDDIR    = $PPDDIR"
    echo ""
fi

# ─────────────────────────────────────────────────────────────────────────────
# Instalar filtro
# ─────────────────────────────────────────────────────────────────────────────
echo "Installing filter driver ..."
$INSTALL -d "$FILTERDIR"
$INSTALL -m 755 -s ./build/rastertotmtr "$FILTERDIR/rastertotmtr"
echo "  -> $FILTERDIR/rastertotmtr"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Instalar PPDs
# ─────────────────────────────────────────────────────────────────────────────
echo "Installing PPD files ..."
$INSTALL -m 755 -d "$PPDDIR"
for ppd_file in ./ppd/*.ppd; do
    $INSTALL -m 644 "$ppd_file" "$PPDDIR/"
    echo "  -> $PPDDIR/$(basename "$ppd_file")"
done
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Recargar CUPS
# ─────────────────────────────────────────────────────────────────────────────
echo "Restarting CUPS ..."
if [ "$CUPS_IS_SNAP" = "1" ]; then
    # Para el snap de CUPS, la forma correcta es snap restart
    snap restart cups 2>/dev/null || true
    # También intentar via systemctl por si está activo el socket
    systemctl reload cups 2>/dev/null || systemctl restart cups 2>/dev/null || true
elif command -v systemctl >/dev/null 2>&1; then
    systemctl reload cups 2>/dev/null || systemctl restart cups 2>/dev/null
elif [ -x /etc/init.d/cups ]; then
    /etc/init.d/cups restart
elif [ -x /etc/init.d/cupsys ]; then
    /etc/init.d/cupsys restart
else
    echo "  [WARN] No se pudo reiniciar CUPS automáticamente"
fi
echo ""

echo "Installation Completed"
echo ""
echo "─────────────────────────────────────────────────────────────"
echo " Para agregar la TM-T88V por red (UB-E04):"
echo ""
if [ "$CUPS_IS_SNAP" = "1" ]; then
    echo "   sudo cups.lpadmin -p TM-T88V \\"
    echo "     -v socket://IP_DE_LA_IMPRESORA:9100 \\"
    echo "     -P $PPDDIR/tm-t88v-rastertotmtr-180.ppd -E"
    echo ""
    echo "   O bien desde la interfaz web: http://localhost:631"
    echo ""
    echo " NOTA: Con CUPS snap, usa 'cups.lpadmin' y 'cups.lpstat'"
    echo "       en lugar de los comandos normales lpadmin/lpstat"
else
    echo "   sudo lpadmin -p TM-T88V \\"
    echo "     -v socket://IP_DE_LA_IMPRESORA:9100 \\"
    echo "     -P $PPDDIR/tm-t88v-rastertotmtr-180.ppd -E"
fi
echo ""
echo " Para agregar la TM-T88V por USB:"
if [ "$CUPS_IS_SNAP" = "1" ]; then
    echo "   sudo cups.lpadmin -p TM-T88V \\"
else
    echo "   sudo lpadmin -p TM-T88V \\"
fi
echo "     -v usb://EPSON/TM-T88V \\"
echo "     -P $PPDDIR/tm-t88v-rastertotmtr-180.ppd -E"
echo "─────────────────────────────────────────────────────────────"
echo ""
