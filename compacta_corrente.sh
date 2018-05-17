#!/bin/bash

# Criador: Alan Barros
	# Data: 02/02/2017
	# Objetivo: Compactar e limpar log corrente
	# Modo de usar: compacta_corrente.sh [arquivo a ser compactado]
	# Versão 3.1 (12/02/2018) O parametro --tail agora aceita valores em Porcentagem. Exemplo: --tail=30% ou as linhas diretamente exemplo --tail=1000
	# Versão 3.0 (09/02/2018) Código reescrito e simplificado, removida função de cálculo de tamanho, menu de escolha, agora para escolher compactar via bzip2 use o parametro --bz em qualquer posição, para usar tail use o parametro --tail=-100 sendo que é preciso informar o numero negativo de linha que deseja, função de teste implementada, possibilidade de usar o script com o comando find implementada.
	# Versão 2.7 (07/02/2018) Menu compactação com suporte a bzip2 adicionado.
	# Versão 2.6 (07/02/2018) Adicionada função para analisar tamanho: ~/compacta_corrente.sh [-dir ou -arq]
	# Versão 2.5 (30/12/2017) Correção do bug compactação com tail e arquivo menor que 10 linhas, script foi melhor comentado.
	# Versão 2.4 (28/12/2017) Opção para escolher cat para compactação o arquivo inteiro ou tail para compactar 10% do arquivo.
	# Versão 2.3 (07/05/2017) Para detalhes da versão digite: ~$: ./compacta_corrente.sh --help
versao="3.1 (12/02/2018)"
#################### DEFINIÇÃO DE VARIÁVEIS #######################

parametros=${#} # Conta os argumentos

# Sai caso haja mais de 3 ou menos de 1 parametro
if [[ ${parametros} -gt 3 ]]; then 
	echo "${0}: São permitidos apenas 3 parametros, use --help para ajuda"
	exit 0
	elif [[ ${parametros} -lt 1 ]]; then
	echo "${0}: É preciso ao menos 1 parametro, use --help para ajuda"
fi

for x in ${@} # Organiza os argumentos 
	do
	case ${x} in
		"--temp="*)
			dirTemp=`echo ${x} | cut -d "=" -f 2`
			if [ -d ${dirTemp} ]; then
			    DIR_BKP=${1} # Define o backup alternativo
			else
			    echo "${0}: ${dirTemp} não é um diretório válido, use o parametro --help para ajuda"
			fi
			;;
        "--tail="*)
            linhas=`echo ${x} | cut -d "=" -f 2`
            ;;
        "--bz")
            COM_COMPACTACAO='bzip2' # Define compactador alternativo
            ;;
		"--help")
			mostrarAjuda=1
			;;
        "--teste")
            teste=1
            ;;
        "--version")
            echo "Versão ${versao} - Powered by Alan Barros"
            exit 0
            ;;
            *)
			if [[ ! -f ${x} ]]; then # Se não for um arquivo sai
				echo -e "${0}: \"${x}\" não é um arquivo"
				exit 0; 
			fi 
			_logCorrente=${x} # Define log corrente
	esac
done

######################  Funções  ##################################
echo -e "Compactando log corrente - Powered by Alan Barros\n"

function teste(){ # Para um script em teste durante uma execução em produção 
    if [[ -z $teste ]]; then
        echo "${0}: Esta funcao está em teste no momento"
        exit 0
    fi
}

function exibeAjuda(){ # Exibe a mensagem de ajuda
	echo " ################################################################################################"
    echo -e "\t\t\t SCRIPT COMPACTA CORRENTE - by Alan Barros"
	echo ""
	echo "  Exemplo: user@ubuntu:/var/log$ ~/compacta_corrente.sh messages"
	echo "  Sintaxe: compacta_corrente.sh [ arquivo_para_compactar ] [ diretorio_destino (opcional) ]  "
    echo "  Parâmetros para uso:"
    echo -e "  --tail=-numLinhas \t - Usa tail para exibir as últimas linhas na compressão"
    echo -e "  --bz  \t\t - Compactação usando bzip2"
    echo -e "  --help \t\t - Exibe esta mensagem de ajuda"
    echo -e '  -temp="/dev/shm" \t - Altera o diretório de backup temporário, usado caso o / esteja cheio'
	echo "                                                 "
	echo "  O que o script faz: Troca permissão do arquivo de log corrente; compacta o mesmo para o    "
	echo "  diretório HOME do usuário atual ou para o que foi passado no parametro --temp=""; move o "
	echo "  arquivo para o seu diretório original (.) em seguida volta as permissões originais.      "
	echo "  Por fim, será exibido um log das ações. Arquivo compactado: arquivo_AAAA-MM-DD_HHmm.[gz][bz] "
	echo ""
    echo " ################################################################################################"
	exit 0
}

