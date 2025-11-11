//
//  DateFormatter+Extensions.swift
//  ImageToCalendar
//
//  Date formatting utilities
//

import Foundation

extension DateFormatter {
    static let displayDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let displayDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let displayTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

extension Date {
    func displayString(includeTime: Bool = true) -> String {
        if includeTime {
            return DateFormatter.displayDateTime.string(from: self)
        } else {
            return DateFormatter.displayDate.string(from: self)
        }
    }
}
