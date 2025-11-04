# This script is resposible for the step in which we use an LLM to broadly extract tools from the set of abstracts.
# You must set an environment variable with your API key or use a locally hosted LLM model to use this.
# This script produces JSON, equivalent to our '03-extraction-results.json'
import functools
import asyncio
import csv
import json
import sys

from concurrent.futures import ThreadPoolExecutor
from openai import OpenAI

MAX_WORKERS = 30
OPENAI_URL = "https://api.deepseek.com"
MODEL = "deepseek-chat"

client = OpenAI(base_url=OPENAI_URL)
executor = ThreadPoolExecutor(max_workers=MAX_WORKERS)


def run_in_executor(f):
    @functools.wraps(f)
    def inner(*args, **kwargs):
        loop = asyncio.get_running_loop()
        return loop.run_in_executor(executor, lambda: f(*args, **kwargs))

    return inner


@run_in_executor
def get_tools(id, title, abstract):
    response = client.chat.completions.create(
        model=MODEL,
        messages=[
            {
                "role": "system",
                "content": """You will receive a paper abstract that relates to cloud observability/monitoring/logging/tracing tools. Enumerate all observability/monitoring/logging/tracing tools mentioned in it. Respond with the names separated by comma: tool1,tool2,tool3. If there are no relevant tools, reply with an empty string.""",
            },
            {"role": "user", "content": abstract},
        ],
    )
    message = response.choices[0].message.content
    tools = list(filter(None, message.replace('"', "").lower().split(",")))
    result = {"id": id, "title": title, "abstract": abstract, "tools": tools}
    print(json.dumps(result), file=sys.stderr)
    return result


async def main():
    tasks = []
    with open("01-scopus-search-results.csv") as f:
        rows = csv.DictReader(f)
        for id, row in enumerate(rows, start=1):
            tasks.append(get_tools(id, row['Title'], row['Abstract']))
    results = await asyncio.gather(*tasks)
    print(json.dumps(results))


asyncio.run(main())
