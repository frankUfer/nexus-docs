//
//  CollectBillingData.swift
//  AthleticPerformance
//
//  Created by Frank Ufer on 20.06.25.
//

import Foundation

func collectBillingData(patients: [Patient], billingDate: Date) -> [BillingEntry] {
    var result: [BillingEntry] = []

    for patient in patients {
        for therapy in patient.therapies.compactMap({ $0 }) {
            for plan in therapy.therapyPlans {
                let eligibleSessions = plan.treatmentSessions.filter { session in
                    session.isDone &&
                    !session.isInvoiced &&
                    session.date <= billingDate
                }

                let billingAllowed = checkBillingPeriodSatisfied(for: plan, billingPeriod: therapy.billingPeriod, upTo: billingDate)
                
                // Nur wenn Billing erlaubt
                if billingAllowed {
                    for session in eligibleSessions {
                        for serviceId in session.treatmentServiceIds {
                            if let service = AppGlobals.shared.treatmentServices.first(where: { $0.internalId == serviceId }) {
                                let quantity = 1
                                let price = service.price ?? 0.0
                                let volume = Double(quantity) * price

                                let entry = BillingEntry(
                                    patient: patient,
                                    therapy: therapy,
                                    plan: plan,
                                    service: service,
                                    serviceDate: session.date,
                                    sessionId: session.id,
                                    quantity: quantity,
                                    volume: volume,
                                    isBillable: service.isBillable
                                )

                                result.append(entry)

                            }
                        }
                    }
                }
            }
        }
    }
    
    result.sort { $0.serviceDate < $1.serviceDate }
    return result
}
