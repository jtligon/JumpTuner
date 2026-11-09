// AICharacterParams.swift
// Visual parameters returned by Claude for a described character.

import UIKit

struct AICharacterParams: Codable {

    enum HeadShape: String, Codable { case round, square, diamond }
    enum LimbStyle: String, Codable { case normal, stubby }

    var name: String
    var bodyHex: String
    var accentHex: String
    var headShape: HeadShape
    var hasAntenna: Bool
    var hasEars: Bool
    var eyeCount: Int
    var limbStyle: LimbStyle

    var bodyColor: UIColor { UIColor(hex: bodyHex) ?? UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1) }
    var accentColor: UIColor { UIColor(hex: accentHex) ?? UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1) }
}

private extension UIColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        self.init(
            red:   CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >>  8) & 0xFF) / 255,
            blue:  CGFloat( value        & 0xFF) / 255,
            alpha: 1
        )
    }
}
