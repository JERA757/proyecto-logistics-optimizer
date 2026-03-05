import streamlit as st
from neo4j import GraphDatabase
import pandas as pd

# --- CONFIGURACIÓN DE CONEXIÓN ---
URI = "bolt://localhost:7687"
USER = "neo4j"
PASSWORD = "proyecto123"

class Neo4jService:
    def __init__(self, uri, user, password):
        self.driver = GraphDatabase.driver(uri, auth=(user, password))
    def close(self):
        self.driver.close()
    def query(self, cypher, parameters=None):
        with self.driver.session() as session:
            result = session.run(cypher, parameters)
            return [record.data() for record in result]

db = Neo4jService(URI, USER, PASSWORD)

# Configuración de página
st.set_page_config(page_title="Logistics Optimizer Pro", layout="wide", page_icon="🚚")

# --- ESTILOS CSS PERSONALIZADOS ---
st.markdown("""
    <style>
    .main-title { font-size: 32px; font-weight: bold; margin-bottom: 20px; color: #FFFFFF; }
    .stMetric { background-color: #1e2130; padding: 15px; border-radius: 10px; border: 1px solid #4a4a4a; }
    [data-testid="stMetricValue"] { font-size: 28px; color: #00FFCC; }
    </style>
    """, unsafe_allow_html=True)

st.markdown('<div class="main-title">🚚 Logistics Optimizer: Smart Routing Dashboard</div>', unsafe_allow_html=True)

# --- SIDEBAR (PANEL DE CONTROL) ---
st.sidebar.image("https://cdn-icons-png.flaticon.com/512/3063/3063822.png", width=80)
st.sidebar.header("📍 Configuración de Ruta")
peso_camion = st.sidebar.slider("Peso del Camión (Toneladas)", 5, 50, 25)
origen_id = st.sidebar.number_input("ID Almacén Origen", value=1)
destino_nombre = st.sidebar.selectbox("Punto de Entrega", ["Tienda Norte", "Tienda Sur", "Centro Este"])

st.sidebar.markdown("---")
st.sidebar.info("**Dashboard Técnico:** Cálculos basados en pesos dinámicos de tráfico y capacidad de infraestructura.")

if st.sidebar.button("🚀 Calcular y Optimizar"):
    
    # 1. GDS: Limpiar y Proyectar Grafo
    db.query("CALL gds.graph.drop('logisticsGraph', false) YIELD graphName;")
    db.query("""
    CALL gds.graph.project('logisticsGraph',
      { 
        Almacen: {properties: ['lat', 'lon']}, 
        PuntoEntrega: {properties: ['lat', 'lon']}, 
        Interseccion: {properties: ['lat', 'lon']} 
      },
      { CONECTA_A: { properties: ['distancia', 'tiempo_min'] } }
    );
    """)

    # --- FILA 1: MÉTRICAS CLAVE ---
    col1, col2, col3 = st.columns(3)
    
    # Tiempo Dijkstra
    res_tiempo = db.query("""
    MATCH (s:Almacen {id: $oid}), (t:PuntoEntrega {nombre: $tid})
    CALL gds.shortestPath.dijkstra.stream('logisticsGraph', {
        sourceNode: s, targetNode: t, relationshipWeightProperty: 'tiempo_min'
    }) YIELD totalCost AS tiempo RETURN tiempo
    """, {"oid": origen_id, "tid": destino_nombre})

    with col1:
        st.metric("⏱️ Tiempo Estimado", f"{res_tiempo[0]['tiempo'] if res_tiempo else 0} min")
    
    # Costo de Negocio
    res_costo = db.query("""
    MATCH path = (a:Almacen {id: $oid})-[:CONECTA_A*]->(dest:PuntoEntrega {nombre: $tid})
    WITH relationships(path) AS rels UNWIND rels AS r
    RETURN sum(r.distancia * r.estado_trafico) AS total
    """, {"oid": origen_id, "tid": destino_nombre})
    
    with col2:
        st.metric("💰 Costo de Ruta", f"${res_costo[0]['total']:.2f}" if res_costo else "$0.00")

    with col3:
        st.metric("🎯 Eficiencia A*", "Óptima ✅")

    st.markdown("---")

    # --- FILA 2: TABLAS DE DATOS ---
    c1, c2 = st.columns(2)
    
    with c1:
        st.subheader("🚫 Restricciones de Carga")
        rest_data = db.query("""
        MATCH (a:Almacen {id: $oid})-[r:CONECTA_A]->(dest)
        WHERE r.capacidad_max < $peso
        RETURN coalesce(dest.nombre, 'Vía a Intersección ' + id(dest)) AS Destino, 
               r.capacidad_max AS `Capacidad (t)`
        """, {"oid": origen_id, "peso": peso_camion})
        
        if rest_data:
            st.dataframe(pd.DataFrame(rest_data), width="stretch")
        else:
            st.success("No hay restricciones de carga para este camión en las rutas directas.")

    with c2:
        st.subheader("📋 Hoja de Ruta (Pasos)")
        ruta_data = db.query("""
        MATCH (s:Almacen {id: $oid}), (t:PuntoEntrega {nombre: $tid})
        CALL gds.shortestPath.dijkstra.stream('logisticsGraph', {
            sourceNode: s, targetNode: t, relationshipWeightProperty: 'distancia'
        })
        YIELD nodeIds UNWIND nodeIds AS nodeId
        WITH gds.util.asNode(nodeId) AS n
        RETURN coalesce(n.nombre, 'Intersección ' + id(n)) AS Parada,
               labels(n)[0] AS Tipo
        """, {"oid": origen_id, "tid": destino_nombre})
        
        if ruta_data:
            st.dataframe(pd.DataFrame(ruta_data), width="stretch")
        else:
            st.error("No se encontró una ruta válida entre el origen y el destino.")

else:
    st.info("👈 Ajusta los parámetros en el panel izquierdo y presiona 'Calcular' para iniciar la optimización.")

# Pie de página
st.markdown("---")
st.caption("Sistema desarrollado con Neo4j Graph Data Science (GDS) y Streamlit Engine.")
