//
//  PuzzleGame.swift
//  PuzzleMaker
//
//  Created by santamaru on 2026/01/17.
//

import SwiftUI
import UIKit

class PuzzleGame: ObservableObject {
    @Published var pieces: [PuzzlePiece] = []
    @Published var isGameStarted = false
    @Published var isCompleted = false
    @Published var selectedImage: UIImage?
    @Published var puzzleSize: Int = 3 // 3x3 = 9ピース
    @Published var selectedPuzzleSize: Int? // 選択されたパズルサイズ（まだ開始していない）
    @Published var elapsedTime: TimeInterval = 0
    @Published var isTimerRunning = false
    @Published var screenSize: CGSize = UIScreen.main.bounds.size
    
    private var timer: Timer?
    private let snapThreshold: CGFloat = 80 // スナップの閾値（大きくしてより積極的にスナップ）
    
    init() {
        startTimer()
    }
    
    func startTimer() {
        timer?.invalidate()
        elapsedTime = 0
        isTimerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isTimerRunning else { return }
            self.elapsedTime += 0.1
        }
    }
    
    func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
    }
    
    func createPuzzle(from image: UIImage, size: Int) {
        selectedImage = image
        puzzleSize = size
        pieces = []
        isCompleted = false
        isGameStarted = true
        elapsedTime = 0
        startTimer()
        
        let imageSize = image.size
        let pieceWidth = imageSize.width / CGFloat(size)
        let pieceHeight = imageSize.height / CGFloat(size)
        
        var newPieces: [PuzzlePiece] = []
        
        // パズルピースを作成
        for row in 0..<size {
            for col in 0..<size {
                let rect = CGRect(
                    x: CGFloat(col) * pieceWidth,
                    y: CGFloat(row) * pieceHeight,
                    width: pieceWidth,
                    height: pieceHeight
                )
                
                // 画像の範囲をチェック
                guard rect.maxX <= imageSize.width && rect.maxY <= imageSize.height else {
                    continue
                }
                
                // 画像の一部を切り出し（そのまま四角形）
                guard let cgImage = image.cgImage,
                      let croppedCGImage = cgImage.cropping(to: rect) else {
                    continue
                }
                
                let pieceImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
                
                // 正しい位置（完成時の位置）- 画像座標系
                // ピースの中心位置を計算（positionは中心を指定するため）
                let targetX = CGFloat(col) * pieceWidth + pieceWidth / 2
                let targetY = CGFloat(row) * pieceHeight + pieceHeight / 2
                
                // ランダムな初期位置を画像座標系で生成
                // 画面下部エリアに配置するため、画像の範囲外のY座標を使用
                let screenWidth = UIScreen.main.bounds.width
                let screenHeight = UIScreen.main.bounds.height
                
                // 画像を画面に収まるようにスケール計算（ContentViewと同じロジック）
                let maxWidth = screenWidth * 0.9
                let maxHeight = screenHeight * 0.4
                let imageAspect = imageSize.width / imageSize.height
                let maxAspect = maxWidth / maxHeight
                
                let scale: CGFloat
                if imageAspect > maxAspect {
                    scale = maxWidth / imageSize.width
                } else {
                    scale = maxHeight / imageSize.height
                }
                let finalScale = min(scale, 0.6)
                
                // スケールされたピースサイズ
                let scaledPieceWidth = pieceWidth * finalScale
                let scaledPieceHeight = pieceHeight * finalScale
                
                // 画面座標での配置エリア（画面下部、確実に画面内に収まる範囲）
                let headerHeight: CGFloat = 80
                let puzzleAreaHeight = screenHeight * 0.4 // 画面の上半分にパズル完成エリア
                let randomAreaTop = headerHeight + puzzleAreaHeight + 20
                let randomAreaBottom = screenHeight - 50
                
                // 画面座標でのランダム位置範囲（確実に画面内に収まるように）
                // マージンを大きくして、確実に画面内に収まるようにする
                let margin: CGFloat = max(40, scaledPieceWidth)
                let screenMinX = margin
                let screenMaxX = screenWidth - margin
                let screenMinY = randomAreaTop
                let screenMaxY = randomAreaBottom
                
                // 範囲が有効かチェック（より厳密に）
                guard screenMaxX > screenMinX + scaledPieceWidth && 
                      screenMaxY > screenMinY + scaledPieceHeight else {
                    // フォールバック: 画面中央下部に配置
                    let fallbackScreenX = screenWidth / 2
                    let fallbackScreenY = (randomAreaTop + randomAreaBottom) / 2
                    let offsetY: CGFloat = 100
                    let offsetX = screenWidth / 2 - imageSize.width * finalScale / 2
                    let fallbackImageX = (fallbackScreenX - offsetX) / finalScale
                    let fallbackImageY = (fallbackScreenY - offsetY) / finalScale
                    
                    let piece = PuzzlePiece(
                        row: row,
                        column: col,
                        image: pieceImage,
                        currentPosition: CGPoint(x: fallbackImageX, y: fallbackImageY),
                        targetPosition: CGPoint(x: targetX, y: targetY)
                    )
                    newPieces.append(piece)
                    continue
                }
                
                // 画像座標系に変換
                // ContentViewでのoffsetY = 100を考慮
                let offsetY: CGFloat = 100
                let offsetX = screenWidth / 2 - imageSize.width * finalScale / 2
                
                // 画面座標から画像座標への変換
                // positionX = piece.currentPosition.x * scale + offsetX
                // positionY = piece.currentPosition.y * scale + offsetY
                // より逆算: currentPosition = (screenPosition - offset) / scale
                // ピースの中心が範囲内に収まるように調整
                let imageMinX = (screenMinX + scaledPieceWidth / 2 - offsetX) / finalScale
                let imageMaxX = (screenMaxX - scaledPieceWidth / 2 - offsetX) / finalScale
                let imageMinY = (screenMinY + scaledPieceHeight / 2 - offsetY) / finalScale
                let imageMaxY = (screenMaxY - scaledPieceHeight / 2 - offsetY) / finalScale
                
                // 範囲が有効な場合のみランダム位置を生成
                let randomX: CGFloat
                let randomY: CGFloat
                
                if imageMaxX > imageMinX {
                    randomX = CGFloat.random(in: imageMinX...imageMaxX)
                } else {
                    // フォールバック: 画像の右側に配置
                    randomX = imageSize.width + 50
                }
                
                if imageMaxY > imageMinY {
                    randomY = CGFloat.random(in: imageMinY...imageMaxY)
                } else {
                    // フォールバック: 画像の下側に配置
                    randomY = imageSize.height + 100
                }
                
                let piece = PuzzlePiece(
                    row: row,
                    column: col,
                    image: pieceImage,
                    currentPosition: CGPoint(x: randomX, y: randomY),
                    targetPosition: CGPoint(x: targetX, y: targetY)
                )
                
                newPieces.append(piece)
            }
        }
        
        // ピースをシャッフル
        pieces = newPieces.shuffled()
    }
    
    func updatePiecePosition(_ pieceId: UUID, to position: CGPoint, scale: CGFloat = 1.0, isDragging: Bool = false) {
        guard let index = pieces.firstIndex(where: { $0.id == pieceId }) else { return }
        
        var piece = pieces[index]
        
        // ドラッグ中は位置を更新するだけ（完成判定はしない）
        if isDragging {
            piece.currentPosition = position
            pieces[index] = piece
        } else {
            // ドラッグ終了時は位置を更新するだけ（スナップはsnapPieceToGridで行う）
            piece.currentPosition = position
            pieces[index] = piece
        }
    }
    
    // ドラッグ終了時に最寄りのマスにスナップ
    func snapPieceToGrid(_ pieceId: UUID, scale: CGFloat) {
        guard let index = pieces.firstIndex(where: { $0.id == pieceId }) else { return }
        
        var piece = pieces[index]
        let scaledThreshold = snapThreshold / scale
        
        // 最寄りのグリッド位置を探す（正しい位置でなくても良い）
        if let nearestPosition = findNearestGridPosition(to: piece.currentPosition, for: piece, scale: scale) {
            let distance = sqrt(
                pow(piece.currentPosition.x - nearestPosition.x, 2) +
                pow(piece.currentPosition.y - nearestPosition.y, 2)
            )
            
            // 最寄りのマスが近い場合、そこにスナップ
            if distance < scaledThreshold * 2.0 {
                // 既にその位置に他のピースがあるかチェック（より厳密に）
                guard let image = selectedImage else { return }
                let pieceWidth = image.size.width / CGFloat(puzzleSize)
                let pieceHeight = image.size.height / CGFloat(puzzleSize)
                let conflictThreshold = max(pieceWidth, pieceHeight) * 0.5 // 同じ位置とみなす距離（ピースサイズの半分）
                
                let hasConflict = pieces.enumerated().contains { otherIndex, otherPiece in
                    if otherIndex == index { return false } // 自分自身は除外
                    let otherDistance = sqrt(
                        pow(otherPiece.currentPosition.x - nearestPosition.x, 2) +
                        pow(otherPiece.currentPosition.y - nearestPosition.y, 2)
                    )
                    return otherDistance < conflictThreshold
                }
                
                // 衝突がない場合のみスナップ
                if !hasConflict {
                    piece.currentPosition = nearestPosition
                    pieces[index] = piece
                }
            }
        }
        
        // ドロップ後に完成判定をチェック
        checkCompletion(scale: scale)
    }
    
    // ピースがどのグリッド位置に配置されているかを返す（配置されていない場合はnil）
    private func getGridPositionForPiece(_ piece: PuzzlePiece, imageSize: CGSize) -> (row: Int, col: Int)? {
        let pieceWidth = imageSize.width / CGFloat(puzzleSize)
        let pieceHeight = imageSize.height / CGFloat(puzzleSize)
        // より厳密な閾値：ピースサイズの20%（より正確に枠に収まっている必要がある）
        let threshold = max(pieceWidth, pieceHeight) * 0.2
        
        // すべてのグリッド位置をチェック
        for row in 0..<puzzleSize {
            for col in 0..<puzzleSize {
                // グリッドの中心座標（画像座標系）
                let gridX = CGFloat(col) * pieceWidth + pieceWidth / 2
                let gridY = CGFloat(row) * pieceHeight + pieceHeight / 2
                
                let distance = sqrt(
                    pow(piece.currentPosition.x - gridX, 2) +
                    pow(piece.currentPosition.y - gridY, 2)
                )
                
                if distance < threshold {
                    // このグリッド位置に他のピースが既にいるかチェック
                    let conflictThreshold = max(pieceWidth, pieceHeight) * 0.2
                    let hasConflict = pieces.contains { otherPiece in
                        if otherPiece.id == piece.id { return false } // 自分自身は除外
                        let otherDistance = sqrt(
                            pow(otherPiece.currentPosition.x - gridX, 2) +
                            pow(otherPiece.currentPosition.y - gridY, 2)
                        )
                        return otherDistance < conflictThreshold
                    }
                    
                    // 衝突がなければ、このピースはこのグリッド位置に配置されている
                    if !hasConflict {
                        return (row: row, col: col)
                    }
                }
            }
        }
        
        return nil
    }
    
    // ピースがグリッド位置に近いかどうかを判定（位置を返すのではなく、近いかどうかのみ判定）
    private func isPieceNearGrid(_ piece: PuzzlePiece, imageSize: CGSize, excludingPieceId: UUID? = nil) -> Bool {
        return getGridPositionForPiece(piece, imageSize: imageSize) != nil
    }
    
    // デバイス回転時に配置されていないピースの位置を再計算
    func repositionUnplacedPieces(screenWidth: CGFloat, screenHeight: CGFloat, imageSize: CGSize, scale: CGFloat) {
        guard selectedImage != nil else { return }
        
        let isLandscape = screenWidth > screenHeight
        let pieceWidth = imageSize.width / CGFloat(puzzleSize)
        let pieceHeight = imageSize.height / CGFloat(puzzleSize)
        let scaledPieceWidth = pieceWidth * scale
        let scaledPieceHeight = pieceHeight * scale
        
        // ヘッダーと完成メッセージのスペースを考慮
        let headerHeight: CGFloat = 80
        // 横向き時は完成前はメッセージのスペースを確保しない（完成後はcachedScaleで維持）
        // 縦向き時は元の値を使用
        let completionMessageHeight: CGFloat = isLandscape ? 0 : (UIDevice.current.userInterfaceIdiom == .pad ? 100 : 60)
        // 横向き時は完成前はメッセージのスペースを確保しない、縦向き時は確保する
        let availableHeight = screenHeight - headerHeight - completionMessageHeight
        
        // パズル完成エリアの計算
        let puzzleAreaHeight = isLandscape ? availableHeight * 0.98 : availableHeight * 0.4
        let offsetY: CGFloat = isLandscape ? headerHeight / 2 + 5 : 100
        let offsetX = screenWidth / 2 - imageSize.width * scale / 2
        
        // 配置エリアの計算
        let (screenMinX, screenMaxX, screenMinY, screenMaxY, leftMinX, leftMaxX, rightMinX, rightMaxX): (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
        
        if isLandscape {
            // 横向き時：左右のスペースに配置
            let puzzleAreaWidth = imageSize.width * scale
            let leftAreaWidth = (screenWidth - puzzleAreaWidth) / 2 - 20
            let rightAreaWidth = (screenWidth - puzzleAreaWidth) / 2 - 20
            
            let leftMin = 20.0
            let leftMax = leftAreaWidth
            let rightMin = screenWidth - rightAreaWidth
            let rightMax = screenWidth - 20.0
            
            let areaTop = headerHeight + 10
            // 横向き時は完成前はメッセージのスペースを確保しない（完成後はcachedScaleで維持）
            let actualMessageHeight: CGFloat = isLandscape ? (UIDevice.current.userInterfaceIdiom == .pad ? 60 : 50) : completionMessageHeight
            let areaBottom = screenHeight - (isCompleted ? actualMessageHeight + 10 : 20)
            
            (screenMinX, screenMaxX, screenMinY, screenMaxY, leftMinX, leftMaxX, rightMinX, rightMaxX) = 
                (leftMin, leftMax, areaTop, areaBottom, leftMin, leftMax, rightMin, rightMax)
        } else {
            // 縦向き時：下のスペースに配置
            let areaTop = headerHeight + puzzleAreaHeight + 20
            // 縦向き時は常に完成メッセージのスペースを確保
            let areaBottom = screenHeight - (isCompleted ? completionMessageHeight + 20 : 50)
            
            (screenMinX, screenMaxX, screenMinY, screenMaxY, leftMinX, leftMaxX, rightMinX, rightMaxX) = 
                (20, screenWidth - 20, areaTop, areaBottom, 0, 0, 0, 0)
        }
        
        // 配置されていないピースの位置を再計算
        // まず、すべてのグリッド位置にどのピースが配置されているかを記録
        var gridOccupancy: [Int: UUID] = [:] // gridIndex -> pieceId
        
        for index in pieces.indices {
            let piece = pieces[index]
            if let gridPos = getGridPositionForPiece(piece, imageSize: imageSize) {
                let gridIndex = gridPos.row * puzzleSize + gridPos.col
                // 既に他のピースが配置されている場合はスキップ（最初に見つかったピースを優先）
                if gridOccupancy[gridIndex] == nil {
                    gridOccupancy[gridIndex] = piece.id
                }
            }
        }
        
        for index in pieces.indices {
            var piece = pieces[index]
            
            // グリッド位置に配置されているピースは、そのグリッド位置を維持する
            if let gridPos = getGridPositionForPiece(piece, imageSize: imageSize) {
                let gridIndex = gridPos.row * puzzleSize + gridPos.col
                // このグリッド位置にこのピースが配置されていることを確認
                if gridOccupancy[gridIndex] == piece.id {
                    // グリッド位置を維持（画像座標系で正確な位置に設定）
                    let gridX = CGFloat(gridPos.col) * pieceWidth + pieceWidth / 2
                    let gridY = CGFloat(gridPos.row) * pieceHeight + pieceHeight / 2
                    piece.currentPosition = CGPoint(x: gridX, y: gridY)
                    pieces[index] = piece
                    continue
                }
            }
            
            // 既に正しい位置にあるピースもスキップ（念のため）
            let distanceToTarget = sqrt(
                pow(piece.currentPosition.x - piece.targetPosition.x, 2) +
                pow(piece.currentPosition.y - piece.targetPosition.y, 2)
            )
            let threshold = max(pieceWidth, pieceHeight) * 0.6
            if distanceToTarget < threshold {
                continue // 既に正しい位置にある
            }
            
            // 画面座標でのランダム位置を生成
            let randomScreenX: CGFloat
            let randomScreenY: CGFloat
            
            if isLandscape {
                // 横向き時：左右どちらかにランダムに配置
                let useLeft = Bool.random()
                let leftMin = leftMinX + scaledPieceWidth / 2
                let leftMax = max(leftMin, leftMaxX - scaledPieceWidth / 2)
                let rightMin = rightMinX + scaledPieceWidth / 2
                let rightMax = max(rightMin, rightMaxX - scaledPieceWidth / 2)
                
                if useLeft && leftMax > leftMin {
                    randomScreenX = CGFloat.random(in: leftMin...leftMax)
                } else if rightMax > rightMin {
                    randomScreenX = CGFloat.random(in: rightMin...rightMax)
                } else if leftMax > leftMin {
                    randomScreenX = CGFloat.random(in: leftMin...leftMax)
                } else {
                    randomScreenX = screenWidth / 2
                }
                
                let yMin = screenMinY + scaledPieceHeight / 2
                let yMax = max(yMin, screenMaxY - scaledPieceHeight / 2)
                randomScreenY = CGFloat.random(in: yMin...yMax)
            } else {
                // 縦向き時：下のスペースに配置
                let xMin = screenMinX + scaledPieceWidth / 2
                let xMax = max(xMin, screenMaxX - scaledPieceWidth / 2)
                let yMin = screenMinY + scaledPieceHeight / 2
                let yMax = max(yMin, screenMaxY - scaledPieceHeight / 2)
                
                randomScreenX = CGFloat.random(in: xMin...xMax)
                randomScreenY = CGFloat.random(in: yMin...yMax)
            }
            
            // 画像座標系に変換
            let imageX = (randomScreenX - offsetX) / scale
            let imageY = (randomScreenY - offsetY) / scale
            
            piece.currentPosition = CGPoint(x: imageX, y: imageY)
            pieces[index] = piece
        }
    }
    
    // 画面外に出ているピースを画面内に戻す（横向きの時は枠の外に配置）
    func ensurePiecesInBounds(screenWidth: CGFloat, screenHeight: CGFloat, imageSize: CGSize, scale: CGFloat) {
        let isLandscape = screenWidth > screenHeight
        let headerHeight: CGFloat = 80
        let offsetY: CGFloat = isLandscape ? headerHeight / 2 + 5 : 100
        let offsetX = screenWidth / 2 - imageSize.width * scale / 2
        
        let pieceWidth = imageSize.width / CGFloat(puzzleSize)
        let pieceHeight = imageSize.height / CGFloat(puzzleSize)
        let scaledPieceWidth = pieceWidth * scale
        let scaledPieceHeight = pieceHeight * scale
        
        // パズル完成エリア（グリッド）の範囲を計算
        let puzzleAreaWidth = imageSize.width * scale
        let puzzleAreaHeight = imageSize.height * scale
        let puzzleAreaLeft = offsetX
        let puzzleAreaRight = offsetX + puzzleAreaWidth
        let puzzleAreaTop = offsetY
        let puzzleAreaBottom = offsetY + puzzleAreaHeight
        
        // まず、すべてのグリッド位置にどのピースが配置されているかを記録
        var gridOccupancy: [Int: UUID] = [:] // gridIndex -> pieceId
        
        for index in pieces.indices {
            let piece = pieces[index]
            if let gridPos = getGridPositionForPiece(piece, imageSize: imageSize) {
                let gridIndex = gridPos.row * puzzleSize + gridPos.col
                // 既に他のピースが配置されている場合はスキップ（最初に見つかったピースを優先）
                if gridOccupancy[gridIndex] == nil {
                    gridOccupancy[gridIndex] = piece.id
                }
            }
        }
        
        for index in pieces.indices {
            var piece = pieces[index]
            
            // グリッド位置に配置されているピースは、そのグリッド位置を維持する
            if let gridPos = getGridPositionForPiece(piece, imageSize: imageSize) {
                let gridIndex = gridPos.row * puzzleSize + gridPos.col
                // このグリッド位置にこのピースが配置されていることを確認
                if gridOccupancy[gridIndex] == piece.id {
                    // グリッド位置を維持（画像座標系で正確な位置に設定）
                    let gridX = CGFloat(gridPos.col) * pieceWidth + pieceWidth / 2
                    let gridY = CGFloat(gridPos.row) * pieceHeight + pieceHeight / 2
                    piece.currentPosition = CGPoint(x: gridX, y: gridY)
                    pieces[index] = piece
                    continue
                }
            }
            
            // 既に正しい位置にあるピースもスキップ（念のため）
            let distanceToTarget = sqrt(
                pow(piece.currentPosition.x - piece.targetPosition.x, 2) +
                pow(piece.currentPosition.y - piece.targetPosition.y, 2)
            )
            let threshold = max(pieceWidth, pieceHeight) * 0.6
            if distanceToTarget < threshold {
                continue // 既に正しい位置にある
            }
            
            // 画面座標での位置を計算
            let screenX = piece.currentPosition.x * scale + offsetX
            let screenY = piece.currentPosition.y * scale + offsetY
            
            if isLandscape {
                // 横向き時：枠（パズル完成エリア）の外に配置
                let pieceCenterX = screenX
                let pieceCenterY = screenY
                
                // パズル完成エリア内にあるかチェック
                let isInPuzzleArea = pieceCenterX >= puzzleAreaLeft - scaledPieceWidth / 2 &&
                                    pieceCenterX <= puzzleAreaRight + scaledPieceWidth / 2 &&
                                    pieceCenterY >= puzzleAreaTop - scaledPieceHeight / 2 &&
                                    pieceCenterY <= puzzleAreaBottom + scaledPieceHeight / 2
                
                if isInPuzzleArea {
                    // パズル完成エリア内にある場合は、左右のスペースに移動
                    let leftAreaRight = puzzleAreaLeft - 20
                    let rightAreaLeft = puzzleAreaRight + 20
                    
                    // 左右どちらかにランダムに配置
                    let useLeft = Bool.random()
                    let newScreenX: CGFloat
                    let leftMinX = scaledPieceWidth / 2
                    let leftMaxX = max(leftMinX, leftAreaRight - scaledPieceWidth / 2)
                    let rightMinX = min(rightAreaLeft + scaledPieceWidth / 2, screenWidth - scaledPieceWidth / 2)
                    let rightMaxX = screenWidth - scaledPieceWidth / 2
                    
                    if useLeft && leftMaxX > leftMinX {
                        newScreenX = CGFloat.random(in: leftMinX...leftMaxX)
                    } else if rightMaxX > rightMinX {
                        newScreenX = CGFloat.random(in: rightMinX...rightMaxX)
                    } else if leftMaxX > leftMinX {
                        newScreenX = CGFloat.random(in: leftMinX...leftMaxX)
                    } else {
                        // フォールバック：画面の端に配置
                        newScreenX = screenX < screenWidth / 2 ? scaledPieceWidth / 2 : screenWidth - scaledPieceWidth / 2
                    }
                    
                    // Y座標は画面内に収まる範囲でランダムに配置
                    let minY = scaledPieceHeight / 2
                    let maxY = screenHeight - scaledPieceHeight / 2
                    let safeMaxY = max(minY, maxY) // 下限 <= 上限 を保証
                    let newScreenY = CGFloat.random(in: minY...safeMaxY)
                    
                    // 画像座標系に変換
                    let correctedImageX = (newScreenX - offsetX) / scale
                    let correctedImageY = (newScreenY - offsetY) / scale
                    
                    piece.currentPosition = CGPoint(x: correctedImageX, y: correctedImageY)
                    pieces[index] = piece
                } else {
                    // 既に枠の外にある場合は、画面内に収まるように調整
                    let minX = scaledPieceWidth / 2
                    let maxX = screenWidth - scaledPieceWidth / 2
                    let minY = scaledPieceHeight / 2
                    let maxY = screenHeight - scaledPieceHeight / 2
                    
                    if screenX < minX || screenX > maxX || screenY < minY || screenY > maxY {
                        let clampedScreenX = max(minX, min(maxX, screenX))
                        let clampedScreenY = max(minY, min(maxY, screenY))
                        
                        let correctedImageX = (clampedScreenX - offsetX) / scale
                        let correctedImageY = (clampedScreenY - offsetY) / scale
                        
                        piece.currentPosition = CGPoint(x: correctedImageX, y: correctedImageY)
                        pieces[index] = piece
                    }
                }
            } else {
                // 縦向き時：画面内に収まるように調整（従来の動作）
                let minX = scaledPieceWidth / 2
                let maxX = screenWidth - scaledPieceWidth / 2
                let minY = scaledPieceHeight / 2
                let maxY = screenHeight - scaledPieceHeight / 2
                
                if screenX < minX || screenX > maxX || screenY < minY || screenY > maxY {
                    let clampedScreenX = max(minX, min(maxX, screenX))
                    let clampedScreenY = max(minY, min(maxY, screenY))
                    
                    let correctedImageX = (clampedScreenX - offsetX) / scale
                    let correctedImageY = (clampedScreenY - offsetY) / scale
                    
                    piece.currentPosition = CGPoint(x: correctedImageX, y: correctedImageY)
                    pieces[index] = piece
                }
            }
        }
    }
    
    // 最寄りのグリッド位置を探す（中心座標を返す）
    private func findNearestGridPosition(to position: CGPoint, for piece: PuzzlePiece, scale: CGFloat) -> CGPoint? {
        guard let image = selectedImage else { return nil }
        
        let imageSize = image.size
        let pieceWidth = imageSize.width / CGFloat(puzzleSize)
        let pieceHeight = imageSize.height / CGFloat(puzzleSize)
        
        // すべてのグリッド位置をチェック（中心座標）
        var nearestPosition: CGPoint?
        var minDistance: CGFloat = CGFloat.greatestFiniteMagnitude
        
        for row in 0..<puzzleSize {
            for col in 0..<puzzleSize {
                // グリッドの中心座標
                let gridX = CGFloat(col) * pieceWidth + pieceWidth / 2
                let gridY = CGFloat(row) * pieceHeight + pieceHeight / 2
                
                let distance = sqrt(
                    pow(position.x - gridX, 2) +
                    pow(position.y - gridY, 2)
                )
                
                if distance < minDistance {
                    minDistance = distance
                    nearestPosition = CGPoint(x: gridX, y: gridY)
                }
            }
        }
        
        return nearestPosition
    }
    
    func checkCompletion(scale: CGFloat = 1.0) {
        // 全てのピースが正しい位置にあるかチェック
        // 個々のピースのisPlacedフラグではなく、実際の位置をチェック
        guard !pieces.isEmpty, !isCompleted else { return }
        
        guard let image = selectedImage else { return }
        
        // すべてのグリッド位置にピースが配置されているかチェック
        var gridOccupancy: [Int: Int] = [:] // gridIndex -> pieceIndex
        
        // 各ピースがどのグリッド位置に配置されているかを記録
        for (index, piece) in pieces.enumerated() {
            if let gridPos = getGridPositionForPiece(piece, imageSize: image.size) {
                let gridIndex = gridPos.row * puzzleSize + gridPos.col
                // 既に他のピースが配置されている場合は、完了と判定しない
                if gridOccupancy[gridIndex] != nil {
                    // 重複がある場合は完了と判定しない
                    return
                }
                gridOccupancy[gridIndex] = index
            } else {
                // グリッド位置に配置されていないピースがある場合は完了と判定しない
                return
            }
        }
        
        // すべてのグリッド位置にピースが配置されているかチェック
        let expectedGridCount = puzzleSize * puzzleSize
        if gridOccupancy.count != expectedGridCount {
            // すべてのグリッド位置にピースが配置されていない
            return
        }
        
        // 各ピースが正しいグリッド位置に配置されているかチェック
        var allCorrect = true
        var incorrectPieces: [Int] = []
        
        for (index, piece) in pieces.enumerated() {
            if let gridPos = getGridPositionForPiece(piece, imageSize: image.size) {
                let expectedRow = piece.row
                let expectedCol = piece.column
                if gridPos.row != expectedRow || gridPos.col != expectedCol {
                    // 間違ったグリッド位置に配置されている
                    allCorrect = false
                    incorrectPieces.append(index)
                }
            } else {
                // グリッド位置に配置されていない（これは上でチェック済みなので、ここには来ないはず）
                allCorrect = false
                incorrectPieces.append(index)
            }
        }
        
        // デバッグ用（開発時のみ）
        #if DEBUG
        if !allCorrect {
            print("完成判定: グリッド上のピース数 = \(gridOccupancy.count)/\(puzzleSize * puzzleSize), 不正なピース数 = \(incorrectPieces.count)/\(pieces.count)")
            for idx in incorrectPieces {
                let piece = pieces[idx]
                if let gridPos = getGridPositionForPiece(piece, imageSize: image.size) {
                    print("  ピース[\(idx)]: グリッド位置 = (\(gridPos.row), \(gridPos.col)), 期待位置 = (\(piece.row), \(piece.column))")
                } else {
                    print("  ピース[\(idx)]: グリッド位置に配置されていない")
                }
            }
        }
        #endif
        
        if allCorrect {
            isCompleted = true
            stopTimer()
            
            // 完成アニメーション用の遅延
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // アニメーション完了後の処理は必要に応じて追加
            }
        }
    }
    
    func resetGame() {
        if let image = selectedImage {
            createPuzzle(from: image, size: puzzleSize)
        }
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, milliseconds)
    }
}

