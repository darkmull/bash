#!/bin/bash

FILE="demo.tar"
LOCATION="/tmp/demo"

function validar_directorio
{
    [[ -d $LOCATION ]] || echo "El directorio existe"
}

validar_directorio