# Diagrama de Secuencia · Control Plane (ciclo de evaluación cada minuto)

```mermaid
sequenceDiagram
    autonumber
    participant EB as EventBridge<br/>cron(* * * * ? *)
    participant EVAL as Lambda<br/>Level Evaluator
    participant DDB as DynamoDB<br/>system-state
    participant CW as CloudWatch

    Note over EB: Tick al :00 de cada minuto UTC

    EB->>EVAL: trigger
    EVAL->>DDB: GetItem(id=system)
    DDB-->>EVAL: { level, errorCount, currentMinuteStart, errorsLastMinute }

    Note over EVAL: now = Date.now()<br/>currentMinuteNow = floor(now/60000)*60000

    alt currentMinuteStart < currentMinuteNow (minuto cerrado)
        EVAL->>DDB: UpdateItem<br/>SET errors_last_minute = errorCount,<br/>error_count_current_minute = 0,<br/>current_minute_start = currentMinuteNow<br/>IF current_minute_start = expected
        DDB-->>EVAL: ok / ConditionalCheckFailed (idempotente)
        Note over EVAL: log "Minute rolled over"
    end

    Note over EVAL: target = resolveTargetLevel(errorsLastMinute)<br/>errors >= 10 → 3<br/>errors >= 5  → 2<br/>errors < 5   → 1

    alt target > currentLevel (degradación, salto directo)
        EVAL->>DDB: UpdateItem SET level = target
        EVAL->>CW: PutMetricData<br/>LevelTransition{From=current, To=target}<br/>ServiceLevel = target
    else target < currentLevel (recuperación, gradual)
        Note over EVAL: newLevel = currentLevel - 1
        EVAL->>DDB: UpdateItem SET level = newLevel
        EVAL->>CW: PutMetricData<br/>LevelTransition{From=current, To=newLevel}<br/>ServiceLevel = newLevel
    else target == currentLevel
        Note over EVAL: log "No transition applies"
        EVAL->>CW: PutMetricData<br/>ServiceLevel = currentLevel<br/>(gauge continuo)
    end
```

**Propiedades clave**

- **Idempotencia del rollover**: la `ConditionExpression` sobre `current_minute_start` previene rollovers duplicados si el evaluador se ejecuta dos veces en el mismo minuto.
- **Atomicidad del estado**: cada cambio de nivel es una operación atómica en DynamoDB.
- **Independencia del path de request**: aunque el evaluador no se ejecute (por ejemplo por un fallo aislado), el data plane sigue sirviendo requests con el último nivel conocido. La pérdida de un tick solo retrasa el cambio, no lo bloquea.
- **Gauge continuo**: la métrica `ServiceLevel` se publica en cada evaluación (haya o no transición), garantizando una serie temporal completa para dashboards.
