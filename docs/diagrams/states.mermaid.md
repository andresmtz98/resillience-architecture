# Diagrama de Estados · Niveles de Servicio

```mermaid
stateDiagram-v2
    direction LR

    [*] --> L1

    state "Nivel 1 · Full" as L1
    state "Nivel 2 · Degraded" as L2
    state "Nivel 3 · Maintenance" as L3

    L1 --> L2: errors ≥ 5 ∧ errors < 10
    L1 --> L3: errors ≥ 10
    L2 --> L3: errors ≥ 10

    L2 --> L1: errors < 5
    L3 --> L2: errors < 10

    L1 --> L1: errors < 5 / no-op
    L2 --> L2: 5 ≤ errors < 10 / no-op
    L3 --> L3: errors ≥ 10 / no-op
```

**Reglas de transición**

Las transiciones se evalúan **al cierre de cada minuto** comparando el número de errores observados durante el minuto recién cerrado contra los umbrales:

```
errors >= 10  → target = Nivel 3
errors >= 5   → target = Nivel 2
errors < 5    → target = Nivel 1
```

| Tipo | Comportamiento | Justificación |
|---|---|---|
| **Degradación** | Salto directo al `target` (puede saltar de 1 a 3) | Reaccionar rápido al deterioro de salud |
| **Recuperación** | Un nivel a la vez (solo `currentLevel - 1`) | El reto exige recuperación gradual |
| **Permanencia** | Sin operación | Ahorra escrituras innecesarias |

**Ejemplo de trayectoria**

| Minuto cerrado | Errores | Nivel previo | Nivel siguiente | Tipo |
|---|---|---|---|---|
| 1 | 5 | 1 | 2 | degrade |
| 2 | 0 | 2 | 1 | recover (gradual) |
| 3 | 15 | 1 | 3 | degrade (salto) |
| 4 | 0 | 3 | 2 | recover (gradual) |
| 5 | 15 | 2 | 3 | degrade |
| 6 | 0 | 3 | 2 | recover (gradual) |
| 7 (sin tráfico) | 0 | 2 | 1 | recover (gradual) |
