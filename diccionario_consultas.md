# Diccionario de Consultas

## 1. ⚙️ Preparación del Entorno 
Antes de cualquier cálculo, el sistema inicializa las coordenadas y proyecta el grafo en la memoria RAM (GDS) para garantizar respuestas en tiempo real.

### Paso A: Reseteo de Tráfico
```cypher
MATCH ()-[r:CONECTA_A]-() 
SET r.estado_trafico = 1.0;
```

### Paso B: Proyección en Memoria (GDS)
Este paso cumple con el requisito Plus de la rúbrica: Uso de proyecciones en memoria.
```cypher
CALL gds.graph.drop('logisticsGraph', false);
CALL gds.graph.project(
  'logisticsGraph',
  {
    Almacen: { label: 'Almacen', properties: ['lat', 'lon'] },
    PuntoEntrega: { label: 'PuntoEntrega', properties: ['lat', 'lon'] },
    Interseccion: { label: 'Interseccion', properties: ['lat', 'lon'] }
  },
  { CONECTA_A: { type: 'CONECTA_A', properties: { distancia: { property: 'distancia' }, tiempo_min: { property: 'tiempo_min' } } } }
);
```

## 2. 🛣️ Comparación de Pesos: Distancia vs. Tiempo (Mínimo Entregable)
Esta consulta demuestra que el sistema puede elegir entre la ruta físicamente más corta y la más rápida según el tráfico.
```cypher
MATCH (source:Almacen {id: 1}), (target:PuntoEntrega {nombre: "Tienda Norte"})
CALL gds.shortestPath.dijkstra.stream('logisticsGraph', {
    sourceNode: source, targetNode: target, relationshipWeightProperty: 'distancia'
}) YIELD totalCost AS km
WITH source, target, km
CALL gds.shortestPath.dijkstra.stream('logisticsGraph', {
    sourceNode: source, targetNode: target, relationshipWeightProperty: 'tiempo_min'
}) YIELD totalCost AS minutos
RETURN "Almacén 1 -> Tienda Norte" AS Tramo, km AS `Distancia (KM)`, minutos AS `Tiempo (Minutos)`;
```

## 3. 🔍 Desafío Técnico #1: Dijkstra vs. A* (Heurística)
Comparamos el algoritmo exhaustivo (Dijkstra) frente al algoritmo optimizado por coordenadas (A*).
```cypher
MATCH (source:Almacen {id: 1}), (target:PuntoEntrega {nombre: "Tienda Norte"})
CALL gds.shortestPath.dijkstra.stream('logisticsGraph', {
    sourceNode: source, targetNode: target, relationshipWeightProperty: 'tiempo_min'
}) YIELD totalCost AS costoDijkstra
WITH source, target, costoDijkstra
CALL gds.shortestPath.astar.stream('logisticsGraph', {
    sourceNode: source, targetNode: target, latitudeProperty: 'lat', longitudeProperty: 'lon', relationshipWeightProperty: 'tiempo_min'
}) YIELD totalCost AS costoAStar
RETURN costoDijkstra AS `Dijkstra (Tiempo)`, costoAStar AS `A* (Heurística)`,
CASE WHEN costoDijkstra = costoAStar THEN "Coincidencia Óptima" ELSE "Diferencia" END AS Estado;
```

## 4. 💰 Desafío Técnico #2: Cálculo de Costo Total de Ruta
Implementación de la fórmula de negocio: $$Costo = \sum (distancia \times factor\_trafico)$$.
```cypher
MATCH path = (a:Almacen {id: 1})-[:CONECTA_A*]->(dest:PuntoEntrega)
WITH dest, relationships(path) AS rels
UNWIND rels AS r
WITH dest.nombre AS Destino, sum(r.distancia * r.estado_trafico) AS Costo_Calculado
RETURN Destino, Costo_Calculado ORDER BY Costo_Calculado ASC;
```

## 5. 🛑 Desafío Técnico #3: Restricciones de Carga y Seguridad
Filtro de seguridad que bloquea automáticamente las calles cuya infraestructura no soporta el peso del camión (en este ejemplo, menor a 25t).
```cypher
MATCH (a:Almacen {id: 1})-[r:CONECTA_A]->(dest)
WHERE r.capacidad_max < 25
RETURN dest.nombre AS Punto_No_Apto, r.capacidad_max AS Capacidad_Calle, "BLOQUEADO" AS Estado;
```

## 6. 🗺️ Visualización de Ruta Óptima
Consulta para visualizar la ruta óptima desde un almacén a un punto de entrega.
```cypher
MATCH (source:Almacen {id: 1}), (target:PuntoEntrega {nombre: "Tienda Norte"})
CALL gds.shortestPath.dijkstra.stream('logisticsGraph', {
    sourceNode: source,
    targetNode: target,
    relationshipWeightProperty: 'tiempo_min'
})
YIELD nodeIds
// El truco: Convertimos los IDs de GDS en nodos reales de la BD
UNWIND nodeIds AS nodeId
MATCH (n) WHERE id(n) = nodeId
WITH collect(n) AS nodos
// Buscamos las relaciones entre esos nodos para que Neo4j las dibuje
UNWIND nodos AS n1
UNWIND nodos AS n2
MATCH (n1)-[r:CONECTA_A]->(n2)
RETURN n1, r, n2; 
```
