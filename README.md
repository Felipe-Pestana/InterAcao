# InterAcao
Script de instalação de softwares do treinamento

Características do script:

✅ Verificação de dependências: Verifica e instala o winget se necessário

✅ Tratamento de erros: Robusto com tratamento completo de erros

✅ Parametrização: Permite customizar a lista de aplicativos

✅ Relatório detalhado: Mostra sucesso/falha de cada instalação

✅ Verificação de privilégios: Alerta sobre execução como administrador

✅ Repositórios oficiais: Usa apenas fontes oficiais e verificadas

✅ Interface amigável: Output colorido e informativo

✅ Configurações pós-instalação: Dicas para configuração dos aplicativos


## Como Executar

Clone o repositório

```bash
  git clone https://github.com/Felipe-Pestana/InterAcao/
```

Abra o diretório do repo

```bash
  cd InterAcao
```

Execute o script

```bash
  .\Install-DevApps.ps1
```
Caso ocorra algum erro na execução, execute o comando abaixo como adiministrador no Terminal:

```bash
    Set-ExecutionPolicy Unrestricted
```

## Aprimoramentos

🔄 Sistema de Atualizações
- Verificação automática: Para aplicativos já instalados, verifica se há atualizações
- Atualização inteligente: Se houver atualizações, executa automaticamente
- Status detalhado: Diferencia entre "já atualizado" e "atualização realizada"

📊 Relatório Aprimorado

- Status específicos: Instalado, Atualizado, Já Atualizado, Falha, Pulado
- Contadores detalhados: Mostra quantidade de cada tipo de operação
- Taxa de sucesso: Calcula e exibe percentual de sucesso geral
