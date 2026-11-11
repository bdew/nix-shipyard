import json
import subprocess
import sys
from collections import Counter
from concurrent.futures import ThreadPoolExecutor


def preload_image(image, docker_bin):
    repository, separator, digest = image.partition("@")
    if separator:
        if repository.rfind(":") > repository.rfind("/"):
            repository = repository.rsplit(":", 1)[0]
        reference = f"{repository}@{digest}"
    else:
        reference = image

    result = subprocess.run(
        [docker_bin, "image", "inspect", reference],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )

    if result.returncode == 0:
        return "present"

    print(f"[Docker Preload] Pulling: {repository} ({digest})")

    pull_result = subprocess.run(
        [docker_bin, "image", "pull", image],
        stdout=subprocess.DEVNULL,
        check=False,
    )
    if pull_result.returncode == 0:
        print(f"[Docker Preload] Pulled: {repository} ({digest})")
        return "pulled"

    print(f"[Docker Preload] Failed: {repository} ({digest})")
    return "failed"


def main():
    docker_bin = sys.argv[2]
    action = sys.argv[3]
    if action not in ("switch", "boot", "dry-activate"):
        print(f"[Docker Preload] Skipping: unsupported action={action!r}")
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
        f"server: {versions['Server']['Version']}"
    )

    with open(sys.argv[1], encoding="utf-8") as file:
        images = file.read().splitlines()

    with ThreadPoolExecutor() as executor:
        futures = [
            executor.submit(preload_image, image, docker_bin)
            for image in images
        ]
        results = Counter(future.result() for future in futures)

    print(f"[Docker Preload] Done - images: {len(images)}, pulled: {results['pulled']}, failed: {results['failed']}")
    return int(results["failed"] > 0)


if __name__ == "__main__":
    sys.exit(main())
