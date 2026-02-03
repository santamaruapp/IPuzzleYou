//
//  PuzzlePiece.swift
//  PuzzleMaker
//
//  Created by santamaru on 2026/01/17.
//

import SwiftUI

struct PuzzlePiece: Identifiable, Equatable {
    let id: UUID
    let row: Int
    let column: Int
    let image: UIImage
    var currentPosition: CGPoint
    var targetPosition: CGPoint
    var isPlaced: Bool {
        // 実際の位置が正しい位置に近いかどうかで判定
        let threshold: CGFloat = 5.0
        let distance = sqrt(
            pow(currentPosition.x - targetPosition.x, 2) +
            pow(currentPosition.y - targetPosition.y, 2)
        )
        return distance < threshold
    }
    
    init(id: UUID = UUID(), row: Int, column: Int, image: UIImage, currentPosition: CGPoint, targetPosition: CGPoint, isPlaced: Bool = false) {
        self.id = id
        self.row = row
        self.column = column
        self.image = image
        self.currentPosition = currentPosition
        self.targetPosition = targetPosition
        // isPlacedは計算プロパティなので、initでは設定しない
    }
}

