//
//  String.swift
//  AthleticsPerformance
//
//  Created by Frank Ufer on 02.04.25.
//

import Foundation
import UIKit

extension String {
    var isValidName: Bool {
        let words = self.split(separator: " ")
        return words.count >= 2 &&
               self.range(of: #"^[A-Za-zÄÖÜäöüß\s\-]+$"#, options: .regularExpression) != nil
    }

    var isValidBirthdate: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.date(from: self) != nil
    }

    var isValidInsuranceNumber: Bool {
        let cleaned = self.replacingOccurrences(of: " ", with: "")
        return cleaned.range(of: #"^[A-Z0-9]{10}$"#, options: .regularExpression) != nil
    }
}

extension String {
    func width(usingFont font: UIFont) -> CGFloat {
        let attributes = [NSAttributedString.Key.font: font]
        let size = (self as NSString).size(withAttributes: attributes)
        return size.width
    }

    func height(usingFont font: UIFont, constrainedToWidth width: CGFloat) -> CGFloat {
        let attributes = [NSAttributedString.Key.font: font]
        let rect = NSString(string: self).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return ceil(rect.height) + 8
    }
}
