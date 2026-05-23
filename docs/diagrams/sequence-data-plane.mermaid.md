# Diagrama de Secuencia · Data Plane (request síncrono)

```mermaid
sequenceDiagram
    autonumber
    actor C as Cliente / k6
    participant API as API Gateway
    participant SFN as Step Functions Express
    participant DDB as DynamoDB<br/>system-state
    participant Lx as Lambda Level X
    participant CW as CloudWatch

    C->>API: POST /service-api<br/>{ message, timestamp, error }
    API->>SFN: StartSyncExecution<br/>{ body: {...} }

    SFN->>DDB: GetItem(id=system)
    DDB-->>SFN: { level, errorCount, ... }

    alt body.error == true
        SFN->>DDB: UpdateItem ADD<br/>error_count_current_minute += 1
        DDB-->>SFN: ok
    end

    Note over SFN: Choice State<br/>RouteByLevel ($.state.Item.level.N)

    alt level == 1
        SFN->>Lx: invoke level_1_full
    else level == 2
        SFN->>Lx: invoke level_2_degraded
    else level == 3
        SFN->>Lx: invoke level_3_maintenance
    end

    Lx-->>CW: PutMetricData<br/>RequestsByLevel{Level=X}
    Lx-->>SFN: { level, message, processed_at }

    SFN-->>CW: execution logs
    SFN-->>API: $.output (Lambda payload)
    API-->>C: 200 OK<br/>{ level, message, ... }

    Note over API,Lx: Si cualquier paso falla,<br/>Catch → FailSafeLevel3 → HardcodedMaintenance Pass
```

**Notas de diseño**

- API Gateway invoca el state machine **síncronamente** vía la integración nativa `states:StartSyncExecution`. No hay Lambda intermedia.
- El conteo de errores ocurre **antes** del routing, garantizando que el request actual ya cuente para la próxima ventana de evaluación.
- `RequestsByLevel` se publica desde la propia Lambda L1/L2/L3 en modo "best-effort" (un fallo en CloudWatch no rompe el request).
- En caso de fallo de cualquier paso, hay tres niveles de defensa: retries con backoff, Catch hacia `FailSafeLevel3` (que reintenta L3), y como último recurso un `Pass` state hardcoded que sintetiza la respuesta de mantenimiento sin invocar Lambda.
