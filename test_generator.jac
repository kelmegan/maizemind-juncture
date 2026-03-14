"""Quick test of the graph generator pipeline."""
import from src.graph_generator { Document, generate_argument_graph }

with entry {
    print("=== Testing graph generator ===");

    test_notes = "Social media is harmful to teens. Studies show increased anxiety and depression among heavy users. However, some argue it helps teens stay connected. There is no conclusive evidence on long-term effects.";

    print(f"Input notes: {test_notes}");
    print("Calling generate_argument_graph...");

    result = generate_argument_graph(test_notes, []);

    print(f"\n=== RESULT ===");
    print(f"Nodes ({len(result.get('nodes', []))}):");
    for n in result.get("nodes", []) {
        print(f"  - [{n.get('type','')}] {n.get('id','')}: {n.get('text','')}");
    }
    print(f"\nEdges ({len(result.get('edges', []))}):");
    for e in result.get("edges", []) {
        print(f"  - {e.get('from_id','')} --{e.get('type','')}--> {e.get('to_id','')}");
    }
    print(f"\nScore: {result.get('reasoning_score', {})}");
    print(f"Summary: {result.get('summary', {})}");
    print("=== DONE ===");
}
