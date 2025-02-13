#!/bin/bash

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

set_colors() {
    RED='\033[1;31m'        # Vermelho brilhante
    GREEN='\033[1;32m'      # Verde brilhante
    YELLOW='\033[1;93m'     # Amarelo claro
    BLUE='\033[1;36m'       # Azul claro ciano
    NC='\033[0m'            # Sem cor (reset)
}

# Testa se está em um terminal para exibir cores
if [ -t 1 ] && ! grep -q -e '--no-color' <<<"$@"
then
    set_colors
fi

function parse_options() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -p|--porcentagem)
                PORC_MIN_DADOS="$2"
                shift
                ;;
            *)
                POSITIONAL_ARGS+=("$1")
                ;;
        esac
        shift
    done
    set -- "${POSITIONAL_ARGS[@]}"
}

function show_help() {
    echo -e "${YELLOW}Uso:${NC} ${GREEN}./tempo_caracteristico.sh${NC} ${BLUE}<input_directory>${NC} ${BLUE}<output_directory>${NC} ${BLUE}[intervals]${NC} ${BLUE}[options]${NC}"
    echo -e "   Este script executa e plota o tempo característico para arquivos .ctl de SPI."
    echo -e "   Ele gera arquivos .bin, .ctl e figuras correspondentes usando GrADS."
    echo -e "${RED}Atenção!${NC} Verifique se todos os comandos necessários estão disponíveis."
    echo -e "${YELLOW}Opções:${NC}"
    echo -e "  ${GREEN}-h, --help${NC}\t\t\tExibe esta ajuda e sai"
    echo -e "  ${GREEN}-p, --porcentagem${NC}\t\tDefine a porcentagem mínima de dados (padrão: 75)"
    echo -e "  ${GREEN}intervals${NC}\t\t\t(Opcional) Defina intervalos como '3 6 12' etc."
    echo -e "${YELLOW}Exemplo:${NC}"
    echo -e "  ${GREEN}./tempo_caracteristico.sh${NC} ${BLUE}./arquivos_ctl${NC} ${BLUE}./saida${NC} ${BLUE}3 6 12${NC} ${BLUE}-p 80${NC}"
}

# Error handling function
handle_error() {
	local error_message="$1"
	echo -e "${RED}ERROR:${NC} ${error_message}" >&2
	exit 1
}

# Function to check if a command exists
check_command() {
	command -v "$1" >/dev/null 2>&1 || show_help "Required command '$1' not found"
}

# Check for required commands
check_command grads
check_command sed

# Adicionar verificação de permissões do executável logo após os checks iniciais
EXEC_PATH="${SCRIPT_DIR}/bin/tempo_caracteristico"
if [ ! -x "$EXEC_PATH" ]; then
    echo -e "${YELLOW}Ajustando permissões do executável...${NC}"
    chmod +x "$EXEC_PATH" || handle_error "Falha ao ajustar permissões do executável"
fi

POSITIONAL_ARGS=()
parse_options "$@"

