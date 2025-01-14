// Implementado por Eduardo Machado
// 2015

#include <string.h>
#include <stdio.h>
#include <math.h>
#include <stdlib.h>

float tempo_caracteristico(float serie[], float undef, int nSerie);
float auto_correlacao(float serie[], float undef, int nSerie, int lag);
float correlacao(float x[], float y[], float undef, int nSerie);
void desloca_serie(float entrada[], float saida[], float undef, int nSerie, int lag);
float covariancia(float x[], float y[], float undef, int nSerie);
float desvio_padrao(float vetor[], float undef, int nSerie);
float media(float vetor[], float undef, int nSerie);
int conta_dados(float vetor[], float undef, int nSerie);

int main(int argc, char *argv[])
{
	FILE *arqIn, *arqOut;
	char *arqNameIn, *arqNameOut;
	float undef, a, b;
	float* aux;
	int nx, ny, nz, nt, i, j, k, l, nMinimo;

/* Leitura dos parâmetros [ENTRADA .bin] [SAIDA .bin] [NX] [NY] [NZ] [NT] [UNDEF] */
	if (argc != 9)
	{
		puts("Parâmetros errados.");
		return;
	}
	arqNameIn=argv[1];
	arqNameOut=argv[2];
	nx=atoi(argv[3]);
	ny=atoi(argv[4]);
	nz=atoi(argv[5]);
	nt=atoi(argv[6]);
	undef=atof(argv[7]);
	nMinimo=atoi(argv[8]);
	printf("%s %s %d %d %d %d %f\n", arqNameIn, arqNameOut, nx, ny, nz, nt, undef);
	arqIn = fopen(arqNameIn, "rb");
	if (arqIn == NULL)  // Se houve erro na abertura
	{
		printf("Problemas na abertura do arquivo\n");
		return;
	}
	float ****matriz = (float****)malloc(nx * sizeof(float***)); //Aloca um Vetor de Ponteiros****
	float ***saida = (float***)malloc(nx * sizeof(float**));
	for (i = 0; i < nx; i++)
	{
		matriz[i] = (float***) malloc(ny * sizeof(float**));
		saida[i] = (float**) malloc(ny * sizeof(float*));
		for (j = 0; j < ny; j++)
		{
			matriz[i][j] = (float**) malloc(nz * sizeof(float*));
			saida[i][j] = (float*) malloc(nz * sizeof(float));
			for (k = 0; k < nz; k++)
			{
				matriz[i][j][k] = (float*) malloc(nt * sizeof(float));
			}
		}
	}

	for (i = 0; i < nt; i++)
	{
		for (j = 0; j < nz; j++)
		{
			for (k = 0; k < ny; k++)
			{
				for (l = 0; l < nx; l++)
				{
				fread(&matriz[l][k][j][i], sizeof(float), 1, arqIn);
				}
			}
		}
	}

	for (i = 0; i < nx; i++)
	{
		for (j = 0; j < ny; j++)
		{
			for (k = 0; k < nz; k++)
			{
				a=conta_dados(matriz[i][j][k], undef, nt);
				b=((nt*nMinimo)/100);
				printf("Calculo: %f %f\n", a, b);
				if (conta_dados(matriz[i][j][k] , undef, nt) < ((nt*nMinimo)/100))
				{
					saida[i][j][k]=undef;
					printf("Dados insuficientes na quadrícula : nx = %d , ny = %d , nt = %d\n", i, j, k);
				}
				else
				{
					saida[i][j][k]=tempo_caracteristico(matriz[i][j][k] , undef, nt);
				}
			}
		}
	}


	fclose(arqIn);
	arqOut=fopen(arqNameOut, "wb");
	if (arqOut == NULL) // Se não conseguiu criar
	{
		printf("Problemas na CRIACAO do arquivo\n");
		return;
	}
	for (i = 0; i < nz; i++){
		for (j = 0; j < ny; j++){
			for (k = 0; k < nx; k++){
				fwrite(&saida[k][j][i], sizeof(float), 1, arqOut);
			}
		}
	}
	fclose(arqOut);
	return;
}

