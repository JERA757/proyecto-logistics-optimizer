// 1. Asignar coordenadas base a todos los nodos del sistema
MATCH (n:Almacen) SET n.lat = 7.3, n.lon = -62.6;
MATCH (n:PuntoEntrega) SET n.lat = 7.4, n.lon = -62.5;
MATCH (n:Interseccion) SET n.lat = 7.35, n.lon = -62.55;
// Borrar la proyección anterior si existe para limpiar la RAM
CALL gds.graph.drop('logisticsGraph', false);

// Proyectar el grafo usando la sintaxis de mapa (Full Configuration)
CALL gds.graph.project(
  'logisticsGraph',
  {
    Almacen: { label: 'Almacen', properties: ['lat', 'lon'] },
    PuntoEntrega: { label: 'PuntoEntrega', properties: ['lat', 'lon'] },
    Interseccion: { label: 'Interseccion', properties: ['lat', 'lon'] }
  },
  {
    CONECTA_A: {
      type: 'CONECTA_A',
      properties: {
        distancia: { property: 'distancia' },
        tiempo_min: { property: 'tiempo_min' }
      }
    }
  }
);
MATCH (source:Almacen {id: 1}), (target:PuntoEntrega {nombre: "Tienda Norte"})
// Cálculo 1: Distancia
CALL gds.shortestPath.dijkstra.stream('logisticsGraph', {
    sourceNode: source, targetNode: target, relationshipWeightProperty: 'distancia'
}) YIELD totalCost AS km
// Cálculo 2: Tiempo
WITH source, target, km
CALL gds.shortestPath.dijkstra.stream('logisticsGraph', {
    sourceNode: source, targetNode: target, relationshipWeightProperty: 'tiempo_min'
}) YIELD totalCost AS minutos
RETURN 
    "Almacén 1 -> Tienda Norte" AS Tramo,
    km AS `Distancia (KM)`, 
    minutos AS `Tiempo (Minutos)`,
    "Dijkstra" AS Algoritmo;
// Desafío 1: Comparación Directa Dijkstra vs A*
MATCH (source:Almacen {id: 1}), (target:PuntoEntrega {nombre: "Tienda Norte"})
CALL gds.shortestPath.dijkstra.stream('logisticsGraph', {
    sourceNode: source,
    targetNode: target,
    relationshipWeightProperty: 'tiempo_min'
}) YIELD totalCost AS costoDijkstra

WITH source, target, costoDijkstra
CALL gds.shortestPath.astar.stream('logisticsGraph', {
    sourceNode: source,
    targetNode: target,
    latitudeProperty: 'lat',
    longitudeProperty: 'lon',
    relationshipWeightProperty: 'tiempo_min'
}) YIELD totalCost AS costoAStar

RETURN 
    "Ruta a Tienda Norte" AS Trayecto,
    costoDijkstra AS `Dijkstra (Tiempo)`, 
    costoAStar AS `A* (Heurística)`,
    CASE WHEN costoDijkstra = costoAStar THEN "Coincidencia Óptima" ELSE "Diferencia" END AS Estado;
MATCH path = (a:Almacen {id: 1})-[:CONECTA_A*]->(dest:PuntoEntrega)
WITH dest, relationships(path) AS rels
UNWIND rels AS r
WITH dest.nombre AS Destino, sum(r.distancia * r.estado_trafico) AS Costo_Calculado
RETURN Destino, Costo_Calculado
ORDER BY Costo_Calculado ASC;
MATCH (a:Almacen {id: 1})-[r:CONECTA_A]->(dest)
WHERE r.capacidad_max < 25
RETURN dest.nombre AS Punto_No_Apto, r.capacidad_max AS Capacidad_Calle, "BLOQUEADO" AS Estado;
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