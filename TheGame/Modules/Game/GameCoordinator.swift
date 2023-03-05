//
//  GameCoordinator.swift
//  TheGame
//
//  Created by Aleksei Pugachev on 4.03.2023.
//

import UIKit
import Combine
import CoreLocation

class GameCoordinatorObservable: ObservableObject {
    
    @Published fileprivate(set) var status = GameKit.Status.active
    @Published fileprivate(set) var voicechat = false
    
    @Published fileprivate(set) var round: (CLLocation,[String])?
    
    @Published fileprivate(set) var answered = (0,0)
    
}

class GameCoordinator {
    
    private(set) var observables = GameCoordinatorObservable()

    private var disposeBag = Set<AnyCancellable>()
    
    private var round = 0
    
    init() {
        GameKit.shared.observables.$status.sink { status in
            self.observables.status = status
            
            if status == .game {
                self.round = 0
                
                self.observables.answered = (0,0)
                
                self.goNextRound()
            }
        }
        .store(in: &disposeBag)
        
        GameKit.shared.observables.$voicechat.sink { voicechat in
            self.observables.voicechat = voicechat
        }
        .store(in: &disposeBag)
    }
    
}

extension GameCoordinator {
    
    private func goNextRound() {
        guard GameKit.shared.rounds.count > round else {
            GameKit.shared.stopMatch()
            return
        }
        
        observables.round = GameKit.shared.rounds[round]
        round += 1
    }
    
}

extension GameCoordinator {
    
    public func findMatch() {
        GameKit.shared.findMatch()
    }
    
    public func shareplayMatch() {
        Task {
            try? await GameKit.shared.shareplayMatch()
        }
    }
    
    public func stopMatch() {
        GameKit.shared.stopMatch()
    }
    
    public func toggleVoicechat() {
        GameKit.shared.toggleVoicechat()
    }
    
    public func answer(_ answer: String) {
        observables.answered.0 += 1
        
        if answer == observables.round?.1.first {
            observables.answered.1 += 1
        }
        
        goNextRound()
    }
    
}
