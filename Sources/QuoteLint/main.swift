import BiasCore
import Foundation

// quotelint — content tooling that runs without Xcode.
//
//   quotelint                          validate data/quotes.json (shipping rules)
//   quotelint build                    data/groups.csv + data/quotes.csv -> data/quotes.json
//   quotelint template                 write starter CSVs
//   quotelint self-check               run the core logic checks
//
// Exits 1 on any error, so CI fails on bad content.

// MARK: - Argument parsing

struct Options {
    var command = "validate"
    var positional: [String] = []
    var values: [String: String] = [:]
    var flags: Set<String> = []

    var mode: QuoteValidator.Mode {
        values["mode"] == "development" ? .development : .shipping
    }

    func value(_ key: String, default fallback: String) -> String {
        values[key] ?? fallback
    }
}

func parseOptions() -> Options {
    var options = Options()
    var args = Array(CommandLine.arguments.dropFirst())
    let commands: Set<String> = ["validate", "build", "template", "self-check"]

    if let first = args.first, commands.contains(first) {
        options.command = first
        args.removeFirst()
    } else if args.contains("--self-check") {
        options.command = "self-check"
    }

    let valueKeys: Set<String> = ["mode", "min", "groups", "quotes", "out", "version", "out-dir", "generated-at"]

    var index = 0
    while index < args.count {
        let arg = args[index]
        if arg.hasPrefix("--") {
            let key = String(arg.dropFirst(2))
            if valueKeys.contains(key), index + 1 < args.count {
                options.values[key] = args[index + 1]
                index += 2
                continue
            }
            options.flags.insert(key)
        } else if arg.hasPrefix("-"), arg.count > 1 {
            options.flags.insert(String(arg.dropFirst()))
        } else {
            options.positional.append(arg)
        }
        index += 1
    }
    return options
}

func printUsage() {
    print(
        """
        quotelint — content tooling for Project BIAS

        USAGE
          quotelint [command] [options]

        COMMANDS
          validate            Check quotes.json against the content rules (default)
          build               Build quotes.json from data/groups.csv + data/quotes.csv
          template            Write starter CSVs
          self-check          Run the core logic checks

        OPTIONS
          --mode shipping|development   Rule strictness (default: shipping)
          --groups PATH                 groups CSV (default: data/groups.csv)
          --quotes PATH                 quotes CSV (default: data/quotes.csv)
          --out PATH                    output JSON (default: data/quotes.json)
          --out-dir PATH                directory for `template` (default: data)
          --min N                       minimum quotes per group (default: 60)
          --version N                   database version written by `build` (default: 1)
          --generated-at YYYY-MM-DD     optional timestamp written by `build` (omitted by default)
          --stats                       print per-group counts
          --force                       write output even when there are errors; overwrite templates
          -h, --help                    show this message

        EXAMPLES
          quotelint --stats
          quotelint build --mode development
          quotelint build --groups my/groups.csv --quotes my/quotes.csv --out data/quotes.json
        """
    )
}

// MARK: - Shared helpers

let fileManager = FileManager.default

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(("error: " + message + "\n").data(using: .utf8) ?? Data())
    exit(1)
}

func readFile(_ path: String, label: String) -> String {
    guard fileManager.fileExists(atPath: path) else {
        fail("\(label) not found at \(path)")
    }
    do {
        return try String(contentsOfFile: path, encoding: .utf8)
    } catch {
        fail("could not read \(path): \(error.localizedDescription)")
    }
}

func printIssues(_ issues: [ValidationIssue]) {
    for issue in issues {
        print(issue.description)
    }
}

// MARK: - Commands

func runSelfCheck() -> Never {
    let results = SelfChecks.run()
    for result in results {
        let mark = result.passed ? "ok  " : "FAIL"
        var line = "\(mark)  \(result.name)"
        if let detail = result.detail, !detail.isEmpty { line += "  (\(detail))" }
        print(line)
    }
    let failures = results.filter { !$0.passed }
    print("")
    if failures.isEmpty {
        print("\(results.count) checks passed")
        exit(0)
    }
    print("\(failures.count) of \(results.count) checks FAILED")
    exit(1)
}

func runValidate(_ options: Options) -> Never {
    let path = options.positional.first ?? "data/quotes.json"
    let data: Data
    do {
        data = try Data(contentsOf: URL(fileURLWithPath: path))
    } catch {
        fail("no readable file at \(path)")
    }

    let database: QuoteDatabase
    do {
        database = try JSONDecoder().decode(QuoteDatabase.self, from: data)
    } catch {
        fail("\(path) is not valid quote JSON: \(error)")
    }

    var validatorOptions = options.mode == .shipping
        ? QuoteValidator.Options.shipping
        : QuoteValidator.Options.development
    if let raw = options.values["min"], let minimum = Int(raw) {
        validatorOptions.minimumQuotesPerGroup = minimum
    }

    let store = QuoteStore(database: database)
    print("quotelint — \(path) [\(options.mode.rawValue)]")
    print("")

    if options.flags.contains("stats") {
        printCounts(store: store, minimum: validatorOptions.minimumQuotesPerGroup)
    }

    let issues = QuoteValidator.validate(database, mode: options.mode, options: validatorOptions)
    printIssues(issues)
    if !issues.isEmpty { print("") }

    let errors = issues.filter { $0.severity == .error }
    let warnings = issues.filter { $0.severity == .warning }
    if errors.isEmpty {
        print("\(errors.count) errors, \(warnings.count) warnings — good to go")
        exit(0)
    }
    print("\(errors.count) errors, \(warnings.count) warnings — fix the errors above")
    exit(1)
}

