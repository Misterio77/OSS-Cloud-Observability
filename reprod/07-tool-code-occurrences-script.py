from argparse import ArgumentParser
from collections import Counter
from pathlib import Path
from subprocess import CalledProcessError, run
from tempfile import TemporaryDirectory
from time import sleep
import json
import sys

import yaml

START_MONTH = (2020, 1)
END_MONTH = (2026, 6)


def months_between(start, end):
    year, month = start
    while (year, month) <= end:
        yield f"{year:04d}-{month:02d}"
        if month == 12:
            year, month = year + 1, 1
        else:
            month += 1


def is_svn(url):
    return url.startswith("svn://")


def is_software_heritage_git_archive(url):
    return "/vault/git-bare/" in url and url.endswith("/raw/")


def clone_software_heritage_git_archive(url, destination):
    destination_path = Path(destination)
    archive_path = destination_path.with_suffix(".tar")
    extracted_path = destination_path.with_name(f"{destination_path.name}-archive")
    extracted_path.mkdir()

    run(
        ["curl", "--fail", "--location", "--silent", "--show-error", "--output", archive_path, url],
        check=True,
    )
    run(["tar", "--extract", "--file", archive_path, "--directory", extracted_path], check=True)
    repositories = list(extracted_path.glob("*.git"))
    if len(repositories) != 1:
        raise ValueError(f"Expected one Git repository in {url}, found {len(repositories)}")
    run(
        ["git", "clone", "--no-checkout", repositories[0], destination],
        check=True,
        stdout=sys.stderr,
    )


def clone_repository(repository, destination):
    url = repository["url"]
    if is_svn(url):
        first_revision = next(rev for rev in repository["revs"] if rev is not None)
        run(
            ["svn", "checkout", "-q", f"-r{first_revision}", f"{url.rstrip('/')}/trunk", destination],
            check=True,
            stdout=sys.stderr,
        )
    elif is_software_heritage_git_archive(url):
        clone_software_heritage_git_archive(url, destination)
    else:
        run(
            ["git", "clone", "--filter=blob:none", "--no-checkout", url, destination],
            check=True,
            stdout=sys.stderr,
        )


def checkout_revision(repository, destination, revision, attempts=8):
    if is_svn(repository["url"]):
        command = ["svn", "update", "-q", f"-r{revision}"]
    else:
        command = ["git", "checkout", "--quiet", "--detach", revision]

    for attempt in range(1, attempts + 1):
        try:
            run(command, check=True, cwd=destination, stdout=sys.stderr)
            return
        except CalledProcessError:
            if attempt == attempts:
                raise
            delay = min(15 * (2 ** (attempt - 1)), 120)
            print(
                f"Checkout {revision} failed; retrying in {delay}s "
                f"({attempt}/{attempts})",
                file=sys.stderr,
            )
            sleep(delay)


def count_occurrences(paths, patterns_file):
    if not paths:
        return Counter()

    command = [
        "grep",
        "-F",
        "-h",
        "-I",
        "-i",
        "-o",
        "-r",
        "-w",
        "--exclude-dir=.git",
        "--exclude-dir=.svn",
        f"--file={patterns_file}",
        "--",
        *paths,
    ]
    completed = run(command, capture_output=True)
    if completed.returncode not in (0, 1):
        completed.check_returncode()
    return Counter(match.decode().casefold() for match in completed.stdout.splitlines())


def validate_revisions(tools, months):
    for tool in tools:
        for repository in tool["repositories"]:
            revisions = repository.get("revs")
            if not isinstance(revisions, list) or len(revisions) != len(months):
                raise ValueError(
                    f"{repository['url']} must have one revision for each of the "
                    f"{len(months)} months"
                )
            if all(revision is None for revision in revisions):
                raise ValueError(f"{repository['url']} has no revisions in the requested period")


def parse_args():
    parser = ArgumentParser()
    parser.add_argument(
        "--output",
        type=Path,
        help="write an atomic checkpoint after each analyzed tool instead of using stdout",
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="skip tools already present for every month in the output checkpoint",
    )
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        metavar="TOOL",
        help="skip a tool repository while retaining its name as a search pattern",
    )
    return parser.parse_args()


def load_results(months, output, resume):
    empty = {month: {} for month in months}
    if not resume or output is None or not output.exists():
        return empty

    try:
        saved = json.loads(output.read_text())
    except (json.JSONDecodeError, OSError):
        print(f"Ignoring unreadable checkpoint {output}", file=sys.stderr)
        return empty

    if set(saved) != set(months) or not all(isinstance(saved[month], dict) for month in months):
        print(f"Ignoring incompatible checkpoint {output}", file=sys.stderr)
        return empty
    return {month: saved[month] for month in months}


def write_results(results, output):
    serialized = json.dumps(results, indent=2, sort_keys=True) + "\n"
    if output is None:
        return
    temporary_output = output.with_suffix(f"{output.suffix}.tmp")
    temporary_output.write_text(serialized)
    temporary_output.replace(output)


def tool_is_complete(results, months, tool_name):
    return all(tool_name in results[month] for month in months)


def analyze_tool(haystack, months, results, patterns_file):
    with TemporaryDirectory(prefix=f"occurrences-{haystack['name']}-") as repository_directory:
        repository_paths = []
        previous_revisions = [None] * len(haystack["repositories"])

        for repository_index, repository in enumerate(haystack["repositories"]):
            destination = Path(repository_directory) / str(repository_index)
            clone_repository(repository, str(destination))
            repository_paths.append(str(destination))

        for month_index, month in enumerate(months):
            active_paths = []
            for repository_index, repository in enumerate(haystack["repositories"]):
                revision = repository["revs"][month_index]
                if revision is None:
                    continue
                if revision != previous_revisions[repository_index]:
                    checkout_revision(repository, repository_paths[repository_index], revision)
                    previous_revisions[repository_index] = revision
                active_paths.append(repository_paths[repository_index])

            counts = count_occurrences(active_paths, patterns_file)
            counts.pop(haystack["name"].casefold(), None)
            results[month][haystack["name"]] = dict(sorted(counts.items()))


def main():
    args = parse_args()
    if args.resume and args.output is None:
        raise ValueError("--resume requires --output")

    months = list(months_between(START_MONTH, END_MONTH))
    with open("06-tool-selection-manual.yaml") as file:
        tools = yaml.safe_load(file)
    validate_revisions(tools, months)

    excluded = set(args.exclude)
    unknown_exclusions = excluded - {tool["name"] for tool in tools}
    if unknown_exclusions:
        raise ValueError(f"Unknown excluded tools: {', '.join(sorted(unknown_exclusions))}")

    results = load_results(months, args.output, args.resume)
    with TemporaryDirectory(prefix="occurrence-patterns-") as patterns_directory:
        patterns_file = Path(patterns_directory) / "tool-names.txt"
        patterns_file.write_text("\n".join(tool["name"] for tool in tools) + "\n")

        for haystack in tools:
            if haystack["name"] in excluded:
                print(f"Skipping excluded tool {haystack['name']}", file=sys.stderr)
                continue
            if args.resume and tool_is_complete(results, months, haystack["name"]):
                print(f"Resuming after completed tool {haystack['name']}", file=sys.stderr)
                continue

            print(f"Analyzing {haystack['name']}", file=sys.stderr)
            analyze_tool(haystack, months, results, patterns_file)
            write_results(results, args.output)

    if args.output is None:
        print(json.dumps(results, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
