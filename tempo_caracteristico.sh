#!/bin/bash

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
NC2BIN="/geral/programas/converte_nc_bin/converte_dados_nc_to_bin.sh"

set_colors() {
    RED='\033[1;31m'        # Vermelho brilhante
    GREEN='\033[1;32m'      # Verde brilhante
    YELLOW='\033[1;93m'     # Amarelo claro
    BLUE='\033[1;36m'       # Azul claro ciano
    PURPLE='\033[1;35m'     # Roxo brilhante
    BOLD='\033[1m'          # Negrito
    NC='\033[0m'            # Sem cor (reset)
}

# Testa se está em um terminal para exibir cores
if [ -t 1 ] && ! grep -q -e '--no-color' <<<"$@"
then
    set_colors
fi

print_bar() {
    local color=$1
    local text=$2
    local width=$(tput cols)
    local text_len=${#text}
    local pad_len=$(( (width - text_len - 2) / 2 ))
    local padding=$(printf '%*s' $pad_len '')
    echo -e "${color}${padding// /=} ${text} ${padding// /=}=${NC}"
}

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
    echo -e "${YELLOW}Uso:${NC} ${GREEN}./tempo_caracteristico.sh${NC} ${BLUE}<output_directory>${NC} ${BLUE}<input_directory1> [input_directory2...]${NC} ${BLUE}[intervals]${NC} ${BLUE}[options]${NC}"
    echo -e "   Este script executa e plota o tempo característico para arquivos .ctl de SPI."
    echo -e "   Ele gera arquivos .bin, .ctl e figuras correspondentes usando GrADS."
    echo -e "${RED}Atenção!${NC} Verifique se todos os comandos necessários estão disponíveis."
    echo -e "${YELLOW}Opções:${NC}"
    echo -e "  ${GREEN}-h, --help${NC}\t\t\tExibe esta ajuda e sai"
    echo -e "  ${GREEN}-p, --porcentagem${NC}\t\tDefine a porcentagem mínima de dados (padrão: 75)"
    echo -e "  ${GREEN}intervals${NC}\t\t\t(Opcional) Defina intervalos como '3 6 12' etc."
    echo -e "${YELLOW}Exemplo:${NC}"
    echo -e "  ${GREEN}./tempo_caracteristico.sh${NC} ${BLUE}./saida${NC} ${BLUE}./dir1 ./dir2 ./dir3${NC} ${BLUE}3 6 12${NC} ${BLUE}-p 80${NC}"
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

# Function to determine CLEVS and CCOLORS based on INTERVALO
get_clevs() {
    local interval="$1"
    
    declare -A intervals=(
        [1]="0 0.5 1 1.5 2 2.5 3 3.5 4 4.5 5"
        [3]="0 2 4 6 8 10 12 14 16 18 20"
        [6]="0 3 6 9 12 15 18 21 24 27 30"
        [9]="0 4 8 12 16 20 24 28 32 36 40"
        [12]="0 4 8 12 16 20 24 28 32 36 40"
        [24]="10 15 20 25 30 35 40 45 50 55 60"
        [48]="30 33 36 39 42 45 48 51 54 57 60"
        [60]="30 33 36 39 42 45 48 51 54 57 60"
    )
    
    if [[ -n "${intervals[$interval]}" ]]; then
        echo "${intervals[$interval]}"
    else
        handle_error "Intervalo inválido: $interval"
    fi
}

get_colors() {
    echo "70 4 11 5 12 8 27 2"
}

# Check for required commands
check_command grads
check_command sed
check_command cdo || handle_error "CDO (Climate Data Operators) não encontrado. Instale o pacote CDO."

# Adicionar verificação de permissões do executável logo após os checks iniciais
EXEC_PATH="${SCRIPT_DIR}/bin/tempo_caracteristico"
if [ ! -x "$EXEC_PATH" ]; then
    echo -e "${YELLOW}Ajustando permissões do executável...${NC}"
    chmod +x "$EXEC_PATH" || handle_error "Falha ao ajustar permissões do executável"
fi

POSITIONAL_ARGS=()
parse_options "$@"

# Ajustar checagem de argumentos
if [ ${#POSITIONAL_ARGS[@]} -lt 2 ]; then
    show_help
    exit 1
fi

# Primeiro argumento posicional é o diretório de saída
BASE_DIR_SAIDA="${POSITIONAL_ARGS[0]}"

# Verificar se há intervalos específicos na última posição
LAST_ARG="${POSITIONAL_ARGS[${#POSITIONAL_ARGS[@]}-1]}"
USER_INTERVALS=()
INPUT_DIRS=()

# Verificar se o último argumento contém os intervalos (números separados por espaços)
if [[ "$LAST_ARG" =~ ^[0-9\ ]+$ ]]; then
    USER_INTERVALS=($LAST_ARG)
    # Pega todos os argumentos exceto o primeiro (BASE_DIR_SAIDA) e o último (intervals)
    for ((i=1; i<${#POSITIONAL_ARGS[@]}-1; i++)); do
        INPUT_DIRS+=("${POSITIONAL_ARGS[$i]}")
    done
else
    # Se não tiver intervalos, pega todos exceto o primeiro (BASE_DIR_SAIDA)
    for ((i=1; i<${#POSITIONAL_ARGS[@]}; i++)); do
        INPUT_DIRS+=("${POSITIONAL_ARGS[$i]}")
    done
fi

# Validate output parameter
[ -z "$BASE_DIR_SAIDA" ] && handle_error "Output directory cannot be empty"

# Check if we have any input directories
if [ ${#INPUT_DIRS[@]} -eq 0 ]; then
    handle_error "Ao menos um diretório de entrada deve ser fornecido"
fi

# Configurar PORC_MIN_DADOS com valor padrão se não foi definido
PORC_MIN_DADOS=${PORC_MIN_DADOS:-75}

# Cria diretório temporário
TEMP_DIR=$(mktemp -d)
trap 'rm -rf -- "$TEMP_DIR"' EXIT

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

echo -e "${GREEN}${BOLD}=== Iniciando operação ===${NC}"
echo -e "${BLUE}[CONFIG]${NC} Porcentagem mínima de dados: ${PORC_MIN_DADOS}"
echo -e "${BLUE}[CONFIG]${NC} Diretório de saída: ${BASE_DIR_SAIDA}"
echo -e "${BLUE}[CONFIG]${NC} Diretórios de entrada: ${INPUT_DIRS[@]}"

# Loop através de cada diretório de entrada
for DIR_CTL in "${INPUT_DIRS[@]}"; do
    # Variáveis para rastrear o progresso
    ((DIR_COUNT++))
    print_bar "${PURPLE}" "Processando diretório ${DIR_COUNT} de ${#INPUT_DIRS[@]}: $(basename ${DIR_CTL})"
    echo -e "${BLUE}[INFO]${NC} Processando diretório de entrada: ${DIR_CTL}"
    
    # Validate input directory
    [ ! -d "$DIR_CTL" ] && handle_error "Input directory $DIR_CTL does not exist"
    [ ! -r "$DIR_CTL" ] && handle_error "Input directory $DIR_CTL is not readable"
    
    DIR_SAIDA="${BASE_DIR_SAIDA}/tempocaracteristico/$(basename ${DIR_CTL})"
    DIR_FIGURAS="${DIR_SAIDA}/figures"
    
    # Create output directories with error checking
    mkdir -p "${DIR_SAIDA}" || handle_error "Failed to create output directory ${DIR_SAIDA}"
    mkdir -p "${DIR_FIGURAS}" || handle_error "Failed to create figures directory ${DIR_FIGURAS}"
    
    echo -e "${BLUE}[CONFIG]${NC} Diretório de saída para $(basename ${DIR_CTL}): ${DIR_SAIDA}"
    echo -e "${BLUE}[CONFIG]${NC} Diretório de figuras para $(basename ${DIR_CTL}): ${DIR_FIGURAS}"

    # Novo loop que varre todos os arquivos .ctl com "_spi"
    for file in "${DIR_CTL}"/*_spi*.ctl; do
        # Verificar se existem arquivos que correspondem ao padrão
        if [[ ! -f "$file" ]]; then
            echo -e "${YELLOW}[AVISO]${NC} Nenhum arquivo .ctl encontrado em ${DIR_CTL}"
            continue
        fi
        
        ARQUIVO=$(basename "$file")
        PREFIXO="${ARQUIVO%_spi*}"
        INTERVALO="${ARQUIVO#*_spi}"
        INTERVALO="${INTERVALO%.*}"

        # Se USER_INTERVALS não estiver vazio, checar se INTERVALO está na lista
        if [ "${#USER_INTERVALS[@]}" -gt 0 ]; then
            FOUND=0
            for i in "${USER_INTERVALS[@]}"; do
                [ "$i" = "$INTERVALO" ] && FOUND=1
            done
            [ "$FOUND" -eq 0 ] && continue
        fi

        # Analisa o arquivo .ctl
        parse_ctl_file "$file"
        
        # Assume que a variável SPI é a primeira variável listada no arquivo .ctl
        # se a variável SPI não for encontrada, tenta ler do nome do arquivo
        if [[ "${#VARIABLES[@]}" -gt 0 ]]; then
            echo -e "${BLUE}Lendo variáveis do arquivo .ctl $(basename "$file")${NC}"
            VAR="${VARIABLES[0]}"
        else
            echo -e "${YELLOW}Variável SPI não encontrada no .ctl; Usando Filename: $(basename "$file")${NC}"
            # o intervalo está depois do _spi
            VAR="${ARQUIVO%_spi*}"
            VAR="${VAR##*_}"
        fi
        PREFIXO_FIG="${PREFIXO}"
        
        if [[ -z "$VAR" ]]; then
            handle_error "Variável SPI não encontrada no arquivo .ctl ou no nome do arquivo"
        fi

        echo -e "${GREEN}Processando intervalo: ${INTERVALO} em ${DIR_CTL}${NC}"
        cd "${DIR_CTL}" || handle_error "Falha ao entrar em ${DIR_CTL}"
        run_tempo_caracteristico "${ARQUIVO}" "${PORC_MIN_DADOS}" || \
            handle_error "Processamento do tempo característico falhou para ${ARQUIVO}"
        cd - || handle_error "Falha ao voltar ao diretório anterior"

        mv "${DIR_CTL}/${PREFIXO}_spi${INTERVALO}_tc."* "${DIR_SAIDA}" || \
            handle_error "Falha ao mover arquivos de saída para intervalo ${INTERVALO}"

        ARQ_TEMPLATE="${SCRIPT_DIR}/src/gs/gs.gs"

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
        CINT=$(get_clevs "$INTERVALO")
        CCOL=$(get_colors)

        sed -i "s#<CTL>#${DIR_SAIDA}/${PREFIXO}_spi${INTERVALO}_tc.ctl#g;
            s#<LATI>#${LATI}#g;
            s#<LATF>#${LATF}#g;
            s#<LONI>#${LONI}#g;
            s#<LONF>#${LONF}#g;
            s#<TITLE>#${INTERVALO}#g;
            s#<VAR>#${VAR}#g;
            s#<BOTTOM>#${BOTTOM}#g;
            s#<NOME_FIG>#${DIR_FIGURAS}/${PREFIXO_FIG}_spi${INTERVALO}#g;
            s#<CINT>#${CINT}#g;
            s#<CCOL>#${CCOL}#g;" \
            "${TEMP_GS}" || handle_error "Falha ao ajustar template"

        echo -e "${YELLOW}Executando o template GrADS para intervalo ${INTERVALO}...${NC}"
        grads -pbc "run ${TEMP_GS}" || handle_error "GrADS falhou para intervalo ${INTERVALO}"
    done
done

# Função para detectar padrão de nomes e criar nome do ensemble
generate_ensemble_name() {
    local input_dirs=("$@")
    local ensemble_name=""
    
    # Verifica se todas as pastas têm um padrão de nome similar (ex: EC-Earth3_ssp245_r1_gr_2027-2100)
    local common_prefix=""
    local common_suffix=""
    
    # Pega o primeiro diretório como referência
    local first_dir=$(basename "${input_dirs[0]}")
    
    # Tenta encontrar padrão "rN" onde N é um número
    if [[ "$first_dir" =~ _r[0-9]+_ ]]; then
        # Extrai o prefixo e sufixo antes e depois do padrão rN
        common_prefix="${first_dir%%_r[0-9]*}"
        common_suffix="${first_dir#*_r[0-9]_}"
        ensemble_name="${common_prefix}_Ensemble_${common_suffix}"
    else
        # Se não encontrar o padrão, usa "Ensemble" como nome base
        ensemble_name="Ensemble_$(date +%Y%m%d)"
    fi
    
    echo "$ensemble_name"
}

# Função para calcular o ensemble mean
calculate_ensemble_mean() {
    local base_dir_saida="$1"
    shift
    local input_dirs=("$@")
    local ensemble_name=$(generate_ensemble_name "${input_dirs[@]}")
    
    echo -e "${PURPLE}${BOLD}=== Calculando Ensemble Mean ===${NC}"
    echo -e "${BLUE}[INFO]${NC} Nome do ensemble: ${ensemble_name}"
    
    # Cria diretório para o ensemble
    local ensemble_dir="${base_dir_saida}/tempocaracteristico/${ensemble_name}"
    local ensemble_fig="${ensemble_dir}/figures"
    
    mkdir -p "${ensemble_dir}" || handle_error "Falha ao criar diretório do ensemble ${ensemble_dir}"
    mkdir -p "${ensemble_fig}" || handle_error "Falha ao criar diretório de figuras do ensemble ${ensemble_fig}"
    
    # Processa cada intervalo SPI (1, 3, 6, 12, etc.)
    local processed_intervals=()
    
    # Encontra todos os intervalos disponíveis
    for dir in "${input_dirs[@]}"; do
        dir_out="${base_dir_saida}/tempocaracteristico/$(basename ${dir})"
        for ctl_file in "${dir_out}"/*_spi*_tc.ctl; do
            if [[ -f "$ctl_file" ]]; then
                file_name=$(basename "$ctl_file")
                # Extrai o intervalo (ex: de arq_spi3_tc.ctl pega o 3)
                if [[ "$file_name" =~ _spi([0-9]+)_tc ]]; then
                    intervalo="${BASH_REMATCH[1]}"
                    # Adiciona o intervalo à lista se ainda não estiver lá
                    if ! [[ " ${processed_intervals[@]} " =~ " ${intervalo} " ]]; then
                        processed_intervals+=("$intervalo")
                    fi
                fi
            fi
        done
    done
    
    echo -e "${BLUE}[INFO]${NC} Intervalos encontrados: ${processed_intervals[@]}"
    
    # Para cada intervalo, processa o ensemble mean
    for intervalo in "${processed_intervals[@]}"; do
        echo -e "${GREEN}Processando ensemble mean para intervalo SPI${intervalo}${NC}"
        
        # Prepara lista de arquivos para o CDO ensmean
        local nc_files=()
        local prefixo=""
        local suffix=""
        
        # Converte cada arquivo .ctl para .nc temporário para uso com CDO
        for dir in "${input_dirs[@]}"; do
            dir_out="${base_dir_saida}/tempocaracteristico/$(basename ${dir})"
            for ctl_file in "${dir_out}"/*_spi${intervalo}_tc.ctl; do
                if [[ -f "$ctl_file" ]]; then
                    base_name=$(basename "$ctl_file" _tc.ctl)
                    # Extrai o prefixo para usar depois
                    if [[ -z "$prefixo" ]]; then
                        prefixo="${base_name%_spi*}"
                    fi
                    
                    # Converte de .ctl para .nc usando CDO - salva no diretório temporário
                    echo -e "${YELLOW}Convertendo ${ctl_file} para NetCDF temporário${NC}"
                    local nc_out="${TEMP_DIR}/$(basename ${dir})_${base_name}_tc.nc"
                    cdo -f nc import_binary "${ctl_file}" "${nc_out}" || \
                        handle_error "Falha ao converter ${ctl_file} para NetCDF"
                    
                    nc_files+=("${nc_out}")
                fi
            done
        done
        
        if [ ${#nc_files[@]} -eq 0 ]; then
            echo -e "${YELLOW}[AVISO]${NC} Nenhum arquivo encontrado para SPI${intervalo}"
            continue
        fi
        
        # Calcula o ensemble mean usando CDO - também usa arquivo temporário
        local temp_ensemble_nc="${TEMP_DIR}/${prefixo}_spi${intervalo}_tc_ensemble.nc"
        echo -e "${BLUE}[INFO]${NC} Calculando ensemble mean para ${#nc_files[@]} arquivos"
        
        # Construir comando CDO ensmean
        local cdo_cmd="cdo ensmean"
        for nc_file in "${nc_files[@]}"; do
            cdo_cmd+=" ${nc_file}"
        done
        cdo_cmd+=" ${temp_ensemble_nc}"
        
        echo -e "${YELLOW}Executando: ${cdo_cmd}${NC}"
        eval ${cdo_cmd} || handle_error "Falha ao calcular ensemble mean para SPI${intervalo}"
        
        # Converte o resultado de volta para .ctl usando NC2BIN
        local ensemble_ctl="${ensemble_dir}/${prefixo}_spi${intervalo}_tc_ensemble.ctl"
        echo -e "${YELLOW}Convertendo resultado para CTL usando NC2BIN${NC}"
        bash "${NC2BIN}" "${temp_ensemble_nc}" "${ensemble_ctl}" || \
            handle_error "Falha ao converter ensemble NC para CTL"
        
        # Plot do resultado com GrADS
        local temp_gs="${TEMP_DIR}/ensemble_spi${intervalo}.gs"
        cp "${SCRIPT_DIR}/src/gs/gs.gs" "${temp_gs}" || handle_error "Falha ao copiar template GrADS"
        
        # Extrai parâmetros da grade do primeiro arquivo NC
        local dimensions=$(cdo griddes "${nc_files[0]}" | grep -E "xsize|ysize|xfirst|yfirst|xinc|yinc")
        local xsize=$(echo "$dimensions" | grep "xsize" | awk '{print $3}')
        local ysize=$(echo "$dimensions" | grep "ysize" | awk '{print $3}')
        local xfirst=$(echo "$dimensions" | grep "xfirst" | awk '{print $3}')
        local yfirst=$(echo "$dimensions" | grep "yfirst" | awk '{print $3}')
        local xinc=$(echo "$dimensions" | grep "xinc" | awk '{print $3}')
        local yinc=$(echo "$dimensions" | grep "yinc" | awk '{print $3}')
        
        local LONF=$(awk -v start="$xfirst" -v delta="$xinc" -v n="$xsize" 'BEGIN {print start + (n-1)*delta}')
        local LATF=$(awk -v start="$yfirst" -v delta="$yinc" -v n="$ysize" 'BEGIN {print start + (n-1)*delta}')
        
        # Garante que LATI < LATF
        if [ "$(echo "$yfirst > $LATF" | bc -l)" -eq 1 ]; then
            local TMP="$yfirst"
            yfirst="$LATF"
            LATF="$TMP"
        fi
        
        # Determina a variável do NetCDF
        local var_name=$(cdo showname "${temp_ensemble_nc}" | head -1)
        
        # Bottom text para o gráfico
        local BOTTOM=$(basename "${temp_ensemble_nc[0]}" .nc)
        BOTTOM="${BOTTOM##*/}"  # Remove o caminho, mantendo apenas o nome do arquivo
        BOTTOM="${BOTTOM%%_r[0-9]*}_${BOTTOM#*_r[0-9]_}"
        echo -e "${BLUE}[INFO]${NC} Bottom text: ${BOTTOM}"
        local CINT=$(get_clevs "$intervalo")
        local CCOL=$(get_colors)
        
        sed -i "s#<CTL>#${ensemble_ctl}#g;
            s#<LATI>#${yfirst}#g;
            s#<LATF>#${LATF}#g;
            s#<LONI>#${xfirst}#g;
            s#<LONF>#${LONF}#g;
            s#<TITLE>#${intervalo} (Ensemble)#g;
            s#<VAR>#${var_name}#g;
            s#<BOTTOM>#${BOTTOM}#g;
            s#<NOME_FIG>#${ensemble_fig}/${prefixo}_spi${intervalo}_ensemble#g;
            s#<CINT>#${CINT}#g;
            s#<CCOL>#${CCOL}#g;" \
            "${temp_gs}" || handle_error "Falha ao ajustar template para ensemble"
        
        echo -e "${YELLOW}Executando o template GrADS para ensemble do intervalo ${intervalo}...${NC}"
        grads -pbc "run ${temp_gs}" || handle_error "GrADS falhou para ensemble do intervalo ${intervalo}"
        
        echo -e "${GREEN}Ensemble mean para SPI${intervalo} concluído com sucesso${NC}"
    done
    
    echo -e "${GREEN}${BOLD}=== Processamento do Ensemble Mean concluído ===${NC}"
}

# Após processar todos os diretórios individualmente, calcula o ensemble mean
if [ ${#INPUT_DIRS[@]} -gt 1 ]; then
    calculate_ensemble_mean "${BASE_DIR_SAIDA}" "${INPUT_DIRS[@]}"
else
    echo -e "${YELLOW}[AVISO]${NC} Apenas um diretório de entrada fornecido - ensemble mean não calculado."
fi

echo -e "${GREEN}Script finalizado com sucesso${NC}"
exit 0
