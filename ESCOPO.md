# Solicitação de teste de intrusão — Nexo Supply

**Cliente:** Nexo Supply Tecnologia Ltda.

**Contato técnico:** operacoes@nexosupply.example

**Modalidade:** teste de intrusão em aplicação web, no modelo de caixa-preta (black box), com credenciais de colaborador obtidas por autocadastro.

---

## 1. Contexto

A Nexo Supply opera um marketplace corporativo de suprimentos usado por colaboradores de diferentes empresas parceiras. Cada organização publica itens no catálogo compartilhado, compra de outros participantes e administra as permissões de acesso de seus colaboradores e sua carteira de créditos.

A plataforma passou recentemente por uma migração de catálogo e por uma revisão do modelo de permissões administrativas. Antes de ampliar o número de organizações atendidas, a diretoria contratou uma avaliação de segurança da aplicação.

O objetivo é verificar se um colaborador comum, com acesso legítimo a uma das organizações, consegue:

- acessar dados de colaboradores de outras organizações;
- assumir o controle de contas de outros usuários;
- obter permissões administrativas que não lhe foram concedidas;
- interferir no resultado financeiro de uma transação;
- alcançar recursos internos da plataforma.

---

## 2. Escopo autorizado

Use o endereço abaixo como ponto de entrada. Se você alterou a porta no arquivo `.env`, substitua `8080` pela porta configurada:

```
http://localhost:8080
```

Os testes abrangem a aplicação e os serviços internos que possam ser acessados por meio de suas funcionalidades. A máquina hospedeira, os demais contêineres, a rede local e os serviços externos estão fora do escopo.

---

## 3. Categorias autorizadas

Os testes devem se limitar às seguintes categorias:

- **Information Disclosure** — exposição de informações sensíveis
- **Authentication** — falhas no processo de autenticação
- **Authorization / Access Control** — falhas de controle de acesso
- **Business Logic** — falhas na lógica de negócio
- **Cross-Site Scripting (XSS)** — refletido e armazenado
- **Server-Side Request Forgery (SSRF)**

---

## 4. Restrições

É expressamente proibido:

- executar scanners automatizados de vulnerabilidade;
- realizar ataques de força bruta de credenciais;
- realizar credential stuffing (tentativas de acesso com combinações de usuário e senha obtidas de outras fontes);
- realizar ataques de negação de serviço, testes de carga ou testes de estresse;
- explorar a infraestrutura do ambiente;
- testar endereços ou serviços fora do escopo;
- executar ataques fora das categorias autorizadas;
- destruir, corromper ou tornar indisponíveis os dados da aplicação.

---

## 5. Acesso

A Nexo Supply fornece o seguinte código para você criar sua conta na organização inicial do exercício, a Meridiano Suprimentos:

```
OCEAN-A-2026
```

Crie sua conta pela tela de cadastro. O contrato prevê um número limitado de contas; crie apenas as necessárias para realizar o trabalho.

Nenhuma outra credencial será fornecida.

---
