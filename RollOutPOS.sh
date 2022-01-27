#!/bin/sh

set +x

# -------------------------------------------
# Declaramos variables globales
DirInstalador='/home/reg/gd90_transport'
DirRoll="RollOutPOS"
ArchTar="RollOutPOS.tar"
ArchAct="ActualizaPOS.sh"
LogFile="LogCopia"
FECHAHOY=$(date +%d-%m-%Y-%H:%M:%S)


echo "-------------------------------------------"
echo "Ejecutando RollOutPOS.sh"
# cd $DirInstalador


# -------------------------------------------
# Eliminacion de Directorio RolloutPOS existente
function elimina_RollOutPOS_Antiguo
{
        ls -l $DirInstalador/$DirRoll > /dev/null 2>&1
        if [ "$(echo $?)" == "0" ]; 
        then
                rm -rf "$DirInstalador/$DirRoll"
                echo "El directorio $DirInstalador/$DirRoll fue eliminado" >> $DirInstalador/$LogFile-$FECHAHOY".txt"
                sleep 2
        fi
}


# -------------------------------------------
# validacion de existencia y descomprimido del archivo RolloutPOS.tar
function validar_archivo_tar
{
        ls -l $DirInstalador/$ArchTar > /dev/null 2>&1
        # if [[ ! -f "$DirInstalador/$ArchTar" ]];
        if [ "$(echo $?)" == "0" ];
        then
            tar xvf $DirInstalador/$ArchTar -C $DirInstalador
            echo "El archivo $ArchTar a sido descomprimido correctamente!" >> $DirInstalador/$LogFile-$FECHAHOY".txt"
        else
            echo "El archivo $ArchTar no existe. No hay actualizaciones por ejecutar!" >> $DirInstalador/$LogFile-$FECHAHOY".txt"
            exit
        fi
}


# -------------------------------------------
# backup del archivo RolloutPOS.tar
function renombrar_archivo_tar
{
        if [ -f "$DirInstalador/$ArchTar" ];
        then
            mv $DirInstalador/$ArchTar $DirInstalador/$ArchTar-$FECHAHOY
            echo "El archivo $ArchTar a sido renombrado por $ArchTar-$FECHAHOY!" >> $DirInstalador/$LogFile-$FECHAHOY".txt"
        else
            echo "El archivo $ArchTar no existe!" >> $DirInstalador/$LogFile-$FECHAHOY".txt"
        fi
}


# -------------------------------------------
# cambio de permisos de archivo ActualizaPOS.sh
function permisos_ActualizaPOS
{
        if [[ ! -f "$DirInstalador/$DirRoll/$ArchAct" ]];
        then
            echo "El archivo $ArchAct no existe!"
            echo "El archivo $ArchAct no existe!" >> $DirInstalador/$LogFile-$FECHAHOY".txt"
            exit
        else
            chmod 746 $DirInstalador/$DirRoll/$ArchAct
            echo "Los permisos del archivo $ArchAct se actualizaron correctamente!"
            echo "Los permisos del archivo $ArchAct se actualizaron correctamente!" >> $DirInstalador/$LogFile-$FECHAHOY".txt"
        fi
}


# -------------------------------------------
# ejecutando archivo ActualizaPOS.sh
function ejecuta_ActualizaPOS
{
        if [[ ! -f "$DirInstalador/$DirRoll/$ArchAct" ]];
        then
            echo "El archivo $ArchAct no pudo ejecutarse!"
            echo "El archivo $ArchAct no pudo ejecutarse!" >> $DirInstalador/$LogFile-$FECHAHOY".txt"
            exit
        else
            echo "Ejecutando $ArchAct"
            echo "Ejecutando $ArchAct" >> $DirInstalador/$LogFile-$FECHAHOY".txt"
            sh $DirInstalador/$DirRoll/$ArchAct
            exit
        fi
}

# -------------------------------------------
# llamamos a las funciones
elimina_RollOutPOS_Antiguo
validar_archivo_tar
renombrar_archivo_tar
permisos_ActualizaPOS
ejecuta_ActualizaPOS
