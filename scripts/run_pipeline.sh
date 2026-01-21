#!/bin/bash
# Este script executa todo o pipeline de carga de dados, garantindo a ordem correta.

# Para o script se um comando falhar
set -e

# Encontra o diretório onde o script está localizado para poder chamar os outros
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "🚀 Iniciando o carregamento da camada Silver..."

# Executa todos os scripts da camada Silver
"$DIR/load_silver_customers.sh"
"$DIR/load_silver_geolocation.sh"
"$DIR/load_silver_order_items.sh"
"$DIR/load_silver_order_payments.sh"
"$DIR/load_silver_order_reviews.sh"
"$DIR/load_silver_orders.sh"
"$DIR/load_silver_products.sh"
"$DIR/load_silver_sellers.sh"

echo "✅ Camada Silver carregada com sucesso!"
echo "---------------------------------"
echo "🚀 Iniciando o carregamento da camada Gold..."

# Por último, executa o script da camada Gold
"$DIR/load_gold_f_order.sh"

echo "✅ Camada Gold carregada com sucesso!"
echo "---------------------------------"
echo "🎉 Pipeline finalizado com sucesso!"
