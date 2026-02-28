# proyecto-logistics-optimizer



1. Búsqueda de Rutas con Restricción de Carga (Uso de WITH)
   Esta consulta filtra calles que no soportan el peso del camión en tiempo real.
    MATCH (a:Almacen {id: 1})-[r:CONECTA_A]->(dest)
    WHERE r.capacidad_max >= 15 
    WITH dest, (r.distancia * r.estado_trafico) AS costo_dinamico
    RETURN dest.nombre AS Destino, costo_dinamico AS Costo
    ORDER BY costo_dinamico ASC;

2. Actualización Masiva de Tráfico (Uso de UNWIND)
   Simula la recepción de datos de una API de tráfico para actualizar el grafo.
    UNWIND [{id: 3, nuevo_trafico: 0.9}, {id: 1, nuevo_trafico: 0.2}] AS data
    MATCH ()-[r:CONECTA_A {id: data.id}]->()
    SET r.estado_trafico = data.nuevo_trafico
    RETURN count(r) AS RelacionesActualizadas;

3. Comparación de Ruta Corta vs. Ruta Rápida (Requisito Mínimo)
   Compara Dijkstra basado en distancia frente a un peso que incluye estado_trafico.
   // Primero calculamos por distancia pura
   CALL gds.shortestPath.dijkstra.stream('logisticsGraph', {
      sourceNode: 0, 
      targetNode: 2, 
      relationshipWeightProperty: 'distancia'
   }) YIELD totalCost RETURN "Dijkstra Distancia" AS Tipo, totalCost;

   // Luego comparamos con el factor tiempo/tráfico
   CALL gds.shortestPath.dijkstra.stream('logisticsGraph', {
      sourceNode: 0, 
      targetNode: 2, 
      relationshipWeightProperty: 'tiempo_min' // O una propiedad calculada
   }) YIELD totalCost RETURN "Dijkstra Tiempo" AS Tipo, totalCost;

4. Filtrado Avanzado de Caminos (Uso de Patrones Variable)
   Busca todos los puntos de entrega alcanzables desde un almacén en máximo 3 saltos.
   MATCH (a:Almacen {id: 1})-[r:CONECTA_A*1..3]->(p:PuntoEntrega)
    RETURN p.nombre, p.id, count(r) AS Saltos
    ORDER BY Saltos ASC;

5. Cálculo de Costo Total de Ruta (Uso de Funciones GDS)Calcula el costo total sumando las propiedades dinámicas de las aristas según la fórmula: $distancia \times factor\_trafico$.
   MATCH path = (a:Almacen {id: 1})-[:CONECTA_A*]->(b:PuntoEntrega {id: 4})
    WITH path, relationships(path) AS rels
    UNWIND rels AS r
    WITH path, sum(r.distancia * r.estado_trafico) AS costo_logistico
   RETURN nodes(path) AS Ruta, costo_logistico
   LIMIT 1;
