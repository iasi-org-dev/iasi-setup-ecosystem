"""Apply reviewed structural documentation without rewriting Java statements."""

from pathlib import Path
import re

PROJECT = Path(__file__).resolve().parents[4]
AUTHOR = "Javier G. Grandez"
VERSION = "0.1.0"
DATE = "2026-11-19"

PURPOSES = {
    "RC": "Defines composable IASI return-code bits without deciding execution flow.",
    "Verbosity": "Names console visibility levels independently of application commands.",
    "MessageCatalog": "Resolves localized message templates using an explicit resource bundle and locale.",
    "Severity": "Associates message severity with console presentation colors.",
    "Redactor": "Removes control characters and recognizable credentials before text reaches log sinks.",
    "MessageDefinition": "Describes a localized event independently of its logging backend.",
    "LogSink": "Accepts sanitized events through a backend-neutral output contract.",
    "Loggers": "Composes the default console and file backends without depending on application state.",
    "Logger": "Localizes and sanitizes events before distributing them to persistent and console sinks.",
    "LogEvent": "Carries immutable event metadata and sanitized text shared by all output backends.",
    "FileLogSink": "Persists UTF-8 events without console colors in an exclusively created execution log.",
    "ConsoleSink": "Formats and filters console messages while preserving borrowed output streams.",
    "OperationResult": "Combines optional operation data with an explicit return-code mask, without inferring status from messages.",
    "Platform": "Describes host OS and runtime properties without claiming virtualization capabilities.",
    "Platform.Family": "Groups recognized operating systems while retaining an explicit unknown case.",
    "ValueConversion": "Converts textual values to reusable Java types, using ISO date and time formats.",
    "ValueConstraints": "Checks numeric bounds and positive-integer constraints independently of CLI definitions.",
    "ValueConstraintException": "Distinguishes a violated value constraint from an unparseable lexical value.",
    "PathValidation": "Checks filesystem object types and prepares missing paths when their policy permits creation.",
    "App": "Defines the process entry point and the current initialize-and-inspect application sequence.",
    "Initializer": "Coordinates configuration layers in precedence order and returns the validated singleton context.",
    "Context": "Holds one single-threaded execution state, borrowed console streams and immutable original target selections.",
    "ContextValidator": "Publishes validated application values and resolves targets, aborting initialization on known failures.",
    "InitializationMessages": "Reports application initialization diagnostics and terminates failed initialization with the accumulated return code.",
    "ContextSummary": "Prints the temporary console-only view of effective execution values and target selections.",
    "Help": "Renders localized CLI help as plain text, preserving spacing and obtaining its version from build metadata.",
    "ExternalConfiguration": "Loads one external TOML layer into textual working arguments without provisioning machines.",
    "TargetDiscovery": "Discovers immediate target directories without interpreting command-line selection patterns.",
    "ARG": "Declares the immutable identity, data class and constraints of one supported argument.",
    "ArgClass": "Identifies the data representation required when transforming a textual argument value.",
    "ArgType": "Distinguishes flags, named parameters, definitions and positional targets.",
    "ArgsList": "Indexes supported argument declarations and exposes their environment bindings and effective-value schema.",
    "Arguments": "Stores syntax-only command-line data in indexed name/value lists, preserving occurrence order.",
    "WorkingArguments": "Accumulates textual configuration layers and keeps unclassified environment values separate until reconciliation.",
    "ArgumentAccess": "Reads indexed parameter occurrences without interpreting their data types or executing application actions.",
    "ArgumentConstraints": "Applies ARG constraints using reusable numeric and filesystem validation services.",
    "ArgumentDefinitionsValidator": "Checks loaded CLI names and multiplicity against the declarations accepted by the application.",
    "ArgumentException": "Carries a controlled diagnostic key for an invalid application argument.",
    "ArgumentTransformer": "Selects reusable text conversions from ARG metadata and translates conversion failures to diagnostic keys.",
    "ArgumentValidator": "Validates supported working values and constraints before preparing declared filesystem paths.",
    "ArgumentValuesLoader": "Splits comma-separated values while respecting quotes that survived shell tokenization.",
    "ArgumentValuesLoader.State": "Tracks the current quoted segment and completed values during one parameter scan.",
    "CommandLineLoader": "Loads CLI syntax during construction and aborts locally on malformed tokens, without consulting the argument schema.",
    "CommandLineArguments": "Applies explicit CLI values and reconciles remaining environment entries with supported argument declarations.",
    "EnvironmentArguments": "Reads uppercase environment bindings using the selected prefix and preserves unclassified values for later reconciliation.",
    "TargetValidator": "Matches original regular expressions against discovered target names without modifying the original patterns.",
    "TargetValidator.Selection": "Separates immutable selected paths from original patterns that matched no target.",
    "RCTest": "Checks the return-code bit contract and its independence from execution decisions.",
    "SourceGateTest": "Exercises source metrics and style checks using isolated synthetic Java fixtures.",
    "JavadocGateTest": "Checks structural documentation failures without demanding comments on self-explanatory methods.",
    "DependencyDirectionTest": "Protects reusable package boundaries and application-owned process termination points.",
    "PlatformTest": "Checks host classification and explicit operation status using simulated system properties.",
    "LoggerTest": "Checks backend substitution, shared sanitized events and output resource ownership.",
    "LoggerTest.Definition": "Supplies test-local event metadata without depending on an application message catalog.",
    "LoggerTest.RecordingSink": "Records emitted events and simulates backend write and close failures.",
    "LoggerTest.TrackingStream": "Detects accidental closure of a stream borrowed by the console sink.",
    "FileLogSinkTest": "Checks the agreed executable-and-timestamp log filename.",
    "ConsoleSinkTest": "Checks operational console formatting, error routing and optional colors independently of help output.",
    "ValueConversionTest": "Checks numeric, calendar, URI and email conversion boundaries using application-independent services.",
    "ArgsListTest": "Checks argument constructors, accepted names and environment binding declarations.",
    "ArgumentValidatorTest": "Checks mandatory values, typed lists and filesystem preparation for declared arguments.",
    "WorkingArgumentsTest": "Checks layer updates, deferred environment classification and preservation of textual flag values.",
    "TargetsTest": "Checks regex selection, unmatched patterns and preservation of original target lists.",
    "CommandLineLoaderTest": "Checks syntax-only token loading, indexed occurrences and surviving quote boundaries.",
    "ExternalConfigurationTest": "Checks textual TOML scalar and array loading and rejection of malformed documents.",
    "ContextTest": "Checks singleton identity, immutable original targets and single-threaded return-code accumulation.",
    "HelpTest": "Checks exact localized help layout, build-version reporting and the absence of operational prefixes.",
    "SourceGate": "Checks source encoding, style and callable complexity while treating method documentation as optional.",
    "SourceGate.Source": "Relates parsed Java trees to their original source positions for metric calculations.",
    "SourceGate.Metrics": "Counts control-flow complexity and nesting within an inspected callable.",
}

