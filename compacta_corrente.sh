#!/bin/bash

# Criador: Alan Barros
# Data: 02/02/2017
# Objetivo: Compactar e limpar log corrente
# Modo de usar: compacata_corrente.sh [arquivo a ser compactado]
# Versão 0.2

# Recebe argumento na variável
ARG1=${1}
echo " "; echo "######### COMPACTA ARQUIVO #############"

# Testa se foi enviado argumento e se é um arquivo de ficheiro
if [ -z ${ARG1} ]; then
	echo "-- Insira um arquivo como argumento";
	exit 0;
else
	if [ -f ${ARG1} ]; then
		echo "-- Arquivo ${ARG1} é válido";
	else
		echo "-- Arquivo ${ARG1} é inválido";
		exit 0;
	fi
fi

#Define data
data=$(date +%Y-%m-%d)

#Cria váriaveis úteis
PWD=$(pwd)
WAY=${PWD}/${ARG1}
BKP=${ARG1}_$data.gz 
LOG=~/log/compactacao_${ARG1}_$data.log

#Funções

function compacta() { ## [Arquivo para compactar] [Destino da compactação]
	echo "Aguarde, compactando e zerando arquivo ${1}"
	$(sudo cat ${1} | gzip -9v - > ${2} && sudo cat /dev/null > ${1})
	echo "$(date +%H:%M:%S) - Comando utilizado: sudo cat ${1} | gzip -9v - > ${2} && sudo cat /dev/null > ${1}" >> ${LOG}
}

function permissao() { ## [Arquivo que vai mudar permissão] [Permissão em decimal]
	$(sudo chmod ${2} ${1})
	listagem=$(ls -lhart ${1} | cut -d " " -f 1)
	echo "Permissão alterada para ${listagem}"
	echo "$(date +%H:%M:%S) - Permissão do arquivo ${1} alterada para ${2}" >> ${LOG}
}

#Verifica e armazena permissão do arquivo
PERM=$(ls -lhart ${WAY} | cut -c 2-10)

cnt=1
while [ $cnt -le 9 ]
do
	VALOR[$cnt]=$(echo ${PERM} | cut -c $cnt)
	if [ ${VALOR[$cnt]} == "r" ]; then
                 NUM[$cnt]=4;
        elif [ ${VALOR[$cnt]} == "w" ]; then
                NUM[$cnt]=2;
        elif [ ${VALOR[$cnt]} == "x" ]; then
                NUM[$cnt]=1;
        else
                NUM[$cnt]=0;
        fi
	
	let cnt++
done

let P_OWN=${NUM[1]}+${NUM[2]}+${NUM[3]}
let P_GRP=${NUM[4]}+${NUM[5]}+${NUM[6]}
let P_OTR=${NUM[7]}+${NUM[8]}+${NUM[9]}

PERMISSAO=${P_OWN}${P_GRP}${P_OTR}

# Cria e/ou verifica diretório do log
if [ ! -d "$HOME/log" ]; then mkdir ~/log; fi

#Exibe permissão original
echo "Arquivo ${WAY} com permissão ${PERMISSAO}" >> ${LOG}

#Altera permissão do arquivo
permissao ${WAY} 777

#Compacta o arquivo deixando o original vazio
compacta ${WAY} ~/${BKP}

#Voltando permissao
permissao ${WAY} ${PERMISSAO}

#Exibe Relatório
echo " "; echo "Relatório da compactação do log"
cat ${LOG}
