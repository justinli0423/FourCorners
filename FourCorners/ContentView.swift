//
//  ContentView.swift
//  FourCorners
//
//  Created by Justin Li on 2021-11-13.
//

import SwiftUI
import AVKit

enum PlacementSelection: String, CaseIterable, Identifiable {
    case random
    case inOrder
    
    var id: String { self.rawValue }
}

struct CornerViewModel {
    var id: Corner
    var probability: Double = Double(1/6)
    var isEnabled: Bool = true
    var lastVisited: Bool = false
    var isActive: Bool = false
    
    enum Corner {
        case topLeft
        case topRight
        case left
        case right
        case bottomLeft
        case bottomRight
    }
}

class DrillViewModel: ObservableObject {
    var audioPlayer: AVAudioPlayer!
    @Published var corners: [CornerViewModel] = [
        .init(id: .topLeft),
        .init(id: .topRight),
        .init(id: .left),
        .init(id: .right),
        .init(id: .bottomLeft),
        .init(id: .bottomRight),
    ]
    @Published var recoveryTime: Double = 0.6
    @Published var setInterval: Double = 30
    @Published var previewTimer: Double = 1
    @Published var numSets: Int = 5
    @Published var numBirdsPerSet: Int = 20
    @Published var isSoundEnabled: Bool = false
    
    @Published var remainingBreakTime: Double = 30
    @Published var remainingSets: Int = 5
    @Published var remainingBirdsPerSet: Int = 20
    
    @Published var drillInProgress: Bool = false
    
    func setup() {
        remainingBreakTime = setInterval
        remainingSets = numSets
        remainingBirdsPerSet = numBirdsPerSet
        
        if isSoundEnabled,
           let path = Bundle.main.path(forResource: "beep", ofType: "mp3") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            } catch {
                print( "Could not find file")
            }
        }
        
        setupCorners()
        startDrill()
    }
    
    func setupCorners() {
        var lastUsedIndex: Int? = nil
        
        // reset and cache last used index
        corners = corners.enumerated().map { (index, viewModel) in
            var vm = viewModel
            if vm.lastVisited {
                lastUsedIndex = index
            }
            vm.isActive = false
            vm.lastVisited = false
            return vm
        }
        
        let numCornersEnabled = corners.filter { viewModel in
            return viewModel.isEnabled
        }.count
        
        var probability = Double(1)/Double(numCornersEnabled)
        
        if let lastUsedIndex = lastUsedIndex {
            let lastCornerProbability = probability / 2
            probability = Double(1 - Double(lastCornerProbability)) / Double(numCornersEnabled - 1)
            
            corners = corners.enumerated().map { (index, viewModel) -> CornerViewModel in
                guard viewModel.isEnabled else {
                    return viewModel
                }
                
                var newVM = viewModel
                
                if index < lastUsedIndex {
                    newVM.probability = Double(index + 1) * probability
                } else {
                    newVM.probability = Double(index) * probability + lastCornerProbability
                }
                
                if index == corners.count - 1 {
                    newVM.probability = 1
                }
                return newVM
            }
        } else {
            corners = corners.enumerated().map { (index, viewModel) -> CornerViewModel in
                guard viewModel.isEnabled else {
                    return viewModel
                }
                
                var newVM = viewModel
                newVM.probability = Double(index + 1) * probability
                
                if index == corners.count - 1 {
                    newVM.probability = 1
                }
                return newVM
            }
        }
    }
    
    func startDrill() {
        drillInProgress = true
        remainingBreakTime = setInterval
        
        if remainingSets == numSets {
            // first set - don't need the rest interval
            startNewSet()
        } else if remainingSets > 0 {
            // start drill after rest timer
            _ = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] overallTimer in
                guard let self = self else { return }
                if !self.drillInProgress {
                    overallTimer.invalidate()
                    return
                }
                if self.remainingBreakTime == 0 {
                    // break time is over
                    overallTimer.invalidate()
                    self.startNewSet()
                    return
                }
                self.remainingBreakTime -= 1
            }
        } else {
            drillInProgress = false
        }
    }
    
    func startNewSet() {
        remainingSets -= 1
        remainingBirdsPerSet = numBirdsPerSet
        _ = Timer.scheduledTimer(withTimeInterval: recoveryTime + previewTimer, repeats: true) { [weak self] setTimer in
            guard let self = self else { return }
            if !self.drillInProgress {
                setTimer.invalidate()
            }
            if self.remainingBirdsPerSet == 0 {
                setTimer.invalidate()
                self.startDrill()
                return
            }
            
            self.selectCorner()
        }
        
    }
    
    func selectCorner() {
        setupCorners()
        remainingBirdsPerSet -= 1
        
        let probability = Double.random(in: 0...1)
        var isCornerSelected = false
        
        corners = corners.map { viewModel in
            var vm = viewModel
            if probability <= vm.probability && !isCornerSelected {
                isCornerSelected = true
                vm.lastVisited = true
                vm.isActive = true
                
                if isSoundEnabled && drillInProgress {
                    audioPlayer.play()
                }
            }
            return vm
        }
        
        resetAllCorners()
    }
    
    func resetAllCorners() {
        _ = Timer.scheduledTimer(withTimeInterval: previewTimer, repeats: false) { [weak self] setTimer in
            guard let self = self else { return }
            if !self.drillInProgress {
                setTimer.invalidate()
            }
            
            self.corners = self.corners.map { viewModel in
                var vm = viewModel
                vm.isActive = false
                return vm
            }
            
        }
    }
    
    func stopDrill() {
        drillInProgress = false
    }
}

