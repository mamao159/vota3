# Vota3 — pacote inicial

Este pacote inicia o repositório GitHub Pages e a estrutura do Supabase.

## 1. GitHub
1. Crie um repositório público chamado `vota3`.
2. Extraia este ZIP e envie todo o conteúdo para a raiz do repositório.
3. No GitHub, abra **Settings → Pages**.
4. Em **Build and deployment**, escolha **Deploy from a branch**.
5. Selecione `main` e `/ (root)` e salve.
6. O endereço será `https://SEU-USUARIO.github.io/vota3/`.

## 2. Supabase
1. Crie um projeto novo em https://supabase.com/dashboard.
2. Guarde a senha do banco em local seguro.
3. Abra **SQL Editor → New query**.
4. Copie e execute `supabase/schema.sql`.
5. Em **Project Settings → API**, copie a Project URL e a chave `anon`/publishable.
6. Abra `assets/js/config.js` e substitua os dois valores de exemplo.

**Nunca coloque a chave `service_role` ou `secret` no GitHub, HTML ou JavaScript do navegador.**

## 3. Primeiro teste
Abra a URL do GitHub Pages. Os três ambientes estarão disponíveis pela página inicial.
Nesta etapa, as telas são apenas a estrutura visual. A autenticação, inscrição, aprovação, votação, apuração e atualização ao vivo serão conectadas nas próximas etapas, por Edge Functions seguras.

## Arquitetura de segurança
- O navegador não recebe permissão direta para inserir ou consultar cédulas.
- As tabelas começam com RLS habilitado e sem políticas públicas.
- As operações sensíveis serão feitas por Edge Functions usando a chave secreta apenas no servidor.
- `ballots` não contém identificador do eleitor. `voter_status` registra apenas que a pessoa votou em determinada rodada.
- Para reduzir correlação temporal, a implementação final deverá evitar guardar IP e não deverá expor horários individuais de cédulas.
- Administradores não terão uma tela para consultar a escolha de cada eleitor. Ainda assim, acesso privilegiado ao projeto Supabase pode permitir correlação operacional; isso não equivale a anonimato criptográfico absoluto.

## Observação
O critério de idade usa a data de nascimento cadastrada. A definição de dois finalistas será feita pelo total de votos do 2º escrutínio e, em empate, pela maior idade. Se persistir empate entre pessoas com a mesma data de nascimento, a aplicação deverá interromper a classificação e solicitar um procedimento de desempate definido e registrado pelo administrador.
