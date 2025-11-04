from tempfile import TemporaryDirectory
import json
import yaml
import sys
from subprocess import run

def is_svn(url) -> bool:
    return url.startswith('svn://')

def git_clone(url, rev, dir):
    run(["git", "clone", "--depth=1", f"--revision={rev}", url], stdout=sys.stderr, cwd=dir)

def svn_clone(url, rev, dir):
    run(["git", "svn", "clone", "-s", f"-r{rev}:HEAD", url], stdout=sys.stderr, cwd=dir)

def main():
    with open("06-tool-selection-manual.yaml") as f:
        tools = yaml.safe_load(f)
    results = {}
    for haystack in tools:
        results[haystack['name']] = {}
        with TemporaryDirectory(suffix=haystack['name'], delete=False) as dir:
            # Clone repos
            for repository in haystack['repositories']:
                if is_svn(repository['url']):
                    svn_clone(repository['url'], repository['rev'], dir)
                else:
                    git_clone(repository['url'], repository['rev'], dir)
            # Find occurrences for each other tool
            for needle in tools:
                if needle['name'] == haystack['name']:
                    continue
                cmd = run(["grep", "-o", f"\\<{needle['name']}\\>", "-r", "-i", dir], capture_output=True)
                matches = len(cmd.stdout.splitlines())
                if matches > 0:
                    results[haystack['name']][needle['name']] = matches
        print(json.dumps(results[haystack['name']]))
    print(json.dumps(results))
               

main()
