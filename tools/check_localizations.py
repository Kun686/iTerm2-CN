#!/usr/bin/env python3
"""Validate iTerm2-CN localization resources."""

import argparse
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys
from xml.parsers.expat import ExpatError
from xml.etree import ElementTree


REQUIRED_BASE_LOCALIZATIONS = {"en", "zh-Hans"}
CN_PRODUCT_NAME = "iTerm2-CN"
ABOUT_PRODUCT_NAME_KEY = "U4n-GV-8aZ.title"
RAILROAD_LABEL_KEY_PREFIX = (
    "ui.swift.regexvisualization.icuregextorailroadconverter."
)
RAILROAD_DSL_UNSAFE_CHARACTERS = frozenset("\\\"'`\r\n")
LANGUAGE_DECLARATION = re.compile(
    r"\biTermApplicationLanguageIdentifier\s+const\s+"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*"
    r'@"(?P<identifier>(?:\\.|[^"\\])*)"\s*;'
)
LANGUAGE_REGISTRY_FUNCTION = re.compile(
    r"\biTermApplicationLanguageRegistry\s*\(\s*void\s*\)\s*\{"
)
LANGUAGE_REGISTRY_ASSIGNMENT = re.compile(r"\bregistry\s*=\s*@\[")
LANGUAGE_REGISTRY_ENTRY_IDENTIFIER = re.compile(
    r"\biTermApplicationLanguageRegistryIdentifierKey\s*:\s*"
    r'(?P<value>@"(?:\\.|[^"\\])*"|[A-Za-z_][A-Za-z0-9_]*)'
    r"\s*(?=,|})"
)
INFO_PLIST_USAGE_DESCRIPTION_KEY = re.compile(
    r"NS[A-Za-z0-9]+UsageDescription"
)
HAN_CHARACTER = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]")
SWIFT_UI_STRING_SINK = re.compile(r"\b(?P<sink>tooltip|toolTip)\s*[:=]")
SWIFT_STRING_LITERAL = re.compile(r'"(?:\\.|[^"\\])*"')
SWIFT_ACTION_ARRAY_SINK = re.compile(
    r"(?P<sink>"
    r"(?:(?<=\.)\b(?:actionLabels|doNotRememberLabels)(?=\s*=))|"
    r"(?:\bwithActions(?=\s*:))"
    r")\s*[:=]\s*\["
)
SWIFT_SINGLE_ACTION_LABEL_SINK = re.compile(
    r"(?P<sink>"
    r"(?:(?<=\.)\bcancelLabel(?=\s*=))|"
    r"(?:\bwarningActionWithLabel(?=\s*:))"
    r")\s*[:=]"
)
SWIFT_LOCALIZED_INTERPOLATION_FALLBACK = re.compile(
    r"\bString\s*\(\s*localized\s*:[^\n]*?"
    r"\?\?\s*\"(?P<literal>(?:\\.|[^\"\\])*)\""
)
SWIFT_STRING_PROPERTY_DECLARATION = re.compile(
    r"^[ \t]*(?:override\s+)?(?:(?:class|static)\s+)?"
    r"var\s+(?P<selector>[A-Za-z_][A-Za-z0-9_]*)\s*:\s*"
    r"String\s*\??\s*(?P<open>\{)",
    re.MULTILINE,
)
SWIFT_STRING_FUNCTION_DECLARATION = re.compile(
    r"^[ \t]*(?:override\s+)?(?:class\s+|static\s+)?"
    r"func\s+(?P<selector>[A-Za-z_][A-Za-z0-9_]*)\b"
    r"[^{};]*?->\s*String\s*\??\s*(?P<open>\{)",
    re.MULTILINE,
)
OBJC_UI_STRING_SINK = re.compile(
    r"(?P<sink>"
    r"(?:(?<=\.)\b(?:messageText|informativeText|placeholderString|toolTip|"
    r"accessibilityLabel|accessibilityHelp|stringValue|notificationTitle|title|heading|purpose)(?=\s*=))|"
    r"(?:\b(?:asyncShowWarningWithTitle|showWarningWithTitle|announcementWithTitle|showToastWithMessage|showWithMessage|"
    r"messageText|informativeText|addButtonWithTitle|setMessageText|"
    r"setInformativeText|setPlaceholderString|setToolTip|"
    r"setAccessibilityLabel|setAccessibilityHelp|heading|withTitle|title|notify|withDescription|confirmWith|recovery|"
    r"labelWithString|buttonWithTitle|checkboxWithTitle|radioButtonWithTitle|switchWithTitle|"
    r"menuItemWithTitle|initWithTitle|initWithLabelText|defaultTitle|"
    r"setStringValue|setTitle)(?=\s*:))"
    r")\s*[:=]"
)
OBJC_STRING_LITERAL = re.compile(r'@"(?:\\.|[^"\\])*"')
OBJC_DELAYED_UI_STRING_SINK = re.compile(
    r"\bperformSelector\s*:\s*@selector\(\s*"
    r"(?P<setter>setStringValue|setTitle|setPlaceholderString|setToolTip)\s*:"
    r"\s*\)\s*withObject\s*:"
)
OBJC_ATTRIBUTED_UI_STRING_SINK = re.compile(
    r"\[\[\s*(?:NS|NSMutable)AttributedString\s+alloc\s*\]\s*"
    r"(?P<sink>initWithString)\s*:"
)
OBJC_SEARCHABLE_COMBO_LABEL_SINK = re.compile(
    r"\[\[\s*iTermSearchableComboViewItem\s+alloc\s*\]\s*"
    r"(?P<sink>initWithLabel)\s*:"
)
OBJC_CURSOR_PRESET_NAME_SINK = re.compile(
    r"\[\[\s*iTermCursorBlinkFadePreset\s+alloc\s*\]\s*"
    r"(?P<sink>initWithName)\s*:"
)
OBJC_DISCLOSABLE_VIEW_INITIALIZER = re.compile(
    r"\[\s*\[\s*iTerm(?:Scrolling)?DisclosableView\s+alloc\s*\]\s*initWithFrame\s*:"
)
OBJC_DISCLOSABLE_TEXT_ARGUMENT = re.compile(r"\b(?P<sink>prompt|message)\s*:")
OBJC_LOCALIZED_DESCRIPTION_FALLBACK = re.compile(
    r"\blocalizedDescription\s*\]?\s*\?\:\s*"
    r"(?P<literal>@\"(?:\\.|[^\"\\])*\")"
)
OBJC_COMPLETION_CALL = re.compile(r"\bcompletion\s*(?P<open>\()")
OBJC_SCRIPT_UI_COMPLETION_PATHS = frozenset(
    {
        ("API", "iTermScriptExporter.m"),
        ("API", "iTermScriptImporter.m"),
    }
)
OBJC_ACTION_ARRAY_SINK = re.compile(
    r"\b(?P<sink>actions|actionLabels|doNotRememberLabels)\s*[:=]\s*@\["
)
OBJC_SINGLE_ACTION_LABEL_SINK = re.compile(
    r"(?P<sink>"
    r"(?:(?<=\.)\bcancelLabel(?=\s*=))|"
    r"(?:\b(?:cancelLabel|warningActionWithLabel)(?=\s*:))"
    r")\s*[:=]"
)
OBJC_INDIRECT_UI_SINK = re.compile(
    r"(?P<sink>"
    r"(?:(?<=\.)\b(?:messageText|informativeText|placeholderString|toolTip|"
    r"accessibilityLabel|accessibilityHelp|stringValue|notificationTitle|title|heading|purpose)(?=\s*=))|"
    r"(?:\b(?:asyncShowWarningWithTitle|showWarningWithTitle|announcementWithTitle|"
    r"showToastWithMessage|heading|notify|withDescription)(?=\s*:))"
    r")\s*[:=]\s*(?P<variable>[A-Za-z_][A-Za-z0-9_]*)\b(?!\s*[.(\[])"
)
OBJC_DRAWN_STRING_SINK = re.compile(
    r"\[\s*(?P<variable>[A-Za-z_][A-Za-z0-9_]*)\s+"
    r"(?P<sink>drawAtPoint|drawInRect)\s*:"
)
OBJC_INDIRECT_ACTIONS_SINK = re.compile(
    r"\bactions\s*:\s*(?P<variable>[A-Za-z_][A-Za-z0-9_]*)\b"
    r"(?!\s*[.(\[])"
)
OBJC_METHOD_BOUNDARY = re.compile(r"^[+-]\s*\(", re.MULTILINE)
OBJC_STRING_METHOD_DECLARATION = re.compile(
    r"^[+-]\s*\(\s*NSString\s*\*[^)]*\)\s*"
    r"(?P<selector>[A-Za-z_][A-Za-z0-9_]*)\b[^;{]*"
    r"(?P<open>\{)",
    re.MULTILINE,
)
OBJC_LOCALIZATION_CALL = re.compile(
    r"\b(?:NSLocalizedString(?:WithDefaultValue)?|"
    r"[A-Za-z_][A-Za-z0-9_]*LocalizedString)\s*(?P<open>\()"
)
OBJC_LOG_CALL = re.compile(
    r"\b(?:NSLog|RLog|DLog|CLog|XLog|os_log|os_log_error|os_log_fault|"
    r"LogDebug|LogInfo|LogNotice|LogWarning|LogError|LogVerbose)\s*\("
)
SWIFT_TRIGGER_PROVIDER_SELECTORS = frozenset(
    {"title", "description", "triggerOptionalParameterPlaceholder"}
)
SWIFT_SHARED_TRIGGER_DIAGNOSTIC_BODIES = {
    "SGRTrigger": r'return "Change Style “\(self.param ?? "")”"',
    "SetNamedMarkTrigger": r'return "Set Named Mark to \(self.param ?? "")"',
    "FoldTrigger": r'return "Fold to \(self.param ?? "")"',
    "InjectTrigger": r'return "Inject Data “\(self.param ?? "")”"',
    "ExitWorkgroupTrigger": 'return "Exit Workgroup"',
    "EnterWorkgroupTrigger": r'return "Enter Workgroup “\(displayLabel(forID: effectiveID))”"',
    "BufferInputTrigger": 'if shouldBuffer { return "Buffer Input" } else { return "Stop Buffering Input" }',
    "SetUserVariableTrigger": (
        'if let string = param as? String, let (name, value) = variableNameAndValue(string) {\n'
        r'return "Set User Variable “\(name)” to “\(value)”"' '\n} else {\n'
        r'return "Set User Variable “\(param ?? "")”"' '\n}'),
}
SWIFT_WORKGROUP_DIAGNOSTIC_LABEL_BODY = (
    'guard let id, !id.isEmpty else { return "(unset)" }\n'
    'if let wg = availableWorkgroups.first(where: { $0.uniqueIdentifier == id }) {\n'
    'return wg.name.isEmpty ? "Untitled" : wg.name\n'
    '}\nreturn "(missing)"'
)
SWIFT_STATUS_BAR_PROVIDER_SELECTORS = frozenset(
    {
        "statusBarComponentShortDescription",
        "statusBarComponentDetailedDescription",
    }
)
OBJC_TRIGGER_PROVIDER_SELECTORS = frozenset(
    {
        "title",
        "description",
        "paramPlaceholder",
        "triggerOptionalParameterPlaceholderWithInterpolation",
    }
)
OBJC_SHARED_TRIGGER_DIAGNOSTICS = {
    "AlertTrigger": {"Show alert “%@”"},
    "AnnotateTrigger": {"Annotate as as “%@”"},
    "BellTrigger": {"Ring Bell"},
    "CaptureTrigger": {"Capture output, running “%@” on double-click", "Capture Output"},
    "CoprocessTrigger": {"Run Coprocess “%@”"},
    "ScriptTrigger": {"Run Command “%@”"},
    "SendTextTrigger": {"Send text “%@”"},
    "SetDirectoryTrigger": {"Report Directory as “%@”"},
    "SetHostnameTrigger": {"Report User & Host as “%@”"},
    "iTermHyperlinkTrigger": {"Make Hyperlink with URL “%@”"},
    "iTermRPCTrigger": {"Invoke Script Function “%@”"},
    "iTermSetTitleTrigger": {"Set Title to “%@”"},
    "PasswordTrigger": {"Open Password Manager to “%@”", "Open Password Manager"},
    "iTermUserNotificationTrigger": {"Post Notification “%@”"},
}
# Compound descriptions are recognized only as complete original bodies, not
# by permitting their individual words in arbitrary expressions or UI sinks.
OBJC_SHARED_TRIGGER_DIAGNOSTIC_BODIES = {
    "BounceTrigger": 'return [NSString stringWithFormat:@"Bounce dock icon %@", self.bounceType == NSCriticalRequest ? @"until focused" : @"once"];',
    "MarkTrigger": 'return [NSString stringWithFormat:@"Set Mark and %@ scrolling", [self shouldStopScrolling] ? @"stop" : @"continue"];',
    "HighlightTrigger": 'return [NSString stringWithFormat:@"Highlight text %@ over %@", self.textColor.humanReadableDescription ?: @"(no color)", self.backgroundColor.humanReadableDescription ?: @"(no color))"];',
    "iTermHighlightLineTrigger": 'return [NSString stringWithFormat:@"Highlight Line with %@ over %@", self.textColor.humanReadableDescription ?: @"(no color)", self.backgroundColor.humanReadableDescription ?: @"(no color)"];',
}
OBJC_STATUS_BAR_PROVIDER_SELECTORS = frozenset(
    {
        "statusBarComponentShortDescription",
        "statusBarComponentDetailedDescription",
    }
)
OBJC_OPEN_QUICKLY_PROVIDER_SELECTORS = frozenset(
    {"tipTitle", "tipDetail", "restrictionDescription"}
)
OBJC_STRING_LIKE_TYPES = frozenset(
    {
        "NSString",
        "NSMutableString",
        "NSAttributedString",
        "NSMutableAttributedString",
    }
)
OBJC_INDIRECT_VALUE_TYPES = OBJC_STRING_LIKE_TYPES | {
    "NSArray",
    "NSMutableArray",
}
OBJC_UI_FRAGMENT_VARIABLE_SUFFIXES = (
    "title",
    "message",
    "description",
    "reason",
    "text",
    "heading",
    "sentence",
    "prompt",
    "warning",
    "error",
    "label",
)
OBJC_STRING_TRANSFORMATION_MARKERS = (
    "stringWithFormat",
    "stringByAppendingString",
    "stringByAppendingFormat",
    "componentsJoinedByString",
)
SOURCE_EXTENSIONS = {".c", ".cc", ".cpp", ".h", ".m", ".mm", ".swift"}
SOURCE_LOCALIZATION_REFERENCE_PATTERNS = (
    re.compile(
        r'\bString\s*\(\s*localized\s*:\s*"(?P<key>(?:\\.|[^"\\])*)"'
    ),
    re.compile(
        r'\bNSLocalizedString(?:WithDefaultValue)?\s*'
        r'\(\s*@"(?P<key>(?:\\.|[^"\\])*)"'
    ),
    re.compile(
        r'\blocalizedStringForKey\s*:\s*@"(?P<key>(?:\\.|[^"\\])*)"'
    ),
    re.compile(
        r'\blocalizedString\s*\(\s*forKey\s*:\s*"'
        r'(?P<key>(?:\\.|[^"\\])*)"'
    ),
    re.compile(
        r'\b(?:localizedHTML|localizedJavaScriptStringLiteral)\s*'
        r'\(\s*"(?P<key>(?:\\.|[^"\\])*)"'
    ),
)
FORMAT_PLACEHOLDER = re.compile(
    r"%(?:"
    r"(?P<escaped>%)|"
    r"#@(?P<plural>[A-Za-z_][A-Za-z0-9_]*)@|"
    r"(?P<position>[1-9][0-9]*\$)?"
    r"(?P<flags>[-+0#']*)"
    r"(?P<width>\*|[0-9]+)?"
    r"(?P<precision>\.(?:\*|[0-9]+)?)?"
    r"(?P<length>hh|ll|[hlqLztj])?"
    r"(?P<conversion>[@dDuUxXoOfFeEgGaAcCsSpn])"
    r")"
)
SOURCE_STRING_ESCAPE = re.compile(
    r"\\(?:[abfnrtv\\\"']|x[0-9A-Fa-f]{2}|u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8})"
)
STRINGSDICT_FORMAT_METADATA_KEYS = frozenset(
    {
        "NSStringLocalizedFormatKey",
        "NSStringFormatSpecTypeKey",
        "NSStringFormatValueTypeKey",
    }
)
TIP_DATA_ENTRY = re.compile(
    r'@"(?P<identifier>[0-9]+)"\s*:\s*@\{(?P<fields>.*?)\}\s*,?',
    re.DOTALL,
)
TIP_DATA_FIELD = {
    "title": re.compile(
        r'\bkTipTitleKey\s*:\s*@"(?P<value>(?:\\.|[^"\\])*)"'
    ),
    "body": re.compile(
        r'\bkTipBodyKey\s*:\s*@"(?P<value>(?:\\.|[^"\\])*)"'
    ),
}