# Ajustar checagem de argumentos
if [ ${#POSITIONAL_ARGS[@]} -lt 1 ] || [ ${#POSITIONAL_ARGS[@]} -gt 3 ]; then
	show_help
fi

DIR_CTL="${POSITIONAL_ARGS[0]}"
BASE_DIR_SAIDA="${POSITIONAL_ARGS[1]:-output}"

# Validate input parameters
[ -z "$DIR_CTL" ] && handle_error "Input directory cannot be empty"
[ -z "$BASE_DIR_SAIDA" ] && handle_error "Output directory cannot be empty"

# Check if input directory exists and is readable
[ ! -d "$DIR_CTL" ] && handle_error "Input directory $DIR_CTL does not exist"
[ ! -r "$DIR_CTL" ] && handle_error "Input directory $DIR_CTL is not readable"

# Configurar PORC_MIN_DADOS com valor padrão se não foi definido
PORC_MIN_DADOS=${PORC_MIN_DADOS:-75}

DIR_SAIDA="${BASE_DIR_SAIDA}/tempocaracteristico/$(basename ${DIR_CTL})"
DIR_FIGURAS="${DIR_SAIDA}/figures"

# Cria diretório temporário
TEMP_DIR=$(mktemp -d)
trap 'rm -rf -- "$TEMP_DIR"' EXIT

# Create output directories with error checking
mkdir -p "${DIR_SAIDA}" || handle_error "Failed to create output directory ${DIR_SAIDA}"
mkdir -p "${DIR_FIGURAS}" || handle_error "Failed to create figures directory ${DIR_FIGURAS}"

# Se usuário forneceu intervalos, montar lista em um array
USER_INTERVALS=()
if [ -n "$3" ]; then
	# Usuário pode fornecer algo como "3 6 12"
	USER_INTERVALS=($3)
fi

# Adicionar antes do loop principal
function run_tempo_caracteristico() {
    local ARQ_CTL_IN=$1
    local MIN_DADOS=$2

    local ARQ_BIN_IN="$(dirname $ARQ_CTL_IN)/$(grep dset $ARQ_CTL_IN | tr -s " " | cut -d" " -f2 | sed -e s/\\^//g )"
    local ARQ_BIN_OUT="$(dirname $ARQ_BIN_IN)/$(basename $ARQ_BIN_IN .bin)_tc.bin"

    local NX=$(grep xdef ${ARQ_CTL_IN} | tr  "\t" " " | tr -s " " | cut -d" " -f2)
    local NY=$(grep ydef ${ARQ_CTL_IN} | tr  "\t" " " | tr -s " " | cut -d" " -f2)
    local NZ=$(grep zdef ${ARQ_CTL_IN} | tr  "\t" " " | tr -s " " | cut -d" " -f2)
    local NT=$(grep tdef ${ARQ_CTL_IN} | tr  "\t" " " | tr -s " " | cut -d" " -f2)
    local UNDEF=$(grep undef ${ARQ_CTL_IN} | tr  "\t" " " | tr -s " " | cut -d" " -f2)
    local NGS=$(basename ${ARQ_CTL_IN} .ctl | rev | cut -d"_" -f1 | rev )
    
    echo arquivo Log > log_${NGS}.txt

    "${SCRIPT_DIR}/bin/tempo_caracteristico" "$(dirname ${ARQ_BIN_IN})/${ARQ_BIN_IN}" \
        "$(dirname ${ARQ_BIN_IN})/${ARQ_BIN_OUT}" ${NX} ${NY} ${NZ} ${NT} ${UNDEF} ${MIN_DADOS} >> log_${NGS}.txt || \
        return 1

    local ARQ_CTL_OUT="$(dirname $ARQ_CTL_IN)/$(basename $ARQ_CTL_IN .ctl)_tc.ctl"
    cp $ARQ_CTL_IN $ARQ_CTL_OUT || return 1
    sed -i "s#$(basename $ARQ_BIN_IN)#$(basename $ARQ_BIN_OUT)#g;" ${ARQ_CTL_OUT} || return 1
    sed -i "s#${NT}#1#g;" ${ARQ_CTL_OUT} || return 1

    return 0
}

# Função para analisar o arquivo .ctl
parse_ctl_file() {
    local ctl_file="$1"
    # Inicializa variáveis
    NX=""
    NY=""
    NT=""
    DSET=""
    TITLE=""
    VARIABLES=()
    IN_VARS_BLOCK=false

    while read -r line; do
        # Remove espaços em branco no início e no fim and comments more robustly
        line="$(sed -e 's/#.*$//' <<<"$line")" # Remove comments after #
        line="$(echo -e "${line}" | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        # Ignora linhas vazias
        if [[ -z "$line" ]]; then
            continue
        fi

        if [[ "$line" =~ ^title[[:space:]]+(.*) ]]; then
            TITLE="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^xdef[[:space:]]+([0-9]+)[[:space:]]+.* ]]; then
            NX=${BASH_REMATCH[1]}
        elif [[ "$line" =~ ^ydef[[:space:]]+([0-9]+)[[:space:]]+.* ]]; then
            NY=${BASH_REMATCH[1]}
        elif [[ "$line" =~ ^tdef[[:space:]]+([0-9]+)[[:space:]]+.* ]]; then
            NT=${BASH_REMATCH[1]}
        elif [[ "$line" =~ ^dset[[:space:]]+(\^*)(.*) ]]; then
            DSET="${line#dset }"
            if [[ "${BASH_REMATCH[1]}" == "^" ]]; then
                DSET_DIR="${DIR_CTL}"
                DSET_FILE="${BASH_REMATCH[2]}"
            else
                DSET_PATH="${BASH_REMATCH[2]}"
                DSET_DIR=$(dirname "${DSET_PATH}")
                DSET_FILE=$(basename "${DSET_PATH}")
            fi
        elif [[ "$line" =~ ^vars[[:space:]]+ ]]; then
            IN_VARS_BLOCK=true
        elif [[ "$line" =~ ^endvars ]]; then
            IN_VARS_BLOCK=false
        elif $IN_VARS_BLOCK; then
            # Pega o nome da variável
            var_line=$(echo "$line" | awk '{print $1}')
            var_name=$(echo "$var_line" | sed 's/[=>].*$//')
            VARIABLES+=("$var_name")
        fi
    done < "${ctl_file}"
}

# Novo loop que varre todos os arquivos .ctl com "_spi"
echo -e "${GREEN}${BOLD}=== Iniciando operação ===${NC}"
echo -e "${BLUE}[CONFIG]${NC} Porcentagem mínima de dados: ${PORC_MIN_DADOS}"
echo -e "${BLUE}[CONFIG]${NC} Diretório de entrada: ${DIR_CTL}"
echo -e "${BLUE}[CONFIG]${NC} Diretório de saída: ${DIR_SAIDA}"
echo -e "${BLUE}[CONFIG]${NC} Diretório de figuras: ${DIR_FIGURAS}"

for file in "${DIR_CTL}"/*_spi*.ctl; do
	ARQUIVO=$(basename "$file")
	PREFIXO="${ARQUIVO%_spi*}"
	#PREFIXO_FIG="${PREFIXO}"
	INTERVALO="${ARQUIVO#*_spi}"
	INTERVALO="${INTERVALO%.*}"

    # Analisa o arquivo .ctl
    parse_ctl_file "$file"

    # Assume que a variável SPI é a primeira variável listada no arquivo .ctl
    VAR="${VARIABLES[0]}"
    PREFIXO_FIG="${PREFIXO}"

	# Se USER_INTERVALS não estiver vazio, checar se INTERVALO está na lista
	if [ "${#USER_INTERVALS[@]}" -gt 0 ]; then    # Corrigido: adicionado espaço antes do -gt
		FOUND=0
		for i in "${USER_INTERVALS[@]}"; do
			[ "$i" = "$INTERVALO" ] && FOUND=1
		done
		[ "$FOUND" -eq 0 ] && continue
	fi

	echo -e "${GREEN}Processando intervalo: ${INTERVALO}${NC}"
	cd "${DIR_CTL}" || handle_error "Falha ao entrar em ${DIR_CTL}"
	run_tempo_caracteristico "${ARQUIVO}" "${PORC_MIN_DADOS}" || \
		handle_error "Processamento do tempo característico falhou para ${ARQUIVO}"
	cd - || handle_error "Falha ao voltar ao diretório anterior"

	mv "${DIR_CTL}/${PREFIXO}_spi${INTERVALO}_tc."* "${DIR_SAIDA}" || \
		handle_error "Falha ao mover arquivos de saída para intervalo ${INTERVALO}"

    ARQ_TEMPLATE="${SCRIPT_DIR}/src/gs/gs"

	[ ! -f "${ARQ_TEMPLATE}" ] && handle_error "Template ${ARQ_TEMPLATE} não encontrado"
	TEMP_GS="${TEMP_DIR}/temp${INTERVALO}.gs"
	cp "${ARQ_TEMPLATE}" "${TEMP_GS}" || handle_error "Falha ao copiar template"

	XDEF_LINE="$(grep -i '^xdef ' "$file" | head -n1)"
	YDEF_LINE="$(grep -i '^ydef ' "$file" | head -n1)"

	LONI="$(echo "$XDEF_LINE" | awk '{print $4}')"
	LON_DELTA="$(echo "$XDEF_LINE" | awk '{print $5}')"
	NXDEF="$(echo "$XDEF_LINE" | awk '{print $2}')"
	LONF=$(awk -v start="$LONI" -v delta="$LON_DELTA" -v n="$NXDEF" 'BEGIN {print start + (n-1)*delta}')

	LATI="$(echo "$YDEF_LINE" | awk '{print $4}')"
	LAT_DELTA="$(echo "$YDEF_LINE" | awk '{print $5}')"
	NYDEF="$(echo "$YDEF_LINE" | awk '{print $2}')"
	LATF=$(awk -v start="$LATI" -v delta="$LAT_DELTA" -v n="$NYDEF" 'BEGIN {print start + (n-1)*delta}')

    if [ "$(echo "$LATI > $LATF" | bc -l)" -eq 1 ]; then
        TMP="$LATI"
        LATI="$LATF"
        LATF="$TMP"
    fi

    # just the filename, not the path
    BOTTOM=$(basename "$file")

	sed -i "s#<CTL>#${DIR_SAIDA}/${PREFIXO}_spi${INTERVALO}_tc.ctl#g;
		s#<LATI>#${LATI}#g;
		s#<LATF>#${LATF}#g;
		s#<LONI>#${LONI}#g;
		s#<LONF>#${LONF}#g;
		s#<TITLE>#${INTERVALO}#g;
		s#<VAR>#${VAR}#g;
        s#<BOTTOM>#${BOTTOM}#g;
		s#<NOME_FIG>#${DIR_FIGURAS}/${PREFIXO_FIG}_spi${INTERVALO}#g;" \
		"${TEMP_GS}" || handle_error "Falha ao ajustar template"

	echo -e "${YELLOW}Executando o template GrADS para intervalo ${INTERVALO}...${NC}"
	grads -pbc "run ${TEMP_GS}" || handle_error "GrADS falhou para intervalo ${INTERVALO}"
done

echo -e "${GREEN}Script finalizado com sucesso${NC}"
exit 0
