## ROADMAP – Plataforma DaaS Comercial (GCP)
---

## FASE 0 — Fundamentos (infra mínima)

**Objetivo:** ter o “campo de jogo” pronto.

### Infra (Terraform)

* Projeto GCP
* APIs habilitadas:

  * BigQuery
  * Cloud Storage
  * Cloud Run
  * Eventarc
  * Firestore
* Buckets:

  * `landing`
  * `bronze`
  * `silver`
  * `quarantine`
* Datasets BigQuery:

  * `silver`
  * `gold`
  * `quarantine`
* IAM:

  * Service Account do pipeline
  * Permissões mínimas (GCS + BQ)

✅ **Entrega**

* Terraform aplicado
* Infra reproduzível
* Nenhuma tabela criada

---

## FASE 1 — Ingestão (Landing → Bronze)

**Objetivo:** receber arquivos de clientes com rastreabilidade.

### Componentes

* Upload via:

  * Signed URL **ou**
  * API simples
* Evento GCS (`OBJECT_FINALIZE`)
* Cloud Run (Python) acionado por Eventarc

### O que o pipeline faz

* Valida nome do arquivo
* Extrai metadados (cliente, domínio, data)
* Calcula hash
* Move para `bronze/`
* Registra metadata (Firestore ou BQ)

✅ **Entrega**

* Bronze imutável
* Log de ingestão
* Reprocessamento possível

---

## FASE 2 — Tipagem e Silver dinâmica

**Objetivo:** transformar dado bruto em **produto confiável**.

### Pipeline (Cloud Run / Job)

* Lê arquivo Bronze
* Inferência + regras de tipagem
* Normalização (datas, decimais, nulls)
* Validação mínima

### Criação da Silver

* Se tabela **não existe** → cria
* Se existe:

  * compatível → append
  * incompatível → nova versão ou quarantine

### Padrões

* Colunas técnicas:

  * `tenant_id`
  * `source_file`
  * `ingestion_ts`
* Particionamento
* Clustering

✅ **Entrega**

* Silver criada automaticamente
* Tipagem forte
* Dados auditáveis

---

## FASE 3 — Contrato de schema

**Objetivo:** controle e previsibilidade (produto comercial).

### Modelo

* Schema em YAML/JSON por cliente/tabela
* Versionado em Git ou GCS

```yaml
table: orders
version: v1
required:
  - order_id
  - customer_id
types:
  order_id: STRING
  order_ts: TIMESTAMP
  total_value: FLOAT
```

### Pipeline

* Lê contrato
* Valida dado
* Rejeita quebra de contrato

✅ **Entrega**

* Governança
* Evolução controlada
* Base para SLA

---

## FASE 4 — Quarantine & Qualidade

**Objetivo:** não quebrar o pipeline.

### Regras de Quarantine

* Schema inválido
* Tipo inconsistente
* Coluna obrigatória ausente

### O que vai para quarantine

* Arquivo original
* Erros
* Schema detectado
* Timestamp

✅ **Entrega**

* Pipeline resiliente
* Evidência de erro
* Debug rápido

---

## FASE 5 — Gold (produtos de dados)

**Objetivo:** dados prontos para consumo comercial.

### Características

* Poucas tabelas
* Modelagem estável
* Criadas por SQL versionado
* Agregações e joins

### Execução

* Cloud Run + SQL
* Ou Scheduler + job

Terraform:

* **Só cria o dataset**
* Nunca a lógica

✅ **Entrega**

* Produtos claros
* Baixo custo
* Performance alta

---

## FASE 6 — Exposição DaaS

**Objetivo:** vender e controlar acesso.

### Opções

* API (Cloud Run)
* BigQuery Authorized Views
* Export sob demanda

### Controles

* Auth (API Key / OAuth)
* Rate limit
* Quotas
* Billing labels

✅ **Entrega**

* Consumo controlado
* Pronto para clientes externos

---

## FASE 7 — Observabilidade e custo

**Objetivo:** operar como produto.

### Métricas

* Arquivos ingeridos
* Linhas processadas
* Erros
* Tempo por etapa

### Custo

* Custo por cliente
* Custo por GB
* Custo por tabela

✅ **Entrega**

* Previsibilidade financeira
* Base para pricing

---

## FASE 8 — Escala e maturidade

**Objetivo:** virar plataforma.

* Multi-tenant real
* SLA por cliente
* Data catalog
* Billing automático
* Onboarding self-service
* Versionamento avançado

---

## VISÃO FINAL (mental model)

| Camada    | Responsável |
| --------- | ----------- |
| Infra     | Terraform   |
| Dados     | Python      |
| Contrato  | YAML        |
| Qualidade | Pipeline    |
| Produto   | Gold        |
| Venda     | API / Views |

