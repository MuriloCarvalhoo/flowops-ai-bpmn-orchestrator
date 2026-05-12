# FlowOps AI BPMN Orchestrator

> Plataforma experimental para orquestração de incidentes corporativos usando BPMN, Camunda, microserviços e IA.

## Visão geral

O **FlowOps AI BPMN Orchestrator** é um projeto backend-first criado para simular a gestão de incidentes críticos em ambientes corporativos.

A proposta é demonstrar como processos de negócio podem ser modelados, executados, monitorados e automatizados usando uma arquitetura moderna baseada em:

- BPMN
- Camunda 8 / Zeebe
- Java + Spring Boot
- Microserviços
- Eventos assíncronos
- IA para triagem e apoio à decisão
- Observabilidade
- Docker
- CI/CD

O projeto foi pensado para simular cenários reais de empresas que precisam lidar com processos complexos, integração entre sistemas, automação, governança e escalabilidade.

---

## Problema

Empresas com operações críticas precisam tratar incidentes com rapidez, rastreabilidade e padronização.

Exemplos:

- suspeita de fraude em transação financeira;
- falha em pagamento;
- indisponibilidade de serviço;
- atraso logístico;
- abertura de chamado crítico;
- divergência cadastral;
- exceções em processos de onboarding.

Em muitos cenários, esses fluxos dependem de múltiplos sistemas, decisões humanas, aprovações, notificações, validações e regras de negócio.

O objetivo do FlowOps é demonstrar como esses processos podem ser orquestrados de ponta a ponta usando BPMN e automação inteligente.

---

## Objetivo do projeto

Criar uma plataforma que permita:

1. Registrar incidentes corporativos.
2. Classificar automaticamente o incidente com apoio de IA.
3. Iniciar um workflow BPMN no Camunda.
4. Executar etapas automatizadas por microserviços.
5. Permitir intervenção humana quando necessário.
6. Monitorar status, SLA e gargalos.
7. Gerar histórico auditável do processo.
8. Expor métricas técnicas e operacionais.

---

## Principais funcionalidades

### Gestão de incidentes

- Criação de incidentes via API REST.
- Consulta de incidentes por status, categoria e severidade.
- Histórico de eventos do incidente.
- Associação entre incidente e instância de processo BPMN.

### Classificação com IA

- Classificação automática de:
  - categoria;
  - severidade;
  - risco;
  - sugestão de próxima ação.
- Explicação textual da decisão sugerida.
- Fallback para classificação baseada em regras.

### Orquestração BPMN

- Processo BPMN versionado no repositório.
- Execução com Camunda 8.
- Service tasks para etapas automatizadas.
- User tasks para decisões manuais.
- Gateways para decisão por severidade e risco.
- Eventos de timeout para controle de SLA.

### Automação de etapas

- Validação de dados do incidente.
- Priorização automática.
- Simulação de análise de risco.
- Notificação de responsáveis.
- Escalonamento por SLA.
- Encerramento com causa raiz.

### Observabilidade

- Logs estruturados.
- Métricas de execução.
- Tempo médio por etapa.
- Taxa de incidentes por severidade.
- Incidentes dentro e fora do SLA.
- Health checks dos serviços.

---

## Arquitetura proposta

```mermaid
flowchart TD
    A[Frontend React] --> B[API Gateway / Incident API]
    B --> C[Incident Service]
    C --> D[(PostgreSQL)]
    C --> E[AI Classification Service]
    C --> F[Camunda 8 / Zeebe]
    F --> G[Validation Worker]
    F --> H[Risk Analysis Worker]
    F --> I[Notification Worker]
    F --> J[Human Approval Task]
    C --> K[Event Broker]
    K --> L[Metrics Service]
    L --> M[Dashboard]