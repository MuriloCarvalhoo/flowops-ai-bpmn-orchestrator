# Web Modeler — Element Templates pré-instalados

Todo `*.json` desta pasta é enviado, no `docker compose up`, ao projeto
`Bundled Templates` no Web Modeler self-managed pelo service
`web-modeler-template-seeder` (ver `docker-compose.yml`).

O upload é idempotente: o seeder pula arquivos cujo `name` já existe no projeto.

Pra adicionar mais templates, baixe o JSON do repositório
`camunda/connectors` (pasta `connectors/<área>/element-templates/`) e
coloque aqui. Reinicie:

    docker compose up -d web-modeler-template-seeder

Logs:

    docker compose logs web-modeler-template-seeder
