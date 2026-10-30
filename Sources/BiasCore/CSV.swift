import Foundation

/// A parsed CSV file.
public struct CSVTable: Sendable {
    /// Normalised header names: trimmed, lowercased, spaces and dashes to underscores.
    public let header: [String]
    public let rows: [[String]]
    /// 1-based line number in the original file, for error messages a human can act on.
    public let lineNumbers: [Int]

    public init(header: [String], rows: [[String]], lineNumbers: [Int]) {
        self.header = header
        self.rows = rows
        self.lineNumbers = lineNumbers
    }

    public func index(of column: String) -> Int? {
        header.firstIndex(of: Self.normalizeHeader(column))
    }

    public func has(_ column: String) -> Bool {
        index(of: column) != nil
    }

    /// Value at `column` for `row`, or `nil` when the column is absent or blank.
    public func value(_ column: String, in row: [String]) -> String? {
        guard let index = index(of: column), index < row.count else { return nil }
        let trimmed = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public static func normalizeHeader(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }
}

/// RFC 4180 CSV, written by hand because the standard library has none and the format is small.
///
/// Deliberately tolerant: curators export from Google Sheets, Numbers, and Excel, so the parser
/// accepts a UTF-8 BOM, CRLF line endings, quoted fields containing commas and newlines, and
/// doubled quotes as escapes.
public enum CSV {
    public static func parse(_ text: String) -> CSVTable {
        var chars = Array(text)
        if chars.first == "\u{FEFF}" { chars.removeFirst() }

        var records: [(fields: [String], line: Int)] = []
        var fields: [String] = []
        var field = ""
        var inQuotes = false
        var line = 1
        var recordLine = 1
        var recordStarted = false
        var index = 0

        while index < chars.count {
            let char = chars[index]

            if inQuotes {
                if char == "\"" {
                    if index + 1 < chars.count, chars[index + 1] == "\"" {
                        field.append("\"")
                        index += 2
                        continue
                    }
                    inQuotes = false
                    index += 1
                    continue
                }
                if char == "\n" || char == "\r\n" { line += 1 }
                field.append(char)
                index += 1
                continue
            }

            switch char {
            case "\"":
                inQuotes = true
                recordStarted = true
            case ",":
                fields.append(field)
                field = ""
                recordStarted = true
            case "\r\n", "\n":
                // Note: Swift treats CRLF as a single grapheme cluster, so "\r\n" has to be its
                // own case — matching on "\r" then "\n" would silently swallow both into a field.
                fields.append(field)
                field = ""
                records.append((fields, recordLine))
                fields = []
                recordStarted = false
                line += 1
                recordLine = line
            case "\r":
                break
            default:
                field.append(char)
                recordStarted = true
            }
            index += 1
        }

        if recordStarted || !field.isEmpty || !fields.isEmpty {
            fields.append(field)
            records.append((fields, recordLine))
        }

        // Drop blank lines, keep real ones.
        records = records.filter { record in
            !(record.fields.count == 1 && record.fields[0].trimmingCharacters(in: .whitespaces).isEmpty)
        }

        guard let first = records.first else {
            return CSVTable(header: [], rows: [], lineNumbers: [])
        }

        let header = first.fields.map { CSVTable.normalizeHeader($0) }
        var rows: [[String]] = []
        var lineNumbers: [Int] = []
        for record in records.dropFirst() {
            var padded = record.fields
            if padded.count < header.count {
                padded.append(contentsOf: Array(repeating: "", count: header.count - padded.count))
            }
            rows.append(padded)
            lineNumbers.append(record.line)
        }

        return CSVTable(header: header, rows: rows, lineNumbers: lineNumbers)
    }

    public static func encode(header: [String], rows: [[String]]) -> String {
        var out: [String] = []
        out.append(header.map(escape).joined(separator: ","))
        for row in rows {
            out.append(row.map(escape).joined(separator: ","))
        }
        return out.joined(separator: "\n") + "\n"
    }

    private static func escape(_ field: String) -> String {
        let needsQuoting = field.contains(",")
            || field.contains("\"")
            || field.contains("\n")
            || field.contains("\r")
            || field != field.trimmingCharacters(in: .whitespaces)
        guard needsQuoting else { return field }
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
