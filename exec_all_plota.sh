######################################
#Arquivo de execução e plotagem para mais de um arquivo ctl 
#Implementado por Vinicius Machado
#Outubro/2019
######################################


#!/bin/bash
###############PAR-EXEC###############

PREFIXO_ARQ="ptcxc" #exemplo ptcxc_spi3.ctl -> ptcxc

INTERVALOS="3 6 12 24 48 60" #n de meses de cada caso do spi - possiveis 1 3 6 9 12 24 48 60

PORC_MIN_DADOS="75" #verificar com a professora o desejado caso precise

DIR_CTL="/home2/viniciusmachado/pedidos_modificacao/karollyn/dados_teste" #onde estarao os arquivos ctl apos spi

DIR_SAIDA="saida" #tempo caracteristico

DIR_FIGURAS="figuras"

REMOVER="1" #remove logs e arquivos temporarios, 0 para nao, 1 para sim

###############PAR-GRADS###############

LATI="-53.75"

LATF="16.25"

LONI="-83.75"

LONF="-31.25"

PREFIXO_TITULO="tc"	 #PREFIXO_TITULO+spi_respectivo

VAR="spi" #spi

PREFIXO_FIG="ptcxc"	#PREFIXO_FIG+spi_respectivo

#########################################################################################################################################
mkdir -p ${DIR_SAIDA}
mkdir -p ${DIR_FIGURAS}
for INTERVALO in ${INTERVALOS} ; do

	cd ${DIR_CTL} >> log_entrada.txt

	ARQUIVO=${PREFIXO_ARQ}_spi${INTERVALO}.ctl
	echo "executando para arquivo: ${ARQUIVO}"
	
	/geral/programas/tempo_caracteristico/tempo_caracteristico.sh ${ARQUIVO} ${PORC_MIN_DADOS} >> log_entrada.txt
	
	cd - >> log_entrada.txt
	mv ${DIR_CTL}/${PREFIXO_ARQ}_spi${INTERVALO}_tc.* ${DIR_SAIDA}
	
	###############PLOTA-GRADS###############
	
	ARQ_TEMPLATE="/geral/programas/tempo_caracteristico/src/gs/gs_spi${INTERVALO}"
	
	cp ${ARQ_TEMPLATE} temp${INTERVALO}.gs
	
	sed -i "s#<CTL>#${DIR_SAIDA}/${PREFIXO_ARQ}_spi${INTERVALO}_tc.ctl#g;
		s#<LATI>#${LATI}#g;
		s#<LATF>#${LATF}#g;
		s#<LONI>#${LONI}#g;
		s#<LONF>#${LONF}#g;
		s#<TITLE>#${PREFIXO_TITULO}_spi${INTERVALO}#g;
		s#<VAR>#${VAR}#g;
		s#<NOME_FIG>#${DIR_FIGURAS}/${PREFIXO_FIG}_spi${INTERVALO}#g;
		" temp${INTERVALO}.gs
		
	grads -pbc "run temp${INTERVALO}.gs" >> log_gs${INTERVALO}.txt
	
done

	if [[ ${REMOVER} -eq "1" ]] ; then
		rm *temp*
		rm *log* 
		rm ${DIR_CTL}/log_entrada.txt
	fi

#########################################################################################################################################
