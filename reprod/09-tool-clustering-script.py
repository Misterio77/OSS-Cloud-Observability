import json
import yaml
import math
import random
import networkx as nx
import matplotlib as mpl
import matplotlib.pyplot as plt
import colorsys

# Seed for the RNG
# Picked arbitrarily, the graph looks nice with this one.
SEED = 379
random.seed(SEED)
mpl.rcParams['svg.hashsalt'] = str(SEED) # Deterministic SVG ID's

# Helper function to create community colors
def create_community_colors(graph, communities):
    colors = ["#98c7ef", "#fe9f9a", "#feea65", "#e7b6ee", "#81e08c", "#88e0e0", "#cea1b6", "#fe9d48", "#f570d7"]
    node_colors = []
    for node in graph:
        current_community_index = 0
        for community in communities:
            if node in community:
                node_colors.append(colors[current_community_index])
                break
            current_community_index += 1
    return node_colors

# Prepare graph
G = nx.DiGraph()

with open("./08-tool-code-occurrences-results.json") as f:
    tools = json.load(f)

# How referred to a tool is
tool_scores = {}
for tool, related_tools in tools.items():
    G.add_node(tool)
    # Make it relative to the total occurrences
    total_occurrences = sum(related_tools.values())
    for related_tool, occurrences in related_tools.items():
        weight = occurrences/total_occurrences
        tool_scores[related_tool] = tool_scores.get(related_tool, 0.5) + math.sqrt(weight)
        if weight > 0.05:
            G.add_edge(tool, related_tool, weight=weight)

# Separate into communities
communities = list(nx.community.greedy_modularity_communities(G))

# Node sizes based on number of how much other tools relate to it
sizes = [tool_scores.get(node, 0.5)*250 for node in G]

# Plot results
plt.figure(
    frameon=False,
    layout='constrained',
    figsize=(11, 6),
)

node_colors = create_community_colors(G, communities)
pos = nx.spring_layout(G, iterations=250, k=1.3, seed=SEED)
nx.draw_networkx_nodes(
    G,
    pos=pos,
    node_size=sizes,
    node_color=node_colors,
)
nx.draw_networkx_labels(G, pos, font_size=8)
for edge in G.edges(data='weight'):
    weight = edge[2]
    nx.draw_networkx_edges(G, pos,
       edgelist=[edge],
       width=weight*1.5,
       node_size=sizes,
       arrowstyle="]->",
       arrowsize=12,
       arrows=True,
       connectionstyle='arc3,rad=0.05',
    )
plt.savefig("./10-tool-clustering-results.svg", dpi=200.0)
print("Saved to ./10-tool-clustering-results.svg")
