//
//  StringDrawing.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-05-13.
//  Co-author: Claude Code
//

import Cocoa

extension NSString {
    func drawVerticallyCentered(in rect: CGRect, withAttributes attributes: [NSAttributedString.Key: Any]? = nil) {
        let size = self.size(withAttributes: attributes)
        let centeredRect = CGRect(
            x: rect.origin.x,
            y: rect.origin.y + (rect.size.height - size.height) / 2.0,
            width: rect.size.width,
            height: size.height)
        self.draw(in: centeredRect, withAttributes: attributes)
    }
}
