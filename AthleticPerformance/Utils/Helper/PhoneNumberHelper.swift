//
//  PhoneNumberHelper.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 07.04.25.
//

import Foundation
import libPhoneNumber

struct PhoneNumberHelper {
    static let shared = PhoneNumberHelper()

    private var util: NBPhoneNumberUtil {
        NBPhoneNumberUtil.sharedInstance()!
    }

    /// Gibt die formatierte Nummer zurück, z. B. „+49 176 1234567“
    func format(_ rawNumber: String, region: String = "DE") -> String {
        do {
            let number = try util.parse(rawNumber, defaultRegion: region)
            return try util.format(number, numberFormat: .INTERNATIONAL)
        } catch {
            return rawNumber
        }
    }

    /// Prüft, ob eine Nummer gültig ist
    func isValid(_ rawNumber: String, region: String = "DE") -> Bool {
        do {
            let number = try util.parse(rawNumber, defaultRegion: region)
            return util.isValidNumber(forRegion: number, regionCode: region)
        } catch {
            return false
        }
    }

    /// Gibt die nationale Formatierung zurück, z. B. „0176 1234567“
    func formatNational(_ rawNumber: String, region: String = "DE") -> String {
        do {
            let number = try util.parse(rawNumber, defaultRegion: region)
            return try util.format(number, numberFormat: .NATIONAL)
        } catch {
            return rawNumber
        }
    }
}
