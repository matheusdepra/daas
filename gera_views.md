# Semantic Layer Declarativa no DaaS (Ideia de Produto)

## Objetivo
Permitir que usuários criem **views semânticas** sobre a Silver **sem escrever SQL**, servindo como camada oficial de consumo para humanos, BI e **agentes de IA**.

---

## Princípios
- Silver é **técnica e automática**
- Semântica é **declarativa**
- Usuário define **o que**, não **como**
- SQL é **gerado**, não escrito manualmente

---

## Conceito Central
A view semântica nasce de um **arquivo declarativo (YAML/JSON)** que descreve:
- tabela fonte
- colunas expostas
- aliases
- casts simples
- filtros básicos

O sistema gera e executa o SQL automaticamente.

---

## Exemplo de Definição (YAML)

```yaml
view_name: orders_semantic
source_table: silver.orders

fields:
  order_id:
    alias: order_id
  order_ts:
    alias: order_date
    cast: DATE
  total_value:
    alias: revenue

filters:
  - company = "{{tenant}}"
