# 🚚 Logistics Optimizer - Smart Routing (UNEG)

Proyecto III de la asignatura **Sistemas de Bases de Datos II**. Este sistema optimiza la cadena de suministros mediante grafos, permitiendo calcular rutas basadas en distancia, tiempo real y restricciones de carga pesada.

## 🛠️ Tecnologías
- **Base de Datos:** Neo4j 5.x
- **Librerías:** GDS (Graph Data Science) y APOC.
- **Algoritmos:** Dijkstra (Costo mínimo) y A* (Heurística geográfica).

## 🚀 Instalación
1. Importar el archivo `.dump` en Neo4j Desktop o ejecutar `script_carga.cypher`.
2. Asegurarse de tener instalados los plugins **GDS** y **APOC**.
3. Ejecutar las consultas del `diccionario_consultas.md`.

## 📈 Justificación NoSQL (Grafos vs Relacional)
Calcular rutas en SQL requiere múltiples *Joins* recursivos que consumen demasiada CPU. En Neo4j, el cálculo es una navegación de punteros en memoria, lo que permite:
- **Escalabilidad:** Las consultas no se ralentizan al aumentar las intersecciones.
- **Flexibilidad:** Cambiar el factor de tráfico es instantáneo.
- **Algoritmos Nativos:** GDS ya trae Dijkstra optimizado, algo que en SQL habría que programar manualmente.
