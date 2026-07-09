"""Argument graph schema"""

node ArgumentGraph {
    has id: str,
        nodes: list[dict],
        edges: list[dict],
        createdAt: str,
        updatedAt: str;
}

"Find a root-owned ArgumentGraph by id, or None if not found."
def find_argument_graph(from_node: Root, graph_id: str) -> ArgumentGraph | None {
    for graph in [from_node -->](?:ArgumentGraph) {
        if graph.id == graph_id {
            return graph;
        }
    }
    return None;
}