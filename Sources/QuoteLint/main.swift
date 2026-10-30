import BiasCore
import Foundation

// quotelint
//
// Validates data/quotes.json against the content rules, and optionally runs the core self-checks.
// Designed to run with Command Line Tools only, so content work never requires Xcode.
//
//   swift run quotelint                        # validate data/quotes.json in shipping mode
//   swift run quotelint --mode development     # relaxed rules while curating
//   swift run quotelint --self-check           # run the core logic checks
//   swift run quotelint --stats                # per-group content counts
//
// Exits 1 on any error, so CI fails on bad content.

struct Arguments {
    var path = "data/quotes.json"
    var mode: QuoteValidator.Mode = .shipping
    var runSelfChecks = false
    var showStats = false
    var minimumQuotes: Int?

    static func parse(_ raw: [String]) -> Arguments {
        var args = Arguments()
        var index = 0
        while index < raw.count {
            let value = raw[index]
            switch value {
            case "--self-check":
                args.runSelfChecks = true
            case "--stats":
                args.showStats = true
            case "--mode":
                if index + 1 < raw.count {
                    args.mode = raw[index + 1] == "development" ? .development : .shipping
                    index += 1
                }
            case "--min":
                if index + 1 < raw.count {
                    args.minimumQuotes = Int(raw[index + 1])
                    index += 1
                }
            case "--help", "-h":
                printUsage()
                exit(0)
            default:
                if !value.hasPrefix("-") { args.path = value }
            }
            index += 1
        }
        return args
    }
}

func printUsage() {
    print(
        """
        quotelint — validate the quote database

        USAGE
          swift run quotelint [path] [options]

        OPTIONS
          --mode shipping|development   Rule strictness (default: shipping)
          --min N                       Override the minimum quotes per group (default: 60)
          --stats                       Print per-group content counts
          --self-check                  Run the core logic self-checks
          -h, --help                    Show this message

        DEFAULT PATH
          data/quotes.json
        """
    )
}

// MARK: - Self checks

if Arguments.parse(Array(CommandLine.arguments.dropFirst())).runSelfChecks {
    let results = SelfChecks.run()
    let failures = results.filter { !$0.passed }
    for result in results {
        let mark = result.passed ? "ok  " : "FAIL"
        var line = "\(mark)  \(result.name)"
        if let detail = result.detail, !detail.isEmpty {
            line += "  (\(detail))"
        }
        print(line)
    }
    print("")
    if failures.isEmpty {
        print("\(results.count) checks passed")
        exit(0)
    } else {
        print("\(failures.count) of \(results.count) checks FAILED")
        exit(1)
    }
}

// MARK: - Validation

let args = Arguments.parse(Array(CommandLine.arguments.dropFirst()))

guard FileManager.default.fileExists(atPath: args.path) else {
    print("error: no file at \(args.path)")
    print("hint: copy data/quotes.template.json to data/quotes.json and start curating")
    exit(1)
}

let data: Data
do {
    data = try Data(contentsOf: URL(fileURLWithPath: args.path))
} catch {
    print("error: could not read \(args.path): \(error.localizedDescription)")
    exit(1)
}

let database: QuoteDatabase
do {
    database = try JSONDecoder().decode(QuoteDatabase.self, from: data)
} catch {
    print("error: \(args.path) is not valid quote JSON")
    print("\(error)")
    exit(1)
}

let store = QuoteStore(database: database)
var options = args.mode == .shipping ? QuoteValidator.Options.shipping : QuoteValidator.Options.development
if let minimum = args.minimumQuotes {
    options.minimumQuotesPerGroup = minimum
}

print("quotelint — \(args.path) [\(args.mode.rawValue)]")
print("")

if args.showStats {
    print("groups")
    for group in database.groups {
        let count = store.quoteCount(in: group.id)
        let gate = count >= options.minimumQuotesPerGroup ? "ok" : "thin"
        print("  \(group.id.padding(toLength: 14, withPad: " ", startingAt: 0)) \(String(format: "%4d", count)) quotes   \(gate)")
    }
    let total = database.quotes.filter { !$0.retired }.count
    print("  \("total".padding(toLength: 14, withPad: " ", startingAt: 0)) \(String(format: "%4d", total)) quotes")
    print("")
}

let issues = QuoteValidator.validate(database, mode: args.mode, options: options)
let errors = issues.filter { $0.severity == .error }
let warnings = issues.filter { $0.severity == .warning }

for issue in issues {
    print(issue.description)
}

if !issues.isEmpty { print("") }

if errors.isEmpty {
    print("\(errors.count) errors, \(warnings.count) warnings — good to go")
    exit(0)
} else {
    print("\(errors.count) errors, \(warnings.count) warnings — fix the errors above")
    exit(1)
}
