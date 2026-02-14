//
//  BillingPeriods.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 23.04.25.
//

import Foundation

enum BillingPeriod: Codable, Hashable, CaseIterable, Identifiable {
    case session
    case monthly
    case quarterly
    case end
    case custom

    var id: String {
        switch self {
        case .session: return "session"
        case .monthly: return "monthly"
        case .quarterly: return "quarterly"
        case .end: return "end"
        case .custom: return "custom"
        }
    }

    var localizedLabel: String {
        switch self {
        case .session: return NSLocalizedString("afterSession", comment: "after session")
        case .monthly: return NSLocalizedString("monthly", comment: "monthly")
        case .quarterly: return NSLocalizedString("quarterly", comment: "quarterly")
        case .end: return NSLocalizedString("end", comment: "at the end")
        case .custom: return NSLocalizedString("custom", comment: "custom")
        }
    }
    
    var localizedDescription: String {
        switch self {
        case .session: return NSLocalizedString("afterSessionDescription", comment: "after session")
        case .monthly: return NSLocalizedString("monthlyDescription", comment: "monthly")
        case .quarterly: return NSLocalizedString("quarterlyDescription", comment: "quarterly")
        case .end: return NSLocalizedString("endDescription", comment: "at the end")
        case .custom: return NSLocalizedString("customDescription", comment: "custom")
        }
    }
}