class DuplicateJSONKeyError(ValueError):
    pass


def reject_duplicate_json_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateJSONKeyError(f"duplicate key {key!r}")
        result[key] = value
    return result


def string_units(localization, path="stringUnit"):
    if not isinstance(localization, dict):
        return
    unit = localization.get("stringUnit")
    if isinstance(unit, dict):
        yield path, unit
    variations = localization.get("variations")
    if isinstance(variations, dict):
        for variation_kind, variants in variations.items():
            if not isinstance(variants, dict):
                continue
            for variant, value in variants.items():
                yield from string_units(
                    value, f"variations.{variation_kind}.{variant}.stringUnit"
                )


def check_about_product_name(sources):
    catalog = sources / "AboutWindow" / "AboutWindow.xcstrings"
    if not catalog.is_file():
        return []
    try:
        document = json.loads(catalog.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return []
    entry = document.get("strings", {}).get(ABOUT_PRODUCT_NAME_KEY, {})
    localizations = entry.get("localizations", {})
    errors = []
    for language in sorted(REQUIRED_BASE_LOCALIZATIONS):
        units = list(string_units(localizations.get(language)))
        if len(units) != 1:
            continue
        value = units[0][1].get("value")
        if isinstance(value, str) and value != CN_PRODUCT_NAME:
            errors.append(
                f"{catalog}: {ABOUT_PRODUCT_NAME_KEY}[{language}]: expected "
                f"CN product name {CN_PRODUCT_NAME!r}, found {value!r}"
            )
    return errors


def variation_path_shape(path):
    """Normalize locale-specific plural categories while preserving other variants."""
    components = path.split(".")
    for index in range(len(components) - 2):
        if components[index : index + 2] == ["variations", "plural"]:
            components[index + 2] = "*"
    return ".".join(components)


def format_signature(value):
    signature = []
    for match in FORMAT_PLACEHOLDER.finditer(value):
        if match.group("escaped"):
            signature.append(("escaped-percent",))
        elif match.group("plural"):
            signature.append(("plural", match.group("plural")))
        else:
            signature.append(
                (
                    "format",
                    match.group("position") or "",
                    match.group("flags") or "",
                    match.group("width") or "",
                    match.group("precision") or "",
                    match.group("length") or "",
                    match.group("conversion"),
                )
            )
    return tuple(signature)


def format_signatures_match(source_signature, translated_signature):
    if source_signature == translated_signature:
        return True
    all_format_tokens = [
        token
        for token in source_signature + translated_signature
        if token[0] == "format"
    ]
    if any(not token[1] for token in all_format_tokens):
        return False
    return sorted(source_signature) == sorted(translated_signature)


def control_structure_signature(value):
    return (
        value.count("\n"),
        value.count("\r"),
        value.count("\t"),
        value.count(r"\n"),
        value.count(r"\r"),
        value.count(r"\t"),
    )


def parse_arguments(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Repository root to inspect (defaults to the script's repository).",
    )
    return parser.parse_args(argv)


def registered_localizations(sources):
    registry_path = (
        sources / "Settings" / "iTermApplicationLanguageController.m"
    )
    try:
        registry_source = registry_path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        return (), [f"{registry_path}: unable to read language registry: {error}"]

    registry_source = source_without_comments(registry_source)
    errors = []
    declared_identifiers = {}
    for declaration in LANGUAGE_DECLARATION.finditer(registry_source):
        name = declaration.group("name")
        identifier = declaration.group("identifier")
        if name in declared_identifiers:
            errors.append(
                f"{registry_path}: duplicate language identifier declaration {name!r}"
            )
            continue
        declared_identifiers[name] = identifier

    function_match = LANGUAGE_REGISTRY_FUNCTION.search(registry_source)
    assignment_match = (
        LANGUAGE_REGISTRY_ASSIGNMENT.search(registry_source, function_match.end())
        if function_match
        else None
    )
    array_end = (
        objc_array_literal_end(registry_source, assignment_match.end())
        if assignment_match
        else None
    )
    if assignment_match is None or array_end is None:
        errors.append(f"{registry_path}: language registry is empty or malformed")
        identifiers = ()
    else:
        registry_body = registry_source[assignment_match.end() : array_end]
        identifiers = []
        for index, (_, entry) in enumerate(
            objc_top_level_array_elements(registry_body), 1
        ):
            if not entry.strip():
                continue
            identifier_match = LANGUAGE_REGISTRY_ENTRY_IDENTIFIER.search(entry)
            if identifier_match is None:
                errors.append(
                    f"{registry_path}: language registry entry {index} has no "
                    "resolvable identifier"
                )
                continue
            value = identifier_match.group("value")
            if value.startswith('@"'):
                identifier = value[2:-1]
                if not identifier or "\\" in identifier:
                    errors.append(
                        f"{registry_path}: unresolved language registry identifier "
                        f"{value!r}"
                    )
                    continue
            else:
                identifier = declared_identifiers.get(value)
                if identifier is None:
                    errors.append(
                        f"{registry_path}: unresolved language registry identifier "
                        f"{value!r}"
                    )
                    continue
            identifiers.append(identifier)

    duplicate_identifiers = sorted(
        identifier
        for identifier in set(identifiers)
        if identifiers.count(identifier) > 1
    )
    for identifier in duplicate_identifiers:
        errors.append(
            f"{registry_path}: duplicate language registry identifier {identifier!r}"
        )

    localizations = tuple(
        identifier
        for identifier in dict.fromkeys(identifiers)
        if identifier != "system"
    )
    if not localizations:
        empty_registry_error = f"{registry_path}: language registry is empty or malformed"
        if empty_registry_error not in errors:
            errors.append(empty_registry_error)
    for language in sorted(REQUIRED_BASE_LOCALIZATIONS - set(localizations)):
        errors.append(f"{registry_path}: required localization '{language}' is not registered")
    return localizations, errors


def decode_strings_file(path):
    data = path.read_bytes()
    if data.startswith((b"\xff\xfe", b"\xfe\xff")):
        return data.decode("utf-16")
    return data.decode("utf-8-sig")


def skip_strings_whitespace_and_comments(source, index):
    while index < len(source):
        if source[index].isspace():
            index += 1
        elif source.startswith("//", index):
            newline = source.find("\n", index + 2)
            index = len(source) if newline < 0 else newline + 1
        elif source.startswith("/*", index):
            end = source.find("*/", index + 2)
            if end < 0:
                raise ValueError("unterminated block comment")
            index = end + 2
        else:
            break
    return index


def parse_strings_token(source, index, stop_characters):
    if index >= len(source):
        raise ValueError("expected token")
    if source[index] == '"':
        index += 1
        token = []
        while index < len(source):
            character = source[index]
            if character == '"':
                return "".join(token), index + 1
            if character == "\\":
                if index + 1 >= len(source):
                    raise ValueError("unterminated escape sequence")
                token.append(source[index : index + 2])
                index += 2
                continue
            token.append(character)
            index += 1
        raise ValueError("unterminated quoted string")
    start = index
    while (
        index < len(source)
        and not source[index].isspace()
        and source[index] not in stop_characters
    ):
        index += 1
    if index == start:
        raise ValueError("expected token")
    return source[start:index], index


def parse_strings_entries(source):
    entries = []
    index = 0
    while True:
        index = skip_strings_whitespace_and_comments(source, index)
        if index >= len(source):
            return entries
        key, index = parse_strings_token(source, index, "=")
        index = skip_strings_whitespace_and_comments(source, index)
        if index >= len(source) or source[index] != "=":
            raise ValueError("expected '=' after key")
        index = skip_strings_whitespace_and_comments(source, index + 1)
        value, index = parse_strings_token(source, index, ";")
        index = skip_strings_whitespace_and_comments(source, index)
        if index >= len(source) or source[index] != ";":
            raise ValueError("expected ';' after value")
        entries.append((key, value))
        index += 1


def localized_resource_identity(path, sources):
    relative_parts = path.relative_to(sources).parts
    for index, part in enumerate(relative_parts[:-1]):
        if part.endswith(".lproj"):
            language = part[: -len(".lproj")]
            identity = relative_parts[:index] + relative_parts[index + 1 :]
            return language, "/".join(identity)
    return None


def is_test_resource(path, sources):
    return any(
        part.lower() == "tests" or part.lower().endswith("tests")
        for part in path.relative_to(sources).parts
    )


def check_strings_syntax(sources, required_localizations):
    errors = []
    localized_documents = {}
    for path in sorted(sources.rglob("*.strings")):
        try:
            result = subprocess.run(
                ["/usr/bin/plutil", "-lint", str(path)],
                capture_output=True,
                text=True,
                check=False,
                timeout=10,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            errors.append(f"{path}: unable to validate .strings file: {error}")
            continue
        if result.returncode != 0:
            detail = (result.stdout + result.stderr).strip()
            errors.append(f"{path}: invalid .strings file: {detail}")
            continue
        try:
            entries = parse_strings_entries(decode_strings_file(path))
        except (OSError, UnicodeError, ValueError) as error:
            errors.append(f"{path}: invalid .strings file: {error}")
            continue
        seen = set()
        for key, _ in entries:
            if key in seen:
                errors.append(f"{path}: duplicate key {key!r}")
            seen.add(key)
        identity = localized_resource_identity(path, sources)
        if identity and not is_test_resource(path, sources):
            language, resource_name = identity
            if language in required_localizations:
                localized_documents.setdefault(resource_name, {})[language] = dict(entries)

    for resource_name, localizations in sorted(localized_documents.items()):
        english = localizations.get("en", {})
        for language in required_localizations:
            if language not in localizations:
                errors.append(f"{resource_name}[{language}]: localized resource is missing")
                continue
            document = localizations[language]
            for key in sorted(english.keys() - document.keys()):
                errors.append(f"{resource_name}[{language}]: missing key {key!r}")
            for key in sorted(document.keys() - english.keys()):
                errors.append(f"{resource_name}[{language}]: unexpected key {key!r}")
            for key in sorted(english.keys() & document.keys()):
                value = document[key]
                if not value.strip():
                    errors.append(f"{resource_name}[{language}]: {key}: translation is empty")
                    continue
                if language == "en":
                    continue
                source_signature = format_signature(english[key])
                translated_signature = format_signature(value)
                if not format_signatures_match(source_signature, translated_signature):
                    errors.append(
                        f"{resource_name}[{language}]: {key}: format placeholders differ"
                    )
                if control_structure_signature(english[key]) != control_structure_signature(value):
                    errors.append(
                        f"{resource_name}[{language}]: {key}: control structure differs"
                    )
    return errors


def flatten_plist_strings(value, path=()):
    if isinstance(value, str):
        yield path, value
    elif isinstance(value, dict):
        for key, child in value.items():
            yield from flatten_plist_strings(child, path + (str(key),))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from flatten_plist_strings(child, path + (str(index),))


def info_plist_usage_description_keys(value):
    if isinstance(value, dict):
        for key, child in value.items():
            if (
                isinstance(key, str)
                and INFO_PLIST_USAGE_DESCRIPTION_KEY.fullmatch(key)
            ):
                yield key
            yield from info_plist_usage_description_keys(child)
    elif isinstance(value, list):
        for child in value:
            yield from info_plist_usage_description_keys(child)


def check_info_plist_usage_descriptions(project_root, info_catalog_keys):
    """Require every privacy prompt declared by source plists in InfoPlist.xcstrings."""
    errors = []
    plist_root = project_root / "plists"
    if not plist_root.is_dir():
        return errors

    usage_description_sources = {}
    for path in sorted(plist_root.rglob("*.plist")):
        try:
            document = plistlib.loads(path.read_bytes())
        except (OSError, plistlib.InvalidFileException, ValueError, ExpatError) as error:
            errors.append(f"{path}: unable to inspect Info.plist privacy keys: {error}")
            continue
        for key in info_plist_usage_description_keys(document):
            usage_description_sources.setdefault(key, []).append(path)

    for key in sorted(usage_description_sources.keys() - info_catalog_keys):
        source_paths = ", ".join(str(path) for path in usage_description_sources[key])
        errors.append(
            f"{project_root / 'sources' / 'InfoPlist.xcstrings'}: missing "
            f"privacy usage description key {key!r} referenced by {source_paths}"
        )
    return errors


def check_stringsdict_syntax(sources, required_localizations):
    errors = []
    localized_documents = {}
    for path in sorted(sources.rglob("*.stringsdict")):
        try:
            data = path.read_bytes()
            document = plistlib.loads(data)
        except (OSError, plistlib.InvalidFileException, ValueError, ExpatError) as error:
            errors.append(f"{path}: invalid .stringsdict file: {error}")
            continue
        if not isinstance(document, dict):
            errors.append(f"{path}: invalid .stringsdict file: root must be a dictionary")
            continue
        if not data.startswith(b"bplist"):
            try:
                root = ElementTree.fromstring(data)
            except ElementTree.ParseError as error:
                errors.append(f"{path}: invalid .stringsdict file: {error}")
                continue
            for dictionary in root.iter("dict"):
                seen = set()
                for child in dictionary:
                    if child.tag != "key":
                        continue
                    key = child.text or ""
                    if key in seen:
                        errors.append(f"{path}: duplicate key {key!r}")
                    seen.add(key)
        identity = localized_resource_identity(path, sources)
        if identity and not is_test_resource(path, sources):
            language, resource_name = identity
            if language in required_localizations:
                localized_documents.setdefault(resource_name, {})[language] = document

    for resource_name, localizations in sorted(localized_documents.items()):
        english = localizations.get("en", {})
        for language in required_localizations:
            if language not in localizations:
                errors.append(f"{resource_name}[{language}]: localized resource is missing")
                continue
            document = localizations[language]
            for key in sorted(english.keys() - document.keys()):
                errors.append(f"{resource_name}[{language}]: missing key {key!r}")
            for key in sorted(document.keys() - english.keys()):
                errors.append(f"{resource_name}[{language}]: unexpected key {key!r}")
            if language == "en":
                continue
            for key in sorted(english.keys() & document.keys()):
                source_values = dict(flatten_plist_strings(english[key]))
                translated_values = dict(flatten_plist_strings(document[key]))
                source_metadata_paths = {
                    value_path
                    for value_path in source_values
                    if value_path and value_path[-1] in STRINGSDICT_FORMAT_METADATA_KEYS
                }
                translated_metadata_paths = {
                    value_path
                    for value_path in translated_values
                    if value_path and value_path[-1] in STRINGSDICT_FORMAT_METADATA_KEYS
                }
                for value_path in sorted(
                    source_metadata_paths - translated_metadata_paths
                ):
                    errors.append(
                        f"{resource_name}[{language}]: {key}: missing format "
                        f"metadata path {'.'.join(value_path)}"
                    )
                for value_path in sorted(
                    translated_metadata_paths - source_metadata_paths
                ):
                    errors.append(
                        f"{resource_name}[{language}]: {key}: unexpected format "
                        f"metadata path {'.'.join(value_path)}"
                    )
                for value_path in sorted(source_values.keys() & translated_values.keys()):
                    source_value = source_values[value_path]
                    translated_value = translated_values[value_path]
                    if not translated_value.strip():
                        errors.append(
                            f"{resource_name}[{language}]: {key}: translation is empty"
                        )
                        continue
                    leaf_name = value_path[-1] if value_path else ""
                    if leaf_name in STRINGSDICT_FORMAT_METADATA_KEYS - {
                        "NSStringLocalizedFormatKey"
                    }:
                        if source_value != translated_value:
                            errors.append(
                                f"{resource_name}[{language}]: {key}: format metadata differs"
                            )
                        continue
                    if not format_signatures_match(
                        format_signature(source_value), format_signature(translated_value)
                    ):
                        errors.append(
                            f"{resource_name}[{language}]: {key}: format placeholders differ"
                        )
                    if control_structure_signature(source_value) != control_structure_signature(
                        translated_value
                    ):
                        errors.append(
                            f"{resource_name}[{language}]: {key}: control structure differs"
                        )
    return errors


def source_without_comments(source):
    output = []
    index = 0
    quote = None
    block_comment_depth = 0
    line_comment = False
    while index < len(source):
        if line_comment:
            if source[index] == "\n":
                output.append("\n")
                line_comment = False
            else:
                output.append(" ")
            index += 1
            continue
        if block_comment_depth:
            if source.startswith("/*", index):
                output.extend((" ", " "))
                block_comment_depth += 1
                index += 2
            elif source.startswith("*/", index):
                output.extend((" ", " "))
                block_comment_depth -= 1
                index += 2
            else:
                output.append("\n" if source[index] == "\n" else " ")
                index += 1
            continue
        if quote:
            output.append(source[index])
            if source[index] == "\\" and index + 1 < len(source):
                output.append(source[index + 1])
                index += 2
                continue
            if source[index] == quote:
                quote = None
            index += 1
            continue
        if source.startswith("//", index):
            output.extend((" ", " "))
            line_comment = True
            index += 2
        elif source.startswith("/*", index):
            output.extend((" ", " "))
            block_comment_depth = 1
            index += 2
        else:
            if source[index] in {'"', "'"}:
                quote = source[index]
            output.append(source[index])
            index += 1
    return "".join(output)


def check_hardcoded_chinese(sources):
    errors = []
    for path in sorted(
        path for path in sources.rglob("*") if path.suffix in SOURCE_EXTENSIONS
    ):
        try:
            source = path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as error:
            errors.append(f"{path}: unable to scan source text: {error}")
            continue
        for line_number, line in enumerate(source_without_comments(source).splitlines(), 1):
            if HAN_CHARACTER.search(line):
                errors.append(
                    f"{path}:{line_number}: hard-coded Chinese text outside localization resources"
                )
    return errors


def contains_translatable_english_text(literal):
    without_placeholders = FORMAT_PLACEHOLDER.sub("", literal)
    without_escapes = SOURCE_STRING_ESCAPE.sub("", without_placeholders)
    return re.search(r"[A-Za-z]", without_escapes) is not None


def objc_variable_looks_like_ui_fragment(variable):
    lowered = variable.lower()
    return (
        lowered in {"base", "repr", "punctuated"}
        or lowered.endswith(OBJC_UI_FRAGMENT_VARIABLE_SUFFIXES)
    )


def objc_array_literal_end(source, content_start):
    square_depth = 1
    index = content_start
    while index < len(source):
        literal_match = OBJC_STRING_LITERAL.match(source, index)
        if literal_match is not None:
            index = literal_match.end()
            continue
        character = source[index]
        if character == "[":
            square_depth += 1
        elif character == "]":
            square_depth -= 1
            if square_depth == 0:
                return index
        index += 1
    return None


def objc_top_level_array_elements(body):
    elements = []
    start = 0
    square_depth = 0
    parenthesis_depth = 0
    brace_depth = 0
    index = 0
    while index < len(body):
        literal_match = OBJC_STRING_LITERAL.match(body, index)
        if literal_match is not None:
            index = literal_match.end()
            continue
        character = body[index]
        if character == "[":
            square_depth += 1
        elif character == "]":
            square_depth -= 1
        elif character == "(":
            parenthesis_depth += 1
        elif character == ")":
            parenthesis_depth -= 1
        elif character == "{":
            brace_depth += 1
        elif character == "}":
            brace_depth -= 1
        elif (
            character == ","
            and square_depth == 0
            and parenthesis_depth == 0
            and brace_depth == 0
        ):
            elements.append((start, body[start:index]))
            start = index + 1
        index += 1
    elements.append((start, body[start:]))
    return elements


def swift_delimited_expression_end(source, start, opener, closer):
    depth = 0
    index = start
    while index < len(source):
        if source.startswith('"""', index) or source[index] == '"':
            literal_end = swift_string_literal_end(source, index)
            if literal_end is None:
                return None
            index = literal_end
            continue
        character = source[index]
        if character == opener:
            depth += 1
        elif character == closer:
            depth -= 1
            if depth == 0:
                return index + 1
        index += 1
    return None


def swift_string_literal_end(source, start):
    delimiter = '"""' if source.startswith('"""', start) else '"'
    index = start + len(delimiter)
    while index < len(source):
        if source.startswith(delimiter, index):
            return index + len(delimiter)
        if source.startswith(r"\(", index):
            interpolation_end = swift_delimited_expression_end(
                source, index + 1, "(", ")"
            )
            if interpolation_end is None:
                return None
            index = interpolation_end
            continue
        if source[index] == "\\":
            index += 2
        else:
            index += 1
    return None


def swift_braced_block_end(source, open_brace):
    return swift_delimited_expression_end(source, open_brace, "{", "}")


def swift_array_literal_end(source, content_start):
    square_depth = 1
    index = content_start
    while index < len(source):
        if source.startswith('"""', index) or source[index] == '"':
            literal_end = swift_string_literal_end(source, index)
            if literal_end is None:
                return None
            index = literal_end
            continue
        character = source[index]
        if character == "[":
            square_depth += 1
        elif character == "]":
            square_depth -= 1
            if square_depth == 0:
                return index
        index += 1
    return None


def swift_top_level_array_elements(body):
    elements = []
    start = 0
    square_depth = 0
    parenthesis_depth = 0
    brace_depth = 0
    index = 0
    while index < len(body):
        if body.startswith('"""', index) or body[index] == '"':
            literal_end = swift_string_literal_end(body, index)
            if literal_end is None:
                break
            index = literal_end
            continue
        character = body[index]
        if character == "[":
            square_depth += 1
        elif character == "]":
            square_depth -= 1
        elif character == "(":
            parenthesis_depth += 1
        elif character == ")":
            parenthesis_depth -= 1
        elif character == "{":
            brace_depth += 1
        elif character == "}":
            brace_depth -= 1
        elif (
            character == ","
            and square_depth == 0
            and parenthesis_depth == 0
            and brace_depth == 0
        ):
            elements.append((start, body[start:index]))
            start = index + 1
        index += 1
    elements.append((start, body[start:]))
    return elements


def swift_localization_call_ranges(source):
    ranges = []
    pattern = re.compile(r"\bString\s*\(\s*localized\s*:")
    for match in pattern.finditer(source):
        open_parenthesis = source.find("(", match.start(), match.end())
        if open_parenthesis < 0:
            continue
        end = swift_delimited_expression_end(
            source, open_parenthesis, "(", ")"
        )
        if end is not None:
            ranges.append((match.start(), end))
    return ranges


def swift_ui_provider_selectors(path, sources):
    try:
        relative = path.relative_to(sources)
    except ValueError:
        return frozenset()
    if (
        relative.parts
        and relative.parts[0] == "Triggers"
        and path.stem.endswith("Trigger")
        and path.stem != "Trigger"
    ):
        return SWIFT_TRIGGER_PROVIDER_SELECTORS
    if relative.parts[:2] == ("StatusBar", "Components"):
        return SWIFT_STATUS_BAR_PROVIDER_SELECTORS
    return frozenset()


def check_hardcoded_english_swift_localized_interpolation_fallbacks(sources):
    errors = []
    for path in sorted(sources.rglob("*.swift")):
        try:
            source = source_without_comments(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError) as error:
            errors.append(f"{path}: unable to scan source text: {error}")
            continue
        for match in SWIFT_LOCALIZED_INTERPOLATION_FALLBACK.finditer(source):
            if not contains_translatable_english_text(match.group("literal")):
                continue
            line_number = source.count("\n", 0, match.start("literal")) + 1
            errors.append(
                f"{path}:{line_number}: hard-coded English text in Swift "
                "localized interpolation fallback"
            )
    return errors


def swift_body_is_shared_trigger_diagnostic(path, sources, declaration, body, source):
    """Classify only reviewed original instance descriptions with real log consumers."""
    original = SWIFT_SHARED_TRIGGER_DIAGNOSTIC_BODIES.get(path.stem)
    if (original is None
            or path.relative_to(sources).parts != ("Triggers", path.stem + ".swift")
            or re.fullmatch(r'\s*override\s+var\s+description\s*:\s*String\s*\{',
                            declaration.group(0)) is None):
        return False
    # As with the ObjC classifier, preserve literal spaces and identifier
    # boundaries. Interpolation text is conservatively compared as written.
    token = SWIFT_STRING_LITERAL.pattern + r"|\w+|\S"
    if path.stem == "EnterWorkgroupTrigger":
        # Its parameter row shares the helper with the logged description.
        # Restoring only the outer format must not hide translated fallbacks.
        helper = re.search(
            r'\bprivate\s+func\s+displayLabel\(forID\s+id:\s*String\?\)\s*->\s*String\s*\{',
            source)
        if helper is None:
            return False
        helper_end = swift_braced_block_end(source, helper.end() - 1)
        if (helper_end is None
                or re.findall(token, source[helper.end():helper_end - 1])
                != re.findall(token, SWIFT_WORKGROUP_DIAGNOSTIC_LABEL_BODY)):
            return False
    return (re.findall(token, body) == re.findall(token, original)
            and trigger_description_has_match_log_consumers(sources))


def check_hardcoded_english_swift_ui_providers(sources):
    errors = []
    for path in sorted(sources.rglob("*.swift")):
        selectors = swift_ui_provider_selectors(path, sources)
        if not selectors:
            continue
        try:
            source = source_without_comments(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError) as error:
            errors.append(f"{path}: unable to scan source text: {error}")
            continue
        declarations = []
        for pattern in (
            SWIFT_STRING_PROPERTY_DECLARATION,
            SWIFT_STRING_FUNCTION_DECLARATION,
        ):
            declarations.extend(pattern.finditer(source))
        for declaration in sorted(declarations, key=lambda match: match.start()):
            selector = declaration.group("selector")
            if selector not in selectors:
                continue
            block_end = swift_braced_block_end(
                source, declaration.start("open")
            )
            if block_end is None:
                continue
            body_start = declaration.start("open") + 1
            body = source[body_start:block_end - 1]
            if swift_body_is_shared_trigger_diagnostic(path, sources, declaration, body, source):
                continue
            localized_ranges = swift_localization_call_ranges(body)
            for literal_match in SWIFT_STRING_LITERAL.finditer(body):
                if any(
                    start <= literal_match.start() < end
                    for start, end in localized_ranges
                ):
                    continue
                literal = literal_match.group(0)[1:-1]
                if not contains_translatable_english_text(literal):
                    continue
                absolute_offset = body_start + literal_match.start()
                line_number = source.count("\n", 0, absolute_offset) + 1
                errors.append(
                    f"{path}:{line_number}: hard-coded English text returned "
                    f"by Swift UI provider '{selector}'"
                )
    return errors


def check_hardcoded_english_swift_ui_literals(sources):
    errors = []
    for path in sorted(sources.rglob("*.swift")):
        try:
            source = source_without_comments(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError) as error:
            errors.append(f"{path}: unable to scan source text: {error}")
            continue
        for line_number, line in enumerate(source.splitlines(), 1):
            for sink_match in SWIFT_UI_STRING_SINK.finditer(line):
                value_expression = line[sink_match.end():]
                if "String(localized:" in value_expression:
                    continue
                for literal_match in SWIFT_STRING_LITERAL.finditer(value_expression):
                    literal = literal_match.group(0)[1:-1]
                    if contains_translatable_english_text(literal):
                        errors.append(
                            f"{path}:{line_number}: hard-coded English text in "
                            f"Swift UI sink '{sink_match.group('sink')}'"
                        )
    return errors


def check_hardcoded_english_swift_action_labels(sources):
    errors = []
    for path in sorted(sources.rglob("*.swift")):
        try:
            source = source_without_comments(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError) as error:
            errors.append(f"{path}: unable to scan source text: {error}")
            continue
        for sink_match in SWIFT_ACTION_ARRAY_SINK.finditer(source):
            array_end = swift_array_literal_end(source, sink_match.end())
            if array_end is None:
                continue
            body = source[sink_match.end():array_end]
            for offset, element in swift_top_level_array_elements(body):
                literal_match = SWIFT_STRING_LITERAL.match(element.lstrip())
                if literal_match is None:
                    continue
                literal = literal_match.group(0)[1:-1]
                if not contains_translatable_english_text(literal):
                    continue
                absolute_offset = sink_match.end() + offset
                line_number = source.count("\n", 0, absolute_offset) + 1
                errors.append(
                    f"{path}:{line_number}: hard-coded English text in "
                    "Swift action label"
                )
        for sink_match in SWIFT_SINGLE_ACTION_LABEL_SINK.finditer(source):
            value_expression = source[sink_match.end():].lstrip()
            if value_expression.startswith("String(localized:"):
                continue
            literal_match = SWIFT_STRING_LITERAL.match(value_expression)
            if literal_match is None:
                continue
            literal = literal_match.group(0)[1:-1]
            if contains_translatable_english_text(literal):
                line_number = source.count("\n", 0, sink_match.start()) + 1
                errors.append(
                    f"{path}:{line_number}: hard-coded English text in "
                    "Swift action label"
                )
    return errors


def check_hardcoded_english_objc_ui_literals(sources):
    errors = []
    paths = sorted(
        path for path in sources.rglob("*") if path.suffix in {".m", ".mm"}
    )
    for path in paths:
        try:
            source = source_without_comments(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError) as error:
            errors.append(f"{path}: unable to scan source text: {error}")
            continue
        for sink_match in OBJC_UI_STRING_SINK.finditer(source):
            value_expression = source[sink_match.end():].lstrip()
            if value_expression.startswith("NSLocalizedString"):
                continue
            literal_match = OBJC_STRING_LITERAL.match(value_expression)
            if literal_match is None:
                format_prefix = re.match(
                    r"\[NSString\s+stringWithFormat\s*:\s*", value_expression
                )
                if format_prefix:
                    literal_match = OBJC_STRING_LITERAL.match(
                        value_expression[format_prefix.end():]
                    )
            if literal_match is None:
                continue
            literal = literal_match.group(0)[2:-1]
            if contains_translatable_english_text(literal):
                line_number = source.count("\n", 0, sink_match.start()) + 1
                errors.append(
                    f"{path}:{line_number}: hard-coded English text in "
                    f"Objective-C UI sink '{sink_match.group('sink')}'"
                )
    return errors


def check_hardcoded_english_objc_special_ui_literals(sources):
    errors = []
    paths = sorted(
        path for path in sources.rglob("*") if path.suffix in {".m", ".mm"}
    )
    for path in paths:
        try:
            source = source_without_comments(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError) as error:
            errors.append(f"{path}: unable to scan source text: {error}")
            continue
        special_sinks = (
            (OBJC_DELAYED_UI_STRING_SINK, None),
            (OBJC_ATTRIBUTED_UI_STRING_SINK, "initWithString"),
            (OBJC_SEARCHABLE_COMBO_LABEL_SINK, "initWithLabel"),
            (OBJC_CURSOR_PRESET_NAME_SINK, "initWithName"),
        )
        for pattern, fixed_sink in special_sinks:
            for sink_match in pattern.finditer(source):
                value_expression = source[sink_match.end():].lstrip()
                if value_expression.startswith("NSLocalizedString"):
                    continue
                literal_match = OBJC_STRING_LITERAL.match(value_expression)
                if literal_match is None:
                    continue
                literal = literal_match.group(0)[2:-1]
                if not contains_translatable_english_text(literal):
                    continue
                if (
                    fixed_sink == "initWithString"
                    and len(re.findall(r"[A-Za-z]", literal)) < 2
                ):
                    continue
                if fixed_sink is None:
                    sink = (
                        "performSelector:"
                        f"{sink_match.group('setter')}:withObject"
                    )
                else:
                    sink = fixed_sink
                line_number = source.count("\n", 0, sink_match.start()) + 1
                errors.append(
                    f"{path}:{line_number}: hard-coded English text in "
                    f"Objective-C UI sink '{sink}'"
                )
        # Scope prompt/message to these UI views, never model or protocol prompts.
        for initializer in OBJC_DISCLOSABLE_VIEW_INITIALIZER.finditer(source):
            end = objc_array_literal_end(source, initializer.start() + 1)
            if end is None:
                continue
            for argument in OBJC_DISCLOSABLE_TEXT_ARGUMENT.finditer(source, initializer.end(), end):
                expression = source[argument.end():end].lstrip()
                format_prefix = re.match(r"\[NSString\s+stringWithFormat\s*:\s*", expression)
                if format_prefix:
                    expression = expression[format_prefix.end():]
                literal_match = OBJC_STRING_LITERAL.match(expression)
                if literal_match is None:
                    continue
                if contains_translatable_english_text(literal_match.group(0)[2:-1]):
                    line_number = source.count("\n", 0, argument.start()) + 1
                    errors.append(
                        f"{path}:{line_number}: hard-coded English text in "
                        f"Objective-C UI sink 'disclosable {argument.group('sink')}'"
                    )
    return errors


def objc_assignment_is_used_only_by_logs(
    source, assignment_start, assignment_end, variable
):
    next_method = OBJC_METHOD_BOUNDARY.search(source, assignment_end)
    method_end = next_method.start() if next_method is not None else len(source)
    saw_log_use = False
    for use in re.finditer(
        rf"(?<![A-Za-z0-9_]){re.escape(variable)}\b",
        source[assignment_end:method_end],
    ):
        absolute_use = assignment_end + use.start()
        use_statement_start = max(
            source.rfind(";", assignment_end, absolute_use),
            source.rfind("{", assignment_end, absolute_use),
            source.rfind("}", assignment_end, absolute_use),
            assignment_end - 1,
        ) + 1
        use_statement_end = source.find(";", absolute_use, method_end)
        if use_statement_end < 0:
            return False
        statement = source[use_statement_start:use_statement_end]
        if not OBJC_LOG_CALL.search(statement):
            return False
        saw_log_use = True
    return saw_log_use


def objc_fallback_is_shared_transfer_diagnostic(path, sources, source, match, statement):
    """Recognize only the original manager fallback also consumed by RLog.

    The notification shares this diagnostic; it is not display-only copy.
    Keep other files, methods, sinks, and newly introduced fallback text checked.
    """
    if (path.relative_to(sources).parts != ("FileTransfer", "FileTransferManager.m")
            or match.group("literal") != '@"File transfer failed with an unknown error"'
            or re.fullmatch(
                r'\s*\[transferrableFile\s+didFailWithError:error\.localizedDescription\s*\?:\s*'
                r'@"File transfer failed with an unknown error"', statement) is None):
        return False
    boundaries = [item.start() for item in OBJC_METHOD_BOUNDARY.finditer(source)]
    method_start = objc_method_start(boundaries, match.start())
    declaration = re.match(
        r'-\s*\(void\)\s*transferrableFile:\s*\(TransferrableFile\s*\*\)transferrableFile\s+'
        r'didFinishTransmissionWithError:\s*\(NSError\s*\*\)error\s*\{', source[method_start:])
    if declaration is None:
        return False
    method_end = objc_braced_block_end(source, method_start + declaration.end() - 1)
    if method_end is None or match.end() >= method_end:
        return False
    try:
        consumer = source_without_comments(
            (sources / "FileTransfer/TransferrableFile.m").read_text(encoding="utf-8"))
    except (OSError, UnicodeError):
        return False
    failure = re.search(r'-\s*\(void\)\s*didFailWithError:\s*\(NSString\s*\*\)error\s*\{', consumer)
    if failure is None:
        return False
    failure_end = objc_braced_block_end(consumer, failure.end() - 1)
    return failure_end is not None and re.search(
        r'\bRLog\(@"didFailWithError:%@",\s*error\);',
        consumer[failure.end():failure_end]) is not None


def check_hardcoded_english_objc_localized_description_fallbacks(sources):
    errors = []
    paths = sorted(
        path for path in sources.rglob("*") if path.suffix in {".m", ".mm"}
    )
    for path in paths:
        try:
            source = source_without_comments(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError) as error:
            errors.append(f"{path}: unable to scan source text: {error}")
            continue
        for match in OBJC_LOCALIZED_DESCRIPTION_FALLBACK.finditer(source):
            literal = match.group("literal")[2:-1]
            if not contains_translatable_english_text(literal):
                continue
            statement_start = max(
                source.rfind(";", 0, match.start()),
                source.rfind("{", 0, match.start()),
                source.rfind("}", 0, match.start()),
            ) + 1
            statement = source[statement_start:match.end()]
            if OBJC_LOG_CALL.search(statement):
                continue
            if objc_fallback_is_shared_transfer_diagnostic(path, sources, source, match, statement):
                continue
            statement_end = source.find(";", match.end())
            if statement_end >= 0:
                assignment = re.match(
                    r"\s*(?:[A-Za-z_][A-Za-z0-9_]*(?:\s*<[^;{}=]+>)?"
                    r"\s*\*+\s*)?(?P<variable>[A-Za-z_][A-Za-z0-9_]*)"
                    r"\s*=",
                    source[statement_start:statement_end],
                )
                if assignment is not None and objc_assignment_is_used_only_by_logs(
                    source,
                    statement_start,
                    statement_end + 1,
                    assignment.group("variable"),
                ):
                    continue
            line_number = source.count("\n", 0, match.start("literal")) + 1
            errors.append(
                f"{path}:{line_number}: hard-coded English fallback after "
                "localizedDescription"
            )
    return errors


def check_hardcoded_english_objc_script_completion_messages(sources):
    errors = []
    for relative_parts in sorted(OBJC_SCRIPT_UI_COMPLETION_PATHS):
        path = sources.joinpath(*relative_parts)
        if not path.is_file():
            continue
        try:
            source = source_without_comments(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError) as error:
            errors.append(f"{path}: unable to scan source text: {error}")
            continue
        method_boundaries = [
            match.start() for match in OBJC_METHOD_BOUNDARY.finditer(source)
        ]
        seen = set()
        for call_match in OBJC_COMPLETION_CALL.finditer(source):
            call_end = objc_parenthesized_call_end(
                source, call_match.start("open")
            )
            if call_end is None:
                continue
            call = source[call_match.start():call_end]
            localized_ranges = objc_localization_call_ranges(call)
            for literal_match in OBJC_STRING_LITERAL.finditer(call):
                if any(
                    start <= literal_match.start() < end
                    for start, end in localized_ranges
                ):
                    continue
                literal = literal_match.group(0)[2:-1]
                if not contains_translatable_english_text(literal):
                    continue
                absolute_offset = call_match.start() + literal_match.start()
                seen.add(absolute_offset)
                line_number = source.count("\n", 0, absolute_offset) + 1
                errors.append(
                    f"{path}:{line_number}: hard-coded English text in "
                    "Objective-C script completion message"
                )
            arguments = source[call_match.start("open") + 1:call_end - 1]
            for _, argument in objc_top_level_array_elements(arguments):
                variable_match = re.fullmatch(
                    r"\s*(?P<variable>[A-Za-z_][A-Za-z0-9_]*)\s*",
                    argument,
                )
                if variable_match is None:
                    continue
                variable = variable_match.group("variable")
                if objc_declared_pointer_type(
                    source,
                    method_boundaries,
                    call_match.start(),
                    variable,
                ) not in OBJC_STRING_LIKE_TYPES:
                    continue
                for absolute_offset, _ in objc_unlocalized_assignment_literals(
                    source, method_boundaries, call_match.start(), variable
                ):
                    if absolute_offset in seen:
                        continue
                    seen.add(absolute_offset)
                    line_number = source.count("\n", 0, absolute_offset) + 1
                    errors.append(
                        f"{path}:{line_number}: hard-coded English text assigned "
                        f"to '{variable}' for Objective-C script completion message"
                    )
    return errors


def objc_parenthesized_call_end(source, open_parenthesis):
    depth = 0
    index = open_parenthesis
    while index < len(source):
        literal_match = OBJC_STRING_LITERAL.match(source, index)
        if literal_match:
            index = literal_match.end()
            continue
        if source[index] == "(":
            depth += 1
        elif source[index] == ")":
            depth -= 1
            if depth == 0:
                return index + 1
        index += 1
    return None


def objc_localization_call_ranges(source):
    ranges = []
    for match in OBJC_LOCALIZATION_CALL.finditer(source):
        end = objc_parenthesized_call_end(source, match.start("open"))
        if end is not None:
            ranges.append((match.start(), end))
    return ranges


def objc_statement_end(source, expression_start):
    parenthesis_depth = 0
    square_depth = 0
    brace_depth = 0
    index = expression_start
    while index < len(source):
        literal_match = OBJC_STRING_LITERAL.match(source, index)
        if literal_match:
            index = literal_match.end()
            continue
        character = source[index]
        if character == "(":
            parenthesis_depth += 1
        elif character == ")":
            parenthesis_depth -= 1
        elif character == "[":
            square_depth += 1
        elif character == "]":
            square_depth -= 1
        elif character == "{":
            brace_depth += 1
        elif character == "}":
            brace_depth -= 1
        elif (
            character == ";"
            and parenthesis_depth == 0
            and square_depth == 0
            and brace_depth == 0
        ):
            return index
        index += 1
    return None


def objc_method_start(method_boundaries, offset):
    return max(
        (boundary for boundary in method_boundaries if boundary < offset),
        default=0,
    )


def objc_unlocalized_assignment_literals(
    source, method_boundaries, before_offset, variable, visited_variables=None
):
    visited_variables = frozenset(visited_variables or ())
    if variable in visited_variables:
        return
    visited_variables = visited_variables | {variable}
    method_start = objc_method_start(method_boundaries, before_offset)
    method_source = source[method_start:before_offset]
    assignment_start_pattern = re.compile(
        rf"(?<![A-Za-z0-9_]){re.escape(variable)}\s*"
        rf"(?<![=!<>])=(?!=)\s*",
    )
    for assignment in assignment_start_pattern.finditer(method_source):
        expression_start = assignment.end()
        expression_end = objc_statement_end(method_source, expression_start)
        if expression_end is None:
            continue
        expression = method_source[expression_start:expression_end]
        localized_ranges = objc_localization_call_ranges(expression)
        literal_ranges = [
            (match.start(), match.end())
            for match in OBJC_STRING_LITERAL.finditer(expression)
        ]
        for literal_match in OBJC_STRING_LITERAL.finditer(expression):
            if any(
                start <= literal_match.start() < end
                for start, end in localized_ranges
            ):
                continue
            if objc_literal_is_dictionary_subscript_key(
                expression, literal_match.start(), literal_match.end()
            ):
                continue
            literal = literal_match.group(0)[2:-1]
            if not contains_translatable_english_text(literal):
                continue
            absolute_offset = (
                method_start + expression_start + literal_match.start()
            )
            yield absolute_offset, literal
        stripped_expression = expression.strip()
        can_trace_references = (
            re.fullmatch(
                r"[A-Za-z_][A-Za-z0-9_]*", stripped_expression
            )
            is not None
            or any(
                marker in expression
                for marker in OBJC_STRING_TRANSFORMATION_MARKERS
            )
        )
        if not can_trace_references:
            continue
        for reference in re.finditer(
            r"(?<![A-Za-z0-9_])(?P<variable>[A-Za-z_][A-Za-z0-9_]*)\b",
            expression,
        ):
            if any(
                start <= reference.start() < end
                for start, end in literal_ranges
            ):
                continue
            if any(
                start <= reference.start() < end
                for start, end in localized_ranges
            ):
                continue
            referenced_variable = reference.group("variable")
            if referenced_variable in visited_variables:
                continue
            if not objc_variable_looks_like_ui_fragment(referenced_variable):
                continue
            absolute_reference = (
                method_start + expression_start + reference.start()
            )
            declared_type = objc_declared_pointer_type(
                source,
                method_boundaries,
                absolute_reference,
                referenced_variable,
            )
            if declared_type not in OBJC_INDIRECT_VALUE_TYPES:
                continue
            yield from objc_unlocalized_assignment_literals(
                source,
                method_boundaries,
                method_start + assignment.start(),
                referenced_variable,
                visited_variables,
            )


def objc_literal_is_dictionary_subscript_key(source, start, end):
    """Return whether an Objective-C literal is the key in object[@"key"]."""
    before = start - 1
    while before >= 0 and source[before].isspace():
        before -= 1
    if before < 0 or source[before] != "[":
        return False

    container_end = before - 1
    while container_end >= 0 and source[container_end].isspace():
        container_end -= 1
    if container_end >= 0 and source[container_end] == "@":
        return False

    after = end
    while after < len(source) and source[after].isspace():
        after += 1
    return after < len(source) and source[after] == "]"


def objc_declared_pointer_type(source, method_boundaries, before_offset, variable):
    """Return the latest Objective-C pointer type declared for variable."""
    method_start = objc_method_start(method_boundaries, before_offset)
    method_source = source[method_start:before_offset]
    declaration_pattern = re.compile(
        rf"(?<![A-Za-z0-9_])(?P<type>[A-Za-z_][A-Za-z0-9_]*)"
        rf"(?:\s*<[^;{{}}=]+>)?\s*\*+\s*{re.escape(variable)}\b"
    )
    matches = list(declaration_pattern.finditer(method_source))
    if not matches:
        return None
    return matches[-1].group("type")


def objc_braced_block_end(source, open_brace):
    depth = 0
    index = open_brace
    while index < len(source):
        literal_match = OBJC_STRING_LITERAL.match(source, index)
        if literal_match is not None:
            index = literal_match.end()
            continue
        character = source[index]
        if character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return index + 1
        index += 1
    return None


def objc_ui_provider_selectors(path, sources):
    try:
        relative = path.relative_to(sources)
    except ValueError:
        return frozenset()
    if (
        relative.parts
        and relative.parts[0] == "Triggers"
        and path.stem.endswith("Trigger")
        and path.stem != "Trigger"
    ):
        return OBJC_TRIGGER_PROVIDER_SELECTORS
    if relative.parts[:2] == ("StatusBar", "Components"):
        return OBJC_STATUS_BAR_PROVIDER_SELECTORS
    if relative.parts == ("Keyboard", "iTermKeyBindingAction.m"):
        return frozenset({"displayName"})
    if relative.parts == ("OpenQuickly", "iTermOpenQuicklyCommands.m"):
        return OBJC_OPEN_QUICKLY_PROVIDER_SELECTORS
    return frozenset()


def objc_literal_is_shared_trigger_diagnostic(path, sources, declaration, body, literal_match):
    """Recognize reviewed original returns shared with both matched-trigger logs.

    This is a narrow classification, not a dataflow or matcher correctness proof.
    Native tests exercise the real description/title objects in both languages.
    New text, other providers, and changed consumers remain checked.
    """
    literal = literal_match.group(0)
    if (path.relative_to(sources).parts != ("Triggers", path.stem + ".m")
            or re.fullmatch(r'-\s*\(\s*NSString\s*\*\s*\)\s*description\s*\{',
                            declaration.group(0)) is None):
        return False
    original_body = OBJC_SHARED_TRIGGER_DIAGNOSTIC_BODIES.get(path.stem)
    if original_body is not None:
        # Preserve literal whitespace and identifier boundaries while allowing
        # formatting changes between tokens. Comments were stripped by caller.
        token = OBJC_STRING_LITERAL.pattern + r"|\w+|\S"
        if re.findall(token, body) != re.findall(token, original_body):
            return False
    else:
        if literal[2:-1] not in OBJC_SHARED_TRIGGER_DIAGNOSTICS.get(path.stem, ()):
            return False
        statement_start = max(body.rfind(delimiter, 0, literal_match.start())
                              for delimiter in (";", "{", "}")) + 1
        statement_end = body.find(";", literal_match.end())
        if statement_end < 0:
            return False
        value = re.escape(literal)
        expression = (rf'\[NSString\s+stringWithFormat:\s*{value}\s*,\s*self\.param\s*\]'
                      if "%@" in literal else value)
        if re.fullmatch(rf'\s*return\s+{expression}\s*;',
                        body[statement_start:statement_end + 1]) is None:
            return False
    return trigger_description_has_match_log_consumers(sources)


def trigger_description_has_match_log_consumers(sources):
    try:
        consumer = source_without_comments(
            (sources / "Triggers/Trigger.m").read_text(encoding="utf-8"))
    except (OSError, UnicodeError):
        return False
    method = re.search(r'-\s*\(BOOL\)\s*reallyTryString:[^{]*\{', consumer)
    if method is None:
        return False
    method_end = objc_braced_block_end(consumer, method.end() - 1)
    return method_end is not None and len(re.findall(
        r'\bDLog\(@"Trigger %@ matched string %@",\s*self,\s*s\);',
        consumer[method.end():method_end])) == 2


def check_hardcoded_english_objc_ui_providers(sources):
    errors = []
    paths = sorted(
        path for path in sources.rglob("*") if path.suffix in {".m", ".mm"}
    )
    for path in paths:
        selectors = objc_ui_provider_selectors(path, sources)
        if not selectors:
            continue
        try:
            source = source_without_comments(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError) as error:
            errors.append(f"{path}: unable to scan source text: {error}")
            continue
        for declaration in OBJC_STRING_METHOD_DECLARATION.finditer(source):
            selector = declaration.group("selector")
            if selector not in selectors:
                continue
            block_end = objc_braced_block_end(
                source, declaration.start("open")
            )
            if block_end is None:
                continue
            body_start = declaration.start("open") + 1
            body = source[body_start:block_end - 1]
            if (
                selector in OBJC_STATUS_BAR_PROVIDER_SELECTORS
                and "doesNotRecognizeSelector" in body
            ):
                continue
            localized_ranges = objc_localization_call_ranges(body)
            for literal_match in OBJC_STRING_LITERAL.finditer(body):
                if any(
                    start <= literal_match.start() < end
                    for start, end in localized_ranges
                ):
                    continue
                if objc_literal_is_dictionary_subscript_key(
                    body, literal_match.start(), literal_match.end()
                ):
                    continue
                literal = literal_match.group(0)[2:-1]
                if not contains_translatable_english_text(literal):
                    continue
                if objc_literal_is_shared_trigger_diagnostic(
                    path, sources, declaration, body, literal_match
                ):
                    continue
                absolute_offset = body_start + literal_match.start()
                line_number = source.count("\n", 0, absolute_offset) + 1
                errors.append(
                    f"{path}:{line_number}: hard-coded English text returned by "
                    f"Objective-C UI provider '{selector}'"
                )
    return errors


def objc_literal_is_shared_fork_diagnostic(path, sources, source, method_boundaries,
                                          sink, literal_offset, literal):
    """Only the two original PTY diagnostics shared with logs/terminal output.

    The notification reuses these verbatim. Translating them at construction
    changes taskDiedWithError's diagnostic payload, not just display copy.
    Keep this tied to the exact path, failure case, literals, and consumer.
    """
    if (path.relative_to(sources).parts != ("Tasks", "PTYTask.m")
            or sink.group("sink") != "withDescription"
            or sink.group("variable") != "error"
            or literal not in {
                "Unable to fork child process: you may have too many processes already running.",
                "%@ The system error was: %s",
            }):
        return False
    method_start = objc_method_start(method_boundaries, sink.start())
    if not re.match(r"-\s*\(void\)\s*didForkAndExec:", source[method_start:]):
        return False
    case_start = source.rfind("case ", method_start, literal_offset)
    case = re.match(r"case iTermJobManagerForkAndExecStatusFailedToFork:\s*\{", source[case_start:])
    if case is None:
        return False
    case_end = objc_braced_block_end(source, case_start + case.end() - 1)
    if case_end is None or not case_start < literal_offset < sink.start() < case_end:
        return False
    return re.search(r"\[self\.delegate\s+taskDiedWithError:\s*error\s*\];",
                     source[sink.end():case_end]) is not None


def check_hardcoded_english_objc_indirect_ui_literals(sources):
    errors = []
    paths = sorted(
        path for path in sources.rglob("*") if path.suffix in {".m", ".mm"}
    )
    for path in paths:
        try:
            source = source_without_comments(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError) as error:
            errors.append(f"{path}: unable to scan source text: {error}")
            continue
        method_boundaries = [match.start() for match in OBJC_METHOD_BOUNDARY.finditer(source)]
        seen = set()
        for sink_match in OBJC_INDIRECT_UI_SINK.finditer(source):
            variable = sink_match.group("variable")
            for absolute_offset, literal in objc_unlocalized_assignment_literals(
                source, method_boundaries, sink_match.start(), variable
            ):
                if objc_literal_is_shared_fork_diagnostic(
                    path, sources, source, method_boundaries, sink_match,
                    absolute_offset, literal
                ):
                    continue
                identity = (path, absolute_offset)
                if identity in seen:
                    continue
                seen.add(identity)
                line_number = source.count("\n", 0, absolute_offset) + 1
                errors.append(
                    f"{path}:{line_number}: hard-coded English text assigned to "
                    f"'{variable}' for Objective-C UI sink "
                    f"'{sink_match.group('sink')}'"
                )
        for sink_match in OBJC_UI_STRING_SINK.finditer(source):
            value_start = sink_match.end()
            while value_start < len(source) and source[value_start].isspace():
                value_start += 1
            if not source.startswith("[NSString", value_start):
                continue
            expression_end = objc_array_literal_end(source, value_start + 1)
            if expression_end is None:
                continue
            expression = source[value_start:expression_end + 1]
            if not re.match(
                r"\[NSString\s+stringWithFormat\s*:", expression
            ):
                continue
            if objc_localization_call_ranges(expression):
                continue
            literal_ranges = [
                (match.start(), match.end())
                for match in OBJC_STRING_LITERAL.finditer(expression)
            ]
            traced_variables = set()
            for reference in re.finditer(
                r"(?<![A-Za-z0-9_])(?P<variable>[A-Za-z_][A-Za-z0-9_]*)\b",
                expression,
            ):
                if any(
                    start <= reference.start() < end
                    for start, end in literal_ranges
                ):
                    continue
                variable = reference.group("variable")
                if variable in traced_variables:
                    continue
                if not objc_variable_looks_like_ui_fragment(variable):
                    continue
                declared_type = objc_declared_pointer_type(
                    source,
                    method_boundaries,
                    sink_match.start(),
                    variable,
                )
                if declared_type not in OBJC_STRING_LIKE_TYPES:
                    continue
                traced_variables.add(variable)
                for absolute_offset, _ in objc_unlocalized_assignment_literals(
                    source, method_boundaries, sink_match.start(), variable
                ):
                    identity = (path, absolute_offset)
                    if identity in seen:
                        continue
                    seen.add(identity)
                    line_number = source.count("\n", 0, absolute_offset) + 1
                    errors.append(
                        f"{path}:{line_number}: hard-coded English text assigned "
                        f"to '{variable}' for Objective-C UI sink "
                        f"'{sink_match.group('sink')}'"
                    )
        for sink_match in OBJC_DRAWN_STRING_SINK.finditer(source):
            variable = sink_match.group("variable")
            declared_type = objc_declared_pointer_type(
                source, method_boundaries, sink_match.start(), variable
            )
            if declared_type not in {
                "NSString",
                "NSMutableString",
                "NSAttributedString",
                "NSMutableAttributedString",
            }:
                continue
            for absolute_offset, _ in objc_unlocalized_assignment_literals(
                source, method_boundaries, sink_match.start(), variable
            ):
                identity = (path, absolute_offset)
                if identity in seen:
                    continue
                seen.add(identity)
                line_number = source.count("\n", 0, absolute_offset) + 1
                errors.append(
                    f"{path}:{line_number}: hard-coded English text assigned to "
                    f"'{variable}' for Objective-C UI sink "
                    f"'{sink_match.group('sink')}'"
                )
    return errors


def check_hardcoded_english_objc_indirect_action_labels(sources):
    errors = []
    paths = sorted(
        path for path in sources.rglob("*") if path.suffix in {".m", ".mm"}
    )
    for path in paths:
        try:
            source = source_without_comments(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError) as error:
            errors.append(f"{path}: unable to scan source text: {error}")
            continue
        method_boundaries = [match.start() for match in OBJC_METHOD_BOUNDARY.finditer(source)]
        seen = set()

        indirect_variables = []
        for sink_match in OBJC_ACTION_ARRAY_SINK.finditer(source):
            array_end = objc_array_literal_end(source, sink_match.end())
            if array_end is None:
                continue
            body = source[sink_match.end():array_end]
            for _, element in objc_top_level_array_elements(body):
                variable_match = re.match(
                    r"\s*(?P<variable>[A-Za-z_][A-Za-z0-9_]*)\b"
                    r"(?!\s*[.(\[])",
                    element,
                )
                if variable_match:
                    indirect_variables.append(
                        (sink_match.start(), variable_match.group("variable"))
                    )
        for sink_match in OBJC_INDIRECT_ACTIONS_SINK.finditer(source):
            indirect_variables.append(
                (sink_match.start(), sink_match.group("variable"))
            )

        for sink_offset, variable in indirect_variables:
            declared_type = objc_declared_pointer_type(
                source, method_boundaries, sink_offset, variable
            )
            if declared_type is not None and declared_type not in {
                "NSString",
                "NSMutableString",
                "NSArray",
                "NSMutableArray",
            }:
                continue
            for absolute_offset, _ in objc_unlocalized_assignment_literals(
                source, method_boundaries, sink_offset, variable
            ):
                identity = (path, absolute_offset)
                if identity in seen:
                    continue
                seen.add(identity)
                line_number = source.count("\n", 0, absolute_offset) + 1
                errors.append(
                    f"{path}:{line_number}: hard-coded English text assigned to "
                    f"'{variable}' for Objective-C action label"
                )
    return errors


def check_hardcoded_english_objc_action_labels(sources):
    errors = []
    paths = sorted(
        path for path in sources.rglob("*") if path.suffix in {".m", ".mm"}
    )
    for path in paths:
        try:
            source = source_without_comments(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError) as error:
            errors.append(f"{path}: unable to scan source text: {error}")
            continue
        for sink_match in OBJC_ACTION_ARRAY_SINK.finditer(source):
            array_end = objc_array_literal_end(source, sink_match.end())
            if array_end is None:
                continue
            body = source[sink_match.end():array_end]
            for offset, element in objc_top_level_array_elements(body):
                literal_match = OBJC_STRING_LITERAL.match(element.lstrip())
                if literal_match is None:
                    continue
                literal = literal_match.group(0)[2:-1]
                if not contains_translatable_english_text(literal):
                    continue
                absolute_offset = sink_match.end() + offset
                line_number = source.count("\n", 0, absolute_offset) + 1
                errors.append(
                    f"{path}:{line_number}: hard-coded English text in "
                    "Objective-C action label"
                )
        for sink_match in OBJC_SINGLE_ACTION_LABEL_SINK.finditer(source):
            value_expression = source[sink_match.end():].lstrip()
            if value_expression.startswith("NSLocalizedString"):
                continue
            literal_match = OBJC_STRING_LITERAL.match(value_expression)
            if literal_match is None:
                format_prefix = re.match(
                    r"\[NSString\s+stringWithFormat\s*:\s*", value_expression
                )
                if format_prefix:
                    literal_match = OBJC_STRING_LITERAL.match(
                        value_expression[format_prefix.end():]
                    )
            if literal_match is None:
                continue
            literal = literal_match.group(0)[2:-1]
            if contains_translatable_english_text(literal):
                line_number = source.count("\n", 0, sink_match.start()) + 1
                errors.append(
                    f"{path}:{line_number}: hard-coded English text in "
                    "Objective-C action label"
                )
    return errors


def check_localization_references(sources, known_keys):
    errors = []
    for path in sorted(
        path for path in sources.rglob("*") if path.suffix in SOURCE_EXTENSIONS
    ):
        try:
            source = source_without_comments(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError) as error:
            errors.append(f"{path}: unable to scan localization references: {error}")
            continue
        for pattern in SOURCE_LOCALIZATION_REFERENCE_PATTERNS:
            for match in pattern.finditer(source):
                key = match.group("key")
                if key in known_keys:
                    continue
                line_number = source.count("\n", 0, match.start()) + 1
                errors.append(
                    f"{path}:{line_number}: localization key {key!r} was not found"
                )
    return errors


def advanced_settings_localization_entries(source):
    """Extract display text, never defaults, from the model's DEFINE_* macros."""
    source = source_without_comments(source)
    sections = {}
    for match in re.finditer(r'^#define\s+(SECTION_\w+)\s+(@"(?:\\.|[^"\\])*")', source, re.MULTILINE):
        value = json.loads(match[2][1:])
        if not value.endswith(": "):
            raise ValueError(f"advanced settings section lacks ': ': {match[1]}")
        sections[match[1]] = value[:-2]

    def literal_value(expression):
        literals = list(OBJC_STRING_LITERAL.finditer(expression))
        if not literals or OBJC_STRING_LITERAL.sub("", expression).strip():
            raise ValueError(f"unsupported advanced settings display expression: {expression}")
        return "".join(json.loads(item[0][1:]) for item in literals)

    declarations = []
    continued_directive = False
    for line in source.splitlines(keepends=True):
        directive = continued_directive or line.lstrip().startswith("#")
        continued_directive = directive and line.rstrip().endswith("\\")
        declarations.append("\n" if directive else line)
    source = "".join(declarations)
    entries = {f"ui.advanced.group.{group}": group for group in sections.values()}
    for match in re.finditer(r'^DEFINE_(\w+)\s*\(', source, re.MULTILINE):
        end = objc_parenthesized_call_end(source, match.end() - 1)
        if end is None:
            raise ValueError("unterminated advanced settings definition")
        arguments = [value.strip() for _, value in objc_top_level_array_elements(source[match.end():end - 1])]
        if match[1].startswith("DEPRECATED_"):
            continue  # enumerateDictionaries explicitly excludes these from the UI.
        name = arguments[0]
        if not re.fullmatch(r"[A-Za-z_]\w*", name):
            raise ValueError(f"invalid advanced settings identifier: {name}")
        identifier = name[0].upper() + name[1:]
        section = re.match(r"(SECTION_\w+)\s+", arguments[-1])
        if section is None or section[1] not in sections:
            raise ValueError(f"unknown advanced settings section for {identifier}")
        key = f"ui.advanced.setting.{identifier}.description"
        if key in entries:
            raise ValueError(f"duplicate advanced settings identifier: {identifier}")
        entries[key] = literal_value(arguments[-1][section.end():])
        if match[1] == "INT_ENUM":
            options = arguments[-2]
            array_start = options.find("@[")
            array_end = objc_array_literal_end(options, array_start + 2)
            if array_start < 0 or array_end is None:
                raise ValueError(f"invalid advanced settings options for {identifier}")
            for index, (_, option) in enumerate(objc_top_level_array_elements(options[array_start + 2:array_end])):
                entries[f"ui.advanced.setting.{identifier}.option.{index}"] = literal_value(option)
    if not any(key.endswith(".description") for key in entries):
        raise ValueError("no advanced settings display definitions found")
    return entries


def check_advanced_settings_localization(sources, catalog_entries):
    model_path = sources / "Settings/iTermAdvancedSettingsModel.m"
    if not model_path.is_file():
        return []
    try:
        entries = advanced_settings_localization_entries(model_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, ValueError) as error:
        return [f"{model_path}: {error}"]
    errors = []
    for key, english in entries.items():
        record = catalog_entries.get(key)
        if record is None:
            errors.append(f"{model_path}: missing advanced settings localization key {key!r}")
            continue
        path, entry = record
        if entry.get("shouldTranslate") is False:
            errors.append(f"{path}: {key}: advanced settings text must be translatable")
        unit = entry.get("localizations", {}).get("en", {}).get("stringUnit", {})
        if unit.get("value") != english:
            errors.append(f"{path}: {key}: English fallback differs from advanced settings model")
    view_path = sources / "Settings/iTermAdvancedSettingsViewController.m"
    try:
        view_source = source_without_comments(view_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError) as error:
        errors.append(f"{view_path}: unable to inspect advanced settings display: {error}")
        return errors
    for marker in (
        '@"ui.advanced.group.%@"', '@"ui.advanced.setting.%@.description"',
        '@"ui.advanced.setting.%@.option.%lu"', 'localizedStringForKey:key',
        'temp[kAdvancedSettingDescription] = iTermAdvancedSettingsLocalizedDescription(dict, remainder)',
        'iTermAdvancedSettingsLocalizedGroup(groupName)',
        'iTermAdvancedSettingsSearchText(dict)',
        'iTermAdvancedSettingsLocalizedOption(identifier, index, title)',
    ):
        if marker not in view_source:
            errors.append(f"{view_path}: advanced settings localization runtime is missing {marker!r}")
    return errors


def check_tip_data_localization(sources, catalog_entries):
    """Ensure every app-owned Tip of the Day field is localized by stable tip ID."""
    path = sources / "TIps" / "iTermTipData.m"
    if not path.is_file():
        return []
    try:
        source = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        return [f"{path}: unable to inspect Tip of the Day data: {error}"]

    errors = []
    entries = list(TIP_DATA_ENTRY.finditer(source_without_comments(source)))
    if not entries:
        return [f"{path}: no Tip of the Day entries were found"]

    identifiers = [entry.group("identifier") for entry in entries]
    duplicates = sorted(
        identifier for identifier in set(identifiers) if identifiers.count(identifier) > 1
    )
    for identifier in duplicates:
        errors.append(f"{path}: duplicate tip identifier {identifier!r}")

    runtime_markers = (
        '@"ui.tips.data.%@.%@"',
        "localizedStringForKey:key",
        'iTermLocalizedTipValue(identifier, @"title"',
        'iTermLocalizedTipValue(identifier, @"body"',
    )
    for marker in runtime_markers:
        if marker not in source:
            errors.append(
                f"{path}: Tip of the Day localization runtime is missing {marker!r}"
            )

    for entry in entries:
        identifier = entry.group("identifier")
        fields = entry.group("fields")
        for field_name, pattern in TIP_DATA_FIELD.items():
            field_match = pattern.search(fields)
            if field_match is None:
                errors.append(
                    f"{path}: tip {identifier!r} is missing {field_name} source text"
                )
                continue
            source_value = field_match.group("value")
            key = f"ui.tips.data.{identifier}.{field_name}"
            catalog_record = catalog_entries.get(key)
            if catalog_record is None:
                errors.append(
                    f"{path}: tip {identifier!r} {field_name} is missing "
                    f"localization key {key!r}"
                )
                continue
            catalog_path, catalog_entry = catalog_record
            if catalog_entry.get("shouldTranslate") is False:
                errors.append(f"{catalog_path}: {key}: tip text must be translatable")
                continue
            localizations = catalog_entry.get("localizations", {})
            english_units = dict(string_units(localizations.get("en")))
            english_unit = english_units.get("stringUnit", {})
            if english_unit.get("value") != source_value:
                errors.append(
                    f"{catalog_path}: {key}: English fallback differs from "
                    f"iTermTipData.m"
                )
    return errors


def check_xib_catalog_membership(project_root, catalogs):
    errors = []
    xib_catalogs = []
    for catalog in catalogs:
        root_xib = catalog.with_suffix(".xib")
        base_xib = catalog.parent / "Base.lproj" / f"{catalog.stem}.xib"
        if root_xib.is_file():
            errors.append(
                f"{root_xib}: localized XIB must be in Base.lproj"
            )
        elif base_xib.is_file():
            xib_catalogs.append(catalog)
    if not xib_catalogs:
        return errors
    project_file = project_root / "iTerm2.xcodeproj" / "project.pbxproj"
    try:
        project = project_file.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        errors.append(
            f"{project_file}: unable to inspect XIB target membership: {error}"
        )
        return errors

    native_targets_section_match = re.search(
        r"/\* Begin PBXNativeTarget section \*/"
        r"(?P<body>.*?)"
        r"/\* End PBXNativeTarget section \*/",
        project,
        re.DOTALL,
    )
    main_target_build_phase_ids = set()
    if native_targets_section_match:
        for target_match in re.finditer(
            r"^\s*[A-F0-9]{24}\b.*?=\s*\{"
            r"(?P<body>.*?)"
            r"^\s*\};",
            native_targets_section_match.group("body"),
            re.MULTILINE | re.DOTALL,
        ):
            target_body = target_match.group("body")
            if not re.search(r"\bisa\s*=\s*PBXNativeTarget\s*;", target_body):
                continue
            if not re.search(
                r'^\s*name\s*=\s*(?:iTerm2|"iTerm2")\s*;',
                target_body,
                re.MULTILINE,
            ):
                continue
            build_phases_match = re.search(
                r"\bbuildPhases\s*=\s*\((?P<phases>.*?)\);",
                target_body,
                re.DOTALL,
            )
            if build_phases_match:
                main_target_build_phase_ids.update(
                    re.findall(
                        r"\b[A-F0-9]{24}\b",
                        build_phases_match.group("phases"),
                    )
                )
            break
    if not main_target_build_phase_ids:
        errors.append(
            f"{project_file}: unable to find build phases for the main iTerm2 target"
        )

    resources_section_match = re.search(
        r"/\* Begin PBXResourcesBuildPhase section \*/"
        r"(?P<body>.*?)"
        r"/\* End PBXResourcesBuildPhase section \*/",
        project,
        re.DOTALL,
    )
    resource_build_file_ids = set()
    if resources_section_match:
        for phase_match in re.finditer(
            r"^\s*(?P<id>[A-F0-9]{24})\b.*?=\s*\{"
            r"(?P<body>.*?)"
            r"^\s*\};",
            resources_section_match.group("body"),
            re.MULTILINE | re.DOTALL,
        ):
            if phase_match.group("id") not in main_target_build_phase_ids:
                continue
            files_match = re.search(
                r"\bfiles\s*=\s*\((?P<files>.*?)\);",
                phase_match.group("body"),
                re.DOTALL,
            )
            if not files_match:
                continue
            resource_build_file_ids.update(
                re.findall(r"\b[A-F0-9]{24}\b", files_match.group("files"))
            )

    lines = project.splitlines()
    for catalog in xib_catalogs:
        path_tokens = (
            f"path = {catalog.name};",
            f'path = "{catalog.name}";',
        )
        file_reference_ids = []
        for line in lines:
            if "isa = PBXFileReference;" not in line:
                continue
            if not any(token in line for token in path_tokens):
                continue
            match = re.match(r"\s*([A-F0-9]+)\b", line)
            if match:
                file_reference_ids.append(match.group(1))
        build_file_ids = set()
        for file_reference_id in file_reference_ids:
            build_file_pattern = re.compile(
                rf"^\s*([A-F0-9]+)\b.*isa = PBXBuildFile;.*"
                rf"fileRef = {re.escape(file_reference_id)}\b",
                re.MULTILINE,
            )
            for match in build_file_pattern.finditer(project):
                build_file_ids.add(match.group(1))
        if not build_file_ids & resource_build_file_ids:
            errors.append(
                f"{catalog}: XIB catalog is not in the main iTerm2 target's "
                "Resources build phase"
            )
    return errors


def check_project(project_root):
    project_root = project_root.resolve()
    sources = project_root / "sources"
    if not sources.is_dir():
        return [f"resource directory does not exist: {sources}"], 0

    required_localizations, errors = registered_localizations(sources)
    if not any(path.is_dir() for path in sources.rglob("Base.lproj")):
        errors.append(f"{sources}: Base localization directory is missing")
    for localization_directory in sorted(sources.rglob("*.lproj")):
        if not localization_directory.is_dir() or localization_directory.stem == "Base":
            continue
        if localization_directory.stem not in required_localizations:
            errors.append(
                f"{localization_directory}: localization directory "
                f"'{localization_directory.name}' is not registered"
            )
    catalogs = list(sources.rglob("*.xcstrings"))
    uk_crash_reporter_catalog = (
        project_root
        / "ThirdParty"
        / "UKCrashReporter"
        / "UKCrashReporter.xcstrings"
    )
    if uk_crash_reporter_catalog.is_file():
        catalogs.append(uk_crash_reporter_catalog)
    catalogs = sorted(catalogs)
    if not catalogs:
        errors.append(f"no string catalogs found under: {sources}")
        return errors, 0

    checked_entries = 0
    catalog_localizations = set()
    catalog_keys = set()
    catalog_entries = {}
    info_catalog_keys = None
    info_catalog_path = sources / "InfoPlist.xcstrings"
    if info_catalog_path not in catalogs:
        errors.append(f"{info_catalog_path}: required Info.plist catalog is missing")
    for path in catalogs:
        try:
            document = json.loads(
                path.read_text(encoding="utf-8"),
                object_pairs_hook=reject_duplicate_json_keys,
            )
        except (
            OSError,
            UnicodeError,
            json.JSONDecodeError,
            DuplicateJSONKeyError,
        ) as error:
            errors.append(f"{path}: invalid string catalog: {error}")
            continue
        if document.get("sourceLanguage") != "en":
            errors.append(f"{path}: sourceLanguage must be 'en'")
        strings = document.get("strings")
        if not isinstance(strings, dict):
            errors.append(f"{path}: top-level 'strings' value must be an object")
            continue
        checked_entries += len(strings)
        catalog_keys.update(strings)
        if path == info_catalog_path:
            info_catalog_keys = set(strings)
        for key, entry in strings.items():
            if not isinstance(entry, dict):
                errors.append(f"{path}: {key}: entry must be an object")
                continue
            catalog_entries.setdefault(key, (path, entry))
            if entry.get("shouldTranslate") is False:
                continue
            localizations = entry.get("localizations")
            if not isinstance(localizations, dict):
                localizations = {}
            catalog_localizations.update(localizations)
            for language in required_localizations:
                if language not in localizations:
                    errors.append(
                        f"{path}: {key}: missing localization '{language}'"
                    )
                    continue
                units = list(string_units(localizations[language]))
                if not units:
                    errors.append(
                        f"{path}: {key}[{language}]: localization has no string unit"
                    )
                    continue
                for unit_path, unit in units:
                    value = unit.get("value")
                    if not isinstance(value, str) or not value.strip():
                        errors.append(
                            f"{path}: {key}[{language}]: translation is empty "
                            f"at {unit_path}"
                        )
                    elif key.startswith(RAILROAD_LABEL_KEY_PREFIX) and any(
                        character in RAILROAD_DSL_UNSAFE_CHARACTERS
                        for character in value
                    ):
                        errors.append(
                            f"{path}: {key}[{language}]: railroad label contains "
                            f"a DSL delimiter at {unit_path}"
                        )
                    if language != "en" and unit.get("state") != "translated":
                        errors.append(
                            f"{path}: {key}[{language}]: translation state is "
                            f"{unit.get('state')!r} at {unit_path}"
                        )
            source_units = {
                unit_path: unit
                for unit_path, unit in string_units(localizations.get("en"))
            }
            translated_units = {
                unit_path: unit
                for unit_path, unit in string_units(localizations.get("zh-Hans"))
            }
            source_shapes = {
                variation_path_shape(unit_path) for unit_path in source_units
            }
            translated_shapes = {
                variation_path_shape(unit_path) for unit_path in translated_units
            }
            if source_shapes != translated_shapes:
                errors.append(
                    f"{path}: {key}[zh-Hans]: variation structure differs: "
                    f"en={sorted(source_shapes)!r}, "
                    f"zh-Hans={sorted(translated_shapes)!r}"
                )
            for unit_path in sorted(source_units.keys() & translated_units.keys()):
                source_value = source_units[unit_path].get("value")
                translated_value = translated_units[unit_path].get("value")
                if not isinstance(source_value, str) or not isinstance(
                    translated_value, str
                ):
                    continue
                source_signature = format_signature(source_value)
                translated_signature = format_signature(translated_value)
                if not format_signatures_match(
                    source_signature, translated_signature
                ):
                    errors.append(
                        f"{path}: {key}[zh-Hans]: format placeholders differ "
                        f"at {unit_path}: en={source_signature!r}, "
                        f"zh-Hans={translated_signature!r}"
                    )
                source_control = control_structure_signature(source_value)
                translated_control = control_structure_signature(translated_value)
                if source_control != translated_control:
                    errors.append(
                        f"{path}: {key}[zh-Hans]: control structure differs "
                        f"at {unit_path}: en={source_control!r}, "
                        f"zh-Hans={translated_control!r}"
                    )
            if source_units.keys() != translated_units.keys():
                for shape in sorted(source_shapes & translated_shapes):
                    source_values = [
                        unit.get("value")
                        for unit_path, unit in source_units.items()
                        if variation_path_shape(unit_path) == shape
                        and isinstance(unit.get("value"), str)
                    ]
                    translated_values = [
                        unit.get("value")
                        for unit_path, unit in translated_units.items()
                        if variation_path_shape(unit_path) == shape
                        and isinstance(unit.get("value"), str)
                    ]
                    source_signatures = {
                        format_signature(value) for value in source_values
                    }
                    translated_signatures = {
                        format_signature(value) for value in translated_values
                    }
                    signatures_match = source_signatures == translated_signatures
                    if (
                        not signatures_match
                        and len(source_signatures) == 1
                        and len(translated_signatures) == 1
                    ):
                        signatures_match = format_signatures_match(
                            next(iter(source_signatures)),
                            next(iter(translated_signatures)),
                        )
                    if not signatures_match:
                        errors.append(
                            f"{path}: {key}[zh-Hans]: format placeholders differ "
                            f"across variation {shape}"
                        )
                    source_controls = {
                        control_structure_signature(value) for value in source_values
                    }
                    translated_controls = {
                        control_structure_signature(value)
                        for value in translated_values
                    }
                    if source_controls != translated_controls:
                        errors.append(
                            f"{path}: {key}[zh-Hans]: control structure differs "
                            f"across variation {shape}"
                        )
    for language in sorted(catalog_localizations - set(required_localizations)):
        errors.append(f"localization '{language}' is not registered")
    for language in sorted(set(required_localizations) - catalog_localizations):
        errors.append(f"registered localization '{language}' has no resources")
    if info_catalog_keys is not None:
        errors.extend(
            check_info_plist_usage_descriptions(project_root, info_catalog_keys)
        )
    errors.extend(check_strings_syntax(sources, required_localizations))
    errors.extend(check_stringsdict_syntax(sources, required_localizations))
    errors.extend(check_about_product_name(sources))
    errors.extend(check_hardcoded_chinese(sources))
    errors.extend(check_hardcoded_english_swift_ui_literals(sources))
    errors.extend(check_hardcoded_english_swift_action_labels(sources))
    errors.extend(
        check_hardcoded_english_swift_localized_interpolation_fallbacks(
            sources
        )
    )
    errors.extend(check_hardcoded_english_swift_ui_providers(sources))
    errors.extend(check_hardcoded_english_objc_ui_literals(sources))
    errors.extend(check_hardcoded_english_objc_special_ui_literals(sources))
    errors.extend(
        check_hardcoded_english_objc_localized_description_fallbacks(sources)
    )
    errors.extend(check_hardcoded_english_objc_script_completion_messages(sources))
    errors.extend(check_hardcoded_english_objc_indirect_ui_literals(sources))
    errors.extend(check_hardcoded_english_objc_action_labels(sources))
    errors.extend(check_hardcoded_english_objc_indirect_action_labels(sources))
    errors.extend(check_hardcoded_english_objc_ui_providers(sources))
    errors.extend(check_localization_references(sources, catalog_keys))
    errors.extend(check_tip_data_localization(sources, catalog_entries))
    errors.extend(check_advanced_settings_localization(sources, catalog_entries))
    errors.extend(check_xib_catalog_membership(project_root, catalogs))
    return errors, checked_entries


def main(argv=None):
    arguments = parse_arguments(argv)
    errors, checked_entries = check_project(arguments.project_root)
    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        print(f"Localization check failed with {len(errors)} error(s).", file=sys.stderr)
        return 1
    print(f"Localization check passed ({checked_entries} entries checked).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
