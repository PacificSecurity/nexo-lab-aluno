# Nexo Supply

Laboratório de segurança de aplicações web para você praticar na própria máquina. A aplicação simula um marketplace corporativo B2B (de empresas para empresas), com catálogo compartilhado entre organizações, fila de revisão de itens, carrinho, finalização de compras, carteira de créditos e painéis de administração.

São dezessete vulnerabilidades inseridas intencionalmente, distribuídas entre exposição de informações, autenticação, controle de acesso, lógica de negócio, XSS e SSRF. Parte dessas falhas pode ser combinada em quatro cadeias de ataque que, em sequência, levam de uma conta recém-criada ao acesso a dados de faturamento armazenados em um serviço interno. Não há flags (códigos para coletar como prova de exploração): o objetivo é identificar e documentar as falhas e seus impactos.

## Origem do laboratório

Este é o ambiente usado na atividade em grupo do processo seletivo de 2026. Cada grupo recebeu uma instância própria, teve um período para explorar a aplicação e, ao final, apresentou o que encontrou.

Para quem participou, o laboratório é uma oportunidade de conhecer todas as falhas do cenário e compará-las com os achados do grupo. Para quem não participou, é um ambiente para praticar do zero, no próprio ritmo.

Quem fez a atividade encontrará nomes de usuário, identificadores e códigos diferentes dos usados na ocasião. Esses valores são gerados a partir de uma semente de configuração, definida em `LAB_SEED`, que varia entre as instâncias. A estrutura do cenário permanece a mesma.

## Requisitos

- **Docker com Compose v2**, configurado para executar contêineres Linux. Use o Docker Desktop no Windows e no macOS; no Linux, use o Docker Engine com o plugin do Compose.
- **Terminal com Bash disponível.** No Windows, use o WSL ou o Git Bash. Os comandos deste guia não funcionam diretamente no PowerShell nem no Prompt de Comando.
- **Arquitetura compatível com as imagens `linux/amd64`.** Elas são destinadas a processadores Intel ou AMD. Em Macs com Apple Silicon e outras máquinas ARM, funcionam por emulação, com possível perda de desempenho. Nos Macs com Apple Silicon, ative a opção de emulação com Rosetta no Docker Desktop.
- **Cerca de 3 GB livres em disco e 2 GB de memória disponíveis para o Docker**, além da porta 8080 livre.

Com o Docker instalado e o pacote baixado, você pode usar o laboratório sem conexão com a internet.

O [guia de instalação e uso](LEIA-ME.md) detalha esses requisitos e explica como verificá-los.

## Instalação

Baixe o pacote, caso ainda não o tenha:

**[nexo-lab-aluno-amd64.tar.gz](https://atividade-preselec-pacsec.s3.us-east-1.amazonaws.com/nexo-lab-aluno-amd64.tar.gz)** — aproximadamente 218 MB

```
SHA-256  160f49a597720382278cbb020dcb78cf4d31b9c4c462ebf695dd48be2255a818
MD5      19b8a9133d696f55d1bca0d88534ff23
```

Antes de extrair o pacote, confira se o hash SHA-256 corresponde ao valor acima:

```bash
shasum -a 256 nexo-lab-aluno-amd64.tar.gz
```

Se preferir conferir o MD5, use o comando abaixo no Linux ou no WSL:

```bash
md5sum nexo-lab-aluno-amd64.tar.gz
```

No macOS, o comando equivalente é `md5 nexo-lab-aluno-amd64.tar.gz`.

Extraia e entre na pasta `lab`:

```bash
tar -xzf nexo-lab-aluno-amd64.tar.gz
cd lab
```

Com o Docker em execução, carregue as imagens e inicie o laboratório:

```bash
docker load -i imagens.tar.gz
./lab.sh subir
```

Abra [http://localhost:8080](http://localhost:8080) e crie sua conta com o código de organização **OCEAN-A-2026**.

## Documentos

- [LEIA-ME.md](LEIA-ME.md) — instalação, comandos do `lab.sh`, configuração e problemas comuns.
- [ESCOPO.md](ESCOPO.md) — solicitação de teste de intrusão, com objetivos, categorias autorizadas e restrições. Leia antes de começar os testes.
- [WRITEUP.md](WRITEUP.md) — **solução completa**, com as vulnerabilidades e as cadeias de ataque.

## Sobre a solução (writeup)

O writeup lista as dezessete vulnerabilidades, mostra como identificar cada uma e detalha as quatro cadeias de ataque. Você pode usá-lo para conferir seus achados, retomar a análise quando tiver dificuldade para avançar ou estudar o cenário com o apoio dos exemplos.

Se quiser praticar a descoberta das falhas, tente explorar a aplicação antes de consultar a solução. Assim, você aproveita o exercício e depois pode comparar seu raciocínio com os caminhos apresentados.

## Aviso

A aplicação é intencionalmente vulnerável e está configurada para ficar acessível apenas na sua máquina, pelo endereço `127.0.0.1`. Mantenha essa configuração no `docker-compose.yml`, não exponha o laboratório por túneis ou encaminhamento de portas e não o disponibilize em uma rede corporativa.

O ambiente não inicia automaticamente quando você liga o computador. Depois de reiniciar a máquina, execute `./lab.sh subir` novamente.
