"""Argument graph schema"""

node ArgumentGraph {
    has id: str,
        nodes: list[dict],
        edges: list[dict],
        createdAt: str,
        updatedAt: str;
}