func printCounts(store: QuoteStore, minimum: Int) {
    print("groups")
    for group in store.groups {
        let count = store.quoteCount(in: group.id)
        let gate = count >= minimum ? "ok" : "thin"
        print("  \(pad(group.id, 14))\(String(format: "%4d", count)) quotes   \(gate)")
    }
    let total = store.database.quotes.filter { !$0.retired }.count
    print("  \(pad("total", 14))\(String(format: "%4d", total)) quotes")
    print("")
}

func pad(_ value: String, _ width: Int) -> String {
    value.count >= width ? value + " " : value.padding(toLength: width, withPad: " ", startingAt: 0)
}

func runBuild(_ options: Options) -> Never {
    let groupsPath = options.value("groups", default: "data/groups.csv")
    let quotesPath = options.value("quotes", default: "data/quotes.csv")
    let outPath = options.value("out", default: "data/quotes.json")
    let version = Int(options.value("version", default: "1")) ?? 1
    // Deliberately not defaulted to "now": a build timestamp would rewrite the file on every run
    // and make the committed JSON churn for no reason.
    let generatedAt = options.values["generated-at"] ?? ""

    let groupsCSV = readFile(groupsPath, label: "groups CSV")
    let quotesCSV = readFile(quotesPath, label: "quotes CSV")

    let result = QuoteCSVImporter.build(
        groupsCSV: groupsCSV,
        quotesCSV: quotesCSV,
        version: version,
        generatedAt: generatedAt
    )

    print("import — \(groupsPath) + \(quotesPath)")
    for issue in result.issues {
        print(issue.description)
    }
    if !result.issues.isEmpty { print("") }

    // The importer builds the file; the validator decides whether it may be written.
    var validatorOptions = options.mode == .shipping
        ? QuoteValidator.Options.shipping
        : QuoteValidator.Options.development
    if let raw = options.values["min"], let minimum = Int(raw) {
        validatorOptions.minimumQuotesPerGroup = minimum
    }

    let issues = QuoteValidator.validate(result.database, mode: options.mode, options: validatorOptions)
    printIssues(issues)
    if !issues.isEmpty { print("") }

    let errors = issues.filter { $0.severity == .error }
    let warnings = issues.filter { $0.severity == .warning }
    let importErrors = result.issues.filter { $0.severity == .error }

    print(
        "\(errors.count) validation errors, \(warnings.count) warnings, "
            + "\(importErrors.count) import errors"
    )

    let blocking = !errors.isEmpty || !importErrors.isEmpty
    if blocking && !options.flags.contains("force") {
        print("not written. fix the errors, or pass --force to write anyway (development only).")
        exit(1)
    }

    do {
        let data = try result.database.encodedJSON()
        try data.write(to: URL(fileURLWithPath: outPath), options: .atomic)
    } catch {
        fail("could not write \(outPath): \(error.localizedDescription)")
    }

    let store = QuoteStore(database: result.database)
    print("")
    printCounts(store: store, minimum: validatorOptions.minimumQuotesPerGroup)
    print("wrote \(outPath) — \(result.database.quotes.count) quotes, \(result.database.groups.count) groups")
    if blocking {
        print("WARNING: written despite errors because --force was passed. Do not ship this file.")
    }
    exit(blocking ? 1 : 0)
}

func runTemplate(_ options: Options) -> Never {
    let directory = options.values["out-dir"] ?? "data"
    let force = options.flags.contains("force")
    try? fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)

    let files: [(String, String)] = [
        ("groups.csv", QuoteCSVImporter.templateGroupsCSV()),
        ("quotes.csv", QuoteCSVImporter.templateQuotesCSV())
    ]

    for (name, contents) in files {
        let path = "\(directory)/\(name)"
        if fileManager.fileExists(atPath: path) && !force {
            print("skipped \(path) — already exists (use --force to overwrite)")
            continue
        }
        do {
            try contents.write(toFile: path, atomically: true, encoding: .utf8)
            print("wrote \(path)")
        } catch {
            fail("could not write \(path): \(error.localizedDescription)")
        }
    }
    exit(0)
}

// MARK: - Entry point

let options = parseOptions()

if options.flags.contains("help") || options.flags.contains("h") {
    printUsage()
    exit(0)
}

switch options.command {
case "self-check":
    runSelfCheck()
case "build":
    runBuild(options)
case "template":
    runTemplate(options)
default:
    runValidate(options)
}
