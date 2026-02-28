":begin
CREATE RANGE INDEX FOR (n:Almacen) ON (n.id);
CREATE RANGE INDEX FOR (n:PuntoEntrega) ON (n.id);
CREATE CONSTRAINT UNIQUE_IMPORT_NAME FOR (node:`UNIQUE IMPORT LABEL`) REQUIRE (node.`UNIQUE IMPORT ID`) IS UNIQUE;
:commit
CALL db.awaitIndexes(300);
:begin
UNWIND [{_id:0, properties:{id:1, nombre:"Centro de Distribución A"}}] AS row
CREATE (n:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row._id}) SET n += row.properties SET n:Almacen;
UNWIND [{_id:1, properties:{id:2, nombre:"Tienda Norte"}}, {_id:3, properties:{id:4, nombre:"Tienda Sur"}}] AS row
CREATE (n:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row._id}) SET n += row.properties SET n:PuntoEntrega;
UNWIND [{_id:2, properties:{id:3}}] AS row
CREATE (n:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row._id}) SET n += row.properties SET n:Interseccion;
:commit
:begin
UNWIND [{start: {_id:2}, end: {_id:1}, properties:{tiempo_min:8, capacidad_max:10, distancia:5.0, estado_trafico:2.5}}] AS row
MATCH (start:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.start._id})
MATCH (end:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.end._id})
CREATE (start)-[r:CONECTA_A]->(end) SET r += row.properties;
UNWIND [{start: {_id:0}, end: {_id:2}, properties:{tiempo_min:15, capacidad_max:20, distancia:10.5, estado_trafico:1.2}}] AS row
MATCH (start:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.start._id})
MATCH (end:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.end._id})
CREATE (start)-[r:CONECTA_A]->(end) SET r += row.properties;
UNWIND [{start: {_id:0}, end: {_id:3}, properties:{tiempo_min:25, capacidad_max:30, distancia:20.0, estado_trafico:1.0}}] AS row
MATCH (start:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.start._id})
MATCH (end:`UNIQUE IMPORT LABEL`{`UNIQUE IMPORT ID`: row.end._id})
CREATE (start)-[r:CONECTA_A]->(end) SET r += row.properties;
:commit
:begin
MATCH (n:`UNIQUE IMPORT LABEL`)  WITH n LIMIT 20000 REMOVE n:`UNIQUE IMPORT LABEL` REMOVE n.`UNIQUE IMPORT ID`;
:commit
:begin
DROP CONSTRAINT UNIQUE_IMPORT_NAME;
:commit
"