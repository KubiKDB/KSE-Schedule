import SwiftUI

class ScheduleViewModel: ObservableObject {
    @Published var scheduleEntries: [(String,[Event])] = []
    @Published var isLoading: Bool = false
    @AppStorage("UserGroups") private var groupIDsString: String = ""

    public var groupIDs: [Int] {
        get {
            groupIDsString.split(separator: ",").compactMap { Int($0) }
        }
        set {
            groupIDsString = newValue.map { String($0) }.joined(separator: ",")
        }
    }
    
    func parseGroups(from filePath: String) -> [(Int, String)]? {
        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            let lines = content.components(separatedBy: .newlines)
            
            let tuples: [(Int, String)] = lines.compactMap { line in
                let parts = line.components(separatedBy: " : ")
                guard parts.count == 2, let number = Int(parts[0].trimmingCharacters(in: .whitespaces)) else {
                    return nil
                }
                let subject = parts[1].trimmingCharacters(in: .whitespaces)
                return (number, subject)
            }
            
            return tuples
        } catch {
            print("Error reading file: \(error)")
            return nil
        }
    }
    
    
    func fetchSchedule() {
        isLoading = true
        downloadICS(for: groupIDs) { localURL in
            DispatchQueue.main.async {
                self.isLoading = false
                if let localURL = localURL {
                    self.scheduleEntries = self.parseICS(from: localURL)
                } else {
                    print("Failed to download the schedule.")
                }
            }
        }
    }
    
    private func downloadICS(for groupIDs: [Int], completion: @escaping (URL?) -> Void) {
        print(groupIDsString)
        let baseURL = "https://schedule.kse.ua/uk/index/ical"
        let idString = groupIDs.map { "\($0)" }.joined(separator: ",")
        let endDate = calculateEndDate()
        let urlString = "\(baseURL)?id_grp=\(idString)&date_end=\(endDate)"
        print(urlString)
        
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            completion(nil)
            return
        }
        
        let task = URLSession.shared.downloadTask(with: url) { localURL, _, error in
            if let localURL = localURL {
                completion(localURL)
            } else {
                print("Download error: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
            }
        }
        task.resume()
    }
    
    private func calculateEndDate() -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy"
            let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
            return formatter.string(from: futureDate)
        }
    
    private func parseICS(from fileURL: URL) -> [(String,[Event])] {
        guard let icsString = try? String(contentsOf: fileURL, encoding: .utf8) else {
            print("Failed to read ICS file")
            return []
        }
        var currentEvent: Event?
        var events: [String: [Event]] = [:]
        
        var isLoadingDesc = true
        
        for line in icsString.components(separatedBy: "\n") {
            if line.hasPrefix("BEGIN:VEVENT") {
                currentEvent = Event()
            } else if line.hasPrefix("END:VEVENT") {
                events[formatDate(currentEvent!.startDate), default: []].append(currentEvent!)
                currentEvent = nil
            } 
            if line.hasPrefix("SUMMARY:") {
                currentEvent?.title = String(line.dropFirst(8))
            } else if line.hasPrefix("DTSTART;") {
                currentEvent?.startDate = parseDate(from: String(line.dropFirst(8)))
            } else if line.hasPrefix("DTEND;") {
                currentEvent?.endDate = parseDate(from: String(line.dropFirst(6)))
            } else if line.hasPrefix("LOCATION:") {
                currentEvent?.location = String(line.dropFirst(9))
            } else if line.hasPrefix("DESCRIPTION:") && isLoadingDesc {
                currentEvent?.desc = String(line.dropFirst(12)).split(separator: "\\n\\n")[0].replacingOccurrences(of: "\\n", with: " ")
            } else if line.hasPrefix("BEGIN:VALARM") {
                isLoadingDesc = false
            } else if line.hasPrefix("END:VALARM") {
                isLoadingDesc = true
            }
        }
        return sortedEvents(by: events)
    }
    
    func sortedEvents(by events: [String: [Event]]) -> [(String, [Event])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        formatter.locale = Locale(identifier: "Europe/Kiev")

        return events.sorted { (first, second) -> Bool in
            guard let date1 = formatter.date(from: first.key),
                  let date2 = formatter.date(from: second.key) else {
                return false
            }
            return date1 < date2
        }
    }

    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
    
    private func parseDate(from string: String) -> Date {
        var cleanedString = string
        var timeZone = TimeZone(identifier: "Europe/Kiev")

        if let tzidRange = string.range(of: "TZID=") {
            let tzidStart = string.index(tzidRange.upperBound, offsetBy: 0)
                if let colonIndex = string.range(of: ":", range: tzidRange.upperBound..<string.endIndex) {
                let tzidEnd = colonIndex.lowerBound
                let tzid = String(string[tzidStart..<tzidEnd])
                
                if let parsedTimeZone = TimeZone(identifier: tzid) {
                    timeZone = parsedTimeZone
                }
                
                cleanedString = String(string[colonIndex.upperBound...])
            }
        }
        cleanedString = cleanedString.replacingOccurrences(of: "\r", with: "")
        
        let dateFormat = "yyyyMMdd'T'HHmmss"
        

        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = dateFormat
        return formatter.date(from: cleanedString)!
    }



}

struct Event: Identifiable {
    let id = UUID()
    var title: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var location: String = ""
    var desc: String = ""
}
