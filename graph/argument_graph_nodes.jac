"""Argument graph schema"""

node ArgumentGraph {
    has id: str,
        nodes: list[dict],
        edges: list[dict],
        createdAt: str,
        updatedAt: str,
        graphMode: str = "education_argument",
        graph_mode: str = "education_argument",
        schema_version: str = "",
        board_id: str = "",
        primary_decision_id: str = "",
        meeting: dict = {},
        template: str = "",
        title: str = "",
        summary: str = "";
}