if [[ -n ${mostrarAjuda} ]]; then exibeAjuda; fi # Mostra ajuda

if [[ -z ${_logCorrente} ]]; then # Sai se não houver passado um arquivo
	echo "${0}: É necessário informar um arquivo de log, use --help para ajuda"
	exit 0
fi

function corrigeLocal(){ # Define variaveis de localização e caso não esteja no diretório do log entra
    _camAbsLog=${1}
    _logCorrente=$(echo ${1} | awk -F "/" '{print $NF}')
    _dirLogCorrente=$(echo ${1} | awk -F "/${_logCorrente}" '{print $1}' )

    if [[ -d ${_dirLogCorrente} ]]; then
       	cd ${_dirLogCorrente}
       	_dirLogCorrente=`pwd`
    else 
    	_dirLogCorrente=`pwd`
    fi

    _camAbsLog=`echo ${_dirLogCorrente}/${_logCorrente}`
}

corrigeLocal ${_logCorrente} # Chamada da função corrigeLocal

if [[ -n ${linhas} ]]; then # Define número de linhas no tail
    if [ `echo ${linhas} | cut -c ${#linhas}` == "%" ]; then 
        percento=`echo ${linhas} | tr -d %---+`
        if [ ${percento} -lt 100 -a ${percento} -gt 0 ]; then
            echo "Contando quanto é ${percento}% das linhas. Por favor, aguarde..."
            linhas=`wc -l ${_logCorrente} | awk '{print $1}'`
            percento=0.${percento}
            linhas=$(echo "${linhas} * ${percento}" | bc | cut -d . -f 1)
            echo -e "${0}: Compactando as últimas ${linhas} linhas\n"
        else
            echo "${0}: Porcentagem inválida."
            exit 0
        fi
    fi
    [ ${linhas} -gt 0 ] 2> /dev/null
    if [ $? -eq 0 -o $? -eq 1 ] ; then 
    	COM_EXIBICAO="tail -${linhas}" # Define exebição alternativa
    else
        echo "${0}: Valor ${linhas} não é válido"
        exit 0
    fi
fi

function compacta() { # [Arquivo para compactar] [Destino da compactação]
	echo "Aguarde, compactando e zerando o arquivo \"${1}\" "
	$(sudo ${COM_EXIBICAO} "${1}" | ${COM_COMPACTACAO} -9v - > ${2}.${extensaoBKP} && sudo cat /dev/null > "${1}" && sudo mv ${2}.${extensaoBKP} "${_dirLogCorrente}")
	echo -e "\n$(date +%H:%M:%S) - Comando compactação:\nsudo ${COM_EXIBICAO} '${1}' | ${COM_COMPACTACAO} -9v - > '${2}.${extensaoBKP}' && sudo cat /dev/null > '${1}' && sudo mv ${2}.${extensaoBKP} $PWD\n" >> ${LOG}
}

function permissao() { # [Arquivo que vai mudar permissão] [Permissão em decimal]
	$(sudo chmod ${2} "${1}")
	listagem=$(ls -l "${1}" | cut -d " " -f 1)
	echo "$(date +%H:%M:%S) - As permissões do arquivo '${1}' foram alteradas de ${PERMISSAO} para ${2}" >> ${LOG}
}

function verPermissoes() { #Verifica e armazena permissão do arquivo
	PERM=$(stat -c '%a' "${_camAbsLog}")

	PERMISSAO=${PERM} # Define permissão do arquivo
}

if [ ! -d "$HOME/log" ]; then mkdir ~/log; fi # Cria e/ou verifica diretório do log
data=$(date +%Y-%m-%d_%H%M) #Define data

# Cria váriaveis padrão úteis
if [[ -z ${DIR_BKP} ]]; then DIR_BKP=$HOME; fi
if [[ -z ${COM_EXIBICAO} ]]; then COM_EXIBICAO='cat'; fi
if [[ -z ${COM_COMPACTACAO} ]]; then COM_COMPACTACAO='gzip'; fi
extensaoBKP=$(echo ${COM_COMPACTACAO} | cut -c 1-2)
BKP=${_logCorrente}_$data
LOG=~/log/compactacao_${_logCorrente}_$data.log

###################### Compactação #####################################

verPermissoes #Verifica permissões
originalPerm=${PERMISSAO} #Armazena permissão original
permissao "${_camAbsLog}" 777 #Altera permissão do arquivo
compacta "${_camAbsLog}" ${DIR_BKP}/${BKP} #Compacta o arquivo deixando o original vazio
verPermissoes #Verifica permissões
permissao "${_camAbsLog}" ${originalPerm} #Voltando permissao
echo " "; echo "Relatório da compactação do log"; cat ${LOG} # Exibe Relatório