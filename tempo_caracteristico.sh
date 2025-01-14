#!/bin/bash

# Implementado por Eduardo Machado
# 2015

if [[ $# != 2 ]]; then																																									# Caso não sejam colocados todos os parâmetros ou
	echo "" 																																															# sejam colocados parâmetros demais, o script não
	echo "ERRO! Parametros errados! Utilize:"																															# roda e imprime na tela essa mensagem de ERRO
	echo "tempo_caracteristico [ARQ_CTL_ENTRADA] [% MIN. DADOS]"
	echo ""
	echo ""
else
	ARQ_CTL_IN=${1}
	MIN_DADOS=${2}																																									# Leitura de parâmetros

	ARQ_BIN_IN="$(dirname $ARQ_CTL_IN)/$(grep dset $ARQ_CTL_IN | tr -s " " | cut -d" " -f2 | sed -e s/\\^//g )"
							# Retira as variáveis necessárias para a execução

	ARQ_BIN_OUT="$(dirname $ARQ_BIN_IN)/$(basename $ARQ_BIN_IN .bin)_tc.bin"
																						# do programa do arquivo ctl

	NX=$(cat ${ARQ_CTL_IN} | grep xdef | tr  "\t" " " | tr -s " " | cut -d" " -f2)
	NY=$(cat ${ARQ_CTL_IN} | grep ydef | tr  "\t" " " | tr -s " " | cut -d" " -f2)
	NZ=$(cat ${ARQ_CTL_IN} | grep zdef | tr  "\t" " " | tr -s " " | cut -d" " -f2)
	NT=$(cat ${ARQ_CTL_IN} | grep tdef | tr  "\t" " " | tr -s " " | cut -d" " -f2)
	UNDEF=$(cat ${ARQ_CTL_IN} | grep undef | tr  "\t" " " | tr -s " " | cut -d" " -f2)
	NGS=$(basename ${ARQ_CTL_IN} .ctl | rev | cut -d"_" -f1 | rev )
	echo arquivo Log > log_${NGS}.txt

	echo "$(dirname ${ARQ_BIN_IN})/${ARQ_BIN_IN}" "$(dirname ${ARQ_BIN_IN})/${ARQ_BIN_OUT}" ${NX} ${NY} ${NZ} ${NT} ${UNDEF} ${MIN_DADOS}														# Imprime os parâmetros que estão sendo usados

	/geral/programas/tempo_caracteristico/bin/tempo_caracteristico "$(dirname ${ARQ_BIN_IN})/${ARQ_BIN_IN}" "$(dirname ${ARQ_BIN_IN})/${ARQ_BIN_OUT}" ${NX} ${NY} ${NZ} ${NT} ${UNDEF} ${MIN_DADOS} >> log_${NGS}.txt

	ARQ_CTL_OUT="$(dirname $ARQ_CTL_IN)/$(basename $ARQ_CTL_IN .ctl)_tc.ctl" 																										#	o programa cria o arquivo ctl
	cp $ARQ_CTL_IN $ARQ_CTL_OUT
	#sed  -i "s#$(basename $ARQ_BIN_IN .bin)#$(basename $ARQ_BIN_OUT .bin)#g;" ${ARQ_CTL_OUT}
	sed  -i "s#$(basename $ARQ_BIN_IN)#$(basename $ARQ_BIN_OUT)#g;" ${ARQ_CTL_OUT}
	sed  -i "s#${NT}#1#g;" ${ARQ_CTL_OUT}

fi
