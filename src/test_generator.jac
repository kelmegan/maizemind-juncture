"""Standalone test for the graph generator pipeline.
Run with: jac run src/test_generator.jac
"""

import json;
import from src.graph_generator { Document, generate_argument_graph }

with entry {
    test_notes = "Climate change is primarily caused by human activities. "
                 "Burning fossil fuels releases CO2 into the atmosphere. "
                 "Some scientists argue that natural cycles also play a role. "
                 "The Paris Agreement aims to limit warming to 1.5 degrees. "
                 "However, many countries are not meeting their targets. "
                 "Renewable energy is growing but not fast enough.";

    test_docs = [
        Document(
            title="IPCC Report 2023",
            content="Human activities have unequivocally caused global warming."
        )
    ];

    print("=== MaizeMind Graph Generator ===");
    print("Processing notes...\n");

    result = generate_argument_graph(test_notes, test_docs);

    with open("graph_output.json", "w") as f {
        json.dump(result, f, indent=2);
    }

    print("--- NODES ---");
    for n in result.get("nodes", []) {
        print(f"  [{n.get('type', '')}] {n.get('text', '')} "
              f"(conf: {n.get('confidence', '')}, status: {n.get('status', '')})");
    }

    print("\n--- EDGES ---");
    for e in result.get("edges", []) {
        print(f"  {e.get('from_id', '')} --{e.get('type', '')}--> {e.get('to_id', '')}");
    }

    s = result.get("reasoning_score", {});
    print(f"\n--- SCORE: {s.get('overall', '0')} ---");
    print(f"\nSaved to graph_output.json");
}