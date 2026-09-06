#!/usr/bin/env python3
"""Select, version, and specialize the Info.plist used by an iTerm2 build."""

import argparse
import os
from pathlib import Path
import plistlib
import shutil
import sys
import tempfile


CONFIGURATION_PLISTS = {
    "Development": "dev-iTerm2.plist",
    "Beta": "beta-iTerm2.plist",
    "Nightly": "nightly-iTerm2.plist",
}
DEPLOYMENT_VARIANTS = {
    "release": "release-iTerm2.plist",
    "preview": "preview-iTerm2.plist",
}
SUPPORTED_EDITIONS = ("upstream", "cn")
FORBIDDEN_FEED_KEYS = (
    "SUFeedURL",
    "SUFeedURLForFinal",
    "SUFeedURLForTesting",
)
BUNDLE_VERSION_KEYS = (
    "CFBundleShortVersionString",
    "CFBundleVersion",
    "CFBundleGetInfoString",
)


class PlistPolicyError(ValueError):
    pass


def plist_name(configuration, variant):
    if configuration == "Deployment":
        try:
            return DEPLOYMENT_VARIANTS[variant]
        except KeyError as error:
            choices = ", ".join(sorted(DEPLOYMENT_VARIANTS))
            raise PlistPolicyError(
                f"unsupported Deployment plist variant {variant!r}; expected one of: {choices}"
            ) from error
    try:
        return CONFIGURATION_PLISTS[configuration]
    except KeyError as error:
        choices = ", ".join(sorted((*CONFIGURATION_PLISTS, "Deployment")))
        raise PlistPolicyError(
            f"unsupported build configuration {configuration!r}; expected one of: {choices}"
        ) from error


def load_document(path):
    try:
        with path.open("rb") as stream:
            document = plistlib.load(stream)
    except (OSError, plistlib.InvalidFileException, ValueError) as error:
        raise PlistPolicyError(f"could not read {path}: {error}") from error

    if not isinstance(document, dict):
        raise PlistPolicyError(f"{path}: root must be a dictionary")
    return document


def validate_upstream_source(document, path):
    if "iTermCNCommunityBuild" in document:
        raise PlistPolicyError(
            f"{path}: source plists must not define iTermCNCommunityBuild"
        )
    if document.get("CFBundleDisplayName") == "iTerm2-CN":
        raise PlistPolicyError(
            f"{path}: source plists must not use the iTerm2-CN display name"
        )
    if document.get("CFBundleName") == "iTerm2-CN":
        raise PlistPolicyError(
            f"{path}: source plists must not use the iTerm2-CN bundle name"
        )


def specialize(document, edition):
    if edition not in SUPPORTED_EDITIONS:
        choices = ", ".join(SUPPORTED_EDITIONS)
        raise PlistPolicyError(
            f"unsupported build edition {edition!r}; expected one of: {choices}"
        )
    result = dict(document)
    if edition == "upstream":
        return result

    result["CFBundleDisplayName"] = "iTerm2-CN"
    result["iTermCNCommunityBuild"] = True
    for key in FORBIDDEN_FEED_KEYS:
        result.pop(key, None)
    result["SUEnableAutomaticChecks"] = False
    result["SUAutomaticallyUpdate"] = False
    return result


def validate_output(document, path, edition):
    if edition == "upstream":
        if document.get("iTermCNCommunityBuild") is True:
            raise PlistPolicyError(f"{path}: upstream output is marked as a CN build")
        if document.get("CFBundleDisplayName") == "iTerm2-CN":
            raise PlistPolicyError(f"{path}: upstream output uses the iTerm2-CN name")
        if document.get("CFBundleName") == "iTerm2-CN":
            raise PlistPolicyError(f"{path}: upstream output uses the iTerm2-CN bundle name")
        return

    if document.get("iTermCNCommunityBuild") is not True:
        raise PlistPolicyError(f"{path}: iTermCNCommunityBuild must be true")
    if document.get("CFBundleDisplayName") != "iTerm2-CN":
        raise PlistPolicyError(f"{path}: CFBundleDisplayName must be iTerm2-CN")
    if document.get("CFBundleName") == "iTerm2-CN":
        raise PlistPolicyError(f"{path}: CFBundleName must preserve the upstream identity")
    for key in FORBIDDEN_FEED_KEYS:
        if key in document:
            raise PlistPolicyError(f"{path}: forbidden update feed key {key} is present")
    for key in ("SUEnableAutomaticChecks", "SUAutomaticallyUpdate"):
        if document.get(key) is not False:
            raise PlistPolicyError(f"{path}: {key} must be false")


def prepare(
    source_root,
    configuration,
    variant,
    output,
    temporary_directory=None,
    version=None,
    edition="upstream",
):
    source = source_root / "plists" / plist_name(configuration, variant)
    source_document = load_document(source)
    validate_upstream_source(source_document, source)
    document = specialize(source_document, edition)
    if version is not None:
        for key in BUNDLE_VERSION_KEYS:
            document[key] = version
    validate_output(document, source, edition)

    output.parent.mkdir(parents=True, exist_ok=True)
    temporary_directory = temporary_directory or output.parent
    temporary_directory.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            prefix=f".{output.name}.", dir=temporary_directory, delete=False
        ) as stream:
            temporary = Path(stream.name)
        shutil.copy2(source, temporary)
        with temporary.open("wb") as stream:
            plistlib.dump(document, stream, sort_keys=False)
        os.replace(temporary, output)
        temporary = None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)

    output_document = load_document(output)
    validate_output(output_document, output, edition)
    if version is not None:
        for key in BUNDLE_VERSION_KEYS:
            if output_document.get(key) != version:
                raise PlistPolicyError(f"{output}: {key} was not set to {version!r}")
    return source


def parse_args(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", required=True, type=Path)
    parser.add_argument("--configuration", required=True)
    parser.add_argument("--variant", default="release")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--temporary-directory", type=Path)
    parser.add_argument("--version")
    parser.add_argument("--edition", default="upstream")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    try:
        source = prepare(
            args.source_root.resolve(),
            args.configuration,
            args.variant,
            args.output.resolve(),
            args.temporary_directory.resolve() if args.temporary_directory else None,
            args.version,
            args.edition,
        )
    except PlistPolicyError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    print(f"Prepared {args.edition} Info.plist from {source}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
