# Diagrama de Componentes

```mermaid
flowchart LR
    Client([Cliente / k6])

    subgraph AWS[AWS Cloud · us-east-1]
        direction LR

        subgraph Data[Data Plane · síncrono]
            direction LR
            APIGW[API Gateway REST<br/>POST /prod/service-api]
            SFN[[Step Functions Express<br/>router]]
            DDB[(DynamoDB<br/>system-state)]
            L1[Lambda Level 1<br/>Full]
            L2[Lambda Level 2<br/>Degraded]
            L3[Lambda Level 3<br/>Maintenance]
        end

        subgraph Control[Control Plane · asíncrono]
            direction LR
            EB[EventBridge<br/>cron * * * * ? *]
            EVAL[Lambda Level Evaluator]
        end

        CW[CloudWatch<br/>Logs + Metrics]
    end

    Client -->|POST JSON| APIGW
    APIGW -->|StartSyncExecution| SFN
    SFN <-->|GetItem · UpdateItem ADD| DDB
    SFN -->|invoke level| L1
    SFN -->|invoke level| L2
    SFN -->|invoke level| L3

    EB -->|trigger 1/min| EVAL
    EVAL <-->|rollover · transition| DDB

    L1 -.->|RequestsByLevel| CW
    L2 -.->|RequestsByLevel| CW
    L3 -.->|RequestsByLevel| CW
    EVAL -.->|ServiceLevel · LevelTransition| CW
    SFN -.->|execution logs| CW

    classDef compute fill:#ED7100,stroke:#232F3E,color:#fff
    classDef integration fill:#E7157B,stroke:#232F3E,color:#fff
    classDef storage fill:#3334B9,stroke:#232F3E,color:#fff
    classDef obs fill:#7AA116,stroke:#232F3E,color:#fff

    class L1,L2,L3,EVAL compute
    class APIGW,SFN,EB integration
    class DDB storage
    class CW obs
```

**Convenciones**

- Líneas continuas: invocaciones síncronas en el path del request
- Líneas punteadas: emisión asíncrona de logs/métricas (no bloquea)
- Doble flecha: lectura y escritura

**Lectura del diagrama**

El sistema se organiza en dos planos que comparten un único punto de coordinación: la tabla `system-state` en DynamoDB.

- **Data Plane** atiende requests del cliente. API Gateway delega en una máquina de estados Express que decide a qué nivel enrutar leyendo el estado actual y, si el request reporta error, lo cuenta atómicamente en DynamoDB antes de invocar la Lambda correspondiente.
- **Control Plane** observa y decide. Cada minuto al segundo `:00` UTC, EventBridge dispara al Level Evaluator, que cierra la ventana del minuto anterior y aplica la regla de transición.

CloudWatch recibe logs de ejecución del state machine y métricas custom de los componentes que las emiten.
