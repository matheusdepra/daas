# DaaS MVP - Plataforma de Dados como Serviço

Este projeto é um MVP (Minimum Viable Product) de uma plataforma de dados como serviço (DaaS) construída na Google Cloud Platform (GCP). Ele implementa um pipeline de dados ELT (Extract, Load, Transform) utilizando uma arquitetura Medalha (Bronze, Silver, Gold) para processar e analisar os dados do dataset [Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).

## Arquitetura

O pipeline de dados segue a arquitetura Medalha, organizada em três camadas:

1.  **Bronze (Dados Brutos)**: Os dados brutos em formato CSV são armazenados em um bucket do Google Cloud Storage. Tabelas externas no BigQuery são criadas para ler esses arquivos diretamente, sem processamento.
2.  **Silver (Dados Tratados)**: Os dados da camada Bronze são limpos, padronizados, tipados e enriquecidos. O resultado é armazenado em tabelas internas no BigQuery, prontas para serem consumidas por diferentes áreas.
3.  **Gold (Dados Agregados)**: Os dados da camada Silver são agregados para criar tabelas de fatos e dimensões, otimizadas para análises de negócio e dashboards.

## Tecnologias Utilizadas

- **Infraestrutura como Código**: Terraform
- **Armazenamento de Dados**: Google Cloud Storage (GCS)
- **Data Warehouse**: Google BigQuery
- **Orquestração/Transformação**: Shell Scripts com a CLI `bq`

## Estrutura do Projeto

```
.
├── main.tf                 # Arquivo principal do Terraform com a definição da infraestrutura
├── scripts/                # Scripts para transformação e carga de dados (Bronze -> Silver -> Gold)
│   ├── load_silver_*.sh
│   └── load_gold_*.sh
├── .gitignore
└── README.md
```

## Como Executar o Projeto

### Pré-requisitos

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) instalado e autenticado.
- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) instalado.
- Permissões adequadas no projeto GCP para criar recursos do GCS e BigQuery.

### 1. Configuração

Antes de aplicar o Terraform, certifique-se de que o ID do projeto no arquivo `main.tf` está correto:

```terraform
provider "google" {
  project = "SEU-PROJETO-GCP" # Altere para o seu ID de projeto
  region  = "us-central1"
}
```

### 2. Deploy da Infraestrutura

Execute os seguintes comandos do Terraform na raiz do projeto:

```bash
# Inicializa o Terraform
terraform init

# Revisa o plano de execução
terraform plan

# Aplica a configuração para criar os recursos na GCP
terraform apply
```

### 3. Carga dos Dados Brutos (Bronze)

Após a criação da infraestrutura, você precisa fazer o upload dos arquivos CSV do dataset Olist para o bucket do Cloud Storage criado pelo Terraform (o nome padrão é `daas-bronze-mvp`).

1. Baixe o dataset do [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).
2. Faça o upload dos arquivos `.csv` para a pasta `olist/` dentro do bucket `daas-bronze-mvp`.

### 4. Execução dos Scripts de Transformação

Os scripts devem ser executados na ordem correta para garantir a dependência dos dados.

**a. Dê permissão de execução para os scripts:**
```bash
chmod +x scripts/*.sh
```

**b. Execute os scripts para a camada Silver:**
*Estes scripts leem da camada Bronze e gravam na Silver.*
```bash
./scripts/load_silver_customers.sh
./scripts/load_silver_geolocation.sh
./scripts/load_silver_order_items.sh
./scripts/load_silver_order_payments.sh
./scripts/load_silver_order_reviews.sh
./scripts/load_silver_orders.sh
./scripts/load_silver_products.sh
./scripts/load_silver_sellers.sh
```

**c. Execute o script para a camada Gold:**
*Este script lê da camada Silver e cria a tabela de fatos na camada Gold.*
```bash
./scripts/load_gold_f_order.sh
```

Ao final, a tabela `f_orders` no dataset `mvp_gold` estará pronta para ser consultada e utilizada em ferramentas de BI e análise de dados.