PACKAGES = {
    "org.iasi.base": "Defines application-independent return-code bits and visibility levels; it depends only on the JDK.",
    "org.iasi.common.i18n": "Loads localized catalogs without imposing console or logging presentation rules.",
    "org.iasi.common.logging": "Provides reusable logging ports, event sanitization and console/file adapters without application-context dependencies.",
    "org.iasi.common.operation": "Represents operation data and explicit status masks without deciding whether the caller continues execution.",
    "org.iasi.common.platform": "Identifies host operating-system and runtime properties without probing machine provisioning capabilities.",
    "org.iasi.common.validation": "Converts textual values and checks reusable numeric and filesystem constraints without CLI or application dependencies.",
    "org.iasi.setupdev": "Contains the executable entry point for the development-ecosystem setup application.",
    "org.iasi.setupdev.args": "Loads CLI syntax, declares supported arguments and reconciles textual configuration layers before context publication.",
    "org.iasi.setupdev.configuration": "Reads external TOML configuration as textual argument data without creating or starting virtual machines.",
    "org.iasi.setupdev.console": "Presents application help and the temporary context summary; help bypasses operational logging formatting.",
    "org.iasi.setupdev.core": "Coordinates initialization, owns the single-threaded execution context and publishes validated effective values.",
    "org.iasi.setupdev.messages": "Reports application-specific initialization diagnostics using reusable console infrastructure and the execution return code.",
    "org.iasi.setupdev.targets": "Discovers target directories while leaving regex selection and machine operations to other components.",
}

