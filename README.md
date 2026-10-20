# ToggleMaster - Ambiente Unificado Docker Compose

Este repositório unifica e orquestra a stack completa dos microsserviços do projeto **ToggleMaster**:
- **`auth-service`**: Serviço de autenticação em Go (porta `8001`).
- **`flag-service`**: Serviço de Feature Flags em Python/Flask (porta `8002`).
- **`targeting-service`**: Serviço de regras de segmentação em Python/Flask (porta `8003`).
- **`evaluation-service`**: Serviço de avaliação ("hot path") com cache em Go (porta `8004`).
- **`analytics-service`**: Worker de eventos e métricas com AWS SQS / DynamoDB em Python (porta `8005`).
- **`postgres-db`**: Banco de dados PostgreSQL 16 (porta `5432`), provisionando automaticamente os bancos `auth_db`, `flags_db` e `targeting_db` com seus respectivos schemas.
- **`redis-cache`**: Cache em memória Redis 7 (porta `6379`) para avaliações de alta velocidade.

---

## 📁 Estrutura de Arquivos Criada

Todos os arquivos dos 5 repositórios originais foram mantidos intactos:
```text
.
├── docker-compose.yml       # Orquestração de todos os 5 microsserviços, Redis e PostgreSQL
├── .env                     # Variáveis de ambiente configuradas
├── .env.example             # Modelo documentado das variáveis de ambiente
├── .dockerignore            # Otimização de build
├── docker/
│   ├── Dockerfile.auth      # Build Go para o auth-service
│   ├── Dockerfile.flag      # Build Python para o flag-service
│   ├── Dockerfile.targeting # Build Python para o targeting-service
│   ├── Dockerfile.evaluation# Build Go para o evaluation-service
│   ├── Dockerfile.analytics # Build Python para o analytics-service
│   └── init-db.sh           # Script de inicialização idempotente (auth_db, flags_db, targeting_db)
├── auth-service/            # Repositório original Go
├── flag-service/            # Repositório original Python
├── targeting-service/       # Repositório original Python
├── evaluation-service/      # Repositório original Go
└── analytics-service/       # Repositório original Python
```

---

## 🚀 Como Executar o Ambiente

Quando desejar subir os contêineres:

```bash
docker compose up --build -d
```

Para verificar o status e healthcheck dos contêineres:

```bash
docker compose ps
```

Para visualizar os logs:

```bash
docker compose logs -f
```

Para encerrar o ambiente:

```bash
docker compose down
```

*(Observação: Se for recriar os bancos de dados do zero, use `docker compose down -v`)*

---

## 🧪 Testando os Serviços (Conforme os READMEs)

### 1. `auth-service` (Porta 8001)

1. **Health Check:**
   ```bash
   curl http://localhost:8001/health
   # Retorno: {"status":"ok"}
   ```

2. **Criar Chave de API de Serviço:**
   ```bash
   curl -X POST http://localhost:8001/admin/keys \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer admin-secreto-123" \
     -d '{"name": "service-key"}'
   ```
   *(Copie a chave retornada no campo `"key"` como `SUA_CHAVE_API`)*

3. **Validar a chave:**
   ```bash
   curl http://localhost:8001/validate \
     -H "Authorization: Bearer <SUA_CHAVE_API>"
   # Retorno: {"message":"Chave válida"}
   ```

---

### 2. `flag-service` (Porta 8002)

1. **Health Check:**
   ```bash
   curl http://localhost:8002/health
   # Retorno: {"status":"ok"}
   ```

2. **Criar Flag `enable-new-dashboard`:**
   ```bash
   curl -X POST http://localhost:8002/flags \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer <SUA_CHAVE_API>" \
     -d '{
       "name": "enable-new-dashboard",
       "description": "Ativa o novo dashboard para usuários",
       "is_enabled": true
     }'
   ```

3. **Listar Flags:**
   ```bash
   curl http://localhost:8002/flags \
     -H "Authorization: Bearer <SUA_CHAVE_API>"
   ```

---

### 3. `targeting-service` (Porta 8003)

1. **Health Check:**
   ```bash
   curl http://localhost:8003/health
   # Retorno: {"status":"ok"}
   ```

2. **Criar Regra de Segmentação (50% dos usuários):**
   ```bash
   curl -X POST http://localhost:8003/rules \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer <SUA_CHAVE_API>" \
     -d '{
       "flag_name": "enable-new-dashboard",
       "is_enabled": true,
       "rules": {
         "type": "PERCENTAGE",
         "value": 50
       }
     }'
   ```

3. **Consultar Regra Criada:**
   ```bash
   curl http://localhost:8003/rules/enable-new-dashboard \
     -H "Authorization: Bearer <SUA_CHAVE_API>"
   ```

---

### 4. `evaluation-service` (Porta 8004)

> **Nota:** Adicione a chave criada no passo 1 ao arquivo `.env` no campo `SERVICE_API_KEY=<SUA_CHAVE_API>` para que o `evaluation-service` consiga consultar o `flag-service` e `targeting-service`.

1. **Health Check:**
   ```bash
   curl http://localhost:8004/health
   # Retorno: {"status":"ok"}
   ```

2. **Avaliar Flag para Usuário 1:**
   ```bash
   curl "http://localhost:8004/evaluate?user_id=user-123&flag_name=enable-new-dashboard"
   # Retorno: {"flag_name":"enable-new-dashboard","user_id":"user-123","result":true}
   ```

3. **Avaliar Flag para Usuário 2:**
   ```bash
   curl "http://localhost:8004/evaluate?user_id=user-abc&flag_name=enable-new-dashboard"
   # Retorno: {"flag_name":"enable-new-dashboard","user_id":"user-abc","result":false}
   ```

4. **Verificar Cache Redis:**
   Ao repetir a mesma chamada, a resposta virá do cache com log `"Cache HIT"`.

---

### 5. `analytics-service` (Porta 8005)

1. **Health Check:**
   ```bash
   curl http://localhost:8005/health
   # Retorno: {"status":"ok"}
   ```

2. **Integração AWS SQS / DynamoDB:**
   Configure suas credenciais da AWS em `.env` (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_SQS_URL`, etc.). O worker consome os eventos enfileirados pelo `evaluation-service` e grava na tabela DynamoDB (`ToggleMasterAnalytics`).
