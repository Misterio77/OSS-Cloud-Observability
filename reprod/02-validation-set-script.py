# Given a set of keywords (e.g. known tools), this tool picks all abstracts that contain any of them, as well as a % of random sample.
import json
import csv
import random

KEYWORDS = ["grafana", "prometheus", "graphite", "opentelemetry", "elasticsearch", "fluentd", "kibana", "logstash", "jaeger", "influxdb", "ceilometer"]
TARGET_SIZE=50
SEED = "nevergonnagiveyouup"

random.seed(SEED)

def main():
    golden_set = []
    with open("01-scopus-search-results.csv") as f:
        rows = list(csv.DictReader(f))
        for id, row in enumerate(rows, start=1):
            abstract = row['Abstract'].lower()
            if any(keyword in abstract for keyword in KEYWORDS):
                golden_set.append({"source": "keyword", "id": id, "title": row['Title'], "abstract": row['Abstract'], "tools": []})

        random_samples = TARGET_SIZE-len(golden_set)
        picks = random.sample(list(enumerate(rows, start=1)), k=random_samples)
        for id, row in picks:
            golden_set.append({"source": "random", "id": id, "title": row['Title'], "abstract": row['Abstract'], "tools": []})

    print(json.dumps(golden_set))

main()
