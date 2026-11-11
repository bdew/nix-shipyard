import json
import subprocess
import sys
from collections import Counter
from concurrent.futures import ThreadPoolExecutor


def normalize_repository(repository):
    parts = repository.split("/", 1)
    if len(parts) == 1:
        return f"docker.io/library/{repository}"

    registry, name = parts
    if "." not in registry and ":" not in registry and registry != "localhost":
        return f"docker.io/{repository}"
    if registry == "index.docker.io":
        return f"docker.io/{name}"
    return repository


def reconcile_image_references(docker_bin, repository, digest, tag):
    reference = f"{repository}@{digest}"
    inspect_result = subprocess.run(
        [docker_bin, "image", "inspect", "--format", "{{json .}}", reference],
        capture_output=True,
        check=True,
        text=True,
    )
    target_image = json.loads(inspect_result.stdout)
    target_id = target_image["Id"]
    normalized_repository = normalize_repository(repository)

    if tag:
        tags = target_image["RepoTags"] or []
        already_tagged = any(
            ":" in existing_tag
            and normalize_repository(existing_tag.rsplit(":", 1)[0]) == normalized_repository
            and existing_tag.rsplit(":", 1)[1] == tag
            for existing_tag in tags
        )
        if not already_tagged:
            target_tag = f"{repository}:{tag}"
            print(
                f"[Docker Preload] Tagging: {reference} as {target_tag}",
                flush=True,
            )
            subprocess.run(
                [docker_bin, "image", "tag", reference, target_tag],
                check=True,
            )

    image_list = subprocess.run(
        [
            docker_bin,
            "image",
            "ls",
            "--no-trunc",
            "--digests",
            "--format",
            "{{json .}}",
        ],
        capture_output=True,
        check=True,
        text=True,
    )
    removed = set()
    for line in image_list.stdout.splitlines():
        listed_image = json.loads(line)
        listed_repository = listed_image["Repository"]
        if normalize_repository(listed_repository) != normalized_repository:
            continue

        if listed_image["ID"] == target_id:
            continue

        listed_tag = listed_image["Tag"]
        listed_digest = listed_image["Digest"]
        references = []
        if listed_tag != "<none>":
            references.append(("tag", listed_tag, f"{listed_repository}:{listed_tag}"))

        if listed_digest != "<none>":
            references.append(("digest", listed_digest, f"{listed_repository}@{listed_digest}"))

        for reference_type, value, listed_reference in references:
            if reference_type == "digest" and value == digest:
                continue
            if reference_type == "tag" and value == tag:
                continue
            if listed_reference in removed:
                continue

            subprocess.run(
                [docker_bin, "image", "rm", "-f", listed_reference],
                check=True,
            )
            removed.add(listed_reference)
            print(f"[Docker Preload] Untagged: {listed_reference}", flush=True)


def preload_image(image, docker_bin, action):
    repository, separator, digest = image.partition("@")
    if separator:
        tagged_repository = repository
        if repository.rfind(":") > repository.rfind("/"):
            repository = repository.rsplit(":", 1)[0]
        reference = f"{repository}@{digest}"
        tag_separator = tagged_repository.rfind(":")
        tag = (
            tagged_repository[tag_separator + 1:]
            if tag_separator > tagged_repository.rfind("/")
            else None
        )
    else:
        reference = image
        tag = None

    result = subprocess.run(
        [docker_bin, "image", "inspect", reference],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )

    if result.returncode != 0:
        print(f"[Docker Preload] Pulling: {repository} ({digest})", flush=True)
        pull_result = subprocess.run(
            [docker_bin, "image", "pull", image],
            stdout=subprocess.DEVNULL,
            check=False,
        )
        if pull_result.returncode != 0:
            print(f"[Docker Preload] Failed: {repository} ({digest})", flush=True)
            return "failed"
        print(f"[Docker Preload] Pulled: {repository} ({digest})", flush=True)
        status = "pulled"
    else:
        status = "present"

    if separator and action != "dry-activate":
        reconcile_image_references(docker_bin, repository, digest, tag)
    return status


def main():
    docker_bin = sys.argv[2]
    action = sys.argv[3]
    if action not in ("switch", "boot", "dry-activate"):
        print(
            f"[Docker Preload] Skipping: unsupported action={action!r}",
            flush=True,
        )
        return

    version_result = subprocess.run(
        [docker_bin, "version", "--format", "{{json .}}"],
        capture_output=True,
        check=True,
        text=True,
    )
    versions = json.loads(version_result.stdout)
    print(
        f"[Docker Preload] Docker client: {versions['Client']['Version']}, "
        f"server: {versions['Server']['Version']}",
        flush=True,
    )

    with open(sys.argv[1], encoding="utf-8") as file:
        images = file.read().splitlines()

    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = [
            executor.submit(preload_image, image, docker_bin, action)
            for image in images
        ]
        print(f"[Docker Preload] Preloading {len(images)} images...", flush=True)
        results = Counter(future.result() for future in futures)

    print(
        f"[Docker Preload] Done - images: {len(images)}, "
        f"pulled: {results['pulled']}, failed: {results['failed']}",
        flush=True,
    )
    return int(results["failed"] > 0)


if __name__ == "__main__":
    sys.exit(main())
