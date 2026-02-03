//
//  PuzzlePieceView.swift
//  PuzzleMaker
//
//  Created by santamaru on 2026/01/17.
//

import SwiftUI

struct PuzzlePieceView: View {
    let piece: PuzzlePiece
    let scale: CGFloat
    let isDragging: Bool
    
    var body: some View {
        Image(uiImage: piece.image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: piece.image.size.width * scale, height: piece.image.size.height * scale)
            .shadow(color: .black.opacity(isDragging ? 0.5 : 0.2), radius: isDragging ? 10 : 5)
            .scaleEffect(isDragging ? 1.1 : 1.0)
            .animation(.spring(response: 0.3), value: isDragging)
    }
}