CONTRACTS = {
    ("Context", "initializeTargets"): "Copies the original target patterns once; later selections must use the separate resolved-target list.\n@throws IllegalStateException if the originals were already initialized",
    ("Context", "getTargets"): "Returns immutable original patterns in CLI order. An empty list requests all discovered targets.",
    ("Context", "setRC"): "Accumulates status bits with OR only; it neither validates the mask nor changes execution flow.",
    ("Logger", "emit"): "Writes the persistent sink before the console, so a persistence failure cannot announce a successfully logged event.\n@throws IOException if either output backend fails",
    ("Logger", "close"): "Attempts to close both sinks, retaining a second failure as a suppressed exception.",
    ("Logger", "earlyError"): "Reports a bootstrap error without opening a file or requiring a persistent logging backend.",
    ("ConsoleSink", "close"): "Flushes borrowed stdout/stderr streams without closing them.",
    ("FileLogSink", "FileLogSink"): "Requires a previously prepared directory and exclusively creates the execution log without overwriting an existing file.\n@throws IOException if creation fails, including a filename collision",
    ("LogSink", "close"): "Releases only resources owned by this sink; borrowed process streams must remain open.",
    ("LogSink", "write"): "Consumes an already sanitized event without changing its identity, timestamp or severity.",
    ("WorkingArguments", "setArgument"): "Updates an already classified value or defers a new environment name without guessing whether it is a flag, parameter or definition.",
    ("ArgumentValidator", "validateArgs"): "Checks all supplied values before creating declared paths. The caller publishes the returned typed values to its context.\n@throws IOException if an allowed path cannot be created",
    ("Help", "show"): "Writes plain help text without logging prefixes or colors and leaves the caller-owned stream open.\n@param out destination for help text",
    ("PathValidation", "prepare"): "Creates only missing paths whose policy permits creation; callers must check constraints first.\n@throws IOException if the filesystem cannot create the requested path",
}

TOKENS = re.compile(r'"""[\s\S]*?"""|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|/\*\*[\s\S]*?\*/')
TYPE = re.compile(r'(?m)^(?P<indent> *)(?:(?:public|private|protected|abstract|static|final|sealed|non-sealed)\s+)*(?:class|interface|enum|record|@interface)\s+(?P<name>\w+)')


def comment(indent, text, identify=False):
    lines = text.splitlines()
    if identify:
        lines += ["", f"@author {AUTHOR}", f"@since {VERSION}", f"@version {VERSION}",
                  f"@history {DATE} | {VERSION} | Establish structural documentation and component responsibilities."]
    return indent + "/**\n" + "".join(indent + " *" + (" " + line if line else "") + "\n" for line in lines) + indent + " */\n"


def declaration_start(source, offset):
    # Keep documentation before Lombok or override annotations.
    position = offset
    cursor = offset
    while cursor > 0:
        end = cursor - 1
        start = source.rfind("\n", 0, end) + 1
        previous = source[start:end].strip()
        if not previous:
            cursor = start
        elif previous.startswith("@"):
            position = start
            cursor = start
        else:
            break
    return position


sources = sorted((PROJECT / "src").rglob("*.java"))
sources += [PROJECT / "outputs/TASK-00.01.05/qa/tools/SourceGate.java"]
for path in sources:
    if path.name == "package-info.java":
        continue
    source = path.read_text(encoding="utf-8")
    source = TOKENS.sub(lambda match: "" if match.group().startswith("/**") else match.group(), source)
    source = re.sub(r"(?m)^ +$", "", source)
    source = re.sub(r"\n{3,}", "\n\n", source)
    insertions = []
    for match in TYPE.finditer(source):
        name = match.group("name")
        key = name if name == path.stem else f"{path.stem}.{name}"
        if key not in PURPOSES:
            raise ValueError(f"Missing reviewed purpose: {path}: {key}")
        insertions.append((declaration_start(source, match.start()), comment(match.group("indent"), PURPOSES[key], True)))
    for (owner, method), contract in CONTRACTS.items():
        if path.stem != owner:
            continue
        declaration = re.compile(r'(?m)^(?P<indent> *)(?:(?:public|private|protected|static|final|synchronized|default)\s+)*(?:[\w<>?,.\[\]]+\s+)?' + re.escape(method) + r'\s*\(')
        for match in declaration.finditer(source):
            insertions.append((declaration_start(source, match.start()), comment(match.group("indent"), contract)))
    for position, text in sorted(insertions, reverse=True):
        source = source[:position] + text + source[position:]
    path.write_text(source, encoding="utf-8", newline="\n")

for package, purpose in PACKAGES.items():
    path = PROJECT / "src/main/java" / Path(*package.split(".")) / "package-info.java"
    path.write_text(comment("", purpose) + f"package {package};\n", encoding="utf-8", newline="\n")

print(f"Updated {len(sources)} Java sources and {len(PACKAGES)} package descriptions")
