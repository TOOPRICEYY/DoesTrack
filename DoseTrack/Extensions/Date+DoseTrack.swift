import Foundation

extension Calendar {
    static var doseTrackCalendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = Locale.current
        calendar.timeZone = TimeZone.current
        return calendar
    }

    func dateBySettingTime(hour: Int, minute: Int, on date: Date) -> Date? {
        self.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: date,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }
}

extension Date {
    static var doseTrackCalendar: Calendar { .doseTrackCalendar }

    var startOfDay: Date {
        Calendar.doseTrackCalendar.startOfDay(for: self)
    }

    func addingDays(_ days: Int) -> Date {
        Calendar.doseTrackCalendar.date(byAdding: .day, value: days, to: self) ?? self
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.doseTrackCalendar.isDate(self, inSameDayAs: other)
    }
}
