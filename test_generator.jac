"""Quick test of the graph generator pipeline."""
import from src.graph_generator { Document, generate_argument_graph }

with entry {
    print("=== Testing graph generator ===");

    test_notes = "Social media is harmful to teens. Studies show increased anxiety and depression among heavy users. However, some argue it helps teens stay connected. There is no conclusive evidence on long-term effects.";
    business_notes = "We need to decide whether to launch the analytics pilot in Q3. Option A is an internal pilot only. Option B is a limited beta with five customers. Engineering says the core pipeline is already built, but legal review is not complete. Open question: can legal finish before May 15? Megan will confirm the legal timeline by 2026-05-02. Risk: if review slips, the beta could expose us to compliance issues.";

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
    print(f"Graph mode: {result.get('graphMode', '')}");
    print(f"Title: {result.get('title', '')}");
    print("=== DONE ===");

    print("\n=== Testing business meeting decision mode ===");
    print(f"Input notes: {business_notes}");

    business_result = generate_argument_graph(
        business_notes,
        [],
        [],
        [],
        "business_meeting_decision",
        "business_meeting_decision"
    );

    print(f"\n=== BUSINESS RESULT ===");
    print(f"Graph mode: {business_result.get('graphMode', '')}");
    print(f"Title: {business_result.get('title', '')}");
    print(f"Summary: {business_result.get('summaryText', '')}");
    print(f"Nodes ({len(business_result.get('nodes', []))}):");
    for n in business_result.get("nodes", []) {
        print(f"  - [{n.get('type','')}/{n.get('semanticRole','')}] {n.get('id','')}: {n.get('text','')}");
    }
    print(f"\nEdges ({len(business_result.get('edges', []))}):");
    for e in business_result.get("edges", []) {
        print(f"  - {e.get('from_id','')} --{e.get('type','')}--> {e.get('to_id','')}");
    }
    print("=== DONE ===");
}