float tempo_caracteristico(float serie[], float undef, int nSerie){
	int N=30; /* Constante tirada do artigo */
	int i, lag;
	float t0, somatoriaCor, autoCor;

	somatoriaCor=0;
	for (i = 0; i < N; i++)
	{
		autoCor=auto_correlacao(serie, undef, nSerie, i+1);
		if (autoCor == undef){
			return(undef);
		}
		somatoriaCor=somatoriaCor+((1-(i/N))*autoCor);
	}

	/* t0 é a variável de tempo característico */
	t0=1+(2*somatoriaCor);
	return(t0);
}

float auto_correlacao(float serie[], float undef, int nSerie, int lag){
	float serie2[nSerie], result;
	int i;

	desloca_serie(serie, serie2, undef, nSerie, lag);
	result=correlacao(serie, serie2,undef, nSerie);
	return(result);
}

float correlacao(float x[], float y[], float undef, int nSerie){
	float cor, cov, dpx, dpy;
	/* Calcula a correlação entre duas séries */
	cov=covariancia(x,y,undef,nSerie);
	dpx=desvio_padrao(x, undef, nSerie);
	dpy=desvio_padrao(y, undef, nSerie);
	if ((cov == undef) || (dpx == undef) || (dpy == undef))
	{
		return(undef);
	}
	cor=cov/(dpx*dpy);
	return(cor);
}

void desloca_serie(float entrada[], float saida[], float undef, int nSerie, int lag){
	int i;

	/* Preenche os primeiros "lag" valores com indefinido */
	for (i = 0; i < lag; i++)
	{
		saida[i]=undef;
	}
	/* Faz a defasagem da série */
	for (i = lag; i < nSerie; i++)
	{
		saida[i]=entrada[i - lag];
	}

	return;
}

float covariancia(float x[], float y[], float undef, int nSerie){
	float somatoriaX, somatoriaY, varXY, somatoriaXY, cov;
	int i, divisor;

	/* Faz as somatórias dos vetores x e y */
	somatoriaX=0;
	somatoriaY=0;
	somatoriaXY=0;
	divisor=0;
	for (i = 0; i < nSerie; i++)
	{
		if ((x[i] != undef) && (y[i] != undef))
		{
			somatoriaX=somatoriaX+x[i];
			somatoriaY=somatoriaY+y[i];
			somatoriaXY=somatoriaXY+(x[i]*y[i]);
			divisor++;
		}
	}
	if (divisor == 0)
	{
		return(undef);
	}
	/* Agora as variáveis somatoriaX e somatoriaY estão com os valores
		 das somatórias dos vetores de x e y.
		 Já a variável somatoriaXY está com o resultado da somatória das
		 multiplicações dos valores de x e y. */

	varXY=(somatoriaX*somatoriaY)/divisor;

	/* Valor total da covariancia */
	cov=(somatoriaXY - varXY)/divisor;

	return(cov);
}

float desvio_padrao(float vetor[], float undef, int nSerie){
	float somatoriaMedia, somatoriaVariancia, mediaSerie, variancia, dp;
	int i, divisor;

/* Média de todos os valores do vetor */
	mediaSerie=media(vetor,undef,nSerie);
	if (mediaSerie == undef)
	{
		return(undef);
	}
/* Calcula a variancia */
	somatoriaVariancia=0;
	divisor=0;
	for (i = 0; i < nSerie; i++)
	{
		if (vetor[i] != undef)
		{
			somatoriaVariancia=somatoriaVariancia+(pow((vetor[i]-mediaSerie),2));
			divisor++;
		}
	}
	variancia=somatoriaVariancia/divisor;

/* O desvio padrão recebe a raiz quadrada da variancia */
	dp=(sqrt(variancia));
	return(dp);
}

/* Função que calcula a média aritimética */
float media(float vetor[], float undef, int nSerie){
	float somatoria, med;
	int divisor, i;

	somatoria=0;
	divisor=0;
	for (i = 0; i < nSerie; i++)
	{
		if (vetor[i] != undef)
		{
			somatoria=somatoria+vetor[i];
			divisor++;
		}
	}
	if (divisor == 0)
	{
		return(undef);
	}
	med=somatoria/divisor;
	return(med);
}

int conta_dados(float vetor[], float undef, int nSerie){
	int cont, i;

	cont=0;
	for (i = 0; i < nSerie; i++){
		if (vetor[i] != undef){
			cont++;
		}
	}
	return(cont);
}