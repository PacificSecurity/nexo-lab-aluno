# Instalação e uso

## Requisitos

**Docker com Compose v2**, configurado para executar contêineres Linux. No Windows e no macOS, o Docker Desktop já inclui esses componentes. No Linux, instale o Docker Engine e o plugin do Docker Compose. Confirme se estão disponíveis:

```bash
docker info
docker compose version
```

**Terminal com Bash disponível.** No macOS e no Linux, use o terminal do sistema. No Windows, use o WSL com a integração do Docker habilitada ou o Git Bash. Os comandos deste guia não funcionam diretamente no PowerShell nem no Prompt de Comando.

**Arquitetura compatível com as imagens `linux/amd64`.** As imagens são destinadas a processadores Intel ou AMD. Em Macs com Apple Silicon e outras máquinas ARM, elas funcionam por emulação, o que pode tornar a inicialização mais lenta e gerar um aviso de diferença de plataforma. Nos Macs com Apple Silicon, ative a opção de emulação com Rosetta nas configurações do Docker Desktop para melhorar o desempenho.

**Recursos.** Reserve cerca de 3 GB livres em disco e 2 GB de memória para o Docker. O ambiente usa quatro contêineres.

**Porta 8080 livre.** Se ela estiver ocupada, você pode usar outra porta. Veja a seção [Configuração](#configuração).

Depois de baixar as imagens, **o laboratório funciona sem conexão com a internet**. Todos os serviços rodam localmente.

## Iniciar o laboratório

Coloque o `imagens.tar.gz` na pasta do repositório, onde estão o `lab.sh` e o `docker-compose.yml`. Com o Docker em execução, carregue as imagens e inicie o laboratório:

```bash
docker load -i imagens.tar.gz
./lab.sh subir
```

A primeira execução de `docker load` pode levar alguns minutos. Quando o script informar que o laboratório está pronto, abra [http://localhost:8080](http://localhost:8080) e crie sua conta com o código de organização `OCEAN-A-2026`.

Se aparecer um erro de permissão ao executar o script, use `chmod +x lab.sh` e tente novamente.

## Comandos

| Comando | Função |
|---|---|
| `./lab.sh subir` | Inicia os serviços, preservando os dados existentes |
| `./lab.sh parar` | Encerra os serviços, preservando os dados |
| `./lab.sh estado` | Mostra o estado dos contêineres |
| `./lab.sh doutor` | Verifica a disponibilidade dos serviços |
| `./lab.sh reiniciar` | Recria os contêineres, preservando os dados |
| `./lab.sh resetar` | Apaga os dados e restaura o cenário, após confirmação |
| `./lab.sh logs` | Exibe os logs em tempo real; pressione `Ctrl+C` para encerrar a visualização |
| `./lab.sh apagar` | Remove os contêineres e os dados, após confirmação |

Use o script para iniciar e reiniciar o ambiente, pois ele mantém os serviços conectados entre si. O laboratório não inicia automaticamente quando você liga o computador.

## Configuração

O arquivo `.env` contém a configuração local. Se a porta 8080 estiver ocupada, altere `APP_PORT` e execute `./lab.sh reiniciar`. Seus dados serão mantidos. Use a nova porta no navegador e no proxy de interceptação.

Para praticar com outros identificadores, altere `LAB_SEED`, execute `./lab.sh apagar` e depois `./lab.sh subir`. Esse procedimento apaga os dados existentes, elimina o progresso anterior e cria um novo cenário.

## Prática

O cenário contém dezessete vulnerabilidades relacionadas a exposição de informações, autenticação, controle de acesso, lógica de negócio, XSS e SSRF. Parte dessas falhas pode ser combinada em quatro cadeias de ataque. Procure relacionar os achados e avaliar o impacto que eles permitem alcançar em conjunto.

Não há flags para coletar. Use os objetivos definidos no [ESCOPO.md](ESCOPO.md) para orientar sua análise e documentar os resultados.

Quando quiser conferir seus achados ou precisar de ajuda para avançar, consulte a solução completa em [WRITEUP.md](WRITEUP.md).

## Problemas comuns

- **Docker indisponível:** inicie o Docker e execute `docker info` e `docker compose version` para verificar se ele está disponível.
- **Imagem não encontrada:** carregue o arquivo `imagens.tar.gz` correspondente à versão dos scripts que você está usando.
- **Aviso de plataforma ou inicialização muito lenta:** isso pode ocorrer em máquinas ARM, que executam as imagens `linux/amd64` por emulação. Nos Macs com Apple Silicon, ative a opção de emulação com Rosetta no Docker Desktop. Aguarde a conclusão de `./lab.sh subir`.
- **Serviço indisponível:** execute `./lab.sh reiniciar`. Se o problema persistir, consulte os logs com `./lab.sh logs`.
- **Cadastro recusado:** confira o código de organização e verifique se o limite de contas foi atingido. Se precisar restaurar o cenário, lembre-se de que essa ação apaga as contas criadas e os demais dados da prática.

## Encerrar o laboratório

Execute `./lab.sh parar` ao terminar. O ambiente é intencionalmente vulnerável e deve permanecer acessível apenas na sua máquina. Mantenha a configuração de acesso em `127.0.0.1` e não exponha o laboratório por túneis ou encaminhamento de portas.
