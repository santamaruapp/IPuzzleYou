//
//  ContentView.swift
//  PuzzleMaker
//
//  Created by santamaru on 2026/01/17.
//

import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @StateObject private var game = PuzzleGame()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingImagePicker = false
    @State private var draggedPieceId: UUID?
    @State private var isDragging = false
    @State private var showingReferenceImage = false // 参照画像表示フラグ
    @State private var deviceOrientation: UIDeviceOrientation = .unknown
    @State private var cachedScale: CGFloat? = nil // ゲーム中のパズルスケールを保持（完成後も同じサイズを維持）
    
    private let puzzleSizes = [2, 3, 4, 5, 6]
    
    // デバイスの向きを判定（横向きのみを true とする）
    private func isLandscapeOrientation(geometry: GeometryProxy? = nil) -> Bool {
        let orientation = deviceOrientation
        
        // 横向きのみを true とする（逆さまは縦向きとして扱う）
        if orientation == .landscapeLeft || orientation == .landscapeRight {
            return true
        }
        
        // 縦向き（通常と逆さま）は false
        if orientation == .portrait || orientation == .portraitUpsideDown {
            return false
        }
        
        // 向きが不明な場合は、画面サイズで判定（フォールバック）
        if let geometry = geometry {
            return geometry.size.width > geometry.size.height
        }
        
        // それでも不明な場合は false（縦向きとして扱う）
        return false
    }
    
    // 逆さまかどうかを判定
    private func isUpsideDown() -> Bool {
        return deviceOrientation == .portraitUpsideDown
    }
    
    // 座標を通常の縦向きの座標系に変換（逆さまの時はY座標を反転）
    private func convertCoordinate(_ point: CGPoint, in geometry: GeometryProxy) -> CGPoint {
        if isUpsideDown() {
            // 逆さまの時はY座標を反転
            return CGPoint(x: point.x, y: geometry.size.height - point.y)
        }
        return point
    }
    
    // 座標を通常の縦向きの座標系から逆変換（逆さまの時はY座標を反転）
    private func reverseConvertCoordinate(_ point: CGPoint, in geometry: GeometryProxy) -> CGPoint {
        if isUpsideDown() {
            // 逆さまの時はY座標を反転
            return CGPoint(x: point.x, y: geometry.size.height - point.y)
        }
        return point
    }
    
    // iPadかどうかを判定
    private func isiPad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    // 画像を画面に収まるようにスケール計算
    private func calculateScale(for image: UIImage, in geometry: GeometryProxy) -> CGFloat {
        let isLandscape = isLandscapeOrientation(geometry: geometry)
        let isPadDevice = isiPad()
        
        // ヘッダーと完成メッセージのスペースを考慮
        let headerHeight: CGFloat = 80
        // 完成後は完成メッセージの高さを考慮しない（cachedScaleで維持するため）
        // 完成前のみ完成メッセージのスペースを確保
        let completionMessageHeight: CGFloat
        if game.isCompleted {
            // 完成後はメッセージの高さを考慮しない（サイズを維持するため）
            completionMessageHeight = 0
        } else if isLandscape {
            // 横向き時：完成前はメッセージのスペースを確保しない
            completionMessageHeight = 0
        } else {
            // 縦向き時：完成前のみメッセージのスペースを確保
            completionMessageHeight = isPadDevice ? 100 : 60
        }
        // 完了前後でパズルのサイズが変わらないように、
        // 完成後はメッセージの高さを考慮しない
        let availableHeight = geometry.size.height - headerHeight - completionMessageHeight
        
        if isLandscape {
            // 横向き時：画面全体を最大限活用（ゲーム中は通常サイズ）
            let maxWidth = geometry.size.width * 0.99 // ほぼ全幅を使用
            let maxHeight = availableHeight * 0.98 // ほぼ全高を使用
            
            let imageAspect = image.size.width / image.size.height
            let maxAspect = maxWidth / maxHeight
            
            let scale: CGFloat
            if imageAspect > maxAspect {
                // 幅が制限
                scale = maxWidth / image.size.width
            } else {
                // 高さが制限
                scale = maxHeight / image.size.height
            }
            
            // 横向き時は上限を大きく設定（画面全体を使う）
            return min(scale, 2.0) // 最大2.0倍まで
        } else {
            // 縦向き時
            if isPadDevice {
                // iPad版：より大きく表示
                let maxWidth = geometry.size.width * 0.95 // ほぼ全幅を使用
                let maxHeight = availableHeight * 0.75 // より多くの高さを使用
                
                let imageAspect = image.size.width / image.size.height
                let maxAspect = maxWidth / maxHeight
                
                let scale: CGFloat
                if imageAspect > maxAspect {
                    scale = maxWidth / image.size.width
                } else {
                    scale = maxHeight / image.size.height
                }
                
                return min(scale, 1.2) // iPad版は最大1.2倍まで
            } else {
                // iPhone版：従来の設定
                let maxWidth = geometry.size.width * 0.9
                let maxHeight = availableHeight * 0.4
                
                let imageAspect = image.size.width / image.size.height
                let maxAspect = maxWidth / maxHeight
                
                let scale: CGFloat
                if imageAspect > maxAspect {
                    scale = maxWidth / image.size.width
                } else {
                    scale = maxHeight / image.size.height
                }
                
                return min(scale, 0.6) // 最大0.6倍まで
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            if !game.isGameStarted {
                // スタート画面
                startView
            } else {
                // ゲーム画面
                gameView
            }
        }
        .onAppear {
            // デバイスの向き変更を監視開始
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            deviceOrientation = UIDevice.current.orientation
        }
        .onDisappear {
            // 監視を停止
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            deviceOrientation = UIDevice.current.orientation
        }
    }
    
    private var startView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // タイトルセクション
                VStack(spacing: 8) {
                    Text("IPuzzleYou")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text(String(localized: "subtitle"))
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                
                // 選択した画像のプレビュー
                if let image = game.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                        .padding(.horizontal)
                }
                
                // 画像選択
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images
                ) {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title3)
                        Text(game.selectedImage == nil ? String(localized: "select_image") : String(localized: "change_image"))
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .onChange(of: selectedPhoto) { oldValue, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await MainActor.run {
                                game.selectedImage = image
                                game.selectedPuzzleSize = nil // 画像変更時はサイズ選択をリセット
                            }
                        }
                    }
                }
                
                // パズルサイズ選択
                if game.selectedImage != nil {
                    VStack(spacing: 20) {
                        Text(String(localized: "select_difficulty"))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(puzzleSizes, id: \.self) { size in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            game.selectedPuzzleSize = size
                                        }
                                    }) {
                                        VStack(spacing: 6) {
                                            Text("\(size)×\(size)")
                                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                            Text("\(size * size) \(String(localized: "pieces"))")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(.white)
                                        .frame(width: 90, height: 90)
                                        .background(
                                            Group {
                                                if game.selectedPuzzleSize == size {
                                                    LinearGradient(
                                                        colors: [.green, .green.opacity(0.8)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                } else {
                                                    LinearGradient(
                                                        colors: [.blue.opacity(0.7), .blue.opacity(0.5)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                }
                                            }
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 18))
                                        .shadow(
                                            color: game.selectedPuzzleSize == size ? .green.opacity(0.4) : .blue.opacity(0.2),
                                            radius: game.selectedPuzzleSize == size ? 12 : 6,
                                            x: 0,
                                            y: game.selectedPuzzleSize == size ? 6 : 3
                                        )
                                        .scaleEffect(game.selectedPuzzleSize == size ? 1.05 : 1.0)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // 開始ボタン
                        if game.selectedPuzzleSize != nil {
                            Button(action: {
                                if let image = game.selectedImage,
                                   let size = game.selectedPuzzleSize {
                                    // 新しいゲーム開始時にはスケールをリセット
                                    cachedScale = nil
                                    game.createPuzzle(from: image, size: size)
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                        .font(.title3)
                                    Text(String(localized: "start"))
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(
                                        colors: [.green, .green.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .green.opacity(0.4), radius: 12, x: 0, y: 6)
                            }
                            .padding(.horizontal)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                    )
                    .padding(.horizontal)
                }
            }
            .padding()
        }
    }
    
    private var gameView: some View {
        GeometryReader { geometry in
            let isLandscape = isLandscapeOrientation(geometry: geometry)
            
            if isLandscape && game.isCompleted {
                // 横向き時で完成後：パズルとメッセージを横並び
                HStack(spacing: 0) {
                    // パズルエリア
                    puzzleArea
                    
                    // 完成メッセージ（パズルの右側）
                    completionMessage
                        .frame(width: 200) // メッセージの幅を固定
                }
                .safeAreaInset(edge: .top) {
                    headerView
                }
            } else {
                // 縦向き時または完成前：通常のレイアウト
                VStack(spacing: 0) {
                    // ヘッダー
                    headerView
                    
                    // パズルエリア
                    puzzleArea
                    
                    // 完成メッセージ（画面下部）
                    if game.isCompleted {
                        completionMessage
                    }
                }
            }
        }
    }
    
    private var puzzleArea: some View {
        GeometryReader { geometry in
            let image = game.selectedImage
            
            ZStack {
                // 完成時の位置を示すグリッド（薄く表示）
                if let image = image {
                    // 完了後も同じスケールを維持するため、キャッシュされたスケールを優先
                    let currentScale: CGFloat = {
                        if let cached = cachedScale {
                            // 完成後も同じサイズを維持（サイズ変更なし）
                            return cached
                        } else {
                            let scale = calculateScale(for: image, in: geometry)
                            // 完成前は必ずキャッシュ（完成後はサイズを固定するため）
                            if !game.isCompleted {
                                DispatchQueue.main.async {
                                    cachedScale = scale
                                }
                            }
                            return scale
                        }
                    }()
                    
                    // 完成判定は常に完成前のスケール（cachedScale）で行う
                    let completionCheckScale = cachedScale ?? currentScale
                    
                    // パズルピース（先に配置して、ドラッグ可能にする）
                    puzzlePiecesView(image: image, geometry: geometry, scale: currentScale)
                    
                    // グリッドは後ろに配置し、タッチイベントを無効化
                    // 完成後かつ横向きの場合は、グリッドも2倍のスケールで表示
                    gridView(image: image, geometry: geometry, scale: currentScale)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                // 画面表示時に完成判定をチェック
                if let image = image {
                    // 完成判定は常に完成前のスケールで行う
                    let completionCheckScale = cachedScale ?? calculateScale(for: image, in: geometry)
                    game.checkCompletion(scale: completionCheckScale)
                    // 画面外に出ているピースを画面内に戻す（表示スケールを使用）
                    let currentScale = cachedScale ?? calculateScale(for: image, in: geometry)
                    game.ensurePiecesInBounds(screenWidth: geometry.size.width, screenHeight: geometry.size.height, imageSize: image.size, scale: currentScale)
                }
            }
            .onChange(of: game.isCompleted) { oldValue, newValue in
                // 完成判定がtrueになった時点で、cachedScaleを固定（完成前のスケールを保持）
                if newValue && !oldValue {
                    // 完成前のスケールを確実に保持
                    if let image = image, cachedScale == nil {
                        // 念のため、cachedScaleがnilの場合は設定
                        let scale = calculateScale(for: image, in: geometry)
                        DispatchQueue.main.async {
                            cachedScale = scale
                        }
                    }
                }
            }
            .onChange(of: geometry.size) { oldSize, newSize in
                // デバイス回転時に配置されていないピースの位置を再計算
                if let image = image, game.isGameStarted {
                    // 完成後はcachedScaleを更新しない（サイズを維持するため）
                    let currentScale: CGFloat
                    if game.isCompleted {
                        // 完成後はcachedScaleを使用（更新しない）
                        currentScale = cachedScale ?? calculateScale(for: image, in: geometry)
                    } else {
                        // 完成前はスケールを再計算しキャッシュを更新
                        currentScale = calculateScale(for: image, in: geometry)
                        DispatchQueue.main.async {
                            cachedScale = currentScale
                        }
                    }
                    game.repositionUnplacedPieces(
                        screenWidth: newSize.width,
                        screenHeight: newSize.height,
                        imageSize: image.size,
                        scale: currentScale
                    )
                    // 画面外に出ているピースを画面内に戻す
                    game.ensurePiecesInBounds(screenWidth: newSize.width, screenHeight: newSize.height, imageSize: image.size, scale: currentScale)
                }
            }
        }
    }
    
    private func puzzlePiecesView(image: UIImage, geometry: GeometryProxy, scale: CGFloat) -> some View {
        let isLandscape = isLandscapeOrientation(geometry: geometry)
        let headerHeight: CGFloat = 80
        // 横向き時はより上に配置（ヘッダーの中央付近から開始）
        let offsetY: CGFloat = isLandscape ? headerHeight / 2 + 5 : 100
        
        return ForEach(game.pieces) { piece in
            let pieceView = PuzzlePieceView(
                piece: piece,
                scale: scale,
                isDragging: isDragging && draggedPieceId == piece.id
            )
            
            // オフセットとスケールされたピースサイズを計算
            let offsetX = geometry.size.width / 2 - image.size.width * scale / 2
            let scaledPieceWidth = piece.image.size.width * scale
            let scaledPieceHeight = piece.image.size.height * scale
            
            // 通常の計算（完成後も同じ）
            let rawPositionX = piece.currentPosition.x * scale + offsetX
            let rawPositionY = piece.currentPosition.y * scale + offsetY
            
            let minX = scaledPieceWidth / 2
            let maxX = geometry.size.width - scaledPieceWidth / 2
            let minY = scaledPieceHeight / 2
            let maxY = geometry.size.height - scaledPieceHeight / 2
            
            // 画面内に収まるように位置を制限
            let clampedX = max(minX, min(maxX, rawPositionX))
            let clampedY = max(minY, min(maxY, rawPositionY))
            
            // 座標変換を行わない（デバイスの向きに関わらず、パズルの位置を維持）
            let positionX = clampedX
            let positionY = clampedY
            
            pieceView
                .position(x: positionX, y: positionY)
                .animation(.none, value: piece.currentPosition)
                .onAppear {
                    // 画面外に出ている場合は、位置を修正
                    if !piece.isPlaced {
                        // 通常の縦向きの座標系で判定
                        let isOutOfBounds = rawPositionX < minX || rawPositionX > maxX || rawPositionY < minY || rawPositionY > maxY
                        if isOutOfBounds {
                            // 通常の縦向きの座標系で計算
                            let correctedImageX = (clampedX - offsetX) / scale
                            let correctedImageY = (clampedY - offsetY) / scale
                            game.updatePiecePosition(piece.id, to: CGPoint(x: correctedImageX, y: correctedImageY), scale: scale, isDragging: false)
                        }
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            draggedPieceId = piece.id
                            
                            // 座標変換を行わない（デバイスの向きに関わらず、パズルの位置を維持）
                            // 画面内に制限
                            let clampedX = max(minX, min(maxX, value.location.x))
                            let clampedY = max(minY, min(maxY, value.location.y))
                            
                            // 画像座標系で計算
                            let newX = (clampedX - offsetX) / scale
                            let newY = (clampedY - offsetY) / scale
                            game.updatePiecePosition(piece.id, to: CGPoint(x: newX, y: newY), scale: scale, isDragging: true)
                        }
                        .onEnded { _ in
                            isDragging = false
                            // ドラッグ終了時にスナップを試みる
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                game.snapPieceToGrid(piece.id, scale: scale)
                            }
                            // スナップ後に完成判定を再チェック（完成前のスケールを使用）
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                // 完成判定は常に完成前のスケールで行う
                                // scaleは表示用のスケール（完成後は2倍になる可能性がある）なので、
                                // 完成前のスケールを取得する必要がある
                                // cachedScaleが存在する場合はそれを使用、なければscaleを使用
                                let completionCheckScale = cachedScale ?? scale
                                game.checkCompletion(scale: completionCheckScale)
                            }
                            draggedPieceId = nil
                        }
                )
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 16) {
            // タイマー
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(game.formatTime(game.elapsedTime))
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
            )
            
            Spacer()
            
            // 参照画像表示ボタン
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showingReferenceImage.toggle()
                }
            }) {
                Image(systemName: "photo.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [.purple, .purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            // リセットボタン
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    game.resetGame()
                }
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [.orange, .orange.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            // ホームボタン
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    game.isGameStarted = false
                    game.stopTimer()
                }
            }) {
                Image(systemName: "house.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            .ultraThinMaterial,
            in: Rectangle()
        )
        .sheet(isPresented: $showingReferenceImage) {
            if let image = game.selectedImage {
                referenceImageView(image: image)
            }
        }
    }
    
    private func referenceImageView(image: UIImage) -> some View {
        NavigationView {
            ScrollView {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
            }
            .navigationTitle("参照画像")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        showingReferenceImage = false
                    }
                }
            }
        }
    }
    
    private func gridView(image: UIImage, geometry: GeometryProxy, scale: CGFloat) -> some View {
        let imageWidth = image.size.width * scale
        let imageHeight = image.size.height * scale
        let pieceWidth = imageWidth / CGFloat(game.puzzleSize)
        let pieceHeight = imageHeight / CGFloat(game.puzzleSize)
        
        // デバイスの向きに応じてオフセットを調整
        let isLandscape = isLandscapeOrientation(geometry: geometry)
        let headerHeight: CGFloat = 80
        // 横向き時はより上に配置（ヘッダーの中央付近から開始）
        let offsetY: CGFloat = isLandscape ? headerHeight / 2 + 5 : 100
        let offsetX = geometry.size.width / 2 - imageWidth / 2
        
        return ZStack {
            ForEach(0..<game.puzzleSize, id: \.self) { row in
                ForEach(0..<game.puzzleSize, id: \.self) { col in
                    // 通常の計算（完成後も同じ）
                    let gridX = offsetX + CGFloat(col) * pieceWidth + pieceWidth / 2
                    let gridY = offsetY + CGFloat(row) * pieceHeight + pieceHeight / 2
                    
                    Rectangle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        .frame(width: pieceWidth, height: pieceHeight)
                        .position(x: gridX, y: gridY)
                }
            }
        }
    }
    
    private var completionMessage: some View {
        GeometryReader { geometry in
            let isLandscape = isLandscapeOrientation(geometry: geometry)
            let isPadDevice = isiPad()
            
            // 横向きの時は小さく表示、縦向きの時は元のサイズ
            let iconSize: CGFloat = isPadDevice ? (isLandscape ? 32 : 40) : (isLandscape ? 20 : 24)
            let titleFont: Font = isPadDevice ? (isLandscape ? .title3 : .title) : (isLandscape ? .headline : .headline)
            let timeFont: Font = isPadDevice ? (isLandscape ? .subheadline : .title3) : (isLandscape ? .caption : .subheadline)
            let buttonFont: Font = isPadDevice ? (isLandscape ? .subheadline : .headline) : (isLandscape ? .caption : .subheadline)
            let spacing: CGFloat = isPadDevice ? (isLandscape ? 8 : 15) : (isLandscape ? 6 : 8)
            let hSpacing: CGFloat = isPadDevice ? (isLandscape ? 12 : 16) : (isLandscape ? 8 : 12)
            let padding: CGFloat = isPadDevice ? (isLandscape ? 12 : 20) : (isLandscape ? 8 : 12)
            let buttonHPadding: CGFloat = isPadDevice ? (isLandscape ? 12 : 20) : (isLandscape ? 8 : 12)
            let buttonVPadding: CGFloat = isPadDevice ? (isLandscape ? 6 : 12) : (isLandscape ? 4 : 8)
            let messageHeight: CGFloat = isPadDevice ? (isLandscape ? 60 : 100) : (isLandscape ? 50 : 60)
            
            if isLandscape {
                // 横向き時：パズルの右側に縦向きで表示
                VStack(spacing: spacing) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: iconSize * 1.5))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .green.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    VStack(alignment: .center, spacing: 6) {
                        Text(String(localized: "completed"))
                            .font(titleFont)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(String(localized: "time"))
                            .font(timeFont)
                            .foregroundColor(.secondary)
                        
                        Text(game.formatTime(game.elapsedTime))
                            .font(timeFont)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            game.isGameStarted = false
                            game.isCompleted = false
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text(String(localized: "new_puzzle"))
                        }
                        .font(buttonFont)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, buttonHPadding)
                        .padding(.vertical, buttonVPadding)
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: game.isCompleted)
            } else {
                // 縦向き時：元のサイズで表示
                VStack(spacing: spacing) {
                    HStack(spacing: hSpacing) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: iconSize))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .green.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "completed"))
                                .font(titleFont)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("\(String(localized: "time")) \(game.formatTime(game.elapsedTime))")
                                .font(timeFont)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                game.isGameStarted = false
                                game.isCompleted = false
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text(String(localized: "new_puzzle"))
                            }
                            .font(buttonFont)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, buttonHPadding)
                            .padding(.vertical, buttonVPadding)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(padding)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                    )
                }
                .padding(.horizontal)
                .padding(.bottom)
                .frame(height: messageHeight)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: game.isCompleted)
            }
        }
    }
}

#Preview {
    ContentView()
}
