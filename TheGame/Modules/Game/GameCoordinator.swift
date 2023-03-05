//
//  GameCoordinator.swift
//  TheGame
//
//  Created by Aleksei Pugachev on 4.03.2023.
//

import UIKit
import Combine

class GameCoordinatorObservable: ObservableObject {
    
    @Published var status = GameKit.Status.active
    @Published var voicechat = false
    
}

class GameCoordinator {
    
    private(set) var observables = GameCoordinatorObservable()

    private var disposeBag = Set<AnyCancellable>()
    
    init() {
        GameKit.shared.observables.$status.sink { status in
            self.observables.status = status
        }
        .store(in: &disposeBag)
        
        GameKit.shared.observables.$voicechat.sink { voicechat in
            self.observables.voicechat = voicechat
        }
        .store(in: &disposeBag)
    }
    
}

extension GameCoordinator {
    
    public func findMatch() {
        GameKit.shared.findMatch()
    }
    
    public func stopMatch() {
        GameKit.shared.stopMatch()
    }
    
    public func toggleVoicechat() {
        GameKit.shared.toggleVoicechat()
    }
    
}
