#!/bin/bash

# Criador: Alan Barros
# Data: 02/02/2017
# Objetivo: Compactar e limpar log corrente
# Modo de usar: compacta_corrente.sh [arquivo a ser compactado]
# Versão 2.3 (07/05/2017) Para detalhes da versão digite: ~$: ./compacta_corrente.sh --help
# Versão 2.4 (28/12/2017) Opção para escolher cat para compactação o arquivo inteiro ou tail para compactar 10% do arquivo.

# Recebe argumento na variável
_logCorrente=${1}
_dirTmp=${2}

# Testa os argumentos passados (Trava anti-falha)

if [ -z ${_logCorrente} ]; then # Verifica se passou um arquivo como arguento
	echo "Insira um arquivo como argumento, use o parametro --help para ajuda";
	exit 0;
else
	if [ ! -f ${_logCorrente} ]; then
		if [ ${1}=="--help" ]; then
			echo " ################################################################################################"
			echo " # Execute o script do mesmo local onde o log corrente está: 					#"
			echo " # EX: user@ubuntu:/var/log$ ~/compacta_corrente.sh messages /dev/shm				#"
			echo " # Sintaxe: compacta_corrente.sh [ arquivo_para_compactar ] [ diretorio_destino (opcional) ]	#"
			echo " # 												#"
			echo " # O que o script faz: Troca permissão do arquivo de log corrente; compacta o mesmo para o 	#"
			echo " # diretório HOME do usuário atual ou para o que foi passado no parametro $'2'; move o  arquivo	#"
			echo " # para o seu diretório original (.) em seguida volta as permissões originais. 			#"
			echo " # Por fim, será exibido um log das ações. Arquivo compactado: arquivo_AAAA-MM-DD_HHmm.gz	#"
			echo " ################################################################################################"
		exit 0;
		fi
		echo "Arquivo ${_logCorrente} não é um arquivo válido, use o parametro --help para ajuda";
		exit 0;
	fi
fi

_local=$(echo ${_logCorrente} | grep "/" | wc -l) # Conta as / no nome do arquivo

if [ ${_local} -ne 0 ]; then # Bloqueia se houver barras no nome do arquivo
	echo "Esteja no mesmo diretóro do arquivo, use o parametro --help para ajuda"
	exit 0;
fi

if [ -z $_dirTmp ]; then #Testa se existe o segundo parametro para destino do backup temporário.
        DIR_BKP=$HOME
else
        if [ -d $_dirTmp ]; then
                DIR_BKP=$_dirTmp
        else
                echo "O parametro deve ser vazio um diretório válido, use o parametro --help para ajuda"
        fi
fi

#Define data
data=$(date +%Y-%m-%d_%H%M)

# Cria e/ou verifica diretório do log
if [ ! -d "$HOME/log" ]; then mkdir ~/log; fi

#Cria váriaveis padrão úteis
_dirLogCorrente=$(echo ${PWD} | sed 's/ /\\ /g')
_camAbsLog=${PWD}/${_logCorrente}
COM_EXIBICAO='cat'
BKP=${_logCorrente}_$data.gz
LOG=~/log/compactacao_${_logCorrente}_$data.log


#Funções

function muda_comando() {
    if [ ${1} == "tail" ]; then
        echo "Aguarde... Estamos contando as linhas do arquivo :D"
        tot_linhas=$(wc -l ${_camAbsLog} | cut -d " " -f 1)
        comp_linhas=$(echo "$tot_linhas * 0.10" | bc | cut -d . -f 1)
        #linhas=10000
        COM_EXIBICAO="tail -${comp_linhas}"
        echo "O arquivo contém ${tot_linhas} linhas, compactando apenas as últimas ${comp_linhas}" >> ${LOG}
    fi
    
    #Altera váriáveis padrão
    ARQ_EXIBICAO=$(echo ${COM_EXIBICAO} | sed 's/ //g')
    BKP=${_logCorrente}_${ARQ_EXIBICAO}_$_$data.gz
}

function escolhe_compactacao() {
        echo "Deseja utilizar qual tipo de compactação?"
        echo "1 - cat-gzip (padrao - arquivo inteiro)"
        echo "2 - tail-gzip (10% do arquivo original)"
        read tipo_compactacao
        case ${tipo_compactacao} in
            1)
                echo "Utilizando cat e gzip (compactando todo o arquivo)"
                ;;
            2)
                muda_comando tail
                ;;
            *)
                echo "Utilizando cat e gzip (compactando todo o arquivo)"
        esac
}

function compacta() { # [Arquivo para compactar] [Destino da compactação]
	echo "Aguarde, compactando e zerando o arquivo '${1}'"
	$(sudo ${COM_EXIBICAO} "${1}" | gzip -9v - > ${2} && sudo cat /dev/null > "${1}" && sudo mv ${2} $PWD)
	echo -e "\n$(date +%H:%M:%S) - Comando compactação:\nsudo ${COM_EXIBICAO} '${1}' | gzip -9v - > '${2}' && sudo cat /dev/null > '${1}' && sudo mv ${2} $PWD\n" >> ${LOG}
}

function permissao() { # [Arquivo que vai mudar permissão] [Permissão em decimal]
	$(sudo chmod ${2} "${1}")
	listagem=$(ls -lhart "${1}" | cut -d " " -f 1)
	echo "$(date +%H:%M:%S) - As permissões do arquivo '${1}' foram alteradas de ${PERMISSAO} para ${2}" >> ${LOG}
}

function ver_permissoes() {
	#Verifica e armazena permissão do arquivo
	PERM=$(ls -lhart "${_camAbsLog}" | cut -c 2-10)

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
}

#Verifica permissões
ver_permissoes

#Armazena permissão original
originalPerm=${PERMISSAO}

#Altera permissão do arquivo
#permissao "${_dirLogCorrente}/${_logCorrente}" 777
permissao "${_camAbsLog}" 777

#Tipo de compactação
escolhe_compactacao

#Compacta o arquivo deixando o original vazio
compacta "${_camAbsLog}" ${DIR_BKP}/${BKP}

#Verifica permissões
ver_permissoes

#Voltando permissao
permissao "${_camAbsLog}" ${originalPerm}

#Exibe Relatório
echo " "; echo "Relatório da compactação do log"
cat ${LOG}
