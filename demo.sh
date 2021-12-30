#!/bin/bash

FILE="demo.tar"
LOCATION="/tmp/demo"

function validar_directorio
{
   if [[ -d $LOCATION ]] || echo "El directorio existe"
}

validar_directorio