struct ContentView: View {
    @StateObject private var drillViewModel = DrillViewModel()
    @State private var isEditingInterval = false
    @State private var isEditingSetInterval = false
    @State private var isEditingPreview = false
    
    @State var initialCountdown = 5
    @State var initialTimer: Timer? = nil
    
    var body: some View {
        VStack (alignment: .center) {
            Text("FourCorners")
                .font(.title)
            
            if drillViewModel.drillInProgress {
                drillInProgressView
            } else {
                setupDrillView
            }
            
            Group {
                Button(action: {
                    if drillViewModel.drillInProgress || initialTimer != nil {
                        initialTimer?.invalidate()
                        initialTimer = nil
                        initialCountdown = 5
                        drillViewModel.stopDrill()
                        return
                    }
                    
                    // start Action
                    initialTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                        if initialCountdown == 0 {
                            timer.invalidate()
                            initialTimer = nil
                            initialCountdown = 5
                            drillViewModel.setup()
                        }
                        
                        initialCountdown -= 1
                    }
                }, label: {
                    Text(!(drillViewModel.drillInProgress || initialTimer != nil) ? "Start" : "Cancel")
                        .font(.largeTitle)
                        .foregroundColor(Color.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 4)
                })
            }
            .background(!(drillViewModel.drillInProgress || initialTimer != nil) ? Color.blue : Color.red)
            .cornerRadius(16)
        }.padding(.horizontal, 12)
    }
    
    var drillInProgressView: some View {
        VStack (alignment: .leading, spacing: 4) {
            VStack (alignment: .center) {
                HStack{
                    Spacer()
                }
                if drillViewModel.remainingBirdsPerSet > 0 {
                    Text("\(drillViewModel.remainingBirdsPerSet) birds left")
                        .font(.title)
                    Text("\(drillViewModel.remainingSets) sets left")
                        .font(.title3)
                } else {
                    Text("\(String(format: "%.0f", drillViewModel.remainingBreakTime)) seconds until next set")
                        .font(.title)
                    Text("\(drillViewModel.remainingSets) sets left")
                        .font(.title3)
                }
            }
            
            Spacer()
            
            ZStack(alignment: .center) {
                VStack {
                    HStack {
                        Circle()
                            .foregroundColor(drillViewModel.corners[0].isActive ? Color.red : Color.gray)
                            .frame(width: 80, height: 80)
                        Spacer()
                        Circle()
                            .foregroundColor(drillViewModel.corners[1].isActive ? Color.red : Color.gray)
                            .frame(width: 80, height: 80)
                    }
                    Spacer()
                    HStack {
                        Circle()
                            .foregroundColor(drillViewModel.corners[2].isActive ? Color.red : Color.gray)
                            .frame(width: 80, height: 80)
                        Spacer()
                        Circle()
                            .foregroundColor(drillViewModel.corners[3].isActive ? Color.red : Color.gray)
                            .frame(width: 80, height: 80)
                    }
                    Spacer()
                    HStack {
                        Circle()
                            .foregroundColor(drillViewModel.corners[4].isActive ? Color.red : Color.gray)
                            .frame(width: 80, height: 80)
                        Spacer()
                        Circle()
                            .foregroundColor(drillViewModel.corners[5].isActive ? Color.red : Color.gray)
                            .frame(width: 80, height: 80)
                    }
                    .padding(.bottom, 20)
                }
                .padding(.vertical, 40)
                .padding(.horizontal, 12)
            }
        }.padding(.top, 24)
    }
    
    var setupDrillView: some View {
        VStack (alignment: .leading, spacing: 4) {
            HStack {
                Text("Set Interval: ")
                HStack {
                    Text("\(String(format: "%.0f", drillViewModel.setInterval)) s")
                        .foregroundColor(isEditingSetInterval ? .red : .blue)
                    
                    Slider(
                        value: $drillViewModel.setInterval,
                        in: 10...50,
                        step: 5,
                        onEditingChanged: { editing in
                            isEditingSetInterval = editing
                        }
                    ).disabled(drillViewModel.drillInProgress)
                }
            }
            
            HStack {
                Text("Recovery Between Birds: ")
                HStack {
                    Text("\(String(format: "%.0f", drillViewModel.recoveryTime * 1000)) ms")
                        .foregroundColor(isEditingInterval ? .red : .blue)
                    
                    Slider(
                        value: $drillViewModel.recoveryTime,
                        in: 0.1...1.55,
                        step: 0.05,
                        onEditingChanged: { editing in
                            isEditingInterval = editing
                        }
                    ).disabled(drillViewModel.drillInProgress)
                }
            }
            
            HStack {
                Text("Preview Timer: ")
                HStack {
                    Text("\(String(format: "%.0f", drillViewModel.previewTimer * 1000)) ms")
                        .foregroundColor(isEditingPreview ? .red : .blue)
                    
                    Slider(
                        value: $drillViewModel.previewTimer,
                        in: 0.1...1.55,
                        step: 0.05,
                        onEditingChanged: { editing in
                            isEditingPreview = editing
                        }
                    ).disabled(drillViewModel.drillInProgress)
                }
            }
            
            HStack {
                Text("Sets:")
                Picker("Number of Sets", selection: $drillViewModel.numSets) {
                    ForEach(1 ..< 11, id: \.self) {
                        Text("\($0) sets")
                    }
                }.disabled(drillViewModel.drillInProgress)
            }
            
            HStack {
                Text("Birds per set:")
                Picker("Birds Per Set", selection: $drillViewModel.numBirdsPerSet) {
                    ForEach(10 ..< 30, id: \.self) {
                        Text("\($0) birds")
                    }
                }.disabled(drillViewModel.drillInProgress)
            }
            
            Toggle("Sound: ", isOn: $drillViewModel.isSoundEnabled).disabled(drillViewModel.drillInProgress)
            
            Text(initialTimer != nil ? "Starting in: \(initialTimer != nil ? String(initialCountdown) : "")" : "").foregroundColor(.red)
            
            ZStack(alignment: .center) {
                courtBackground
                VStack {
                    HStack {
                        Circle()
                            .foregroundColor(drillViewModel.corners[0].isEnabled ? Color.red : Color.gray)
                            .frame(width: 50, height: 50)
                            .onTapGesture {
                                drillViewModel.corners[0].isEnabled.toggle()
                            }
                        Spacer()
                        Circle()
                            .foregroundColor(drillViewModel.corners[1].isEnabled ? Color.red : Color.gray)
                            .frame(width: 50, height: 50)
                            .onTapGesture {
                                drillViewModel.corners[1].isEnabled.toggle()
                            }
                    }
                    Spacer()
                    HStack {
                        Circle()
                            .foregroundColor(drillViewModel.corners[2].isEnabled ? Color.red : Color.gray)
                            .frame(width: 50, height: 50)
                            .onTapGesture {
                                drillViewModel.corners[2].isEnabled.toggle()
                            }
                        Spacer()
                        Circle()
                            .foregroundColor(drillViewModel.corners[3].isEnabled ? Color.red : Color.gray)
                            .frame(width: 50, height: 50)
                            .onTapGesture {
                                drillViewModel.corners[3].isEnabled.toggle()
                            }
                    }
                    Spacer()
                    HStack {
                        Circle()
                            .foregroundColor(drillViewModel.corners[4].isEnabled ? Color.red : Color.gray)
                            .frame(width: 50, height: 50)
                            .onTapGesture {
                                drillViewModel.corners[4].isEnabled.toggle()
                            }
                        Spacer()
                        Circle()
                            .foregroundColor(drillViewModel.corners[5].isEnabled ? Color.red : Color.gray)
                            .frame(width: 50, height: 50)
                            .onTapGesture {
                                drillViewModel.corners[5].isEnabled.toggle()
                            }
                    }
                    .padding(.bottom, 30)
                }
                .padding(.vertical, 40)
                .padding(.horizontal, 12)
            }
        }
    }
    
    
    var courtBackground: some View {
        GeometryReader { geo in
            Image("Court")
                .resizable()
                .scaledToFit()
                .clipped()
                .padding(.horizontal, 12)
                .rotationEffect(.degrees(90))
                .frame(width: geo.size.width)
                .cornerRadius(10)
        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
